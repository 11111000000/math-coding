`mathc graph --decision=<id> [--format=dot|json]` walks the
relations graph starting from `<id>` across all eight §7
relation kinds (decision `graph-viewer-2026-10@1`).

The default format is DOT (`digraph "<id>" { ... }`); the
JSON form is the structural projection consumed by the
static site at `dist/graph.html`. An unknown id emits
`MC-POLICY-NOT-FOUND` on stderr and exits 1. The DOT form
emits an empty digraph for an unknown id and exits 0
(the operator decides what to do).

Exit codes follow OCAML_BEST_PRACTICES.md §4.3: 0 on
success, 1 on policy not-found, 2 on input error.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc graph --decision=bootstrap-v3@3 > /tmp/graph-bootstrap.dot
  $ grep -q '^digraph "bootstrap-v3@3"' /tmp/graph-bootstrap.dot \
  >   && grep -q '"bootstrap-v3" -> "infrastructure-honesty"' /tmp/graph-bootstrap.dot \
  >   && echo "graph dot: bootstrap-v3 emits a digraph with bootstrap-v3 -> infrastructure-honesty edge" \
  >   || echo "FAIL: digraph contents missing expected nodes / edges"
  graph dot: bootstrap-v3 emits a digraph with bootstrap-v3 -> infrastructure-honesty edge

  $ cd "$DUNE_SOURCEROOT"
  $ mathc graph --decision=bootstrap-v3@3 --format=json > /tmp/graph-bootstrap.json
  $ grep -q '"root":"bootstrap-v3"' /tmp/graph-bootstrap.json \
  >   && grep -q '"from":"bootstrap-v3"' /tmp/graph-bootstrap.json \
  >   && grep -q '"kind":"addresses"' /tmp/graph-bootstrap.json \
  >   && echo "graph json: root + edges + addresses kind all present" \
  >   || echo "FAIL: json shape missing required fields"
  graph json: root + edges + addresses kind all present

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc graph --decision=does-not-exist --format=json 2>&1 | grep -q 'MC-POLICY-NOT-FOUND'; then \
  >   echo "graph unknown-id: MC-POLICY-NOT-FOUND emitted"; \
  > else echo "FAIL: expected MC-POLICY-NOT-FOUND"; fi
  graph unknown-id: MC-POLICY-NOT-FOUND emitted
