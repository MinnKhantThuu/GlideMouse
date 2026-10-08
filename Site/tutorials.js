function followHash(){
  const hash=location.hash.slice(1);
  const lang=hash==='my'||hash.startsWith('my-')?'my':'en';
  document.documentElement.lang=lang;
  document.querySelectorAll('.language').forEach(section=>section.hidden=section.id!==lang);
  document.querySelectorAll('[data-lang]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.lang===lang)));
  const target=document.getElementById(hash);
  if(target)target.scrollIntoView({block:'start',behavior:'instant'});
}
document.querySelectorAll('[data-lang]').forEach(button=>button.addEventListener('click',()=>{
  const chapter=location.hash.match(/^#(?:en|my)-(setup|buttons|profiles|scrolling|shortcuts)$/)?.[1];
  location.hash=button.dataset.lang+(chapter?'-'+chapter:'');
}));
window.addEventListener('hashchange',followHash);
followHash();
