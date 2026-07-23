// router.mjs — single-page-application navigation for math-coding site.
//
// Pure-FP feasibility: a router is inherently effectful (history.pushState,
// DOM swap, fetch). Pure helpers below are testable; the side-effectful
// `navigateTo` and `setupRouter` are the only mutation points.
//
// Behaviour:
//   - <a href="..."> clicks inside the same origin, plain clicks, are intercepted.
//     The page's main content (and <title>, aria-current, manifest state) is
//     updated in place. Browser history gets a new entry.
//
//   - Modified clicks (Ctrl/Cmd/Shift/Alt), target=_blank, mailto:, anchors,
//     external-origin links, and download links fall through to default
//     navigation behaviour.
//
//   - popstate (back/forward buttons) re-renders the destination without
//     pushing a new history entry.
//
//   - 4xx/5xx fetches fall back to full navigation.
//
//   - <main aria-busy="true"> signals loading (CSS shows an indicator).
//
// Graceful degradation: if JS fails to load (or this module errors out),
// every <a href> stays a normal anchor — full-page reload still works.

const SCROLL_KEY = 'math-coding-scroll';
const SCROLL_TIMEOUT_MS = 600;

let manifestCache = null;
let manifestPromise = null;
let currentPending = null;     // promise of an in-flight navigation
let indicatorTimer = null;

const root = typeof document !== 'undefined' ? document : null;

// === Pure helpers (testable) ============================================

/**
 * Returns true if `href` is a same-origin, non-anchor, non-mailto,
 * non-download link. Pure.
 *
 * @param {string|null|undefined} href
 * @param {string} [origin] window.location.origin, for same-origin check
 * @returns {boolean}
 */
export const isInternalLink = (href, origin = '') => {
  if (!href) return false;
  if (href.startsWith('#')) return false;            // pure anchor
  if (href.startsWith('mailto:')) return false;
  if (href.startsWith('tel:')) return false;
  if (href.startsWith('javascript:')) return false;
  if (href.startsWith('data:')) return false;
  if (href.startsWith('http://') || href.startsWith('https://')) {
    // Same-origin external link.
    if (!origin) return false;
    return href.startsWith(`${origin}/`) || href === origin;
  }
  if (href.startsWith('//')) return false;            // protocol-relative, off-origin
  if (href.length === 0) return false;
  return true;                                       // relative URL
};

/**
 * Returns true if the click event was modified and should bypass the SPA.
 * Pure of side effects on document.
 */
export const isModifiedClick = (e) =>
  Boolean(e.metaKey || e.ctrlKey || e.shiftKey || e.altKey);

/**
 * Returns the destination URL the link would resolve to. Pure.
 */
export const resolveHref = (a) => {
  if (!a || typeof a.getAttribute !== 'function') return null;
  const href = a.getAttribute('href');
  if (!href || href.startsWith('#')) return null;
  if (typeof location === 'undefined') return href;
  return new URL(href, location.href).href;
};

// === Side-effectful operations =========================================

/**
 * Cache-or-fetch the packets manifest. Pure side effect.
 * Same promise is reused when called concurrently.
 */
export const loadManifest = async (url = '/data/packets-manifest.json') => {
  if (manifestCache) return manifestCache;
  if (manifestPromise) return manifestPromise;
  manifestPromise = fetch(url, { cache: 'force-cache' })
    .then(r => r.ok ? r.json() : [])
    .then(d => { manifestCache = Array.isArray(d) ? d : []; return manifestCache; })
    .catch(() => { manifestCache = []; return manifestCache; });
  return manifestPromise;
};

const showIndicator = () => {
  if (indicatorTimer) clearTimeout(indicatorTimer);
  // Show after a short delay so fast transitions are seamless.
  indicatorTimer = setTimeout(() => {
    if (root) root.body.classList.add('is-loading');
  }, 120);
};

const hideIndicator = () => {
  if (indicatorTimer) { clearTimeout(indicatorTimer); indicatorTimer = null; }
  if (root) root.body.classList.remove('is-loading');
};

const saveScroll = () => {
  try {
    const key = `${SCROLL_KEY}:${location.pathname}${location.search}`;
    sessionStorage.setItem(key, String(window.scrollY));
  } catch { /* sessionStorage may be unavailable */ }
};

const restoreScroll = () => {
  try {
    const key = `${SCROLL_KEY}:${location.pathname}${location.search}`;
    const stored = sessionStorage.getItem(key);
    if (stored != null) {
      window.scrollTo({ top: Number(stored), behavior: 'instant' });
    } else {
      window.scrollTo({ top: 0, left: 0 });
    }
  } catch {
    window.scrollTo({ top: 0, left: 0 });
  }
};

/**
 * Swap <main>'s children with the parsed HTML's <main> children.
 * Update <title>, aria-current, and theme attribute preservation.
 *
 * Returns nothing. Pure DOM mutation.
 */
export const swapContent = (doc) => {
  if (!root) return;
  const newMain = doc.querySelector('main');
  const oldMain = root.querySelector('main');
  if (newMain && oldMain) {
    oldMain.replaceChildren(...Array.from(newMain.children));
    oldMain.removeAttribute('aria-busy');
  }
  if (doc.title) root.title = doc.title;

  // Update aria-current="page" in the nav.
  root.querySelectorAll('.site-nav a').forEach((a) => {
    a.removeAttribute('aria-current');
    const href = a.getAttribute('href');
    if (href && !href.startsWith('http') && !href.startsWith('#')) {
      try {
        const target = new URL(href, location.href).pathname;
        if (target === location.pathname) {
          a.setAttribute('aria-current', 'page');
        }
      } catch { /* ignore */ }
    }
  });
};

/**
 * Fetch the URL, parse, swap. Idempotent against rapid clicks:
 * concurrent calls cancel each other, only the latest wins.
 *
 * @param {string} url     absolute or relative URL
 * @param {boolean} [pushState]   true for in-app navigation
 *                               (false for popstate/back-forward)
 * @returns {Promise<boolean>}   true if navigated, false if fell back
 */
export const navigateTo = async (url, pushState = true) => {
  if (!root) { location.href = url; return false; }
  const target = new URL(url, location.href).href;
  if (target === location.href && pushState) {
    // Click on current page; just scroll up.
    window.scrollTo({ top: 0 });
    return true;
  }

  if (currentPending) {
    // Coalesce: ignore stale navigations.
    try { currentPending.abort?.(); } catch { /* no abort for fetch */ }
    currentPending = null;
  }

  if (pushState) saveScroll();
  showIndicator();
  if (root.querySelector('main')) {
    root.querySelector('main').setAttribute('aria-busy', 'true');
  }

  let resp;
  try {
    resp = await fetch(target, {
      credentials: 'same-origin',
      redirect: 'follow',
      headers: { Accept: 'text/html' },
    });
  } catch {
    hideIndicator();
    location.href = target;
    return false;
  }

  if (!resp.ok) {
    hideIndicator();
    location.href = target;
    return false;
  }

  let html;
  try {
    html = await resp.text();
  } catch {
    hideIndicator();
    location.href = target;
    return false;
  }

  const doc = new DOMParser().parseFromString(html, 'text/html');

  // Update URL BEFORE swap so aria-current logic sees the new URL.
  if (pushState) history.pushState({}, '', target);

  swapContent(doc);

  // Run page-specific setup on the new content.
  if (typeof window.__setupPageContent === 'function') {
    try { window.__setupPageContent(); } catch (e) { /* ignore */ }
  }

  restoreScroll();
  hideIndicator();
  return true;
};

/**
 * Intercept internal-link clicks on the document. Falls through to
 * default browser behaviour for external / modified / anchor / mailto.
 */
const onClick = (e) => {
  const a = e.target.closest && e.target.closest('a');
  if (!a) return;
  if (a.target === '_blank') return;
  if (a.hasAttribute('download')) return;
  if (isModifiedClick(e)) return;

  const href = a.getAttribute('href');
  if (!isInternalLink(href, location.origin)) return;
  if (a.origin !== location.origin) return;
  if (href.startsWith('#')) return;

  e.preventDefault();
  navigateTo(new URL(href, location.href).href, true);
};

const onPopState = () => {
  // Back/forward: do not push another history entry.
  navigateTo(location.href, false);
};

/**
 * Install the SPA router. Idempotent. Safe to call more than once.
 * Defer until document.body is available if needed.
 *
 * Side effect: registers `click` + `popstate` listeners on document/window,
 * and exposes `__setupPageContent` as a hook for the page logic module.
 */
export const setupRouter = () => {
  if (typeof window === 'undefined' || !root) return;
  if (setupRouter._installed) return;
  setupRouter._installed = true;

  document.addEventListener('click', onClick, { passive: false });
  window.addEventListener('popstate', onPopState);

  // Expose navigation API for programmatic jumps (used by live-filter).
  window.navigateTo = navigateTo;

  // Allow the main module to install its own setup hook at runtime.
  window.__setupPageContent = window.__setupPageContent || null;
};
