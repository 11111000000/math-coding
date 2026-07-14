# Refinement: packet-lifecycle

## State

- pre: a packet may be edited in place; witness meaningless;
  history unknowable.
- post: a packet is append-only at commit level; every
  change leaves a SHA; supersession spawns a new packet.

## Operation

1. Create a packet via `sh math-coding create <name> --from
   <spec.yaml>` (or `init <name>` for legacy template mode).
   This writes five files. lifecycle: sketch.

2. Fill in the five files with content matching the spec.
   The verifier accepts placeholder content (sketch is
   permissive).

3. Move to working: add the first commit with code.
   `applications: []` is allowed at working. `verify.sh`
   may emit warnings but should not block.

4. Move to verified: ensure axiom A6 holds for this packet
   (tests pass, structure clean). Add the first SHA to
   `applications[]`. lifecycle: verified.

5. Amendments: each new commit adds a new entry to
   `applications[]`. The proposition is unchanged; the
   evidence is richer.

6. Supersession: when the proposition itself changes,
   create `math/<name>-v2/` with a `supersession:` block
   pointing back. The old packet's lifecycle becomes
   superseded. **Do not edit the old packet.**

7. Deprecation: lifecycle becomes deprecated when the
   packet is superseded but still referenced. Once nothing
   references it, move to archived.

## Mapping

| change kind | mechanism | git footprint |
|-------------|-----------|----------------|
| typo fix | amendment | +1 commit, +1 applications entry |
| new test | amendment | +1 commit, +1 applications entry |
| proposition changes | supersession | +1 new directory, no edits to old |
| rename | not allowed | (use supersession instead) |
| delete | archival | lifecycle: archived, file remains |

## Invariant preservation

- For every packet with `lifecycle: verified`, the verifier
  must find at least one entry in `applications[]` whose
  SHA points to a commit where the listed files match HEAD.

- For every `supersession:` block, the named successor must
  exist as a directory under math/.

- For every packet with `lifecycle: superseded` or
  `lifecycle: archived`, `applications[]` is frozen: no new
  entries may be added.

## Test obligation

- axiom A6 — the verifier checks `supersession:` references
  resolve.
- `sh core/check/drift-check.sh` — every `applications[].sha`
  either matches HEAD (applied) or is unknown (lookahead).

## Runtime check

None. The lifecycle is enforced at commit time.