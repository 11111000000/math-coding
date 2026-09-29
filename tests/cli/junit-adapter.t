mc attest FILE parses a JUnit XML report and emits a JSON summary
on stdout containing the keys "suite_name", "test_count",
"failure_count", "skip_count", and "tests" (with at least one
pass and one failure so an empty parser is rejected). Acceptance
gate for obligation junit-attestation-import in
bootstrap/adapters.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cat > "$tmp/report.xml" <<EOF
  > <?xml version="1.0" encoding="UTF-8"?>
  > <testsuite name="demo" tests="2" failures="1" skipped="0">
  >   <testcase classname="d" name="pass-case"/>
  >   <testcase classname="d" name="fail-case"><failure>oops</failure></testcase>
  > </testsuite>
  > EOF
  $ mathc attest "$tmp/report.xml"
  {"error_count":0,"failure_count":1,"skip_count":0,"suite_name":"demo","test_count":2,"tests":[{"classname":"d","message":null,"name":"pass-case","result":"pass","time":null},{"classname":"d","message":null,"name":"fail-case","result":"fail","time":null}]}
  $ rm -rf "$tmp"
