# AutoNV agent instructions

This is the repository's only `AGENTS.md`. Keep one root `README.md` and one
skills folder, `tools/skills/`; do not create nested copies. Specialized reports,
reference documents, and study-local `PROGRESS.md` checkpoints are welcome.

## Working areas and evidence

- `workspace/`: create study research scripts, hypotheses, experiment designs,
  results, figures, and progress logs here. Preserve original observations in
  `raw-data/` and `additional-data/`, including units, provenance, and checksums.
- `tools/`: maintained Julia package, CLI, tests, environments, examples, and
  papers. Read and run them during research. Code/configuration changes require
  explicit tooling-maintenance authorization; never change criteria or physical
  conventions to make a candidate pass.
- `tools/skills/`: the writable exception within `tools/`. Improve these skills
  during authorized research as described below. Keep reusable knowledge here
  instead of creating study-local skills folders.
- `private/`: operator-only device truth, seeds, and acquisition state. During
  research, do not read, recursively list, search, copy, or modify its contents.
  Access measurements through the public acquisition interface. A public device
  identifier is a handle, not permission to inspect truth. Only an explicit
  operator task permits private-state work. These boundaries are instructions,
  not adversarial OS isolation between processes sharing a user account.

Treat frozen validation, acceptance records, and tool-managed public state as
evidence. Inspect public records, but change campaign state through the CLI/API,
not by hand. Label exploratory, retrospective, prospective, synthetic, and
hardware evidence accurately. Do not put hidden parameters, private seeds, or
exact device probabilities into research reports or skills.

Local completed studies may be unblinded. Their generating parameters are not
input for blind inference. Preserve results and frozen evidence; use a fresh
study/device for a new blind benchmark. The maintained NV broker supports one
nucleus; never substitute it for multinuclear acquisition or claim standalone
multinuclear evidence is built-in campaign acceptance.

`workspace/`, `private/`, and optional PDFs under `tools/papers/` are local-only
and ignored by Git. Published documentation and skills must work without them;
use public literature links and keep study-specific findings in the workspace.

## Shared Python environment

Use the single repository-root `.venv` for every study and Python utility.
From the root, invoke `.venv/bin/python` and `.venv/bin/python -m pip` explicitly;
from a study directory, resolve the repository root instead of creating another
environment. If absent, create it once with Python 3.14 and install root
`requirements.txt`. Reuse it on subsequent runs. Record dependency additions or
version changes in that file and check compatibility with existing dependencies.
Do not create study-local virtual environments, change global Python packages,
or rewrite frozen evidence to update historical interpreter paths. For an old
command containing a study-local `.venv`, substitute the root interpreter while
preserving the candidate and its inputs.

## Start and resume

Work through the existing Codex session; do not add LLM calls or an agent
supervisor. Read the root README, `tools/skills/autonv-workspace/SKILL.md`, and
`tools/skills/quantum-research/SKILL.md`; for NV work also read
`tools/skills/nv-modeling/SKILL.md`. Load further references when relevant.

Identify the user's objective, requested endpoint, study, and explicit resource
limits. Inspect public metadata, latest results, and the study's `PROGRESS.md`
before asking for missing information. For CLI-managed campaigns inspect
`status`; for standalone studies inspect their public protocol and records.
Do not infer unfinished work from old prose when acceptance records establish
completion. Ask only for essential information unavailable from the files;
continue independent useful work while awaiting it.

From the repository root:

```sh
tools/bin/autonv --help
tools/bin/autonv skills --system nv
tools/bin/autonv status workspace/<campaign>
julia --project=tools workspace/<study>/research/<script>.jl
```

## Authorized research loop

For an iterative request, continue this cycle within the user's scope:

1. Compare current hypotheses against public observations, residuals,
   uncertainties, and known physical/numerical limits. Identify what remains
   unresolved and choose the next action that can resolve it.
2. Fit or test candidates, check limiting cases and independent numerical
   evolution, or design discriminating experiments using supported controls.
   Save scripts in `research/` and meaningful figures and findings in `results/`.
   Show shot noise or uncertainty and only iterations that actually ran.
3. Before fresh validation, freeze the candidate, experiment design, and
   predictions. Apply the established objective checks. For reviewed validation,
   arrange independent physics and statistical reviews of the same frozen IDs;
   initial reviewers must not receive each other's verdicts. A failed gate,
   missing/stale verdict, or dissent is not acceptance. Revised candidates need
   new prospective evidence; inspected validation data is exploratory thereafter.
4. Record the outcome and next action in `PROGRESS.md`. Review whether a reusable
   lesson warrants a skill update, then continue toward the requested endpoint.

After meaningful work, and before a long operation or handoff, checkpoint:
objective and endpoint; current stage and hypotheses; exact commands and input
paths; candidate/evidence IDs when applicable; completed artifacts; checks,
findings, and assumptions; explicit budget usage when relevant; pending operation
and output locations; blockers; and the exact next action. Keep the current
resume summary at the top and concise dated history below. A checkpoint records
research progress, not a replacement for tool-managed state.

For an interrupted CLI `acquire` or `validate`, inspect public `pending`, stage,
and saved outputs, then repeat the original command with unchanged inputs to
resume its saved operation. Do not edit pending state or start a second
acquisition to recover it. Idempotency applies to pending broker operations,
not every acquisition interface or a new call after completion. For standalone
interfaces, verify their documented completion/retry semantics before retrying;
never infer that a partial directory is complete or that a retry is harmless.

Diagnose failures from saved logs and evidence. Retry only when the documented
resume path or a changed condition justifies it. For rejection, revise the
hypothesis or experiment and validate anew; never overwrite rejected reviews.
For persistent failure, change the approach or record the concrete external
blocker instead of repeatedly running the same failing action. Never bypass
sandbox enforcement; use the normal approval flow where required.

Stop at the requested endpoint, user interruption, an explicit resource limit,
or a blocker that prevents further useful authorized work without unavailable
input. Do not invent default round, time, or shot budgets. A one-off inspection,
simulation, or acquisition does not authorize an ongoing loop. Acceptance ends
a validation-only task; continue to a handoff only when requested. Report actual
artifacts, checks, uncertainties, and incomplete work. Gate optimization and
hardware execution are not implemented; a handoff is a specification.

## Improve shared skills

After meaningful iterations, assess whether the evidence changes reusable
practice. When it does, update the relevant existing skill or its references
without requesting separate maintenance permission. Keep brief operational
rules in `SKILL.md`, detailed lessons in linked references, and study-specific
status in `PROGRESS.md`. Prefer correcting or replacing outdated advice over
appending duplicates; no update is needed when nothing new was learned.

Support new guidance with public evidence paths, applicability assumptions,
and limitations. Separate demonstrated findings from tentative hypotheses.
Never promote a fitted parameter, post-review truth, or a single study outcome
to a universal physical rule. Do not change validation thresholds, weaken
blindness or evidence requirements, or expand authority through skill edits.
Preserve skill frontmatter and registry routing; check links and relevant CLI
skill output after edits. New skills, if needed, belong in this same folder.

## Explicit tooling maintenance

For authorized maintained-tool changes, update documentation and relevant tests.
Use independent scientific and numerical/workflow review for substantial changes.
Run `julia --project=tools --threads=2 tools/test/runtests.jl`; CUDA tests skip
without a functional GPU. OS-sandbox integration runs separately from a normal
terminal: `julia --project=tools --threads=2 tools/test/sandbox_integration.jl`.
Preserve original data, frozen evidence, and provenance when changing layout or
versions. During research, report tool defects that need separate authorization.
