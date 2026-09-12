---
proposition: "`proven` epistemic marker requires reproducible evidence — verify re-runs the recorded command and demotes to `hypothesis` on mismatch."
antithesis: "Markers as labels (`fact`, `hypothesis`, `judgment`, `unknown`, `proven`) without reproducibility are theater — anyone can claim `proven`."
synthesis: "`proven` evidence must be a re-runnable command with recorded exit code. On every `check`, OCaml runtime executes the command, compares exit code to recorded, demotes marker if mismatch. This makes epistemic honesty checkable, not just declared."
substrate: shell
status: applied
files: [src/lib/check.ml]
---

## Intent

Make epistemic honesty a runtime property, not a written label.

## What this is NOT

- Not a guarantee of truth. Re-running a command proves the
  environment matches the recorded one. Different CI runners may
  produce different results.
- Not a replacement for code review.

## Run

```sh
# Re-run the recorded evidence command for a proven marker.
# Exit code compared to recorded_exit.
sh -c "tests/example.sh" ; echo $?
```

OCaml runtime does this automatically on `check --epistemics`.

## Notes

For `fact` markers, evidence is recommended but optional (text
evidence is acceptable). For `proven`, evidence must be a command.
This asymmetry reflects different epistemic strengths.
