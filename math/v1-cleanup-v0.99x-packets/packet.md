---
proposition: "v1.0 keeps only v1-native packets in math/; 17 v0.99x implementation-detail packets and 1 migration packet are removed."
antithesis: "v0.993 had 30+ packets documenting implementation details (shell scripts, AGENTS.md templates, migration steps). v1.0 keeps them around as 'history' but they obscure the v1.0 surface and waste reviewer attention."
synthesis: "Removed 18 directories from math/: agent-mode-subagent-v0992, apply-commit-order-v0992, build-skill-install-improvements-v0992, build-skill-v0992, claude-skills-v0992, cursor-skills-v0992, cursor-temp-cleanup-v0992, doc-version-sync-v0991, epistemic-v0991, install-skill-gate-v0992, multi-agent-skills-v0992, shared-install-v0993, spec-consolidation-v0992, universal-agents-md-v0992, universal-build-pipeline-v0992, witness-external-v0992, v1-migration-from-v0993. 31 packets remain (7 axiom + 24 v1.0 decisions). Site index now lists 29 rows (31 packets minus 2 axiom in dedicated axioms.html)."
substrate: shell
status: applied
files: [tools/build_site.ml]
---

## Intent

Reduce noise. v1.0 is a clean break; v0.99x implementation details
belong in v0.99x git history, not in v1.0's decision ledger.

## What this is NOT

- Not a rewrite. The OCaml runtime, tests, and site renderer are
  unchanged. Only the math/ directory's contents are pruned.
- Not a replacement. v0.99x packets are still reachable via
  `git log --all -- math/agent-mode-subagent-v0992/` etc.

## Run

```sh
./math-coding check    # 145 pass, 0 fail
./math-coding probe    # 145 pass, 0 fail
./math-coding site     # dist/ with 31 packets
```

## Notes

The seven axiom packets (00-difference ... 06-self-application)
stay — they're the v1.0 foundation, not implementation detail.
All v1.0-native packets (v1-*, site-v1-*, math-coding-v0993, etc.)
stay. Only v0.99x-implementation-detail packets and the explicit
"migration from v0.99x" packet go.
