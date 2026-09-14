#!/bin/sh
# install.sh — install math-coding binary and skills into any agent.
#
# Auto-detects agent (claude-code, opencode, cursor) and drops the
# right files. Installs binary to ~/.local/bin.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
#   MATH_CODING_VERSION=v0.2.0 sh

set -eu

VERSION="${MATH_CODING_VERSION:-latest}"
REPO="https://github.com/11111000000/math-coding"
BIN_DIR="${HOME}/.local/bin"

# OS / arch detection.
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$os" in
  linux)  os=linux ;;
  darwin) os=darwin ;;
  *) echo "error: unsupported OS: $os" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) echo "error: unsupported arch: $arch" >&2; exit 1 ;;
esac

# Resolve download URL.
if [ "$VERSION" = "latest" ]; then
  URL="$REPO/releases/latest/download/math-coding-$os-$arch"
else
  URL="$REPO/releases/download/v$VERSION/math-coding-$os-$arch"
fi

# Pick extension.
case "$os" in
  windows) ext=".exe" ;;
  *) ext="" ;;
esac
FULL_URL="$URL$ext"

# Download to ~/.local/bin.
mkdir -p "$BIN_DIR"
echo "fetching $FULL_URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$BIN_DIR/math-coding$ext" "$FULL_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$BIN_DIR/math-coding$ext" "$FULL_URL"
else
  echo "error: need curl or wget" >&2; exit 1
fi
chmod +x "$BIN_DIR/math-coding$ext"
echo "installed: $BIN_DIR/math-coding$ext"

# PATH note.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: add '$BIN_DIR' to PATH (export PATH=\$PATH:$BIN_DIR)" ;;
esac

# Agent auto-detect and skill install.
for d in \
  "$HOME/.claude/skills/math-coding" \
  "$HOME/.config/opencode/skills/math-coding" \
  "$HOME/.cursor/skills/math-coding" \
  "$HOME/.continue/skills/math-coding"; do
  if [ -d "$(dirname "$(dirname "$d")")" ] || [ -d "$(dirname "$d")" ]; then
    mkdir -p "$d"
    # Download SKILL.md from repo.
    SKILL_URL="$REPO/raw/main/skills/math-coding/SKILL.md"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL -o "$d/SKILL.md" "$SKILL_URL" 2>/dev/null || true
    fi
    if [ -f "$d/SKILL.md" ]; then
      echo "skill: $d/SKILL.md"
    fi
  fi
done

# Always install universal AGENTS.md snippet.
AGENTS_DIR="$HOME/.config/math-coding"
mkdir -p "$AGENTS_DIR"
SNIPPET_URL="$REPO/raw/main/skills/math-coding/AGENTS.md"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$AGENTS_DIR/AGENTS.md" "$SNIPPET_URL" 2>/dev/null || true
fi
echo "universal snippet: $AGENTS_DIR/AGENTS.md"

# Smoke test.
if "$BIN_DIR/math-coding" version >/dev/null 2>&1; then
  echo "ok: $($BIN_DIR/math-coding version)"
else
  echo "warn: install succeeded but binary did not run; check arch/OS"
fi
