# Optical preparation, SPAM, and likelihoods

Contents: measurement regimes; preparation/reset; photon and binary likelihoods;
calibration; drift and backaction. SPAM means state preparation and measurement.
The formulas below are explicit generative modeling choices; they do not assert
that every NV apparatus or synthetic interface implements the same readout.

## Identify what was recorded

Off-resonant NV fluorescence often gives spin-dependent photon rates with
imperfect contrast and optical pumping during the collection window. A
normalized fluorescence value is not automatically a projective spin
probability or a binomial count. Low-temperature resonant excitation is a
different regime: [Robledo et al.](https://doi.org/10.1038/nature10401),
journal pp574–578, Figs.1–4 (author preprint PDF pp1–5), demonstrate
spin-selective optical preparation/readout and mapping of nuclear information
onto the electron. Optical electron–nuclear flip processes can disturb nuclei.
Their fidelity and resonant conditions do not transfer to arbitrary ambient
fluorescence experiments.

Record the actual observation: photons per shot or time bin, thresholded binary
label, integrated photons over many resets, analog intensity, or already
calibrated binary outcome. Include thresholds, collection windows, reference
counts, repetitions, heralds, rejected shots, charge checks, acquisition order,
and calibration provenance. Fit preserved raw counts where available.

## Preparation and reset are quantum operations

A simple electron preparation model is
`ρe=(1−εprep)|0⟩⟨0|+εprep|1⟩⟨1|`, followed by the actual control pulses.
This excludes leakage, coherence errors and charge-state population, which
require additional states or a calibrated preparation channel when relevant.
Do not apply independent contrast corrections that count the same preparation
error twice.

Electron optical reset does not imply that every nearby nucleus returns to
`1/2`. Nuclear polarization, correlations, optical flips and electron-state
dwell times can persist between shots. A defensible independent-shot model
states why the initial nuclear state is constant and how it is prepared.
With incomplete reset, use a physical reset channel on the joint state or a
validated reduced transition model. Distinguish a fresh experimental repetition
from repeated readouts of the same nuclear state.

For outcome `r`, an instrument `𝓜r` gives probability `Tr 𝓜r(ρ)` and updated
state `𝓜r(ρ)/Tr 𝓜r(ρ)`. Its POVM effect predicts one outcome but does not by
itself specify the post-measurement state. Conditional initialization, repeated
nuclear readout, heralding and feedback require this distinction. Optical
reset-induced random phases may need modeling even when nuclear populations
are unchanged.

## A binary readout model

Let `p=Tr(Eideal ρ)` be the modeled probability for ideal state 0 after the
analysis rotation. Define

```text
η0 = P(label 0 | state 0),   η1 = P(label 0 | state 1),
q = η1 + (η0−η1)p,
k | n,q ~ Binomial(n,q),
log L = k log q + (n−k) log(1−q) + log choose(n,k).
```

`η1` is a false-positive rate, not the fidelity of state 1. State explicitly
which convention is used. Parameters must yield probabilities in `[0,1]`;
allowing unrestricted offset and contrast is unphysical. If leakage or multiple
nitrogen-conditioned responses exist, use the corresponding calibrated
multi-state confusion model or a general effect, rather than silently forcing
them into two numbers.

Binomial likelihood assumes independent identically distributed binary shots
within each setting/block. Fixed calibrated SPAM is appropriate when the public
interface guarantees it. In that case do not add nuisance freedom merely to
improve the candidate. When calibration is uncertain, fit its raw reference
observations jointly or propagate its posterior/uncertainty into predictions.
Do not let a freely moving calibration absorb Hamiltonian discrepancies.

## Photon likelihoods

If each shot samples a spin state and emits a Poisson-distributed number of
photons with conditional means `λ0,λ1`, then

`P(c|p)=p Pois(c;λ0)+(1−p)Pois(c;λ1)`.

This **mixture** is generally not `Pois(c;pλ0+(1−p)λ1)`. Spin-state variability
adds variance. For `n` independent shots where only the sum `C` is retained,
a suitable model under these assumptions is

`P(C|p)=Σm Binomial(m;n,p) Pois(C;mλ0+(n−m)λ1)`.

If optical pumping during the collection window, detector dead time,
afterpulsing, shelving or charge switching matters, constant conditional Poisson
rates may fail. Use calibrated count histograms, time-resolved rate equations,
or an appropriate stochastic model. A threshold maps these distributions to
`η0,η1` with information loss. Keep the threshold rule frozen for comparisons;
do not choose it after examining prospective outcomes.

Normalization such as `(F−F1)/(F0−F1)` propagates both reference noise and shared
denominator uncertainty, producing correlations and sometimes values outside
`[0,1]`. Such values are not invalid raw observations. Do not clip them to force
a probability likelihood. Fit original signal/reference counts or use a
justified covariance model for the transformed observations.

## Calibrations that distinguish errors

Use only authorized, supported controls. Useful references include dark/background
counts; nominal `|0⟩` and `|1⟩` readout histograms; preparation/charge checks;
Rabi amplitude and duration scans; Ramsey X/Y for detuning and phase; and
population measurements after pulse trains. Interleave references across a
long scan when drift matters. A nominal π pulse is not independently perfect
ground truth for calibrating `|1⟩`: propagate its preparation error or use an
independent calibration.

Common confounding patterns are reduced initialization/readout contrast versus
decoherence, microwave detuning versus an apparent hyperfine shift, imperfect
π pulses versus extra spectral peaks, and nitrogen/charge changes versus
multiple components. Calibration and science data should jointly constrain
such explanations. Identify which nuisance parameters are shared across
settings, blocks, or sequences instead of assigning an arbitrary contrast to
every trace.

Slow laser, magnetic, temperature or charge drift can violate pooled iid counts.
Retain timestamps/block IDs, test repeated reference settings, and preserve
within-block uncertainty. A hierarchical or correlated likelihood is an option
only when supported by the acquisition process and evidence; it does not grant
permission to replace a campaign's fixed acceptance gate. Report incompatibility
with that gate if the interface's assumptions fail.
