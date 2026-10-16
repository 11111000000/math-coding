// assets/site.js -- site navigation, active-link highlight,
// live verdict counter. The site.css file drives the hamburger
// and dropdown visibility declaratively (via media queries and
// the [aria-expanded] sibling selector); this script only adds
// the click / keyboard affordance and keeps aria-* attributes in
// sync with the rendered state.
//
// Loaded with `defer` from `lib/render.ml::render_page`, so the
// document is fully parsed before the IIFE below runs.
(function () {
  'use strict';

  // Hamburger toggle: flips aria-expanded on .nav-toggle. CSS
  // already shows/hides .nav-inner via the sibling selector
  // [aria-expanded="true"] + .nav-inner on viewports <= 760 px,
  // so this handler only mutates the attribute; it does not
  // touch inline styles.
  function setupHamburger() {
    var btn = document.querySelector('.nav-toggle');
    var inner = document.querySelector('.nav-inner');
    if (!btn || !inner) return;
    btn.addEventListener('click', function () {
      var expanded = btn.getAttribute('aria-expanded') === 'true';
      btn.setAttribute('aria-expanded', expanded ? 'false' : 'true');
    });
    // If the user resizes from mobile (menu open) to desktop,
    // collapse the toggle so the desktop nav reflects a clean
    // aria state. CSS handles the visual side; we only need to
    // keep the attribute honest.
    var mq = window.matchMedia('(max-width: 760px)');
    var onChange = function (ev) {
      if (!ev.matches) {
        btn.setAttribute('aria-expanded', 'false');
      }
    };
    if (mq.addEventListener) mq.addEventListener('change', onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }

  // Grouped dropdowns (site-redesign-2026-10 + a11y follow-up):
  //   - click the group toggle -> aria-expanded toggles, panel
  //     shows / hides (CSS reads aria-expanded)
  //   - click outside any open group -> all groups close
  //   - Escape key -> close the open group, return focus to its toggle
  //   - mouse hover is handled by CSS :hover (and :focus-within for
  //     keyboard users); JS only adds click / keyboard semantics
  function setupGroupDropdowns() {
    var groups = document.querySelectorAll('.nav-group');
    if (!groups.length) return;

    function closeAll(except) {
      groups.forEach(function (g) {
        if (g === except) return;
        var t = g.querySelector('.nav-group-toggle');
        if (t) t.setAttribute('aria-expanded', 'false');
      });
    }

    groups.forEach(function (g) {
      var toggle = g.querySelector('.nav-group-toggle');
      if (!toggle) return;
      toggle.addEventListener('click', function (e) {
        e.stopPropagation();
        var open = toggle.getAttribute('aria-expanded') === 'true';
        closeAll(g);
        toggle.setAttribute('aria-expanded', open ? 'false' : 'true');
      });
    });

    document.addEventListener('click', function (e) {
      var t = e && e.target;
      groups.forEach(function (g) {
        if (t && g.contains(t)) return;
        var btn = g.querySelector('.nav-group-toggle');
        if (btn) btn.setAttribute('aria-expanded', 'false');
      });
    });

    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      var open = document.querySelector(
        '.nav-group-toggle[aria-expanded="true"]'
      );
      if (open) {
        open.setAttribute('aria-expanded', 'false');
        open.focus();
      }
    });
  }

  // Highlight the nav link that points at the current page.
  // path may end with or without a trailing slash and may include
  // a directory (e.g. `/math-coding/decisions/`); we match by the
  // basename against the link's href so /decisions/ and the
  // index.html fallback both highlight correctly.
  function highlightActiveLink() {
    var here = location.pathname.split('/').filter(Boolean).pop() ||
               'index.html';
    var links = document.querySelectorAll('.nav-link');
    links.forEach(function (a) {
      var href = a.getAttribute('href') || '';
      var linkBase = href.split('/').filter(Boolean).pop() || href;
      if (linkBase === here) a.classList.add('active');
    });
  }

  // Hide-on-scroll for the sticky nav (UX follow-up to
  // fix-dropdown-anim-2026-10): when the user scrolls DOWN,
  // the nav slides up off-screen (transform: translateY(-100%)
  // via the .nav-hidden class in style.css). When the user
  // scrolls UP, the nav slides back. The threshold avoids
  // jitter at the top of the page and at the very bottom.
  // The handler is rAF-throttled (one read per animation frame)
  // and uses {passive: true} on the listener so the scroll
  // event doesn't block the main thread.
  function setupHideOnScroll() {
    var nav = document.querySelector('.site-nav');
    if (!nav) return;
    var lastY = window.scrollY || 0;
    var ticking = false;
    var TOP_THRESHOLD = 80;
    var EDGE_THRESHOLD = 60;
    var MIN_DELTA = 4;
    function update() {
      var y = window.scrollY || 0;
      var docH = document.documentElement.scrollHeight;
      var winH = window.innerHeight;
      // Always show near the very top so the user can still
      // tap a nav link immediately after page load.
      if (y < TOP_THRESHOLD) {
        nav.classList.remove('nav-hidden');
      } else if (y + winH > docH - EDGE_THRESHOLD) {
        // Always show near the bottom — the user is reaching
        // the end of the page; hiding the nav now would force
        // them to scroll all the way back up.
        nav.classList.remove('nav-hidden');
      } else if (y - lastY > MIN_DELTA) {
        // Scrolled down by more than MIN_DELTA px — hide.
        nav.classList.add('nav-hidden');
      } else if (lastY - y > MIN_DELTA) {
        // Scrolled up — show.
        nav.classList.remove('nav-hidden');
      }
      lastY = y;
      ticking = false;
    }
    window.addEventListener('scroll', function () {
      if (!ticking) {
        window.requestAnimationFrame(update);
        ticking = true;
      }
    }, { passive: true });
  }

  // Live verdict counter (Phase 3 of site-quality-polish-2026-10):
  // reads data-mathc-* attributes that the kernel already emits
  // on the package-grid wrapper and surfaces them in the hero
  // meta paragraph. Falls back gracefully: if the wrapper is
  // absent (e.g., on a non-home page) the script is a no-op.
  // Values are sanitised to a leading digit (a strict subset of
  // what the kernel emits today); any future kernel change that
  // passes non-numeric text is dropped to `0`.
  function updateLiveCounters() {
    var grid = document.querySelector('[data-mathc-package-count]');
    var meta = document.querySelector('.hero .meta');
    if (!grid || !meta) return;
    function digits(attr) {
      var raw = grid.getAttribute(attr) || '';
      var m = raw.match(/^[0-9]+/);
      return m ? m[0] : '0';
    }
    var total = digits('data-mathc-package-count');
    var pass = digits('data-mathc-pass-count');
    var unknown = digits('data-mathc-unknown-count');
    var fail = digits('data-mathc-fail-count');
    var summary =
      'Live: ' + total + ' obligations (' +
      pass + ' pass, ' +
      unknown + ' unknown' +
      (fail !== '0' ? ', ' + fail + ' fail' : '') +
      '). The package grid below is the live output of mathc packages.';
    meta.innerHTML = 'Active policy: <code>bootstrap-v3</code>. ' +
      summary.replace(/mathc packages/g, '<code>mathc packages</code>');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      setupHamburger();
      setupGroupDropdowns();
      highlightActiveLink();
      updateLiveCounters();
      setupHideOnScroll();
    });
  } else {
    setupHamburger();
    setupGroupDropdowns();
    highlightActiveLink();
    updateLiveCounters();
    setupHideOnScroll();
  }
})();