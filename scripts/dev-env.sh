#!/usr/bin/env bash
# scripts/dev-env.sh — cached entry into the `test` dev shell.
#
# Sourced, not executed:
#
#     . scripts/dev-env.sh
#     mc_dev_env_ensure          # populate PATH from cache (or build it)
#     mc_run_in_shell '<cmd>'    # run cmd inside the cached dev env
#
# Why this exists
# --------------
# `nix develop .#test` realises the devShell derivation on every call,
# which needs an exclusive lock on /nix/var/nix/db/big-lock. Two
# things on this host take that same lock:
#
#   * nix-gc.timer       (daily 00:00 UTC)
#   * nix-optimise.timer (daily ~04:02 UTC)
#
# GC acquires the lock about 15 s into its run and holds it for the
# remainder — 40 s observed on 2026-10-20, after deleting 8 313 paths
# and touching 1.4 GB of RAM. Any `nix develop .#test` issued inside
# that window stalls silently: no error, rc=0, no output. Measured:
#
#     store lock held 25 s  ->  nix develop returned in 24 992 ms
#     GC lock taken at t+15s -> nix develop returned in 40 760 ms
#
# The stall is invisible because it is a lock wait, not a failure.
# `OCAML_BEST_PRACTICES.md` §11.42 documents the reproduction.
#
# How this avoids it
# ------------------
# `nix print-dev-env .#test` writes the shell environment (PATH,
# OCAMLPATH, ...) as a sourceable script. We materialise it once
# into .dev/test-env.sh and `eval` that file on subsequent calls.
# Cache hit costs ~10 ms and touches no store lock at all.
#
# Invalidation is by content hash of flake.nix + flake.lock, stored
# alongside the cache in .dev/test-env.stamp. Editing either file
# invalidates automatically; nothing else does. Override the cache
# location with MC_DEV_ENV_CACHE_DIR.
#
# Caveat: `print-dev-env` itself takes the store lock, so the FIRST
# call after an invalidation can still stall during a GC window. That
# is a one-shot cost per flake edit, not per command. `mc_run_in_shell`
# accepts MC_DEV_ENV_TIMEOUT to bound the wait instead of hanging.

MC_DEV_ENV_CACHE_DIR="${MC_DEV_ENV_CACHE_DIR:-$PWD/.dev}"
MC_DEV_ENV_FILE="$MC_DEV_ENV_CACHE_DIR/test-env.sh"
MC_DEV_ENV_STAMP="$MC_DEV_ENV_CACHE_DIR/test-env.stamp"
MC_DEV_ENV_TIMEOUT="${MC_DEV_ENV_TIMEOUT:-180}"

_mc_dev_env_fingerprint() {
  # Hash the two files that can change the dev-shell closure. Anything
  # else (source edits, _build contents) does not affect the env.
  cat flake.nix flake.lock 2>/dev/null | cksum | awk '{print $1 "-" $2}'
}

_mc_dev_env_build() {
  mkdir -p "$MC_DEV_ENV_CACHE_DIR" || return 1
  local tmp="$MC_DEV_ENV_FILE.tmp.$$"
  if [ -n "$MC_DEV_ENV_TIMEOUT" ]; then
    timeout "$MC_DEV_ENV_TIMEOUT" nix print-dev-env .#test > "$tmp" 2>/dev/null || {
      rm -f "$tmp"
      return 1
    }
  else
    nix print-dev-env .#test > "$tmp" 2>/dev/null || {
      rm -f "$tmp"
      return 1
    }
  fi
  # A truncated env file would silently break PATH. Require the
  # essential bindings before publishing the cache.
  if ! grep -q '^PATH=' "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$MC_DEV_ENV_FILE" || { rm -f "$tmp"; return 1; }
  _mc_dev_env_fingerprint > "$MC_DEV_ENV_STAMP"
  return 0
}

# Populate the cache if missing or stale, then eval it into the
# current shell. Returns non-zero (without touching PATH) if the
# env cannot be produced — callers decide whether to fall back.
mc_dev_env_ensure() {
  local want
  want=$(_mc_dev_env_fingerprint)
  if [ ! -s "$MC_DEV_ENV_FILE" ]; then
    _mc_dev_env_build || return 1
  elif [ "$(cat "$MC_DEV_ENV_STAMP" 2>/dev/null || true)" != "$want" ]; then
    _mc_dev_env_build || return 1
  fi
  # shellcheck disable=SC1090
  eval "$(cat "$MC_DEV_ENV_FILE")" || return 1
  return 0
}

# Run a command inside the dev shell.
#
# Fast path: cached env, no store lock, ~10 ms.
# Fallback: if the cache cannot be built (nix missing, devShell not
# realised yet, GC window exceeded MC_DEV_ENV_TIMEOUT), fall back to
# `nix develop` so behaviour degrades to today's, never to a failure.
mc_run_in_shell() {
  local cmd="$1"
  if mc_dev_env_ensure 2>/dev/null; then
    bash -c "$cmd"
    return $?
  fi
  nix develop .#test --command bash -c "$cmd"
}

# Expire the cache by hand: `rm -rf .dev/test-env.sh .dev/test-env.stamp`.
# Also honours a caller-supplied MC_DEV_ENV_CACHE_DIR.