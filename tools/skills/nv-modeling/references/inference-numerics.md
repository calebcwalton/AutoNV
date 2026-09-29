# Identification, experiment design, and numerical checks

Contents: identifiable quantities; model count; discriminating designs;
adaptive selection; numerical methods for small/intermediate registers.
This guide supplies no generative prior, parameter range, nucleus count,
shot budget, or acceptance threshold for a new device.

## What can the observations identify?

A fitted Hamiltonian predicts probabilities for specified preparation, controls
and readout. It is not automatically a unique microscopic reconstruction.
For electron-only observations, check at least:

- Addition of an identity Hamiltonian and permutations of equivalent nuclei.
- Nuclear-basis rotations that leave preparation and measured effects invariant;
  all interaction/control tensors must transform with the basis.
- Transverse sign/azimuth freedom without an independent nuclear phase reference.
- Cosine-only frequency/sign ambiguity and aliases from a regular time grid.
- Detuning versus conditional hyperfine shifts, especially with polarized nuclei.
- Unresolved nearly identical spins versus one effective spin or a broad bath.
- SPAM, pulse errors, nitrogen populations and drift versus extra spectral terms.

Gauge-fix only true equivalences; otherwise retain multiple physical candidates.
Sorting nuclei makes reporting reproducible but does not supply information.
Profile likelihoods, posterior modes and bootstrap fits can reveal boundaries
and alternate assignments that a local covariance matrix misses. State whether
intervals are conditional on a chosen nucleus count, fixed calibration, and
neglected interactions. A zero-coupled additional nucleus is invisible, so
electron data cannot bound every physically present spin without a detectability
definition and explicit assumptions.

Use the Jacobian of **observable** probabilities, with nuisance parameters
included, to examine local sensitivity. Near-collinear columns identify
combinations that a selected design cannot separate. Full column rank after
removing true gauges supports regular local identifiability; rank deficiency
flags first-order insensitivity but can require higher-order analysis. Full
rank does not exclude global aliases or label symmetries.
Report predictive uncertainty even if individual parameters remain broad.

## Compare nucleus counts as hypotheses

Fit plausible counts and physical alternatives supported by public metadata;
do not stop at the first count producing a small training residual. At a
vanishing coupling the extra-spin model meets a boundary with unidentifiable
parameters, and label symmetries create singular structure. Therefore standard
likelihood-ratio χ² calibration and naive parameter-count penalties can be
misleading. Information criteria may be descriptive screens; assess their
assumptions, use a justified parametric bootstrap or model evidence when
appropriate, and seek fresh predictive discrimination.

Assess whether improvement persists across quadratures, pulse counts and
resonance orders rather than allowing extra spins to fit one spectral trace.
Report a smallest adequate predictive model and any observationally equivalent
larger models; do not call it an exact atom count without resolving the
detection limitations. Trained denoisers or inferred “pure” traces may guide
exploration but are not replacement observations. Jung 2021 PDF pp5–6 compares
different pulse-count sensitivities and discusses independent-spin model limits.

## Designs that separate explanations

| Uncertainty | Useful supported settings | What still needs checking |
|---|---|---|
| Detuning/sign/alias | Ramsey X and Y; short and nonuniformly spaced times | Preparation/readout phase and timing calibration |
| Transverse hyperfine or close resonances | Hahn plus several CPMG counts/orders | Finite pulses, contrast, and decoherence |
| Fundamental versus harmonic | Pulse width/amplitude, phase cycle, detuning, field variation | Full drift during pulses and leakage |
| Additional spin versus interaction | Longer-time echoes, selective RF double resonance, correlations | Actual RF selectivity and nuclear preparation |
| Graph connectivity under overlap | Chained/correlated spectroscopy | Duplicate vertices, readout mapping, spectral resolution |
| Coherent physics versus drift/SPAM | Interleaved population/reference settings and repeat blocks | Acquisition order and reset-induced memory |

Only propose settings available through the public interface. If a decisive
control is absent, document the unresolved equivalence and narrow the claim.
Do not invent experiments that the broker cannot perform or replace missing
multinuclear access with its single-nucleus fixture.

## Adaptive selection

For independent binary counts with probability `q(x,θ)`, a local Fisher matrix is
`F(x)=n ∇q ∇qᵀ/[q(1−q)]`. Use actual readout probability `q`, nuisance parameters,
and realistic duration/overhead. This formula does not make a nearly singular
design identifiable or handle global model ambiguity. At boundaries use the
exact likelihood rather than an unstable numerical denominator.

Model discrimination can instead score expected information gain about the
model index and parameters, or predicted separation relative to shot and
calibration uncertainty. Average over plausible modes rather than selecting
settings for only the current best point. Include some phase/time diversity
to expose aliases; do not allocate every shot where one fit predicts maximal
contrast. Trade off information with elapsed experiment/reset/readout time and
computation, using the user's actual limits.

[Joas et al.](https://doi.org/10.1038/s41534-021-00389-z), PDF pp2–3 Fig.1
and Methods pp6–7, demonstrate online Bayesian updates and adaptive Ramsey
timing with optical-readout overhead. Their inverse-uncertainty timing heuristic
is not a universal optimum. The experiment estimates a parallel coupling for
one nucleus, not an unrestricted multi-spin tensor or unknown-count network.
Use it as evidence that adaptive acquisition can be practical, not as proof
that a chosen prior or heuristic resolves every ambiguity.

Adaptive exploratory design and prospective validation have different roles.
Before fresh validation, freeze candidate, calibration assumptions, settings,
and predictions. Use the campaign's established multiplicity/error allocation.
After inspecting outcomes, revisions require new prospective evidence. A
retrospective random split of already inspected data does not restore blindness.

## Numerical methods for 3–9 carbon-13 nuclei

An electron qubit and `K` spin-1/2 nuclei have dimension `d=2^(K+1)`:
`K=3` gives `16`, `K=9` gives `1024`. Full electron spin gives `3·2^K`;
explicit `14N` multiplies either dimension by three, `15N` by two. State these
factors before allocating matrices.

At `d=1024`, a dense complex128 matrix is 16 MiB. A dense `d² × d²`
Liouvillian is 16 TiB, before workspace. Consequently a feasible state or
density matrix does not imply a feasible dense superoperator. These are
allocation estimates, not claims that every fitting workload is fast.

Choose the method from the structure:

- Independent nuclei with a product initial nuclear state, electron-secular
  drift, and ideal π switches:
  ordered 2×2 conditional propagators and product traces are exact under those
  assumptions, with cost linear in nucleus count.
- Interacting nuclei with the same ideal branch switching: propagate joint
  nuclear branch matrices of dimension `2^K`; retain the correct initial state.
- Finite transverse electron controls: full electron–nuclear propagation is
  generally required; independent scalar coherence products are not exact.
- Piecewise constant closed evolution: Hermitian eigendecomposition, matrix
  exponential or Krylov action with cached **unchanged** segment parameters.
  Matrix-free/sparse state propagation avoids dense superoperator allocation.
- Time-dependent pulses: adaptive ODE or converged time slicing; include drift
  throughout each segment and resolve envelope/phase discontinuities.
- Open evolution: apply the Lindblad generator directly to density matrices,
  or use trajectories with their sampling error. Do not form a dense
  Liouvillian simply because a solver permits it.

Initially mixed nuclei can be handled exactly as a density matrix or weighted
ensemble of orthogonal pure states. Random-state trace estimates/trajectories
add stochastic error and need convergence evidence; they are not noiseless
model predictions. Cluster truncation and tensor methods are options for
larger interacting systems, but validate convergence on observable probabilities
against exact small subsystems and expanded clusters/bond dimensions.

## Checks that catch physical mistakes

Compare two constructions that do not merely call the same buggy sequence
builder. Useful independent references are direct Kronecker-matrix evolution
versus conditional 2×2 traces, analytic rotations versus a general exponential,
and finite-pulse integration versus its calibrated zero-width limit.

Verify zero time; zero hyperfine coupling; one-nucleus exact evolution;
commuting conditional Hamiltonians under ideal echo; no-drive free evolution;
zero internuclear coupling; pulse rotation signs and π/2 factors; and invariance
under a consistently transformed nuclear basis/permutation. A zero transverse
coupling is not a universal “no signal” limit: longitudinal coupling can still
modulate Ramsey, though static commuting couplings refocus in ideal echo.

Check Hermiticity, state trace/positivity to numerical tolerance, unitary norm
and probability bounds. Tighten solver tolerance/time step and compare both
individual probabilities and total log likelihood; errors small at one setting
can accumulate across large datasets. Validate at extremes of the fitted design,
not only a benign parameter point. Keep solver error below the precision needed
for the actual inference and fixed validation gate; do not create new acceptance
thresholds in a skill. Record code/environment versions, tolerances, dimensions,
frames, basis order and the exact checks that ran.
