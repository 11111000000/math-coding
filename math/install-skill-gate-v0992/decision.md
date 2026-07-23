# install-skill-gate-v0992

## Thesis

  install-skill.sh refuses to ship a stale SKILL.md.

## Antithesis

  The gate requires meta/build-skill.sh in source-repo. Target projects don't have it. The gate would break target installs.

## Synthesis

  The gate is conditional: it runs only when meta/build-skill.sh exists. Source-repo: gate active, fail-fast. Target: gate skipped silently, install works as before.
