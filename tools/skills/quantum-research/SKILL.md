---
name: quantum-research
description: Propose quantum Hamiltonian hypotheses, design synthetic experiments, and assess fresh-data validation in AutoNV using Julia and QuantumToolbox.
---

# Quantum research in AutoNV

Read the public device description and repository API documentation before constructing a candidate. It defines available preparations, controls, measurements, units, and limits. Initial devices assume calibrated preparation, controls, and readout; the unknown is the drift Hamiltonian. Do not silently absorb calibration errors into drift terms.

Keep maintained tool code unchanged during research; run its CLI and read its source and documentation. Write candidate code, analysis, and figures inside `workspace/`. Improve shared skills only in `tools/skills/` under the root [AGENTS.md](../../../AGENTS.md) learning policy; other tool maintenance requires an explicit user request. Do not inspect `private/` or hidden device seeds/parameters, even if readable by the current OS account. Use the public acquisition interface for observations.

Write Julia candidate code using the simulation interfaces or QuantumToolbox. Record the Hamiltonian, basis ordering, frame, units, parameters, approximations, and alternatives it excludes. Input frequencies use MHz, times use microseconds, and evolution uses angular frequency; apply the factor of `2π` once. Distinguish Pauli matrices from spin operators `Iα=σα/2`.

Work from the user's existing Codex session. AutoNV provides Julia functions and CLI tools; it does not send requests to Codex, start chat sessions, or run an autonomous agent supervisor. Write candidate scripts in the research workspace and call the documented `init`, `acquire`, `validate`, `review`, and `status` commands explicitly. Run candidate evaluation through the sandboxed validation tool. Acquire device observations through the broker. Do not inspect synthetic truth, private RNG state, exact device probabilities, or controller-private files. Model predictions are public; device probabilities are not.

Choose experiments that distinguish remaining hypotheses, using only device-supported operations. Fit against exploratory counts; use likelihood and residual structure rather than visual agreement alone. Use known analytic limits and an independent small-system calculation to check numerical implementation. Request CPU by default for tiny systems; CUDA is an optional acceleration backend, not a different physical model.

Before validation, freeze the entire candidate bundle and its predictions. Fresh validation counts must arrive afterwards. A changed candidate needs new validation data; previously inspected validation counts become exploratory data. Follow the controller's campaign-wide statistical error allocation; never accept a model solely because reviewers agree or the fit residual is small.

When the user requests reviewed validation, the existing Codex session can delegate to separate physics and numerical/statistical reviewers. Give each reviewer the same frozen candidate and evidence identifiers, without the other reviewer's verdict. Reviewers must report specific objections and distinguish predictive adequacy from parameter identifiability. Submit their verdicts explicitly with the review tool. Acceptance requires objective evidence checks and both approvals. A missing, malformed, stale, or dissenting verdict is not approval. AutoNV records verdicts; it does not itself invoke or authenticate the agents that produced them.

Complete the research steps the user requests. Do not turn a one-off simulation or acquisition into an autonomous loop. For iterative research, follow the root agent loop and checkpoints without adding default budgets. Stop at the requested endpoint, user interruption, an explicit limit, or an external blocker after useful independent work is exhausted. Acceptance completes validation, but a requested handoff may remain. Preserve saved evidence, and report what was tested, uncertainty, unresolved equivalent models, and limitations. A saved incomplete validation is not a successful result. Hardware operation and gate design are separate future tasks.
