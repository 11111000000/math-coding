---
proposition: "html_escape must emit every character, escaping only &, <, >, \"; earlier version dropped non-special characters via `flush_range` without appending, producing empty `<title>` and `<h1>` tags."
antithesis: "Initial html_escape implementation in tools/build_site.ml used `flush_range i (i+1)` followed by `loop (i + 1)` for the wildcard case — this advanced the read pointer but never added the character to the buffer. All standard text was silently discarded; only &, <, >, \" survived."
synthesis: "Fixed by replacing `flush_range i (i+1); loop (i + 1)` with `Buffer.add_char buf c; loop (i + 1)`. Added a regression check in run.sh that greps for `<title>math-coding | </title>` and fails if any are present. The bug would have been caught earlier with a unit test on html_escape; documenting it here so future readers learn."
substrate: none
status: applied
files: [tools/build_site.ml, math/site-v1-build-toolchain/run.sh]
---

## Intent

Stop empty HTML tags from a broken escape function. The lesson
generalises: any function that conditionally emits bytes must be
unit-tested for the unconditional case.

## What this is NOT

- Not a performance optimisation. The fix is one extra buffer
  write per non-special character.
- Not a security fix. Empty tags render fine; they just lose content.

## Test cases

1. `html_escape "hello"` returns `"hello"`.
2. `html_escape "<a>"` returns `"&lt;a&gt;"`.
3. `html_escape "a&b"` returns `"a&amp;b"`.
4. Round-trip: a packet name passes through html_escape and
   appears verbatim in the rendered `<title>`.

## Run

```sh
./math-coding site
bash math/site-v1-build-toolchain/run.sh
# prints: "site build OK: 45 pages"
```

## Notes

The bug was masked because `html_escape` was only called on packet
names that had no special characters in the visible output. It
would have surfaced if any packet name contained `&`, `<`, or `>`.
