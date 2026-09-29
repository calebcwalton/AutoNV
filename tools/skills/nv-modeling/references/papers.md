# NV literature and modeling decisions

All page numbers below are **one-based PDF pages**, not journal pagination, unless explicitly labeled otherwise. Locators refer to the six supplied PDF editions examined for the 2026-09-29 literature review; publisher layouts may differ. Paper PDFs are optional local resources and are not distributed with this repository. Use the primary publication links below to obtain the sources. Supplementary material is not assumed to be available. These summaries paraphrase the reviewed sources; source-specific device parameters are not priors for future blind studies.

## Core convention

For the electron basis `(ms=0, ms=−1)` and one carbon-13 nucleus, write

`H = |0><0| ⊗ H0 + |1><1| ⊗ H1`,

with `H0 = ωL Iz` and `H1 = (ωL+a) Iz + b Ix`. Here `a,b` are **signed conditional shifts**, `Iα=σα/2`, and coefficients in this equation are angular frequencies. This is the convention of Taminiau 2014's Methods. A transverse coordinate rotation can choose `b≥0` in the isolated-nucleus model with no calibrated transverse nuclear reference; such a choice does not establish its physical sign or azimuth.

Bradley 2019 instead writes `H = ωL Iz + A∥ Sz Iz + A⊥ Sz Ix` with physical spin-1 `Sz`. Projection onto `ms=−1` gives `a=−A∥`, `b=−A⊥` in the same nuclear axes. A further nuclear-axis rotation may alter the displayed transverse sign. Never copy a table of hyperfine values between these conventions without translating it. The conditional precession magnitude is `sqrt((ωL+a)^2+b^2)`.

AutoNV's `nv_model` constructor uses **Bradley's physical-spin convention**: its `a_parallel_mhz` and `a_perp_mhz` are `A∥/2π` and `A⊥/2π` in MHz. They enter the `|1⟩` block with a minus sign. Thus its conditional shifts are the negatives of those named inputs. The extra electron term is `2π detuning_mhz Zₑ/2`.

Use microseconds and MHz at the user interface. Multiply a frequency in MHz by `2π` to get radians per microsecond. A paper's `A/2π` in kHz converts to MHz by dividing by 1000 before that multiplication. Electron detuning in a selected microwave rotating frame is not the full laboratory electron energy splitting.

## Source map

| Primary source | Where to look | Decision supported |
|---|---|---|
| [Taminiau et al., 2012, Detection and Control of Individual Nuclear Spins Using a Weakly Coupled Electron Spin](https://doi.org/10.1103/PhysRevLett.109.137602) | PDF p1 Fig.1; p2 Eqs.(1–3); p3 Table I and Fig.3 | Conditional nuclear precession, electron coherence response, and independent validation at different resonances/fields. |
| [Taminiau et al., 2014, Universal control and error correction in multi-qubit spin registers in diamond](https://doi.org/10.1038/nnano.2014.2) | PDF p1 pulse-sequence description; p5 Methods, “Nuclear gate design,” unnumbered Hamiltonians | Explicit conditional-shift convention and timing; control depends on anisotropic hyperfine interaction. |
| [Bradley et al., 2019, A Ten-Qubit Solid-State Spin Register with Quantum Memory up to One Minute](https://doi.org/10.1103/PhysRevX.9.031045) | PDF p2 Eqs.(1–2); pp3–4 DDRF description | Physical-spin hyperfine convention, secular approximation, and constraints behind selective RF control. |
| [Abobeih et al., 2019, Atomic-scale imaging of a 27-nuclear-spin cluster using a quantum sensor](https://doi.org/10.1038/s41586-019-1834-7) | PDF pp1–3, Figs.1–2; p6 Methods; p7 Eq.(3), “3D structure analysis” and “Finding the position of the NV centre” | Nuclear–nuclear interactions and multidimensional experiments resolve structure beyond independent-nucleus spectra; limits of point-dipole inference. |
| [van de Stolpe et al., 2024, Mapping a 50-spin-qubit network through correlated sensing](https://doi.org/10.1038/s41467-024-46075-4) | PDF p2 Eq.(1), Fig.1; p7 “Network reconstruction” | Effective nuclear Ising network, spectral overlap, and why correlated chains are needed beyond pairwise assignments. |
| [Jung et al., 2021, Deep learning enhanced individual nuclear-spin detection](https://doi.org/10.1038/s41534-021-00377-3) | PDF p1 Eqs.(1–3); p2 Eq.(4) and Fig.1 | Analytic CPMG signal and resonance periodicity are useful without implementing the paper's learning pipeline. |

## What each source changes

**Six nuclei (2012).** For an unpolarized nucleus, Eq.(1) gives `Px=(1+M)/2`; Eq.(2) relates `M` to conditional rotation axes and rotation angle. Contributions multiply for mutually noninteracting nuclei. This supports a small conditional-evolution reference calculation, but not independent-factor simulation of an interacting bath. Table I contains measured strengths and angles for six particular nuclei. Fig.3 checks predicted resonance positions and amplitudes against other measurements, a useful template for held-out validation.

**Universal control (2014).** Methods give `H0=ωL Iz`, `H1=(ωL+A∥)Iz+A⊥Ix` for electron states `0,−1`. The sequence is `(τ–π–2τ–π–τ)^(N/2)` with `N` total pulses and total free evolution `2Nτ`; `2τ` is the interpulse separation. The approximate resonances `τ≈kπ/(2ωL+A∥)` rely on the stated large-Larmor regime. These formulas guide proposed spectroscopy points; exact propagators should validate candidate predictions. Published control performance and hyperfine parameters are device-specific.

**Ten qubits (2019).** Eq.(1) removes the electron splitting in an interaction picture and neglects nonsecular terms. Eq.(2) is a further driven rotating-frame approximation with transverse coupling set to zero for simplicity and frequency separation large compared with the RF Rabi rate. Do not use Eq.(2) as the general drift model, or drop transverse terms when modeling electron-pulse spectroscopy. The register comprises an electron, eight carbon-13 nuclei, and nitrogen: the title does not mean ten equivalent carbon nuclei.

**Twenty-seven nuclei (2019).** Long nuclear coherence and double-resonance spectroscopy expose internuclear couplings hidden in broad electron spectra. Eq.(3) uses `Cij = αij/r^3 [3(Δz)^2/r^2−1]`, `αij=μ0 γi γj ħ/(4π)`; the structure fit uses measured frequencies `|Cij|/(4π)`. Preserve these sign and factor conventions when importing couplings. The same Methods warn that treating the electron as a point dipole can give large discrepancies for their hyperfine range. Coupling magnitudes alone leave spatial ambiguities; do not equate a fitted hyperfine vector with a unique atom location.

**Fifty spins (2024).** Eq.(1) is `H=Σ Ai Iz(i)+Σ(i<j) Cij Iz(i)Iz(j)`. Its `Ai` are effective nuclear precession frequencies, not the parallel hyperfine coefficients of other papers. Spectral overlap makes pairwise frequency/coupling observations insufficient to identify a unique connectivity graph. Correlated chain measurements provide additional constraints. This motivates a future graph/model extension; it does not justify a dense `2^50` Hilbert-space simulation in the initial package.

**ML nuclear detection (2021).** Eqs.(1–3) give the independent-spin product response `Px=(1+Π Mk)/2` and the single-spin CPMG term. The conditional frequency uses `sqrt((A+ωL)^2+B^2)`, consistent with signed conditional shifts above. Eq.(4) gives local period `2π/(ω̃+ωL)` in half delay `τ`. The model's pulse count and half-delay conventions must match the simulator. Keep this analytic physics and its applicability limits; learned denoising or recovered “pure” traces must not replace raw counts in validation, and no training pipeline is needed initially.

## Hypothesis limits

The initial two-level electron plus one nuclear spin is a synthetic testbed. It does not test leakage into the remaining electron level, nitrogen dynamics, internuclear interactions, optical preparation, finite pulse errors, or non-Markovian bath noise. Add and compare such models only when observations and available controls distinguish them. An identity shift is unobservable. Nuclear relabelings and unobserved nuclear-basis changes can yield identical electron outcomes. Report these equivalences rather than presenting one accepted parameter vector as a unique microscopic Hamiltonian.

## Primary-literature additions and scope

| Source | Verified locator | Use and limitation |
|---|---|---|
| Doherty et al., 2012, [Theory of the ground-state spin of the NV− center in diamond](https://doi.org/10.1103/PhysRevB.85.205203); [author preprint](https://arxiv.org/pdf/1107.3868) | Preprint PDF p7 Eq.(24), p8 Eq.(29); section II.D and III | Ground-state electronic spin Hamiltonian; nitrogen hyperfine/quadrupole terms. The cited preprint equation numbers are not asserted to equal the final journal numbering. |
| Udvarhelyi et al., [Spin-strain interaction in nitrogen-vacancy centers in diamond](https://arxiv.org/html/1712.02684) | Section III Eq.(3), section IV coordinate conversion | Symmetry-complete tensor strain treatment; prevents using an effective electric-field analogy as a general strain model. |
| Loretz et al., 2015, [Spurious Harmonic Response of Multipulse Quantum Sensing Sequences](https://doi.org/10.1103/PhysRevX.5.021009); [publisher PDF](https://journals.aps.org/prx/pdf/10.1103/PhysRevX.5.021009) | PDF pp2–4, Eqs.(1–6), Table I | Finite-pulse phase accumulation and harmonic ambiguity. Sequence-specific, weak-coupling formulas are not generic correction factors. |
| Robledo et al., 2011, [High-fidelity projective read-out of a solid-state spin quantum register](https://doi.org/10.1038/nature10401); [author preprint](https://arxiv.org/pdf/1301.0392) | Journal pp574–578, Figs.1–4; preprint PDF pp1–5 | Resonant optical preparation, spin readout, nuclear mapping, and optical backaction. Cryogenic resonant-readout performance is not an ambient fluorescence calibration. |
| Joas et al., 2021, [Online adaptive quantum characterization of a nuclear spin](https://doi.org/10.1038/s41534-021-00389-z); [publisher PDF](https://www.nature.com/articles/s41534-021-00389-z.pdf) | PDF pp2–3 Fig.1; pp6–7 Methods | Adaptive Ramsey acquisition with readout/computation overhead and a limited hyperfine target. Does not establish unknown-count, full-tensor network identification. |

The detailed [Hamiltonian](hamiltonians.md), [control](controls.md),
[measurement](measurement.md), [interaction/noise](interactions-noise.md), and
[inference/numerical](inference-numerics.md) references synthesize these sources
with explicit mathematical modeling choices. In particular, likelihood equations,
allocation estimates, diagnostic tests and solver recommendations are operational
derivations/guidance, not claims that a cited experiment used every such method.
No bibliography entry supplies a new device's parameter distribution, nuclear
count, hidden state, or guarantee of identifiability. Paper PDFs are excluded from version control; keep any local copies under
`tools/papers/`.
