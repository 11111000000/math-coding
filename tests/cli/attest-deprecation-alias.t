`mathc attest FILE` is preserved as a deprecation alias for
`mathc import-junit FILE`. Per plan-2026-11-adoption-fixes §4 B1,
the alias emits a one-shot stderr warning naming `import-junit` as
the canonical replacement, then forwards to the same JUnit XML
parser. The original stdout JSON is unchanged so existing scripts
keep working without modification.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cat > "$tmp/report.xml" <<EOF
  > <?xml version="1.0" encoding="UTF-8"?>
  > <testsuite name="demo" tests="2" failures="1" skipped="0">
  >   <testcase classname="d" name="pass-case"/>
  >   <testcase classname="d" name="fail-case"><failure>oops</failure></testcase>
  > </testsuite>
  > EOF

The alias exits 0 and writes the canonical JSON to stdout (the
warning goes to stderr; pipelines that capture stdout are
unaffected).

  $ mathc attest "$tmp/report.xml" 2>/tmp/alias.stderr
  {"error_count":0,"failure_count":1,"skip_count":0,"suite_name":"demo","test_count":2,"tests":[{"classname":"d","message":null,"name":"pass-case","result":"pass","time":null},{"classname":"d","message":null,"name":"fail-case","result":"fail","time":null}]}

The stderr warning names both the deprecated verb and the
canonical replacement, exactly once.

  $ grep -c "deprecated" /tmp/alias.stderr
  1
  $ grep -c "import-junit" /tmp/alias.stderr
  1
  $ cat /tmp/alias.stderr
  warning: 'mathc attest FILE' is deprecated; use 'mathc import-junit FILE' for JUnit XML parsing. (plans/2026-11-adoption-fixes §4 B1)

  $ rm -rf "$tmp" /tmp/alias.stderr
