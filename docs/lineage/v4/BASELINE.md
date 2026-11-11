# V4 baseline

- Branch: `archive/v4`
- Tag: `v4-baseline`
- Commit: `dd14c22a443958822cb0224a49b43f58edc4a111`
- Implementation branch: `feat/v5-clean-slate`

The v4 implementation is preserved in Git history. It is not part of the
active v5 tree and must not be imported by v5 modules.

Measured at the freeze:

- build and all 14 test suites passed;
- map: `green`, 46 claims, uncertainty 0/12, eight uncovered files;
- audit: 45 controls reached their subject, one had unknown reach;
- doctor: exit 1 because the generated math-coding block was absent from
  `AGENTS.md`;
- `main` was 30 commits ahead of `origin/main`.

The frozen tree is a benchmark and a source of defect scenarios, not a
source of truth for the v5 architecture or the v5 specification.
