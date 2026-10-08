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

const viewer=document.getElementById('screenshot-viewer');
const viewerImage=document.getElementById('viewer-image');
const closeButton=document.getElementById('viewer-close');
const zoomButton=document.getElementById('viewer-zoom');
let opener;
function zoomLabel(){
  const zoomed=viewer.dataset.zoomed==='true';
  zoomButton.textContent=document.documentElement.lang==='my'
    ? (zoomed?'ပြန်ချုံ့ရန်':'ချဲ့ရန်')
    : (zoomed?'Fit to window':'Zoom in');
  zoomButton.setAttribute('aria-pressed',String(zoomed));
}
document.querySelectorAll('.screenshot-open').forEach(link=>link.addEventListener('click',event=>{
  // Preserve the browser's modifier-click behavior and a direct-link fallback.
  if(event.ctrlKey||event.metaKey||event.shiftKey||event.altKey||typeof viewer.showModal!=='function')return;
  event.preventDefault();
  opener=link;
  const source=link.querySelector('img');
  viewerImage.src=link.href;
  viewerImage.alt=source.alt;
  viewerImage.width=Number(source.getAttribute('width'));
  viewerImage.height=Number(source.getAttribute('height'));
  viewerImage.style.setProperty('--zoom-width',String(viewerImage.width*2)+'px');
  viewer.dataset.zoomed='false';
  closeButton.textContent=document.documentElement.lang==='my'?'ပိတ်မည်':'Close';
  viewer.setAttribute('aria-label',document.documentElement.lang==='my'?'မျက်နှာပြင်ပုံကို အကျယ်ကြည့်ရန်':'Screenshot preview');
  zoomLabel();
  viewer.showModal();
  document.body.classList.add('viewer-open');
}));
closeButton.addEventListener('click',()=>viewer.close());
zoomButton.addEventListener('click',()=>{
  viewer.dataset.zoomed=String(viewer.dataset.zoomed!=='true');
  zoomLabel();
});
viewer.addEventListener('click',event=>{if(event.target===viewer)viewer.close()});
viewer.addEventListener('close',()=>{
  document.body.classList.remove('viewer-open');
  viewer.dataset.zoomed='false';
  opener?.focus({preventScroll:true});
});
