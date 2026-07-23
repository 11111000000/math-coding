// pure/filter.mjs
// Pure predicates over the packet manifest.
// Tested by tests/pure-fp.test.mjs in CI (Node --test).
// No DOM, no side-effects.

/**
 * Filter packets by depends-on axiom (string id), lifecycle, and
 * search query. The "depends on axiom" filter shows all packets that
 * list the given axiom in their depends_on array.
 *
 * Pure: same input → same output.
 *
 * @param {Array<object>} packets
 * @param {{deps?: string|null, lifecycle?: string|null, q?: string|null}} opts
 * @returns {Array<object>}
 */
export const filterPackets = (packets, opts = {}) => {
  // Empty string is treated as "no filter", same as null.
  const deps = (opts.deps == null || opts.deps === '') ? null : opts.deps;
  const lifecycle = (opts.lifecycle == null || opts.lifecycle === '') ? null : opts.lifecycle;
  const q = (opts.q ?? '').toLowerCase().trim();

  return packets.filter(p => {
    if (deps !== null) {
      const ds = Array.isArray(p.depends_on) ? p.depends_on : [];
      if (!ds.includes(deps) && p.id !== deps) return false;
    }
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
    deps: params.get('deps') || null,
    lifecycle: params.get('lifecycle') || null,
    q: params.get('q') || '',
  };
};
