#!/bin/sh
# skills/math-coding/install.sh — math-coding binary + skill installer.
#
# Two phases:
#   1. Fetch `mathc` (GitHub Release binary; falls back to source build
#      via opam if no release exists for this OS/arch).
#   2. Drop SKILL.md + AGENTS.md into every detected agent dir.
#
# The agent dir scan covers: claude-code, opencode, cursor, continue.
# After install, verifies the SKILL.md has YAML frontmatter so Claude
# Code / opencode actually pick it up.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
#   MATH_CODING_VERSION=v2.1 sh
#
# Env:
#   MATH_CODING_VERSION=latest|<vX.Y.Z>  default: latest
#   MATH_CODING_NO_BUILD=1               skip source-build fallback
#   MATH_CODING_NO_SKILL=1               skip agent-skill install

set -eu

VERSION="${MATH_CODING_VERSION:-latest}"
REPO="https://github.com/11111000000/math-coding"
RAW_REPO="https://raw.githubusercontent.com/11111000000/math-coding/main"
BIN_DIR="${HOME}/.local/bin"
BIN_NAME="mathc"

log() { printf '[install] %s\n' "$*" >&2; }
die() { printf '[install] error: %s\n' "$*" >&2; exit 1; }

# OS / arch detection.
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$os" in
  linux)  os=linux ;;
  darwin) os=darwin ;;
  mingw*|msys*|cygwin*) os=windows ;;
  *) die "unsupported OS: $os" ;;
esac
case "$arch" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) die "unsupported arch: $arch" ;;
esac

# Extension (binary or .exe).
case "$os" in
  windows) ext=".exe" ;;
  *) ext="" ;;
esac

# Phase 1: fetch `mathc`.
mkdir -p "$BIN_DIR"
BIN_PATH="$BIN_DIR/$BIN_NAME$ext"

fetch_from_release() {
  if [ "$VERSION" = "latest" ]; then
    URL="$REPO/releases/latest/download/mathc-$os-$arch$ext"
  else
    URL="$REPO/releases/download/$VERSION/mathc-$os-$arch$ext"
  fi
  log "fetching release: $URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$BIN_PATH" "$URL" && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$BIN_PATH" "$URL" && return 0
  fi
  return 1
}

build_from_source() {
  if [ "${MATH_CODING_NO_BUILD:-0}" = "1" ]; then
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    log "skipping source build: git not found"
    return 1
  fi
  log "no release for $os/$arch; falling back to source build"
  TMPDIR_SRC="$(mktemp -d)"
  if ! git clone --depth=1 "$REPO.git" "$TMPDIR_SRC"; then
    rm -rf "$TMPDIR_SRC"
    return 1
  fi

  if command -v opam >/dev/null 2>&1; then
    if ! (
      cd "$TMPDIR_SRC"
      opam install --yes dune
      dune build --profile=release core/main.exe
      install -m755 _build/default/core/main.exe "$BIN_PATH"
    ); then
      rm -rf "$TMPDIR_SRC"
      return 1
    fi
  elif command -v nix >/dev/null 2>&1; then
    if ! (
      cd "$TMPDIR_SRC"
      nix develop --command bash -c '
        set -eu
        dune build --profile=release core/main.exe
        install -m755 _build/default/core/main.exe "$1"
      ' bash "$BIN_PATH"
    ); then
      rm -rf "$TMPDIR_SRC"
      return 1
    fi
  else
    log "source build needs opam or nix; not found"
    rm -rf "$TMPDIR_SRC"
    return 1
  fi

  rm -rf "$TMPDIR_SRC"
  [ -f "$BIN_PATH" ] || return 1
  return 0
}

if ! fetch_from_release; then
  if ! build_from_source; then
    die "could not install mathc: no release for $os/$arch and source build failed.
Install OCaml+dune (https://ocaml.org) or Nix and retry, or build manually:
    git clone $REPO
    cd math-coding
    opam install dune
    sh scripts/install.sh"
  fi
fi
chmod +x "$BIN_PATH"
log "installed: $BIN_PATH"

# PATH note.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) log "note: add '$BIN_DIR' to PATH (export PATH=\$PATH:$BIN_DIR)" ;;
esac

# Phase 2: drop SKILL.md + AGENTS.md into every detected agent.
if [ "${MATH_CODING_NO_SKILL:-0}" = "1" ]; then
  log "skipping agent-skill install (MATH_CODING_NO_SKILL=1)"
else
  SKILL_URL="$RAW_REPO/skills/math-coding/SKILL.md"
  AGENTS_URL="$RAW_REPO/skills/math-coding/AGENTS.md"
  fetch_to() {
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL -o "$1" "$2" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
      wget -q -O "$1" "$2" 2>/dev/null
    else
      return 1
    fi
  }
  for d in \
    "$HOME/.claude/skills/math-coding" \
    "$HOME/.config/opencode/skills/math-coding" \
    "$HOME/.cursor/skills/math-coding" \
    "$HOME/.continue/skills/math-coding"; do
    mkdir -p "$d"
    if fetch_to "$d/SKILL.md" "$SKILL_URL" && [ -f "$d/SKILL.md" ]; then
      # Frontmatter smoke-test: Claude Code and opencode require
      # `name:` and `description:` in the YAML block; otherwise the
      # skill is silently ignored with a warning.
      if head -1 "$d/SKILL.md" | grep -q '^---$'; then
        log "skill: $d/SKILL.md (frontmatter ok)"
      else
        log "warn: $d/SKILL.md missing YAML frontmatter; agent may ignore it"
      fi
    else
      log "warn: $d/SKILL.md not written; download failed"
    fi
  done

  AGENTS_DIR="$HOME/.config/math-coding"
  mkdir -p "$AGENTS_DIR"
  if fetch_to "$AGENTS_DIR/AGENTS.md" "$AGENTS_URL"; then
    log "universal snippet: $AGENTS_DIR/AGENTS.md"
  fi
fi

# Smoke test.
if "$BIN_PATH" version >/dev/null 2>&1; then
  log "ok: $("$BIN_PATH" version)"
else
  die "install succeeded but binary did not run; check arch/OS"
fi
