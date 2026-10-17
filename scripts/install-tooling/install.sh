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
#   --cosign-verify      (default: on) before the install /
#                        docker / nix branches, run
#                        `cosign verify` against
#                        `ghcr.io/11111000000/mathc:${version}`
#                        (the Docker image tag for this
#                        version). Exits 1 on verification
#                        failure. Skipped when `cosign` is not
#                        installed (warning to stderr).
#   --no-cosign-verify   disable the verify step
#   --version=<X>        override the default version
#                        (default = MC_VERSION_DEFAULT below)
#   --check              exit 0 if installed binary and skill
#                        already match the remote artifacts
#   --libc=glibc|musl    override the libc auto-detect (Linux only)
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
# Default channel is "stable" (latest tagged vX.Y.Z, GitHub's
# canonical /releases/latest/ URL); the rolling prerelease
# "edge" is the explicit opt-in via --channel=edge. See
# decisions/install-tooling-default-tag-stable-2026-10.yaml
# (which revises install-tooling-default-tag-edge-2026-10).
MC_VERSION_DEFAULT="3.3.1"
MC_REPO="11111000000/math-coding"
MC_RELEASE_BASE="https://github.com/${MC_REPO}/releases/download"
MC_BINARY_BASENAME="mathc"
MC_TEMPLATE_REMOTE_PATH="scripts/install-tooling/templates/active-policy.yaml"
MC_TARBALL_NAME="dist-adoption.tar.gz"
# Per `decisions/ux-3-cosign-image-2026-10.yaml` outcome
# `cosign-verify-runs-on-install`. The Docker image signature
# is checked by default; pass `--no-cosign-verify` to skip.
# The two flags below match the cosign-sign/cosign-verify jobs
# in `.github/workflows/docker.yml` (keyless, GitHub OIDC).
MC_COSIGN_IDENTITY_REGEXP='https://github.com/11111000000/math-coding'
MC_COSIGN_OIDC_ISSUER='https://token.actions.githubusercontent.com'
MC_COSIGN_IMAGE_PREFIX='ghcr.io/11111000000/mathc'

# --- Usage ----------------------------------------------------------------
print_usage() {
  cat <<USAGE
Usage: install.sh [options]

Options:
  --user-skill            install the per-user opencode skill
  --upgrade               (implies --user-skill) overwrite the skill
                          even when its version pin matches
  --no-path-update       skip the shell RC PATH auto-update
  --with-docker           print docker pull + run commands
  --docker-fallback       on native install failure (exit 1 / 124),
                          if docker is on PATH, print the docker run
                          command and exit 0 (default: off)
  --print-nix-command     print the `nix run github:...` command
  --cosign-verify         (default on) verify the ghcr.io image
                          signature; --no-cosign-verify to skip
  --no-cosign-verify      skip the cosign signature verification
  --version=<X>           override MC_VERSION_DEFAULT
  --check                 exit 0 if already installed and in sync
  --libc=glibc|musl       override the libc auto-detect (Linux only)
  -h | --help             show this help

Examples:
  curl -fsSL https://github.com/${MC_REPO}/releases/latest/download/install.sh | sh
  curl ... | sh -s -- --user-skill
  curl ... | sh -s -- --version=v3.3.0 --with-docker

Exit codes: 0=ok, 1=checksum-mismatch, 2=input-error, 124=network-error.
USAGE
}

# --- Flag parsing ---------------------------------------------------------
install_user_skill=0
install_upgrade=0
# D2: auto-add $install_dir to user's PATH via shell RC files.
# Default on. Override with --no-path-update. Failure to update
# a shell RC is a warning, not a fatal error (the binary itself
# installed successfully; PATH-update is a convenience).
install_path_update=1
install_print_docker=0
install_print_nix=0
install_docker_fallback=0
install_version="${MC_VERSION_DEFAULT}"
install_check_only=0
# CLI override for libc auto-detect. Empty = use detect_libc().
# Set by --libc=glibc or --libc=musl in parse_flags() below.
install_libc_override=""
install_print_help=0
# Default-on per `decisions/ux-3-cosign-image-2026-10.yaml`.
# Flipped to 0 by `--no-cosign-verify`.
install_cosign_verify=1

parse_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --user-skill)        install_user_skill=1 ;;
      --upgrade)           install_user_skill=1; install_upgrade=1 ;;
      --no-path-update)    install_path_update=0 ;;
      --with-docker)       install_print_docker=1 ;;
      --docker-fallback)   install_docker_fallback=1 ;;
      --print-nix-command) install_print_nix=1 ;;
      --cosign-verify)     install_cosign_verify=1 ;;
      --no-cosign-verify)  install_cosign_verify=0 ;;
      --check)             install_check_only=1 ;;
      --libc=*) install_libc_override="${1#--libc=}" ;;
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
# Returns: os="linux|darwin", arch="x86_64|aarch64".
# Normalizes: amd64 -> x86_64, arm64 -> aarch64, x86_64i -> x86_64.
# Windows hosts are routed to the native PS1 installer
# (`install.ps1`); under Git-Bash / MSYS / Cygwin, the
# underlying OS is Linux-class POSIX, so we treat them
# as `linux` and download the matching glibc binary.
detect_os_arch() {
  uname_sm=$(uname -sm 2>/dev/null || echo "unknown unknown")
  raw_os=$(printf '%s\n' "$uname_sm" | awk '{print $1}')
  raw_arch=$(printf '%s\n' "$uname_sm" | awk '{print $2}')

  case "$raw_os" in
    Linux|GNU|MINGW*|MSYS*|CYGWIN*) os=linux ;;
    Darwin)                        os=darwin ;;
    *)
      echo "install.sh: unknown OS: $raw_os" >&2
      echo "hint: native Windows hosts should use the PowerShell installer:" >&2
          echo "      irm https://github.com/${MC_REPO}/releases/latest/download/install.ps1 | iex" >&2
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

# --- libc detection (Linux only) -----------------------------------------
# Returns one line: "libc=glibc" or "libc=musl".
# Used to pick between mathc-linux-<arch> (glibc) and
# mathc-linux-<arch>-musl (alpine / Void / Chimera / etc.).
# Order of probes:
#   1. CLI override --libc=glibc|musl (checked in main()).
#   2. `getconf GNU_LIBC_VERSION` returns "glibc <ver>" → glibc.
#   3. `ldd --version 2>&1` first line contains "musl"    → musl.
#   4. ldd absence with no getconf → glibc (default; matches
#      the runner-vendored release matrix).
detect_libc() {
  if command -v getconf >/dev/null 2>&1; then
    glibc_ver=$(getconf GNU_LIBC_VERSION 2>/dev/null || printf '')
    case "$glibc_ver" in
      glibc*) printf 'libc=glibc\n'; return 0 ;;
    esac
  fi
  if command -v ldd >/dev/null 2>&1; then
    ldd_first=$(ldd --version 2>&1 | head -n 1 || printf '')
    case "$ldd_first" in
      *musl*) printf 'libc=musl\n'; return 0 ;;
      *GNU*|*GLIBC*) printf 'libc=glibc\n'; return 0 ;;
    esac
  fi
  printf 'libc=glibc\n'
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
  # SHA256SUMS lists the relative path (e.g. dist-bin/mathc-linux-x86_64);
  # install.sh names the binary by basename (e.g. mathc-linux-x86_64).
  # Match by basename suffix: strip any leading path-prefix.
  expected=$(awk -v b="$base" '{
    n = split($0, parts, " ")
    if (n >= 2) {
      p = parts[2]
      sub(/.*\//, "", p)
      if (p == b) print parts[1]
    }
  }' "$sums")
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
# Args: $1=version, $2=os, $3=arch, $4=libc, $5=out_path.
# $4 may be empty (= "glibc" implied for non-Linux); for Linux hosts
# it is "glibc" or "musl" (default "glibc"). Result: bin_basename
# (mathc-<os>-<arch>[-musl]) printed to stdout for SHA-256 lookup.
# Returns 0 on success; non-zero on any failure (caller maps to exit code).
download_binary() {
  version="$1"
  os="$2"
  arch="$3"
  libc="${4:-glibc}"
  out="$5"
  bin_basename="mathc-${os}-${arch}"
  case "$os:$libc" in
    linux:musl) bin_basename="${bin_basename}-musl" ;;
  esac
  case "$version" in
    edge|latest) url="${MC_RELEASE_BASE}/${version}/${bin_basename}" ;;
    v*)         url="${MC_RELEASE_BASE}/${version}/${bin_basename}" ;;
    *)          url="${MC_RELEASE_BASE}/v${version}/${bin_basename}" ;;
  esac
  if ! dl "$url" "$out"; then
    return 124
  fi
  # Echo the basename + the original URL on a second line, so the
  # caller can derive the matching .sig / .pem URLs without
  # recomputing the version / os / arch / libc convention.
  # Format: "<bin_basename>\n<bin_url>".
  printf '%s\n%s\n' "$bin_basename" "$url"
  return 0
}

# --- Download the binary's cosign signature and certificate ---------------
# Per `decisions/release-cosign-blob-sign-2026-10.yaml`. The release
# workflow publishes `<bin>.sig` and `<bin>.pem` alongside every
# `mathc-*` binary. Args:
#   $1 = binary URL (e.g.
#        https://github.com/.../mathc-linux-x86_64)
#   $2 = sig out_path
#   $3 = cert out_path
# Behavior:
#   - install_cosign_verify = 0 OR cosign not installed:
#     no-op; sets $2 / $3 to empty strings and exits 0. The
#     caller passes empty paths to verify_cosign_blob, which
#     short-circuits to "skipped".
#   - .sig or .pem download fails (e.g. pre-D6 release, 404):
#     sets the corresponding path to empty string and exits 0.
#     The verify_cosign_blob call site then warns-and-skips.
#   - Both succeed: exits 0 with $2 / $3 set to the temp paths.
# Returns: 0 always (network errors on .sig/.pem are tolerated,
# the binary itself is still installed and SHA-256 verified).
download_cosign_blob_assets() {
  bin_url="$1"
  sig_out="$2"
  cert_out="$3"
  if [ "$install_cosign_verify" = "0" ]; then
    : > "$sig_out" 2>/dev/null || true
    : > "$cert_out" 2>/dev/null || true
    return 0
  fi
  if ! command -v cosign >/dev/null 2>&1; then
    : > "$sig_out" 2>/dev/null || true
    : > "$cert_out" 2>/dev/null || true
    return 0
  fi
  sig_url="${bin_url}.sig"
  cert_url="${bin_url}.pem"
  # Tolerate 404 / network error on each file individually:
  # a pre-D6 release that does not publish .sig / .pem is the
  # common case. `dl` returns 124 on network errors; the OR
  # short-circuit on `dl` failure empties the path.
  if ! dl "$sig_url" "$sig_out" 2>/dev/null; then
    : > "$sig_out" 2>/dev/null || true
  fi
  if ! dl "$cert_url" "$cert_out" 2>/dev/null; then
    : > "$cert_out" 2>/dev/null || true
  fi
  return 0
}

# --- Cosign signature verification (Docker image) -------------------------
# Per `decisions/ux-3-cosign-image-2026-10.yaml` outcome
# `cosign-verify-runs-on-install`. Verifies the ghcr.io image
# signature using keyless cosign + GitHub Actions OIDC issuer,
# matching the `cosign-sign` / `cosign-verify` jobs in
# `.github/workflows/docker.yml` so user-side and CI-side
# checks use the same identity + issuer.
#
# Behavior:
#   - install_cosign_verify = 0 (--no-cosign-verify): no-op, exit 0.
#   - cosign not on PATH: print a warning to stderr and exit 0
#     (most users do not install cosign; the flag is on by
#     default but missing-cosign is a warning, not a failure).
#   - cosign verify exits 0: print a one-line confirmation to
#     stderr ("cosign verify: ok: ...") and exit 0.
#   - cosign verify exits non-zero: print an error to stderr,
#     emit `diagnostic: MC-INSTALL-COSIGN-VERIFY-FAIL`, and
#     return 1 (mapped to exit 1 by the caller).
#
# Args: $1=version (the tag suffix; e.g. `3.3.0` or `edge`).
# Returns: 0 on success / skipped / missing-cosign; 1 on verify fail.
verify_cosign() {
  version="$1"
  if [ "$install_cosign_verify" = "0" ]; then
    return 0
  fi
  # POSIX-sh `command -v` is the portable test (NOT `which`,
  # which is not in POSIX).
  if ! command -v cosign >/dev/null 2>&1; then
    echo "install.sh: cosign not installed; skipping image signature verification (use --no-cosign-verify to suppress this warning)" >&2
    return 0
  fi
  image_tag="${MC_COSIGN_IMAGE_PREFIX}:${version}"
  # Suppress cosign's stdout; we surface result via our own
  # one-liner. cosign writes verify-success metadata to stdout,
  # which would clutter the install script's normal output.
  if cosign verify \
        --certificate-identity-regexp "${MC_COSIGN_IDENTITY_REGEXP}" \
        --certificate-oidc-issuer "${MC_COSIGN_OIDC_ISSUER}" \
        "${image_tag}" >/dev/null 2>&1; then
    echo "install.sh: cosign verify: ok: ${image_tag}" >&2
    return 0
  fi
  echo "install.sh: cosign verify: FAIL: ${image_tag}" >&2
  echo "  the image signature does not match the math-coding GitHub Actions OIDC issuer." >&2
  echo "  this can indicate a registry compromise, a pre-sign release, or a missing signature." >&2
  echo "  retry with --no-cosign-verify only if you explicitly trust the registry for this version." >&2
  echo "diagnostic: MC-INSTALL-COSIGN-VERIFY-FAIL" >&2
  return 1
}

# --- Cosign signature verification (binary blob) --------------------------
# Per `decisions/release-cosign-blob-sign-2026-10.yaml` outcome
# `install-sh-verifies-cosign-blob`. Verifies the released binary's
# keyless cosign signature against the matching `<bin>.sig` /
# `<bin>.pem` pair. The pair is published as release assets by
# `.github/workflows/release.yml`'s `cosign sign-blob (each mathc-*
# binary)` step, using the workflow's GitHub Actions OIDC token
# (keyless, no `--key` flag). The same identity regexp +
# `MC_COSIGN_OIDC_ISSUER` are used here as in the IMAGE cosign
# verify (`verify_cosign` above) so user-side and CI-side checks
# agree as a single string.
#
# Behavior (mirrors `verify_cosign`):
#   - install_cosign_verify = 0 (--no-cosign-verify): no-op, exit 0.
#   - cosign not on PATH: print a warning to stderr and exit 0
#     (most users do not install cosign; the flag is on by
#     default but missing-cosign is a warning, not a failure).
#   - .sig or .pem absent (e.g. a pre-D6 release that did not
#     publish signatures): print a warning to stderr and exit 0
#     (no signature to verify against; SHA-256 remains the
#     fallback integrity check).
#   - cosign verify-blob exits 0: print a one-line confirmation
#     to stderr ("cosign verify-blob: ok: <bin>") and exit 0.
#   - cosign verify-blob exits non-zero: print an error to stderr,
#     emit `diagnostic: MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL`, and
#     return 1 (mapped to exit 1 by the caller).
#
# Args: $1=binary_path, $2=signature_path, $3=certificate_path.
# Returns: 0 on success / skipped / missing-cosign / pre-D6 release;
# 1 on verify failure.
verify_cosign_blob() {
  bin="$1"
  sig="$2"
  cert="$3"
  if [ "$install_cosign_verify" = "0" ]; then
    return 0
  fi
  if ! command -v cosign >/dev/null 2>&1; then
    echo "install.sh: cosign not installed; skipping binary signature verification (use --no-cosign-verify to suppress this warning)" >&2
    return 0
  fi
  if [ -z "$sig" ] || [ ! -f "$sig" ] || [ -z "$cert" ] || [ ! -f "$cert" ]; then
    echo "install.sh: cosign signature/certificate not published for $(basename "$bin") (pre-D6 release?); skipping verify" >&2
    return 0
  fi
  # Suppress cosign's stdout; we surface the result via our own
  # one-liner. cosign writes verify-success metadata to stdout,
  # which would clutter the install script's normal output.
  if cosign verify-blob \
        --signature "$sig" \
        --certificate "$cert" \
        --certificate-identity-regexp "${MC_COSIGN_IDENTITY_REGEXP}" \
        --certificate-oidc-issuer "${MC_COSIGN_OIDC_ISSUER}" \
        "$bin" >/dev/null 2>&1; then
    echo "install.sh: cosign verify-blob: ok: $(basename "$bin")" >&2
    return 0
  fi
  echo "install.sh: cosign verify-blob: FAIL: $(basename "$bin")" >&2
  echo "  the binary signature does not match the math-coding GitHub Actions OIDC issuer." >&2
  echo "  this can indicate a release-asset compromise, a pre-sign release, or a tampered binary." >&2
  echo "  retry with --no-cosign-verify only if you explicitly trust the release CDN for this version." >&2
  echo "diagnostic: MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL" >&2
  return 1
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

# --- Docker fallback on native install failure ---------------------------
# Per `decisions/docker-availability-guarantee-2026-10.yaml`
# obligation `install-sh-docker-fallback-mode`. When the
# native install branch fails and `--docker-fallback` is set,
# AND `docker` is on PATH, print the docker run line and
# exit 0 (the fallback IS the deliverable). When docker is
# NOT on PATH, print a notice and exit 1.
print_docker_fallback() {
  version="$1"
  if command -v docker >/dev/null 2>&1; then
    cat <<DOCKER
native install failed; Docker fallback available:

docker pull ghcr.io/${MC_REPO%/*}/mathc:${version}
docker run --rm -v "\$(pwd):/repo" ghcr.io/${MC_REPO%/*}/mathc:${version} --help

install.sh: --docker-fallback printed; nothing was installed
DOCKER
    exit 0
  else
    echo "install.sh: --docker-fallback: docker binary not found on PATH; no fallback available" >&2
    exit 1
  fi
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
  case "$version" in
    edge|latest) url="${MC_RELEASE_BASE}/${version}/${MC_TARBALL_NAME}" ;;
    v*)          url="${MC_RELEASE_BASE}/${version}/${MC_TARBALL_NAME}" ;;
    *)           url="${MC_RELEASE_BASE}/v${version}/${MC_TARBALL_NAME}" ;;
  esac
  tmpdir=$(mktemp -d) || {
    echo "install.sh: mktemp failed" >&2
    return 2
  }
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  if ! dl "$url" "$tmpdir/adoption.tar.gz"; then
    return 124
  fi
  # The tarball contains `adoption/opencode/SKILL.md` plus the
  # other platform drops. We extract only the opencode one.
  if ! tar -xzOf "$tmpdir/adoption.tar.gz" adoption/opencode/SKILL.md > "$tmpdir/SKILL.md" 2>/dev/null; then
    echo "install.sh: cannot extract opencode/SKILL.md from tarball" >&2
    echo "diagnostic: MC-INSTALL-SKILL-EXTRACT" >&2
    return 2
  fi

  if [ -f "$skill_dst" ] && [ "$upgrade" = "0" ]; then
    # Check the installed skill's compatible_with pin; if it pins
    # the same version, skip.
    existing_pin=$(awk '/^compatible_with:[[:space:]]*mathc@>=/ {print; exit}' "$skill_dst" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
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

# --- PATH auto-add (D2) ---------------------------------------------------
# Idempotently update the user's shell RC files so that
# $install_dir is on $PATH for new login shells. Supported
# shells and RC paths:
#   bash:   ~/.bashrc, ~/.profile (login)
#   zsh:    ~/.zshrc, ~/.zshenv (login)
#   ksh:    ~/.kshrc
#   posix:  ~/.profile (fallback)
# Idempotency: a grep guard checks for the literal install_dir
# on a non-comment line; re-running never appends a duplicate.
# Args: $1=install_dir. Returns 0 if any RC was updated or
# already in sync; returns 1 if all candidate RCs failed.
update_path_in_rc() {
  dir="$1"
  rc_files=""
  # bash: ~/.bashrc is the interactive, non-login default.
  # ~/.profile is the POSIX-login (and bash --login) default.
  case "${SHELL:-}" in
    */bash)
      rc_files="${HOME}/.bashrc ${HOME}/.profile" ;;
    */zsh)
      # zsh reads .zshrc for interactive; .zshenv for all.
      # We update .zshrc; .zshenv is rarely edited manually.
      rc_files="${HOME}/.zshrc ${HOME}/.zshenv ${HOME}/.zprofile" ;;
    */ksh|*/ksh93|*/mksh)
      rc_files="${HOME}/.kshrc" ;;
    *)
      # Unknown SHELL — fall back to POSIX ~/.profile only.
      rc_files="${HOME}/.profile" ;;
  esac

  updated_any=0
  for rc in $rc_files; do
    if [ ! -f "$rc" ] || [ ! -w "$rc" ]; then
      continue
    fi
    # Idempotency guard: skip if this install_dir already appears
    # in rc on a non-comment line.
    if grep -qE "(^|[^#]*[[:space:]])${dir}([[:space:]]|:|\$)" "$rc" 2>/dev/null; then
      updated_any=1
      continue
    fi
    if {
      printf '\n# Added by math-coding install.sh (%s)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf unknown)"
      printf 'export PATH="%s:$PATH"\n' "$dir"
    } >> "$rc"; then
      echo "install.sh: PATH appended to $rc" >&2
      updated_any=1
    else
      echo "install.sh: cannot append to $rc (filesystem error)" >&2
    fi
  done

  if [ "$updated_any" = "1" ]; then
    return 0
  fi
  echo "install.sh: no shell RC updated for $dir (none were writable)" >&2
  return 1
}

# Returns 0 if $install_dir is on $PATH (or is exactly PATH).
# Pure inspection; no I/O. Used by the final report.
path_contains_install_dir() {
  dir="$1"
  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;;
    *) return 1 ;;
  esac
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

  # Cosign signature verification (Docker image). Runs BEFORE any
  # print/install branches so a failed verify halts the install
  # before any I/O. `--print-help` and `--check` skip this step
  # (those are introspection / reporting modes, not actual installs);
  # `--with-docker` and `--print-nix-command` and a real binary
  # install all pass through it.
  if [ "$install_cosign_verify" = "1" ] \
       && [ "$install_print_help" != "1" ]; then
    if ! verify_cosign "$version"; then
      return 1
    fi
  fi

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
  trap 'rm -f "$sums_tmp" "$bin_tmp" "$sig_tmp" "$cert_tmp"' EXIT INT TERM

  case "$version" in
    edge|latest) sums_url="${MC_RELEASE_BASE}/${version}/SHA256SUMS" ;;
    v*)          sums_url="${MC_RELEASE_BASE}/${version}/SHA256SUMS" ;;
    *)           sums_url="${MC_RELEASE_BASE}/v${version}/SHA256SUMS" ;;
  esac
  if ! dl "$sums_url" "$sums_tmp"; then
    if [ "$install_docker_fallback" = "1" ]; then
      print_docker_fallback "$install_version"
    fi
    return 124
  fi

  # libc detect (Linux only). Honors --libc override; falls back
  # to auto-detect via getconf / ldd for alpine / void.
  libc="glibc"
  if [ -n "${install_libc_override:-}" ]; then
    # explicit override; we validate the value below
    libc="$install_libc_override"
  elif [ "$os" = "linux" ]; then
    libc_line=$(detect_libc)
    # shellcheck disable=SC2162  # we want the bare value
    libc=$(printf '%s\n' "$libc_line" | awk -F= '/^libc=/{print $2}')
  fi
  case "$libc" in
    glibc|musl) ;;
    *)
      echo "install.sh: --libc=$libc: invalid libc (use glibc or musl)" >&2
      echo "diagnostic: MC-INSTALL-LIBC-INVALID" >&2
      return 2 ;;
  esac
  if [ "$os" = "linux" ]; then
    echo "install.sh: libc detect: ${libc}" >&2
  fi

  if ! bin_meta=$(download_binary "$version" "$os" "$arch" "$libc" "$bin_tmp"); then
    if [ "$install_docker_fallback" = "1" ]; then
      print_docker_fallback "$install_version"
    fi
    return 124
  fi
  bin_basename=$(printf '%s\n' "$bin_meta" | sed -n '1p')
  bin_url=$(printf '%s\n' "$bin_meta" | sed -n '2p')

  # D6: download the cosign signature + certificate for the
  # binary (best-effort). Skipped silently when --no-cosign-verify
  # or cosign not on PATH. A pre-D6 release that does not publish
  # .sig / .pem yields empty temp files, which `verify_cosign_blob`
  # treats as "skip" with a warning to stderr.
  sig_tmp=$(mktemp) || { echo "install.sh: mktemp failed" >&2; return 2; }
  cert_tmp=$(mktemp) || { echo "install.sh: mktemp failed" >&2; rm -f "$sig_tmp"; return 2; }
  download_cosign_blob_assets "$bin_url" "$sig_tmp" "$cert_tmp"

  # D6: cosign blob verify (auth check). Runs BEFORE SHA-256
  # verify (integrity check); both gates are independently
  # closed. verify_cosign_blob is silent on success (one-line
  # "ok" to stderr) and on skip (warning); returns 1 on real
  # signature mismatch.
  if ! verify_cosign_blob "$bin_tmp" "$sig_tmp" "$cert_tmp"; then
    rm -f "$bin_tmp" "$sig_tmp" "$cert_tmp"  # remove partials
    return 1
  fi
  rm -f "$sig_tmp" "$cert_tmp"  # cleanup cosign scratch files

  if ! verify_sha256 "$sums_tmp" "$bin_tmp" "$bin_basename"; then
    rm -f "$bin_tmp"  # remove the partial before exit
    if [ "$install_docker_fallback" = "1" ]; then
      print_docker_fallback "$install_version"
    fi
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

  # D2: idempotent PATH update across shell RC files. Best-effort:
  # if update_path_in_rc fails for some but not all RC files, we
  # still report the binary installed correctly. Caller asserts
  # success on the binary; the PATH update is convenience.
  if [ "$install_path_update" = "1" ]; then
    if ! update_path_in_rc "$install_dir"; then
      echo "install.sh: some shell RC files were not updated (manual PATH edit may be needed)" >&2
    fi
  fi

  # Final report: run `mathc version` for confirmation.
  echo "install.sh: installed to $dest"
  if [ -x "$dest" ]; then
    "$dest" version
    if path_contains_install_dir "$install_dir"; then
      echo "install.sh: PATH: $install_dir already on \$PATH"
    else
      echo "install.sh: PATH hint: ensure $install_dir is on \$PATH (restart the shell)"
    fi
  fi
  return 0
}

main "$@"
exit_status=$?
exit "$exit_status"
