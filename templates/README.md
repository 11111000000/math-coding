# math-coding adoption templates

This directory ships reusable artifacts for adopting math-coding
in a downstream repository. Each file is a one-way drop: copy it
into the target repo at the path noted in the file's comment.

| File | Drop into target repo at | Purpose |
|---|---|---|
| `ci.yml` | `.github/workflows/mathc.yml` | Blocking `mathc self-check` GitHub Actions workflow; runs `mathc validate` on staged decisions then `mathc self-check`. |
| `master-policy.yaml` | `decisions/decision.yaml` (a pre-3.4 layout) or `.math-coding/policy.yaml` (the layout `mathc init` writes) | The master policy: the decision a project starts from. Edit `scope.paths[]` to point at your own tree. |

## `master-policy.yaml` is the source, not a copy

It is the ONE source of the master policy. Two other places hold a
copy of it, and both are GENERATED from this file by
`scripts/sync-master-policy.sh` (the check is
`tests/fixtures/master-policy-one-source.sh`):

- `scripts/install-tooling/templates/active-policy.yaml` -- the
  verbatim copy the kernel validates.
- the string literal in `lib/init/init.ml` -- the copy the binary
  embeds, and the one `mathc init` writes.

A project that copies this file gets the master policy; a project
that runs `mathc init` gets the same bytes, because the binary
carries the same source.

