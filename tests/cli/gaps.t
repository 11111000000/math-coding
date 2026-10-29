mathc gaps -- the worklist: every open promise, its class, and what
can be done about it.

The report says HOW MANY obligations are undecided. This command says
WHICH, and what can be done about each one. The classification is the
kernel's own dispatch, and this fixture pins all four classes:

declaration     the verifier is a `manual-` declaration: the kernel
does not execute it and says so.
unknown-scheme  the verifier names a command the kernel does not
know: neither a check nor a declaration.
checkable       the kernel can execute it here; the gap is about
EVIDENCE.
unidentified    the obligation has no id, so no gate ever decides it.

The worklist is built by the SAME code the gate uses to decide an
obligation's evidence (`Gate.obligation_gap`), so it cannot disagree
with the verdict about what is missing. The corpus here is a scratch
project with one decision per class, so the expected output is the
classification itself and not a count that moves with the real corpus.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ mkdir -p decisions && echo ok > present.txt
  $ cat > decisions/decl-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: decl-probe
  > revision: 1
  > state: active
  > intent: a decision whose only verifier is a declaration
  > commitment: the declaration is the promise
  > obligations:
  >   - id: declared-gap
  >     claim: a gap no program can run
  >     acceptance:
  >       all:
  >         - verifier: manual-text-scan-readme-md
  >           result: pass
  > YAML
  $ cat > decisions/scheme-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: scheme-probe
  > revision: 1
  > state: active
  > intent: a decision whose verifier names a command that does not exist
  > commitment: the verifier is the promise
  > obligations:
  >   - id: imaginary-command
  >     claim: a check that names a command the kernel does not know
  >     acceptance:
  >       all:
  >         - verifier: mathc-not-a-command --now
  >           result: pass
  > YAML
  $ cat > decisions/checkable-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: checkable-probe
  > revision: 1
  > state: active
  > intent: a decision whose verifier the kernel can execute
  > commitment: the check is the promise
  > obligations:
  >   - id: real-check
  >     claim: a check the kernel can run
  >     acceptance:
  >       all:
  >         - verifier: file-exists present.txt
  >           result: pass
  > YAML
  $ cat > decisions/noid-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: noid-probe
  > revision: 1
  > state: active
  > intent: a decision with an obligation that carries no id
  > commitment: the promise is the promise
  > obligations:
  >   - claim: a promise no gate can name
  >     acceptance:
  >       all:
  >         - verifier: file-exists present.txt
  >           result: pass
  > YAML
  $ cat > decisions/malformed-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: malformed-probe
  > revision: 1
  > state: active
  > intent: a decision whose verifier names a known scheme with arguments it does not take
  > commitment: the string is wrong
  > obligations:
  >   - id: malformed-string
  >     claim: a path verifier with a case label after it
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/does-not-exist.t (positive case)
  >           result: pass
  > YAML
  $ MATH_CODING_ROOT="$tmpdir" $INSIDE_DUNE/bin/mathc.exe gaps --format=json | jq -c '{open: (.open|length), classes: ([.open[].class]|sort)}'
  {"open":5,"classes":["cannot-be-set-up","checkable","not-a-check","not-a-check","unidentified"]}
  $ MATH_CODING_ROOT="$tmpdir" $INSIDE_DUNE/bin/mathc.exe gaps --format=json | jq -c '[.open[] | {decision, obligation, class}] | sort_by(.class)'
  [{"decision":"malformed-probe","obligation":"malformed-string","class":"cannot-be-set-up"},{"decision":"checkable-probe","obligation":"real-check","class":"checkable"},{"decision":"decl-probe","obligation":"declared-gap","class":"not-a-check"},{"decision":"scheme-probe","obligation":"imaginary-command","class":"not-a-check"},{"decision":"noid-probe","obligation":"","class":"unidentified"}]
  $ MATH_CODING_ROOT="$tmpdir" $INSIDE_DUNE/bin/mathc.exe gaps --format=json | jq -r '[.open[] | select(.class=="not-a-check") | .action] | .[0]'
  this is not a check the kernel can run: write the check, cover the gap with a dated waiver, or drop the promise
  $ MATH_CODING_ROOT="$tmpdir" $INSIDE_DUNE/bin/mathc.exe gaps --format=text | head -2
  open gaps: 5
    checkable-probe/real-check  checkable missing
  $ cd /
  $ rm -rf "$tmpdir"
