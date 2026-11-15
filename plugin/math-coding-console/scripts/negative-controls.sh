#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp -R "$ROOT/shared" "$ROOT/server" "$ROOT/client" "$ROOT/test" "$ROOT/scripts" "$TMP/"
cp "$ROOT/package.json" "$ROOT/tsconfig.json" "$ROOT/index.client.tsx" "$TMP/"
ln -s "$ROOT/node_modules" "$TMP/node_modules"

run_control() {
  name=$1
  file=$2
  expression=$3
  target=$4
  cp "$TMP/$file" "$TMP/$file.original"
  sed -i "$expression" "$TMP/$file"
  if (cd "$TMP" && npx tsx --test "$target" >/dev/null 2>&1); then
    echo "negative-control: FAIL $name (the broken copy still passed)" >&2
    mv "$TMP/$file.original" "$TMP/$file"
    exit 1
  fi
  mv "$TMP/$file.original" "$TMP/$file"
  echo "negative-control: ok $name"
}

run_control \
  "red and unknown are canonical results" \
  "server/project.ts" \
  's/!\[0, 1, 3\]/[0]/' \
  "test/project.test.ts"

run_control \
  "map and spec must describe the same claims" \
  "server/project.ts" \
  's/map.claims !== claims.length/false/' \
  "test/project.test.ts"

run_control \
  "a corrupt JSONL line cannot be skipped" \
  "server/evidence.ts" \
  's/return lines.map(/return lines.filter((line) => !line.includes("not-json")).map(/' \
  "test/contracts.test.ts"

run_control \
  "the graph cannot invent claim dependencies" \
  "client/graph-layout.ts" \
  '/  const represented =/i\  edges.push({ id: "fake-dependency", from: "claim:a", to: "claim:b", kind: "scope" });' \
  "test/graph.test.ts"

run_control \
  "an unsupported schema cannot be accepted" \
  "shared/domain.ts" \
  's/z.literal(5)/z.literal(4)/g' \
  "test/contracts.test.ts"

run_control \
  "snapshot cannot execute project checks" \
  "server/core/operations.ts" \
  's|loadProject(workspace.directory, runtime.binary);|loadProject(workspace.directory, runtime.binary, "run");|' \
  "test/service.test.ts"

run_control \
  "run checks cannot bypass the disabled setting" \
  "server/core/operations.ts" \
  's/if (!runtime.allowRunChecks)/if (false)/' \
  "test/service.test.ts"

run_control \
  "a changed source cannot be delegated to an agent" \
  "client/attention.ts" \
  's/if (sourceChanged) {/if (false \&\& sourceChanged) {/' \
  "test/attention.test.ts"

run_control \
  "a waiver record is not accepted risk without canonical waived state" \
  "client/attention.ts" \
  's/state === "waived" && claim.waiver/claim.waiver/' \
  "test/attention.test.ts"

run_control \
  "a waived review cannot become a pending human decision" \
  "client/attention.ts" \
  's/reviews.length > 0 && state !== "holds" && state !== "waived"/reviews.length > 0 && state !== "holds"/' \
  "test/attention.test.ts"

run_control \
  "an expired waiver cannot override canonical holds" \
  "client/attention.ts" \
  's/claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds"/claim.waiver \&\& nowSeconds >= claim.waiver.expires_at/' \
  "test/attention.test.ts"

run_control \
  "an expired canonical waiver cannot disappear" \
  "client/attention.ts" \
  's/claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds"/claim.waiver \&\& nowSeconds >= claim.waiver.expires_at \&\& state === "holds"/' \
  "test/attention.test.ts"

run_control \
  "machine work in a mixed claim cannot be hidden" \
  "client/attention.ts" \
  's/machineRequirements(claim).length === 0/true/' \
  "test/attention.test.ts"

# The client audit is a rule of the build, so it has to fail when the shared
# interface names the host package directly.
run_audit_control() {
  name=$1
  file=$2
  expression=$3
  cp "$TMP/$file" "$TMP/$file.original"
  sed -i "$expression" "$TMP/$file"
  if (cd "$TMP" && sh scripts/audit-client.sh >"$TMP/audit.out" 2>&1); then
    echo "negative-control: FAIL $name (the client audit still passed)" >&2
    mv "$TMP/$file.original" "$TMP/$file"
    exit 1
  fi
  if ! grep -q "forbidden host import" "$TMP/audit.out"; then
    echo "negative-control: FAIL $name (the client audit failed for another reason)" >&2
    cat "$TMP/audit.out" >&2
    mv "$TMP/$file.original" "$TMP/$file"
    exit 1
  fi
  mv "$TMP/$file.original" "$TMP/$file"
  echo "negative-control: ok $name"
}

run_audit_control \
  "the shared interface cannot import the host package" \
  "client/parts.tsx" \
  's|^import { useState, type ReactNode } from "react";|import { Icon as HostIcon } from "@getpaseo/plugin/client/ui";\nimport { useState, type ReactNode } from "react";|'

echo "negative-control: PASS"
