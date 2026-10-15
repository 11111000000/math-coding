#!/usr/bin/env python3
"""confluence2madr.py — turn a Confluence export into MADR markdown.

Reads a Confluence export JSON file (simplified shape or
Confluence Cloud API response) and writes one MADR-shaped
`.md` per page. The output is a draft: the reviewer fills in
the TBD sections before passing each `.md` to
`mathc import-adr`.

Supported input shapes:

  1. Simplified (one file per space):
     {
       "id": "<space-id>",
       "name": "<space-name>",
       "pages": [
         {"id": "...", "title": "...",
          "version": {"when": "<iso8601>"},
          "body": {"storage": {"value": "<html>"}}}
       ]
     }

  2. Confluence Cloud API response (same fields but `body.storage.value`
     is HTML, `version.when` is the publication timestamp).

Usage:
  scripts/confluence2madr.py <confluence-export.json> <out-dir>

Args:
  <confluence-export.json>  the export file
  <out-dir>                destination directory (created if missing)

Exit codes:
  0  success
  1  read/parse error
  2  bad arguments

The script is pure stdlib: json, re, html.parser, pathlib.
"""

from __future__ import annotations

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from typing import Optional

DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})")


def err(msg: str) -> None:
    print(f"confluence2madr: {msg}", file=sys.stderr)


def kebab(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-") or "confluence"


def first_line(text: str) -> str:
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line[:120]
    return "(empty)"


def to_date(s: Optional[str]) -> str:
    if not s:
        return "1970-01-01"
    m = DATE_RE.match(s)
    if m:
        return m.group(1)
    digits = re.sub(r"[^\d]", "", s)
    if len(digits) >= 8:
        return f"{digits[0:4]}-{digits[4:6]}-{digits[6:8]}"
    return "1970-01-01"


class HTMLStripper(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._buf: list[str] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs: list) -> None:
        if tag in ("br", "br/", "hr"):
            self._buf.append("\n")
        elif tag in ("p", "div", "h1", "h2", "h3", "h4", "h5", "li", "tr"):
            self._buf.append("\n")
        elif tag in ("script", "style"):
            self._skip += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in ("p", "div", "h1", "h2", "h3", "h4", "h5", "li", "tr"):
            self._buf.append("\n")
        elif tag in ("script", "style"):
            self._skip = max(0, self._skip - 1)

    def handle_data(self, data: str) -> None:
        if self._skip == 0:
            self._buf.append(data)

    def text(self) -> str:
        raw = "".join(self._buf)
        raw = re.sub(r"[ \t]+\n", "\n", raw)
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        return raw.strip()


def strip_html(html: str) -> str:
    p = HTMLStripper()
    p.feed(html or "")
    p.close()
    return p.text()


def body_storage(page: dict) -> str:
    body = page.get("body")
    if not body:
        return ""
    storage = body.get("storage") if isinstance(body, dict) else None
    if not storage:
        return ""
    return storage.get("value", "")


def page_date(page: dict) -> str:
    version = page.get("version") or {}
    when = version.get("when") or version.get("by")
    if isinstance(when, str):
        return to_date(when)
    if "created" in page:
        return to_date(page["created"])
    return "1970-01-01"


def page_id(page: dict, idx: int) -> str:
    raw = page.get("id") or f"page-{idx}"
    return kebab(str(raw))


def render_madr(page: dict, idx: int) -> tuple[str, str]:
    title = (page.get("title") or "").strip() or f"page-{idx}"
    date = page_date(page)
    text = strip_html(body_storage(page))
    slug = kebab(title)
    fname = f"{idx:04d}-{slug}.md"
    body = (
        "---\n"
        "status: proposed\n"
        f"date: {date}\n"
        f"source: confluence://{page.get('id', slug)}\n"
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
        "TBD (reviewer to extract from page body)\n"
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


def extract_pages(payload: dict) -> list[dict]:
    if isinstance(payload, list):
        return [p for p in payload if isinstance(p, dict)]
    if "pages" in payload and isinstance(payload["pages"], list):
        return [p for p in payload["pages"] if isinstance(p, dict)]
    if "results" in payload and isinstance(payload["results"], list):
        return [p for p in payload["results"] if isinstance(p, dict)]
    return []


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        err(
            f"usage: {argv[0] if argv else 'confluence2madr.py'} "
            "<confluence-export.json> <out-dir>"
        )
        return 2
    in_path = Path(argv[1])
    out_dir = Path(argv[2])
    if not in_path.is_file():
        err(f"not a file: {in_path}")
        return 2
    try:
        payload = json.loads(in_path.read_text(encoding="utf-8"))
        pages = extract_pages(payload)
        out_dir.mkdir(parents=True, exist_ok=True)
        counter = 0
        for idx, page in enumerate(pages, start=1):
            counter += 1
            fname, body = render_madr(page, counter)
            (out_dir / fname).write_text(body, encoding="utf-8")
        print(f"wrote {counter} MADR files to {out_dir}")
        return 0
    except (json.JSONDecodeError, OSError) as e:
        err(f"read error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
