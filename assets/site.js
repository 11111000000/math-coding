// assets/site.js -- site navigation, mermaid init, search index loader,
// live verdict counter.
(function () {
  'use strict';

  function toggleNav() {
    var btn = document.querySelector('.nav-toggle');
    var inner = document.querySelector('.nav-inner');
    if (!btn || !inner) return;
    btn.addEventListener('click', function () {
      var expanded = btn.getAttribute('aria-expanded') === 'true';
      btn.setAttribute('aria-expanded', expanded ? 'false' : 'true');
      inner.classList.toggle('is-open');
    });
  }

  function highlightActiveLink() {
    var here = window.location.pathname.split('/').pop() || 'index.html';
    var links = document.querySelectorAll('.nav-link');
    links.forEach(function (a) {
      var href = a.getAttribute('href') || '';
      if (href === here) a.classList.add('active');
    });
  }

  // Live verdict counter (Phase 3 of site-quality-polish-2026-10):
  // reads data-mathc-* attributes that the kernel already emits
  // on the package-grid wrapper and surfaces them in the hero
  // meta paragraph. Falls back gracefully: if the wrapper is
  // absent (e.g., on a non-home page) the script is a no-op.
  function updateLiveCounters() {
    var grid = document.querySelector('[data-mathc-package-count]');
    var meta = document.querySelector('.hero .meta');
    if (!grid || !meta) return;
    var total = grid.getAttribute('data-mathc-package-count');
    var pass = grid.getAttribute('data-mathc-pass-count');
    var unknown = grid.getAttribute('data-mathc-unknown-count');
    var fail = grid.getAttribute('data-mathc-fail-count');
    if (!total) return;
    var summary =
      'Live: ' + total + ' obligations (' +
      pass + ' pass, ' +
      unknown + ' unknown' +
      (fail && fail !== '0' ? ', ' + fail + ' fail' : '') +
      '). The package grid below is the live output of mathc packages.';
    var code_open = '<code>';
    var code_close = '</code>';
    meta.innerHTML = 'Active policy: ' + code_open + 'bootstrap-v3' + code_close +
      '. ' + summary.replace(/mathc packages/g, '<code>mathc packages</code>');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      toggleNav();
      highlightActiveLink();
      updateLiveCounters();
    });
  } else {
    toggleNav();
    highlightActiveLink();
    updateLiveCounters();
  }
})();