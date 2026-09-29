# Hamiltonians, frames, and signs

Contents: laboratory model; qubit projection; conditional nuclei; nitrogen;
approximation selection. Equations here use dimensionless spin matrices and
`H/ℏ` in radians/μs. They are a modeling synthesis, not a transcription of any
paper's complete Hamiltonian. Source-specific signs must be translated.

## Laboratory model

Choose a right-handed NV frame with `z` on the symmetry axis and document its
orientation relative to the magnetic field and microwave polarization. A useful
ground-state model is

```text
Hlab/ℏ = D(Sz² − 2/3 1) + ex(Sx²−Sy²) + ey{Sx,Sy}
         + cx{Sx,Sz} + cy{Sy,Sz} + S · G_e · B
         + Σk [−γk B · Ik + S · Ak · Ik]
         + HN/ℏ + Hnn/ℏ + Hdrive(t)/ℏ .
```

`S=1`; `{A,B}=AB+BA`. `G_e` includes the electron Zeeman coefficient (positive
in the common `+gμB S·B/ℏ` convention). Here `γk` is the **signed physical
nuclear magnetogyric ratio**, so nuclear Zeeman energy is `−γk B·Ik`. If instead
one defines a signed Zeeman coefficient multiplying `+B·I`, it is `−γk`.
Write the equation, not just a value labeled “gamma.” `Ak` is a full hyperfine
tensor in the same axes, containing contact and anisotropic contributions;
coefficients are not all positive magnitudes. `D/2π` is roughly 2.87 GHz under
ordinary conditions, but is temperature/strain dependent and must be calibrated
when it affects the measurement. Do not use a GHz lab splitting as a MHz
rotating-frame detuning.

The quadrupolar spin operators above provide a convenient phenomenological
description of static electric/strain splitting and mixing. `D` includes the
axial shift. The coefficients are defined by this equation and need not equal
a paper's named electric-field components. Doherty et al. derive the electronic
Hamiltonian and nitrogen hyperfine/quadrupole terms; see the author preprint
PDF p7 Eq.(24), p8 Eq.(29), and
[published ground-state theory](https://doi.org/10.1103/PhysRevB.85.205203).
For actual stress/strain inference, use the full tensor symmetry and coordinate
conversion in [Udvarhelyi et al., Eq.(3)](https://arxiv.org/html/1712.02684):
strain is not generally interchangeable with a three-component effective
electric field, and terms mixing `ms=0` with `±1` can matter.

`Hnn` describes nuclear interactions and `HN` the host nitrogen when not already
included in the nuclear sum. Avoid double counting. A full optical excitation
cycle requires excited states, metastable states and charge dynamics; this
ground-state Hamiltonian does not model them.

## Projection is a physical approximation

In electron basis `(|0⟩=|ms=0⟩, |1⟩=|ms=−1⟩)`, with
`Z=diag(1,−1)`, the exact matrix projections are

```text
P Sz P  = (Z−1)/2 = diag(0,−1)
P Sz² P = (1−Z)/2
P Sx P  = X/√2 ;  P Sy P = Y/√2 .
```

Thus replacing `Sz` by `Z/2` loses a nuclear-only hyperfine term as well as
changing the conditional shifts. Pauli drive amplitudes also differ from
laboratory spin-1 drive amplitudes by matrix elements and rotating-wave factors.
Define the **measured** Rabi frequency through the projected drive Hamiltonian
before using a pulse duration.

Let the selected bare transition be `ω01=(E1−E0)/ℏ`. With a frame that rotates
`|1⟩` at `ωmw`, its residual term is
`(ω01−ωmw)|1⟩⟨1| = (ωmw−ω01)Z/2 + identity`.
Accordingly, for the convention `δZ/2`, `δ=ωmw−ω01` under this transformation.
Other frame definitions can reverse both detuning and phase conventions.
Validate with a single-qubit Ramsey X/Y calculation; do not infer a detuning
sign from a cosine-only trace. State the frame of RF controls separately.

Projection alone does not eliminate virtual transitions. If transverse field,
hyperfine, strain, or drive terms couple to the excluded `ms=+1` manifold, compare
coupling/detuning ratios and accumulated second-order shifts over the actual
sequence. A small instantaneous mixing angle need not imply negligible long-time
phase error. Near avoided crossings, for broadband drives, or when leakage is
measured, retain the full electron spin or derive and verify an effective model.

## Conditional nuclear dynamics

After the **electron secular approximation**, a useful qubit model is

```text
Hq/ℏ = δ Z/2 + |0⟩⟨0|⊗H0 + |1⟩⟨1|⊗H1,
H0 = Σk ωk Ikz + Hnn,0,
H1 = Σk [(ωk+ak)Ikz + bx,k Ikx + by,k Iky] + Hnn,1.
```

All `H0,H1,Hnn,m` in this display are angular-frequency matrices. The displayed
`ωk` is the **signed coefficient of Ikz**, not automatically `+|γk B|`.
The frequent paper convention `+ωL Iz` with positive `ωL` can be adopted, but
requires consistent choices of nuclear axes and hyperfine signs relative to
the laboratory magnetic-moment equation. Do not combine its plus sign with
untranslated physical signed gamma values.

In Bradley's convention `H=ωL Iz+Sz(A∥Iz+A⊥Ix)`, projection gives
`a=−A∥`, `bx=−A⊥`. Taminiau 2014 names the **conditional shifts** directly:
`H1=(ωL+A∥)Iz+A⊥Ix`. See [paper translations](papers.md), Bradley PDF p2
Eq.(1), Taminiau PDF p5 Methods. AutoNV's maintained `nv_model` uses Bradley's
named inputs; it is not a general register constructor.

For one spin-1/2, the two nuclear precession magnitudes are `|ωk|` and
`sqrt((ωk+ak)²+bx,k²+by,k²)`, since `Iα=σα/2`. The anisotropic nuclear term
`Sz Ix` is electron secular even though it is transverse for the nucleus.
Dropping it through a second nuclear secular approximation removes much of
the electron-pulse spectroscopy signal. Electron-secular and nuclear-secular
are different approximations.

For independent nuclei without a calibrated transverse nuclear reference, one
can rotate each nuclear x/y plane to set `by,k=0`, `bx,k≥0`. This is a gauge,
not an inferred azimuth. Nuclear RF phases, interactions, known tensor axes,
polarization, or correlations can make such independent rotations physically
meaningful; transform those terms and states together.

## Host nitrogen

For `14N`, use `I_N=1`, a nuclear Zeeman term, the nitrogen hyperfine tensor,
and `Q[I_Nz²−I_N(I_N+1)/3]` when the axial quadrupole description is adequate.
For `15N`, `I_N=1/2` and there is no electric quadrupole splitting. Isotope
and polarization are device facts to obtain from public metadata or controls,
not interchangeable modeling conveniences.

A polarized, stable nitrogen can sometimes be conditioned on one `mI` value.
An unobserved, stationary nitrogen population requires a mixture of conditional
responses, potentially including separate microwave detunings. It cannot always
be represented by one detuning or by another carbon-13 spin. If microwave/RF
controls or optical resets change nitrogen, include its dynamics and transition
probabilities. Calibrate whether pulses address one hyperfine line or cover all
occupied lines. Nitrogen leakage/polarization uncertainty can mimic contrast
loss or additional spectral components.

## Choose approximations by predicted error

Compare candidate approximations at the longest times, highest pulse counts,
largest supported amplitudes, and closest resonances actually used. Relevant
small parameters include coupling divided by excluded-level detuning,
interaction strength divided by nuclear frequency mismatch, and drift norm
times pulse width. Their values alone are not error bars: numerically compare
observable probabilities with the less reduced model. Report a physical error
budget separate from solver error and shot noise. Read
[interactions and noise](interactions-noise.md) before treating residual decay
or correlated structure as evidence for additional nuclei.
