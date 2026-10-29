mathc validate enforces the runtime-attestation materials-digest
rule. Per `spec/constitution.md` §0 (A0 separation) and
`decisions/kernel-bugs-v3.4-2026-10`, an attestation with
`kind_` in `{test, build, observation, analysis}` MUST carry a
non-empty `subject.materials_digest`. An empty digest is
permitted only when `kind_: review` (a human declaration without
a runtime anchor).

This is the positive-and-negative contract for the
materials-digest enforcement (decisions/kernel-bugs-v3.4-2026-10).
The check is part of an A3-protected transition (self-application
closure).

  $ cd "$DUNE_SOURCEROOT"

An attestation with `kind_: test` AND a non-empty digest is
accepted:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > test-with-digest.json <<EOF
  > {
  >   "schema": "math-coding/attestation-3.3",
  >   "kind": "attestation",
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "subject": {"decision": "x", "obligation": "y", "candidate_tree": "HEAD", "materials_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111"},
  >   "kind_": "test",
  >   "producer": {"identity": "ci:bot"},
  >   "result": "pass",
  >   "issued_at": "2026-10-16T00:00:00Z"
  > }
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json test-with-digest.json | jq -c '{verdict, kind}'
  {"verdict":"parse-ok","kind":"attestation"}

An attestation with `kind_: test` and EMPTY `materials_digest`
is rejected with `MC-MATERIALS-DIGEST-EMPTY` (Block):

  $ cat > test-empty-digest.json <<EOF
  > {
  >   "schema": "math-coding/attestation-3.3",
  >   "kind": "attestation",
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "subject": {"decision": "x", "obligation": "y", "candidate_tree": "HEAD", "materials_digest": ""},
  >   "kind_": "test",
  >   "producer": {"identity": "ci:bot"},
  >   "result": "pass",
  >   "issued_at": "2026-10-16T00:00:00Z"
  > }
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json test-empty-digest.json | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-MATERIALS-DIGEST-EMPTY","severity":"block"}

An attestation with `kind_: build` and EMPTY `materials_digest`
is rejected:

  $ cat > build-empty-digest.json <<EOF
  > {
  >   "schema": "math-coding/attestation-3.3",
  >   "kind": "attestation",
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "subject": {"decision": "x", "obligation": "y", "candidate_tree": "HEAD", "materials_digest": ""},
  >   "kind_": "build",
  >   "producer": {"identity": "ci:bot"},
  >   "result": "pass",
  >   "issued_at": "2026-10-16T00:00:00Z"
  > }
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json build-empty-digest.json | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-MATERIALS-DIGEST-EMPTY","severity":"block"}

An attestation with `kind_: observation` and EMPTY
`materials_digest` is rejected:

  $ cat > observation-empty-digest.json <<EOF
  > {
  >   "schema": "math-coding/attestation-3.3",
  >   "kind": "attestation",
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "subject": {"decision": "x", "obligation": "y", "candidate_tree": "HEAD", "materials_digest": ""},
  >   "kind_": "observation",
  >   "producer": {"identity": "ci:bot"},
  >   "result": "pass",
  >   "issued_at": "2026-10-16T00:00:00Z"
  > }
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json observation-empty-digest.json | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-MATERIALS-DIGEST-EMPTY","severity":"block"}

An attestation with `kind_: review` and EMPTY `materials_digest`
is ACCEPTED (humans may declare without a runtime anchor):

  $ cat > review-empty-digest.json <<EOF
  > {
  >   "schema": "math-coding/attestation-3.3",
  >   "kind": "attestation",
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "subject": {"decision": "x", "obligation": "y", "candidate_tree": "HEAD", "materials_digest": ""},
  >   "kind_": "review",
  >   "producer": {"identity": "ci:bot"},
  >   "result": "pass",
  >   "issued_at": "2026-10-16T00:00:00Z"
  > }
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json review-empty-digest.json | jq -c '{verdict, kind}'
  {"verdict":"parse-ok","kind":"attestation"}

The diagnostic is reachable via `mathc explain-diagnostic`:

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-MATERIALS-DIGEST-EMPTY | jq -r '.remediation' | head -3
  Compute the SHA-256 of the run's input artefact (test
  output, build artefact, observed metric) and set
  `subject.materials_digest` to the hex digest. Re-run

Cleanup:

  $ cd /
  $ rm -rf "$tmp"
