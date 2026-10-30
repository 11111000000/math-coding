#!/usr/bin/env bash
# The development loop for the math-coding console.
#
# The console is a plugin that lives in this repository and runs inside Paseo
# on the daemon machine. Editing the source has to reach the running plugin
# without restarting the daemon: a restart would kill the agent doing the
# edit.
#
#   ./dev.sh            typecheck, install (or update) the plugin, reload it
#   ./dev.sh reload     reload the installed plugin without reinstalling
#   ./dev.sh logs       tail the plugin's own output
#   ./dev.sh status     what Paseo thinks of the plugin right now
#
set -euo pipefail

PLUGIN_ID="${MATH_CODING_CONSOLE_ID:-math-coding-console}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

command -v paseo >/dev/null 2>&1 || die "paseo is not on PATH"

case "${1:-all}" in
  logs)
    exec paseo plugin logs "$PLUGIN_ID"
    ;;
  status)
    exec paseo plugin ls
    ;;
  reload)
    log "reloading $PLUGIN_ID"
    paseo plugin reload "$PLUGIN_ID"
    ;;
  all)
    log "typechecking"
    (cd "$HERE" && npm run typecheck)

    log "installing $PLUGIN_ID from $HERE"
    if paseo plugin ls | awk '{print $1}' | grep -qx "$PLUGIN_ID"; then
      paseo plugin remove "$PLUGIN_ID" >/dev/null 2>&1 || true
    fi
    paseo plugin install "$HERE" --id "$PLUGIN_ID"

    log "reloading $PLUGIN_ID"
    paseo plugin reload "$PLUGIN_ID"

    log "status"
    paseo plugin ls | awk -v id="$PLUGIN_ID" '$1 == id { print }'
    ;;
  *)
    die "unknown command: $1"
    ;;
esac
