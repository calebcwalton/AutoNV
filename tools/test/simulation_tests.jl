using Test, LinearAlgebra

@testset "Simulation physics and validation" begin
    m = generic_qubit_model(omega_x_mhz=.13,omega_y_mhz=-.08,omega_z_mhz=.31)
    ω = [.13,-.08,.31]
    n = ω/norm(ω)
    r0 = [0.,0.,1.]
    t = .71
    θ = 2π*norm(ω)*t
    r = r0*cos(θ) + cross(n,r0)*sin(θ) + n*dot(n,r0)*(1-cos(θ))
    for (j,axis) in enumerate(("x","y","z"))
        e = ExperimentSpec("z+",[Evolution(t)],axis,100)
        @test predict(m,e;backend=:cpu) ≈ (1+r[j])/2 atol=1e-8
        @test reference_predict(m,e) ≈ (1+r[j])/2 atol=1e-12
        @test experiment_to_dict(experiment_from_dict(experiment_to_dict(e))) == experiment_to_dict(e)
    end
    exps = default_experiments(:generic;shots=100)
    @test predict_batch(m,exps;backend=:cpu) ≈ predict_batch(m,exps;backend=:cpu,threaded=false) atol=1e-12
    @test predict_batch(m,exps;backend=:cpu) ≈ reference_predict_batch(m,exps) atol=1e-8
    @test resolve_backend(:auto) in (:cpu,:cuda)
    @test_throws ArgumentError resolve_backend(:other)
    if !AutoNV._cuda_available()
        @test_throws ArgumentError resolve_backend(:cuda)
        @test_skip "CUDA parity requires a functional CUDA device"
    else
        @test predict_batch(m,exps;backend=:cuda) ≈ predict_batch(m,exps;backend=:cpu) atol=1e-8
    end
    @test_throws ArgumentError Evolution(-1)
    @test_throws ArgumentError Pulse("x",NaN)
    @test_throws ArgumentError ExperimentSpec("z+",[],"z",0)
    @test_throws ArgumentError predict(m,ExperimentSpec("unknown",[],"z"))
    @test_throws ArgumentError validate_model(m;max_memory_bytes=1)
    # A huge structured operator must be refused before any dense allocation.
    @test_throws ArgumentError ModelSpec(Diagonal(zeros(100_000));preparations=Dict(),controls=Dict(),measurements=Dict())
    @test_throws ArgumentError ModelSpec([0 1;0 0];preparations=m.preparations,controls=m.controls,measurements=m.measurements)
    @test_throws ArgumentError ModelSpec(m.H;preparations=Dict("bad"=>[2 0;0 -1]),controls=m.controls,measurements=m.measurements)
    @test_throws ArgumentError ModelSpec(m.H;preparations=m.preparations,controls=m.controls,measurements=Dict("bad"=>[2 0;0 0]))
    no_drift = generic_qubit_model(omega_x_mhz=0,omega_y_mhz=0,omega_z_mhz=0)
    e = ExperimentSpec("z+",[Evolution(.5;controls=Dict("x"=>π))],"z",100)
    @test predict(no_drift,e) ≈ 0 atol=1e-8
    @test predict(no_drift,ExperimentSpec("z+",[Pulse("x",π)],"z")) ≈ 0 atol=1e-12
    # Analytic amplitude damping: excited-state population decays as exp(-γt).
    damped = ModelSpec(no_drift.H;preparations=m.preparations,controls=m.controls,measurements=m.measurements,
        collapse_operators=[sqrt(.4)*ComplexF64[0 1;0 0]])
    @test predict(damped,ExperimentSpec("z-",[Evolution(2.)],"z")) ≈ 1-exp(-.8) atol=1e-8
    obs = [Observation(ExperimentSpec("z+",[],"z",10),7)]
    @test score([.7],obs).residuals == [0.]
    @test score([0.],obs).loglikelihood == -Inf
end

@testset "Effective NV conditional dynamics" begin
    # No hyperfine coupling: the nucleus factors out; Hahn echo cancels detuning.
    uncoupled = nv_model(detuning_mhz=.17,a_parallel_mhz=0,a_perp_mhz=0)
    for t in (.2,1.,3.)
        @test predict(uncoupled,ExperimentSpec("x+",[Evolution(t)],"x")) ≈ (1+cos(2π*.17*t))/2 atol=1e-8
        @test predict(uncoupled,ExperimentSpec("x+",[Evolution(t/2),Pulse("x",π),Evolution(t/2)],"x")) ≈ 1 atol=1e-8
    end
    δ,ω,a,b = .03,.5,.08,.12
    m = nv_model(detuning_mhz=δ,omega_l_mhz=ω,a_parallel_mhz=a,a_perp_mhz=b)
    X = ComplexF64[0 1;1 0]; Z = ComplexF64[1 0;0 -1]
    # Independent 2x2 conditional propagators, not the full model Hamiltonian.
    h0 = 2π*ω*Z/2
    h1 = 2π*((ω-a)*Z-b*X)/2
    for t in (.3,1.2,4.)
        u0,u1 = exp(-im*h0*t),exp(-im*h1*t)
        coherence = exp(-2π*im*δ*t)*tr(u0*u1')/2
        @test predict(m,ExperimentSpec("x+",[Evolution(t)],"x")) ≈ (1+real(coherence))/2 atol=2e-8
        v0,v1 = exp(-im*h0*t/2),exp(-im*h1*t/2)
        echo = tr((v1*v0)*(v0*v1)')/2
        @test predict(m,ExperimentSpec("x+",[Evolution(t/2),Pulse("x",π),Evolution(t/2)],"x")) ≈ (1+real(echo))/2 atol=2e-8
    end
    cpmg = AutoNV.cpmg_operations(4.,4)
    @test sum(op.duration_us for op in cpmg if op isa Evolution) == 4.
    @test count(op->op isa Pulse,cpmg) == 4
    @test predict(uncoupled,ExperimentSpec("x+",cpmg,"x")) ≈ 1 atol=1e-8
    @test predict_batch(m,default_experiments(:nv)) ≈ reference_predict_batch(m,default_experiments(:nv)) atol=2e-8
end
