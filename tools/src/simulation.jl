"""A constant evolution interval, in microseconds; control amplitudes are radians/μs."""
struct Evolution
    duration_us::Float64
    controls::Dict{String,Float64}
    function Evolution(duration_us::Real; controls=Dict{String,Float64}())
        isfinite(duration_us) && duration_us >= 0 || throw(ArgumentError("duration must be finite and nonnegative"))
        c = Dict{String,Float64}(string(k)=>Float64(v) for (k,v) in pairs(controls))
        all(isfinite, values(c)) || throw(ArgumentError("control amplitudes must be finite"))
        new(Float64(duration_us), c)
    end
end

"""Instantaneous calibrated rotation exp(-i angle_rad control/2)."""
struct Pulse
    axis::String
    angle_rad::Float64
    function Pulse(axis::AbstractString, angle_rad::Real)
        isfinite(angle_rad) || throw(ArgumentError("pulse angle must be finite"))
        new(String(axis), Float64(angle_rad))
    end
end

"""Preparation, ordered operations, binary positive-outcome measurement and shot count."""
struct ExperimentSpec
    preparation::String
    operations::Vector{Union{Evolution,Pulse}}
    measurement::String
    shots::Int
    function ExperimentSpec(preparation, operations, measurement, shots=1000)
        shots isa Integer && 0 < shots <= 100_000_000 || throw(ArgumentError("shots must be an integer in 1:100000000"))
        new(String(preparation), Union{Evolution,Pulse}[operations...], String(measurement), Int(shots))
    end
end

"""Public calibrated capabilities. Times use μs, input frequencies MHz, and angles radians."""
struct DeviceDescription
    name::String
    preparations::Vector{String}
    controls::Vector{String}
    measurements::Vector{String}
    max_duration_us::Float64
end

description_to_dict(d::DeviceDescription) = Dict("name"=>d.name, "preparations"=>d.preparations,
    "controls"=>d.controls,"measurements"=>d.measurements,"max_duration_us"=>d.max_duration_us,
    "units"=>Dict("time"=>"microsecond","frequency"=>"MHz","hamiltonian"=>"radian/microsecond","angle"=>"radian"))

"""Binary counts from a single experiment; no hidden probability is stored."""
struct Observation
    experiment::ExperimentSpec
    counts::Int
    shots::Int
    function Observation(experiment::ExperimentSpec, counts::Integer, shots::Integer=experiment.shots)
        0 <= counts <= shots && shots > 0 || throw(ArgumentError("invalid counts or shots"))
        shots == experiment.shots || throw(ArgumentError("observation shots differ from experiment"))
        new(experiment, Int(counts), Int(shots))
    end
end

_dense(A::AbstractMatrix) = Matrix{ComplexF64}(A)
_dense(A) = Matrix{ComplexF64}(A.data)

"""Finite-dimensional drift Hamiltonian (radians/μs), calibrated operators and density matrices.
Collapse operators have units 1/√μs. Controls generate pulses as exp(-i θ C/2),
while Evolution control amplitudes multiply C directly. Inputs are copied and validated.
"""
struct ModelSpec
    H::Matrix{ComplexF64}
    preparations::Dict{String,Matrix{ComplexF64}}
    controls::Dict{String,Matrix{ComplexF64}}
    measurements::Dict{String,Matrix{ComplexF64}}
    collapse_operators::Vector{Matrix{ComplexF64}}
    label::String
    function ModelSpec(H; preparations, controls, measurements, collapse_operators=[], label="candidate")
        n = size(H,1)
        n > 0 && size(H,2) == n || throw(ArgumentError("Hamiltonian must be square"))
        16 * big(n)^4 * 12 <= 512*1024^2 || throw(ArgumentError("estimated solver memory exceeds limit"))
        for A in (values(preparations)..., values(controls)..., values(measurements)..., collapse_operators...)
            size(A) == (n,n) || throw(ArgumentError("operators must have matching dimensions"))
        end
        m = new(_dense(H), Dict(string(k)=>_dense(v) for (k,v) in pairs(preparations)),
            Dict(string(k)=>_dense(v) for (k,v) in pairs(controls)),
            Dict(string(k)=>_dense(v) for (k,v) in pairs(measurements)),
            [_dense(c) for c in collapse_operators], String(label))
        validate_model(m)
        m
    end
end

"""Validate dimensions, Hermiticity, positive density matrices and binary POVM effects."""
function validate_model(m::ModelSpec; max_memory_bytes::Integer=512*1024^2)
    n = size(m.H,1)
    n > 0 && size(m.H,2) == n || throw(ArgumentError("Hamiltonian must be square"))
    # A dense Liouvillian and its solver work arrays dominate memory use.
    16 * big(n)^4 * 12 <= max_memory_bytes || throw(ArgumentError("estimated solver memory exceeds limit"))
    isempty(m.preparations) && throw(ArgumentError("at least one preparation is required"))
    isempty(m.measurements) && throw(ArgumentError("at least one measurement is required"))
    for A in (m.H, values(m.preparations)..., values(m.controls)..., values(m.measurements)..., m.collapse_operators...)
        size(A) == (n,n) && all(isfinite,A) || throw(ArgumentError("operators must have finite matching dimensions"))
    end
    for A in (m.H, values(m.preparations)..., values(m.controls)..., values(m.measurements)...)
        isapprox(A,A';atol=1e-10,rtol=1e-10) || throw(ArgumentError("Hamiltonian, controls, states and effects must be Hermitian"))
    end
    for ρ in values(m.preparations)
        isapprox(tr(ρ),1;atol=1e-10) && minimum(eigvals(Hermitian(ρ))) >= -1e-10 || throw(ArgumentError("preparations must be density matrices"))
    end
    for E in values(m.measurements)
        λ = eigvals(Hermitian(E))
        minimum(λ) >= -1e-10 && maximum(λ) <= 1+1e-10 || throw(ArgumentError("measurement effects must lie between zero and identity"))
    end
    true
end

function experiment_to_dict(e::ExperimentSpec)
    ops = [op isa Evolution ? Dict("kind"=>"evolve","duration_us"=>op.duration_us,"controls"=>op.controls) :
        Dict("kind"=>"pulse","axis"=>op.axis,"angle_rad"=>op.angle_rad) for op in e.operations]
    Dict("preparation"=>e.preparation,"operations"=>ops,"measurement"=>e.measurement,"shots"=>e.shots)
end
function experiment_from_dict(d)
    ops = Union{Evolution,Pulse}[]
    for op in d["operations"]
        kind = op["kind"]
        push!(ops, kind == "evolve" ? Evolution(op["duration_us"]; controls=get(op,"controls",Dict())) :
            kind == "pulse" ? Pulse(op["axis"],op["angle_rad"]) : throw(ArgumentError("unknown operation: $kind")))
    end
    ExperimentSpec(d["preparation"],ops,d["measurement"],get(d,"shots",1000))
end

_cuda_available() = Base.get_extension(@__MODULE__, :AutoNVCUDAExt) !== nothing && _cuda_available(Val(:loaded))
_cuda_available(::Val) = false
_cuda_transfer(A) = throw(ArgumentError("CUDA extension is not loaded; install CUDA and run using CUDA"))
_cuda_sync() = Base.get_extension(@__MODULE__, :AutoNVCUDAExt) === nothing ? nothing : _cuda_sync(Val(:loaded))
_cuda_sync(::Val) = nothing
"""Resolve :auto, :cpu or :cuda; CUDA is optional and must be loaded with `using CUDA`."""
function resolve_backend(backend=:auto)
    b = Symbol(backend)
    b in (:auto,:cpu,:cuda) || throw(ArgumentError("backend must be auto, cpu or cuda"))
    b == :auto && return _cuda_available() ? :cuda : :cpu
    b == :cuda && !_cuda_available() && throw(ArgumentError("CUDA requested but no functional CUDA device/extension is available"))
    b
end

"""Numerical settings and actual selected backend for reproducible result records."""
simulation_metadata(;backend=:auto,abstol=1e-10,reltol=1e-9) = Dict(
    "backend"=>string(resolve_backend(backend)),"precision"=>"ComplexF64","abstol"=>abstol,"reltol"=>reltol,
    "julia_version"=>string(VERSION),"quantumtoolbox_version"=>string(pkgversion(QuantumToolbox)),"threads"=>Threads.nthreads())

function _experiment_check(m,e)
    haskey(m.preparations,e.preparation) || throw(ArgumentError("unknown preparation: $(e.preparation)"))
    haskey(m.measurements,e.measurement) || throw(ArgumentError("unknown measurement: $(e.measurement)"))
    sum((op.duration_us for op in e.operations if op isa Evolution);init=0.0) <= 1e6 || throw(ArgumentError("experiment exceeds 1000000 μs"))
    for op in e.operations
        names = op isa Pulse ? (op.axis,) : keys(op.controls)
        all(k->haskey(m.controls,k),names) || throw(ArgumentError("unknown control axis"))
    end
end
function _hamiltonian(m,op::Evolution)
    H = copy(m.H)
    for (k,a) in op.controls
        H .+= a .* m.controls[k]
    end
    H
end
function _probability(z)
    isfinite(z) && abs(imag(z)) < 1e-7 && -1e-7 <= real(z) <= 1+1e-7 || error("invalid simulated probability: $z")
    clamp(real(z),0.0,1.0)
end

"""Predict one binary probability with QuantumToolbox master-equation evolution."""
function predict(m::ModelSpec,e::ExperimentSpec;backend=:auto,abstol=1e-10,reltol=1e-9,max_memory_bytes=512*1024^2)
    validate_model(m;max_memory_bytes)
    _experiment_check(m,e)
    b = resolve_backend(backend)
    transfer(A) = b == :cuda ? _cuda_transfer(A) : A
    ρ = Qobj(transfer(m.preparations[e.preparation]))
    cs = [Qobj(c) for c in m.collapse_operators]
    for op in e.operations
        if op isa Pulse
            U = Qobj(transfer(exp(-0.5im*op.angle_rad*m.controls[op.axis])))
            ρ = U*ρ*U'
        elseif op.duration_us > 0
            H = Qobj(_hamiltonian(m,op))
            c_ops = isempty(cs) ? nothing : cs
            if b == :cuda
                # Assemble the small superoperator on CPU. This avoids mixed
                # FillArrays identity/CuArray Kronecker products in dense models;
                # all ODE state evolution and matrix products remain on the GPU.
                L = liouvillian(H,c_ops)
                H = Qobj(transfer(Matrix(L.data));type=SuperOperator())
                c_ops = nothing
            end
            sol = mesolve(H,ρ,[0.0,op.duration_us],c_ops;
                progress_bar=false,abstol,reltol,saveat=[op.duration_us])
            SciMLBase.successful_retcode(sol.retcode) || error("evolution failed: $(sol.retcode)")
            ρ = sol.states[end]
        end
    end
    isapprox(tr(ρ), 1; atol=1e-7, rtol=1e-7) || error("evolved state lost normalization")
    E = Qobj(transfer(m.measurements[e.measurement]))
    _probability(expect(E,ρ))
end

"""Predict independent experiments in parallel, preserving input order.
CPU execution uses Julia threads. CUDA execution uses at most gpu_concurrency tasks,
each with its own CUDA stream; tiny NV systems generally run faster on CPU.
"""
function predict_batch(m::ModelSpec, experiments;backend=:auto,threaded=true,gpu_concurrency=2,kwargs...)
    b = resolve_backend(backend)
    exps = collect(experiments)
    out = Vector{Float64}(undef,length(exps))
    if b == :cuda
        gpu_concurrency > 0 || throw(ArgumentError("gpu_concurrency must be positive"))
        @sync for worker in 1:min(gpu_concurrency,length(exps))
            @async begin
                for i in worker:gpu_concurrency:length(exps)
                    out[i] = predict(m,exps[i];backend=b,kwargs...)
                    _cuda_sync()
                end
            end
        end
    elseif threaded
        Threads.@threads for i in eachindex(exps)
            out[i] = predict(m,exps[i];backend=b,kwargs...)
        end
    else
        for i in eachindex(exps)
            out[i] = predict(m,exps[i];backend=b,kwargs...)
        end
    end
    out
end

"""Independent dense-exponential reference (tighter CPU solve for dissipative models)."""
function reference_predict(m::ModelSpec,e::ExperimentSpec)
    validate_model(m)
    _experiment_check(m,e)
    isempty(m.collapse_operators) || return predict(m,e;backend=:cpu,abstol=1e-12,reltol=1e-11)
    ρ = copy(m.preparations[e.preparation])
    for op in e.operations
        U = op isa Pulse ? exp(-0.5im*op.angle_rad*m.controls[op.axis]) : exp(-im*op.duration_us*_hamiltonian(m,op))
        ρ = U*ρ*U'
    end
    _probability(tr(m.measurements[e.measurement]*ρ))
end
reference_predict_batch(m,experiments) = [reference_predict(m,e) for e in experiments]

"""Binomial log likelihood (including combinatorial factors) and count-frequency residuals."""
function score(predictions, observations::AbstractVector{Observation})
    length(predictions) == length(observations) || throw(DimensionMismatch("one prediction is required per observation"))
    ll = 0.0
    residuals = Float64[]
    for (p,o) in zip(predictions,observations)
        isfinite(p) && 0 <= p <= 1 || throw(ArgumentError("invalid probability"))
        ll += Distributions.logpdf(Distributions.Binomial(o.shots,p),o.counts)
        push!(residuals,o.counts/o.shots-p)
    end
    (loglikelihood=ll,residuals=residuals)
end
