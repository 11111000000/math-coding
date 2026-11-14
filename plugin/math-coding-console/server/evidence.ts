import {
  evidenceSchema,
  type Claim,
  type Evidence,
  type EvidenceRecord,
} from "../shared/domain";
import { canonicalJson, requirementPathMap, requirementKey } from "../shared/requirements";
import { parseJson, parseWith } from "./files";

export function parseTrail(text: string): Evidence[] {
  if (text === "") return [];
  const lines = text.split("\n");
  if (lines.at(-1) === "") lines.pop();
  return lines.map((line, index) =>
    parseWith(evidenceSchema, parseJson(line, `evidence trail line ${index + 1}`), `evidence line ${index + 1}`),
  );
}

export function linkEvidence(records: Evidence[], claims: Claim[]): EvidenceRecord[] {
  const paths = new Map(claims.map((claim) => [claim.id, requirementPathMap(claim)]));
  return records.map((record, sequence) => ({
    ...record,
    sequence,
    requirementPaths: paths.get(record.claim_id)?.get(requirementKey(record.requirement)) ?? [],
  }));
}

export function newestFirst(records: EvidenceRecord[]): EvidenceRecord[] {
  return [...records].sort((a, b) => b.issued_at - a.issued_at || b.sequence - a.sequence);
}

export function evidencePage<T>(records: T[], cursor = 0, limit = 80): {
  records: T[];
  nextCursor: number | null;
} {
  const selected = records.slice(cursor, cursor + limit);
  return {
    records: selected,
    nextCursor: cursor + selected.length < records.length ? cursor + selected.length : null,
  };
}

export function revisionInput(map: unknown, claims: unknown): string {
  return canonicalJson({ map, claims });
}
