(() => {
  'use strict';
  const key = 'newbili-md-appearance';
  const system = matchMedia('(prefers-color-scheme: dark)');
  const root = document.documentElement;
  let preference = 'system';
  try { preference = localStorage.getItem(key) || 'system'; } catch (_) {}
  const valid = value => ['system', 'light', 'dark'].includes(value) ? value : 'system';
  function apply(value) {
    preference = valid(value);
    const dark = preference === 'dark' || (preference === 'system' && system.matches);
    root.dataset.theme = dark ? 'dark' : 'light';
    root.dataset.appearance = preference;
    root.style.colorScheme = dark ? 'dark' : 'light';
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#19171c' : '#f8f7f4');
    document.querySelectorAll('.appearance-select').forEach(select => { select.value = preference; });
    document.querySelectorAll('[data-art-light][data-art-dark]').forEach(img => {
      const source = dark ? img.dataset.artDark : img.dataset.artLight;
      if (img.getAttribute('src') !== source) img.src = source;
    });
  }
  // Runs before the stylesheet, so returning visitors do not see a light flash.
  apply(preference);
  system.addEventListener('change', () => { if (preference === 'system') apply(preference); });
  addEventListener('storage', event => { if (event.key === key || event.key === null) apply(event.newValue || 'system'); });
  document.addEventListener('DOMContentLoaded', () => {
    apply(preference);
    document.querySelectorAll('.appearance-select').forEach(select => {
      select.addEventListener('change', () => {
        apply(select.value);
        try { localStorage.setItem(key, preference); } catch (_) {}
      });
    });
  });
})();
