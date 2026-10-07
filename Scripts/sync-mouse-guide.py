#!/usr/bin/env python3
"""Bundle the same original mouse guide for offline viewing inside the Mac app."""
from pathlib import Path
import json,re,shutil
root=Path(__file__).resolve().parent.parent
out=root/'Sources/GlideMouse/Resources/MouseGuide';out.mkdir(exist_ok=True)
html=(root/'index.html').read_text()
start=html.index('<section id="mouse-guide"')
end=html.index('</section>',start)+len('</section>')
section=html[start:end]
translations=json.loads((root/'Site/translations.js').read_text().split('=',1)[1].strip().removesuffix(';'))
keys=set(re.findall(r'data-(?:copy|aria)="([^"]+)"',section))
subset={lang:{key:value for key,value in copy.items() if key.startswith('gesture') or key in keys} for lang,copy in translations.items()}
(out/'translations.js').write_text('window.glideCopy = '+json.dumps(subset,ensure_ascii=False,indent=2)+';\n')
for name in ['mouse-demo.css','mouse-demo.js']:shutil.copy2(root/'Site'/name,out/name)
(out/'guide.html').write_text('''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self'; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
<link rel="stylesheet" href="mouse-demo.css"><link rel="stylesheet" href="guide.css"><script src="translations.js" defer></script><script src="guide.js" defer></script><script src="mouse-demo.js" defer></script></head><body>'''+section+'''</body></html>''')
(out/'guide.css').write_text('''
:root{--paper:#f7faf9;--ink:#17323d;--blue:#0672d3;--mint:#b6e9d2;--slate:#58707b;--line:#dce6e6;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:var(--ink);background:var(--paper);font-synthesis:none;color-scheme:light}
*{box-sizing:border-box}body{margin:0;padding:22px;line-height:1.65}body:lang(my){font-family:'Myanmar Sangam MN','Noto Sans Myanmar',sans-serif;line-height:1.9}body:lang(zh-Hans){font-family:'PingFang SC',sans-serif}button{font:inherit;cursor:pointer;touch-action:manipulation}button:focus-visible{outline:3px solid var(--blue);outline-offset:3px}.gesture-guide{padding-top:0}.gesture-heading h2{font-size:24px}.gesture-heading p{font-size:14px}.gesture-note{font-size:12px}.gesture-layout{gap:20px}.gesture-modes{margin-bottom:18px}h3{line-height:1.5}
:root[data-theme=dark]{--paper:#172329;--ink:#e4eeee;--slate:#abc0c8;--line:#41565e;--blue:#6ab6f5;color-scheme:dark}
:root[data-theme=dark] .gesture-canvas,:root[data-theme=dark] .gesture-tools button,:root[data-theme=dark] .gesture-modes button[aria-pressed=true]{background:#21343e}
:root[data-theme=dark] .gesture-modes{background:#21343e}:root[data-theme=dark] .gesture-choices button:hover{background:#293f48}:root[data-theme=dark] .gesture-choices button[aria-pressed=true]{background:#254b65}
/* Keep input choices beside the result even in a 740-point native sheet. */
.gesture-heading h2{display:none}.gesture-heading{margin-bottom:12px}.gesture-heading+.gesture-note{display:none}
@media(min-width:700px){.gesture-layout{grid-template-columns:minmax(190px,.7fr) minmax(0,1.8fr)}.gesture-choices{grid-template-columns:1fr}.gesture-choices button{padding:8px 12px;min-height:60px}.gesture-choices button span{font-size:13px}.gesture-choices button small{font-size:11px}.gesture-caption{padding:14px 16px}.gesture-caption h3{font-size:17px}.gesture-caption p{font-size:13px}.gesture-stage{min-height:0}}
''')
(out/'guide.js').write_text('''
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
''')
print(out)
