@testset "Skill routing and CLI" begin
    generic = AutoNV.skill_context("generic")
    nv = AutoNV.skill_context("nv")
    @test occursin("Quantum research", generic)
    @test !occursin("# NV modeling", generic)
    @test occursin("# NV modeling", nv)
    @test occursin("# AutoNV workspace research", nv)
    @test occursin("SHA256:", nv)
    @test_throws ArgumentError AutoNV.skill_context("missing")
    @test_throws ErrorException AutoNV.parse_cli(["--invalid"])
    @test_throws ErrorException AutoNV.parse_cli(["--backend"])
    args, options = AutoNV.parse_cli(["run", "--backend", "cpu"])
    @test args == ["run"]
    @test options["backend"] == "cpu"
    @test AutoNV.main(["--help"]) == 0
    withenv("AUTONV_PROJECT"=>"tools") do
        @test isabspath(AutoNV.active_project_dir())
    end
    mktempdir() do workspace
        command = AutoNV.sandbox_command(`echo test`, workspace)
        @test "autonv" in command.exec
        @test !any(occursin("danger", word) for word in command.exec)
    end
end

@testset "Fixed preparation and readout calibration" begin
    @test AutoNV.check_calibration(generic_qubit_model(), "generic")
    @test AutoNV.check_calibration(nv_model(), "nv")
    @test_throws ArgumentError AutoNV.check_calibration(nv_model(), "generic")
    model = generic_qubit_model()
    model.measurements["x"] .= 0
    @test_throws ArgumentError AutoNV.check_calibration(model, "generic")
end
