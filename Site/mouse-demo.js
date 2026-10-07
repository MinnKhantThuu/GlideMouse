/* Original GlideMouse instructional drawings. No device input is intercepted. */
'use strict';
(() => {
  const root = document.getElementById('mouse-guide');
  if (!root) return;
  const stage = root.querySelector('.gesture-stage');
  const choices = root.querySelector('.gesture-choices');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const demos = {
    buttons: ['upper', 'lower', 'hold', 'double', 'wheel', 'horizontal'],
    touch: ['tap', 'righttap', 'multitap', 'triple', 'fingers', 'threefingers', 'oneswipe', 'swipe', 'threeswipe', 'pinch', 'drag', 'dragscroll', 'modifiers', 'resting']
  };
  const families = { taps: demos.touch.slice(0, 6), movement: demos.touch.slice(6, 10), dragging: demos.touch.slice(10, 12), extras: demos.touch.slice(12) };
  const poses = {triple: 'multitap', threefingers: 'fingers', oneswipe: 'oneswipe', threeswipe: 'threeswipe', drag: 'drag', dragscroll: 'dragscroll', modifiers: 'modifiers', resting: 'resting'};
  let family = 'taps';
  let mode = 'buttons', selected = 'upper', visible = false;
  const language = () => document.documentElement.lang === 'zh-Hans' ? 'zh' : document.documentElement.lang;
  const t = key => window.glideCopy[language() || 'en'][key];
  const key = (name, suffix) => 'gesture' + name[0].toUpperCase() + name.slice(1) + suffix;
  function updateMotion() {
    root.dataset.paused = String(reducedMotion.matches || !visible || document.hidden);
    root.dataset.reduced = String(reducedMotion.matches);
  }
  function select(name, announce = true) {
    selected = name;
    stage.dataset.gesture = name; stage.dataset.pose = poses[name] || name;
    stage.classList.remove('is-running');
    // Restart the illustration's CSS timeline without recording any real input.
    void stage.offsetWidth;
    stage.classList.add('is-running');
    root.querySelector('[data-gesture-title]').textContent = t(key(name, 'Title'));
    root.querySelector('[data-gesture-result]').textContent = t(key(name, 'Result'));
    root.querySelector('[data-gesture-description]').textContent = t(key(name, 'Body'));
    choices.querySelectorAll('button').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.gesture === name)));
    if (announce) root.querySelector('[data-gesture-status]').textContent = t(key(name, 'Title')) + '. ' + t(key(name, 'Result'));
  }
  function render() {
    root.dataset.mode = mode;
    root.querySelectorAll('[data-gesture-mode]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.gestureMode === mode)));
    root.querySelector('[data-touch-families]').hidden = mode !== 'touch';
    root.querySelectorAll('[data-gesture-family]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.gestureFamily === family)));
    const items = mode === 'touch' ? families[family] : demos.buttons;
    choices.replaceChildren(...items.map(name => {
      const button = document.createElement('button');
      button.type = 'button'; button.dataset.gesture = name;
      const title = document.createElement('span'); title.textContent = t(key(name, 'Title'));
      const result = document.createElement('small'); result.textContent = t(key(name, 'Result'));
      button.append(title, result); button.addEventListener('click', () => select(name));
      return button;
    }));
    root.querySelector('[data-gesture-note]').textContent = t(mode === 'touch' ? 'gestureTouchNote' : 'gestureButtonNote');
    select(selected, false); updateMotion();
  }
  root.querySelectorAll('[data-gesture-mode]').forEach(button => button.addEventListener('click', () => {
    mode = button.dataset.gestureMode; family = 'taps'; selected = demos[mode][0]; render();
  }));
  root.querySelectorAll('[data-gesture-family]').forEach(button => button.addEventListener('click', () => {
    family = button.dataset.gestureFamily; selected = families[family][0]; render();
  }));
  window.showMagicMouseGuide = () => { mode = 'touch'; family = 'taps'; selected = 'tap'; render(); };
  reducedMotion.addEventListener('change', updateMotion);
  document.addEventListener('visibilitychange', updateMotion);
  window.addEventListener('glide:language', render);
  const observer = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; updateMotion(); }, {threshold: 0.15});
  observer.observe(stage);
  render();
})();
