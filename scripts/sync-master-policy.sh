#!/bin/sh
# scripts/sync-master-policy.sh — ONE master policy, and the places
# that derive from it.
#
# WHAT THIS IS. The protocol's master policy is the document a project
# starts from: `id: bootstrap-v3`, the scope paths a newcomer edits,
# the one obligation that names their own tree. It used to live in
# three places, and the three had drifted apart:
#
#   1. `scripts/install-tooling/templates/active-policy.yaml` — the
#      copy the installer was supposed to ship. Nothing shipped it:
#      `MC_TEMPLATE_REMOTE_PATH` in `scripts/install-tooling/install.sh`
#      named it and never read it.
#   2. `lib/init/init.ml::master_policy_template` — the copy the
#      binary embeds and `mathc init` writes. Live, and the one an
#      adopter actually receives.
#   3. `decisions/decision.yaml` — THIS repository's instance of the
#      same id (`bootstrap-v3`), at revision 3, with this repository's
#      obligations. Not a copy: an instance. The kernel resolves the
#      active policy by id, and 50 live decisions name `bootstrap-v3`.
#
# The ONE source is `templates/master-policy.yaml`. Everything that is
# a COPY of it is generated from it, and this script is the generator.
#
# THE TWO DERIVED PLACES.
#
#   1. `scripts/install-tooling/templates/active-policy.yaml` — a
#      verbatim copy. It is a DECISION document (the kernel validates
#      it: `tests/cli/install.t`), which is why the copy cannot be a
#      policy sequence.
#   2. `lib/init/init.ml` — the OCaml string literal the binary
#      embeds. The literal is written in OCaml's continued-string form
#      (`"...\n\` + newline + indent), and this script reproduces that
#      form byte for byte: the round trip is checked by
#      `tests/fixtures/master-policy-one-source.sh`, which regenerates
#      the literal in a COPY of the file and requires the copy to come
#      out unchanged.
#
# MODES.
#
#   --check    exit 0 when every derived place matches the source,
#              exit 1 with the name of the place that drifted.
#   --write    rewrite the derived places from the source.
#
# EXIT CODES.
#   0  every derived place matches the source.
#   1  a derived place drifted (--check) or could not be written.
#   2  input error (unknown mode, missing source file).
#
# POSIX-sh, no bashisms. awk is the only tool it needs beyond the
# shell. Mirrors the pattern of scripts/sync-version.sh.

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

SOURCE="templates/master-policy.yaml"
DERIVED_COPY="scripts/install-tooling/templates/active-policy.yaml"
DERIVED_EMBEDDED="lib/init/init.ml"

mode="${1:-}"
case "$mode" in
  --check) mode="check" ;;
  --write) mode="write" ;;
  -h|--help|help|"")
    cat <<USAGE
Usage: scripts/sync-master-policy.sh --check | --write

  --check   exit 0 if every derived copy of the master policy matches
            $SOURCE, exit 1 with the name of the copy that drifted.
  --write   rewrite the derived copies from $SOURCE.

Reads:  $SOURCE
Writes (--write only): $DERIVED_COPY, $DERIVED_EMBEDDED
USAGE
    exit 0
    ;;
  *)
    echo "sync-master-policy: unknown mode: $mode (use --check or --write)" >&2
    exit 2
    ;;
esac

if [ ! -s "$SOURCE" ]; then
  echo "sync-master-policy: $SOURCE is missing or empty" >&2
  echo "diagnostic: MC-MASTER-POLICY-MISSING" >&2
  exit 2
fi

# --- the encoder: a YAML file -> the OCaml string literal ---------------
#
# The literal's shape (lib/init/init.ml):
#
#   let master_policy_template =
#     "schema: math-coding/3.2\n\
#      id: bootstrap-v3\n\
#     \  Master policy for this project. ...\n\
#
# Three rules, all of them OCaml's:
#
#   * `\<newline>` inside a string literal skips the newline AND the
#     whitespace that follows it. So a line's own indentation cannot
#     be written as leading whitespace: the FIRST space of the
#     indentation has to be written as the escape `\ `.
#   * A line whose YAML indentation is zero is written with three
#     plain spaces; a line whose indentation is N > 0 is written with
#     two plain spaces, then `\ `, then N-1 plain spaces.
#   * `"` and `\` are escaped.
#
# The last line closes the literal with `\n"` instead of `\n\`.
encode_literal() {
  awk '
    function esc(s,   out, i, c) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") out = out "\\\\"
        else if (c == "\"") out = out "\\\""
        else out = out c
      }
      return out
    }
    function indent_of(n) {
      if (n == 0) return "   "
      return "  \\ " sprintf("%*s", n - 1, "")
    }
    { lines[NR] = $0; last = NR }
    END {
      for (i = 1; i <= last; i++) {
        n = match(lines[i], /^ */)
        n = RLENGTH
        rest = substr(lines[i], n + 1)
        body = esc(rest)
        if (i == 1) {
          # The first line follows the opening quote directly, so its
          # own indentation (if any) is literal.
          if (last == 1) printf "  \"%s\\n\"\n", body
          else printf "  \"%s\\n\\\n", body
        } else if (i == last) {
          printf "%s%s\\n\"\n", indent_of(n), body
        } else {
          printf "%s%s\\n\\\n", indent_of(n), body
        }
      }
    }
  ' "$SOURCE"
}

# --- the decoder: the OCaml literal -> the YAML file --------------------
#
# The inverse of the encoder, used by --check. It reads the literal
# out of lib/init/init.ml and prints the YAML it holds.
decode_literal() {
  awk '
    function unesc(s,   out, i, c, nxt) {
      out = ""
      i = 1
      while (i <= length(s)) {
        c = substr(s, i, 1)
        if (c == "\\") {
          nxt = substr(s, i + 1, 1)
          if (nxt == "n") out = out "\n"
          else if (nxt == "t") out = out "\t"
          else if (nxt == "\\") out = out "\\"
          else if (nxt == "\"") out = out "\""
          else if (nxt == " ") out = out " "
          else out = out nxt
          i += 2
        } else {
          out = out c
          i++
        }
      }
      return out
    }
    BEGIN { inlit = 0; buf = "" }
    !inlit {
      if ($0 ~ /^let master_policy_template =/) inlit = 1
      next
    }
    {
      line = $0
      closing = (line ~ /"[[:space:]]*$/)
      if (line ~ /^[[:space:]]*"/) {
        # the opening line: the content starts after the first quote
        body = substr(line, index(line, "\"") + 1)
      } else {
        # a continuation line: OCaml skips the newline and the
        # whitespace that follows it, so the leading whitespace is
        # dropped -- except an escaped space, which is content.
        body = line
        sub(/^[[:space:]]+/, "", body)
        while (substr(body, 1, 2) == "\\ ") {
          body = " " substr(body, 3)
        }
      }
      if (closing) {
        # the line that closes the literal: its last quote is the
        # delimiter, not content
        sub(/"[[:space:]]*$/, "", body)
      }
      buf = buf unesc(body)
      if (closing) {
        printf "%s", buf
        exit
      }
    }
  ' "$DERIVED_EMBEDDED"
}

# --- the splice: write the literal into lib/init/init.ml ---------------
splice_embedded() {
  lit_file="$1"
  out_file="$DERIVED_EMBEDDED.sync.tmp"
  awk -v litfile="$lit_file" '
    BEGIN {
      while ((getline l < litfile) > 0) lit[++litn] = l
      close(litfile)
    }
    { lines[++n] = $0 }
    END {
      head = 0
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^let master_policy_template =/) { head = i; break }
      }
      if (head == 0) {
        print "sync-master-policy: no master_policy_template literal found" > "/dev/stderr"
        exit 1
      }
      lit_end = head + 1
      while (lit_end <= n && lines[lit_end] !~ /"[[:space:]]*$/) lit_end++
      for (i = 1; i <= n; i++) {
        if (i <= head) print lines[i]
        else if (i == head + 1) { for (j = 1; j <= litn; j++) print lit[j] }
        else if (i > lit_end) print lines[i]
      }
    }
  ' "$DERIVED_EMBEDDED" > "$out_file"
  mv "$out_file" "$DERIVED_EMBEDDED"
}

# --- the check ----------------------------------------------------------
check() {
  rc=0
  tmp="$(mktemp)" || { echo "sync-master-policy: mktemp failed" >&2; exit 1; }
  trap 'rm -f "$tmp"' EXIT INT TERM

  if [ ! -f "$DERIVED_COPY" ]; then
    echo "sync-master-policy: $DERIVED_COPY is missing" >&2
    rc=1
  elif ! cmp -s "$SOURCE" "$DERIVED_COPY"; then
    echo "sync-master-policy: $DERIVED_COPY has drifted from $SOURCE" >&2
    rc=1
  fi

  if [ ! -f "$DERIVED_EMBEDDED" ]; then
    echo "sync-master-policy: $DERIVED_EMBEDDED is missing" >&2
    rc=1
  else
    decode_literal > "$tmp"
    if ! cmp -s "$SOURCE" "$tmp"; then
      echo "sync-master-policy: the literal embedded in $DERIVED_EMBEDDED has drifted from $SOURCE" >&2
      rc=1
    fi
  fi

  if [ "$rc" -eq 0 ]; then
    echo "sync-master-policy: every derived copy matches $SOURCE"
  fi
  return "$rc"
}

# --- the write ----------------------------------------------------------
write() {
  mkdir -p "$(dirname "$DERIVED_COPY")"
  cp "$SOURCE" "$DERIVED_COPY"

  lit_tmp="$(mktemp)" || { echo "sync-master-policy: mktemp failed" >&2; exit 1; }
  encode_literal > "$lit_tmp"
  splice_embedded "$lit_tmp"
  rm -f "$lit_tmp"

  echo "sync-master-policy: wrote $DERIVED_COPY and the literal in $DERIVED_EMBEDDED"
}

case "$mode" in
  check) check ;;
  write) write ;;
esac
