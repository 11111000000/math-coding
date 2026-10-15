#!/usr/bin/env bash
# scripts/render.sh — build the math-coding site.
#
# Pipeline:
#   1. Build the mathc binary via `scripts/dev build`.
#   2. Run `mathc render --out dist/ --lang=all` to render the
#      site in English, Russian, and Chinese (any
#      site/<name>.ru.md or site/<name>.zh.md sibling is rendered
#      to dist/<name>.ru.html or dist/<name>.zh.html).
#   3. Copy `assets/style.css` to `dist/assets/style.css`.
#   4. Verify every expected file exists (per spec/semantics.md
#      §`render`).
#
# Usage:
#   scripts/render.sh           — uses local _build
#   nix develop .#test --command scripts/render.sh 

set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/4] building mathc..."
scripts/dev build

echo "[2/4] running mathc render..."
mkdir -p dist
# --lang=all emits the English .html, the Russian .ru.html, and
# the Chinese .zh.html for every article that has the
# corresponding source. Sites that do not yet ship a Russian or
# Chinese translation still get the English page; the .ru.html
# and .zh.html are omitted when their sources are absent. The
# index pages (index.html, index.ru.html, index.zh.html) are
# emitted unconditionally per language.
_build/install/default/bin/mathc render --out dist --lang=all

echo "[3/4] copying assets..."
mkdir -p dist/assets
cp -f assets/style.css dist/assets/style.css
cp -f assets/site.js dist/assets/site.js 2>/dev/null || true
# Copy any SVG illustrations (Phase 2 of site-quality-illustrations-2026-10
# plus future additions). The list is glob-derived so a new
# asset/*.svg is picked up without a script change; the verify
# pass at [4/4] catches missing files.
for svg in assets/*.svg; do
  [ -f "$svg" ] || continue
  cp -f "$svg" "dist/assets/$(basename "$svg")"
done

# [3.5/4] building dashboard + graph artefacts.
# The allowlist at [4/4] names three additional files that
# `mathc render` itself does not emit (they were reserved by
# commit d7f0334 for the dashboard and graph viewer decisions
# but the dispatcher was never wired to write them). Until the
# render dispatcher grows native support, we generate the three
# files here from commands that the kernel already ships:
#   * dist/dashboard.html wraps `mathc packages --format=html`
#     (a <section>...</section> fragment) in a minimal HTML
#     document with the site stylesheet and the live count
#     metadata as a visible header.
#   * dist/graph.json is the canonical relations-graph JSON
#     for the bootstrap policy (the root the visitor lands on
#     after a fresh `git clone`).
#   * dist/graph.html is a thin cytoscape.js viewer that
#     fetches graph.json and lays out the eight relation kinds
#     from spec/algebra-3.2.md §7.
# All three paths are static; no build step depends on them.
MATHC="${MATHC_BIN:-_build/install/default/bin/mathc}"
if [ -x "$MATHC" ]; then
  echo "[3.5/4] building dashboard + graph artefacts..."
  mkdir -p dist
  # dist/dashboard.html
  if "$MATHC" packages --format=html > dist/dashboard.body.html 2>/dev/null; then
    {
      printf '%s\n' '<!DOCTYPE html>'
      printf '%s\n' '<html lang="en">'
      printf '%s\n' '<head>'
      printf '%s\n' '<meta charset="utf-8">'
      printf '%s\n' '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
      printf '%s\n' '<base href="/math-coding/">'
      printf '%s\n' '<title>Dashboard &mdash; math-coding</title>'
      printf '%s\n' '<link rel="stylesheet" href="assets/style.css">'
      printf '%s\n' '</head>'
      printf '%s\n' '<body>'
      printf '%s\n' '<main class="site-main">'
      printf '%s\n' '<header class="mathc-dashboard-head"><h1>math-coding dashboard</h1>'
      printf '%s\n' '<p class="mathc-meta">Live obligation counts across all active decisions; the same store that powers <a href="packages.html">packages.html</a> and <code>mathc self-check</code>.</p>'
      printf '%s\n' '</header>'
      cat dist/dashboard.body.html
      printf '%s\n' '</main>'
      printf '%s\n' '</body>'
      printf '%s\n' '</html>'
    } > dist/dashboard.html
    rm -f dist/dashboard.body.html
  else
    echo "  WARN: $MATHC packages --format=html failed; dashboard.html not written" >&2
  fi
  # dist/graph.json
  if "$MATHC" graph --decision=bootstrap-v3 --format=json > dist/graph.json 2>/dev/null; then
    :
  else
    echo "  WARN: $MATHC graph --format=json failed; graph.json not written" >&2
  fi
  # dist/graph.html — static cytoscape.js viewer over graph.json
  cat > dist/graph.html <<'GRAPH_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<base href="/math-coding/">
<title>Decision Graph &mdash; math-coding</title>
<link rel="stylesheet" href="assets/style.css">
<script defer src="https://cdn.jsdelivr.net/npm/cytoscape@3.30.2/dist/cytoscape.min.js"></script>
<style>
  #mathc-graph { width: 100%; height: 80vh; min-height: 480px;
                border: 1px solid #8b3a3a; border-radius: 4px;
                background: #fbfaf6; }
  .mathc-graph-legend { font-size: 0.85rem; color: #555;
                        margin: 1rem 0; }
  .mathc-graph-legend code { background: #f3efe6; padding: 0 0.3rem;
                             border-radius: 2px; }
</style>
</head>
<body>
<main class="site-main">
<header class="mathc-graph-head">
<h1>Decision relations graph</h1>
<p class="mathc-meta">Bootstrap policy (<code>bootstrap-v3@3</code>) and its transitive impact list. Eight relation kinds from <a href="spec/algebra-3.2.html">spec/algebra-3.2.html §7</a>:
<code>addresses</code>, <code>supersedes</code>, <code>revises</code>, <code>refines</code>, <code>depends_on</code>, <code>conflicts_with</code>, <code>implements</code>, <code>verifies</code>. Back-edges (cycles) are rendered in oxblood.</p>
<p class="mathc-graph-legend">Click a node to highlight its neighbours. Drag to rearrange. Scroll to zoom. The data source is <a href="graph.json">graph.json</a> (canonical JSON projection from <code>mathc graph --format=json</code>).</p>
</header>
<div id="mathc-graph" aria-label="Decision relations graph"></div>
<script>
(async () => {
  const r = await fetch('graph.json');
  const g = await r.json();
  const cy = cytoscape({
    container: document.getElementById('mathc-graph'),
    elements: [
      ...g.nodes.map(n => ({ data: { id: n.id, label: n.label || n.id } })),
      ...g.edges.map(e => ({ data: { id: e.from + '->' + e.to,
                                     source: e.from, target: e.to, kind: e.kind } })),
    ],
    style: [
      { selector: 'node', style: { 'label': 'data(label)', 'font-size': '10px',
                                   'background-color': '#8b3a3a', 'color': '#222',
                                   'text-valign': 'bottom', 'text-halign': 'center',
                                   'text-margin-y': 4 } },
      { selector: 'edge', style: { 'curve-style': 'bezier', 'width': 1.5,
                                   'line-color': '#aaa', 'target-arrow-color': '#aaa',
                                   'target-arrow-shape': 'triangle',
                                   'label': 'data(kind)', 'font-size': '8px',
                                   'color': '#777', 'text-rotation': 'autorotate' } },
      { selector: 'edge[kind="supersedes"]', style: { 'line-color': '#8b3a3a',
                                                       'target-arrow-color': '#8b3a3a' } },
      { selector: ':selected', style: { 'background-color': '#222',
                                        'line-color': '#222',
                                        'target-arrow-color': '#222' } },
    ],
    layout: { name: 'cose', animate: false, padding: 30,
              nodeRepulsion: 8000, idealEdgeLength: 100 },
  });
  cy.on('tap', 'node', evt => {
    const n = evt.target;
    cy.elements().removeClass('mathc-highlight mathc-fade');
    const nb = n.closedNeighborhood();
    cy.elements().difference(nb).addClass('mathc-fade');
    nb.addClass('mathc-highlight');
  });
  cy.on('tap', evt => {
    if (evt.target === cy) {
      cy.elements().removeClass('mathc-highlight mathc-fade');
    }
  });
  // cycle back-edge annotation
  if (g._cycle) {
    const note = document.createElement('p');
    note.className = 'mathc-graph-legend';
    note.innerHTML = '<strong>Cycle detected.</strong> The graph walker found a back-edge to an ancestor in the BFS path; the kernel annotates <code>_cycle: true</code> on the JSON projection.';
    document.querySelector('.mathc-graph-head').appendChild(note);
  }
})();
</script>
<style>
  .mathc-fade { opacity: 0.2; }
  .mathc-highlight { 'background-color': #222; }
</style>
</main>
</body>
</html>
GRAPH_HTML
fi

echo "[4/4] verifying dist/..."

required=(
  dist/index.html
  dist/index.ru.html
  dist/index.zh.html
  dist/axioms.html
  dist/methodology.html
  dist/manifesto.html
  dist/foundations.html
  dist/workflow.html
  dist/faq.html
  dist/readme.html
  dist/contributing.html
  dist/bootstrap-gate.html
  dist/install.html
  dist/packages.html
  dist/differences.html
  dist/assets/style.css
  dist/index.json
  dist/dashboard.html
  dist/graph.html
  dist/graph.json
)

# Per-decision pages — meta files excluded (matches lib/packages.ml)
# Uses the YAML `id:` field, not the filename, because some
# decisions keep a `-<date>` suffix in the filename but the
# render path strips it (e.g., `exit-code-symmetry-2026-10.yaml`
# with `id: exit-code-symmetry` produces
# `dist/decisions/exit-code-symmetry.html`).
for d in decisions/*.yaml decisions/*.yml decisions/*.json; do
  [ -f "$d" ] || continue
  base=$(basename "$d")
  case "$base" in
    decision.yaml|obligations.yaml|obligation-count-reconcile.yaml|gate-attestation-store-fill-decision.yaml|ONBOARDING.md|rationale.md) continue ;;
  esac
  decision_id=$(awk '/^id:[[:space:]]/{print $2; exit}' "$d" 2>/dev/null)
  if [ -z "$decision_id" ]; then
    # Fall back to filename for non-YAML/legacy files.
    decision_id=$(basename "$d" .yaml)
    decision_id=$(basename "$decision_id" .yml)
    decision_id=$(basename "$decision_id" .json)
  fi
  required+=( "dist/decisions/${decision_id}.html" )
done

# Per-axiom pages — index.md excluded
for a in axioms/*.md; do
  [ -f "$a" ] || continue
  base=$(basename "$a" .md)
  case "$base" in
    index) continue ;;
  esac
  required+=( "dist/axioms/${base}.html" )
done

# Russian siblings — only when the source `<name>.ru.md` exists.
# The bilingual_pairs_complete obligation is asserted by
# tests/render.ml; the allowlist here mirrors that policy.
for s in site/*.ru.md; do
  [ -f "$s" ] || continue
  base=$(basename "$s" .ru.md)
  required+=( "dist/${base}.ru.html" )
done

# Chinese siblings — only when the source `<name>.zh.md` exists.
# Mirrors the Russian-sibling allowlist above.
for s in site/*.zh.md; do
  [ -f "$s" ] || continue
  base=$(basename "$s" .zh.md)
  required+=( "dist/${base}.zh.html" )
done

missing=0
for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "  MISSING: $f"
    missing=$((missing + 1))
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "render incomplete: $missing missing files" >&2
  exit 2
fi

echo "render OK: dist/ contains ${#required[@]} files."
echo ""
echo "preview locally:"
echo "  python3 -m http.server -d dist/ 8000"