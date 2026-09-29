# This file is launched ONLY inside the code-execution sandbox. The supervisor
# never evaluates generated Julia in its own process.
using AutoNV, LinearAlgebra
using AutoNV: JSON3

length(ARGS) == 5 || error("usage: predict.jl BUNDLE EXPERIMENTS_JSON OUTPUT_JSON BACKEND SYSTEM")
bundle, input, output, backend, system = ARGS
experiments = experiment_from_dict.(JSON3.read(read(input, String), Vector{Dict{String,Any}}))
isempty(experiments) && error("at least one experiment is required")

# Backend availability is infrastructure, not evidence against a Hamiltonian.
AutoNV.enable_cuda!(backend)
resolve_backend(Symbol(backend))
result = try
  redirect_stdout(stderr) do
    include(joinpath(bundle, "main.jl"))
    isdefined(Main, :build_model) || error("candidate/main.jl must define build_model()")
    # include() defines the entrypoint after this closure was compiled.
    model = Base.invokelatest(build_model)
    model isa ModelSpec || error("build_model() must return an AutoNV.ModelSpec")
    validate_model(model)
    AutoNV.check_calibration(model, system)
    probabilities = predict_batch(model, experiments; backend=Symbol(backend))
    # Independent matrix exponentials for closed models; dissipative models use
    # a tighter CPU solve and label this weaker cross-check explicitly.
    indices = unique([1, cld(length(experiments), 2), length(experiments)])
    reference = reference_predict_batch(model, experiments[indices])
    maximum(abs.(probabilities[indices] .- reference)) <= 1e-6 || error("reference evolution disagrees with the candidate simulation")
    Dict("probabilities" => probabilities, "checked" => true,
         "metadata" => simulation_metadata(; backend=Symbol(backend)),
         "reference_method" => isempty(model.collapse_operators) ? "matrix_exponential" : "tighter_cpu_ode",
         "reference_indices" => indices, "reference_probabilities" => reference)
  end
catch err
    Dict("checked" => false, "error" => sprint(showerror, err))
end
write(output, JSON3.write(result))
