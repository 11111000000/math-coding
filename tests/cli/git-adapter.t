mathc assess BASE HEAD runs git diff --name-only BASE..HEAD via
lib/git/git_diff.changed_files and emits a JSON array of the
changed file paths on stdout. The fixture creates a temp git repo
with a known two-commit history (HEAD~1 -> HEAD adds one file),
runs `mathc assess HEAD~1 HEAD` from inside the temp repo, asserts
exit 0 and a JSON array containing the added file. Acceptance
gate for obligation git-changed-files-adapter in
bootstrap/adapters.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ mathc assess HEAD~1 HEAD
  ["b.txt"]
  $ cd /
  $ rm -rf "$tmp"
