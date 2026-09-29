---
name: nv-modeling
description: Build and review NV-center Hamiltonians, calibrated spin measurements, spectroscopy designs, and numerical models from one nucleus to interacting registers, with explicit conventions and approximation limits.
---

# NV modeling

Read [the paper guide](references/papers.md) for six core papers, primary-literature additions, publication links, and page/equation locators. Paper PDFs are optional local resources, not included in the repository. Published parameter sets describe particular devices; they are not priors for a new blind device.

Select the smallest model that can resolve the question, rather than assuming a nucleus count or independent spins. Before fitting, state the basis, tensor order, frame, signed units, preparation, controls, measurement likelihood, and terms deliberately omitted. The repository's maintained NV broker is a one-nucleus example, not an acquisition interface for general registers. This skill adds physics guidance, not tool capabilities or acquisition authority.

Load the references needed for the decision:

- [Hamiltonians and conventions](references/hamiltonians.md): laboratory spin-1 model, projection, hyperfine signs, nitrogen, frames, and approximation hierarchy.
- [Controls and spectroscopy](references/controls.md): Ramsey, Hahn, CPMG, XY8, nuclear RF, finite pulses, timing, and harmonic discrimination.
- [Optical preparation and measurement](references/measurement.md): fluorescence and resonant readout, SPAM calibration, raw-count likelihoods, resets, and measurement backaction.
- [Interactions and noise](references/interactions-noise.md): dipolar networks, secular/Ising limits, bath noise, relaxation, drift, and residual diagnosis.
- [Inference and numerical checks](references/inference-numerics.md): identifiability, nucleus-count comparison, adaptive designs, and tractable exact/reference propagation for 3–9 nuclei.

Preserve these invariants: projected physical `Sz=diag(0,−1)`, not `Z/2`; MHz becomes radians/μs with one factor of `2π`; pulse count differs from block count; pulse widths and elapsed time matter. Product coherence requires independent Hamiltonian factors and a product initial nuclear state. The familiar real unpolarized-spin formula has narrower assumptions than general factorization.

Separate predictive adequacy from physical uniqueness. Gauge freedoms, unresolved spins, harmonics, SPAM, finite-control errors, and interactions can produce competing explanations. Test them with available controls and raw observations; do not equate every dip with a nucleus or infer atomic coordinates from unjustified point-electron dipoles. Never change physical conventions or validation criteria to improve a fit.

For each hypothesis record its validity regime, source, observable predictions, uncertainty, and a discriminating experiment. Check analytic limits and an independent numerical construction before freezing prospective predictions. Research, validation, independent review, and stopping rules remain those of the root AGENTS.md and workspace skill. This reference does not authorize neural-network training, an ongoing acquisition loop, gate optimization, or hardware execution.
