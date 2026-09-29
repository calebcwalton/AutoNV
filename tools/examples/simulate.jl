using AutoNV

model = nv_model()
experiments = default_experiments("nv")
probabilities = predict_batch(model, experiments; backend=:cpu)
for (experiment, p) in zip(experiments, probabilities)
    println("$(experiment.preparation) → $(experiment.measurement): P(+) = $p")
end
