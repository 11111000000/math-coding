#!/bin/sh
# scripts/hotfix-cve.sh - 24h waiver stamp for urgent-CVE merges.
#
# math-coding hotfix waiver generator. POSIX-sh, no bashisms.
#
# Usage: scripts/hotfix-cve.sh <ticket-id> [--reason=<text>] [--expires-in=<duration>]
#
# Exit codes: 0=written, 2=input-error.
#
# Closure: a post-hoc decisions/<id>.yaml + attestations/<id>-<obligation>.json
# pair MUST land within the 24h window. Once expires_at passes, mathc
# self-check returns Block on this subject (waiver no longer effective_at).

set -eu

usage() {
  cat <<USAGE
Usage: hotfix-cve.sh <ticket-id> [--reason=<text>] [--expires-in=<duration>]

Generates a 24h waiver stamp for an urgent CVE / SLA merge. The
post-hoc decisions/<id>.yaml + attestations/<id>-<obligation>.json
pair MUST be added within the window or mathc self-check returns
Block on the next clean run.

  --reason=<text>          Override the default reason text.
  --expires-in=<duration> Override the default 24h window
                           (e.g. 24h, 30m, 7d).

Exit codes: 0=ok, 2=input-error.
USAGE
}

# --- args --------------------------------------------------------------
ticket=""
reason=""
expires_in="24h"
while [ $# -gt 0 ]; do
  case "$1" in
    --reason=*)      reason="${1#--reason=}" ;;
    --expires-in=*)  expires_in="${1#--expires-in=}" ;;
    -h|--help)       usage; exit 0 ;;
    --)              shift; break ;;
    -*) echo "hotfix-cve.sh: unknown flag: $1" >&2
        echo "diagnostic: MC-HOTFIX-FLAG-UNKNOWN" >&2
        exit 2 ;;
    *)  if [ -z "$ticket" ]; then ticket="$1"
        else echo "hotfix-cve.sh: unexpected positional argument: $1" >&2
             echo "diagnostic: MC-HOTFIX-ARGV-UNEXPECTED" >&2
             exit 2
        fi ;;
  esac
  shift
done
[ -n "$ticket" ] || { echo "hotfix-cve.sh: missing <ticket-id>" >&2; usage >&2; exit 2; }
# [a-zA-Z0-9._-]+, no leading dash. Accepts "CVE-2026-1234" alongside
# the pure kebab-case "cve-2026-1234"; rejects shell metacharacters
# so the file path cannot escape decisions/waivers/.
case "$ticket" in
  "" | -* | *[!a-zA-Z0-9._-]*)
    echo "hotfix-cve.sh: invalid ticket id: $ticket" >&2
    echo "diagnostic: MC-HOTFIX-INVALID-ID" >&2
    exit 2 ;;
esac

# --- expires_at: GNU date preferred, BSD fallback ---------------------
# GNU:  -d "+24 hours"      BSD:  -v+24H
compute_expires_at() {
  norm=$(printf '%s' "$expires_in" | tr -d ' ')
  case "$norm" in
    *[!0-9hmHdD]*|'') return 1 ;;
  esac
  case "$norm" in
    *h|*H) gnu_arg="$(printf '%s' "$norm" | sed 's/[hH]$/ hours/')"
           bsd_arg="-v+$(printf '%s' "$norm" | sed 's/[hH]$//')H" ;;
    *m|*M) gnu_arg="$(printf '%s' "$norm" | sed 's/[mM]$/ minutes/')"
           bsd_arg="-v+$(printf '%s' "$norm" | sed 's/[mM]$//')M" ;;
    *d|*D) gnu_arg="$(printf '%s' "$norm" | sed 's/[dD]$/ days/')"
           bsd_arg="-v+$(printf '%s' "$norm" | sed 's/[dD]$//')D" ;;
    *) return 1 ;;
  esac
  if out=$(date -u -d "$gnu_arg" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null); then
    printf '%s\n' "$out"; return 0
  fi
  if out=$(date -u "$bsd_arg" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null); then
    printf '%s\n' "$out"; return 0
  fi
  return 1
}
expires_at=$(compute_expires_at) || {
  echo "hotfix-cve.sh: cannot compute expires_at for --expires-in=$expires_in" >&2
  echo "diagnostic: MC-HOTFIX-DATE-FAILED" >&2
  exit 2
}

# --- render -------------------------------------------------------------
[ -n "$reason" ] || reason="CVE/incident ${ticket}; post-hoc attestation due ${expires_at}"
user="${USER:-$(whoami 2>/dev/null || echo unknown)}"
waiver_dir="decisions/waivers"
[ -d "$waiver_dir" ] || mkdir -p "$waiver_dir" 2>/dev/null || {
  echo "hotfix-cve.sh: cannot create $waiver_dir" >&2
  echo "diagnostic: MC-HOTFIX-MKDIR" >&2; exit 2
}
waiver_path="$waiver_dir/hotfix-${ticket}.yaml"
printf '%s\n' \
  '---' \
  'schema: math-coding/waiver-3.3' \
  'kind: waiver' \
  "id: hotfix-${ticket}" \
  'policy_id: bootstrap-v3' \
  'rule: obligation-missing-attestation' \
  'subject: bootstrap-v3@3' \
  "issuer: human:${user}" \
  "issued_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "expires_at: ${expires_at}" \
  'reason: |' \
  "  ${reason}" \
  'unverified_obligation: post-hoc-attestation-required' \
  'compensating_controls:' \
  '  - post-hoc decision must land before expires_at' \
  > "$waiver_path"
printf '%s\n' "hotfix-cve.sh: wrote ${waiver_path}"
exit 0