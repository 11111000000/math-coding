#!/bin/sh
# math-coding site — content sync script.
# Run from the site/ directory.
# Copies content from main repository into site/content/ for Hugo build.
#
# Source of truth stays in the main repository. This script
# only assembles content for static site generation; it never
# modifies the source.

set -e

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SITE_DIR/.." && pwd)"
CONTENT="$SITE_DIR/content"

# Theory (8 basic + 3 advanced) — flatten to lowercase slugs
mkdir -p "$CONTENT/theory" "$CONTENT/theory-advanced"
for f in "$REPO_ROOT/core/01-Theory"/*.md; do
    [ -f "$f" ] || continue
    # Lowercase the filename, keep hyphens
    base=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
    target="$CONTENT/theory/${base}.md"
    cat > "$target" <<HDR
---
title: "$(grep -E '^# Theory [0-9]+' "$f" | head -1 | sed 's/^# //')"
description: "Theory document"
---

HDR
    cat "$f" >> "$target"
done

for f in "$REPO_ROOT/core/02-Theory-advanced"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
    target="$CONTENT/theory-advanced/${base}.md"
    cat > "$target" <<HDR
---
title: "$(grep -E '^# Theory [0-9]+' "$f" | head -1 | sed 's/^# //')"
description: "Advanced theory"
---

HDR
    cat "$f" >> "$target"
done

# Core convention
cat > "$CONTENT/core/_index.md.tmp" <<'EOF'
---
title: "Core"
description: "The convention itself — every rule grounded in mathematics"
---
EOF
# Preserve the existing _index.md for core (it's hand-curated)
mv "$CONTENT/core/_index.md.tmp" "$CONTENT/core/_index.md.new" 2>/dev/null || true
# Actually, core/ has its own _index.md from manual editing; don't overwrite
rm -f "$CONTENT/core/_index.md.new"

cp "$REPO_ROOT/core/core.md" "$CONTENT/core.md"

# Agents
mkdir -p "$CONTENT/agents"
for f in agents.md process.md rigor-tools.md; do
    title=$(grep -E '^# ' "$REPO_ROOT/agents/$f" | head -1 | sed 's/^# //')
    case "$f" in
        agents.md) target="$CONTENT/agents/_index.md" ;;
        process.md) target="$CONTENT/agents/process.md" ;;
        rigor-tools.md) target="$CONTENT/agents/rigor-tools.md" ;;
    esac
    cat > "$target" <<HDR
---
title: "$title"
description: "Agent instructions"
---

HDR
    cat "$REPO_ROOT/agents/$f" >> "$target"
done

# ADRs — flatten adr/NNNN-name/decision.md to adr/<slug>.md
mkdir -p "$CONTENT/adr"
for d in "$REPO_ROOT/adr"/*/; do
    [ -f "$d/decision.md" ] || continue
    name=$(basename "$d")
    # Lowercase slug: 0001-fractal-property
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    weight=$(echo "$name" | grep -oE '^[0-9]+' | sed 's/^0*//')
    # Display title (no ADR- prefix; weight is implicit in filename)
    pretty=$(echo "$name" | sed 's/^[0-9]*-//' | tr '-' ' ')
    cat > "$CONTENT/adr/${slug}.md" <<HDR
---
title: "$pretty"
description: "Architecture decision record"
weight: ${weight:-0}
---

HDR
    cat "$d/decision.md" >> "$CONTENT/adr/${slug}.md"
done

# Examples — render refinement.md as a page
mkdir -p "$CONTENT/examples"
for d in "$REPO_ROOT/examples"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "external-project" ] && continue
    if [ -f "$d/refinement.md" ]; then
        title=$(grep -E "^# " "$d/refinement.md" | head -1 | sed 's/^# //')
        pretty_title=$(echo "$title" | sed 's/Refinement: //')
        cp "$d/refinement.md" "$CONTENT/examples/${name}.md"
        sed -i "0,/^# /{s|^# .*|# ${pretty_title}|}" "$CONTENT/examples/${name}.md"
    fi
done

# External project example
if [ -d "$REPO_ROOT/examples/external-project/example-packet" ]; then
    cp "$REPO_ROOT/examples/external-project/example-packet/refinement.md" \
       "$CONTENT/examples/external-project.md"
fi

# Integrations
mkdir -p "$CONTENT/integrations"
for f in "$REPO_ROOT/docs/integrations"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    cp "$f" "$CONTENT/integrations/${name}.md"
done

echo "Content sync complete."
ls -la "$CONTENT"