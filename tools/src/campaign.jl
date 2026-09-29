"""A candidate-code or numerical failure distinct from execution infrastructure failure."""
struct CandidateError <: Exception
    message::String
end
Base.showerror(io::IO, error::CandidateError) = print(io, error.message)

is_research_worker() = get(ENV, "AUTONV_WORKER", "0") == "1" || !isempty(get(ENV, "AUTONV_WORKER_ROLE", ""))

"""Create a research workspace managed by explicit user-requested tool calls."""
function campaign_init(path::AbstractString; system="nv", backend="auto", tolerance=.05, alpha=.01)
    is_research_worker() && error("A worker cannot launch another campaign")
    system in ("generic", "nv") || error("system must be generic or nv")
    backend in ("auto", "cpu", "cuda") || error("backend must be auto, cpu or cuda")
    0 < tolerance < 1 || error("tolerance must lie between zero and one")
    0 < alpha < 1 || error("alpha must lie between zero and one")
    path = abspath(path)
    isfile(joinpath(path, "state.json")) && error("Campaign already exists; use its existing workspace or inspect status")
    mkpath(path)
    for name in ("raw-data", "research", "results")
        mkpath(joinpath(path, name))
    end
    state = Dict{String,Any}("version"=>2, "device_id"=>bytes2hex(rand(Random.RandomDevice(), UInt8, 16)),
        "system"=>system, "backend"=>backend,
        "tolerance"=>Float64(tolerance), "alpha"=>Float64(alpha), "round"=>0,
        "validation_attempt"=>0, "status"=>"ready", "stage"=>"idle", "history"=>Any[],
        "validation_device"=>"synthetic")
    write_json_atomic(joinpath(path, "device-description.json"),
        Dict("kind"=>"synthetic", "description"=>description_to_dict(device_description(Symbol(system)))))
    write_json_atomic(joinpath(path, "state.json"), state)
    path
end

"""Read experiment and review records without running simulations or agents."""
campaign_status(path::AbstractString) = read_json(joinpath(abspath(path), "state.json"))

"""Resolve laboratory storage outside the research workspace.

`AUTONV_PRIVATE_ROOT` overrides the default repository `private/devices` directory.
The public device ID is an opaque locator, independent of physical parameters and
the private sampling seed. Moving a workspace must preserve this ID and storage.
"""
function private_device_directory(state)
    get(state, "version", 0) == 2 || error("Legacy campaign: migrate its private device before acquisition")
    id = get(state, "device_id", "")
    id isa AbstractString && occursin(r"^[0-9a-f]{32}$", id) || error("Invalid device ID")
    root = get(ENV, "AUTONV_PRIVATE_ROOT", joinpath(dirname(PACKAGE_ROOT), "private", "devices"))
    joinpath(abspath(root), id)
end

function campaign_lock(path)
    lock = joinpath(path, "controller.lock")
    if isdir(lock)
        owner = joinpath(lock, "pid")
        # Only reclaim a known dead local process. An incomplete lock fails closed.
        pid = isfile(owner) ? tryparse(Int, strip(read(owner, String))) : nothing
        alive = pid === nothing || !Sys.isunix() || ccall(:kill, Cint, (Cint,Cint), pid, 0) == 0 || Libc.errno() != 3
        alive && error("Campaign is locked by another controller: $lock")
        rm(lock; recursive=true)
    end
    mkdir(lock)
    write(joinpath(lock, "pid"), string(getpid()))
    lock
end

"""Hash every regular file and relative name; reject links and non-file entries."""
function bundle_hash(directory)
    isdir(directory) || error("Candidate directory is missing")
    islink(directory) && error("Candidate directory must not be a symlink")
    paths = String[]
    for (root, dirs, files) in walkdir(directory; follow_symlinks=false)
        for name in [dirs; files]
            path = joinpath(root, name)
            islink(path) && error("Candidate bundles cannot contain symbolic links")
            (isdir(path) || isfile(path)) || error("Candidate bundles contain regular files only")
        end
        append!(paths, relpath.(joinpath.(root, files), Ref(directory)))
    end
    "main.jl" in paths || error("Candidate must contain main.jl")
    io = IOBuffer()
    for relative in sort(paths)
        contents = read(joinpath(directory, relative))
        write(io, string(ncodeunits(relative)), ':', relative, ':', string(length(contents)), ':')
        write(io, contents)
    end
    bytes2hex(SHA.sha256(take!(io)))
end

"""Hoeffding validation with summable alpha spending over repeated attempts."""
function validation_gate(predictions, observations; tolerance=.05, alpha=.01, attempt=1)
    m = length(predictions)
    m > 0 && m == length(observations) || error("Prediction/observation counts differ or are empty")
    attempt >= 1 || error("Validation attempt must be positive")
    alpha_attempt = alpha / (Float64(attempt) * (attempt + 1))
    rows = Any[]
    for (p, observation) in zip(predictions, observations)
        n, count = observation["shots"], observation["counts"]
        n isa Integer && n > 0 && count isa Integer && 0 <= count <= n || error("Invalid measurement counts")
        p isa Real && isfinite(p) && 0 <= p <= 1 || error("Invalid candidate probability")
        radius = sqrt(log(2m / alpha_attempt) / (2n))
        discrepancy = abs(count / n - p)
        push!(rows, Dict("prediction"=>p, "frequency"=>count/n, "radius"=>radius,
                        "discrepancy"=>discrepancy, "pass"=>discrepancy + radius <= tolerance))
    end
    Dict("pass"=>all(row["pass"] for row in rows), "alpha_attempt"=>alpha_attempt,
         "tolerance"=>tolerance, "settings"=>rows)
end

function validation_experiments(experiments, state)
    m = length(experiments)
    m > 0 || error("At least one validation experiment is required")
    k = state["validation_attempt"]
    alpha_attempt = state["alpha"] / (Float64(k) * (k + 1))
    # Strictly less than half the tolerance, even at an integer rounding boundary.
    shots = floor(Int, 2log(2m / alpha_attempt) / state["tolerance"]^2) + 1
    result = deepcopy(experiments)
    for experiment in result
        experiment["shots"] = max(experiment["shots"], shots)
        experiment_from_dict(experiment)
    end
    result
end

function review_approved(review, candidate_id, evidence_id)
    review isa AbstractDict && get(review, "approve", false) === true &&
        get(review, "candidate_id", "") == candidate_id &&
        get(review, "evidence_id", "") == evidence_id &&
        get(review, "reason", nothing) isa AbstractString && !isempty(strip(review["reason"]))
end

function validate_public_experiments(experiments, system)
    description = device_description(Symbol(system))
    for raw in experiments
        experiment = experiment_from_dict(raw)
        experiment.preparation in description.preparations || error("Unknown device preparation")
        experiment.measurement in description.measurements || error("Unknown device measurement")
        duration = 0.0
        for operation in experiment.operations
            if operation isa Evolution
                duration += operation.duration_us
                all(axis->axis in description.controls, keys(operation.controls)) || error("Unknown device control")
            else
                operation.axis in description.controls || error("Unknown pulse axis")
            end
        end
        duration <= description.max_duration_us || error("Experiment exceeds device duration limit")
    end
    nothing
end

save_campaign(path, state) = write_json_atomic(joinpath(path, "state.json"), state)

function with_campaign(f, path)
    is_research_worker() && error("A prediction subprocess cannot mutate campaign state")
    path = abspath(path)
    lock = campaign_lock(path)
    state = nothing
    try
        state = campaign_status(path)
        pop!(state, "last_error", nothing)
        f(path, state)
    catch exception
        if state !== nothing
            state["status"] = exception isa InterruptException ? "interrupted" : "incomplete"
            state["last_error"] = sprint(showerror, exception)
            save_campaign(path, state)
        end
        rethrow()
    finally
        rm(lock; recursive=true, force=true)
    end
end

function acquire_for_campaign(path, state, pending, acquire)
    observations = if acquire === nothing
        private = private_device_directory(state)
        if get(state, "device_initialized", false) && !isfile(joinpath(private, "device.json"))
            error("Private device storage is missing; restore it or correct AUTONV_PRIVATE_ROOT before retrying")
        end
        client = DeviceClient(private, state["system"])
        try
            # Wait for durable device creation before recording its existence.
            # A moved research workspace must never silently draw replacement truth.
            device_request!(client, Dict("action"=>"describe"))
            state["device_initialized"] = true
            save_campaign(path, state)
            device_acquire!(client, pending["id"], pending["experiments"])
        finally
            close(client)
        end
    else
        acquire(pending["id"], pending["experiments"])
    end
    length(observations) == length(pending["experiments"]) || error("Device returned wrong observation count")
    for (observation, experiment) in zip(observations, pending["experiments"])
        observation["experiment"] == experiment || error("Device experiment mismatch")
        observation["shots"] == experiment["shots"] || error("Device shot count mismatch")
        n, count = observation["shots"], observation["counts"]
        count isa Integer && 0 <= count <= n || error("Invalid device counts")
    end
    observations
end

"""Acquire exploratory counts. Repeat an interrupted call with the same experiments.

The persistent acquisition ID prevents duplicated measurement acquisition on retry.
These data may inform future candidates but are never reused as fresh validation.
"""
function campaign_acquire(path::AbstractString, experiments; acquire=nothing)
    with_campaign(path) do path, state
        validate_public_experiments(experiments, state["system"])
        isempty(experiments) && error("At least one experiment is required")
        if haskey(state, "pending")
            pending = state["pending"]
            pending["kind"] == "exploration" && pending["experiments"] == experiments ||
                error("An interrupted request is pending; repeat that original request first")
        else
            state["round"] += 1
            state["pending"] = Dict("kind"=>"exploration", "id"=>"exploration-$(state["round"])", "experiments"=>experiments)
        end
        state["stage"] = "acquire"
        state["status"] = "running"
        save_campaign(path, state)
        pending = state["pending"]
        observations = acquire_for_campaign(path, state, pending, acquire)
        record = Dict("kind"=>"exploration", "source_kind"=>"synthetic", "id"=>pending["id"], "observations"=>observations)
        push!(state["history"], record)
        pop!(state, "pending")
        state["stage"] = "idle"
        state["status"] = haskey(state, "validation") ? state["validation"]["status"] : "ready"
        save_campaign(path, state)
        record
    end
end

"""Import existing binary counts as exploratory evidence with explicit provenance.

Imported data can guide hypotheses. It is never silently treated as fresh held-out
validation. Hardware data remain labeled hardware; this version's validation device
is synthetic and cannot establish agreement with a physical device.
"""
function campaign_import(path::AbstractString, observations::AbstractVector;
                         source::AbstractString, source_kind::AbstractString="unknown")
    source_kind in ("synthetic", "hardware", "unknown") || error("source_kind must be synthetic, hardware or unknown")
    isempty(strip(source)) && error("A provenance source is required")
    with_campaign(path) do path, state
        isempty(observations) && error("At least one observation is required")
        for observation in observations
            Set(keys(observation)) == Set(["experiment", "counts", "shots"]) ||
                error("Each observation must contain only experiment, counts and shots")
            validate_public_experiments([observation["experiment"]], state["system"])
            n, count = observation["shots"], observation["counts"]
            n isa Integer && n > 0 && count isa Integer && 0 <= count <= n || error("Invalid imported counts")
            n == observation["experiment"]["shots"] || error("Imported shots disagree with experiment shots")
        end
        state["round"] += 1
        record = Dict("kind"=>"import", "id"=>"import-$(state["round"])", "source"=>source,
            "source_kind"=>source_kind, "use"=>"exploratory", "observations"=>observations)
        write_json_atomic(joinpath(path, "results", record["id"] * ".json"), record)
        push!(state["history"], record)
        save_campaign(path, state)
        record
    end
end

"""Freeze a candidate bundle, predict first, then acquire fresh validation counts.

Candidate `main.jl` defines `build_model()`. It executes only through the restricted
predictor subprocess. Return saved evidence for external human or agent review;
this function never calls an LLM. Repeat interrupted calls with the same arguments.
"""
function campaign_validate(path::AbstractString, bundle::AbstractString, experiments;
                           predictor=predict_bundle, acquire=nothing)
    with_campaign(path) do path, state
        validate_public_experiments(experiments, state["system"])
        isempty(experiments) && error("At least one experiment is required")
        candidate_id = bundle_hash(bundle)
        if haskey(state, "pending")
            pending = state["pending"]
            pending["kind"] == "validation" && pending["candidate_id"] == candidate_id &&
                pending["requested_experiments"] == experiments ||
                error("An interrupted request is pending; repeat its original bundle and experiments")
        else
            state["validation_attempt"] += 1
            pop!(state, "validation", nothing)
            pop!(state, "accepted_candidate", nothing)
            pop!(state, "accepted_evidence", nothing)
            k = state["validation_attempt"]
            frozen = joinpath(path, "validation", string(k), "candidate")
            mkpath(dirname(frozen))
            # Save the increment before copying so a failed copy never reuses an attempt directory.
            save_campaign(path, state)
            cp(abspath(bundle), frozen)
            bundle_hash(frozen) == candidate_id || error("Candidate changed while freezing")
            write_json_atomic(joinpath(dirname(frozen), "public-device.json"),
                Dict("system"=>state["system"], "description"=>description_to_dict(device_description(Symbol(state["system"])))))
            state["pending"] = Dict{String,Any}("kind"=>"validation", "id"=>"validation-$k", "bundle"=>frozen,
                "candidate_id"=>candidate_id, "requested_experiments"=>experiments,
                "experiments"=>validation_experiments(experiments, state))
            state["stage"] = "predict"
        end
        state["status"] = "running"
        save_campaign(path, state)
        pending = state["pending"]
        bundle_hash(pending["bundle"]) == candidate_id || error("Frozen candidate changed")
        if !haskey(pending, "predictions")
            try
                predictions = predictor(pending["bundle"], pending["experiments"], state["backend"])
                bundle_hash(pending["bundle"]) == candidate_id || error("Predictor modified frozen candidate")
                length(predictions) == length(pending["experiments"]) || throw(CandidateError("Wrong prediction count"))
                all(p->p isa Real && isfinite(p) && 0 <= p <= 1, predictions) || throw(CandidateError("Invalid probabilities"))
                pending["predictions"] = predictions
            catch exception
                if exception isa CandidateError
                    push!(state["history"], Dict("kind"=>"numerical_rejection", "candidate_id"=>candidate_id,
                        "attempt"=>state["validation_attempt"], "reason"=>sprint(showerror, exception)))
                    pop!(state, "pending")
                    state["status"] = "rejected"
                    state["stage"] = "idle"
                    save_campaign(path, state)
                    return last(state["history"])
                end
                rethrow()
            end
            # Predictions are committed before any fresh measurement request.
            state["stage"] = "acquire"
            save_campaign(path, state)
        end
        observations = acquire_for_campaign(path, state, pending, acquire)
        gate = validation_gate(pending["predictions"], observations; tolerance=state["tolerance"],
            alpha=state["alpha"], attempt=state["validation_attempt"])
        evidence = Dict{String,Any}("candidate_id"=>candidate_id, "attempt"=>state["validation_attempt"],
            "experiments"=>pending["experiments"], "predictions"=>pending["predictions"],
            "observations"=>observations, "gate"=>gate, "source_kind"=>"synthetic",
            "claim"=>"Predictive agreement with a synthetic device on tested experiments; no hardware or uniqueness claim.")
        numerical_path = joinpath(dirname(pending["bundle"]), "numerical.json")
        evidence["numerical"] = isfile(numerical_path) ? read_json(numerical_path) : Dict("source"=>"injected predictor")
        evidence["evidence_id"] = bytes2hex(SHA.sha256(JSON3.write(evidence)))
        write_json_atomic(joinpath(dirname(pending["bundle"]), "evidence.json"), evidence)
        status = gate["pass"] ? "awaiting_review" : "rejected"
        state["validation"] = Dict("bundle"=>pending["bundle"], "evidence"=>evidence,
            "reviews"=>Dict{String,Any}(), "status"=>status)
        push!(state["history"], Dict("kind"=>"validation", "evidence"=>evidence, "status"=>status))
        pop!(state, "pending")
        pop!(state, "accepted_candidate", nothing)
        pop!(state, "accepted_evidence", nothing)
        state["stage"] = "idle"
        state["status"] = status
        save_campaign(path, state)
        evidence
    end
end

"""Record an independently supplied physics/statistics review of exact frozen evidence.

The caller arranges independent reviewers. This tool records their judgments; it
cannot verify reviewer identity or independence. Both roles and the numeric gate
must approve the same candidate/evidence IDs before a run is marked accepted.
"""
function campaign_review(path::AbstractString, role::AbstractString, verdict::AbstractDict)
    role in ("physics", "statistics") || error("Review role must be physics or statistics")
    with_campaign(path) do path, state
        haskey(state, "pending") && error("Finish the pending acquisition before recording reviews")
        haskey(state, "validation") || error("No validation evidence is available")
        validation = state["validation"]
        evidence = validation["evidence"]
        candidate_id, evidence_id = evidence["candidate_id"], evidence["evidence_id"]
        bundle_hash(validation["bundle"]) == candidate_id || error("Frozen candidate changed")
        get(verdict, "candidate_id", "") == candidate_id && get(verdict, "evidence_id", "") == evidence_id ||
            error("Review IDs do not match current frozen candidate/evidence")
        get(verdict, "approve", nothing) isa Bool || error("Review approve must be boolean")
        get(verdict, "reason", nothing) isa AbstractString && !isempty(strip(verdict["reason"])) || error("Review reason is required")
        haskey(validation["reviews"], role) && error("This role already reviewed this evidence; validate fresh data for a new decision")
        validation["reviews"][role] = Dict(verdict)
        write_json_atomic(joinpath(dirname(validation["bundle"]), "review-$role.json"), verdict)
        accepted = evidence["gate"]["pass"] && all(haskey(validation["reviews"], r) &&
            review_approved(validation["reviews"][r], candidate_id, evidence_id) for r in ("physics", "statistics"))
        rejected = !evidence["gate"]["pass"] || any(!v["approve"] for v in values(validation["reviews"]))
        state["status"] = accepted ? "accepted" : rejected ? "rejected" : "awaiting_review"
        validation["status"] = state["status"]
        if accepted
            state["accepted_candidate"] = validation["bundle"]
            state["accepted_evidence"] = evidence_id
        end
        push!(state["history"], Dict("kind"=>"review", "role"=>role, "verdict"=>verdict, "status"=>state["status"]))
        save_campaign(path, state)
        state
    end
end
