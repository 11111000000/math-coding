// main.mjs — site entry point.
//
// Side effects (the ONLY side-effects in the site):
//   1. setup() theme module → sets [data-theme] on root.
//   2. fetch /data/packets-manifest.json ONCE.
//   3. (if /packets.html) wire up filter-bar; on change re-render #packets-grid.
//   4. (always) populate <span id="git-sha-footer"> with current build sha.
//
// Pure FP modules (filter, render, escape) compose without I/O.
// No innerHTML on dynamic strings — DOMParser.parseFromString for fragments.

import { setup as setupTheme } from './theme.mjs';
import {
  filterPackets,
  sortPackets,
  readFilterFromSearch,
} from './pure/filter.mjs';
import { renderPacketCard, renderFilterCount } from './pure/render.mjs';
import { prettifyMathBlocks } from './math-prettify.mjs';

// === Side effect 1: theme setup (one attribute mutation) ===
setupTheme();

// === Side effect 2: populate git-sha stamps (a few textContent writes) ===
const shaStamps = document.querySelectorAll('#git-sha, #git-sha-footer');
shaStamps.forEach(el => {
  // We embed the build SHA via a query-string-less placeholder
  // from the build script. For now, the build script must replace
  // <!--BUILT-SHA--> with the real short SHA before deploy.
  const html = document.documentElement.outerHTML;
  const match = html.match(/<!--BUILT-SHA:([a-f0-9]+)-->/);
  if (match) el.textContent = match[1];
});

// === Side effect 2b: prettify math notation blocks ===
// Detects math-y <pre> blocks (theorem-box context + unicode signals)
// and adds .pre-math class. CSS renders them as displayed equations.
prettifyMathBlocks(document);

// === Side effect 3: /packets.html live-filter wiring ===
const grid = document.getElementById('packets-grid');
if (grid) {
  wirePacketsPage(grid);
}

async function wirePacketsPage(gridEl) {
  let manifest = [];
  try {
    const resp = await fetch('/data/packets-manifest.json', { cache: 'no-cache' });
    if (resp.ok) manifest = await resp.json();
  } catch (err) {
    gridEl.innerHTML = '';
    renderError(gridEl, 'Could not load manifest: ' + err.message);
    return;
  }

  if (!Array.isArray(manifest)) {
    renderError(gridEl, 'Manifest is not a JSON array.');
    return;
  }

  const axiomSel    = document.getElementById('filter-axiom');
  const lifecycleSel = document.getElementById('filter-lifecycle');
  const qInput      = document.getElementById('filter-q');
  const countEl     = document.getElementById('filter-count');

  const render = () => {
    const filter = readFilterFromSearch(URLSearchParams_toSearchString({
      axiom: axiomSel ? axiomSel.value : '',
      lifecycle: lifecycleSel ? lifecycleSel.value : '',
      q: qInput ? qInput.value : '',
    }));
    const sorted = sortPackets(manifest);
    const filtered = filterPackets(sorted, filter);

    gridEl.replaceChildren(...filtered.map(p => {
      const tmpl = htmlToElement(renderPacketCard(p));
      return tmpl;
    }));

    if (countEl) countEl.textContent = renderFilterCount(manifest.length, filtered.length);

    // Update browser URL (no navigation) so the filter state is shareable.
    const search = [];
    if (filter.axiom)     search.push('axiom=' + encodeURIComponent(filter.axiom));
    if (filter.lifecycle) search.push('lifecycle=' + encodeURIComponent(filter.lifecycle));
    if (filter.q)         search.push('q=' + encodeURIComponent(filter.q));
    const qs = search.length ? '?' + search.join('&') : '';
    if (location.search !== qs) {
      history.replaceState({}, '', qs ? location.pathname + qs : location.pathname);
    }
  };

  if (axiomSel)    axiomSel.addEventListener('change', render);
  if (lifecycleSel) lifecycleSel.addEventListener('change', render);
  if (qInput)      qInput.addEventListener('input', () => {
    // small debounce for typing
    clearTimeout(qInput._t);
    qInput._t = setTimeout(render, 80);
  });

  // initial render with URL search applied
  const urlFilter = readFilterFromSearch(location.search);
  if (axiomSel    && urlFilter.axiom)     axiomSel.value = urlFilter.axiom;
  if (lifecycleSel && urlFilter.lifecycle) lifecycleSel.value = urlFilter.lifecycle;
  if (qInput      && urlFilter.q)         qInput.value = urlFilter.q;

  render();
}

// helper: parse object {axiom, lifecycle, q} into ?axiom=...&lifecycle=...&q=...
function URLSearchParams_toSearchString(obj) {
  const params = new URLSearchParams();
  if (obj.axiom) params.set('axiom', obj.axiom);
  if (obj.lifecycle) params.set('lifecycle', obj.lifecycle);
  if (obj.q) params.set('q', obj.q);
  return params.toString();
}

// helper: convert HTML string to first DOM element (NO scripts execute)
function htmlToElement(html) {
  const tmpl = document.createElement('template');
  tmpl.innerHTML = html.trim();
  return tmpl.content.firstElementChild;
}

function renderError(parent, message) {
  const p = document.createElement('p');
  p.style.cssText = 'font-family: var(--font-mono); color: var(--antithesis); font-size: var(--text-sm)';
  p.textContent = message;
  parent.appendChild(p);
}
