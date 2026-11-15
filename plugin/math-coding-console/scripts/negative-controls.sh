#!/bin/sh
# Every negative control breaks one line of the subject and asks the check that
# covers it to fail. The controls do not depend on each other, so each of them
# gets its own copy of the tree and they run side by side. A control that does
# not catch its break fails the whole script.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The bound keeps the controls from crowding the machine they run on.
MAX_JOBS=${MATHC_NEGATIVE_JOBS:-3}
case "$MAX_JOBS" in
  '' | *[!0-9]*) MAX_JOBS=3 ;;
esac
[ "$MAX_JOBS" -ge 1 ] || MAX_JOBS=1

# A control can only fail a check when the packages are there: without them the
# check cannot start, and every control would look like a caught break.
if [ ! -x "$ROOT/node_modules/.bin/tsx" ]; then
  echo "negative-control: the packages are not installed" >&2
  exit 1
fi

PIDS=""
FAILURES=0
TOTAL=0

prepare() {
  dir=$1
  mkdir -p "$dir"
  cp -R "$ROOT/shared" "$ROOT/server" "$ROOT/client" "$ROOT/test" "$ROOT/scripts" "$dir/"
  cp "$ROOT/package.json" "$ROOT/tsconfig.json" "$ROOT/index.client.tsx" "$dir/"
  ln -s "$ROOT/node_modules" "$dir/node_modules"
}

# A control breaks one line and asks the check that covers it to fail. The
# check has to fail: a check that still passes means the break went unnoticed.
control_check() {
  name=$1
  file=$2
  expression=$3
  target=$4
  dir=$5
  sed -i "$expression" "$dir/$file"
  if (cd "$dir" && ./node_modules/.bin/tsx --test "$target" >/dev/null 2>&1); then
    echo "negative-control: FAIL $name (the broken copy still passed)" >"$dir/result"
    return 1
  fi
  echo "negative-control: ok $name" >"$dir/result"
}

# The client audit is a rule of the build, so it has to fail when the shared
# interface names the host package directly.
control_audit() {
  name=$1
  file=$2
  expression=$3
  target=$4
  dir=$5
  sed -i "$expression" "$dir/$file"
  if (cd "$dir" && sh scripts/audit-client.sh >"$dir/audit.out" 2>&1); then
    echo "negative-control: FAIL $name (the client audit still passed)" >"$dir/result"
    return 1
  fi
  if ! grep -q "forbidden host import" "$dir/audit.out"; then
    echo "negative-control: FAIL $name (the client audit failed for another reason)" >"$dir/result"
    cat "$dir/audit.out" >>"$dir/result"
    return 1
  fi
  echo "negative-control: ok $name" >"$dir/result"
}

# The control runs beside the others, and the bound keeps the number of
# running controls at the limit: the oldest one is waited for when there are
# already too many.
start() {
  "$@" &
  PIDS="$PIDS $!"
  set -- $PIDS
  while [ "$#" -ge "$MAX_JOBS" ]; do
    oldest=$1
    shift
    PIDS="$*"
    if ! wait "$oldest"; then
      FAILURES=$((FAILURES + 1))
    fi
    set -- $PIDS
  done
}

start_control() {
  TOTAL=$((TOTAL + 1))
  dir="$WORK/control-$TOTAL"
  prepare "$dir"
  start "$@" "$dir"
}

start_control \
  control_check \
  "red and unknown are canonical results" \
  "server/project.ts" \
  's/!\[0, 1, 3\]/[0]/' \
  "test/project.test.ts"

start_control \
  control_check \
  "map and spec must describe the same claims" \
  "server/project.ts" \
  's/map.claims !== claims.length/false/' \
  "test/project.test.ts"

start_control \
  control_check \
  "a corrupt JSONL line cannot be skipped" \
  "server/evidence.ts" \
  's/return lines.map(/return lines.filter((line) => !line.includes("not-json")).map(/' \
  "test/contracts.test.ts"

start_control \
  control_check \
  "the graph cannot invent claim dependencies" \
  "client/graph-layout.ts" \
  '/  const represented =/i\  edges.push({ id: "fake-dependency", from: "claim:a", to: "claim:b", kind: "scope" });' \
  "test/graph.test.ts"

start_control \
  control_check \
  "an unsupported schema cannot be accepted" \
  "shared/domain.ts" \
  's/z.literal(5)/z.literal(4)/g' \
  "test/contracts.test.ts"

start_control \
  control_check \
  "snapshot cannot execute project checks" \
  "server/core/operations.ts" \
  's|loadProject(workspace.directory, runtime.binary);|loadProject(workspace.directory, runtime.binary, "run");|' \
  "test/service.test.ts"

start_control \
  control_check \
  "run checks cannot bypass the disabled setting" \
  "server/core/operations.ts" \
  's/if (!runtime.allowRunChecks)/if (false)/' \
  "test/service.test.ts"

start_control \
  control_check \
  "a changed source cannot be delegated to an agent" \
  "client/attention.ts" \
  's/if (sourceChanged) {/if (false \&\& sourceChanged) {/' \
  "test/attention.test.ts"

start_control \
  control_check \
  "a waiver record is not accepted risk without canonical waived state" \
  "client/attention.ts" \
  's/state === "waived" && claim.waiver/claim.waiver/' \
  "test/attention.test.ts"

start_control \
  control_check \
  "a waived review cannot become a pending human decision" \
  "client/attention.ts" \
  's/reviews.length > 0 && state !== "holds" && state !== "waived"/reviews.length > 0 \&\& state !== "holds"/' \
  "test/attention.test.ts"

start_control \
  control_check \
  "an expired waiver cannot override canonical holds" \
  "client/attention.ts" \
  's/claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds"/claim.waiver \&\& nowSeconds >= claim.waiver.expires_at/' \
  "test/attention.test.ts"

start_control \
  control_check \
  "an expired canonical waiver cannot disappear" \
  "client/attention.ts" \
  's/claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds"/claim.waiver \&\& nowSeconds >= claim.waiver.expires_at \&\& state === "holds"/' \
  "test/attention.test.ts"

start_control \
  control_check \
  "machine work in a mixed claim cannot be hidden" \
  "client/attention.ts" \
  's/machineRequirements(claim).length === 0/true/' \
  "test/attention.test.ts"

start_control \
  control_audit \
  "the shared interface cannot import the host package" \
  "client/parts.tsx" \
  's|^import { useState, type ReactNode } from "react";|import { Icon as HostIcon } from "@getpaseo/plugin/client/ui";\nimport { useState, type ReactNode } from "react";|' \
  "-"

set -- $PIDS
for pid in "$@"; do
  if ! wait "$pid"; then
    FAILURES=$((FAILURES + 1))
  fi
done

index=1
while [ "$index" -le "$TOTAL" ]; do
  if [ -f "$WORK/control-$index/result" ]; then
    cat "$WORK/control-$index/result"
  fi
  index=$((index + 1))
done

if [ "$FAILURES" -gt 0 ]; then
  echo "negative-control: FAIL ($FAILURES of $TOTAL controls did not catch their break)" >&2
  exit 1
fi

echo "negative-control: PASS ($TOTAL controls)"
