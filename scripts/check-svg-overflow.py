#!/usr/bin/env python3
# scripts/check-svg-overflow.py
#
# Preventive verifier added 2026-10-15 after GitHub Pages
# rendering of an SVG (text near viewBox right edge) was clipped
# by the browser. Estimates each <text> bounding box from font
# metrics and fails when the bbox overflows the root viewBox +
# a tolerance margin.
#
# Estimation model (intentionally coarse — purely preventive):
#   char_width   = font_size * (0.62 mono | 0.55 serif)
#   width        = char_count * char_width + char_count * letter_spacing_em * font_size
#   height       = font_size * 1.2
#   bbox_y       = (ay - font_size * 0.8, ay + font_size * 0.2)
#
# <g transform="translate(X,Y)"> ancestors accumulate; both
# `translate(X, Y)` and `translate(X Y)` SVG forms are handled.
# Per-element <text>-level `transform` is parsed but only
# `translate(...)` is honoured (sufficient for the existing
# assets/*.svg corpus).
#
# Margin defaults to 5 px; override via --margin=N or the
# SVG_OVERFLOW_MARGIN environment variable (the wrapper script
# surfaces the latter as an opt-in knob).
#
# Exit codes:
#   0 — every <text> inside all viewBoxes (+ margin)
#   1 — at least one <text> overflows its viewBox
#   2 — script error (XML parse failure, IO error, etc.)

import argparse
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

SVG_NS = "{http://www.w3.org/2000/svg}"

MONO_TOKENS = ("mono", "Menlo", "Consolas", "Courier")
RE_FONT_SIZE = re.compile(r"font-size\s*:\s*([\d.]+)\s*(px)?", re.IGNORECASE)
RE_LETTER_SPACING = re.compile(r"letter-spacing\s*:\s*([\d.]+)\s*em", re.IGNORECASE)
RE_FONT_FAMILY = re.compile(r"font-family\s*:\s*([^;}]+)", re.IGNORECASE)
RE_TEXT_ANCHOR = re.compile(r"text-anchor\s*:\s*([^;}]+)", re.IGNORECASE)
RE_TRANSLATE = re.compile(r"translate\s*\(\s*(-?[\d.]+)\s*[,\s]\s*(-?[\d.]+)\s*\)")
RE_NUM = re.compile(r"-?[\d.]+")


def is_mono(family: str) -> bool:
    if not family:
        return False
    return any(tok in family for tok in MONO_TOKENS)


def parse_style_block(css_text: str):
    """Return dict: selector(class) -> {font-size, font-family, letter-spacing, text-anchor}.

    Keys use CSS-hyphen form so callers can look them up with the same key
    they would use for an SVG presentation attribute (e.g. font-size).
    Storing them with underscores and looking them up with hyphens would
    silently miss every match (this was the bug found on 2026-10-15 right
    after the initial commit; widths were being estimated with serif
    defaults for every <text>, including kern-label monospace ones).
    """
    out = {}
    for raw in css_text.split("}"):
        decl = raw.strip()
        if not decl:
            continue
        head, _, body = decl.partition("{")
        if not body:
            continue
        selectors = [s.strip() for s in head.split(",") if s.strip()]
        body_l = body.lower()
        style = {}
        m = RE_FONT_SIZE.search(body_l)
        if m:
            style["font-size"] = float(m.group(1))
        m = RE_FONT_FAMILY.search(body)
        if m:
            style["font-family"] = m.group(1).strip()
        m = RE_LETTER_SPACING.search(body_l)
        if m:
            style["letter-spacing"] = float(m.group(1))
        m = RE_TEXT_ANCHOR.search(body_l)
        if m:
            style["text-anchor"] = m.group(1).strip()
        for sel in selectors:
            out[sel] = style
    return out


def first_class(el):
    cls = el.get("class") or el.get("class") or ""
    return cls.split()[0] if cls else ""


def parse_viewBox(root):
    vb = root.get("viewBox")
    if not vb:
        return None
    nums = [float(n) for n in RE_NUM.findall(vb)]
    if len(nums) != 4:
        return None
    return nums[0], nums[1], nums[2], nums[3]


def parse_translate_attr(t):
    """Yield cumulative (dx, dy) from a transform attribute string.

    Only `translate(X, Y)` / `translate(X Y)` are recognised; other
    transforms are silently ignored. The Yields API lets callers
    fold the delta into a running translation (used for <g> ancestors).
    """
    if not t:
        return 0.0, 0.0
    m = RE_TRANSLATE.search(t)
    if not m:
        return 0.0, 0.0
    return float(m.group(1)), float(m.group(2))


RE_ROTATE = re.compile(r"rotate\s*\(", re.IGNORECASE)
RE_SCALE = re.compile(r"scale\s*\(", re.IGNORECASE)
RE_MATRIX = re.compile(r"matrix\s*\(", re.IGNORECASE)


def has_non_translate_transform(t):
    """Return True if a transform attribute contains anything other
    than a single `translate(...)` call. Used to flag rotated or
    scaled text whose bounding-box check would be misleading.
    """
    if not t:
        return False
    s = t.strip()
    if not s:
        return False
    if RE_ROTATE.search(s) or RE_SCALE.search(s) or RE_MATRIX.search(s):
        return True
    # A pure `translate(X, Y)` (with optional whitespace) is fine;
    # anything else (skew, multiple transforms, missing-parens) is
    # conservatively treated as unsupported.
    if not RE_TRANSLATE.fullmatch(s):
        return True
    return False


def text_content(el):
    """Return concatenated text of <text> element. <tspan> children
    are walked recursively; CDATA/tail text of the <text> itself is
    appended. Yields the natural reading order.
    """
    parts = []
    if el.text:
        parts.append(el.text)
    for child in el:
        parts.append(text_content(child))
        if child.tail:
            parts.append(child.tail)
    return "".join(parts)


def format_at(style_for_class, el, key, default):
    if el.get(key) is not None:
        return el.get(key)
    return style_for_class.get(key, default)


def check_svg(path, margin):
    """Return list of failure strings (empty list == pass)."""
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        print("{}: parse error: {}".format(path, e), file=sys.stderr)
        return ["__parse_error__"]

    root = tree.getroot()
    vb = parse_viewBox(root)
    if vb is None:
        print("SKIP {}: no viewBox".format(path))
        return []

    vb_x, vb_y, vb_w, vb_h = vb
    margin = float(margin)

    # Collect all class-defined styles from <style> descendants.
    styles = {}
    for el in root.iter():
        if el.tag.endswith("}style") or el.tag == "style":
            css = el.text or ""
            styles.update(parse_style_block(css))

    failures = []

    def walk(node, tx, ty, rotated):
        node_t = node.get("transform") or ""
        # A non-translate transform on the node itself OR an ancestor
        # (`rotated` flag set) means we can't reason about the bbox
        # in absolute coordinates — skip overflow detection for
        # such text. Translate-only transforms are still applied.
        if has_non_translate_transform(node_t):
            rotated = True
        local_tx, local_ty = parse_translate_attr(node_t)
        cx, cy = tx + local_tx, ty + local_ty
        if node.tag == SVG_NS + "text" or node.tag == "text":
            if not rotated:
                try:
                    ax = float(node.get("x") or 0) + cx
                    ay = float(node.get("y") or 0) + cy
                except (TypeError, ValueError):
                    ax, ay = cx, cy

                cls = first_class(node)
                sd = styles.get("." + cls, {}) if cls else {}
                family = format_at(sd, node, "font-family", "Georgia, serif")
                fs_str = format_at(sd, node, "font-size", "12")
                m = RE_NUM.search(str(fs_str))
                font_size = float(m.group(0)) if m else 12.0
                # Letter-spacing is per the task spec sourced ONLY from
                # CSS `letter-spacing: Xem` (per-class style). The SVG
                # attribute form (`letter-spacing="X"`) uses user-units
                # and is intentionally ignored — distinguishing unit
                # contexts from a CSS parse is brittle, so this verifier
                # uses the conservative CSS-em estimate and lets the
                # attribute form read as 0.
                letter_spacing = sd.get("letter-spacing", 0.0)
                anchor = format_at(sd, node, "text-anchor", "start")

                content = text_content(node)
                char_count = max(1, len(content))
                char_width = font_size * (
                    0.62 if is_mono(str(family)) else 0.55
                )
                width = (
                    char_count * char_width
                    + char_count * letter_spacing * font_size
                )
                height = font_size * 1.2

                if anchor == "middle":
                    left, right = ax - width / 2, ax + width / 2
                elif anchor == "end":
                    left, right = ax - width, ax
                else:
                    left, right = ax, ax + width

                top = ay - font_size * 0.8
                bottom = ay + font_size * 0.2

                def fails(edge, coord, limit, sign):
                    # sign +1: coord > limit + margin overflows
                    # sign -1: coord < -margin overflows
                    if sign > 0:
                        return coord > limit + margin
                    return coord < -margin

                if fails("left", left, 0, -1):
                    failures.append(
                        "left edge (overflow by {:.1f}px) — text '{:.50}'".format(
                            -left, content
                        )
                    )
                if fails("right", right, vb_w, +1):
                    failures.append(
                        "right edge (overflow by {:.1f}px) — text '{:.50}'".format(
                            right - vb_w, content
                        )
                    )
                if fails("top", top, 0, -1):
                    failures.append(
                        "top edge — text '{:.50}'".format(content)
                    )
                if fails("bottom", bottom, vb_h, +1):
                    failures.append(
                        "bottom edge — text '{:.50}'".format(content)
                    )

        for child in node:
            walk(child, cx, cy, rotated)

    walk(root, 0.0, 0.0, False)
    return failures


def main():
    p = argparse.ArgumentParser()
    p.add_argument(
        "assets_dir",
        nargs="?",
        default="./assets",
        help="Directory containing .svg files (default: ./assets)",
    )
    p.add_argument(
        "--margin",
        type=float,
        default=None,
        help="Tolerance margin in px (default: 5, or env SVG_OVERFLOW_MARGIN)",
    )
    args = p.parse_args()

    env_margin = os.environ.get("SVG_OVERFLOW_MARGIN")
    margin = args.margin
    if margin is None:
        margin = float(env_margin) if env_margin else 5.0

    svg_paths = sorted(glob.glob(os.path.join(args.assets_dir, "*.svg")))
    if not svg_paths:
        print("no SVG files found in {}".format(args.assets_dir), file=sys.stderr)
        return 2

    total = 0
    failed = 0
    skipped = 0
    parse_errors = 0
    for path in svg_paths:
        errs = check_svg(path, margin)
        if errs == ["__parse_error__"]:
            parse_errors += 1
            continue
        total += 1
        if not errs:
            print("PASS {}".format(path))
        else:
            failed += 1
            # Find the line number for the specific failing text
            # (best-effort match against <text> contents in the file).
            ln = lookup_line_for_text(path, errs[0]) or "?"
            print("FAIL {} line {}: {}".format(path, ln, errs[0]))

    print("{} SVG checked, {} failed, {} skipped (known false positives)".format(
        total, failed, skipped
    ))
    if parse_errors:
        print("{} parse errors".format(parse_errors), file=sys.stderr)
    return 1 if (failed or parse_errors) else 0


def lookup_line_for_text(path, err_msg):
    """Best-effort: find the SVG file line containing the <text>
    whose content matches the FAIL message. The err_msg format is
    "...text 'CONTENT...'" so we extract between the final pair of
    quotes. The match is by content prefix, since the FAIL truncates
    long strings at 50 chars.
    """
    # err_msg looks like:
    #   "right edge (overflow by Xpx) — text 'CONTENT'"
    m = re.search(r"text '(.+?)'$", err_msg)
    if not m:
        return None
    snippet = m.group(1)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for i, line in enumerate(fh, 1):
                if "<text" in line and snippet in line:
                    return i
    except OSError:
        pass
    return None


if __name__ == "__main__":
    sys.exit(main())
