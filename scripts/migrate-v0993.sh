#!/bin/sh
# scripts/migrate-v0993.sh — convert v0.993 packets to v1.0 structure.
#
# Old layout: math/<name>/{packet.yaml, decision.md, refinement.md, witness}
# New layout: math/<name>/{packet.md, witness}

set -u

cd "$(dirname "$0")/.." || exit 1

for d in math/*/; do
  name=$(basename "$d")

  if [ -f "$d/packet.md" ]; then
    continue
  fi

  packet_yaml="$d/packet.yaml"
  decision_md="$d/decision.md"
  refinement_md="$d/refinement.md"
  witness="$d/witness"

  if [ ! -f "$packet_yaml" ]; then
    continue
  fi

  proposition=$(awk '/^## Thesis/{flag=1; next} /^## /{flag=0} flag' "$decision_md" 2>/dev/null | head -5 | sed '/^$/d' | tr '\n' ' ')
  antithesis=$(awk '/^## Antithesis/{flag=1; next} /^## /{flag=0} flag' "$decision_md" 2>/dev/null | head -5 | sed '/^$/d' | tr '\n' ' ')
  synthesis=$(awk '/^## Synthesis/{flag=1; next} /^## /{flag=0} flag' "$decision_md" 2>/dev/null | head -5 | sed '/^$/d' | tr '\n' ' ')
  axiom=$(grep '^axiom:' "$packet_yaml" | awk '{print $2}')

  cat > "$d/packet.md" <<PACKET
---
proposition: "$proposition"
$(if [ -n "$antithesis" ]; then echo "antithesis: \"$antithesis\""; fi)
$(if [ -n "$synthesis" ]; then echo "synthesis: \"$synthesis\""; fi)
axiom: $axiom
substrate: none
---

PACKET

  cat "$decision_md" >> "$d/packet.md" 2>/dev/null
  if [ -f "$refinement_md" ]; then
    echo "" >> "$d/packet.md"
    cat "$refinement_md" >> "$d/packet.md"
  fi

  rm -f "$d/packet.yaml" "$d/decision.md" "$d/refinement.md" "$d/task.md" "$d/assumptions.yaml"
  echo "migrated: $name"
done
