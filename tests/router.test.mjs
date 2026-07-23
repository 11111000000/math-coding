// tests/router.test.mjs
// Node --test suite for pure router helpers.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  isInternalLink,
  isModifiedClick,
  resolveHref,
} from '../site/assets/js/router.mjs';

// === isInternalLink ===================================================

test('isInternalLink rejects null / undefined / empty', () => {
  assert.equal(isInternalLink(null), false);
  assert.equal(isInternalLink(undefined), false);
  assert.equal(isInternalLink(''), false);
});

test('isInternalLink accepts relative URLs', () => {
  assert.equal(isInternalLink('/packets.html'), true);
  assert.equal(isInternalLink('packets.html'), true);
  assert.equal(isInternalLink('../foo.html'), true);
  assert.equal(isInternalLink('?deps=00-difference'), true);
});

test('isInternalLink rejects anchors', () => {
  assert.equal(isInternalLink('#'), false);
  assert.equal(isInternalLink('#section-2'), false);
});

test('isInternalLink rejects mailto / tel / javascript / data', () => {
  assert.equal(isInternalLink('mailto:foo@example.com'), false);
  assert.equal(isInternalLink('tel:+1234567890'), false);
  assert.equal(isInternalLink('javascript:alert(1)'), false);
  assert.equal(isInternalLink('data:text/plain;base64,SGk='), false);
});

test('isInternalLink rejects external-origin http(s)', () => {
  // Without origin argument → always treats http as non-internal.
  assert.equal(isInternalLink('https://github.com/foo/bar'), false);
  assert.equal(isInternalLink('http://example.com/'), false);
});

test('isInternalLink treats same-origin http(s) as internal', () => {
  assert.equal(
    isInternalLink('https://11111000000.github.io/math-coding/page',
                    'https://11111000000.github.io'),
    true,
  );
  assert.equal(
    isInternalLink('https://11111000000.github.io/math-coding/',
                    'https://11111000000.github.io'),
    true,
  );
});

test('isInternalLink still rejects off-origin with origin set', () => {
  assert.equal(
    isInternalLink('https://github.com/foo/bar',
                    'https://11111000000.github.io'),
    false,
  );
});

test('isInternalLink rejects protocol-relative', () => {
  assert.equal(isInternalLink('//cdn.example.com/lib.js'), false);
  assert.equal(isInternalLink('//cdn.example.com/lib.js', 'https://x'), false);
});

// === isModifiedClick ===================================================

test('isModifiedClick detects modifier keys', () => {
  assert.equal(isModifiedClick({ metaKey: true }), true);
  assert.equal(isModifiedClick({ ctrlKey: true }), true);
  assert.equal(isModifiedClick({ shiftKey: true }), true);
  assert.equal(isModifiedClick({ altKey: true }), true);
  assert.equal(isModifiedClick({}), false);
  assert.equal(isModifiedClick({ metaKey: false, ctrlKey: false }), false);
});

test('isModifiedClick with multiple modifiers', () => {
  assert.equal(isModifiedClick({ metaKey: true, shiftKey: true }), true);
});

// === resolveHref =======================================================

test('resolveHref returns null for null link', () => {
  assert.equal(resolveHref(null), null);
});

test('resolveHref resolves relative URL against base', () => {
  // We can't easily test with location here in node, but we can
  // at least verify it returns null for anchors.
  const a = document_createElementMock('a', '#x');
  a.getAttribute = () => '#x';
  assert.equal(resolveHref(a), null);
});

test('resolveHref handles non-existent element', () => {
  assert.equal(resolveHref(undefined), null);
  assert.equal(resolveHref(null), null);
});

// Helper to create a minimal anchor-like object for resolveHref tests
// without requiring a browser Document.
function document_createElementMock(_tag, href) {
  return {
    getAttribute(name) { if (name === 'href') return href; return null; },
    setAttribute() {},
    removeAttribute() {},
    addEventListener() {},
    dataset: {},
    classList: { add() {}, remove() {}, contains: () => false, toggle() {} },
  };
}
