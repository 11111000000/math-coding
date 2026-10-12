#!/bin/sh
# scripts/install-tooling/install.sh
#
# math-coding installer. POSIX-sh, no bashisms.
#
# Modes (one or more; default is binary-only):
#
#   --user-skill         install the per-user opencode skill
#   --upgrade            with --user-skill: overwrite even when
#                        the existing version pin matches
#   --with-docker        print docker pull + run commands
#   --print-nix-command  print `nix run github:.../math-coding`
#                        command
#   --version=<X>        override the default version
#                        (default = MC_VERSION_DEFAULT below)
#   --check              exit 0 if installed binary and skill
#                        already match the remote artifacts
#   -h | --help          usage
#
# Exit codes:
#   0   install succeeded; or --check passed; or --with-docker /
#       --print-nix-command printed successfully.
#   1   SHA-256 mismatch (the partial binary was removed).
#   2   input error (unknown flag, missing --version argument,
#       unknown OS/arch, missing/invalid --version).
#  124  network error (curl exit non-zero).
#
# The script reads MC_VERSION_DEFAULT at build time; the
# value is set by `scripts/sync-version.sh --write` per
# `decisions/version-sync-2026-10.yaml`. The fallback below
# is the version that ships with this commit; a fresh
# `sync-version.sh --write` updates it.

# shellcheck disable=SC2034  # variables exported for clarity
MC_VERSION_DEFAULT="3.1.0-alpha-final"
MC_REPO="11111000000/math-coding"
MC_RELEASE_BASE="https://github.com/${MC_REPO}/releases/download"
MC_BINARY_BASENAME="mathc"
MC_SKILL_REMOTE_PATH="dist/adoption/opencode/SKILL.md"
MC_TEMPLATE_REMOTE_PATH="scripts/install-tooling/templates/active-policy.yaml"
MC_TARBALL_NAME="dist-adoption.tar.gz"

# --- Usage ----------------------------------------------------------------
print_usage() {
  cat <<USAGE
Usage: install.sh [options]

Options:
  --user-skill            install the per-user opencode skill
  --upgrade               (implies --user-skill) overwrite the skill
                          even when its version pin matches
  --with-docker           print docker pull + run commands
  --print-nix-command     print the \`nix run github:...\` command
  --version=<X>           override MC_VERSION_DEFAULT
  --check                 exit 0 if already installed and in sync
  -h | --help             show this help

Examples:
  curl -fsSL https://github.com/${MC_REPO}/releases/download/v\${VERSION}/install.sh | sh
  curl ... | sh -s -- --user-skill
  curl ... | sh -s -- --version=3.1.0-alpha-final --with-docker

Exit codes: 0=ok, 1=checksum-mismatch, 2=input-error, 124=network-error.
USAGE
}

# --- Flag parsing ---------------------------------------------------------
install_user_skill=0
install_upgrade=0
install_print_docker=0
install_print_nix=0
install_version="${MC_VERSION_DEFAULT}"
install_check_only=0
install_print_help=0

parse_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --user-skill)        install_user_skill=1 ;;
      --upgrade)           install_user_skill=1; install_upgrade=1 ;;
      --with-docker)       install_print_docker=1 ;;
      --print-nix-command) install_print_nix=1 ;;
      --check)             install_check_only=1 ;;
      --version=*)         install_version="${1#--version=}" ;;
      -h|--help)           install_print_help=1 ;;
      --)                  shift; break ;;
      -*)
        echo "install.sh: unknown flag: $1" >&2
        echo "diagnostic: MC-INSTALL-FLAG-UNKNOWN" >&2
        return 2
        ;;
      *)
        echo "install.sh: unexpected positional argument: $1" >&2
        echo "diagnostic: MC-INSTALL-ARGV-UNEXPECTED" >&2
        return 2
        ;;
    esac
    shift
  done
  return 0
}

# --- OS/arch detection ----------------------------------------------------
# Returns: os="linux|darwin|windows", arch="x86_64|aarch64".
# Normalizes: amd64 -> x86_64, arm64 -> aarch64, x86_64i -> x86_64.
detect_os_arch() {
  uname_sm=$(uname -sm 2>/dev/null || echo "unknown unknown")
  raw_os=$(printf '%s\n' "$uname_sm" | awk '{print $1}')
  raw_arch=$(printf '%s\n' "$uname_sm" | awk '{print $2}')

  case "$raw_os" in
    Linux|GNU) os=linux ;;
    Darwin)    os=darwin ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "install.sh: Windows hosts are not supported by this script." >&2
      echo "hint: use Git-Bash on Windows; WSL on Windows Subsystem for Linux; or the" >&2
      echo "      binary directly (https://github.com/${MC_REPO}/releases)." >&2
      echo "diagnostic: MC-INSTALL-OS-UNSUPPORTED" >&2
      return 2
      ;;
    *)
      echo "install.sh: unknown OS: $raw_os" >&2
      echo "diagnostic: MC-INSTALL-OS-UNSUPPORTED" >&2
      return 2
      ;;
  esac

  case "$raw_arch" in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *)
      echo "install.sh: unknown arch: $raw_arch (supported: x86_64, aarch64)" >&2
      echo "diagnostic: MC-INSTALL-ARCH-UNSUPPORTED" >&2
      return 2
      ;;
  esac

  printf 'os=%s\narch=%s\n' "$os" "$arch"
  return 0
}

# --- Path helpers ---------------------------------------------------------
# pick_install_dir: returns the directory mathc goes into.
#   Linux/macOS: ~/.local/bin (created if missing; on PATH per XDG spec).
#   Override via MATH_CODING_INSTALL_DIR.
pick_install_dir() {
  if [ -n "${MATH_CODING_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$MATH_CODING_INSTALL_DIR"
    return 0
  fi
  printf '%s\n' "${HOME}/.local/bin"
}

# pick_skill_dir: per-user opencode skill path.
#   ${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding
pick_skill_dir() {
  xdg="${XDG_CONFIG_HOME:-${HOME}/.config}"
  printf '%s\n' "${xdg}/opencode/skills/math-coding"
}

# pick_sha_tool: returns `sha256sum` or `shasum -a 256` based on OS.
pick_sha_tool() {
  case "$1" in
    darwin) printf 'shasum -a 256\n' ;;
    linux)  printf 'sha256sum\n' ;;
    *)      printf 'sha256sum\n' ;;
  esac
}

# --- Network: download with curl -fSL ------------------------------------
# Args: $1=url, $2=out_path. Returns curl exit code on network error
# (124-mapped via caller). 0 on success.
dl() {
  url="$1"
  out="$2"
  if ! curl -fSL --retry 3 --connect-timeout 10 "$url" -o "$out" 2>/dev/null; then
    echo "install.sh: curl failed for $url" >&2
    echo "diagnostic: MC-INSTALL-NETWORK" >&2
    return 124
  fi
  return 0
}

# --- SHA-256 verification -------------------------------------------------
# Args: $1=SHA256SUMS_path, $2=binary_path, $3=expected_basename.
# Returns 0 if the binary's hash matches the corresponding line in
# SHA256SUMS; 1 if mismatch; 2 if SHA256SUMS doesn't list the basename.
verify_sha256() {
  sums="$1"
  binary="$2"
  base="$3"
  # `sha256sum -c` syntax: a line "<hash>  <path-glob>"; we want to
  # cd into a temp dir with the file and check the basename. Simpler:
  # compute the binary's hash, grep the matching line, compare.
  case "$os" in
    darwin) actual=$(shasum -a 256 "$binary" | awk '{print $1}') ;;
    *)      actual=$(sha256sum "$binary" | awk '{print $1}') ;;
  esac
  expected=$(awk -v b="$base" '$2 == b {print $1}' "$sums")
  if [ -z "$expected" ]; then
    echo "install.sh: SHA256SUMS does not list $base" >&2
    echo "diagnostic: MC-INSTALL-SHA-LISTING-MISSING" >&2
    return 2
  fi
  if [ "$actual" != "$expected" ]; then
    echo "install.sh: SHA-256 mismatch for $base" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    echo "diagnostic: MC-INSTALL-CHECKSUM-MISMATCH" >&2
    return 1
  fi
  return 0
}

# --- Download the binary --------------------------------------------------
# Args: $1=version, $2=os, $3=arch, $4=out_path.
# Returns 0 on success; non-zero on any failure (caller maps to exit code).
download_binary() {
  version="$1"
  os="$2"
  arch="$3"
  out="$4"
  # Binary name on the release: mathc-<os>-<arch> (.exe on Windows,
  # but Windows isn't supported here).
  bin_basename="mathc-${os}-${arch}"
  url="${MC_RELEASE_BASE}/v${version}/${bin_basename}"
  if ! dl "$url" "$out"; then
    return 124
  fi
  printf '%s\n' "$bin_basename"
  return 0
}

# --- Print docker / nix commands (no I/O) --------------------------------
print_docker() {
  version="$1"
  cat <<DOCKER
docker pull ghcr.io/${MC_REPO%/*}/mathc:${version}
docker run --rm -v "\$(pwd):/repo" ghcr.io/${MC_REPO%/*}/mathc:${version} --help
DOCKER
}

print_nix() {
  version="$1"
  cat <<NIX
nix run github:${MC_REPO}#default -- --help
NIX
  # Note: `nix run` resolves to whatever HEAD is at fetch time. To pin
  # a specific version, use `nix run github:${MC_REPO}/<value>#default`
  # with a tag ref instead. The install script does not enforce pinning;
  # the user opts in by replacing the URL prefix.
}

# --- Install the binary to a directory ------------------------------------
# Args: $1=temp_binary, $2=install_dir.
# Returns 0 on success, 2 on filesystem error.
install_binary_to_dir() {
  tmp="$1"
  dir="$2"
  if ! mkdir -p "$dir" 2>/dev/null; then
    echo "install.sh: cannot create $dir (filesystem error)" >&2
    echo "diagnostic: MC-INSTALL-MKDIR" >&2
    return 2
  fi
  dest="$dir/${MC_BINARY_BASENAME}"
  if ! mv "$tmp" "$dest" 2>/dev/null; then
    echo "install.sh: cannot move binary to $dest (filesystem error)" >&2
    echo "diagnostic: MC-INSTALL-MOVE" >&2
    return 2
  fi
  if ! chmod +x "$dest" 2>/dev/null; then
    echo "install.sh: cannot chmod +x $dest (filesystem error)" >&2
    echo "diagnostic: MC-INSTALL-CHMOD" >&2
    return 2
  fi
  printf '%s\n' "$dest"
  return 0
}

# --- Install the per-user skill ------------------------------------------
# Args: $1=version, $2=upgrade_flag (0/1).
# Returns 0 on success, non-zero on failure.
install_user_skill_file() {
  version="$1"
  upgrade="$2"
  skill_dir=$(pick_skill_dir)
  skill_dst="$skill_dir/SKILL.md"
  url="${MC_RELEASE_BASE}/v${version}/${MC_TARBALL_NAME}"
  tmpdir=$(mktemp -d) || {
    echo "install.sh: mktemp failed" >&2
    return 2
  }
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  if ! dl "$url" "$tmpdir/adoption.tar.gz"; then
    return 124
  fi
  # The tarball contains `dist/adoption/opencode/SKILL.md` plus the
  # other platform drops. We extract only the opencode one.
  if ! tar -xzOf "$tmpdir/adoption.tar.gz" dist/adoption/opencode/SKILL.md > "$tmpdir/SKILL.md" 2>/dev/null; then
    echo "install.sh: cannot extract opencode/SKILL.md from tarball" >&2
    echo "diagnostic: MC-INSTALL-SKILL-EXTRACT" >&2
    return 2
  fi

  if [ -f "$skill_dst" ] && [ "$upgrade" = "0" ]; then
    # Check the installed skill's compatible_with pin; if it pins
    # the same version, skip.
    existing_pin=$(awk '/^compatible_with:[[:space:]]*mathc@>=/ {print; exit}' "$skill_dst" 2>/dev/null || true)
    new_pin="compatible_with: mathc@>=${version}"
    case "$version" in
      *-*) semver="${version%%-*}" ;;
      *) semver="$version" ;;
    esac
    new_pin="compatible_with: mathc@>=${semver}"
    if [ "$existing_pin" = "$new_pin" ]; then
      echo "install.sh: per-user skill at $skill_dst already at version $version (skip; --upgrade to overwrite)" >&2
      trap - EXIT INT TERM
      rm -rf "$tmpdir"
      return 0
    fi
  fi

  if ! mkdir -p "$skill_dir" 2>/dev/null; then
    echo "install.sh: cannot create $skill_dir" >&2
    return 2
  fi
  if ! mv "$tmpdir/SKILL.md" "$skill_dst" 2>/dev/null; then
    echo "install.sh: cannot write skill to $skill_dst" >&2
    return 2
  fi
  echo "install.sh: per-user skill installed at $skill_dst"
  trap - EXIT INT TERM
  rm -rf "$tmpdir"
  return 0
}

# --- --check mode ----------------------------------------------------------
check_installed() {
  version="$1"
  os="$2"
  arch="$3"
  install_dir=$(pick_install_dir)
  binary="$install_dir/${MC_BINARY_BASENAME}"
  rc=0
  if [ ! -x "$binary" ]; then
    echo "install.sh: --check: $binary not installed or not executable" >&2
    rc=1
  else
    # The installed binary's `version` output should mention the
    # version string we expect. `mathc version` prints
    # "math-coding <VERSION>: bootstrap".
    out=$("$binary" version 2>/dev/null || echo "")
    case "$out" in
      *"math-coding $version:"*) echo "ok: $binary at version $version" ;;
      *) echo "install.sh: --check: $binary present but reports a different version" >&2; rc=1 ;;
    esac
  fi
  if [ "$install_user_skill" = "1" ]; then
    skill_dir=$(pick_skill_dir)
    skill_dst="$skill_dir/SKILL.md"
    if [ ! -f "$skill_dst" ]; then
      echo "install.sh: --check: skill $skill_dst not installed" >&2
      rc=1
    else
      echo "ok: $skill_dst present"
    fi
  fi
  return "$rc"
}

# --- Main -----------------------------------------------------------------
main() {
  if ! parse_flags "$@"; then
    return 2
  fi

  if [ "$install_print_help" = "1" ]; then
    print_usage
    return 0
  fi

  # OS/arch (we don't need them for --with-docker / --print-nix-command,
  # but we still resolve for sanity).
  detected=$(detect_os_arch)
  if [ "$?" != "0" ]; then
    printf '%s\n' "$detected" >&2
    return 2
  fi
  # shellcheck disable=SC2162  # we want the bare value, not the var= prefix
  os=$(printf '%s\n' "$detected" | awk -F= '/^os=/{print $2}')
  arch=$(printf '%s\n' "$detected" | awk -F= '/^arch=/{print $2}')

  version="$install_version"
  case "$version" in
    "") echo "install.sh: --version cannot be empty" >&2; return 2 ;;
    # Allow alnum, dot, underscore, hyphen only. Specifically rejects
    # shell metacharacters that could affect URL construction (`&`,
    # `?`, `/`, `;`, `|`, `"`, etc.).
    *[!a-zA-Z0-9._-]*)
      echo "install.sh: --version '$version' has illegal characters" >&2
      return 2 ;;
  esac

  # --with-docker / --print-nix-command are no-I/O modes; print and exit.
  if [ "$install_print_docker" = "1" ]; then
    print_docker "$version"
    echo "install.sh: --with-docker printed; nothing was installed"
    return 0
  fi
  if [ "$install_print_nix" = "1" ]; then
    print_nix "$version"
    echo "install.sh: --print-nix-command printed; nothing was installed"
    return 0
  fi

  # --check: report and exit (no install).
  if [ "$install_check_only" = "1" ]; then
    if check_installed "$version" "$os" "$arch"; then
      return 0
    else
      return 1
    fi
  fi

  # Real install: download SHA256SUMS, then the binary, then verify.
  install_dir=$(pick_install_dir)
  sums_tmp=$(mktemp) || { echo "install.sh: mktemp failed" >&2; return 2; }
  bin_tmp=$(mktemp) || { echo "install.sh: mktemp failed" >&2; rm -f "$sums_tmp"; return 2; }
  trap 'rm -f "$sums_tmp" "$bin_tmp"' EXIT INT TERM

  sums_url="${MC_RELEASE_BASE}/v${version}/SHA256SUMS"
  if ! dl "$sums_url" "$sums_tmp"; then
    return 124
  fi

  if ! bin_basename=$(download_binary "$version" "$os" "$arch" "$bin_tmp"); then
    return 124
  fi

  if ! verify_sha256 "$sums_tmp" "$bin_tmp" "$bin_basename"; then
    rm -f "$bin_tmp"  # remove the partial before exit
    return 1
  fi

  dest=$(install_binary_to_dir "$bin_tmp" "$install_dir")
  if [ "$?" != "0" ]; then
    return 2
  fi

  # Optional skill install.
  if [ "$install_user_skill" = "1" ]; then
    if ! install_user_skill_file "$version" "$install_upgrade"; then
      echo "install.sh: skill install failed; binary is at $dest (continuing)" >&2
    fi
  fi

  trap - EXIT INT TERM
  rm -f "$sums_tmp" "$bin_tmp"

  # Final report: run `mathc version` for confirmation.
  echo "install.sh: installed to $dest"
  if [ -x "$dest" ]; then
    "$dest" version
    echo "install.sh: PATH hint: ensure $install_dir is on \$PATH"
  fi
  return 0
}

main "$@"
exit_status=$?
exit "$exit_status"