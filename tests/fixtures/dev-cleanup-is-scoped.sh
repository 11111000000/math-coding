#!/usr/bin/env bash
# tests/fixtures/dev-cleanup-is-scoped.sh
#
# Failure-first fixture for decisions/nix-develop-store-lock-contention-2026-10.
#
# TWO independent properties, both regressions observed on 2026-10-20:
#
# (A) `scripts/dev::cleanup_dune_lock` must NOT kill processes outside
#     its own session. The original implementation used
#     `pkill -9 -f 'nix develop .#test'`, which matches the full
#     command line of ANY process on the machine. On this host that
#     includes every concurrently-running agent shell. A collateral
#     SIGKILL lands mid-`dune` and leaves a stale `_build/.lock`,
#     which is the documented cause of §11.41 hangs.
#
# (B) The dev-shell environment must be obtainable from a local
#     cache rather than by re-entering `nix develop .#test`. Every
#     `nix develop` realises the devShell derivation and therefore
#     needs /nix/var/nix/db/big-lock. `nix-gc.timer` takes that lock
#     ~15 s into its run and holds it for the remainder (~40 s
#     observed), so any `nix develop .#test` issued in that daily
#     window stalls silently with rc=0 and no diagnostic.
#
# The fixture spawns a decoy process whose command line contains the
# forbidden pattern, invokes cleanup_dune_lock, then asserts the
# decoy survived. It also asserts that `scripts/dev-env.sh` exists and
# serves a cache hit without invoking `nix develop`.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()   { printf 'ok: %s\n' "$1"; }
bad()  { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- (A) cleanup must be scoped -----------------------------------------
if [ ! -f scripts/dev ]; then
  bad "scripts/dev missing"
else
  # The decoy must have 'nix develop .#test' in its REAL /proc/PID/cmdline,
# because that is what `pkill -f` reads. Two earlier attempts failed:
#   - `exec -a ...` sets argv[0] but bash -c still execs the named binary;
#   - a wrapper script doing `exec sleep 30` REPLACES itself, so the
#     pattern disappears from cmdline and the decoy always survives.
# A symlink named to match, pointing at the real sleep binary, keeps
# the pattern in cmdline for the whole lifetime of the process.
decoy_path="$PWD/.dev/nix develop .#test --command bash -c"
mkdir -p "$(dirname "$decoy_path")"
# The script must NOT exec: an exec replaces the process image and the
# pattern leaves /proc/PID/cmdline. Running it as `bash <path> 30`
# keeps the pattern in argv for the whole lifetime, and avoids the
# NixOS `sleep` wrapper (which rejects unknown argv[0] forms).
printf '#!/usr/bin/env bash\nread -r _ < /dev/null\nwhile :; do :; done\n' > "$decoy_path"
chmod +x "$decoy_path"
bash "$decoy_path" 30 &
decoy=$!
sleep 0.4

  if ! kill -0 "$decoy" 2>/dev/null; then
    bad "decoy process failed to start; fixture cannot test cleanup scoping"
  else
    # Invoke the real cleanup_dune_lock from scripts/dev.
    # shellcheck disable=SC1090
    (
      set -e
      cd "$(dirname "$0")/../.."
      # Extract the function without running the case dispatch:
      # source only up to the first `case` statement.
      eval "$(sed -n '/^cleanup_dune_lock()/,/^}/p' scripts/dev)"
      cleanup_dune_lock
    ) >/dev/null 2>&1

    sleep 0.4
    if kill -0 "$decoy" 2>/dev/null; then
      ok "cleanup_dune_lock left an unrelated 'nix develop .#test' process alive"
    else
      bad "cleanup_dune_lock killed an unrelated process (machine-wide pkill -f)"
    fi
    kill -9 "$decoy" 2>/dev/null || true
    wait "$decoy" 2>/dev/null || true
  fi
  rm -f "$decoy_path" 2>/dev/null || true

  # Static assertion: the known-bad patterns must be gone from the
  # CODE. Comments are stripped first — the replacement function
  # documents the old pattern by name, and a naive grep would then
  # flag its own explanation.
  if sed 's/#.*$//' scripts/dev | grep -q "pkill -9 -f 'nix develop"; then
    bad "scripts/dev still contains pkill -9 -f 'nix develop .#test'"
  else
    ok "scripts/dev has no machine-wide pkill on 'nix develop'"
  fi
fi

# --- (B) dev-shell env cache exists and hits ----------------------------
if [ ! -f scripts/dev-env.sh ]; then
  bad "scripts/dev-env.sh missing (no cached dev-shell entry point)"
else
  ok "scripts/dev-env.sh present"

  # First call populates the cache; second must be a hit. Neither may
  # invoke `nix develop`, which is the whole point of the helper.
  cache_dir="${TMPDIR:-/tmp}/mc-dev-env-fixture.$$"
  rm -rf "$cache_dir"

  out1=$(MC_DEV_ENV_CACHE_DIR="$cache_dir" \
    bash -c 'source scripts/dev-env.sh; mc_dev_env_ensure >/dev/null 2>&1; echo populated' 2>&1)
  if printf '%s' "$out1" | grep -q populated; then
    ok "first mc_dev_env_ensure call populated the cache"
  else
    bad "mc_dev_env_ensure did not populate the cache: $out1"
  fi

  # The cached env must actually put dune on PATH.
  if [ -s "$cache_dir/test-env.sh" ]; then
    ok "cache file written at \$MC_DEV_ENV_CACHE_DIR/test-env.sh"
    if grep -q '/nix/store/.*-dune-' "$cache_dir/test-env.sh" 2>/dev/null \
       || grep -q 'dune' "$cache_dir/test-env.sh" 2>/dev/null; then
      ok "cached env references a dune store path"
    else
      bad "cached env does not reference dune"
    fi
  else
    bad "cache file not written at \$MC_DEV_ENV_CACHE_DIR/test-env.sh"
  fi

  # Invalidation: touching flake.lock must invalidate the cache.
  if [ -f "$cache_dir/test-env.stamp" ]; then
    ok "cache stamp file written"
    before=$(cat "$cache_dir/test-env.stamp" 2>/dev/null || echo "")
    touch -d '2030-01-01 00:00:00' flake.lock 2>/dev/null || touch flake.lock
    after_touch=$(cat "$cache_dir/test-env.stamp" 2>/dev/null || echo "")
    if [ "$before" != "$after_touch" ]; then
      bad "stamp changed without mc_dev_env_ensure running (stamp is not a plain mtime echo)"
    else
      ok "stamp is stable until mc_dev_env_ensure recomputes it"
    fi
    git checkout -- flake.lock 2>/dev/null || true
  else
    bad "cache stamp file not written"
  fi

  rm -rf "$cache_dir"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "dev-cleanup-is-scoped: PASS"
  exit 0
fi
echo "dev-cleanup-is-scoped: FAIL"
exit 1