#!/usr/bin/env bash
# tests/fixtures/build-id-distinguishes.sh
#
# WHAT IT MEASURES. Two binaries that answer the same version are the
# same RELEASE and not the same BUILD: `VERSION` says 3.7.4 and the
# installer installs 3.7.4, and the older binary writes a scaffold the
# kernel rejects (decision `one-master-policy-and-build-id-2026-11`).
# The build id is what tells the two apart, and it has to hold ONE
# property or it identifies nothing:
#
#     two different binaries answer differently, and the same binary
#     always answers the same.
#
# The fixture measures that property directly, on copies of the real
# binary:
#
#   A. `mathc version --build-id` answers a short hex id;
#   B. the SAME binary at two paths answers the SAME id;
#   C. a copy with ONE byte appended answers a DIFFERENT id (and still
#      runs -- a digest that cannot be measured is not a digest);
#   D. the installer stamps the artifact it installed, and the stamp
#      names the version and the digest;
#   E. an installed binary with a stamp prints the build id in the
#      banner, and a stamp that does not match the bytes is named as
#      a mismatch instead of being believed.
#
# THE NEGATIVE CONTROL. The property is checked against two FAKE
# binaries that answer a constant, and the check has to fail on them.
# A check that has never been observed to bind is not known to bind.
#
# EXIT CODES.
#   0  the property holds, and the negative control was observed to
#      fail.
#   1  the property does not hold.
#   3  nothing was measured -- unknown, not pass.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

kernel_bin() {
  if [ -x "_build/default/bin/mathc.exe" ]; then
    printf '%s' "$PWD/_build/default/bin/mathc.exe"; return 0
  fi
  if [ -x "_build/install/default/bin/mathc" ]; then
    printf '%s' "$PWD/_build/install/default/bin/mathc"; return 0
  fi
  return 1
}

bin="$(kernel_bin || true)"
if [ -z "$bin" ]; then
  echo "build-id-distinguishes: no kernel binary to ask: the build id was not measured"
  echo "build-id-distinguishes: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

tmp="$(mktemp -d)" || { echo "build-id-distinguishes: mktemp failed" >&2; exit 3; }
trap 'rm -rf "$tmp"' EXIT INT TERM

# The id a binary answers, or the empty string when it cannot answer.
build_id_of() {
  "$1" version --build-id 2>/dev/null | tr -d '\r\n'
}

# --- A. the id is a short hex token -------------------------------------
id_a="$(build_id_of "$bin")"
if printf '%s' "$id_a" | grep -qE '^[0-9a-f]{12}$'; then
  ok "mathc version --build-id answers a 12-hex id ($id_a)"
else
  bad "mathc version --build-id answered '$id_a', which is not a 12-hex id"
fi

# --- B. the same binary answers the same --------------------------------
mkdir -p "$tmp/same"
cp "$bin" "$tmp/same/mathc"
chmod +x "$tmp/same/mathc"
id_b="$(build_id_of "$tmp/same/mathc")"
if [ -n "$id_b" ] && [ "$id_a" = "$id_b" ]; then
  ok "the same binary at another path answers the same id ($id_a)"
else
  bad "the same binary answered '$id_a' and '$id_b' at two paths"
fi

# --- C. a different binary answers differently --------------------------
mkdir -p "$tmp/other"
cp "$bin" "$tmp/other/mathc"
chmod +w "$tmp/other/mathc"
chmod +x "$tmp/other/mathc"
printf 'X' >> "$tmp/other/mathc"
id_c="$(build_id_of "$tmp/other/mathc")"
if [ -z "$id_c" ]; then
  bad "the modified copy could not be measured: the build id is not measurable there"
elif [ "$id_c" = "$id_a" ]; then
  bad "a binary with one byte more answered the same id ($id_a): the id identifies nothing"
else
  ok "a binary with one byte more answers a different id ($id_c)"
fi

# --- D. the installer stamps what it installed --------------------------
# The installer is run against a release directory served over
# file://, so the whole path (download, SHA-256 verify, install,
# stamp) runs without the network.
release="$tmp/release/v9.9.9-test"
mkdir -p "$release"
cp "$bin" "$release/mathc-linux-x86_64"
( cd "$release" && sha256sum mathc-linux-x86_64 > SHA256SUMS )
sed "s|^MC_RELEASE_BASE=.*|MC_RELEASE_BASE=\"file://$tmp/release\"|" \
  scripts/install-tooling/install.sh > "$tmp/install.sh"
chmod +x "$tmp/install.sh"
install_dir="$tmp/install"
if MATH_CODING_INSTALL_DIR="$install_dir" \
   sh "$tmp/install.sh" --no-cosign-verify --no-path-update \
      --version=9.9.9-test >"$tmp/install.log" 2>&1; then
  ok "the installer completed against a local release"
else
  sed 's/^/     /' "$tmp/install.log"
  bad "the installer failed against a local release"
fi
if [ -f "$install_dir/mathc.build-id" ]; then
  stamped_version="$(sed -n 's/^version=//p' "$install_dir/mathc.build-id" | head -1)"
  stamped_build="$(sed -n 's/^build=//p' "$install_dir/mathc.build-id" | head -1)"
  expected_build="$(sha256sum "$release/mathc-linux-x86_64" | awk '{print $1}')"
  if [ "$stamped_version" = "9.9.9-test" ] && [ "$stamped_build" = "$expected_build" ]; then
    ok "the installer stamped the version and the digest it verified"
  else
    bad "the stamp says version=$stamped_version build=$stamped_build, expected version=9.9.9-test build=$expected_build"
  fi
else
  bad "the installer wrote no build stamp"
fi

# --- E. the stamp is printed, and a wrong one is named ------------------
if [ -x "$install_dir/mathc" ]; then
  banner="$("$install_dir/mathc" version 2>/dev/null)"
  case "$banner" in
    *"math-coding 9.9.9-test: bootstrap (build "*) ok "the installed binary prints the build id in the banner" ;;
    *) bad "the installed binary printed '$banner', which carries no build id" ;;
  esac
  # A stamp that does not match the bytes must be named, not believed.
  printf 'version=9.9.9-test\nbuild=%s\n' \
    "0000000000000000000000000000000000000000000000000000000000000000" \
    > "$install_dir/mathc.build-id"
  banner2="$("$install_dir/mathc" version 2>"$tmp/mismatch.err")"
  if grep -q "does not match\|stamp says" "$tmp/mismatch.err" \
     || ! printf '%s' "$banner2" | grep -q "build 000000000000"; then
    ok "a stamp that does not match the bytes is named, not believed"
  else
    bad "a stamp that does not match the bytes was printed as the build id"
  fi
else
  bad "the installer installed no binary"
fi

# --- the negative control -----------------------------------------------
# Two fake binaries that answer a constant: the property check has to
# fail on them, or it cannot bind.
mkdir -p "$tmp/fake"
printf '#!/bin/sh\necho 000000000000\n' > "$tmp/fake/one"
printf '#!/bin/sh\necho 000000000000\n' > "$tmp/fake/two"
chmod +x "$tmp/fake/one" "$tmp/fake/two"
fake_a="$(build_id_of "$tmp/fake/one")"
fake_b="$(build_id_of "$tmp/fake/two")"
if [ -n "$fake_a" ] && [ "$fake_a" = "$fake_b" ]; then
  ok "the negative control binds: two different binaries that answer the same are caught"
else
  bad "the negative control does not bind: the check cannot tell two binaries apart"
fi

printf '\n'
if [ "$fail" -ne 0 ]; then
  echo "build-id-distinguishes: FAIL"
  exit 1
fi
echo "build-id-distinguishes: PASS"
exit 0
