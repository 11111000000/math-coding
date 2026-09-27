Run `mc assess BASE HEAD` against a temporary git repo.

The cram test sets up a fresh git repo with two commits (an empty
bootstrap commit and a second commit that adds a single file), then
invokes `_build/default/bin/mathc.exe assess HEAD~1 HEAD` from inside
that repo. The expected output is a JSON array containing the file
path added by the second commit.

The git adapter (lib/git/git_diff.changed_files) uses the cwd passed
by `mc assess`, so the cram test cd's into the temp repo before
invoking mathc. The temp repo is created in a subdirectory of the
cram scratch space; nothing has to be cleaned up because the cram
sandbox is destroyed when the test finishes.

  $ repo="$TMPDIR/repo"
  $ mkdir -p "$repo"
  $ cd "$repo"
  $ git init -q
  $ git -c user.email=t@t.local -c user.name=t commit -q --allow-empty -m c1
  $ printf 'assess fixture\n' > sample.txt
  $ git add sample.txt
  $ git -c user.email=t@t.local -c user.name=t commit -q -m c2
  $ "$INSIDE_DUNE/bin/mathc.exe" assess HEAD~1 HEAD
  ["sample.txt"]
