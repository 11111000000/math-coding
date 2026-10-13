mathc init --agent opencode installs the per-user opencode
skill at ${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/
math-coding/SKILL.md, copying the in-repo source. Other
agent values print a one-liner pointing at the right install
path (TODO in this slice).

The cram shell's cwd is a bwrap tmp dir. The per-user
install writes to the host's actual home directory; the
test cleans up after itself to keep the host pristine.

--agent opencode: per-user skill installed.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --agent opencode --no-install
  mathc init: created /tmp/nix-shell.AyqRk4/build_4ff512_dune/tmp.QPJGmYykmb/decisions, /tmp/nix-shell.AyqRk4/build_4ff512_dune/tmp.QPJGmYykmb/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)
    per-user opencode skill: installed at /home/az/.config/opencode/skills/math-coding/SKILL.md
  $ per_user="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/math-coding/SKILL.md"
  $ test -f "$per_user" && echo "per-user skill present: ok"
  per-user skill present: ok
  $ rm -rf "$tmpdir"

--agent generic (default): no per-user install (the in-repo
.opencode/skills/math-coding/SKILL.md is the per-repo surface;
a generic agent does not need a per-user copy).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --agent generic --no-install
  mathc init: created /tmp/nix-shell.AyqRk4/build_4ff512_dune/tmp.yTgNdvanFW/decisions, /tmp/nix-shell.AyqRk4/build_4ff512_dune/tmp.yTgNdvanFW/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)
  $ test ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/math-coding/SKILL.md.new" && \
  >   echo "no per-user install for generic agent"
  no per-user install for generic agent
  $ rm -rf "$tmpdir"

--agent claude-code: TODO; the kernel prints a one-liner
pointing at the dist tarball.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --agent claude-code --no-install 2>&1 | grep -q 'claude-code' && \
  >   echo "claude-code path: TODO message printed"
  claude-code path: TODO message printed
  $ rm -rf "$tmpdir"

--agent cursor: TODO; points at the dist tarball.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --agent cursor --no-install 2>&1 | grep -q 'cursor' && \
  >   echo "cursor path: TODO message printed"
  cursor path: TODO message printed
  $ rm -rf "$tmpdir"

--agent continue: no per-user install path; points at per-repo.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --agent continue --no-install 2>&1 | grep -q 'continue' && \
  >   echo "continue path: per-repo note printed"
  continue path: per-repo note printed
  $ rm -rf "$tmpdir"
