---
schema_version: "2.0"
name: mobile-polish-v2-y
proposition: "Mobile typography and navigation v2.0-Y: (1) mjx-container scrolls internally with hidden visual scrollbar (scrollbar-width:none + ::-webkit-scrollbar{display:none}) and cursor:grab affordance; (2) nav below 720px viewport switches to a collapsible hamburger pattern (toggle button + JS class toggle on .nav-inner), preserving horizontal flex layout on desktop; (3) body font-size via clamp(15px, 1.6vw, 16px) so formulas inherit a smaller size on narrow phones; (4) prefers-reduced-motion respected on all transitions; (5) safe-area-inset padding for notched phones on body padding-bottom."
register: judgment
state: applied
actor: agent
confidence: 1.0
superseded_by:
beneficiary: User
---

## Why

Existing mobile layout has three observed defects on iPhone SE / Pixel 7
viewports (≤480px): (a) nav collapses to a vertical column that wastes
vertical space and makes the brand feel like a sidebar rather than a
header; (b) the `scrollbar-width` of `mjx-container` is visible on iOS
Safari and Android Chrome, drawing a thin grey rule inside each formula
that looks like a UI bug more than affordance; (c) formulas that are
inline in a sentence often overflow horizontally even though the page
itself doesn't, because MathJax measures glyphs without consulting the
viewport. Together these make the formal model (the unique selling
point on the appendix layer per `positioning-v2-y`) harder to read on
the very device the AI-agent-builder audience uses.

## Care

- Hamburger toggle requires JavaScript. The site ships plain HTML; if
  JS is disabled, the nav must remain usable. Fallback: the
  `details/summary` element pattern, which degrades to a native
  disclosure widget without script. We choose `details/summary` if
  feasible, otherwise a no-JS CSS-only fallback (`@media (max-width:
  720px)` shows nav-inner as block by default but allows
  `details[open] .nav-inner { max-height: ... }`).
- Hiding the scrollbar is a UX trade-off: users without a touchpad
  (most phone users) lose the affordance. Compensation: add
  `cursor: grab` on `mjx-container` plus a `mask-image` linear gradient
  on the right edge (`-webkit-mask-image: linear-gradient(to right, black
  85%, transparent);`) as a fade hint that more content exists. The fade
  is the recognized signal in Apple Notes / GitHub code blocks.
- `clamp()` for font-size is supported in all evergreen browsers (since
  2018) and dynamic on both desktop and mobile; it does not break
  print stylesheet (`@media print` already sets `body { font-size: 12pt }`).
- `prefers-reduced-motion` adds noise to every transition that has been
  introduced to date; only the nav-toggle transition actually needs a
  animation, so we wrap the whole rule in a media query guarded by
  not-reduced-motion, and ship a no-animation fallback otherwise.

## Thesis

Adopt five coordinated mobile-polish changes:

1. **Hidden scrollbar with affordance**: `mjx-container` gets
   `scrollbar-width: none` (Firefox) + `::-webkit-scrollbar { display:
   none }` (Chrome/Safari) + `cursor: grab` + a mask-image fade on the
   right edge. Scroll still works; visual chrome disappears; user
   intuition ("there's more to the right") is preserved by the fade.
2. **Hamburger nav on ≤720px**: replace the existing
   `<=480px` `flex-direction: column` rule with a
   `<details>`-based toggle (preferred for no-JS compatibility) plus
   inline-JS enhancement that toggles class on click for a smooth
   slide animation. Desktop nav (≥721px) remains the existing
   horizontal flex.
3. **Responsive body font**: replace `html { font-size: 16px }` with
   `html { font-size: clamp(15px, 0.95rem + 0.3vw, 16px) }` so a 375px
   viewport renders at ~15px while a 1920px desktop keeps 16px. MathJax
   formulas inherit this size and so shrink proportionally.
4. **`prefers-reduced-motion`**: wrap the hamburger `transition` in
   `@media (prefers-reduced-motion: no-preference)` and add
   `@media (prefers-reduced-motion: reduce)` that disables it.
5. **`safe-area-inset`**: add `padding-bottom: max(1rem,
   env(safe-area-inset-bottom))` on `<main>` and similar on the
   footer so iPhone-bottom-bar / Android gesture bar never overlap
   content.

## Antithesis

- **Do nothing.** Stay with column-stack nav and visible scrollbar.
  Cost: visitors on phones see the formal model on a half-broken
  layout; the AI-agent pitch lands worse than it could.
- **Pure CSS hamburger without JS or `<details>`.** Use the checkbox
  hack (`input[type=checkbox] + label + ul`). Cost: requires ARIA
  pairing, lost keyboard accessibility, requires `display: none`
  toggles. Worse than `<details>`/JS.
- **Drop down to a slide-out drawer.** Animate the nav from the left
  edge as a side panel. Cost: violates the convention of a top bar,
  more JS, and harder to test without full DOM-control tools.
- **Use a CSS framework (Tailwind, Bulma).** Bring in `tailwind.css`
  to ship a polished mobile-first cascade. Cost: ~10-30 KB extra,
  contradicts the convention (plain text + git; here, plain text +
  git + a CSS framework), and breaks the stand-alone-static-binary
  guarantee for `mathc render`.
- **Add `display: contents` to mjx to make it reflow naturally.**
  Cost: MathJax uses positioning hacks that don't survive a contents
  reflow; several mjx sub-elements compute glyphs absolutely.

## Synthesis

Adopt. Files touched:

- `assets/style.css` — five additions: (1) `mjx-container` scrollbar
  block + mask-image; (2) `details.nav / details.nav[open] > .nav-inner
  { max-height: ... }` plus `summary.nav-toggle { display: none }
  @media (max-width: 720px) { summary.nav-toggle { display: block } }`;
  (3) `html { font-size: clamp(15px, 0.95rem + 0.3vw, 16px) }`; (4)
  `prefers-reduced-motion` blocks; (5) `main, .site-footer { padding-
  bottom: max(1rem, env(safe-area-inset-bottom)) }`.
- `core/render.ml` — replace the existing `<nav class="site-nav">`
  emit with a `<details class="site-nav"><summary class="nav-toggle"
  aria-label="Toggle navigation">☰</summary><div class="nav-inner">…</
  div></details>` form, and append an inline `<script>` (≤15 lines)
  that upgrades the disclosure widget with a slide-down animation and
  proper `aria-expanded` toggling.

Worked example: a visitor from a Claude Code session clicks on the
site link in their terminal, lands on `/manifesto.html` on an iPhone.
The brand stays top-left, a ☰ button appears at the right of the
header. Tapping it slides the menu down with a 200 ms ease-out. No
JS-disabled fallback visible until then; with JS off the menu is
already open (browsers render `<details>` open by default if the
attribute is set; alternatively we render with `open` attribute to
avoid hiding content for non-JS users at first paint).

Trade-offs explicitly accepted:

- A small inline `<script>` (~15 lines) ships in every page. This
  is the only JavaScript added; the rest of the site remains plain
  HTML + CSS. The convention's "plain text + git" guarantee is
  preserved; the new script is plain text in `core/render.ml`.
- The `<details>` element is not stylable uniformly across Safari
  versions older than 14 (May 2020). All current targets (iOS ≥ 14,
  Android ≥ 8 with WebView ≥ 90) render it correctly. For older
  browsers the menu will be open by default — a graceful degradation,
  not a bug.

## Notes

- References: `positioning-v2-y` (audience note matters here), `mjx-mobile-overflow`
  (the previous MathJax-overflow packet; this packet extends, does not
  override it), `narrative-rebalance-v2-y` (front-load pitch; layout
  improvements reinforce that pitch on mobile).
- Inspiration: Apple Notes mask-image edges, GitHub code-block scroll,
  Tufte CSS sidenote behaviour, Tailwind responsive typography default.
- Future packet candidates: dark-mode toggle (out of scope here),
  print stylesheet revision (only triggered by Ctrl+P from phone),
  `prefers-color-scheme: dark` once brand colours settle.
- The inline script will live inside `core/render.ml`'s `render_page`
  output, in a single `<script>(function(){...})();</script>` block at
  the bottom of `<body>`. The script depends only on browser globals
  (no library, no framework, no CDn dependency).

