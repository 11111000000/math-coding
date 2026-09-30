// assets/site.js — site navigation, mermaid init, search index loader.
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

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      toggleNav();
      highlightActiveLink();
    });
  } else {
    toggleNav();
    highlightActiveLink();
  }
})();