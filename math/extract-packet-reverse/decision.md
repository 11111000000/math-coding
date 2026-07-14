# extract-packet-reverse

## Thesis

A packet's five files can be reverse-extracted to a single
YAML spec via one shell call. The agent or tool can ingest
the spec without parsing markdown.

## Antithesis

The five files of a packet are well-structured, but
ingesting them requires parsing five separate files. A
single-spec output is easier to consume in pipelines
(other tools, cross-convention migration, regression
analysis).

## Synthesis

`sh math-coding extract <name>` reads the five files of
`math/<name>/` and emits a single YAML spec to stdout.
The output is in the **same shape** as `create-packet.sh`
input, so:

```
sh math-coding extract cache-ttl > /tmp/spec.yaml
sh math-coding create cache-ttl-renamed --from /tmp/spec.yaml
```

This is the **round-trip**: extract → create produces a
new packet with the same content.

## Surface impact

touches: `core/author/extract-packet.sh` (new script),
`math-coding` dispatcher (new `extract` command)

## Proof

`tests/run.sh` adds a case: extract a packet, then
re-create it, then verify that the re-created packet has
the same 5 files with the same content. axiom Self-Application
holds because probe.sh accepts both packets.