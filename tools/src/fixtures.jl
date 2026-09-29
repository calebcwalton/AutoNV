# Basis convention: electron |0>, |1> (NV ms=0, -1), then nuclear |up>, |down>.
const _NV_I = ComplexF64[1 0;0 1]
const _NV_X = ComplexF64[0 1;1 0]
const _NV_Y = ComplexF64[0 -im;im 0]
const _NV_Z = ComplexF64[1 0;0 -1]

function _calibrated_qubit(nuclear=false)
    paulis = Dict("x"=>_NV_X,"y"=>_NV_Y,"z"=>_NV_Z)
    preps = Dict(axis*sign=> (_NV_I + (sign == "+" ? 1 : -1)*P)/2 for (axis,P) in paulis for sign in ("+","-"))
    effects = Dict(axis=>(_NV_I+P)/2 for (axis,P) in paulis)
    nuclear || return preps,paulis,effects
    # Unpolarized carbon: electron preparation never implies nuclear preparation.
    Dict(k=>kron(v,_NV_I/2) for (k,v) in preps),
        Dict(k=>kron(v,_NV_I) for (k,v) in paulis),Dict(k=>kron(v,_NV_I) for (k,v) in effects)
end

"""Qubit H = 2π(ωx X + ωy Y + ωz Z)/2, with input frequencies in MHz."""
function generic_qubit_model(;omega_x_mhz=.07,omega_y_mhz=-.04,omega_z_mhz=.31)
    preps,controls,effects = _calibrated_qubit()
    H = π*(omega_x_mhz*_NV_X + omega_y_mhz*_NV_Y + omega_z_mhz*_NV_Z)
    ModelSpec(H;preparations=preps,controls,measurements=effects,label="generic qubit")
end

"""Effective NV electron qubit plus an unpolarized carbon-13 spin.
H/2π = δ Zₑ/2 + ωL I_z - |1><1|ₑ(A∥ I_z + A⊥ I_x), where Iα=σα/2.
Inputs are MHz. This secular, rotating-frame model uses ms=0,-1, positive ωL,
and a negative conditional hyperfine term from ms=-1. It excludes leakage and
nonsecular electron transitions; it is not a universal NV Hamiltonian.
"""
function nv_model(;detuning_mhz=.03,omega_l_mhz=.5,a_parallel_mhz=.08,a_perp_mhz=.12)
    preps,controls,effects = _calibrated_qubit(true)
    p1 = (_NV_I-_NV_Z)/2
    H = 2π*(detuning_mhz*kron(_NV_Z/2,_NV_I) + omega_l_mhz*kron(_NV_I,_NV_Z/2) -
        kron(p1,a_parallel_mhz*_NV_Z/2+a_perp_mhz*_NV_X/2))
    ModelSpec(H;preparations=preps,controls,measurements=effects,label="effective NV + one carbon-13")
end

function device_description(system::Union{Symbol,AbstractString})
    s = Symbol(system)
    s in (:generic,:nv) || throw(ArgumentError("system must be generic or nv"))
    DeviceDescription(string(s),[a*b for a in ("x","y","z") for b in ("+","-")],["x","y","z"],["x","y","z"],1e6)
end

"""Small illustrative design: qubit tomography or NV Ramsey, Hahn echo and CPMG-4."""
function default_experiments(system::Union{Symbol,AbstractString};shots=1000)
    s = Symbol(system)
    device_description(s)
    if s == :generic
        return [ExperimentSpec(prep,[Evolution(t)],axis,shots) for prep in ("x+","y+","z+") for axis in ("x","y","z") for t in (.25,.75,1.5)]
    end
    vcat([ExperimentSpec("x+",[Evolution(t)],axis,shots) for axis in ("x","y") for t in (.5,1.,2.,4.)],
        [ExperimentSpec("x+",[Evolution(t/2),Pulse("x",π),Evolution(t/2)],"x",shots) for t in (.5,1.,2.,4.)],
        [ExperimentSpec("x+",cpmg_operations(t,4),"x",shots) for t in (.5,1.,2.,4.)])
end

"""CPMG free evolution with N π rotations about y and total free time t in μs.
The end delays are t/(2N), and internal interpulse delays are t/N.
"""
function cpmg_operations(t::Real,N::Integer;axis="y")
    N > 0 || throw(ArgumentError("CPMG pulse count must be positive"))
    ops = Union{Evolution,Pulse}[Evolution(t/(2N))]
    for j in 1:N
        push!(ops,Pulse(axis,π))
        push!(ops,Evolution(j == N ? t/(2N) : t/N))
    end
    ops
end
