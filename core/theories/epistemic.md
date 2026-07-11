# Theory: Epistemic State

**Rigor:** any

Belief state B: Prop × Agent → [0,1]:
- B(P, a) = 1.0 — agent a fully believes P
- B(P, a) = 0.5 — agent a is uncertain
- B(P, a) = 0.0 — agent a has no belief

**Used in:** assumptions.yaml:epistemology. The marker drives
the action protocol (see agents.md).

| Marker | Belief interval | Action |
|--------|------------------|--------|
| fact | 1.0 | verify if possible |
| hypothesis | (0, 1) | search for evidence |
| judgment | {0, 1} | respect, do not challenge |
| unknown | 0 | ask user, do not proceed |

**Example:** "POSIX sh is universally available" is fact
(verified). "5 files is right minimum" is hypothesis
(needs evidence). "Use plain text" is judgment (design).
"What about TLA+?" is unknown (needs user).
