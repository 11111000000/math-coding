mathc attest-batch reads a TSV manifest and writes one attestation
JSON per row into the output directory. This fixture pins the
positive path: 3-row manifest -> 3 attestation files, each with
a `sha256:` id matching the canonical-JSON SHA-256 of the body
(excluding `id`), per AGENTS.md / source-map line 280-282 and
`lib/attestations/batch.ml::compute_id`.

Hermetic: the test points `MATH_CODING_DECISIONS_DIR` and
`MATH_CODING_ATTESTATIONS_DIR` at operator-named directories
under the tmpdir so it cannot pollute the host checkout even if a
previous test failed mid-run. The resolver honours env-vars over
the new-default `.math-coding/` layout (per `lib/path_config.ml`
and `bin/Mathc.ml::env_or_default`).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ mkdir -p "$MATH_CODING_ATTESTATIONS_DIR"
  $ mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --out="$MATH_CODING_ATTESTATIONS_DIR"
  wrote .test-math-coding/attestations/d1-onboarding-d1-obl-acceptance.json
  wrote .test-math-coding/attestations/d1-onboarding-d1-obl-noise.json
  wrote .test-math-coding/attestations/d2-rollout-d2-obl-build.json

All three files exist.

  $ ls .test-math-coding/attestations
  d1-onboarding-d1-obl-acceptance.json
  d1-onboarding-d1-obl-noise.json
  d2-rollout-d2-obl-build.json

The default `.math-coding/` MUST NOT exist -- the test is hermetic.

  $ test ! -d .math-coding && echo "no default .math-coding/: ok"
  no default .math-coding/: ok

Each file is a single-line JSON object with the required fields.
We assert the schema literal, the schema/kind identity, and that
the `kind_` field matches the manifest row. We do NOT pin
`issued_at` (it is wall-clock-dependent) nor `id` here -- those
are checked separately via the SHA-256 self-check below.

  $ for f in .test-math-coding/attestations/*.json; do
  >   python3 -c "
  > import sys, json, re
  > with open('$f') as g: d = json.load(g)
  > assert d['schema'] == 'math-coding/attestation-3.3', d['schema']
  > assert d['kind'] == 'attestation', d['kind']
  > assert re.fullmatch(r'[0-9a-f]{40}', d['subject']['candidate_tree']), d['subject']['candidate_tree']
  > assert d['subject']['materials_digest'] == '', d['subject']['materials_digest']
  > assert d['result'] in ('pass','fail'), d['result']
  > assert d['producer']['identity'], d['producer']
  > assert d['issued_at'].endswith('Z'), d['issued_at']
  > assert d['id'].startswith('sha256:') and len(d['id']) == 7 + 64, d['id']
  > print(d['subject']['decision'], d['subject']['obligation'], d['kind_'], 'ok')
  > "
  > done
  d1-onboarding d1-obl-acceptance review ok
  d1-onboarding d1-obl-noise review ok
  d2-rollout d2-obl-build test ok

The `id` field MUST equal `sha256:` + SHA-256 of the canonical JSON
of the body (excluding `id`). The canonical-JSON rule is the one
documented in AGENTS.md / source-map line 280-282 and
`lib/attestations/batch.ml::serialize`: sorted keys, no whitespace,
UTF-8 (no \uXXXX escapes for non-ASCII). This is the same rule the
Python upstream `scripts/generate-attestations.py::canonical_json`
applies; if our SHA matches Python's on the same input, the
canonicalization is byte-equivalent at the digest boundary.

  $ for f in .test-math-coding/attestations/*.json; do
  >   python3 -c "
  > import sys, hashlib, json
  > with open('$f') as g: d = json.load(g)
  > body = {k: v for k, v in d.items() if k != 'id'}
  > payload = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
  > expected = 'sha256:' + hashlib.sha256(payload).hexdigest()
  > assert d['id'] == expected, 'id=%s expected %s' % (d['id'], expected)
  > print(d['subject']['decision'], d['subject']['obligation'], 'id ok')
  > "
  > done
  d1-onboarding d1-obl-acceptance id ok
  d1-onboarding d1-obl-noise id ok
  d2-rollout d2-obl-build id ok

Row 2 has no 5th column in the manifest; the binary defaults it to
`pass` (per `lib/attestations/batch.ml::parse_row`). Assert that.

  $ python3 -c "
  > import json
  > with open('.test-math-coding/attestations/d1-onboarding-d1-obl-noise.json') as f:
  >   d = json.load(f)
  > assert d['result'] == 'pass', d['result']
  > print('row2 default result:', d['result'])
  > "
  row2 default result: pass

Re-running overwrites deterministically (no double-emission on
subsequent runs of the same row).

  $ mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --out="$MATH_CODING_ATTESTATIONS_DIR"
  wrote .test-math-coding/attestations/d1-onboarding-d1-obl-acceptance.json
  wrote .test-math-coding/attestations/d1-onboarding-d1-obl-noise.json
  wrote .test-math-coding/attestations/d2-rollout-d2-obl-build.json
  $ ls .test-math-coding/attestations | wc -l
  3

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
