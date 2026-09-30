mc packages [--format=text|json|html] walks decisions/ joined
against attestations/ and emits the package_list per
spec/semantics.md §`packages`. The text form begins with the
literal "math-coding packages" line; the JSON form is sorted by
key and carries as_of, counts, decisions, policy_id, source; the
HTML form embeds data-mc-package-count matching counts.total.
Acceptance gate for obligation packages-cli-dispatcher in
decisions/mc-packages-subcommand.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc packages --format=text | head -n 1
  math-coding packages
  $ mathc packages --format=json | jq -e 'has("as_of") and has("counts") and has("decisions") and has("policy_id") and has("source")'
  true
  $ mathc packages --format=json | jq -e '.counts.total > 0'
  true
  $ mathc packages --format=html | grep -qF 'data-mc-package-count="'
  $ count=$(mathc packages --format=json | jq '.counts.total')
  $ mathc packages --format=html | grep -qF "data-mc-package-count=\"$count\""
