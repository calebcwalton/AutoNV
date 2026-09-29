"""Read system-relevant skill entrypoints for the user's existing agent session."""
function skill_context(system::AbstractString)
    registry = TOML.parsefile(joinpath(PACKAGE_ROOT, "skills", "systems.toml"))
    haskey(registry, system) || throw(ArgumentError("unknown system: $system"))
    parts = String[]
    for name in registry[system]["skills"]
        path = joinpath(PACKAGE_ROOT, "skills", name, "SKILL.md")
        body = read(path, String)
        push!(parts, "Skill: $name\nSource: $path\nSHA256: $(bytes2hex(sha256(body)))\n\n$body")
    end
    return join(parts, "\n\n---\n\n")
end

"""Load optional CUDA only when requested/available, leaving CPU installs independent."""
function enable_cuda!(backend)
    backend = Symbol(backend)
    backend in (:cpu, :auto, :cuda) || throw(ArgumentError("backend must be auto, cpu, or cuda"))
    backend == :cpu && return
    if Base.find_package("CUDA") !== nothing
        try
            Base.eval(Main, :(using CUDA))
        catch err
            backend == :cuda && rethrow()
            @warn "CUDA could not load; using CPU" exception=err
        end
    elseif backend == :cuda
        error("CUDA is not installed in this environment. See docs/cuda.md.")
    end
end

function active_project_dir()
    # Resolve before a child switches to its sandbox working directory.
    return abspath(get(ENV, "AUTONV_PROJECT", PACKAGE_ROOT))
end

"""Construct a subprocess command without invoking a shell."""
function julia_script(script, args...)
    return `$(Base.julia_cmd()) --startup-file=no --project=$(active_project_dir()) $(joinpath(PACKAGE_ROOT, "scripts", script)) $args`
end

launch_device(private_dir, system) = julia_script("device.jl", abspath(private_dir), system)

function demonstration(system)
    model = system == "generic" ? generic_qubit_model() :
            system == "nv" ? nv_model() : throw(ArgumentError("unknown system: $system"))
    return model, default_experiments(system)
end

"""Use Codex's OS sandbox; never fall back to unrestricted execution."""
function sandbox_command(command::Cmd, workspace::AbstractString)
    executable = Sys.which("codex")
    executable === nothing && error("Codex CLI is required for restricted code execution.")
    workspace = realpath(workspace)
    # Explicit custom profile avoids inheriting extra writable workspace roots.
    # Pass special-token keys inside a TOML table, not as dotted override keys:
    # Codex's dotted override parser treats quotes in those keys literally.
    rules = ["permissions.autonv={extends=\":read-only\",filesystem={\":workspace_roots\"=\"write\"},network={enabled=false}}"]
    config = reduce(vcat, [["-c", r] for r in rules])
    return `$executable sandbox -P autonv $config -C $workspace $command`
end

"""Verify permitted workspace writes, denied sibling writes, and denied socket binding."""
function ensure_sandbox!()
    mktempdir() do parent
        workspace = joinpath(parent, "workspace")
        mkpath(workspace)
        forbidden = joinpath(parent, "forbidden.txt")
        command = `$(Base.julia_cmd()) --startup-file=no $(joinpath(PACKAGE_ROOT,"scripts","sandbox_probe.jl")) $workspace $forbidden`
        run(sandbox_command(command, workspace))
        isfile(joinpath(workspace, "allowed.txt")) || error("sandbox could not write inside workspace")
        !isfile(forbidden) || error("sandbox allowed writing outside workspace")
    end
    true
end

"""Run a frozen candidate in isolation and return checked probabilities."""
function predict_bundle(bundle, experiments, backend)
    # The evaluation scratch directory is separate from the immutable bundle.
    scratch = mktempdir(dirname(bundle); prefix="evaluation-")
    input = joinpath(scratch, "experiments.json")
    output = joinpath(scratch, "predictions.json")
    write(input, JSON3.write(experiments))
    description = read_json(joinpath(dirname(bundle), "public-device.json"))
    command = julia_script("predict.jl", abspath(bundle), input, output, String(backend), description["system"])
    sandboxed = sandbox_command(command, scratch)
    # First depot is writable for Julia's caches, other depots remain readable.
    depot = joinpath(scratch, "julia-depot")
    mkpath(depot)
    sandboxed = addenv(sandboxed, "JULIA_DEPOT_PATH" => join([depot; DEPOT_PATH], Sys.iswindows() ? ';' : ':'),
                       "AUTONV_WORKER_ROLE" => "prediction", "AUTONV_WORKER" => "1",
                       "JULIA_PKG_PRECOMPILE_AUTO" => "0")
    open(joinpath(scratch, "stderr.log"), "w") do log
        try
            run(pipeline(sandboxed; stdout=log, stderr=log))
        catch err
            err isa InterruptException && rethrow()
            # ProcessFailedException renders the command's entire environment.
            # Retain diagnostics in the log without leaking inherited secrets.
            error("Restricted prediction process failed; see $(joinpath(scratch, "stderr.log")). No unsandboxed retry was attempted.")
        end
    end
    isfile(output) || throw(CandidateError("candidate produced no prediction file; see $scratch"))
    result = JSON3.read(read(output, String), Dict{String,Any})
    get(result, "checked", false) === true || throw(CandidateError(string(get(result, "error", "candidate numerical checks did not pass"))))
    probabilities = Float64.(result["probabilities"])
    length(probabilities) == length(experiments) || throw(CandidateError("candidate returned the wrong number of predictions"))
    all(p -> isfinite(p) && 0 <= p <= 1, probabilities) || throw(CandidateError("candidate returned invalid probabilities"))
    write_json_atomic(joinpath(dirname(bundle), "numerical.json"), result)
    return probabilities
end

"""Check the v1 known-calibration assumption independently of candidate drift."""
function check_calibration(model::ModelSpec, system)
    calibration, _ = demonstration(system)
    size(model.H) == size(calibration.H) || throw(ArgumentError("candidate changes the known system dimension"))
    for field in (:preparations, :controls, :measurements)
        candidate, expected = getfield(model, field), getfield(calibration, field)
        Set(keys(candidate)) == Set(keys(expected)) || throw(ArgumentError("candidate changes calibrated $field names"))
        all(isapprox(candidate[k], expected[k]; atol=1e-10, rtol=1e-10) for k in keys(expected)) ||
            throw(ArgumentError("candidate changes calibrated $field operators"))
    end
    true
end

"""Print local runtime capabilities; optionally verify OS sandbox startup."""
function doctor(; sandbox_check=false)
    report = Dict{String,Any}("julia" => string(VERSION), "project" => active_project_dir(),
        "quantumtoolbox" => string(pkgversion(QuantumToolbox)),
        "cpu_threads" => Threads.nthreads(), "codex" => Sys.which("codex"),
        "cuda_package_installed" => Base.find_package("CUDA") !== nothing)
    if Sys.which("codex") !== nothing
        report["codex_version"] = strip(read(`codex --version`, String))
    end
    if sandbox_check
        try
            ensure_sandbox!()
            report["sandbox"] = "write and network restrictions verified"
        catch err
            report["sandbox"] = "unavailable: $(sprint(showerror, err))"
        end
    end
    println(JSON3.write(report))
    return report
end

const CLI_HELP = """
AutoNV — quantum modeling tools for your existing Codex session

  autonv doctor [--sandbox-check]
  autonv skills [--system nv|generic]
  autonv init PATH [--system nv|generic] [--backend auto|cpu|cuda]
  autonv import PATH OBSERVATIONS.json --source NAME [--source-kind unknown|synthetic|hardware]
  autonv acquire PATH EXPERIMENTS.json
  autonv validate PATH CANDIDATE_DIRECTORY EXPERIMENTS.json
  autonv review PATH physics|statistics VERDICT.json
  autonv status PATH
  autonv simulate --system nv|generic [--backend auto|cpu|cuda] [--output FILE]

No model requests or automatic agent loop. Propose tests through Codex directly.
Repeat interrupted acquire/validate commands with the same arguments to resume.
"""

function parse_cli(args)
    positional = String[]
    options = Dict{String,String}()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--sandbox-check"
            options["sandbox-check"] = "true"
        elseif startswith(arg, "--")
            key = arg[3:end]
            key in ("system", "backend", "output", "tolerance", "alpha", "source", "source-kind") || error("unknown option: $arg")
            i += 1
            i <= length(args) || error("missing value for $arg")
            options[key] = args[i]
        else
            push!(positional, arg)
        end
        i += 1
    end
    return positional, options
end

"""CLI entrypoint. Scientific functions remain callable without the CLI or an LLM."""
function main(args=ARGS)
    if isempty(args) || args[1] in ("help", "--help", "-h")
        print(CLI_HELP)
        return 0
    end
    command, rest = args[1], args[2:end]
    positional, options = parse_cli(rest)
    system = get(options, "system", "nv")
    backend = get(options, "backend", "auto")
    if command == "doctor"
        report = doctor(; sandbox_check=haskey(options, "sandbox-check"))
        startswith(get(report, "sandbox", ""), "unavailable") && return 1
    elseif command == "skills"
        println(skill_context(system))
    elseif command in ("init", "status")
        length(positional) == 1 || error("$command requires a campaign directory")
        path = abspath(only(positional))
        if command == "status"
            println(JSON3.write(campaign_status(path)))
        else
            campaign_init(path; system, backend,
                tolerance=parse(Float64, get(options, "tolerance", "0.05")),
                alpha=parse(Float64, get(options, "alpha", "0.01")))
            println("Workspace created: $path")
        end
    elseif command == "import"
        length(positional) == 2 || error("import requires a campaign directory and observations JSON file")
        haskey(options, "source") || error("import requires --source identifying the data origin")
        observations = JSON3.read(read(positional[2], String), Vector{Dict{String,Any}})
        record = campaign_import(positional[1], observations; source=options["source"],
            source_kind=get(options, "source-kind", "unknown"))
        println(JSON3.write(record))
    elseif command == "acquire"
        length(positional) == 2 || error("acquire requires a campaign directory and experiments JSON file")
        experiments = JSON3.read(read(positional[2], String), Vector{Dict{String,Any}})
        println(JSON3.write(campaign_acquire(positional[1], experiments)))
    elseif command == "validate"
        length(positional) == 3 || error("validate requires a campaign directory, candidate directory, and experiments JSON file")
        experiments = JSON3.read(read(positional[3], String), Vector{Dict{String,Any}})
        println(JSON3.write(campaign_validate(positional[1], positional[2], experiments)))
    elseif command == "review"
        length(positional) == 3 || error("review requires a campaign directory, role, and verdict JSON file")
        println(JSON3.write(campaign_review(positional[1], positional[2], read_json(positional[3]))))
    elseif command == "simulate"
        enable_cuda!(backend)
        model, experiments = demonstration(system)
        # Loading CUDA above can activate new extension methods in this call.
        probabilities = Base.invokelatest(predict_batch, model, experiments; backend=Symbol(backend))
        result = Dict("system" => system, "synthetic" => true,
                      "metadata" => Base.invokelatest(simulation_metadata; backend=Symbol(backend)),
                      "probabilities" => probabilities,
                      "experiments" => experiment_to_dict.(experiments))
        output = get(options, "output", "")
        isempty(output) ? println(JSON3.write(result)) : write(output, JSON3.write(result))
    else
        error("unknown command '$command'; run autonv --help")
    end
    return 0
end
