#!/bin/sh
# Every negative control breaks one line of the subject and asks the check that
# covers it to fail. The controls do not depend on each other, so each of them
# gets its own copy of the tree and they run side by side. A control that does
# not catch its break fails the whole script.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A filter names the check whose controls are wanted. Without it every control
# of the plugin runs. The filter keeps a focused verifier to its own controls,
# so the controls of one subject do not stand in for the controls of another.
FILTER=${1:-}

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
  # The last argument names the check the control must break. A filter keeps
  # only the controls of that check.
  target=""
  for argument in "$@"; do
    target=$argument
  done
  if [ -n "$FILTER" ] && [ "$target" != "$FILTER" ]; then
    return 0
  fi
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
  's/z.literal(6)/z.literal(5)/g' \
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

start_control \
  control_check \
  "the sheet of the host keeps the surface of the host" \
  "client/host/sheet.tsx" \
  's|<HostProvider value={host}>||; s|</HostProvider>||' \
  "test/host-sheet.test.ts"

start_control \
  control_check \
  "a human decision cannot bypass the disabled setting" \
  "server/core/operations.ts" \
  's/if (!runtime.allowHumanDecisions)/if (false)/' \
  "test/human-decision.test.ts"

start_control \
  control_check \
  "a human decision cannot skip the confirmation of the human" \
  "server/core/operations.ts" \
  's/if (input.confirmation !== "APPLY_HUMAN_DECISION")/if (false)/' \
  "test/human-decision.test.ts"

start_control \
  control_check \
  "a step the map does not offer cannot reach the program" \
  "server/core/human-decision.ts" \
  's/if (!action) {/if (false) {/' \
  "test/human-decision.test.ts"

start_control \
  control_check \
  "a refuted claim cannot be offered a waiver" \
  "shared/human-actions.ts" \
  's/if (state.state !== "refuted")/if (true)/' \
  "test/human-decision.test.ts"

start_control \
  control_check \
  "a settled claim must not ask for a decision" \
  "shared/human-actions.ts" \
  's/if (state.state !== "holds" && state.state !== "waived")/if (true)/' \
  "test/human-decision.test.ts"

start_control \
  control_check \
  "the command of a step cannot drift from the command of the program" \
  "shared/human-actions.ts" \
  's/"record", action.claimId, action.authority, "--by", by/"record", action.claimId, action.authority, "--who", by/' \
  "test/human-decision.test.ts"

# The acceptance of the result follows the verdict of the map. A panel that
# derives it from the states of the claims would report a green conclusion
# next to an unknown verdict, and nothing else in the checks would notice.
start_control \
  control_check \
  "the acceptance cannot be derived from the states of the claims" \
  "client/human-queue.ts" \
  's/snapshot.map.verdict === "green"/snapshot.map.states.length > 0 \&\& snapshot.map.states.every((state) => state.state === "holds")/' \
  "test/human-queue.test.ts"

# The catalogue is a contract between two languages. A translation that is
# missing, a key that only one language holds, or a placeholder that a
# translation drops are all defects that no type of the catalogue catches.
start_control \
  control_check \
  "a missing Russian translation cannot pass the catalogue" \
  "shared/locales/ru.ts" \
  '/    close: "Закрыть",/d' \
  "test/i18n.test.ts"

start_control \
  control_check \
  "a key only the Russian catalogue holds cannot pass" \
  "shared/locales/ru.ts" \
  '/    close: "Закрыть",/a\    invented_key: "Придумано",' \
  "test/i18n.test.ts"

start_control \
  control_check \
  "a translation cannot drop the placeholder of a text" \
  "shared/locales/ru.ts" \
  's|    refresh_failed: .*|    refresh_failed: "Не удалось обновить.",|' \
  "test/i18n.test.ts"

# The console names the permission that is closed. A closed button without a
# reason is a button nobody can read, so the panel names the switch that opens
# it, and the button of the settings opens the place where the switch lives.
start_control \
  control_check \
  "the panel cannot drop the card of the permissions" \
  "client/console.tsx" \
  's|<PermissionsCard theme={theme} compact={compact} runEnabled={runEnabled} decisionsEnabled={decisionsEnabled} onOpenSettings={openSettings} />||' \
  "test/permissions.test.ts"

start_control \
  control_check \
  "the card cannot stop naming the switch of the run" \
  "client/permissions.tsx" \
  's|switchLabel={t("settings.allow_run")}|switchLabel="Run checks"|' \
  "test/permissions.test.ts"

start_control \
  control_check \
  "the frame cannot stop saying that the run is closed" \
  "client/frame.tsx" \
  's|t("permissions.run_closed")|t("permissions.on")|' \
  "test/permissions.test.ts"

start_control \
  control_check \
  "the queue cannot stop saying that the decisions are closed" \
  "client/queue-view.tsx" \
  's|t("permissions.decisions_closed")|t("permissions.on")|g' \
  "test/permissions.test.ts"

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

if [ "$TOTAL" -eq 0 ]; then
  echo "negative-control: FAIL (no control covers '$FILTER')" >&2
  exit 1
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "negative-control: FAIL ($FAILURES of $TOTAL controls did not catch their break)" >&2
  exit 1
fi

echo "negative-control: PASS ($TOTAL controls)"
