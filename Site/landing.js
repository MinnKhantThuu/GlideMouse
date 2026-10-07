'use strict';
(() => {
  const copy = window.glideCopy;
  const readmes = {en:'README.md',my:'README_MM.md',zh:'Docs/USER_GUIDE_ZH.md'};
  let activeLanguage = 'en';
  function setLanguage(value, persist = false) {
    activeLanguage = Object.hasOwn(copy,value) ? value : 'en';
    document.documentElement.lang = activeLanguage === 'zh' ? 'zh-Hans' : activeLanguage;
    document.querySelectorAll('[data-copy]').forEach(element => { element.textContent = copy[activeLanguage][element.dataset.copy]; });
    if (activeLanguage === 'my') {
      const heading = document.querySelector('h1');
      const phrase = 'ပိုလွယ်လွယ်';
      const pieces = copy.my.heroTitle.split(phrase);
      const word = document.createElement('span'); word.className = 'keep-word'; word.textContent = phrase;
      heading.replaceChildren(document.createTextNode(pieces[0]),word,document.createTextNode(pieces[1]));
    }
    document.querySelectorAll('[data-aria]').forEach(element => {element.setAttribute('aria-label',copy[activeLanguage][element.dataset.aria]);});
    document.querySelectorAll('[data-alt]').forEach(element => {element.alt = copy[activeLanguage][element.dataset.alt];});
    document.querySelectorAll('[data-language]').forEach(button => button.setAttribute('aria-pressed',String(button.dataset.language === activeLanguage)));
    document.querySelectorAll('[data-screen]').forEach(image => {image.src = 'Docs/media/screenshots/'+activeLanguage+'-'+image.dataset.screen+'.png';});
    const videoLanguage = activeLanguage === 'my' ? 'my' : 'en';
    document.querySelectorAll('[data-tutorial]').forEach(link => {link.href = 'tutorials.html#'+videoLanguage+'-buttons';});
    document.querySelectorAll('[data-full-guide]').forEach(link => {link.href = 'tutorials.html#'+videoLanguage;});
    document.querySelector('[data-readme]').href = 'https://github.com/MinnKhantThuu/GlideMouse/blob/main/'+readmes[activeLanguage];
    document.title = {en:'GlideMouse — More from your mouse',my:'GlideMouse — Mouse ကို ပိုလွယ်လွယ် သုံးပါ',zh:'GlideMouse — 让鼠标更顺手'}[activeLanguage];
    window.dispatchEvent(new CustomEvent('glide:language'));
    if(persist) {
      const url = new URL(location.href); url.searchParams.set('lang',activeLanguage); history.replaceState(null,'',url);
      try {localStorage.setItem('glidemouse-site-language',activeLanguage);} catch (_) { /* Preference is optional. */ }
    }
  }
  let preference = 'en';
  try {preference = localStorage.getItem('glidemouse-site-language') || 'en';} catch (_) {}
  setLanguage(new URLSearchParams(location.search).get('lang') || preference);
  document.querySelectorAll('[data-language]').forEach(button => button.addEventListener('click',()=>setLanguage(button.dataset.language,true)));
})();
