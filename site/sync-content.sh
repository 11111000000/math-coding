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
    base=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
    target="$CONTENT/theory/${base}.md"
    # Display title (e.g., "Predicate and Invariant" without "Theory 01 — ")
    title=$(grep -E '^# Theory [0-9]+' "$f" | head -1 | sed -E 's/^# Theory [0-9]+ — //' | sed -E 's/^# Theory [0-9]+: //')
    cat > "$target" <<HDR
---
title: "$title"
description: "Theory document"
weight: $(echo "$base" | grep -oE '^[0-9]+' | sed 's/^0*//')
---

HDR
    # Skip the first H1 (we use title from frontmatter instead)
    sed '1,/^# /d' "$f" >> "$target"
done

for f in "$REPO_ROOT/core/02-Theory-advanced"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
    target="$CONTENT/theory-advanced/${base}.md"
    title=$(grep -E '^# Theory [0-9]+' "$f" | head -1 | sed -E 's/^# Theory [0-9]+ — //' | sed -E 's/^# Theory [0-9]+: //')
    cat > "$target" <<HDR
---
title: "$title"
description: "Advanced theory"
weight: $(echo "$base" | grep -oE '^[0-9]+' | sed 's/^0*//')
---

HDR
    sed '1,/^# /d' "$f" >> "$target"
done

# Core convention
cp "$REPO_ROOT/core/core.md" "$CONTENT/core.md"

# Agents
mkdir -p "$CONTENT/agents"
for f in agents.md process.md rigor-tools.md; do
    case "$f" in
        agents.md) target="$CONTENT/agents/_index.md" ;;
        process.md) target="$CONTENT/agents/process.md" ;;
        rigor-tools.md) target="$CONTENT/agents/rigor-tools.md" ;;
    esac
    # Display-friendly title
    case "$f" in
        agents.md) title="Notes for AI agents" ;;
        process.md) title="Process for opening a packet" ;;
        rigor-tools.md) title="Rigor tools" ;;
    esac
    cat > "$target" <<HDR
---
title: "$title"
description: "Agent instructions"
---

HDR
    sed '1,/^# /d' "$REPO_ROOT/agents/$f" >> "$target"
done

# ADRs — flatten adr/NNNN-name/decision.md to adr/<slug>.md
mkdir -p "$CONTENT/adr"
for d in "$REPO_ROOT/adr"/*/; do
    [ -f "$d/decision.md" ] || continue
    name=$(basename "$d")
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    weight=$(echo "$name" | grep -oE '^[0-9]+' | sed 's/^0*//')
    # Display title (just the name without numeric prefix)
    pretty=$(echo "$name" | sed 's/^[0-9]*-//' | tr '-' ' ')
    cat > "$CONTENT/adr/${slug}.md" <<HDR
---
title: "$pretty"
description: "Architecture decision record"
weight: ${weight:-0}
---

HDR
    # Skip the original H1 ("# Decision: 0001 — Fractal Property")
    sed '1,/^# /d' "$d/decision.md" >> "$CONTENT/adr/${slug}.md"
done

# Examples — render refinement.md as a page
mkdir -p "$CONTENT/examples"
for d in "$REPO_ROOT/examples"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "external-project" ] && continue
    if [ -f "$d/refinement.md" ]; then
        case "$name" in
            modal-dialog) pretty_title="Modal Dialog" ;;
            self-application) pretty_title="Self-Application" ;;
            schema-self-application) pretty_title="Schema Self-Application" ;;
            *) pretty_title=$(echo "$name" | tr '-' ' ') ;;
        esac
        cat > "$CONTENT/examples/${name}.md" <<HDR
---
title: "$pretty_title"
description: "Reference example"
---

HDR
        sed '1,/^# /d' "$d/refinement.md" >> "$CONTENT/examples/${name}.md"
    fi
done

# External project example
if [ -d "$REPO_ROOT/examples/external-project/example-packet" ]; then
    cat > "$CONTENT/examples/external-project.md" <<HDR
---
title: "External Project"
description: "Demonstrates external-project mode"
---

HDR
    sed '1,/^# /d' "$REPO_ROOT/examples/external-project/example-packet/refinement.md" \
        >> "$CONTENT/examples/external-project.md"
fi

# Integrations
mkdir -p "$CONTENT/integrations"
for f in "$REPO_ROOT/docs/integrations"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    title=$(grep -E "^# " "$f" | head -1 | sed 's/^# //' | sed 's/ Integration$//')
    cat > "$CONTENT/integrations/${name}.md" <<HDR
---
title: "$title"
description: "Integration guide"
---

HDR
    sed '1,/^# /d' "$f" >> "$CONTENT/integrations/${name}.md"
done

echo "Content sync complete."
ls -la "$CONTENT"