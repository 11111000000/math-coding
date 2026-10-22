scripts/generate-attestations.py honours
MATH_CODING_ATTESTATIONS_DIR (and MATH_CODING_DECISIONS_DIR
for parity). The script reads a TSV manifest
(`<decision><TAB><obligation><TAB><kind_><TAB><producer_identity>`)
from stdin and writes one attestation JSON per row to the
configured directory.

The cram shell's cwd is a bwrap tmp dir. python3 is on the
PATH.

`--help` returns usage and exits 0.

  $ cd "$DUNE_SOURCEROOT"
  $ python3 scripts/generate-attestations.py --help
  usage: generate-attestations [-h]
  
  Generate math-coding attestation JSON files from a TSV manifest on stdin. See
  module docstring for env-var semantics.
  
  options:
    -h, --help  show this help message and exit

Env var honoured: with MATH_CODING_ATTESTATIONS_DIR pointing
at a fresh tmp dir, the script writes JSONs there (not to
the math-coding tree). The script also declares the
MATH_CODING_DECISIONS_DIR env var for kernel parity even
though the script does not currently read decisions.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf /tmp/alt-attestations-test /tmp/alt-attestations-test-manifest.tsv
  $ python3 -c "open('/tmp/alt-attestations-test-manifest.tsv','w').write('smoke-attest\tattest-script-wrote-here\ttest\tsub-agent-A4\n')"
  $ MATH_CODING_ATTESTATIONS_DIR=/tmp/alt-attestations-test \
  >   python3 scripts/generate-attestations.py \
  >   < /tmp/alt-attestations-test-manifest.tsv \
  >   2>/dev/null
  $ test -f /tmp/alt-attestations-test/smoke-attest-attest-script-wrote-here.json \
  >   && echo "wrote JSON to env-var target"
  wrote JSON to env-var target
  $ grep -q '"decision":"smoke-attest"' \
  >   /tmp/alt-attestations-test/smoke-attest-attest-script-wrote-here.json \
  >   && echo "JSON body matches manifest decision"
  JSON body matches manifest decision
  $ grep -q '"id":"sha256:[0-9a-f]\{64\}"' \
  >   /tmp/alt-attestations-test/smoke-attest-attest-script-wrote-here.json \
  >   && echo "JSON carries sha256: + 64 hex chars id"
  JSON carries sha256: + 64 hex chars id

The script does NOT write to the math-coding tree's
attestations/ directory when MATH_CODING_ATTESTATIONS_DIR
is set elsewhere.

  $ cd "$DUNE_SOURCEROOT"
  $ test ! -e "$PWD/attestations/smoke-attest-attest-script-wrote-here.json" \
  >   && echo "math-coding tree untouched (env-var wins)"
  math-coding tree untouched (env-var wins)

Default fallback: with MATH_CODING_ATTESTATIONS_DIR unset,
the script writes to <parent-of-scripts>/attestations. Use
a sandbox copy so we don't pollute the real attestations/
tree.

  $ cd "$DUNE_SOURCEROOT"
  $ sandbox=$DUNE_SOURCEROOT/sandbox-generate-attestations-env-fallback
  $ rm -rf "$sandbox"
  $ mkdir -p "$sandbox/scripts" "$sandbox/attestations"
  $ cp scripts/generate-attestations.py "$sandbox/scripts/"
  $ python3 -c "open('$sandbox/manifest.tsv','w').write('smoke-default-fallback\tattest-default-fallback\ttest\tsub-agent-A4\n')"
  $ env -u MATH_CODING_ATTESTATIONS_DIR -u MATH_CODING_DECISIONS_DIR \
  >   python3 "$sandbox/scripts/generate-attestations.py" \
  >   < "$sandbox/manifest.tsv" \
  >   2>/dev/null
  $ test -f "$sandbox/attestations/smoke-default-fallback-attest-default-fallback.json" \
  >   && echo "default fallback writes to sandbox/attestations"
  default fallback writes to sandbox/attestations
  $ rm -rf "$sandbox" /tmp/alt-attestations-test /tmp/alt-attestations-test-manifest.tsv
