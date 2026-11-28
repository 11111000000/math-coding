# Designs

This folder holds designs shown on the Design canvas in Paseo. The user looks at them there,
points at elements and writes comments, and asks you to revise.

## Layout

- `design/<slug>/design.json`: the design's manifest.
- `design/<slug>/<artboard>.html`: one self-contained HTML page per artboard.
- `design/<slug>/comments.json`: the user's comments, written by the canvas. Only mark comments resolved (below).
- `design/<slug>/tweaks.json` and `tweaks.css`: the tweak values the user set, written by the canvas. Don't edit them.
- `design/canvas.json`: marks this workspace as using the canvas.

`design.json`:

```json
{
  "version": 1,
  "title": "Pricing page",
  "kind": "prototype",
  "description": "What this design is for, in a sentence or two.",
  "artboards": [
    { "id": "desktop", "title": "Desktop", "file": "desktop.html", "width": 1440 },
    { "id": "mobile", "title": "Mobile", "file": "mobile.html", "width": 390, "height": 844 }
  ]
}
```

- `kind` is one of prototype, wireframe, one-pager, slides, other.
- `id` uses lowercase letters, digits and dashes; `file` is an .html file in the same folder.
- `width` is the artboard width in CSS pixels. Presets: desktop 1440x900, tablet 834x1194, mobile 390x844.
- `height` fixes a screen height; leave it out to show the whole page.
- Artboards with the same `group` are variants of one screen and sit side by side.

## Writing pages

- Each page is complete HTML that works offline. Put CSS in `<style>` or in local .css files,
  and use local images and fonts. The canvas blocks loading from the network, CDNs included.
- Scripts run, so prototypes can be interactive. Keep them local too.
- Put `data-dc-id="<short-name>"` on every element the user may want to talk about: sections,
  cards, buttons, headings, images, form fields. Keep existing ids when you revise, so comments
  stay attached to their elements.
- Put values worth tuning (colors, spacing, radii, font sizes) in CSS custom properties on `:root`.
- When asked for options, add variants as new artboards in one group instead of overwriting.
- The user can drag elements on the canvas. A move adds `translate` (or `left`/`top` on positioned
  elements) to that element's inline style, and a dragged artboard gets `x` and `y` in design.json.
  Treat these as the user's intent: keep them, or fold them into proper layout when you revise.
- The user can also fix text on the canvas; it writes straight into the page. Keep their wording.

## Tweaks

Tweaks are controls the canvas shows beside a design, so the user can tune it without a round trip.
Each one drives a CSS custom property that the pages read. Declare them in design.json (or with the
design_set_tweaks tool):

```json
"tweaks": [
  { "id": "accent", "label": "Accent", "type": "color", "var": "--accent", "default": "#d97757" },
  { "id": "gap", "label": "Card gap", "type": "range", "var": "--card-gap", "min": 8, "max": 48, "step": 4, "unit": "px", "default": 24 },
  { "id": "badge", "label": "Show badge", "type": "toggle", "var": "--badge-display", "on": "inline-flex", "off": "none", "default": true },
  { "id": "hero", "label": "Hero", "type": "select", "var": "--hero-align",
    "options": [{ "label": "Left", "value": "start" }, { "label": "Center", "value": "center" }], "default": "start" }
]
```

- Set each variable on `:root` in the page's CSS with the same value as `default`, and use it with
  `var(--name)`. Toggles and selects switch the variable between CSS values, e.g.
  `display: var(--badge-display)` or `justify-content: var(--hero-align)`.
- Link `<link rel="stylesheet" href="tweaks.css">` last in each page's `<head>`: it holds the user's
  values, so the page looks the same outside the canvas.
- When revising, keep the tweaks and the user's values; design_read lists them. Fold a value into
  the design (and its `default`) only when the user asks.

## Comments

Comments arrive as a message listing each comment's number, artboard, the element it points at
(its data-dc-id or CSS path, and a text excerpt) and what the user wants. Make the change, then
mark the comments resolved with the design_resolve_comments tool, with one line per comment on
what you changed for it.
Without the tool, edit comments.json yourself: set each handled comment's `status` to
`"resolved"` and add a `"resolution"` with that one line. Change nothing else in the file.
