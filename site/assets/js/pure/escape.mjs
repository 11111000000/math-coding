// pure/escape.mjs
// Pure HTML escape function.
// XSS-safe by construction; no user input should ever reach innerHTML.

export const escapeHtml = (s) =>
  String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

export const escapeAttr = escapeHtml;
