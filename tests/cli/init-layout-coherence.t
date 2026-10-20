The path resolver asked about the wrong project. Two defects,
one fixture.

Before: `lib/path_config.ml` ran its existence checks against the
process cwd. So `mathc init /srv/app`, launched from a directory
that happened to contain a legacy `decisions/`, scaffolded the
LEGACY tree inside `/srv/app` — the opposite of the documented v3.4
contract ("`mathc init .` scaffolds `.math-coding/decisions/`").

Also: the three resolvers answered three independent questions. A
directory holding `decisions/` but no `decisions/decision.yaml`
resolved the decisions dir to `decisions/` and the policy to
`.math-coding/policy.yaml`, so `mathc init` produced half a project
in each layout. `layout_of` now decides ONCE per project.

Also: `$MATH_CODING_ROOT` anchored several code paths
(`find_project_root`) but not the resolver, so
`MATH_CODING_ROOT=<repo> mathc gate` evaluated an empty project —
0 obligations against a repository holding 199 decisions.

Hermetic: every case `cd`s into a fresh `mktemp -d`, so the layout
choice is a function of that directory alone.

`mathc init DIR` gives a fresh DIR the v3.4 tree even when the
caller's cwd holds a legacy `decisions/`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d) && cd "$tmp"
  $ mkdir -p caller-decisions && cd caller-decisions
  $ mkdir -p ../target
  $ cd "$DUNE_SOURCEROOT"
  $ cd "$tmp/caller-decisions"
  $ mathc init "$tmp/target" --no-install 2>&1 | grep created | sed "s|$tmp|<TMP>|g"
  mathc init: created <TMP>/target/.math-coding/decisions, <TMP>/target/.math-coding/attestations
  $ test -d "$tmp/target/.math-coding/decisions" && echo "v3.4 layout: ok"
  v3.4 layout: ok
  $ test ! -d "$tmp/target/decisions" && echo "no legacy tree: ok"
  no legacy tree: ok

A target that already has a pre-3.4 tree keeps it — decisions,
attestations and policy all resolve to the legacy paths, and the
three agree.

  $ mkdir -p "$tmp/legacy/decisions" "$tmp/legacy/attestations" && touch "$tmp/legacy/decisions/decision.yaml"
  $ mathc init "$tmp/legacy" --merge --no-install 2>&1 | grep created | sed "s|$tmp|<TMP>|g"
  mathc init: created <TMP>/legacy/decisions, <TMP>/legacy/attestations
  $ test -f "$tmp/legacy/decisions/decision.yaml" && echo "legacy policy preserved"
  legacy policy preserved
  $ test ! -d "$tmp/legacy/.math-coding" && echo "no second layout: ok"
  no second layout: ok

Layout coherence on a half-migrated directory: `decisions/` without
a master policy is still one layout, not two.

  $ mkdir -p "$tmp/mixed/decisions"
  $ mathc init "$tmp/mixed" --no-install 2>&1 | grep created | sed "s|$tmp|<TMP>|g"
  mathc init: created <TMP>/mixed/decisions, <TMP>/mixed/attestations
  $ test ! -d "$tmp/mixed/.math-coding" && echo "single layout: ok"
  single layout: ok

$MATH_CODING_ROOT scopes the resolver for commands that take no
explicit path.

  $ mkdir -p "$tmp/root/decisions"
  $ cp "$DUNE_SOURCEROOT/decisions/version-sync-2026-10.yaml" "$tmp/root/decisions/one.yaml"
  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$tmp/root" mathc attest-batch --from=decisions --dry-run 2>/dev/null | wc -l
  4

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
