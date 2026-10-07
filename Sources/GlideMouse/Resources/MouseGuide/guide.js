
'use strict';
window.setGuidePreferences = function(language, theme) {
  document.documentElement.lang = ['en','my','zh-Hans'].includes(language) ? language : 'en';
  document.documentElement.dataset.theme = theme === 'dark' ? 'dark' : 'light';
  const copy = window.glideCopy[language === 'zh-Hans' ? 'zh' : document.documentElement.lang];
  document.querySelectorAll('[data-copy]').forEach(el => {el.textContent = copy[el.dataset.copy];});
  document.querySelectorAll('[data-aria]').forEach(el => {el.setAttribute('aria-label',copy[el.dataset.aria]);});
  window.dispatchEvent(new CustomEvent('glide:language'));
};
window.setGuidePreferences('en','light');
