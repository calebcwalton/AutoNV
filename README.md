# AutoNV

Julia tools for discovering and validating quantum Hamiltonians from experiment
counts, built on QuantumToolbox.jl. The initial acquisition backend is synthetic;
the NV example models an electron qubit coupled to one carbon-13 nucleus.

Use the tools from an existing Codex session. Repository skills guide hypothesis
comparison, experiment design, numerical checks, and independent review. The
package does not call an LLM or run an agent supervisor.

## Repository layout

| Location | Purpose |
|---|---|
| [AGENTS.md](AGENTS.md) | Shared agent instructions, research loop, evidence preservation, and environment policy |
| `tools/src/`, `tools/ext/` | Julia package and optional CUDA extension |
| `tools/bin/`, `tools/scripts/` | CLI and execution helpers |
| `tools/test/`, `tools/examples/` | Tests and candidate examples |
| [tools/skills/](tools/skills/) | Shared workspace, quantum-research, and NV physics skills |
| [requirements.txt](requirements.txt) | Pinned dependencies for the shared Python environment |
| `workspace/` | Local studies, observations, scripts, results, and frozen validation; ignored by Git |
| `private/` | Local operator-only device truth and acquisition state; ignored by Git |
| `tools/papers/` | Optional local paper PDFs; ignored by Git |

This is the only README; `AGENTS.md` is the only agent-instructions file.
Existing synthetic studies and PDFs are not distributed. The
[NV literature guide](tools/skills/nv-modeling/references/papers.md) contains
publication links and modeling references usable without local PDFs.

## Setup

Run commands from the repository root. Julia 1.11 or later is required; the
committed manifest records the resolved Julia environment. CUDA is optional.

```sh
julia --project=tools -e 'using Pkg; Pkg.instantiate()'
tools/bin/autonv doctor
tools/bin/autonv simulate --system nv --backend cpu
```

Python is used for research analysis and plotting, not required by the Julia CLI.
Use Python 3.14 and **one root `.venv` shared by every study**:

```sh
# Create once, only if .venv does not exist.
python3.14 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

Reuse `.venv/bin/python` and `.venv/bin/python -m pip` on subsequent runs. Record
new dependencies and version changes in `requirements.txt`; do not create
study-local environments or install into global Python. Historical local reports
may mention a former study-local `.venv`; substitute the root interpreter without
changing frozen candidate files or evidence. Julia projects are separate from
this Python environment. See [CUDA setup](tools/docs/cuda.md) when needed.

Candidate execution uses the local `codex sandbox` utility, which makes no model
request. It must be available on PATH. Check enforcement from a normal terminal:

```sh
tools/bin/autonv doctor --sandbox-check
```

macOS can reject nested sandboxes. Use the ordinary command-approval flow or a
normal terminal in that case; validation never falls back to unrestricted
execution. The sandbox restricts writes and network access. Directory boundaries
and agent instructions are not adversarial secrecy guarantees between processes
sharing the same OS user.

## Research workflow

Read [AGENTS.md](AGENTS.md) and the
[workspace skill](tools/skills/autonv-workspace/SKILL.md). The
[quantum-research skill](tools/skills/quantum-research/SKILL.md) covers discovery
and validation; the [NV skill](tools/skills/nv-modeling/SKILL.md) adds Hamiltonian
conventions, controls, optical readout, interactions, noise, and numerical methods.

```sh
tools/bin/autonv --help
tools/bin/autonv skills --system nv
```

For example, ask Codex:

> Read the workspace and NV skills. Inspect the observations in workspace/my-nv,
> compare candidate Hamiltonians, and design measurements to resolve uncertainty.
> Continue through fresh validation and independent physics/statistical reviews.
> Preserve the evidence and report the model's limitations.

Research scripts, counts, figures, and checkpoints belong under `workspace/`.
Maintain a study-local `PROGRESS.md` with the current hypothesis, completed
checks, pending operations, and next action. Treat `tools/` code, tests, and
configuration as maintained infrastructure: research must not change them to
improve a fit. Shared skills may receive evidence-backed improvements under the
root agent instructions. Read observations through the acquisition interface;
never inspect private truth during discovery.

## Synthetic acquisition and validation

Create a generic synthetic campaign and an exploratory design:

```sh
tools/bin/autonv init workspace/demo --system generic --backend cpu
julia --project=tools -e 'using AutoNV, JSON3; write("workspace/demo/research/experiments.json", JSON3.write(experiment_to_dict.(default_experiments("generic"))))'
tools/bin/autonv acquire workspace/demo workspace/demo/research/experiments.json
tools/bin/autonv status workspace/demo
```

Use `--system nv` for the supported one-nucleus NV example. A candidate's
`main.jl` must define `build_model()::ModelSpec`; see the
[generic](tools/examples/generic/main.jl) and [NV](tools/examples/nv/main.jl)
examples. Keep all candidate dependencies within its bundle; symlinks are rejected.

Fit on exploratory observations, then propose new settings for prospective
validation. Given a candidate and a new design:

```sh
tools/bin/autonv validate workspace/demo workspace/demo/research/candidate workspace/demo/research/validation-experiments.json
```

Validation snapshots the candidate, executes predictions in a sandbox, freezes
them, and only then acquires fresh counts. Failed candidates need revision and
new prospective data. Once inspected, earlier validation observations become
exploratory for subsequent revisions. For an interrupted broker operation,
inspect status and repeat the original command with unchanged inputs to resume;
do not edit pending state or assume every new acquisition is idempotent.

Arrange independent physics and statistical reviewers in the existing session.
Each reviews the same frozen candidate and evidence IDs without seeing the
other's initial verdict, then writes a verdict matching the
[review schema](tools/schemas/review.json). Record them explicitly:

```sh
tools/bin/autonv review workspace/demo physics workspace/demo/research/physics-review.json
tools/bin/autonv review workspace/demo statistics workspace/demo/research/statistics-review.json
```

Acceptance requires the objective checks and both exact-evidence approvals.
The default probability-error tolerance is 0.05, with an overall statistical
error allowance of 0.01 allocated across attempts. Passing establishes predictive
adequacy on tested settings, not a unique microscopic Hamiltonian. The tools
record reviews; they do not invoke or authenticate reviewers.

## Imported observations and modeling

Preserve original files under `workspace/<study>/raw-data/`. Write conversions
in `research/`, retaining source hashes, units, preparation/control semantics,
counts, and provenance. Compatible converted data can be imported with:

```sh
tools/bin/autonv import workspace/demo workspace/demo/research/converted.json --source measurement-run-id --source-kind hardware
```

See the [workspace workflow](tools/skills/autonv-workspace/references/workflow.md)
for the observation schema, inference process, and calibration handoff. Imported
hardware data does not turn the synthetic acquisition backend into hardware
validation; a physical-device adapter is not implemented.

`ModelSpec` describes a Hermitian Hamiltonian, preparation density matrices,
control operators, binary measurement effects, and optional collapse operators.
The [physics guide](tools/docs/physics.md) explains conventions and limitations.
Constructor frequencies use MHz; evolution applies one factor of `2π` and times
use microseconds. Continuous `Evolution` control coefficients are radians/μs
multiplying their control matrices. `Pulse(axis, θ)` represents an instantaneous
`exp(-im*θ*C/2)` operation. Do not confuse this broker's ideal controls with a
finite-pulse hardware model.

The maintained NV broker supports one nucleus. Larger registers discussed in
skills require a separately supported acquisition/modeling interface. The
repository has no gate optimizer or hardware driver; a calibration handoff is
a specification rather than a demonstrated gate fidelity.

## Verification

```sh
julia --project=tools --threads=2 tools/test/runtests.jl
.venv/bin/python -m pip check
```

Tests cover analytic dynamics, physical inputs, threading, device idempotency,
frozen evidence, review decisions, interruption recovery, and the CLI. CUDA tests
skip without a functional GPU. Run OS-sandbox integration separately, outside an
existing sandbox:

```sh
julia --project=tools --threads=2 tools/test/sandbox_integration.jl
```

Local study evidence, operator state, environments, and paper PDFs stay outside
version control. Preserve completed studies locally; use a new study and device
for a fresh blind benchmark after any previous truth disclosure.
