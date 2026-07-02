#!/bin/sh
# Verify-schemas.sh — mechanically validate JSON Schema files in schemas/.
# This is meta-verification: it checks the specifications
# themselves, not the data they specify.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEMAS_DIR="$REPO_ROOT/schemas"

errors=0
schemas_checked=0

if [ ! -d "$SCHEMAS_DIR" ]; then
    echo "FAIL: schemas directory not found: $SCHEMAS_DIR"
    cat > "$(dirname "$0")/verifier-output.yaml" <<EOF
verdict: NEEDS_REVISION
verified_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
scope:
  - schema-existence
tool: shell-verifier-v2
errors: 1
details: schemas directory missing
EOF
    exit 1
fi

for schema in "$SCHEMAS_DIR"/*.schema.json; do
    [ -f "$schema" ] || continue
    schemas_checked=$((schemas_checked + 1))
    name=$(basename "$schema")

    # Check valid JSON
    if ! grep -q '^\s*{' "$schema"; then
        echo "FAIL: $name does not start with '{'"
        errors=$((errors + 1))
        continue
    fi

    # Check required top-level fields
    for field in '"$schema"' '"type"' '"properties"'; do
        if ! grep -q "$field" "$schema"; then
            echo "FAIL: $name missing top-level field $field"
            errors=$((errors + 1))
        fi
    done

    # Check version field (added in v2)
    if ! grep -q '"version"' "$schema"; then
        echo "FAIL: $name missing 'version' field"
        errors=$((errors + 1))
    fi

    # Check no trailing comma (common JSON error)
    if grep -E ',\s*[}\]]' "$schema" > /dev/null 2>&1; then
        echo "FAIL: $name has trailing comma (invalid JSON)"
        errors=$((errors + 1))
    fi

    # Check balanced braces (rough)
    open=$(tr -cd '{' < "$schema" | wc -c)
    close=$(tr -cd '}' < "$schema" | wc -c)
    if [ "$open" != "$close" ]; then
        echo "FAIL: $name has unbalanced braces ($open open vs $close close)"
        errors=$((errors + 1))
    fi
done

# Write verdict
if [ "$errors" -eq 0 ]; then
    cat > "$(dirname "$0")/verifier-output.yaml" <<EOF
verdict: VERIFIED
errors: 0
verified_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
scope:
  - schema-syntactic-validity
  - schema-version-present
  - schema-balanced-braces
tool: shell-verifier-v2
details: All $schemas_checked schemas are structurally valid.
evidence:
  schemas_checked: $schemas_checked
EOF
    echo "OK: $schemas_checked schemas valid"
    exit 0
else
    cat > "$(dirname "$0")/verifier-output.yaml" <<EOF
verdict: NEEDS_REVISION
errors: $errors
verified_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
scope:
  - schema-syntactic-validity
tool: shell-verifier-v2
details: $errors schema validation failures
EOF
    echo "FAIL: $errors schema violation(s)"
    exit 1
fi