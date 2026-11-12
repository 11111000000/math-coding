#!/usr/bin/env python3
"""Measure the rendered site in a phone-sized viewport.

The probe loads a page of the built site inside a narrow frame, waits for
the webfonts, and reports what the browser actually laid out: whether the
page scrolls sideways, whether a navigation item is cut off, whether the
call-to-action still has its bottom frame, and which typefaces were used.

It never asserts by itself: it prints the measurements as JSON and lets
the caller decide. Exit 0 when every measurement was taken, 3 when the
browser could not be run, which is not evidence of success.

Usage:
    ui-probe.py --dist DIR --chrome PATH [--width PX] [--page index.html]
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


def problems_of(data, page):
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
    return problems


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


def measure(chrome, dist, page, width, height):
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
        try:
            result = subprocess.run(
                [chrome, "--headless", "--no-sandbox", "--disable-gpu",
                 "--virtual-time-budget=15000", "--dump-dom",
                 "http://127.0.0.1:%d/probe.html" % port],
                capture_output=True, text=True, timeout=120)
        finally:
            httpd.shutdown()
        match = re.search(r"PROBE:(\{.*?\})\n", result.stdout, re.S)
        if not match:
            error = re.search(r"PROBE-ERROR:(.*)", result.stdout)
            if error:
                raise RuntimeError("the page failed to measure: %s" % error.group(1).strip())
            raise RuntimeError("the browser returned no measurement")
        return json.loads(match.group(1))
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
    parser.add_argument("--verify", action="store_true",
                        help="report the defects and exit 1 when there are any")
    args = parser.parse_args()

    chrome = find_chrome(args.chrome)
    if chrome is None:
        print("no browser: chromium, google-chrome or chrome is required")
        return 3

    pages = [p for p in args.pages.split(",") if p] or [args.page]
    problems = []
    measurements = {}
    for page in pages:
        try:
            data = measure(chrome, args.dist, page, args.width, args.height)
        except Exception as error:  # noqa: BLE001 - the reason is printed
            print("the measurement failed: %s" % error)
            return 3
        measurements[page] = data
        if args.verify:
            problems.extend(problems_of(data, page))

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
        print("check-ui: %d page(s) measured at %d px, no defect"
              % (len(pages), args.width))
        return 0

    for page, data in measurements.items():
        print(json.dumps(data, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
