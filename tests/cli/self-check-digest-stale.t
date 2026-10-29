mathc self-check reports `fail` (exit 1) for a decision whose body
changed without a recompute.

Before this, the digest was only ever checked by `mathc validate`, which
looks at one named file. `self-check` is the step that decides whether a
whole change merges, and it read the attestation store without ever
looking at the decision bytes — so a tampered decision came back
`unknown`, indistinguishable from a decision that merely lacked an
attestation. `load_decision_entry` already keeps the raw text in
`Memory.source`, so no I/O plumbing was needed.

The verdict is forced to `Block` AFTER waiver aggregation, not injected
as a `Gate.gap`: a synthetic gap id would fail to match a waiver only by
accident, and a stale digest must not be waivable at all. No fifth
verdict string is introduced — `self-check-pass.t` fails if one appears,
and `Block` already renders as `fail` with exit 1.

`MATH_CODING_ROOT` is what points the kernel at the scratch project:
`find_project_root` falls back to climbing from the BINARY's location,
not the cwd, so a scratch dir under the checkout would still be read as
the repository itself.

`mathc rehash` sets the digest up, so this fixture carries no digest
arithmetic of its own. If rehash and self-check disagreed about what the
digest is, the first assertion would fail — which is the point of using
the tool rather than a second implementation of the algorithm.

  $ D=$(mktemp -d)
  $ mkdir -p "$D/decisions"
  $ : > "$D/dune-project"
  $ printf -- '---\nschema: math-coding/3.3\nid: tampered\nrevision: 1\nstate: active\nmode: light\nbody_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nyaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nintent: |\n  original intent text\ncommitment: |\n  original commitment text\noutcomes:\n  - id: o\n    statement: s\nscope:\n  paths:\n    - "bin/Mathc.ml"\nobligations:\n  - id: o1\n    claim: c\n    acceptance:\n      all:\n        - verifier: mathc version\n          result: pass\n' > "$D/decisions/tampered.yaml"
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$D/decisions/tampered.yaml" --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ MATH_CODING_ROOT="$D" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '{verdict, subject: [.subjects[] | select(.name == "tampered") | .verdict]}'
  {"verdict":"unknown","subject":["unknown"]}
  $ sed -i 's/original intent text/FABRICATED INTENT never written by anyone/' "$D/decisions/tampered.yaml"
  $ MATH_CODING_ROOT="$D" $INSIDE_DUNE/bin/mathc.exe self-check > "$D/out.json"; echo "exit=$?"
  exit=1
  $ jq -c '{verdict, subject: [.subjects[] | select(.name == "tampered") | .verdict]}' "$D/out.json"
  {"verdict":"fail","subject":["fail"]}
  $ jq -r '[.subjects[] | select(.name == "tampered") | .causes[0]] | .[0]' "$D/out.json" | grep -c 'not the digest of this file'
  1
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$D/decisions/tampered.yaml" --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ MATH_CODING_ROOT="$D" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '{verdict, subject: [.subjects[] | select(.name == "tampered") | .verdict]}'
  {"verdict":"unknown","subject":["unknown"]}
  $ rm -rf "$D"
