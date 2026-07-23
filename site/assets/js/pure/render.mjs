// pure/render.mjs
// Pure rendering of a packet card as an HTML fragment.
// IMPORTANT: callers must NOT innerHTML this output directly.
// Use DOMParser or build DOM nodes via createElement + textContent.

import { escapeHtml, escapeAttr } from './escape.mjs';

/**
 * Render a single packet as a card HTML fragment.
 * Pure: same packet → same string.
 *
 * @param {object} p  packet { id, title, lifecycle, axiom, lastSha }
 * @returns {string} HTML fragment
 */
export const renderPacketCard = (p) => {
  const lifecycle = (p.lifecycle || '').toLowerCase();
  const lifecycleClass = `lifecycle-pill lifecycle-pill--${escapeAttr(lifecycle)}`;
  const shaShort = p.lastSha ? String(p.lastSha).slice(0, 7) : '';
  const shaFull = p.lastSha ? String(p.lastSha) : '';

  return `
<article class="packet-card" data-lifecycle="${escapeAttr(lifecycle)}" data-axiom="${escapeAttr(p.axiom || '')}">
  <h3 class="packet-card__title">
    <a href="${escapeAttr(`/packets/${p.id}/`)}">${escapeHtml(p.title || p.id)}</a>
  </h3>
  <div class="packet-card__meta">
    <span class="${lifecycleClass}">${escapeHtml(lifecycle)}</span>
    ${p.axiom && p.axiom !== 'false' && p.axiom !== ''
      ? `<span class="sha-link">axiom ${escapeHtml(p.axiom)}</span>`
      : ''}
    ${shaShort ? `<a class="sha-link" title="${escapeAttr(shaFull)}" href="https://github.com/11111000000/math-coding/commit/${escapeAttr(shaFull)}">sha ${escapeHtml(shaShort)}</a>` : ''}
  </div>
  <p class="packet-card__id" style="font-family: var(--font-mono); font-size: var(--text-xs); color: var(--ink-soft); margin: 0">${escapeHtml(p.id)}</p>
</article>`.trim();
};

/**
 * Render an array of packets as a document fragment string.
 * Pure: same array → same string.
 */
export const renderPacketList = (packets) =>
  packets.map(renderPacketCard).join('\n');

/**
 * Render a count message ("24 packets · filtered to 8").
 * Pure.
 */
export const renderFilterCount = (total, filtered) => {
  if (total === filtered) return `${total} packets`;
  return `${filtered} of ${total} packets`;
};
