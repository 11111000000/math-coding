Run `mc attest FILE` against a JUnit XML fixture.

The cram test writes a minimal JUnit XML report to a temp path, then
invokes `_build/default/bin/mathc.exe attest` on it. The expected
output is a JSON object containing the JUnit summary fields,
including test_count=2 (one pass, one failure) and failure_count=1.

The temp file lives in the cram scratch directory (`$TMPDIR`); the
binary writes to stdout only, so no extra cleanup is required.

  $ cat > "$TMPDIR/sample.xml" <<'XML'
  > <?xml version="1.0" encoding="UTF-8"?>
  > <testsuite name="cram.sample" tests="2" failures="1" errors="0" skipped="0">
  >   <testcase classname="cram.A" name="passes" time="0.01"/>
  >   <testcase classname="cram.B" name="fails" time="0.02">
  >     <failure message="oops" type="AssertionError">trace</failure>
  >   </testcase>
  > </testsuite>
  > XML
  $ "$INSIDE_DUNE/bin/mathc.exe" attest "$TMPDIR/sample.xml"
  {"error_count":0,"failure_count":1,"skip_count":0,"suite_name":"cram.sample","test_count":2,"tests":[{"classname":"cram.A","message":null,"name":"passes","result":"pass","time":"0.01"},{"classname":"cram.B","message":"oops","name":"fails","result":"fail","time":"0.02"}]}
