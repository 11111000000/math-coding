#!/usr/bin/env python3
"""Measure the rendered site in a phone-sized viewport.

The probe loads a page of the built site inside a narrow frame, waits for
the webfonts, and reports what the browser actually laid out: whether the
page scrolls sideways, whether a navigation item is cut off, whether the
call-to-action still has its bottom frame, and which typefaces were used.

It can also force the colour scheme of the browser to dark and measure the
contrast of the body text and of the state pills against the paper they
stand on: a theme that cannot be read is not a theme.

It never asserts by itself: it prints the measurements as JSON and lets
the caller decide. Exit 0 when every measurement was taken, 3 when the
browser could not be run or did not honour the colour scheme, which is not
evidence of success.

Usage:
    ui-probe.py --dist DIR --chrome PATH [--width PX] [--page index.html]
                [--scheme dark] [--min-contrast 4.5]
"""

import argparse
import functools
import http.server
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading

PROBE = r"""
(async () => {
  const log = (m) => { document.getElementById('log').textContent += m + "\n"; };
  const frame = document.getElementById('f');
  const race = (p, ms) => Promise.race([p, new Promise((r) => setTimeout(r, ms))]);
  const parseColor = (value) => {
    const match = String(value).match(/rgba?\(([^)]+)\)/);
    if (!match) return null;
    const parts = match[1].split(/[,\s/]+/).filter((p) => p.length > 0).map(Number);
    if (parts.length < 3 || parts.some((p) => Number.isNaN(p))) return null;
    return { r: parts[0], g: parts[1], b: parts[2], a: parts.length > 3 ? parts[3] : 1 };
  };
  const channel = (value) => {
    const s = value / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  const luminance = (color) =>
    0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
  const ratio = (top, bottom) => {
    const a = luminance(top), b = luminance(bottom);
    const hi = Math.max(a, b), lo = Math.min(a, b);
    return (hi + 0.05) / (lo + 0.05);
  };
  const over = (top, bottom) => ({
    r: top.r * top.a + bottom.r * (1 - top.a),
    g: top.g * top.a + bottom.g * (1 - top.a),
    b: top.b * top.a + bottom.b * (1 - top.a),
    a: 1,
  });
  const measure = async () => {
    const doc = frame.contentDocument;
    const win = frame.contentWindow;
    await race(doc.fonts.ready, 3000);
    for (const family of ['JetBrains Mono', 'Source Serif 4']) {
      try { await race(doc.fonts.load('16px "' + family + '"'), 3000); }
      catch (e) { /* a missing file is reported by the checks below */ }
    }
    const out = {};
    const root = doc.documentElement;
    out.innerWidth = win.innerWidth;
    out.scrollWidth = root.scrollWidth;
    out.scheme = win.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark' : 'light';
    const clippedBy = (el) => {
      const r = el.getBoundingClientRect();
      let node = el.parentElement;
      while (node && node !== doc.body) {
        const style = win.getComputedStyle(node);
        if (style.overflowX !== 'visible' || style.overflowY !== 'visible') {
          const pr = node.getBoundingClientRect();
          if (r.right > pr.right + 0.5 || r.left < pr.left - 0.5 ||
              r.bottom > pr.bottom + 0.5 || r.top < pr.top - 0.5) {
            const name = node.className && node.className.toString
              ? node.className.toString().slice(0, 30) : '';
            return node.tagName.toLowerCase() + (name ? '.' + name : '');
          }
        }
        node = node.parentElement;
      }
      return '';
    };
    out.links = Array.from(doc.querySelectorAll('nav.site-nav a')).map((a) => {
      const r = a.getBoundingClientRect();
      const cs = win.getComputedStyle(a);
      return {
        text: a.textContent.trim(),
        left: Math.round(r.left * 10) / 10,
        right: Math.round(r.right * 10) / 10,
        top: Math.round(r.top * 10) / 10,
        bottom: Math.round(r.bottom * 10) / 10,
        active: a.classList.contains('active'),
        clippedBy: clippedBy(a),
        borderBottomWidth: cs.borderBottomWidth,
        borderBottomColor: cs.borderBottomColor,
        font: cs.fontFamily.split(',')[0].replace(/"/g, ''),
      };
    });
    const cta = doc.querySelector('.cta-secondary');
    if (cta) {
      const cs = win.getComputedStyle(cta);
      out.cta = {
        borderTopWidth: cs.borderTopWidth,
        borderRightWidth: cs.borderRightWidth,
        borderBottomWidth: cs.borderBottomWidth,
        borderLeftWidth: cs.borderLeftWidth,
        borderBottomColor: cs.borderBottomColor,
      };
    }
    out.bodyFont = win.getComputedStyle(doc.body).fontFamily.split(',')[0].replace(/"/g, '');
    out.serifLoaded = doc.fonts.check('16px "Source Serif 4"');
    out.monoLoaded = doc.fonts.check('16px "JetBrains Mono"');
    const overflowing = [];
    const inScroller = (el) => {
      let node = el;
      while (node && node.nodeType === 1) {
        const style = win.getComputedStyle(node);
        if (style.overflowX === 'auto' || style.overflowX === 'scroll' ||
            style.overflowX === 'hidden') return true;
        node = node.parentElement;
      }
      return false;
    };
    doc.querySelectorAll('body *').forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return;
      if (r.right > win.innerWidth + 1 || r.left < -1) {
        if (inScroller(el)) return;
        overflowing.push({
          tag: el.tagName,
          class: (el.className && el.className.toString ? el.className.toString() : '').slice(0, 40),
          left: Math.round(r.left),
          right: Math.round(r.right),
        });
      }
    });
    out.overflowing = overflowing.slice(0, 10);
    /* --- the contrast of the theme --- */
    const backdrop = (el) => {
      const layers = [];
      let node = el;
      while (node) {
        const color = parseColor(win.getComputedStyle(node).backgroundColor);
        if (color && color.a > 0) {
          layers.push(color);
          if (color.a >= 1) break;
        }
        node = node.parentElement;
      }
      let base = { r: 255, g: 255, b: 255, a: 1 };
      for (let i = layers.length - 1; i >= 0; i--) base = over(layers[i], base);
      return base;
    };
    const measured = (el) => {
      if (!el) return null;
      const style = win.getComputedStyle(el);
      const ink = parseColor(style.color);
      const paper = backdrop(el);
      if (!ink || !paper) return null;
      return {
        color: style.color,
        background: 'rgb(' + Math.round(paper.r) + ', ' + Math.round(paper.g) +
                    ', ' + Math.round(paper.b) + ')',
        ratio: Math.round(ratio(ink, paper) * 100) / 100,
        size: parseFloat(style.fontSize) || 0,
      };
    };
    const readings = [];
    doc.querySelectorAll('p, li, h1, h2, h3, h4, dt, dd, td, th, code, a, span')
      .forEach((el) => {
        if (!el.textContent.trim().length) return;
        const box = el.getBoundingClientRect();
        if (box.width === 0 || box.height === 0) return;
        const reading = measured(el);
        if (!reading) return;
        reading.tag = el.tagName.toLowerCase();
        reading.text = el.textContent.trim().slice(0, 30);
        readings.push(reading);
      });
    const bySize = readings.slice().sort((a, b) => b.size - a.size);
    const byRatio = readings.slice().sort((a, b) => a.ratio - b.ratio);
    out.contrast = {
      body: bySize.length ? bySize[0] : null,
      heading: measured(doc.querySelector('h1')),
      weakest: byRatio.length ? byRatio[0] : null,
      pills: Array.from(doc.querySelectorAll('.v-pill')).map((pill) => {
        const reading = measured(pill);
        reading.text = pill.textContent.trim();
        reading.state = (pill.className.toString().split(' ')
          .filter((c) => c.startsWith('v-'))[0] || 'v-pill');
        return reading;
      }),
    };
    log('PROBE:' + JSON.stringify(out));
  };
  frame.addEventListener('load', () => {
    measure().catch((e) => log('PROBE-ERROR:' + String(e)));
  });
  frame.src = FRAME_SRC;
})();
"""

WRAPPER = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>probe</title></head>
<body>
<iframe id="f" style="width:%(width)dpx;height:%(height)dpx;border:0"></iframe>
<pre id="log"></pre>
<script>%(probe)s</script>
</body></html>
"""


CHROME_CANDIDATES = (
    "chromium", "chromium-browser", "google-chrome", "google-chrome-stable", "chrome",
    "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium", "/usr/bin/chromium-browser",
    "/snap/bin/chromium", "/opt/google/chrome/chrome",
)


def find_chrome(explicit):
    candidates = []
    if explicit:
        candidates.append(explicit)
    if os.environ.get("CHROME"):
        candidates.append(os.environ["CHROME"])
    candidates.extend(CHROME_CANDIDATES)
    for name in candidates:
        if os.path.isabs(name):
            if os.path.exists(name) and os.access(name, os.X_OK):
                return name
            continue
        found = shutil.which(name)
        if found:
            return found
    return None


def problems_of(data, page, min_contrast, min_pill_contrast):
    """The defects that a phone screen would show on this page."""
    problems = []
    width = data["innerWidth"]
    if data["scrollWidth"] > width + 1:
        problems.append(
            "%s: the page is %d px wide on a %d px screen (it scrolls sideways)"
            % (page, data["scrollWidth"], width))
    for item in data.get("overflowing", []):
        problems.append(
            "%s: <%s class=%s> reaches %d px on a %d px screen"
            % (page, item["tag"].lower(), item["class"], item["right"], width))
    for link in data.get("links", []):
        if link["left"] < -0.5 or link["right"] > width + 0.5:
            problems.append(
                "%s: the navigation item %r is cut off (%s .. %s on a %d px screen)"
                % (page, link["text"], link["left"], link["right"], width))
        if link.get("clippedBy"):
            problems.append(
                "%s: the navigation item %r is cut off by %s"
                % (page, link["text"], link["clippedBy"]))
        if link["active"]:
            if float(link["borderBottomWidth"].replace("px", "") or 0) < 1:
                problems.append("%s: the active item %r lost its bottom frame"
                                % (page, link["text"]))
            if "rgba(0, 0, 0, 0)" in link["borderBottomColor"]:
                problems.append("%s: the active item %r has a transparent bottom frame"
                                % (page, link["text"]))
    cta = data.get("cta")
    if cta and float(cta["borderBottomWidth"].replace("px", "") or 0) < 1:
        problems.append("%s: the call-to-action lost its bottom frame" % page)
    if data.get("bodyFont") != "Source Serif 4":
        problems.append("%s: the text is drawn by %r, not by the loaded serif"
                        % (page, data.get("bodyFont")))
    if not data.get("serifLoaded") or not data.get("monoLoaded"):
        problems.append("%s: a webfont did not load" % page)
    for link in data.get("links", []):
        if link["font"] != "JetBrains Mono":
            problems.append("%s: the navigation item %r is drawn by %r"
                            % (page, link["text"], link["font"]))
            break
    contrast = data.get("contrast") or {}
    body = contrast.get("body")
    if not body:
        problems.append("%s: the contrast of the text was not measured" % page)
    else:
        if body["ratio"] < min_contrast:
            problems.append(
                "%s: the text is %s on %s (%.2f:1, the minimum is %.1f:1)"
                % (page, body["color"], body["background"], body["ratio"], min_contrast))
    heading = contrast.get("heading")
    if heading and heading["ratio"] < min_contrast:
        problems.append(
            "%s: the heading is %s on %s (%.2f:1, the minimum is %.1f:1)"
            % (page, heading["color"], heading["background"], heading["ratio"],
               min_contrast))
    for pill in contrast.get("pills", []):
        if pill["ratio"] < min_pill_contrast:
            problems.append(
                "%s: the pill %s is %s on %s (%.2f:1, the minimum is %.1f:1)"
                % (page, pill["text"], pill["color"], pill["background"],
                   pill["ratio"], min_pill_contrast))
    return problems


def contrast_summary(measurements):
    """The weakest readings of the theme, as a human reads them."""
    body = None
    weakest_pill = None
    weakest_text = None
    for data in measurements.values():
        contrast = data.get("contrast") or {}
        reading = contrast.get("body")
        if reading and (body is None or reading["ratio"] < body["ratio"]):
            body = reading
        pill_reading = contrast.get("weakest")
        if pill_reading and (weakest_text is None
                             or pill_reading["ratio"] < weakest_text["ratio"]):
            weakest_text = pill_reading
        for pill in contrast.get("pills", []):
            if weakest_pill is None or pill["ratio"] < weakest_pill["ratio"]:
                weakest_pill = pill
    parts = []
    if body:
        parts.append("the text %.1f:1" % body["ratio"])
    if weakest_pill:
        parts.append("the weakest pill %s %.1f:1"
                     % (weakest_pill["text"], weakest_pill["ratio"]))
    if weakest_text:
        parts.append("the faintest label %.1f:1" % weakest_text["ratio"])
    return ", ".join(parts)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory, port):
    handler = functools.partial(Quiet, directory=directory)
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    return httpd


def measure(chrome, dist, page, width, height, scheme):
    """Return the measurements of one page, measured at the given width."""
    workdir = tempfile.mkdtemp(prefix="mathc-ui-probe-")
    try:
        os.symlink(os.path.abspath(dist), os.path.join(workdir, "dist"))
        probe = PROBE.replace("FRAME_SRC", json.dumps("dist/" + page))
        wrapper = WRAPPER % {"width": width, "height": height, "probe": probe}
        with open(os.path.join(workdir, "probe.html"), "w", encoding="utf-8") as handle:
            handle.write(wrapper)
        port = free_port()
        httpd = serve(workdir, port)
        command = [chrome, "--headless", "--no-sandbox", "--disable-gpu",
                   "--virtual-time-budget=15000", "--dump-dom"]
        if scheme == "dark":
            # The browser is told to prefer the dark scheme. The feature
            # that would repaint the page on its own is switched off, so
            # that the reading is the reading of the stylesheet.
            command += ["--force-dark-mode",
                        "--disable-features=WebContentsForceDark"]
        command.append("http://127.0.0.1:%d/probe.html" % port)
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    timeout=120)
        finally:
            httpd.shutdown()
        match = re.search(r"PROBE:(\{.*?\})\n", result.stdout, re.S)
        if not match:
            error = re.search(r"PROBE-ERROR:(.*)", result.stdout)
            if error:
                raise RuntimeError("the page failed to measure: %s" % error.group(1).strip())
            raise RuntimeError("the browser returned no measurement")
        data = json.loads(match.group(1))
        if data.get("scheme") != scheme:
            raise RuntimeError(
                "the browser did not honour the %s colour scheme (it reports %s)"
                % (scheme, data.get("scheme")))
        return data
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dist", required=True)
    parser.add_argument("--chrome", default="")
    parser.add_argument("--page", default="index.html")
    parser.add_argument("--pages", default="")
    parser.add_argument("--width", type=int, default=360)
    parser.add_argument("--height", type=int, default=760)
    parser.add_argument("--scheme", default="light", choices=["light", "dark"],
                        help="the colour scheme the browser must use")
    parser.add_argument("--min-contrast", type=float, default=4.5,
                        help="the least contrast of the text")
    parser.add_argument("--min-pill-contrast", type=float, default=0,
                        help="the least contrast of the state pills "
                             "(the least contrast of the text when it is 0)")
    parser.add_argument("--verify", action="store_true",
                        help="report the defects and exit 1 when there are any")
    args = parser.parse_args()
    if args.min_pill_contrast <= 0:
        args.min_pill_contrast = args.min_contrast

    chrome = find_chrome(args.chrome)
    if chrome is None:
        print("no browser: chromium, google-chrome or chrome is required")
        return 3

    pages = [p for p in args.pages.split(",") if p] or [args.page]
    problems = []
    measurements = {}
    for page in pages:
        try:
            data = measure(chrome, args.dist, page, args.width, args.height,
                           args.scheme)
        except Exception as error:  # noqa: BLE001 - the reason is printed
            print("the measurement failed: %s" % error)
            return 3
        measurements[page] = data
        if args.verify:
            problems.extend(problems_of(data, page, args.min_contrast,
                                        args.min_pill_contrast))

    if args.verify:
        families = {page: (data.get("bodyFont"),
                           tuple(sorted({link["font"] for link in data.get("links", [])})))
                     for page, data in measurements.items()}
        if len(set(families.values())) > 1:
            problems.append("the languages are drawn by different typefaces: %s" % families)
        if problems:
            for problem in problems:
                print("check-ui: %s" % problem)
            return 1
        print("check-ui: %d page(s) measured at %d px in the %s theme, no defect"
              % (len(pages), args.width, args.scheme))
        summary = contrast_summary(measurements)
        if summary:
            print("check-ui: the %s theme reads: %s" % (args.scheme, summary))
        return 0

    for page, data in measurements.items():
        print(json.dumps(data, ensure_ascii=False))
    return 0



if __name__ == "__main__":
    sys.exit(main())
