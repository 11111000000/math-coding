---
title: "Deprecation"
description: "Theory document"
weight: 8
---

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