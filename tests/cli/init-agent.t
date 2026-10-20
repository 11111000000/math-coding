mathc init --agent opencode installs the per-user opencode
skill at ${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/
math-coding/SKILL.md, copying the in-repo source. Other
agent values print a one-liner pointing at the right install
path (TODO in this slice).

Path independence (rev 2, decision
`kernel-fixes-found-bugs-2026-10@1`): `$XDG_CONFIG_HOME` is
redirected into a fresh `mktemp -d`, and the assertions are greps
over captured output. The previous revision embedded literal
`/tmp/nix-shell.XXXX/...` paths in its expected output — including
the per-user skill path — so the file could not pass on any run.

--agent opencode: per-user skill installed.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/xdg"
  $ export XDG_CONFIG_HOME="$tmpdir/xdg"
  $ export HOME="$tmpdir"
  $ mathc init "$tmpdir/repo" --agent opencode --no-install > init.log 2>&1
  $ grep -q 'created .*/repo/.math-coding/decisions' init.log && echo "layout: .math-coding/"
  layout: .math-coding/
  $ grep -q 'per-user opencode skill: installed at ' init.log && echo "per-user line present"
  per-user line present
  $ per_user="$XDG_CONFIG_HOME/opencode/skills/math-coding/SKILL.md"
  $ test -f "$per_user" && echo "per-user skill present: ok"
  per-user skill present: ok
  $ cmp -s "$DUNE_SOURCEROOT/adoption/SKILL.md" "$per_user" && echo "copy matches the canonical skill"
  copy matches the canonical skill
  $ cd /
  $ rm -rf "$tmpdir"

--agent generic (default): no per-user install (the in-repo
.opencode/skills/math-coding/SKILL.md is the per-repo surface;
a generic agent does not need a per-user copy).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/xdg"
  $ export XDG_CONFIG_HOME="$tmpdir/xdg"
  $ mathc init "$tmpdir/repo" --agent generic --no-install > init.log 2>&1
  $ ! grep -q 'per-user opencode skill' init.log && echo "no per-user line for generic agent"
  no per-user line for generic agent
  $ test ! -e "${XDG_CONFIG_HOME}/opencode/skills/math-coding/SKILL.md" \
  >   && echo "no per-user install for generic agent"
  no per-user install for generic agent
  $ cd /
  $ rm -rf "$tmpdir"
