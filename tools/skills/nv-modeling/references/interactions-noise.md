# Interactions, noise, and approximation limits

Contents: nuclear dipolar coupling; correlated networks; decoherence models;
residual diagnosis. These are alternative physical hypotheses to test, not
mandatory terms or default parameter distributions for a synthetic device.

## Nuclear interactions

With dimensionless nuclear spins, physical signed magnetogyric ratios in SI
angular units, and positions in meters, the magnetic dipolar Hamiltonian is

```text
Hdd/ℏ = Σi<j κij [Ii·Ij − 3(Ii·rhatij)(Ij·rhatij)],
κij = μ0 ℏ γi γj / (4π rij³).
```

Convert the resulting radians/second to radians/μs before combining it with
repository coefficients. Hyperfine contact contributions are not described by
this nuclear point-dipole equation. Avoid ambiguous labels such as “coupling in
Hz”: specify the operator multiplying it and whether the coefficient includes
`2π`, a spin-1/2 factor, or a measured double-resonance splitting.

In a common large-field rotating frame, like-species secular coupling takes
the form

`Hdd,sec = Σi<j bij[Iz,i Iz,j − (I+,i I−,j + I−,i I+,j)/4]`,

where `bij=κij(1−3 cos² θij)` in this convention. Flip-flops remain secular
when the spins are close in frequency. Only when their mismatch is sufficiently
large relative to the exchange matrix element, over relevant times, may one
drop flip-flops and use `Σbij Iz,i Iz,j`. Strong conditional hyperfine shifts
can suppress exchange in one electron manifold but leave it active in another.
Sequences can also restore otherwise off-resonant dynamics. Check the actual
frame and control schedule before declaring an Ising network.

Abobeih 2019 PDF p7 Eq.(3) defines its `Cij` with angular factor
`3 cos² θ−1`, opposite to the `bij` above, and reports double-resonance
frequencies `|Cij|/(4π)`. Those quantities are not interchangeable with a
coefficient in `bij Iz,i Iz,j` or with `bij/(2π)`. Translate the full equation
and measurement sequence before importing values. Its Methods also discuss
electron-mediated corrections and nonsecular effects. A free-standing Ising
coefficient fit need not equal a bare dipolar coefficient.

## Network evidence

Electron-only coherence from independent nuclei can be computed as a product;
interacting nuclei generally require joint evolution. Weak interactions may
be invisible at early times but resolve at longer storage/correlation times.
Unresolved spectral components and interactions are distinct alternatives:
neither is established by a poor fit alone.

Van de Stolpe 2024 PDF p2 Eq.(1) describes an effective nuclear Ising network.
Its `Ai` denote spin frequencies, not an electron hyperfine coefficient.
Coincident frequencies leave pairwise coupling assignments ambiguous;
correlated chain measurements and high-resolution shifts add information
about connectivity (PDF pp2–4, p7 network reconstruction). A graph learned only
from broad one-dimensional spectra should retain unresolved vertices and
alternative assignments. A published 50-spin map does not justify allocating
a dense `2^50` simulation.

Geometry inference requires more than a list of hyperfine magnitudes. Nuclear
pair couplings, field orientation, a lattice model, and symmetry-related
solutions must be considered together. Abobeih 2019 PDF p7 warns that the
electron point-dipole approximation can fail for its measured hyperfine range.
Contact contributions and the electron wavefunction can prevent a unique
position inference. State which spatial ambiguities remain even when a graph
predicts spectroscopy accurately.

## Noise choices encode different physics

Separate explicitly modeled coherent spins from a residual environment. An
extra envelope multiplying a simulation can double-count the same spins if
its calibration already includes their modulation. Specify which bath is
integrated out and what data constrain its parameters.

| Model | Appropriate interpretation | Failure to check |
|---|---|---|
| Static offset distribution | Inhomogeneous averaging over shots/blocks; Ramsey `T2*` | Treating its effect as identical in Ramsey and echo |
| Classical stochastic detuning `β(t)Z/2` | Time-correlated field/temperature noise with stated covariance | Assuming independent noise in different intervals or shots |
| Markovian Lindblad channel | A coarse-grained memoryless relaxation/dephasing limit | Applying it to resolved coherent nuclei or slow drift |
| Empirical stretched exponential envelope | Descriptive fit within measured sequence/time range | Extrapolating one `T2` across all pulse counts and controls |
| Explicit interacting bath/cluster | Coherent memory, correlations and revivals | Truncation or factorization without convergence checks |

For zero-mean Gaussian classical detuning and ideal pure-dephasing toggling
`y(t)=±1`, one can derive

`W(T)=exp[−1/2 ∫₀ᵀdt ∫₀ᵀds y(t)y(s) C(t−s)]`,

where `C(u)=⟨β(t+u)β(t)⟩` has angular-frequency-squared units. This defines
normalization without ambiguous one-sided/two-sided power spectra. If using a
frequency-domain filter, explicitly define the Fourier transform and its
`2π` factors. Finite pulses rotate the coupling operator; scalar `±1` toggling
is then an approximation. Non-Gaussian fluctuations or quantum bath backaction
need not obey this classical expression.

For a qubit Lindblad equation, collapse `sqrt(γφ/2) Z` makes off-diagonal
coherence decay at rate `γφ`; `sqrt(γφ) Z` gives twice that rate. Collapse
`sqrt(γ1)|0⟩⟨1|` adds coherence decay `γ1/2`, giving
`1/T2=1/(2T1)+γφ` only in that particular two-level Markovian setting. Full
NV spin-1 relaxation can populate both `ms=±1`, changing signal baselines and
invalidating a two-level amplitude-damping interpretation. Thermal excitation
and optical pumping also require the relevant upward/downward rates.

## Residuals should choose the next comparison

Compare candidate residuals against sequence family, pulse count, pulse width,
analysis quadrature, elapsed time, and acquisition order. Examples of useful
**tests**, not diagnostic proofs:

- Width/amplitude dependence suggests comparing finite-pulse models before
  adding a coherent nucleus.
- Errors growing with storage time suggest comparing interactions, noise and
  drift with a hidden weak-spin alternative.
- Quadrature-dependent phase errors suggest frame/control/preparation checks.
- Time-ordered offsets shared by reference settings suggest calibration drift.
- Extra resolved nuclear frequencies or connected correlations motivate a
  larger coherent register, conditioned on the measurement's resolution.

Choose experiments where these explanations make different raw-count
predictions. A smooth decay, isolated outlier or attractive fitted parameter is
not enough to select a microscopic mechanism.
