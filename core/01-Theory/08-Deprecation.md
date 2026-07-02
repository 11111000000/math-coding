# Theory 08 — Deprecation

## Formal definition

A **deprecation** is a relation between two packet versions:

$$P_{\text{old}} \perp P_{\text{new}}$$

read: "$P_{\text{old}}$ is superseded by $P_{\text{new}}$".

The supersession relation has three properties:

1. **Irreflexive**: $\neg(P \perp P)$
2. **Asymmetric**: $P_1 \perp P_2 \Rightarrow \neg(P_2 \perp P_1)$
3. **Transitive**: $P_1 \perp P_2 \land P_2 \perp P_3 \Rightarrow P_1 \perp P_3$

These properties make $\perp$ a **strict partial order** on
packet versions.

The set of packet versions forms a **DAG** (directed acyclic
graph) where edges are supersession relations. The graph is
partial: not every pair of versions is comparable.

**Cascading deprecation**: if $P \perp P'$ and packet $Q$ has
$\text{depends\_on} = \{\ldots, P, \ldots\}$, then $Q$ is
**affected**. The affected status depends on the type of
supersession:

| Type | $P \perp P'$ means | Effect on $Q$ |
|------|---------------------|---------------|
| Renamed | Same intent, different name | $Q$ continues to work, update name |
| Replaced | Different intent | $Q$ re-verify required |
| Removed | No replacement | $Q$ must remove $P$ from `depends_on` |

The convention does not enforce cascading mechanically —
the verifier does not traverse the dependency graph. Cascading
is a **human responsibility** documented in `task.md` of $Q$
when $P$ is deprecated.

## Connection to math-coding

Each packet has a lifecycle state. When a packet transitions
to `deprecated`, it sets a `deprecated_at` field. The
supersession relation is recorded in `task.md` or a separate
`supersession.yaml` (proposed extension):

```yaml
supersession:
  supersedes: <old-packet-task-id>
  reason: <why deprecated>
  type: renamed | replaced | removed
  deprecated_at: 2026-07-02
```

For each dependent packet, the agent must:

1. Read the superseded packet's `supersession` field.
2. Determine the effect on its dependencies.
3. Update its own `task.md` with the deprecation note.
4. If re-verification is required, run the verifier and update
   `verifier-output.yaml`.

This is **epistemic work**, not mechanical. The convention
encourages it but does not enforce it.

## Example

Packet A (`toggle-v1`) was implemented and shipped. Later, the
team decides to rename it to `toggle-v2`. The deprecation:

```yaml
# toggle-v2/packet.yaml
task_id: toggle-v2
supersession:
  supersedes: toggle-v1
  reason: rename
  type: renamed
  deprecated_at: "2026-07-02"
lifecycle: working
```

The relation is `toggle-v1 \perp toggle-v2`.

Now consider packet Q (`export-csv`) which depends on
`toggle-v1`. Its `packet.yaml`:

```yaml
depends_on:
  - toggle-v1
```

After the deprecation, Q's author must:

1. Add to Q's `task.md`: "depends on toggle-v1 which was
   renamed to toggle-v2 on 2026-07-02".
2. Update Q's `depends_on` to `toggle-v2`.
3. Run Q's verifier to ensure nothing else broke.

If Q had structural assumptions about toggle-v1's API that
changed in v2, the verifier would catch it. Otherwise, the
update is mechanical.

For `type: replaced` (different intent), the cascading is
**stronger**: Q's assumptions may no longer hold, requiring
re-verification from scratch.

For `type: removed` (no replacement), Q must remove
toggle-v1 from its `depends_on` or fail to verify.

## References

- Kruskal, "Well-Quasi-Ordering" (1960)
- Fenton & Pfleeger, "Software Metrics" (1997), ch. 8
- Hou et al., "Detecting Deprecated APIs" (2013)