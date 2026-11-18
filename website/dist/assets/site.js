'use strict';

const filter = document.getElementById('scene-filter');
const gallery = document.getElementById('scene-grid');
const galleryStatus = document.getElementById('gallery-status');

if (filter && gallery && galleryStatus) {
  const buttons = [...filter.querySelectorAll('button[data-filter]')];
  const scenes = [...gallery.querySelectorAll('[data-collection]')];
  filter.addEventListener('click', event => {
    const button = event.target.closest('button[data-filter]');
    if (!button || !buttons.includes(button)) return;
    const selected = button.dataset.filter;
    let visible = 0;
    for (const scene of scenes) {
      scene.hidden = selected !== 'all' && scene.dataset.collection !== selected;
      if (!scene.hidden) visible += 1;
    }
    for (const choice of buttons) {
      choice.setAttribute('aria-pressed', String(choice === button));
    }
    gallery.dataset.view = selected;
    galleryStatus.textContent = visible + (visible === 1 ? ' photo shown.' : ' photos shown.');
  });
  filter.hidden = false;
}

if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-in-view');
        observer.unobserve(entry.target);
      }
    }
  }, {threshold: 0.08});
  document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
}
