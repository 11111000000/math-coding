`mathc find KEYWORD [--obligation=ID]` searches the
decisions corpus for case-insensitive substring matches
(decision `mathc-find-subcommand-2026-10`). The output is a
`mathc packages`-shaped JSON object with the `decisions[]`
array filtered to matches.

This fixture exercises four cases. The keyword search
(`mathc find packages`) returns decisions whose id, obligation id,
or obligation verifier contains "packages". The no-match case
(`mathc find this-string-does-not-exist-anywhere`) returns an
empty `decisions[]` array, exit 0. The obligation lookup
(`mathc find --obligation=<id>`) returns the enclosing
decision + the canonical attestation path. Missing keyword
(`mathc find`) exits 2 with an input error.

The keyword and the obligation used to be the MCP integration
decision (`mcp-agent-auto-connect-2026-10`), which the archive
tranche T2.2b moved to `archive/decisions/`: `mathc find` searches
the LIVE corpus, so a decision that has left it is not found. What
is under test is the mechanism - the keyword search matches, the
no-match search returns nothing, the obligation lookup returns the
enclosing decision and the canonical attestation path - so the
instance moved to a decision that is still live
(`mathc-packages-subcommand`).

Exit codes follow OCAML_BEST_PRACTICES.md §4.3: 0 on
success (including zero matches), 2 on input error.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe find packages --format=json > /tmp/find-packages.json
  $ grep -q '"decision_id":"mathc-packages-subcommand"' /tmp/find-packages.json \
  >   && echo "find packages: matches include the mathc-packages-subcommand decision" \
  >   || echo "FAIL: find packages missing expected ids"
  find packages: matches include the mathc-packages-subcommand decision

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe find this-string-does-not-exist-anywhere --format=json > /tmp/find-no.json
  $ grep -q '"decisions":\[\]' /tmp/find-no.json \
  >   && echo "find no-match: empty decisions[], shape preserved" \
  >   || echo "FAIL: expected empty decisions array"
  find no-match: empty decisions[], shape preserved

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe find --obligation=packages-kernel-walker --format=json > /tmp/find-ob.json
  $ grep -q '"decision_id":"mathc-packages-subcommand"' /tmp/find-ob.json \
  >   && grep -q 'attestation_path.*mathc-packages-subcommand-packages-kernel-walker.json' /tmp/find-ob.json \
  >   && echo "find --obligation: returns enclosing decision + attestation_path" \
  >   || echo "FAIL: obligation lookup missing enclosing decision / attestation_path"
  find --obligation: returns enclosing decision + attestation_path

  $ cd "$DUNE_SOURCEROOT"
  $ if $INSIDE_DUNE/bin/mathc.exe find 2>&1 | grep -q 'KEYWORD or --obligation=ID is required'; then \
  >   echo "find (no args): input error"; \
  > else echo "FAIL: expected usage error"; fi
  find (no args): input error
