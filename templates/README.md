# math-coding adoption templates

This directory ships reusable artifacts for adopting math-coding
in a downstream repository. Each file is a one-way drop: copy it
into the target repo at the path noted in the file's comment.

| File | Drop into target repo at | Purpose |
|---|---|---|
| `ci.yml` | `.github/workflows/mathc.yml` | Blocking `mathc self-check` GitHub Actions workflow; runs `mathc validate` on staged decisions then `mathc self-check`. |

