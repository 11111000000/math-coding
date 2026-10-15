`mathc find KEYWORD [--obligation=ID]` searches the
decisions corpus for case-insensitive substring matches
(decision `mathc-find-subcommand-2026-10`). The output is a
`mathc packages`-shaped JSON object with the `decisions[]`
array filtered to matches.

This fixture exercises four cases. The keyword search
(`mathc find mcp`) returns decisions whose id, obligation id,
or obligation verifier contains "mcp". The no-match case
(`mathc find this-string-does-not-exist-anywhere`) returns an
empty `decisions[]` array, exit 0. The obligation lookup
(`mathc find --obligation=<id>`) returns the enclosing
decision + the canonical attestation path. Missing keyword
(`mathc find`) exits 2 with an input error.

Exit codes follow OCAML_BEST_PRACTICES.md §4.3: 0 on
success (including zero matches), 2 on input error.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc find mcp --format=json > /tmp/find-mcp.json
  $ grep -q '"decision_id":"mcp-agent-auto-connect-2026-10"' /tmp/find-mcp.json \
  >   && grep -q '"decision_id":"mcp-server-impl-2026-10"' /tmp/find-mcp.json \
  >   && echo "find mcp: matches include the mcp-agent-auto-connect and mcp-server-impl decisions" \
  >   || echo "FAIL: find mcp missing expected ids"
  find mcp: matches include the mcp-agent-auto-connect and mcp-server-impl decisions

  $ cd "$DUNE_SOURCEROOT"
  $ mathc find this-string-does-not-exist-anywhere --format=json > /tmp/find-no.json
  $ grep -q '"decisions":\[\]' /tmp/find-no.json \
  >   && echo "find no-match: empty decisions[], shape preserved" \
  >   || echo "FAIL: expected empty decisions array"
  find no-match: empty decisions[], shape preserved

  $ cd "$DUNE_SOURCEROOT"
  $ mathc find --obligation=mcp-section-in-skill-md --format=json > /tmp/find-ob.json
  $ grep -q '"decision_id":"mcp-agent-auto-connect-2026-10"' /tmp/find-ob.json \
  >   && grep -q 'attestation_path.*mcp-agent-auto-connect-2026-10-mcp-section-in-skill-md.json' /tmp/find-ob.json \
  >   && echo "find --obligation: returns enclosing decision + attestation_path" \
  >   || echo "FAIL: obligation lookup missing enclosing decision / attestation_path"
  find --obligation: returns enclosing decision + attestation_path

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc find 2>&1 | grep -q 'KEYWORD or --obligation=ID is required'; then \
  >   echo "find (no args): input error"; \
  > else echo "FAIL: expected usage error"; fi
  find (no args): input error
