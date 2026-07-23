#!/bin/sh
# meta/site-build.sh — math-coding documentation site build script.
#
# Pure POSIX shell + pandoc + awk. No JS framework runtime.
# Outputs ./dist/ ready for GitHub Pages (or any static host).
#
# Run:    sh meta/site-build.sh
# Output: dist/
#
# axiom A3 (Material Basis): plain text + git + POSIX.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

DIST="$REPO_ROOT/dist"
SRC="$REPO_ROOT/site"

# yq abstraction: callers use `yaml_get <file> <key>`.
# Implemented in pure awk for POSIX/A3 portability (no yq needed).
yaml_get() {
    _yg_file="$1"
    _yg_key="$2"
    awk -v k="^${_yg_key}:" '
        $0 ~ k {
            sub(k, "")
            sub(/^[[:space:]]+/, "")
            if ($0 ~ /^"/) {
                gsub(/^"/, "")
                gsub(/"$/, "")
            }
            print
            exit
        }
    ' "$_yg_file"
}

# Get first application SHA from a packet.yaml (axiom A5 witness).
yaml_applications_sha() {
    _ya_file="$1"
    awk '
        /^applications:/ { in_app=1; next }
        in_app && /^[[:space:]]*-[[:space:]]*sha:/ {
            sub(/.*sha:[[:space:]]*/, "")
            gsub(/^"/, ""); gsub(/"$/, "")
            print
            exit
        }
        in_app && /^[^[:space:]]/ { exit }
    ' "$_ya_file"
}

# Get array value (e.g. depends_on) as space-separated list.
yaml_array() {
    _ya_file="$1"
    _ya_key="$2"
    awk -v k="^${_ya_key}:" '
        $0 ~ k {
            sub(k, "")
            sub(/^[[:space:]]+/, "")
            if ($0 ~ /^\[/ && $0 ~ /\]$/) {
                sub(/^\[/, "")
                sub(/\]$/, "")
                gsub(/,/, " ")
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                print
                exit
            }
            if ($0 == "") exit
        }
    ' "$_ya_file"
}

log() {
    printf "build: %s\n" "$*"
}

fail() {
    printf "build: ERROR: %s\n" "$*" >&2
    exit 2
}

# Tool check (axiom A3).
command -v pandoc >/dev/null 2>&1 || fail "pandoc not found"
command -v git >/dev/null    >/dev/null 2>&1 || fail "git not found"
command -v awk >/dev/null    >/dev/null 2>&1 || fail "awk not found"

log "preparing $DIST"
rm -rf "$DIST"
mkdir -p "$DIST" \
         "$DIST/assets/css" \
         "$DIST/assets/js/pure" \
         "$DIST/assets/js/components" \
         "$DIST/assets/fonts" \
         "$DIST/data" \
         "$DIST/packets"

# Copy site/ as the static base (HTML pages + assets/).
log "copying site/*.html"
for f in "$SRC"/*.html; do
    [ -f "$f" ] || continue
    cp "$f" "$DIST/"
done

log "copying site/assets/ (except fonts/, handled separately)"
test -d "$SRC/assets/css" && cp -r "$SRC/assets/css" "$DIST/assets/"
test -d "$SRC/assets/js"  && cp -r "$SRC/assets/js"  "$DIST/assets/"

# Copy fonts if they exist in source (vendored woff2).
if [ -d "$SRC/assets/fonts" ]; then
    log "copying vendored fonts"
    cp -r "$SRC/assets/fonts" "$DIST/assets/"
fi

# Render MD sources via pandoc --mathml (fragment mode for marker injection).
render_md() {
    _src="$1"
    _dst="$2"
    pandoc "$_src" \
        --from gfm \
        --to html5 \
        --mathml \
        --no-highlight \
        --output "$_dst"
}

# Inject a rendered MD fragment into a page HTML at <!--MARKER-NAME-->.
#   _page  HTML file with marker
#   _frag  HTML fragment (just the body content of MD)
#   _name  marker name (without the <!--...--> wrappers)
inject_marker() {
    _page="$1"
    _frag="$2"
    _name="$3"
    _marker="<!--MARKER-${_name}-->"
    awk -v marker="$_marker" -v frag="$_frag" '
        BEGIN {
            while ((getline line < frag) > 0) {
                frag_lines[++fc] = line
            }
            close(frag)
        }
        {
            if (index($0, marker)) {
                for (i = 1; i <= fc; i++) print frag_lines[i]
                next
            }
            print
        }
    ' "$_page" > "${_page}.tmp" && mv "${_page}.tmp" "$_page"
}

# Render MD fragments then inject into page templates.
log "rendering core/spec/*.md and KNOWN_LIMITATIONS.md as fragments"
frag="$(mktemp)"
trap 'rm -f "$frag"' EXIT

# axioms.md -> site/axioms.html -> dist/axioms.html (marker: AXIOMS)
if [ -f "$REPO_ROOT/core/spec/axioms.md" ] && [ -f "$SRC/axioms.html" ]; then
    render_md "$REPO_ROOT/core/spec/axioms.md" "$frag"
    cp "$SRC/axioms.html" "$DIST/axioms.html"
    inject_marker "$DIST/axioms.html" "$frag" "AXIOMS"
fi

# fsm.md -> site/fsm.html -> dist/fsm.html (marker: FSM)
if [ -f "$REPO_ROOT/core/spec/fsm.md" ] && [ -f "$SRC/fsm.html" ]; then
    render_md "$REPO_ROOT/core/spec/fsm.md" "$frag"
    cp "$SRC/fsm.html" "$DIST/fsm.html"
    inject_marker "$DIST/fsm.html" "$frag" "FSM"
fi

# KNOWN_LIMITATIONS.md -> site/limitations.html -> dist/limitations.html
if [ -f "$REPO_ROOT/KNOWN_LIMITATIONS.md" ] && [ -f "$SRC/limitations.html" ]; then
    render_md "$REPO_ROOT/KNOWN_LIMITATIONS.md" "$frag"
    cp "$SRC/limitations.html" "$DIST/limitations.html"
    inject_marker "$DIST/limitations.html" "$frag" "LIMITATIONS"
fi

# Other core/spec/*.md pages (packet-schema, decision-modes, etc.) are not
# part of the main nav; skip them in v1.

# Walk math/*/ and emit a packet page per packet.
log "scanning math/ for packets"
packet_count=0
manifest="$DIST/data/packets-manifest.json"
mkdir -p "$(dirname "$manifest")"
: > "$manifest.tmp"

for d in "$REPO_ROOT/math"/*; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ "$name" = "README.md" ] && continue
    [ -f "$d/packet.yaml" ] || continue

    packet_count=$((packet_count + 1))
    out_dir="$DIST/packets/$name"
    mkdir -p "$out_dir"

    yaml_file="$d/packet.yaml"
    task_id="$(yaml_get "$yaml_file" task_id)"
    title="$(yaml_get "$yaml_file" title)"
    lifecycle="$(yaml_get "$yaml_file" lifecycle)"
    axiom="$(yaml_get "$yaml_file" axiom)"
    depends_on_list="$(yaml_array "$yaml_file" depends_on)"
    apps_sha="$(yaml_applications_sha "$yaml_file")"

    # Render MD files in the packet (decision/refinement/task).
    for f in decision.md refinement.md task.md; do
        if [ -f "$d/$f" ]; then
            render_md "$d/$f" "$out_dir/${f%.md}.html"
        fi
    done

    # Render assumptions.yaml to a flat HTML list (no pandoc for YAML).
    assumptions_html=""
    if [ -f "$d/assumptions.yaml" ]; then
        assumptions_html="$out_dir/assumptions.html"
        awk -v file="$d/assumptions.yaml" '
            BEGIN {
                print "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><meta name=\"color-scheme\" content=\"light dark\"><title>assumptions · '"$name"' · math-coding v0.992</title>"
                print "<link rel=\"stylesheet\" href=\"/assets/css/tokens.css\">"
                print "<link rel=\"stylesheet\" href=\"/assets/css/base.css\">"
                print "<link rel=\"stylesheet\" href=\"/assets/css/layout.css\">"
                print "<link rel=\"stylesheet\" href=\"/assets/css/components.css\">"
                print "</head><body class=\"page\">"
                print "<header class=\"site-header\"><div class=\"site-header__inner\">"
                print "<a class=\"wordmark\" href=\"/\"><span class=\"wordmark-name\">math-coding</span><span class=\"wordmark-version\">v0.992</span></a>"
                print "<nav class=\"site-nav\"><a href=\"/\">home</a><a href=\"/axioms.html\">axioms</a><a href=\"/packets.html\">packets</a></nav>"
                print "</div></header><main>"
                print "<h1>" "'"$name"'" "</h1>"
                print "<p>Assumptions — five epistemic markers grounded in evidence.</p>"
            }
            /^[[:space:]]*-[[:space:]]*id:/ {
                id=$0
                sub(/.*id:[[:space:]]*/, "", id)
                sub(/^"/, ""); sub(/"$/, "")
                getline stmt
                getline status
                getline epi
                getline conf
                getline ev
                # extract
                gsub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*"?/, "", id)
                sub(/^[[:space:]]+statement:[[:space:]]*/, "", stmt)
                sub(/^[[:space:]]+status:[[:space:]]*/, "", status)
                sub(/^[[:space:]]+epistemology:[[:space:]]*/, "", epi)
                sub(/^[[:space:]]+confidence:[[:space:]]*/, "", conf)
                sub(/^[[:space:]]+evidence:[[:space:]]*/, "", ev)
                gsub(/^"|"$/, "", stmt); gsub(/\\n/, "\n", stmt)
                gsub(/^"|"$/, "", ev); gsub(/\\n/, "\n", ev)
                print "<div class=\"assumption-row\">"
                print "<div class=\"assumption-row__id\">" id "</div>"
                print "<div class=\"assumption-row__statement\">" stmt "</div>"
                print "<div class=\"assumption-row__marker\" data-marker=\"" tolower(epi) "\">" tolower(epi) "</div>"
                print "</div>"
                # skip evidence/detail lines that follow
                while ((getline line) > 0) {
                    if (line ~ /^[[:space:]]*-[[:space:]]*id:/) { print ""; break }
                    if (line ~ /^[[:space:]]+evidence:/) continue
                }
            }
            END {
                print "</main></body></html>"
            }
        ' "$d/assumptions.yaml" > "$assumptions_html"
    fi

    # Generate a per-packet index.html (proof-term 5-column grid).
    {
        echo '<!doctype html>'
        echo '<html lang="en">'
        echo '<head>'
        echo '<meta charset="utf-8">'
        echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
        echo '<meta name="color-scheme" content="light dark">'
        echo "<title>${name} · math-coding v0.992</title>"
        echo '<link rel="stylesheet" href="/assets/css/tokens.css">'
        echo '<link rel="stylesheet" href="/assets/css/base.css">'
        echo '<link rel="stylesheet" href="/assets/css/layout.css">'
        echo '<link rel="stylesheet" href="/assets/css/components.css">'
        echo '</head>'
        echo '<body class="page">'
        echo '<header class="site-header"><div class="site-header__inner">'
        echo '<a class="wordmark" href="/"><span class="wordmark-name">math-coding</span><span class="wordmark-version">v0.992</span></a>'
        echo '<nav class="site-nav">'
        echo '<a href="/">home</a>'
        echo '<a href="/axioms.html">axioms</a>'
        echo '<a href="/packets.html">packets</a>'
        echo '</nav></div></header>'
        echo '<main>'
        echo "<h1>${name}</h1>"
        echo "<p style=\"font-family: var(--font-display); font-size: var(--text-md); font-weight: 600; margin-top:0\">${title}</p>"
        echo "<div style=\"display:flex;gap:1rem;align-items:center;flex-wrap:wrap;margin:1rem 0 2rem\">"
        echo "<span class=\"lifecycle-pill lifecycle-pill--$(echo "${lifecycle}" | tr '[:upper:]' '[:lower:]')\">${lifecycle}</span>"
        if [ -n "${axiom}" ]; then
            echo "<span class=\"sha-link\">axiom ${axiom}</span>"
        fi
        if [ -n "${apps_sha}" ]; then
            echo "<a class=\"sha-link\" href=\"https://github.com/11111000000/math-coding/commit/${apps_sha}\">sha ${apps_sha:0:7}</a>"
        fi
        echo "</div>"

        # 5-column proof-term grid (axiom Curry-Howard correspondence).
        echo '<div class="packet-grid">'
        echo '<div class="packet-grid__cell">'
        echo '<p class="packet-grid__label">packet.yaml — type signature</p>'
        echo '<pre style="font-size:0.78rem;max-height:24rem;overflow:auto">'
        sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$yaml_file"
        echo '</pre></div>'

        echo '<div class="packet-grid__cell">'
        echo '<p class="packet-grid__label">decision.md — the proposition</p>'
        if [ -f "$out_dir/decision.html" ]; then
            echo '<a href="./decision.html" class="sha-link">read full</a>'
        fi
        echo '</div>'

        echo '<div class="packet-grid__cell">'
        echo '<p class="packet-grid__label">refinement.md — the elaboration</p>'
        if [ -f "$out_dir/refinement.html" ]; then
            echo '<a href="./refinement.html" class="sha-link">read full</a>'
        fi
        echo '</div>'

        echo '<div class="packet-grid__cell">'
        echo '<p class="packet-grid__label">task.md — the goal</p>'
        if [ -f "$out_dir/task.html" ]; then
            echo '<a href="./task.html" class="sha-link">read full</a>'
        fi
        echo '</div>'

        echo '<div class="packet-grid__cell">'
        echo '<p class="packet-grid__label">assumptions.yaml — context Γ</p>'
        if [ -f "$out_dir/assumptions.html" ]; then
            echo '<a href="./assumptions.html" class="sha-link">read full</a>'
        fi
        echo '</div>'

        echo '</div>'  # packet-grid

        # nav back / forward
        echo '<p style="margin-top:2rem"><a href="/packets.html">← all packets</a></p>'

        # A6 probe stamp
        echo '<div class="probe-stamp">built from commit '"$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"' · axiom A6 self-application · <code>sh math-coding probe</code> exit 0</div>'

        echo '</main>'
        echo '</body>'
        echo '</html>'
    } > "$out_dir/index.html"

    # Append to manifest (JSON-lines format for portability).
    if [ -s "$manifest.tmp" ]; then
        echo "," >> "$manifest.tmp"
    fi
    manifest_id="$name"
    manifest_title="$title"
    manifest_lifecycle="$lifecycle"
    manifest_axiom="$axiom"
    manifest_sha="${apps_sha:-}"
    cat >> "$manifest.tmp" <<JSON
{
  "id": "$manifest_id",
  "title": "$manifest_title",
  "lifecycle": "$manifest_lifecycle",
  "axiom": "$manifest_axiom",
  "lastSha": "$manifest_sha",
  "depends_on": "$(echo "$depends_on_list" | tr ' ' ',')",
  "url": "/packets/$manifest_id/"
}
JSON
done

# Wrap the JSON-lines array into a JSON array.
{
    echo "["
    cat "$manifest.tmp"
    echo ""
    echo "]"
} > "$manifest"
rm -f "$manifest.tmp"

# Sanity-check manifest is valid JSON.
if ! command -v python3 >/dev/null 2>&1; then
    log "warning: python3 unavailable, skipping JSON sanity check"
else
    if python3 -c "import json,sys; json.load(open('$manifest'))" 2>/dev/null; then
        log "manifest JSON parses cleanly"
    else
        fail "manifest JSON failed to parse"
    fi
fi

# sitemap.xml + 404.html.
cat > "$DIST/sitemap.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
XML
for page in index axioms packets fsm limitations getting-started philosophy; do
    echo "  <url><loc>https://11111000000.github.io/math-coding/${page}.html</loc></url>" \
        >> "$DIST/sitemap.xml"
done
echo "</urlset>" >> "$DIST/sitemap.xml"

cat > "$DIST/404.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>404 — math-coding v0.992</title>
<link rel="stylesheet" href="/assets/css/tokens.css">
<link rel="stylesheet" href="/assets/css/base.css">
<link rel="stylesheet" href="/assets/css/layout.css">
<link rel="stylesheet" href="/assets/css/components.css">
</head>
<body class="page">
<header class="site-header"><div class="site-header__inner">
<a class="wordmark" href="/"><span class="wordmark-name">math-coding</span><span class="wordmark-version">v0.992</span></a>
</div></header>
<main>
<h1>404 — page not found</h1>
<p style="font-size: var(--text-prose); color: var(--ink-soft); max-width: 62ch">
That URL does not correspond to any axiom or packet.
The convention <code>does not pretend to be</code> what it is not.
</p>
<p><a href="/">← back to home</a></p>
</main>
</body>
</html>
EOF

log "build complete: $DIST"
log "$packet_count packet pages emitted"
log "manifest: $manifest"
