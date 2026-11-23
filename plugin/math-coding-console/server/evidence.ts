import {
  type Claim,
  type Evidence,
  type EvidenceRecord,
} from "../shared/domain";
import { canonicalJson, requirementPathMap, requirementKey } from "../shared/requirements";
import { readEvidence } from "../shared/schema";
import { parseJson } from "./files";

/**
 * The journal of a project, read in the generation of its records.
 *
 * A record of the previous generations is read in the format that generation
 * wrote, and a record that cannot be read refuses the whole journal: a
 * corrupt line is not a line that can be skipped.
 */
export function parseTrail(text: string, claims: Claim[] = []): Evidence[] {
  if (text === "") return [];
  const lines = text.split("\n");
  if (lines.at(-1) === "") lines.pop();
  return lines.map((line, index) => {
    const label = `evidence line ${index + 1}`;
    const json = parseJson(line, `evidence trail line ${index + 1}`);
    try {
      return readEvidence(json, claims).value;
    } catch (error) {
      throw new Error(`${label}: ${error instanceof Error ? error.message : String(error)}`);
    }
  });
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
