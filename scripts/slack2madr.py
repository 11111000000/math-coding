#!/usr/bin/env python3
"""slack2madr.py — extract decision-like Slack messages to MADR markdown.

A heuristic detector turns a Slack export zip into a folder of
MADR-shaped `.md` files, one per detected decision-like
message. A message is "decision-like" if it is a thread starter
with at least one reply, OR if it has at least two reactions.
The output is a draft: the reviewer fills in the TBD sections
before passing each `.md` to `mathc import-adr`.

Usage:
  scripts/slack2madr.py <slack-export.zip> <out-dir>

Args:
  <slack-export.zip>  a Slack workspace export zip
  <out-dir>           destination directory (created if missing)

Exit codes:
  0  success
  1  zip read error
  2  bad arguments

The script is pure stdlib: zipfile, json, re, pathlib.
"""

from __future__ import annotations

import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

THREAD_STARTER_MIN_REPLIES = 1
REACTION_MIN_COUNT = 2
DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})")


def err(msg: str) -> None:
    print(f"slack2madr: {msg}", file=sys.stderr)


def kebab(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-") or "slack"


def ts_to_date(ts: str) -> str:
    if not ts:
        return "1970-01-01"
    try:
        seconds = float(ts.split(".", 1)[0])
    except ValueError:
        m = DATE_RE.match(ts)
        if m:
            return m.group(1)
        return "1970-01-01"
    try:
        return datetime.fromtimestamp(seconds, tz=timezone.utc).strftime("%Y-%m-%d")
    except (OverflowError, OSError, ValueError):
        return "1970-01-01"


def first_line(text: str) -> str:
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line[:120]
    return "(empty)"


def iter_channel_files(zf: zipfile.ZipFile) -> Iterable[tuple[str, list[dict]]]:
    for name in zf.namelist():
        if not name.endswith(".json"):
            continue
        if name.endswith("users.json"):
            continue
        parts = name.split("/")
        if len(parts) < 2:
            continue
        channel = kebab(parts[-2])
        try:
            data = json.loads(zf.read(name).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        msgs: list[dict] = []
        if isinstance(data, list):
            for entry in data:
                if isinstance(entry, dict) and entry.get("type") == "message":
                    msgs.append(entry)
        elif isinstance(data, dict) and data.get("type") == "message":
            msgs.append(data)
        if msgs:
            yield channel, msgs


def reaction_count(msg: dict) -> int:
    return sum(int(r.get("count", 0)) for r in (msg.get("reactions") or []))


def thread_reply_count(msg: dict, all_msgs: list[dict]) -> int:
    ts = msg.get("ts")
    if not ts:
        return 0
    return sum(
        1 for m in all_msgs
        if m.get("thread_ts") == ts and m.get("ts") != ts
    )


def is_decision_like(msg: dict, all_msgs: list[dict]) -> bool:
    if reaction_count(msg) >= REACTION_MIN_COUNT:
        return True
    if thread_reply_count(msg, all_msgs) >= THREAD_STARTER_MIN_REPLIES:
        return True
    return False


def render_madr(msg: dict, channel: str, counter: int) -> tuple[str, str]:
    text = (msg.get("text") or "").strip()
    user = msg.get("user", "unknown")
    ts = msg.get("ts", "")
    date = ts_to_date(ts)
    title = first_line(text)
    fname = f"{counter:04d}-{channel}-{date}.md"
    body = (
        "---\n"
        "status: proposed\n"
        f"deciders: {user}\n"
        f"date: {date}\n"
        f"source: slack://{channel}/{ts}\n"
        "---\n"
        "\n"
        f"# {title}\n"
        "\n"
        "## Context\n"
        "\n"
        f"{text}\n"
        "\n"
        "## Decision\n"
        "\n"
        "TBD (reviewer to extract from thread)\n"
        "\n"
        "## Consequences\n"
        "\n"
        "TBD\n"
        "\n"
        "## Counterexample\n"
        "\n"
        "TBD\n"
    )
    return fname, body


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        err(
            f"usage: {argv[0] if argv else 'slack2madr.py'} "
            "<slack-export.zip> <out-dir>"
        )
        return 2
    zip_path = Path(argv[1])
    out_dir = Path(argv[2])
    if not zip_path.is_file():
        err(f"not a file: {zip_path}")
        return 2
    try:
        out_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path) as zf:
            counter = 0
            for channel, msgs in iter_channel_files(zf):
                for msg in msgs:
                    if is_decision_like(msg, msgs):
                        counter += 1
                        fname, body = render_madr(msg, channel, counter)
                        (out_dir / fname).write_text(body, encoding="utf-8")
        print(f"wrote {counter} MADR files to {out_dir}")
        return 0
    except (zipfile.BadZipFile, OSError) as e:
        err(f"zip read error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
