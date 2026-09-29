# Run explicitly from a normal terminal; nested macOS sandboxes cannot start.
# This test invokes the local sandbox utility, never an LLM.
using Test, AutoNV, JSON3

@testset "Real sandbox and candidate/device subprocesses" begin
    @test AutoNV.ensure_sandbox!()
    mktempdir() do root
      withenv("AUTONV_PRIVATE_ROOT"=>joinpath(root, "private-devices")) do
        campaign = joinpath(root, "campaign")
        campaign_init(campaign; system="generic", backend="cpu")
        bundle = joinpath(campaign, "research", "candidate")
        cp(joinpath(AutoNV.PACKAGE_ROOT, "examples", "generic"), bundle)
        exps = experiment_to_dict.(default_experiments("generic")[1:3])
        evidence = campaign_validate(campaign, bundle, exps)
        haskey(evidence, "numerical") || error("unexpected candidate rejection: $evidence")
        @test evidence["numerical"]["checked"]
        @test evidence["numerical"]["metadata"]["backend"] == "cpu"
        @test evidence["numerical"]["reference_method"] == "matrix_exponential"
        @test length(evidence["observations"]) == 3
        @test all(o["counts"] <= o["shots"] for o in evidence["observations"])
        @test evidence["source_kind"] == "synthetic"
        state = campaign_status(campaign)
        @test state["device_initialized"]
        private = AutoNV.private_device_directory(state)
        @test isfile(joinpath(private, "device.json"))
        @test !isdir(joinpath(campaign, "private-device"))
        client = AutoNV.DeviceClient(private, "generic")
        first_counts = try
            @test AutoNV.device_check!(client, exps)["pass"]
            AutoNV.device_acquire!(client, "repeat-test", exps)
        finally
            close(client)
        end
        client = AutoNV.DeviceClient(private, "generic")
        try
            @test AutoNV.device_acquire!(client, "repeat-test", exps) == first_counts
        finally
            close(client)
        end

        # A physically allowed POVM still cannot replace a calibrated measurement.
        write(joinpath(bundle, "main.jl"), """
        using AutoNV
        function build_model()
            model = generic_qubit_model()
            model.measurements["x"] .= 0
            model
        end
        """)
        rejected = campaign_validate(campaign, bundle, exps)
        @test rejected["kind"] == "numerical_rejection"
        @test occursin("calibrated", rejected["reason"])
        @test campaign_status(campaign)["status"] == "rejected"
      end
    end
end
