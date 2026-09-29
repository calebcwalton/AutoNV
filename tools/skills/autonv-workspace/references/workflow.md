# From workspace data to a calibration handoff

## Inspect and preserve

Read root `AGENTS.md`, CLI help, public state/history, the latest study checkpoint, and existing reports first. Existing completed/unblinded studies are historical evidence, not fresh blind benchmarks. Locate the supplied files under `raw-data/` without modifying them. Inventory file names, byte hashes, format, measurement dates when supplied, device/run identifiers, and associated metadata. Record this inventory in `research/` so conversions and fits can be reproduced. Do not infer acquisition time from file modification time.

All run-relative paths below belong under `workspace/<run>/`. Maintained package files are under `tools/`; paper PDFs may optionally be stored locally in ignored `tools/papers/`. Published literature links remain available through the NV paper guide; read maintained code and references without changing them during research. Keep all reusable research skills in `tools/skills/`, the explicit writable exception governed by root `AGENTS.md`. Device truth outside the workspace is off-limits: do not inspect private storage or copy ground-truth parameters into analysis. Use public counts and capabilities only.

Find the physical meaning of each column or array, time/frequency units, pulse sequence and axis/phase convention, preparation, measurement basis, counts or signal normalization, number of shots, and known readout calibration. For NV experiments also inspect field, rotating frame, selected electron levels, nuclear preparation, and whether pulses were finite or treated as instantaneous. These may be absent; distinguish unknown from a documented zero or default.

Ask for indispensable missing information only after inspecting files and nearby metadata. For example, an unlabeled delay axis cannot establish a frequency scale, and fluorescence amplitudes cannot be turned into binomial counts without a documented measurement model. Continue plots and format inspection while clarifying those uncertainties. Do not silently map unknown operations onto ideal calibrated controls.

Use the shared repository-root `.venv/bin/python` for Python scripts and
`.venv/bin/python -m pip` for dependency installation, with versions recorded in
root `requirements.txt`. Never create a separate environment for a study.
Historical frozen scripts and reports retain their original bytes; substitute
the root interpreter when rerunning old commands.

## Convert without manufacturing evidence

Keep conversion code and converted observations in `research/`. Preserve original values and record every transformation: source hash, row/record mapping, units, calibration, filtering, excluded rows with reasons, and conversion-code version. Work from raw counts where available; retain denoised or normalized traces as derived analysis rather than replacing observations.

The initial binary-observation representation is an array of records:

```json
[
  {
    "experiment": {
      "preparation": "x+",
      "operations": [{"kind": "evolve", "duration_us": 1.0, "controls": {}}],
      "measurement": "x",
      "shots": 1000
    },
    "counts": 734,
    "shots": 1000
  }
]
```

This is a **schema example**, not measured data. `counts` is the integer number of positive binary outcomes, `shots` is the integer total, and the experiment shot total must match. Times are microseconds. Pulse operations use `kind="pulse"`, an available `axis`, and `angle_rad`. Continuous `controls` coefficients are radians per microsecond multiplying their stored control matrices directly; they are not ordinary MHz or automatically Rabi frequencies. The public device description defines which preparations, controls, and measurements are supported.

Use the documented import tool only after confirming that the experimental semantics fit its public device contract. Supply a clear source label and retain detailed provenance alongside the conversion. Imports are exploratory observations, not proof of fresh validation. If the dataset has analog fluorescence, correlations, incompatible pulse descriptions, different dimensions, or uncertain readout, preserve its native representation and explain the required observation-model/adapter work instead of forcing it into this schema.

For a compatible conversion of actual hardware counts, the CLI form is:

```sh
tools/bin/autonv import workspace/my-nv workspace/my-nv/research/observations.json --source measurement-run-id --source-kind hardware
```

Replace the paths and source identifier with those actually inspected. Use `synthetic` for known simulated data and `unknown` when provenance cannot be established. The source label alone does not replace the detailed conversion/provenance record.

## Discover and challenge a Hamiltonian

Write a small set of competing hypotheses in `research/`: terms, basis, frame, signed parameter units, calibrated controls/readout, approximation regime, fit parameters, and distinguishable predictions. Start with a simple model justified by the data; escalate complexity when residuals and experiment coverage support it. For NV conventions and applicability limits, use the NV paper guide.

Fit exploratory observations using a likelihood appropriate to their measurement process. Inspect residuals against time, sequence, and control setting. Compare alternatives and parameter uncertainties; report unidentifiable signs, gauge choices, and equivalent models. Preserve scripts and seeds. Verify implementation with limiting cases and independent numerical evolution before interpreting a poor fit as new physics.

Save progress figures under `results/figures/` with the plotting script in `research/`. Begin with measured outcome frequencies against delay/control setting and shot-noise uncertainty; add candidate predictions and residuals only after a candidate is evaluated. Show fit/validation history only for iterations that actually ran. Label synthetic data, dataset identifiers, units, and exploratory versus fresh validation points. Do not invent convergence curves, use hidden parameters as a reference fit, or present candidate estimates as known truth.

Propose experiments that separate the strongest remaining alternatives, within documented device controls and limits. Save the intended preparation, timing, pulse phases, measurement, shot count, and expected discrimination. If no hardware adapter exists, produce the acquisition specification for the user; do not silently substitute the bundled synthetic device.

## Validate and review

Freeze the candidate and predictions before requesting new observations. Distinguish these evidence classes explicitly:

- **Exploratory/retrospective:** observations already inspected while forming the candidate.
- **Prospective physical-device validation:** predictions committed before newly acquired physical observations, with acquisition provenance.
- **Synthetic validation:** fresh draws from the bundled synthetic device; useful to exercise discovery tools, not to establish physical-device agreement.

A previously untouched held-out set can support a separately documented validation design only if selection, secrecy, and candidate freezing are actually established. Merely splitting a dataset after looking at it is insufficient. The initial CLI validation command acquires from the synthetic device. Do not describe it as validation against an imported physical dataset; real-device validation requires a suitable acquisition adapter or a separately implemented, explicit procedure.

Apply the configured objective numerical/statistical checks and arrange independent physics and statistical reviewers through the user's existing session when requested. Supply the same frozen candidate and evidence identifiers without sharing verdicts between initial reviewers. Record objections and exact-ID verdicts with the review tool. Neither an LLM's confidence nor both approvals can replace a failing evidence check. Reviewed agreement means predictive adequacy for the tested experiments, not a unique microscopic Hamiltonian.

## Prepare the gate-calibration handoff

When the user requests a gate-calibration handoff, create `results/gate-calibration-handoff.md` only as a clearly labeled specification unless actual calibration tools have been implemented and run. Include:

- Supported model, basis/frame/unit conventions, parameter estimates and uncertainty, evidence identifiers, validation provenance, and unresolved alternatives.
- User-requested gates as target operators in that basis, computational subspace, spectator treatment, and relevant leakage assumptions. Ask for gate targets if they are essential and absent; do not silently choose a universal set.
- Available drive channels, coupling operators, phase/frequency convention, amplitude and bandwidth limits, sample timing, duration constraints, and calibration metadata. Mark unknown bounds rather than inventing them.
- Proposed objective and acceptance criteria: target operation, allowed duration/leakage, robustness over parameter uncertainty, and which reported fidelity definition would be used. Distinguish simulated fidelity from measured fidelity.
- Required next tools: pulse optimizer, waveform/hardware adapter, calibration experiments, and independent gate-validation protocol. Record their current implementation status.

If Hamiltonian validation is incomplete, label the handoff provisional and enumerate the evidence needed first. Gate design is downstream work; the initial repository supplies neither an optimizer nor a physical hardware connection. End the report with concrete completed artifacts and next required inputs/actions rather than claiming that gates are calibrated.
