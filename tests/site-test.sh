#!/bin/sh
# tests/site-test.sh — math-coding site self-test (axiom A6).
#
# Verifies that:
#   1. site/ contains no binary assets (axiom A3).
#   2. site/ has no external CDN references (axiom A3).
#   3. CSS files do not exceed design invariants (no shadows, no
#      excessive border-radius or animations).
#   4. dist/ build exists and is consistent (only run after build).
#   5. packets-manifest.json count matches math/<packet>/ folders.
#   6. Each SHA in manifest resolves to a real git commit.
#   7. fsm.html or fsm.svg contains all 4 lifecycle states.
#   8. every .html in dist/ has <meta viewport> + <meta color-scheme>.
#
# axiom A6 (Self-Application) closes the loop: this script lives
# inside core/check/ (or tests/) and is invoked by tests/run.sh
# on every convention invocation.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT" || exit 2

DIST="${DIST:-$REPO_ROOT/dist}"
SITE="$REPO_ROOT/site"

fail() { printf "site-test: FAIL: %s\n" "$*" >&2; exit 1; }
ok()   { printf "site-test: ok: %s\n" "$*"; }

# === 1. site/ has no binary assets ===
for ext in png jpg jpeg gif pdf docx doc xls xlsx ppt pptx zip tar gz bz2 xz exe dmg; do
    found=$(find "$SITE" -type f -iname "*.$ext" 2>/dev/null)
    if [ -n "$found" ]; then
        fail "binary asset in site/: $found"
    fi
done
ok "no binary assets in site/"

# === 2. site/ has no external CDN references ===
# Allow https://github.com (commit links) and https://raw.githubusercontent.com (rare)
# Ban cdnjs, jsdelivr, unpkg, googleapis, google fonts CDN.
if grep -rEn 'cdnjs\.|jsdelivr\.|unpkg\.|googleapis\.|fonts\.googleapis\.com|fonts\.gstatic\.com' "$SITE" \
   >/dev/null 2>&1; then
    fail "external CDN reference found in site/"
fi
# Also ban <script src="https://... (except github.com)
if grep -rEn 'script[[:space:]]+src="https://(?!github\.com)' "$SITE" \
   >/dev/null 2>&1; then
    fail "external script src in site/"
fi
ok "no external CDN references in site/"

# === 3. CSS design invariants ===
# No box-shadow, no animation/transition > 100ms, no border-radius > 2px
# (lifecycle-pill is the only allowed 2px).
# Skip CSS comments and exclude declarations whose property matches
# the comment text.
strip_css_comments() {
    # Removes /* ... */ comments from a CSS stream.
    # Multi-line comment-aware.
    awk '
        BEGIN { in_comment = 0 }
        {
            line = $0
            while (1) {
                if (in_comment) {
                    pos = index(line, "*/")
                    if (pos == 0) { line = ""; break }
                    line = substr(line, pos + 2)
                    in_comment = 0
                } else {
                    pos = index(line, "/*")
                    if (pos == 0) break
                    endpos = index(substr(line, pos), "*/")
                    if (endpos == 0) {
                        line = substr(line, 1, pos - 1)
                        in_comment = 1
                        break
                    }
                    line = substr(line, 1, pos - 1) substr(line, pos + endpos + 1)
                }
            }
            if (line ~ /[^[:space:]]/) print line
        }
    ' "$1"
}

for css in $(find "$SITE/assets/css" -type f -name '*.css' 2>/dev/null); do
    tmp="$(mktemp)"
    strip_css_comments "$css" > "$tmp"

    if grep -nE 'box-shadow:[[:space:]]*[^n]' "$tmp" \
        | grep -vE 'box-shadow:[[:space:]]*none' >/dev/null 2>&1; then
        grep -nE 'box-shadow:' "$tmp" | head -5 >&2
        rm -f "$tmp"
        fail "box-shadow in $css (forbidden by site-design)"
    fi

    if grep -nE 'animation:[[:space:]]*[0-9.]+s|transition:[[:space:]]*[1-9][0-9]{2,}(ms|s)' "$tmp" \
       >/dev/null 2>&1; then
        grep -nE 'animation:[[:space:]]*[0-9.]+s|transition:[[:space:]]*[1-9][0-9]{2,}(ms|s)' "$tmp" \
           | head -5 >&2
        rm -f "$tmp"
        fail "animation/transition > 100ms in $css"
    fi

    if grep -nE 'border-radius:[[:space:]]*[3-9]px|border-radius:[[:space:]]*[1-9][0-9]' "$tmp" \
       >/dev/null 2>&1; then
        grep -nE 'border-radius:[[:space:]]*[3-9]px|border-radius:[[:space:]]*[1-9][0-9]' "$tmp" \
           | head -5 >&2
        rm -f "$tmp"
        fail "border-radius > 2px in $css"
    fi

    rm -f "$tmp"
done
ok "CSS invariants hold (no shadows, animation ≤ 100ms, radius ≤ 2px)"

# === 3b. server-side math equation tagging ===
# dist/fsm.html and dist/axioms.html must have at least one
# class="math-equation" block (rendered server-side, no JS needed).
if [ -d "$DIST" ]; then
    for page in fsm axioms; do
        if [ -f "$DIST/${page}.html" ]; then
            count=$(grep -c 'class="math-equation"' "$DIST/${page}.html" || true)
            if [ "$count" -lt 1 ]; then
                fail "$page.html: no server-tagged math-equation blocks"
            fi
        fi
    done
    ok "math-equation blocks tagged server-side (no JS heuristic needed)"
fi

# === 4. dist/ exists if -e flag passed ===
DIST_REQUIRED="${DIST_REQUIRED:-yes}"
if [ "$DIST_REQUIRED" = "yes" ]; then
    [ -d "$DIST" ] || fail "dist/ directory missing (run sh meta/site-build.sh)"
fi
ok "dist/ exists"

# === 4b. <!--PACKET_COUNT--> substituted in index.html ===
if [ -d "$DIST" ] && [ -f "$DIST/index.html" ]; then
    if grep -q '<!--PACKET_COUNT-->' "$DIST/index.html"; then
        fail "index.html: <!--PACKET_COUNT--> placeholder not substituted"
    fi
    ok "index.html: packet count substituted"
fi

# === 4c. every public HTML page has full 7-link nav ===
if [ -d "$DIST" ]; then
    for f in "$DIST"/*.html; do
        [ -f "$f" ] || continue
        case "$(basename "$f")" in
            404.html) continue ;;  # 404 has different layout by design
        esac
        for path in '/' '/axioms.html' '/packets.html' '/fsm.html' \
                     '/getting-started.html' '/philosophy.html' \
                     '/limitations.html'; do
            if ! grep -qF "href=\"$path\"" "$f"; then
                fail "$(basename "$f"): missing nav link to $path"
            fi
        done
    done
    ok "all public pages have full 7-link nav"
fi

# === 5. manifest count matches math/ ===
if [ -f "$DIST/data/packets-manifest.json" ]; then
    expected=$(find "$REPO_ROOT/math" -mindepth 1 -maxdepth 1 -type d \
        ! -name 'README.md' 2>/dev/null | wc -l)
    actual=$(grep -o '"id":' "$DIST/data/packets-manifest.json" 2>/dev/null | wc -l)
    if [ "$expected" -ne "$actual" ]; then
        fail "manifest count $actual != math/*/ count $expected"
    fi
    ok "manifest packet count matches math/ ($actual packets)"
else
    printf "site-test: skip: no manifest (build not run)\n"
fi

# === 6. every SHA in manifest resolves to git ===
if [ -f "$DIST/data/packets-manifest.json" ]; then
    bad_shas=0
    for sha in $(grep -oE '"lastSha":[[:space:]]*"[a-f0-9]+"' \
                 "$DIST/data/packets-manifest.json" \
                 | sed 's/.*"lastSha":[[:space:]]*"\([a-f0-9]*\)".*/\1/' \
                 | sort -u); do
        if [ -z "$sha" ]; then continue; fi
        if ! git -C "$REPO_ROOT" cat-file -e "$sha" 2>/dev/null; then
            bad_shas=$((bad_shas + 1))
            printf "  bad SHA: %s\n" "$sha" >&2
        fi
    done
    if [ "$bad_shas" -gt 0 ]; then
        fail "$bad_shas SHA(s) in manifest not resolvable in git"
    fi
    ok "all manifest SHAs resolve in git"
fi

# === 7. fsm.html / fsm.svg has 4 lifecycle state names ===
for state in draft applied retired abandoned; do
    found=0
    if [ -f "$DIST/fsm.html" ]; then
        if grep -E "\b${state}\b" "$DIST/fsm.html" >/dev/null 2>&1; then
            found=1
        fi
    fi
    if [ -f "$DIST/assets/fsm/fsm.svg" ] && [ "$found" -eq 0 ]; then
        if grep -E "\b${state}\b" "$DIST/assets/fsm/fsm.svg" >/dev/null 2>&1; then
            found=1
        fi
    fi
    if [ "$found" -eq 0 ]; then
        fail "lifecycle state '$state' missing from FSM diagram"
    fi
done
ok "FSM diagram contains all 4 lifecycle states"

# === 8. every dist .html has meta viewport + color-scheme ===
if [ -d "$DIST" ]; then
    bad=0
    for f in "$DIST"/*.html; do
        [ -f "$f" ] || continue
        if ! grep -q 'name="viewport"' "$f"; then
            bad=$((bad + 1)); printf "  missing viewport: %s\n" "$f" >&2
        fi
        if ! grep -q 'name="color-scheme"' "$f"; then
            bad=$((bad + 1)); printf "  missing color-scheme: %s\n" "$f" >&2
        fi
    done
    if [ "$bad" -gt 0 ]; then
        fail "$bad HTML file(s) missing required meta tags"
    fi
    ok "all dist HTML files have viewport + color-scheme meta"
fi

echo "site-test: PASS (axiom Self-Application holds for site)"
