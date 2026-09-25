#!/bin/sh
# scripts/migrate-v2-to-v2-y.sh — brownfield migration script.
#
# Adopts math-coding v2.0-Y in an existing project. Steps:
#   1. Build and install mathc
#   2. Initialize math/ and .mathrc (preserves existing files)
#   3. Install pre-commit hook under .git-hooks/ (matches mathc init)
#   4. Authorize legacy code with one packet
#
# Run this from the project root after `nix develop`.

set -eu
set -o pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

echo "math-coding v2.0-Y migration"
echo "=============================="

# 1. Build
echo ""
echo "Step 1: build mathc"
if ! command -v dune >/dev/null 2>&1; then
    echo "  dune not in PATH"
    echo "  hint: run 'nix develop --command sh scripts/install.sh' first"
    exit 1
fi
dune build --profile=release core/main.exe

# 2. Initialize
echo ""
echo "Step 2: initialize math/"
if [ ! -d math ]; then
    mkdir -p math
    echo "  created math/"
else
    echo "  math/ already exists; skipping"
fi
if [ ! -f .mathrc ]; then
    cat > .mathrc <<'EOF'
# math-coding v2.1 configuration.
# All fields are optional; sane defaults apply if .mathrc is absent.

SIGNING_MODE: off           # strict | lenient | off
AUTO_AMEND: true            # mathc decide auto-amends witness
FACT_POLICY: warn           # fail | warn | off — agent+fact without evidence
DRAFT_STALE_DAYS: 90        # warn if draft older than this

DIALECTIC_REQUIRED:
  judgment: [Why, Antithesis, Synthesis]
  hypothesis: []
  fact: []
  unknown: []

KIND_DEFAULT: policy        # axiom | policy | fix | experiment
BENEFICIARY_DEFAULT: system # user | developer | team | future_self | system
ACTOR_DEFAULT: agent        # human | agent | system
EOF
    echo "  created .mathrc"
else
    echo "  .mathrc already exists; skipping"
fi

# 3. Pre-commit hook
echo ""
echo "Step 3: install pre-commit hook"
mkdir -p .git-hooks
cat > .git-hooks/pre-commit <<'EOF'
#!/bin/sh
# mathc pre-commit hook — auto-installed by migration script.
exec mathc check --strict
EOF
chmod +x .git-hooks/pre-commit
git config core.hooksPath .git-hooks
echo "  installed .git-hooks/pre-commit (and configured core.hooksPath)"

# 4. Authorize legacy code
echo ""
echo "Step 4: authorize legacy code (optional)"
echo "  To create a legacy-code packet:"
echo "    mathc record legacy-code \"Existing code authorized as legacy: <description>\""
echo "    git add math/legacy-code/ && git commit -m \"legacy-code: authorization\""
echo "    mathc amend legacy-code"
echo "    git add math/legacy-code/witness && git commit"

echo ""
echo "=============================="
echo "Migration complete. Try:"
echo "  mathc help"
echo "  mathc check"