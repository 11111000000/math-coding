// pure/filter.mjs
// Pure predicates over the packet manifest.
// Tested by tests/pure-fp.test.mjs in CI (Node --test).
// No DOM, no side-effects.

/**
 * Filter packets by axiom (string), lifecycle (string), and search query (string).
 * Pure: same input → same output.
 *
 * @param {Array<object>} packets
 * @param {{axiom?: string|null, lifecycle?: string|null, q?: string|null}} opts
 * @returns {Array<object>}
 */
export const filterPackets = (packets, opts = {}) => {
  const axiom = opts.axiom ?? null;
  const lifecycle = opts.lifecycle ?? null;
  const q = (opts.q ?? '').toLowerCase().trim();

  return packets.filter(p => {
    if (axiom !== null && p.axiom !== axiom) return false;
    if (lifecycle !== null && p.lifecycle !== lifecycle) return false;
    if (q !== '') {
      const haystack = `${p.title} ${p.id}`.toLowerCase();
      if (!haystack.includes(q)) return false;
    }
    return true;
  });
};

/**
 * Group packets by lifecycle.
 * Pure: same input → same output.
 */
export const groupByLifecycle = (packets) =>
  packets.reduce((acc, p) => {
    if (!acc[p.lifecycle]) acc[p.lifecycle] = [];
    acc[p.lifecycle].push(p);
    return acc;
  }, {});

/**
 * Sort packets: applied first, then by axiom index (A0..A6), then by id.
 * Pure: same input → same output.
 */
export const sortPackets = (packets) => {
  const lifecycleOrder = { applied: 0, draft: 1, retired: 2, abandoned: 3 };
  return [...packets].sort((a, b) => {
    const la = lifecycleOrder[a.lifecycle] ?? 99;
    const lb = lifecycleOrder[b.lifecycle] ?? 99;
    if (la !== lb) return la - lb;
    if ((a.axiom || '') < (b.axiom || '')) return -1;
    if ((a.axiom || '') > (b.axiom || '')) return 1;
    return a.id.localeCompare(b.id);
  });
};

/**
 * Read URL query parameters as a filter-spec.
 * Pure with respect to a `search` string.
 */
export const readFilterFromSearch = (search) => {
  const params = new URLSearchParams(search || '');
  return {
    axiom: params.get('axiom') || null,
    lifecycle: params.get('lifecycle') || null,
    q: params.get('q') || '',
  };
};
