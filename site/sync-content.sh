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

# Theory (8 basic + 3 advanced)
mkdir -p "$CONTENT/theory" "$CONTENT/theory-advanced"
cp "$REPO_ROOT/core/01-Theory"/*.md "$CONTENT/theory/"
cp "$REPO_ROOT/core/02-Theory-advanced"/*.md "$CONTENT/theory-advanced/"

# Core convention
cp "$REPO_ROOT/core/core.md" "$CONTENT/core.md"

# Agents
mkdir -p "$CONTENT/agents"
cp "$REPO_ROOT/agents/agents.md" "$CONTENT/agents/agents.md"
cp "$REPO_ROOT/agents/process.md" "$CONTENT/agents/process.md"
cp "$REPO_ROOT/agents/rigor-tools.md" "$CONTENT/agents/rigor-tools.md"

# ADRs — flatten adr/NNNN-name/decision.md to adr/NNNN-name.md
mkdir -p "$CONTENT/adr"
for d in "$REPO_ROOT/adr"/*/; do
    [ -f "$d/decision.md" ] || continue
    name=$(basename "$d")
    # Display-friendly title
    pretty=$(echo "$name" | sed 's/^[0-9]*-//' | tr '-' ' ')
    weight=$(echo "$name" | grep -oE '^[0-9]+' | sed 's/^0*//')
    cat > "$CONTENT/adr/${name}.md" <<HDR
---
title: "ADR ${pretty}"
description: "Architecture decision record"
weight: ${weight}
---

HDR
    cat "$d/decision.md" >> "$CONTENT/adr/${name}.md"
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