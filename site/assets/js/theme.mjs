// theme.mjs
// Theme toggle: prefers-color-scheme + manual override via [data-theme].
// Pure setup (input → applyTheme attribute mutation), no DOM pollution.

const root = document.documentElement;
const STORAGE_KEY = 'math-coding-theme';

const prefersDark = () =>
  typeof window !== 'undefined' &&
  window.matchMedia &&
  window.matchMedia('(prefers-color-scheme: dark)').matches;

const initial = () => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'light' || stored === 'dark') return stored;
  } catch { /* localStorage may be unavailable */ }
  return prefersDark() ? 'dark' : 'light';
};

export const setup = () => {
  const theme = initial();
  root.setAttribute('data-theme', theme);

  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  if (mq && mq.addEventListener) {
    mq.addEventListener('change', (e) => {
      try {
        const stored = localStorage.getItem(STORAGE_KEY);
        if (!stored) {
          root.setAttribute('data-theme', e.matches ? 'dark' : 'light');
        }
      } catch { /* ignore */ }
    });
  }

  const btn = document.getElementById('theme-toggle');
  if (btn) {
    btn.addEventListener('click', () => {
      const current = root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
      const next = current === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem(STORAGE_KEY, next); } catch { /* ignore */ }
    });
  }
};
