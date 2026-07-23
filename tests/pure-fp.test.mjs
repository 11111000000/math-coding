// tests/pure-fp.test.mjs
// Node --test runner. Runs in CI only (NOT shipped to browser).
// Verifies pure/filter.mjs, pure/render.mjs, pure/escape.mjs.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  filterPackets,
  sortPackets,
  readFilterFromSearch,
  groupByLifecycle,
} from '../site/assets/js/pure/filter.mjs';
import {
  renderPacketCard,
  renderPacketList,
  renderFilterCount,
} from '../site/assets/js/pure/render.mjs';
import { escapeHtml } from '../site/assets/js/pure/escape.mjs';

// === escapeHtml ===
test('escapeHtml escapes the five dangerous chars', () => {
  assert.equal(escapeHtml('<script>alert(1)</script>'),
               '&lt;script&gt;alert(1)&lt;/script&gt;');
  assert.equal(escapeHtml('a & b'), 'a &amp; b');
  assert.equal(escapeHtml('"x"'), '&quot;x&quot;');
  assert.equal(escapeHtml("it's"), 'it&#39;s');
  assert.equal(escapeHtml(null), '');
  assert.equal(escapeHtml(undefined), '');
  assert.equal(escapeHtml(42), '42');
});

// === filterPackets ===
test('filterPackets returns input unchanged with empty spec', () => {
  const ps = [{ id: 'a', title: 'A' }, { id: 'b', title: 'B' }];
  assert.deepEqual(filterPackets(ps, {}), ps);
});

test('filterPackets filters by depends_on (axiom packet reference)', () => {
  const ps = [
    { id: '00-difference', depends_on: [] },
    { id: '01-care',      depends_on: ['00-difference'] },
    { id: '02-curry-howard', depends_on: ['00-difference', '01-care'] },
    { id: 'some-pkt',    depends_on: ['03-material'] },
  ];
  // Filter by 00-difference: axiom itself + any packet with depends_on
  const out = filterPackets(ps, { deps: '00-difference' });
  assert.deepEqual(out.map(p => p.id).sort(), ['00-difference', '01-care', '02-curry-howard']);
});

test('filterPackets with no deps filter returns input unchanged', () => {
  const ps = [
    { id: 'a', depends_on: ['x'] },
    { id: 'b', depends_on: ['y'] },
  ];
  assert.deepEqual(filterPackets(ps, { deps: null }), ps);
});

test('filterPackets filters by lifecycle', () => {
  const ps = [
    { id: 'a', lifecycle: 'applied' },
    { id: 'b', lifecycle: 'draft' },
  ];
  const out = filterPackets(ps, { lifecycle: 'applied' });
  assert.deepEqual(out.map(p => p.id), ['a']);
});

test('filterPackets searches case-insensitive over title + id', () => {
  const ps = [
    { id: 'a-care', title: 'axiom A1 Care' },
    { id: 'a-material', title: 'axiom A3 Material Basis' },
  ];
  assert.deepEqual(filterPackets(ps, { q: 'CARE' }).map(p => p.id), ['a-care']);
  assert.deepEqual(filterPackets(ps, { q: 'material' }).map(p => p.id), ['a-material']);
  assert.deepEqual(filterPackets(ps, { q: 'nonexistent' }), []);
});

test('filterPackets composes filters (AND semantics)', () => {
  const ps = [
    { id: 'a', depends_on: ['00-difference'], lifecycle: 'applied', title: 'X' },
    { id: 'b', depends_on: ['00-difference'], lifecycle: 'draft',   title: 'X' },
    { id: 'c', depends_on: ['01-care'],       lifecycle: 'applied', title: 'X' },
  ];
  const out = filterPackets(ps, { deps: '00-difference', lifecycle: 'applied' });
  assert.deepEqual(out.map(p => p.id), ['a']);
});

test('filterPackets defends against missing fields', () => {
  const ps = [{ id: 'a' }, { id: 'b', depends_on: ['00-difference'] }];
  assert.deepEqual(filterPackets(ps, { deps: '00-difference' }).map(p => p.id), ['b']);
  assert.deepEqual(filterPackets(ps, {}), ps);
  assert.deepEqual(filterPackets(ps, { deps: '' }), ps);
});

// === sortPackets ===
test('sortPackets puts applied first, then by axiom, then by id', () => {
  const ps = [
    { id: 'b', lifecycle: 'draft', axiom: 'A1' },
    { id: 'a', lifecycle: 'applied', axiom: 'A1' },
    { id: 'c', lifecycle: 'applied', axiom: 'A0' },
  ];
  const sorted = sortPackets(ps);
  assert.deepEqual(sorted.map(p => p.id), ['c', 'a', 'b']);
});

// === groupByLifecycle ===
test('groupByLifecycle keys by lifecycle', () => {
  const ps = [
    { id: 'a', lifecycle: 'applied' },
    { id: 'b', lifecycle: 'applied' },
    { id: 'c', lifecycle: 'draft' },
  ];
  const out = groupByLifecycle(ps);
  assert.equal(out.applied.length, 2);
  assert.equal(out.draft.length, 1);
});

// === readFilterFromSearch ===
test('readFilterFromSearch parses URLSearchParams', () => {
  assert.deepEqual(readFilterFromSearch('?deps=00-difference&lifecycle=applied&q=cache'),
    { deps: '00-difference', lifecycle: 'applied', q: 'cache' });
  assert.deepEqual(readFilterFromSearch(''),
    { deps: null, lifecycle: null, q: '' });
  assert.deepEqual(readFilterFromSearch('?q='),
    { deps: null, lifecycle: null, q: '' });
});

// === renderPacketCard (XSS-safe by escapeHtml layer) ===
test('renderPacketCard escapes hostile user input', () => {
  const p = {
    id: '<script>alert(1)</script>',
    title: '"><img src=x onerror=alert(1)>',
    lifecycle: 'applied',
    axiom: 'A0',
    lastSha: 'abcdef1234567',
  };
  const html = renderPacketCard(p);
  // rendered output must NOT contain raw <script> tag or unescaped onerror attribute
  assert.equal(html.includes('<script>'), false);
  assert.equal(html.includes('"onerror=alert'), false);
  assert.equal(html.includes("'onerror=alert"), false);
  // 7-char sha prefix used
  assert.equal(html.includes('sha abcdef1'), true);
  // escaped entities present
  assert.equal(html.includes('&lt;script&gt;'), true);
});

test('renderPacketCard omits sha when missing', () => {
  const p = { id: 'a', title: 'A', lifecycle: 'draft' };
  const html = renderPacketCard(p);
  assert.equal(html.includes('sha '), false);
});

test('renderPacketList concatenates cards', () => {
  const ps = [
    { id: 'a', title: 'A', lifecycle: 'applied' },
    { id: 'b', title: 'B', lifecycle: 'draft' },
  ];
  const html = renderPacketList(ps);
  assert.equal((html.match(/<article class="packet-card"/g) || []).length, 2);
});

test('renderFilterCount handles total and filtered states', () => {
  assert.equal(renderFilterCount(10, 10), '10 packets');
  assert.equal(renderFilterCount(10, 3), '3 of 10 packets');
});
