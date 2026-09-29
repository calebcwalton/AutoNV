@testset "Predictive gate and alpha spending" begin
    observed = [Dict("shots"=>20_000, "counts"=>10_000)]
    gate = AutoNV.validation_gate([.5], observed)
    @test gate["pass"]
    @test !AutoNV.validation_gate([.6], observed)["pass"]
    @test AutoNV.validation_gate([.5], observed; attempt=2)["alpha_attempt"] ≈ .01/6
    @test sum(.01/(k*(k+1)) for k in 1:1000) < .01
    @test_throws ErrorException AutoNV.validation_gate([NaN], observed)
    @test_throws ErrorException AutoNV.validation_gate([.5], [Dict("shots"=>10, "counts"=>11)])
    @test !AutoNV.review_approved(Dict("approve"=>true), "a", "b")
    @test !AutoNV.review_approved(Dict("approve"=>true, "candidate_id"=>"wrong", "evidence_id"=>"b", "reason"=>"ok"), "a", "b")
end


scripted_observations(id, experiments) = [Dict("experiment"=>e, "shots"=>e["shots"],
    "counts"=>round(Int, .5e["shots"])) for e in experiments]

function test_campaign(directory)
    path = AutoNV.campaign_init(joinpath(directory, "run"); system="generic", backend="cpu")
    bundle = joinpath(directory, "candidate")
    mkpath(bundle)
    write(joinpath(bundle, "main.jl"), "build_model() = nothing # test predictor hook\n")
    experiments = [experiment_to_dict(ExperimentSpec("x+", [Evolution(.7)], "x", 10))]
    path, bundle, experiments
end
approval(e; approve=true) = Dict("approve"=>approve, "candidate_id"=>e["candidate_id"],
    "evidence_id"=>e["evidence_id"], "reason"=>"Independent test verdict")

@testset "Manual acquisition and validation with independent recorded reviews" begin
    mktempdir() do directory
        path, bundle, experiments = test_campaign(directory)
        acquisition = AutoNV.campaign_acquire(path, experiments; acquire=scripted_observations)
        @test acquisition["kind"] == "exploration"
        acquire = function(id, experiments)
            checkpoint = AutoNV.campaign_status(path)
            @test haskey(checkpoint["pending"], "predictions")
            @test experiments[1]["shots"] > 10
            scripted_observations(id, experiments)
        end
        e = AutoNV.campaign_validate(path, bundle, experiments;
            predictor=(b,e,k)->[.5], acquire)
        @test e["gate"]["pass"]
        @test AutoNV.campaign_status(path)["status"] == "awaiting_review"
        result = AutoNV.campaign_review(path, "physics", approval(e))
        @test result["status"] == "awaiting_review"
        result = AutoNV.campaign_review(path, "statistics", approval(e; approve=false))
        @test result["status"] == "rejected"
        e2 = AutoNV.campaign_validate(path, bundle, experiments;
            predictor=(b,e,k)->[.5], acquire)
        @test e2["attempt"] == 2
        @test e2["evidence_id"] != e["evidence_id"]
        @test_throws ErrorException AutoNV.campaign_review(path, "physics", approval(e))
        AutoNV.campaign_review(path, "physics", approval(e2))
        @test AutoNV.campaign_review(path, "statistics", approval(e2))["status"] == "accepted"
        @test !isdir(joinpath(path, "controller.lock"))
    end
end

@testset "Interrupted validation reuses frozen predictions and acquisition ID" begin
    mktempdir() do directory
        path, bundle, experiments = test_campaign(directory)
        calls = Ref(0)
        predictor = (b,e,k)->begin calls[] += 1; [.5] end
        @test_throws InterruptException AutoNV.campaign_validate(path, bundle, experiments;
            predictor, acquire=(id,e)->throw(InterruptException()))
        checkpoint = AutoNV.campaign_status(path)
        @test checkpoint["status"] == "interrupted"
        @test checkpoint["stage"] == "acquire"
        expected_id = checkpoint["pending"]["id"]
        acquire = (id,e)->begin @test id == expected_id; scripted_observations(id,e) end
        evidence = AutoNV.campaign_validate(path, bundle, experiments; predictor, acquire)
        @test evidence["gate"]["pass"]
        @test calls[] == 1
    end
end

@testset "Numerical failures reject before measurement" begin
    mktempdir() do directory
        path, bundle, experiments = test_campaign(directory)
        result = AutoNV.campaign_validate(path, bundle, experiments;
            predictor=(b,e,k)->throw(AutoNV.CandidateError("bad model")),
            acquire=(id,e)->error("must not acquire"))
        @test result["kind"] == "numerical_rejection"
        @test AutoNV.campaign_status(path)["status"] == "rejected"
        @test !haskey(AutoNV.campaign_status(path), "pending")
        invalid = deepcopy(experiments)
        invalid[1]["measurement"] = "unknown"
        @test_throws ErrorException AutoNV.campaign_acquire(path, invalid; acquire=scripted_observations)
    end
end

@testset "Bundle integrity and predictor recursion guard" begin
    mktempdir() do directory
        write(joinpath(directory, "main.jl"), "test")
        original = AutoNV.bundle_hash(directory)
        write(joinpath(directory, "helper.jl"), "helper")
        @test AutoNV.bundle_hash(directory) != original
        if !Sys.iswindows()
            symlink(joinpath(directory, "helper.jl"), joinpath(directory, "linked.jl"))
            @test_throws ErrorException AutoNV.bundle_hash(directory)
        end
        withenv("AUTONV_WORKER_ROLE"=>"prediction") do
            @test_throws ErrorException AutoNV.campaign_init(joinpath(directory, "nested"))
        end
    end
end

@testset "Device counts exclude hidden model parameters" begin
    experiments = [ExperimentSpec("z+", [], "z", 100)]
    device = AutoNV.SyntheticDevice(generic_qubit_model(), Random.Xoshiro(123))
    observations = AutoNV.execute(device, experiments)
    @test observations[1].counts == 100
    @test fieldnames(typeof(observations[1])) == (:experiment, :counts, :shots)
end

@testset "Private device location and bounded NV generation" begin
    mktempdir() do directory
        path = campaign_init(joinpath(directory, "workspace"); system="nv", backend="cpu")
        state = campaign_status(path)
        @test state["version"] == 2
        @test occursin(r"^[0-9a-f]{32}$", state["device_id"])
        @test !haskey(state, "seed") && !haskey(state, "parameters")
        withenv("AUTONV_PRIVATE_ROOT"=>joinpath(directory, "lab")) do
            private = AutoNV.private_device_directory(state)
            @test private == joinpath(directory, "lab", state["device_id"])
            # Inspect only test fixture truth, never a research device.
            config = AutoNV.private_device_config(private, "nv")
            @test all(bounds[1] <= config["parameters"][name] <= bounds[2]
                      for (name,bounds) in AutoNV.device_sampling_bounds())
            @test AutoNV.private_device_config(private, "nv") == config
            @test !isdir(joinpath(path, "private-device"))
            @test_throws ErrorException AutoNV.private_device_config(private, "generic")
        end
        invalid = deepcopy(state)
        invalid["device_id"] = "../escape"
        @test_throws ErrorException AutoNV.private_device_directory(invalid)
        @test_throws ErrorException AutoNV.private_device_directory(Dict("version"=>1))
        state["device_initialized"] = true
        withenv("AUTONV_PRIVATE_ROOT"=>joinpath(directory, "missing-lab")) do
            @test_throws ErrorException AutoNV.acquire_for_campaign(path, state,
                Dict("id"=>"retry", "experiments"=>Any[]), nothing)
        end
    end
    experiments = [ExperimentSpec("x+", [Evolution(.7)], "x", 100)]
    check = AutoNV.device_numerical_check(nv_model(), experiments)
    @test check["pass"]
    @test check["settings_checked"] == 1
    @test check["reference_method"] == "matrix_exponential"
    @test !haskey(check, "probabilities")
end

@testset "Imported data preserve provenance and remain exploratory" begin
    mktempdir() do directory
        path, bundle, experiments = test_campaign(directory)
        observations = scripted_observations("external", experiments)
        record = AutoNV.campaign_import(path, observations; source="instrument-export.json", source_kind="hardware")
        @test record["source_kind"] == "hardware"
        @test record["use"] == "exploratory"
        @test isfile(joinpath(path, "results", record["id"] * ".json"))
        @test all(isdir(joinpath(path, name)) for name in ("raw-data", "research", "results"))
        @test !haskey(AutoNV.campaign_status(path), "validation")
        evidence = AutoNV.campaign_validate(path, bundle, experiments;
            predictor=(b,e,k)->[.5], acquire=scripted_observations)
        @test evidence["source_kind"] == "synthetic"
        @test occursin("no hardware", evidence["claim"])
        bad = deepcopy(observations)
        bad[1]["counts"] = -1
        @test_throws ErrorException AutoNV.campaign_import(path, bad; source="bad")
    end
end
