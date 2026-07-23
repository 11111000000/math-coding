// main.mjs — site entry point.
//
// Side effects (the ONLY side-effects in the site):
//   1. setupRouter() — SPA navigation via fetch + DOM swap.
//   2. setupTheme() — sets [data-theme] on root via localStorage override.
//   3. populate <span id="git-sha-footer"> with current build sha.
//   4. prettifyMathBlocks() — math notation rendering.
//   5. (if /packets.html) wire up filter-bar; re-run on SPA navigation.
//
// Pure FP modules (filter, render, escape) compose without I/O.
// No innerHTML on dynamic strings — DOMParser.parseFromString for
// fragments from router.mjs (which itself uses DOMParser on raw HTML).
//
// The "setup everything for the current page" function is exposed at
// window.__setupPageContent so the router can call it after every
// navigation. It runs both at initial load and on every SPA swap.

import { setup as setupTheme } from './theme.mjs';
import { setupRouter, loadManifest } from './router.mjs';
import {
  filterPackets,
  sortPackets,
  readFilterFromSearch,
} from './pure/filter.mjs';
import { renderPacketCard, renderFilterCount } from './pure/render.mjs';
import { prettifyMathBlocks } from './math-prettify.mjs';

// 1. SPA router first — installs click + popstate listeners.
setupRouter();

// 2. Theme. Persists via localStorage; honors prefers-color-scheme.
setupTheme();

// 3. Page-content setup. Runs once now, then re-runs from router.
const setupPageContent = () => {
  // 3a. git-sha stamps.
  document.querySelectorAll('#git-sha, #git-sha-footer').forEach(el => {
    const html = document.documentElement.outerHTML;
    const match = html.match(/<!--BUILT-SHA:([a-f0-9]+)-->/);
    if (match) el.textContent = match[1];
  });

  // 3b. Math notation detection.
  prettifyMathBlocks(document);

  // 3c. /packets.html live-filter wiring.
  const grid = document.getElementById('packets-grid');
  if (grid) wirePacketsPage(grid);
};

setupPageContent();

// Expose for router to call after every navigation.
if (typeof window !== 'undefined') {
  window.__setupPageContent = setupPageContent;
}

async function wirePacketsPage(gridEl) {
  // Module-level manifest cache (one fetch per session).
  const manifest = await loadManifest();

  if (!Array.isArray(manifest)) {
    renderError(gridEl, 'Manifest is not a JSON array.');
    return;
  }

  const depsSel      = document.getElementById('filter-deps');
  const lifecycleSel = document.getElementById('filter-lifecycle');
  const qInput       = document.getElementById('filter-q');
  const countEl      = document.getElementById('filter-count');

  const render = () => {
    const filter = readFilterFromSearch(URLSearchParams_toSearchString({
      deps: depsSel ? depsSel.value : '',
      lifecycle: lifecycleSel ? lifecycleSel.value : '',
      q: qInput ? qInput.value : '',
    }));
    const sorted = sortPackets(manifest);
    const filtered = filterPackets(sorted, filter);

    gridEl.replaceChildren(...filtered.map(p => htmlToElement(renderPacketCard(p))));

    if (countEl) countEl.textContent = renderFilterCount(manifest.length, filtered.length);

    // Update browser URL (no navigation) so the filter state is shareable.
    const search = [];
    if (filter.deps)       search.push('deps=' + encodeURIComponent(filter.deps));
    if (filter.lifecycle)  search.push('lifecycle=' + encodeURIComponent(filter.lifecycle));
    if (filter.q)          search.push('q=' + encodeURIComponent(filter.q));
    const qs = search.length ? '?' + search.join('&') : '';
    if (location.search !== qs) {
      history.replaceState({}, '', qs ? location.pathname + qs : location.pathname);
    }
  };

  if (depsSel)      depsSel.addEventListener('change', render);
  if (lifecycleSel) lifecycleSel.addEventListener('change', render);
  if (qInput)       qInput.addEventListener('input', () => {
    clearTimeout(qInput._t);
    qInput._t = setTimeout(render, 80);
  });

  // Initial render: URL search > form values.
  const urlFilter = readFilterFromSearch(location.search);
  if (depsSel       && urlFilter.deps)      depsSel.value = urlFilter.deps;
  if (lifecycleSel  && urlFilter.lifecycle) lifecycleSel.value = urlFilter.lifecycle;
  if (qInput        && urlFilter.q)         qInput.value = urlFilter.q;

  render();
}

function URLSearchParams_toSearchString(obj) {
  const params = new URLSearchParams();
  if (obj.deps) params.set('deps', obj.deps);
  if (obj.lifecycle) params.set('lifecycle', obj.lifecycle);
  if (obj.q) params.set('q', obj.q);
  return params.toString();
}

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
