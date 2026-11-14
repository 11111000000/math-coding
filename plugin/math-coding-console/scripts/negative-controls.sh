#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp -R "$ROOT/shared" "$ROOT/server" "$ROOT/client" "$ROOT/test" "$TMP/"
cp "$ROOT/package.json" "$ROOT/tsconfig.json" "$TMP/"
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
  "server/service.ts" \
  's/loadProject(workspace.directory, binaryFromPreferences(values))/loadProject(workspace.directory, binaryFromPreferences(values), "run")/' \
  "test/service.test.ts"

run_control \
  "run checks cannot bypass the disabled setting" \
  "server/service.ts" \
  's/if (!values.allowRunChecks)/if (false)/' \
  "test/service.test.ts"

echo "negative-control: PASS"
