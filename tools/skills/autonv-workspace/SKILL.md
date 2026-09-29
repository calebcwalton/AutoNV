---
name: autonv-workspace
description: Inspect data placed in an AutoNV workspace, discover and validate candidate Hamiltonians using Julia tools, and prepare a gate-calibration handoff from accepted evidence.
---

# AutoNV workspace research

Use this skill when the user points to experimental or simulated data and asks to understand the Hamiltonian, validate a model, or continue toward gate calibration. Work in the user's existing Codex session. AutoNV never submits model requests; its CLI and Julia functions are tools for this session. The local `codex sandbox` utility, when used for candidate evaluation, does not invoke an agent.

Use the repository-root `.venv/bin/python` for Python analysis and plotting.
Reuse this single environment across studies; do not create study-local virtual
environments. Installation and dependency updates use root `requirements.txt`,
as described in the root README and AGENTS.md.

Read [the workspace workflow](references/workflow.md) for data handling, validation provenance, and the gate-calibration handoff. Load [quantum-research](../quantum-research/SKILL.md); for NV systems also load [nv-modeling](../nv-modeling/SKILL.md) and its paper guide when choosing physical terms.

Begin by inspecting the workspace, raw files, metadata, prior results, and current CLI help. Keep `raw-data/` unchanged. Put scripts, conversions, hypotheses, and experiment proposals in `research/`, and reports in `results/`. Inspect metadata before asking questions; ask only for missing information essential to interpreting the data or choosing the next experiment.

Treat maintained tool code as read-only during research; `tools/skills/` is the explicit exception for evidence-backed improvements to shared research guidance. Read the APIs, examples, and papers; call `tools/bin/autonv` from the repository root or use Julia with `--project=tools`. Put candidate code, analysis scripts, and figures under `workspace/`, and keep all reusable skills in `tools/skills/`. Other maintained-tool changes require an explicit maintenance request. Never inspect `private/`, hidden device parameters, or seeds. The public device identifier is a handle for the tool, not a route to ground truth.

Do useful analysis with the information available. Do not invent shot counts, time units, control calibration, measurement meaning, acquisition order, or missing observations. Describe unresolved assumptions and how they limit inference. Real observations, imported simulations, and newly acquired synthetic counts must remain distinguishable throughout results.

Fit candidate models against exploratory data and use fresh, prospectively specified observations for validation. An already inspected dataset can support fitting and retrospective checks but cannot become fresh validation by renaming or splitting it afterwards. Synthetic validation tests a simulator workflow; it does not validate the user's physical device. Arrange independent physics and statistical reviews through the current session when the user requests reviewed validation; submit the resulting verdicts through the explicit tool interface.

When the user requests a gate-calibration handoff, prepare it with the accepted evidence, target gates, controls, bounds, objective, uncertainty, and validation requirements; label it provisional if model validation is incomplete. Do not claim optimized pulses, measured fidelity, hardware calibration, or a gate optimizer run unless actually performed. The initial AutoNV tools do not implement gate optimization or hardware execution. State this boundary and save a concrete handoff so later implementation can continue.

Follow the research loop, recovery rules, and skill-learning policy in the root [AGENTS.md](../../../AGENTS.md). Resume from public state and a study-local `PROGRESS.md`; checkpoint findings, commands, evidence IDs, and the next action after meaningful work. Review reusable learning each iteration and update this skill or its references when supported by evidence. A one-off request does not authorize an ongoing loop. Respect the user's endpoint and explicit limits, without inventing default budgets; record a concrete blocker when no useful authorized work can continue.

Example user prompt:

> Use the AutoNV workspace skill on `workspace/my-nv`. Inspect the files in `raw-data/`, identify the units and controls, fit and compare plausible NV Hamiltonians, and tell me which new experiments would distinguish the remaining models. Validate with appropriately held-out or fresh data and independent reviews where available. Then prepare the gate-calibration handoff, clearly separating completed results from work that needs hardware or a future optimizer.
