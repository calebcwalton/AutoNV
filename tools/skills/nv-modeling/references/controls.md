# Controls, timing, and spectroscopy

Contents: pulse conventions; sequence timing; conditional propagation; finite
pulses and harmonics; nuclear RF. Use only controls exposed by the public device.
An experiment described in literature is not necessarily executable by AutoNV.

## Define the pulse rather than its nickname

In a calibrated electron qubit frame, write

```text
Hdrive(t)/ℏ = Ω(t)/2 [cos φ(t) X + sin φ(t) Y],
Rφ(θ) = exp{−i θ[cos φ X + sin φ Y]/2}, θ=∫Ω(t)dt.
```

An ideal square π pulse has `Ω tπ=π`; `Ω` is radians/μs and its Rabi frequency
in MHz is `Ω/(2π)`. A physical finite pulse evolves under **drift plus drive**.
Its carrier frequency, phase, envelope, amplitude calibration, and relative
timing matter. State whether phase is continuous through gaps or restarted.
For the maintained API, `Pulse(axis,θ)` is instantaneous while an
`Evolution(t; controls=...)` coefficient multiplying a Pauli control is `Ω/2`,
not `Ω`, and is already angular frequency. Confirm actual control matrices.

Use explicit analysis rotations or measurement effects. For example, under
the Pauli convention above, applying `Ry(−π/2)` before Z measurement measures X,
and applying `Rx(+π/2)` before Z measurement measures Y. Check preparation and
readout signs together; an unexplained Y sign can reverse inferred detuning.

## Timing table (ideal instantaneous pulses)

Here `τ` is an **endpoint half delay**, `Nπ` counts π pulses, and the sequence
excludes preparation/readout pulses from its free-evolution time.

| Sequence | Explicit sensing portion | Free evolution | Purpose and limits |
|---|---|---|---|
| Ramsey | free `t` between phase-defined π/2 pulses | `t` | DC detuning, static splittings and phase; vulnerable to inhomogeneous dephasing and aliasing |
| Hahn echo | `τ − πφ − τ` | `2τ` | Refocuses static commuting electron detuning; noncommuting conditional nuclear evolution can remain |
| CP/CPMG train | endpoint `τ`, interior `2τ`, `Nπ` equal-axis π pulses, endpoint `τ` | `2Nπτ` | Nuclear resonances and noise filtering; CPMG additionally specifies preparation relative to refocusing axis |
| XY8 block | same delays, axes `X Y X Y Y X Y X` | `16τ` per 8-pulse block | Suppresses some pulse errors; finite-pulse harmonics remain |

For even `Nπ`, the common block notation is
`(τ−π−2τ−π−τ)^(Nπ/2)`; touching endpoint intervals combine into `2τ`.
An XY8 repetition count `n` means `Nπ=8n`. Never interpret an API argument
named `N`, a paper's block count, and a total pulse count as equal without
expanding one sequence. Taminiau 2014 PDF p5 explicitly uses total pulse count;
Jung 2021's text and diagram must be read together with its Eqs.(1–3).

For finite pulses, distinguish free gaps from center-to-center spacing. If a
center separation is `d` and adjacent equal-width pulses last `tπ`, their free
gap is `d−tπ`; endpoints depend on the chosen sensing-window origin. If free
gaps remain those in the table, sensing elapsed time is `2Nπτ+Nπtπ`.
Do not add a pulse width twice, use a negative gap, or compare scans with
different timing definitions as the same experiment. Include RF pulses,
initialization, readout and dead time in resource accounting.

## Conditional propagation and spectral interpretation

For electron-secular drift and ideal electron π pulses, two electron branches
accumulate ordered nuclear propagators `V0,V1`. Starting the electron in `+X`
and accounting for final branch swaps, its complex coherence can be computed
from `L=Tr(V1 ρn V0†)` times the known electron phase. With `L=2ρ10`,
`⟨X⟩=Re L` and `⟨Y⟩=Im L`. Building the full density matrix once verifies
this convention; different definitions of coherence conjugate the Y formula.

Independent nuclear Hamiltonians **and** a product initial state imply
`L=Πk Tr(V1,k ρk V0,k†)`. Polarized product states still factorize, but factors
may be complex. The frequently used real mixed-spin response assumes
`ρk=1/2`. Initial nuclear correlations or internuclear coupling invalidate
independent-spin factors. See Taminiau 2012 PDF p2 Eqs.(1–2) and Jung 2021 PDF
p1 Eqs.(1–3) for the unpolarized ideal-sequence response. Direct ordered 2×2
propagation is a stable reference near singular-looking analytic denominators.

At high Larmor frequency and weak transverse coupling, Taminiau 2012 Eq.(3)
places conditional coherence resonances near
`τk≈(2k−1)π/(2ωL+a)`. Taminiau 2014's gate family uses integer
`kπ/(2ωL+a)`, distinguishing odd conditional from even unconditional rotations.
These are related but not identical statements about visible coherence dips.
Use exact propagators for final predictions, especially outside the large-field
regime. One nucleus can create many resonances, and several nuclei can share a
dip. Increasing pulse count changes width and depth, not just signal size.

For a classical weak AC field and ideal equally spaced π pulses with spacing
`d`, the fundamental filter frequency is `1/(2d)` with odd harmonics. Since
the table uses `d=2τ`, its fundamental is `1/(4τ)`. This filter picture is not
an exact substitute for quantum conditional nuclear dynamics or backaction.

## Finite pulses and false assignments

[Loretz et al.](https://doi.org/10.1103/PhysRevX.5.021009), PDF pp2–4,
Eqs.(1–6) and Table I, show how evolution during finite XY pulses creates
extra responses. Depending on phase cycle, responses can appear at second,
fourth and eighth harmonics and odd subharmonics; static detuning changes them.
Their illustrative XY4 second-harmonic phase ratio `tπ/(2d)` uses their
interpulse spacing `d` and weak-coupling approximation; it is not a universal
contrast correction. Do not apply one sequence's harmonic table to another.

Before adding a spin or assigning a species to an unexplained dip, compare
predictions for the calibrated pulse envelope and supported variations of:

- Rabi amplitude/pulse width with the timing convention held explicit;
- microwave detuning and pulse-phase cycle (CPMG versus XY8 when supported);
- pulse count and several resonance orders;
- field magnitude/orientation or isotope-sensitive controls when available.

A harmonic explanation must account for the same data across these controls.
Increasing Rabi strength can reduce one finite-pulse error while increasing
leakage or off-resonant excitation; include the relevant level structure.
Phenomenological pulse damping cannot generally reproduce coherent harmonics.

## Nuclear control and correlated spectroscopy

Selective RF introduces its own carrier frame, Rabi rate and phase. Driving
`Iφ` at angular amplitude `Ωn` differs from driving a Pauli operator by `Ωn`.
Selectivity requires separation from unwanted transitions relative to effective
drive bandwidth; inhomogeneous shifts and pulse shaping change this tradeoff.
Bradley 2019 PDF pp2–4 introduces DDRF with electron decoupling and RF phase
updates. Its Eq.(2) assumes negligible transverse coupling for the derivation
and off-resonant suppression in one electron manifold; do not use it as the
general drift model.

RF double resonance, conditional preparation, nuclear echo and spin-chain
measurements can resolve interactions and graph connectivity that electron-only
one-dimensional scans leave ambiguous. Abobeih 2019 PDF pp2–3 and van de Stolpe
2024 PDF pp2–4 give examples. Their required state preparation, long coherence,
selective RF and readout mappings must be available and modeled. A hypothetical
experiment proposal must remain labeled as a proposal when controls are absent.
