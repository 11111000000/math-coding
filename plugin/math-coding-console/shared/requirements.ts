import type { Claim, Requirement } from "./domain";

export interface RequirementNode {
  path: string;
  parentPath: string | null;
  depth: number;
  requirement: Requirement;
}

export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`)
    .join(",")}}`;
}

export function requirementKey(requirement: Requirement): string {
  return canonicalJson(requirement);
}

export function flattenRequirements(claim: Claim): RequirementNode[] {
  const result: RequirementNode[] = [];
  const visit = (requirement: Requirement, path: string, parentPath: string | null, depth: number) => {
    result.push({ path, parentPath, depth, requirement });
    if ("all" in requirement || "any" in requirement) {
      const children = "all" in requirement ? requirement.all : requirement.any;
      children.forEach((child, index) => visit(child, `${path}/${index}`, path, depth + 1));
    }
  };
  claim.requirements.forEach((requirement, index) => visit(requirement, String(index), null, 0));
  return result;
}

export function requirementPathMap(claim: Claim): Map<string, string[]> {
  const result = new Map<string, string[]>();
  for (const node of flattenRequirements(claim)) {
    const key = requirementKey(node.requirement);
    const paths = result.get(key) ?? [];
    paths.push(node.path);
    result.set(key, paths);
  }
  return result;
}

export function requirementLabel(requirement: Requirement): string {
  if ("all" in requirement) return `all (${requirement.all.length})`;
  if ("any" in requirement) return `any (${requirement.any.length})`;
  return requirement.kind === "verifier" ? requirement.spec : `review: ${requirement.spec}`;
}

export function shortRequirement(requirement: Requirement, max = 72): string {
  const label = requirementLabel(requirement);
  return label.length <= max ? label : `${label.slice(0, max - 1)}…`;
}
