# Physics and modeling references

Six core NV papers inform the initial NV example and future model choices. Paper PDFs are not distributed with the repository; the guide links to primary publications. The maintained [paper guide](../skills/nv-modeling/references/papers.md) gives one-based PDF page/equation references, source-specific assumptions, and the conversion between physical-spin and conditional hyperfine signs.

In the user's existing Codex session, load [quantum-research](../skills/quantum-research/SKILL.md) and, for NV devices, [nv-modeling](../skills/nv-modeling/SKILL.md). These are repository-local skills selected by AutoNV's system registry; they need not be installed globally. AutoNV supplies CLI and Julia tools for acquisition, validation, and recording reviews; it does not invoke Codex agents, submit model requests, or launch an autonomous agent loop.

For data already placed in a workspace, start with [autonv-workspace](../skills/autonv-workspace/SKILL.md). It guides raw-data inspection, provenance-preserving conversion, hypothesis comparison, the distinction between physical and synthetic validation, and a concrete gate-calibration handoff.

The initial NV example is an effective electron qubit and one carbon-13 spin, with calibrated controls and readout. It is a place to test hypothesis generation and fresh-data validation. Agreement in this example establishes predictive agreement under its available experiments, not validation of every term in a real NV Hamiltonian. Gate design, hardware calibration, larger interacting networks, and the cited machine-learning pipeline remain later work.
