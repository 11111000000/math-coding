#!/usr/bin/env python3
import datetime
import json
import math
import statistics
import sys

ARMS = ("baseline", "checklist", "protocol")
VERDICTS = ("green", "red", "unknown", "vacant", "not-measured")
OUTCOMES = ("accepted", "rejected", "infrastructure", "abandoned", "pending", "excluded")
FRICTION = (
    "implementation-defect",
    "weak-claim",
    "weak-verifier",
    "bad-control",
    "source-changed",
    "environment-mismatch",
    "infrastructure",
    "uncovered",
    "handoff",
    "claim-weakened-after-fail",
    "false-green",
    "onboarding",
)
EXCLUSIONS = ("duplicate", "not-a-task", "owner-cancelled", "setup-unavailable")
FIELDS = {
    "schema_version", "comparison_id", "task_id", "run_id", "project", "arm",
    "task_kind", "model", "mathc_build", "base_revision", "started_at", "finished_at",
    "agent_seconds", "human_seconds", "agent_tokens", "mathc_calls",
    "repeated_investigations", "control_setup_failures", "environment_mismatches",
    "initial_verdict", "initial_uncovered", "final_verdict", "final_uncovered",
    "final_outdated", "outcome", "accepted_by", "handoff_seconds",
    "observation_complete", "post_acceptance_defects", "reopened", "false_green",
    "friction_classes", "exclusion_reason",
}
TEXT_FIELDS = ("comparison_id", "task_id", "run_id", "project", "task_kind", "model", "mathc_build", "base_revision")
COUNT_FIELDS = (
    "agent_tokens", "mathc_calls", "repeated_investigations", "control_setup_failures",
    "environment_mismatches", "initial_uncovered", "final_uncovered", "final_outdated",
)
TIME_FIELDS = ("agent_seconds", "human_seconds")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value, f"duplicate JSON field: {key}")
        value[key] = item
    return value


def text(record, field):
    value = record[field]
    require(type(value) is str and value.strip() != "", f"{field} must be a nonempty string")
    return value


def count(record, field):
    value = record[field]
    require(type(value) is int and value >= 0, f"{field} must be a nonnegative integer")
    return value


def seconds(value, field):
    require(value is None or (type(value) in (int, float) and math.isfinite(value) and value >= 0),
            f"{field} must be null or a nonnegative finite number")
    return value


def timestamp(value, field):
    require(type(value) is str and value != "", f"{field} must be an ISO-8601 timestamp")
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{field} is not an ISO-8601 timestamp") from error
    require(parsed.tzinfo is not None, f"{field} must include a timezone")
    return parsed


def validate_record(record, location):
    require(type(record) is dict, f"{location}: expected a JSON object")
    missing = FIELDS - record.keys()
    extra = record.keys() - FIELDS
    require(not missing, f"{location}: missing fields: {sorted(missing)}")
    require(not extra, f"{location}: unknown fields: {sorted(extra)}")
    require(record["schema_version"] == 1 and type(record["schema_version"]) is int,
            f"{location}: unsupported schema_version")
    for field in TEXT_FIELDS:
        text(record, field)
    require(record["arm"] in ARMS, f"{location}: unknown arm")
    for field in COUNT_FIELDS:
        count(record, field)
    for field in TIME_FIELDS:
        seconds(record[field], field)
    started = timestamp(record["started_at"], "started_at")
    finished = timestamp(record["finished_at"], "finished_at")
    require(finished >= started, f"{location}: finished_at precedes started_at")
    require(record["initial_verdict"] in VERDICTS and record["final_verdict"] in VERDICTS,
            f"{location}: unknown verdict")
    outcome = record["outcome"]
    require(outcome in OUTCOMES, f"{location}: unknown outcome")
    accepted_by = record["accepted_by"]
    if outcome == "accepted":
        require(type(accepted_by) is str and accepted_by.strip() != "",
                f"{location}: accepted outcome needs an independent accepted_by")
    else:
        require(accepted_by is None, f"{location}: accepted_by is allowed only for accepted outcome")
    seconds(record["handoff_seconds"], "handoff_seconds")
    require(type(record["observation_complete"]) is bool, f"{location}: observation_complete must be boolean")
    defects = record["post_acceptance_defects"]
    reopened = record["reopened"]
    require(defects is None or (type(defects) is int and defects >= 0),
            f"{location}: post_acceptance_defects must be null or a nonnegative integer")
    require(reopened is None or type(reopened) is bool,
            f"{location}: reopened must be null or boolean")
    if record["observation_complete"]:
        require(outcome == "accepted", f"{location}: post-acceptance observation requires accepted outcome")
        require(defects is not None and reopened is not None,
                f"{location}: completed observation needs defects and reopened")
    require(type(record["false_green"]) is bool, f"{location}: false_green must be boolean")
    friction = record["friction_classes"]
    require(type(friction) is list and all(type(item) is str and item in FRICTION for item in friction),
            f"{location}: unknown friction class")
    require(len(friction) == len(set(friction)), f"{location}: duplicate friction class")
    reason = record["exclusion_reason"]
    if outcome == "excluded":
        require(reason in EXCLUSIONS, f"{location}: excluded outcome needs a declared exclusion_reason")
    else:
        require(reason is None, f"{location}: exclusion_reason is allowed only for excluded outcome")


def load(path):
    records = []
    with open(path, encoding="utf-8") as source:
        for number, line in enumerate(source, 1):
            if line.strip() == "":
                continue
            location = f"{path}:{number}"
            try:
                record = json.loads(line, object_pairs_hook=unique_object)
            except json.JSONDecodeError as error:
                raise ValueError(f"{location}: invalid JSON") from error
            validate_record(record, location)
            records.append(record)
    run_ids = set()
    task_arms = set()
    comparisons = {}
    tasks = {}
    for record in records:
        require(record["run_id"] not in run_ids, f"duplicate run_id: {record['run_id']}")
        run_ids.add(record["run_id"])
        comparison_id = record["comparison_id"]
        task_key = comparison_id, record["task_id"]
        arm_key = task_key + (record["arm"],)
        require(arm_key not in task_arms, f"duplicate arm for task: {arm_key}")
        task_arms.add(arm_key)
        identity = comparisons.setdefault(comparison_id, (record["model"], record["mathc_build"]))
        require(identity == (record["model"], record["mathc_build"]),
                f"comparison {comparison_id} mixes model or mathc builds")
        task_identity = tasks.setdefault(task_key, (record["project"], record["base_revision"], record["task_kind"]))
        require(task_identity == (record["project"], record["base_revision"], record["task_kind"]),
                f"task {task_key} mixes project, revision or kind")
    return records


def summarize(records):
    result = {"schema_version": 1, "runs": len(records), "arms": {}}
    for arm in ARMS:
        selected = [record for record in records if record["arm"] == arm]
        outcomes = {outcome: 0 for outcome in OUTCOMES}
        for record in selected:
            outcomes[record["outcome"]] += 1
        handoffs = [record["handoff_seconds"] for record in selected if record["handoff_seconds"] is not None]
        result["arms"][arm] = {
            "runs": len(selected),
            "outcomes": outcomes,
            "completed_observations": sum(record["observation_complete"] for record in selected),
            "reopened": sum(record["reopened"] is True for record in selected),
            "post_acceptance_defects": sum(record["post_acceptance_defects"] or 0 for record in selected),
            "false_green": sum(record["false_green"] for record in selected),
            "handoff_seconds_median": statistics.median(handoffs) if handoffs else None,
            "agent_seconds_total": sum(record["agent_seconds"] for record in selected),
            "human_seconds_total": sum(record["human_seconds"] for record in selected),
            "agent_tokens_total": sum(record["agent_tokens"] for record in selected),
            "mathc_calls_total": sum(record["mathc_calls"] for record in selected),
            "repeated_investigations_total": sum(record["repeated_investigations"] for record in selected),
        }
    return result


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("validate", "summary"):
        print("usage: task-ledger.py validate|summary PATH", file=sys.stderr)
        return 2
    try:
        records = load(sys.argv[2])
        if sys.argv[1] == "validate":
            print(f"valid: {len(records)} run(s)")
        else:
            print(json.dumps(summarize(records), ensure_ascii=False, indent=2, allow_nan=False))
        return 0
    except (OSError, ValueError) as error:
        print(f"task-ledger: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
