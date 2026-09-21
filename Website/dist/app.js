'use strict';
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const preference = matchMedia('(prefers-reduced-motion: reduce)');
let reduced = preference.matches;
let scheduled = 0;
let flowVisible = false;
let heroVisible = true;
const flow = $('.flow');
const hero = $('.hero');
const steps = $$('.flow-step');
const scenes = $$('.scene');
const clamp = (n, min = 0, max = 1) => Math.min(max, Math.max(min, n));
function draw() {
  scheduled = 0;
  if (reduced || document.hidden) return;
  if (heroVisible) hero.style.setProperty('--hero', clamp(scrollY / 560));
  if (!flowVisible) return;
  const r = flow.getBoundingClientRect();
  const p = clamp(-r.top / Math.max(1, r.height - innerHeight));
  flow.style.setProperty('--progress', Math.max(.015, p));
  const stage = clamp(p * 2.7 - .18, 0, 2);
  const current = Math.min(2, Math.round(stage));
  $('.flow-count').textContent = `0${current + 1} — 03`;
  steps.forEach((el, i) => {
    const distance = Math.abs(stage - i);
    el.style.opacity = clamp(1 - distance * 1.6);
    el.style.transform = `translateY(${(i - stage) * 22}px)`;
    el.setAttribute('aria-hidden', String(i !== current));
  });
  scenes.forEach((el, i) => {
    el.style.opacity = i === 0 ? 1 : clamp(stage - i + 1);
    el.setAttribute('aria-hidden', String(i !== current));
  });
  $('.flow-device').style.transform = innerWidth > 700
    ? `perspective(1200px) rotateY(${-5 + p * 5}deg) scale(${.96 + p * .04})`
    : `scale(${.96 + p * .04})`;
}
function schedule() { if (!scheduled && !reduced && !document.hidden) scheduled = requestAnimationFrame(draw); }
function setMotion(value) {
  reduced = value;
  document.body.classList.toggle('reduced', reduced);
  document.documentElement.classList.toggle('reduced-motion', reduced);
  document.documentElement.classList.toggle('js-motion', !reduced);
  $('.motion-toggle').setAttribute('aria-pressed', String(reduced));
  $('.motion-toggle').textContent = reduced ? '启用动效' : '减少动效';
  steps.forEach(el => { if (reduced) el.removeAttribute('aria-hidden'); });
  if (reduced && scheduled) { cancelAnimationFrame(scheduled); scheduled = 0; }
  schedule();
}
$('.motion-toggle').addEventListener('click', () => setMotion(!reduced));
preference.addEventListener('change', e => setMotion(e.matches));
setMotion(reduced);
addEventListener('scroll', schedule, {passive:true});
addEventListener('resize', schedule, {passive:true});
document.addEventListener('visibilitychange', schedule);
const watcher = new IntersectionObserver(entries => {
  for (const entry of entries) {
    if (entry.target === flow) flowVisible = entry.isIntersecting;
    else if (entry.target === hero) heroVisible = entry.isIntersecting;
    else if (entry.isIntersecting) { entry.target.classList.add('visible'); watcher.unobserve(entry.target); }
  }
  schedule();
}, {rootMargin:'100px', threshold:0});
watcher.observe(flow); watcher.observe(hero); $$('.reveal').forEach(el => watcher.observe(el));
let device = 'tablet', dark = false, loadId = 0;
function changePreview() {
  const id = ++loadId;
  const image = new Image();
  const src = `assets/${device}${dark ? '-dark' : ''}.webp`;
  image.onload = () => {
    if (id !== loadId) return;
    const target = $('#canvas-image');
    target.src = src;
    target.width = image.naturalWidth;
    target.height = image.naturalHeight;
    target.alt = `${device === 'phone' ? '手机' : '平板'}${dark ? '深色' : '浅色'}外观`;
    $('.canvas-stage').dataset.device = device;
    $$('[data-device][type=button]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.device === device)));
    $('.theme-toggle').setAttribute('aria-pressed', String(dark));
    if (!reduced) target.animate([{opacity:.45},{opacity:1}], {duration:350,easing:'ease-out'});
  };
  image.src = src;
}
$$('[data-device][type=button]').forEach(button => button.addEventListener('click', () => { device = button.dataset.device; changePreview(); }));
$('.theme-toggle').addEventListener('click', () => { dark = !dark; changePreview(); });
