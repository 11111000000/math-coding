mathc packages [--format=text|json|html] walks decisions/ joined
against attestations/ and emits the package_list per
spec/semantics.md §`packages`. The text form begins with the
literal "math-coding packages" line; the JSON form is sorted by
key and carries as_of, counts, decisions, policy_id, source; the
HTML form embeds data-mathc-package-count matching counts.total.
Acceptance gate for obligation packages-cli-dispatcher in
decisions/mathc-packages-subcommand.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=text | head -n 1
  math-coding packages
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=json | jq -e 'has("as_of") and has("counts") and has("decisions") and has("policy_id") and has("source")'
  true
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=json | jq -e '.counts.total > 0'
  true
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=html | grep -qF 'data-mathc-package-count="'
  $ count=$($INSIDE_DUNE/bin/mathc.exe packages --format=json | jq '.counts.total')
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=html | grep -qF "data-mathc-package-count=\"$count\""
