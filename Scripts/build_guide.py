#!/usr/bin/env python3
"""Render docs/GUIDE.md into docs/site/guide.html (run after editing the guide or its images).

Every screenshot is a 2× Retina capture; it is shown at half its pixel width so all of them share one
physical scale, and a click opens the full-size file in a lightbox.
"""
import re, pathlib, markdown
from PIL import Image

root = pathlib.Path(__file__).resolve().parent.parent
site = root / "docs/site"
md = (root / "docs/GUIDE.md").read_text(encoding="utf-8")
body = markdown.markdown(md, extensions=["tables", "fenced_code", "toc"])

def figure(m):
    src, alt = m.group(1), m.group(2)
    path = src.replace("site/", "", 1)                # docs/GUIDE.md links are relative to docs/
    try:
        w, h = Image.open(site / path).size
    except OSError:
        w, h = 1200, 800
    css_w = w // 2
    return (f'<figure class="shot" style="max-width:{css_w}px">'
            f'<a href="{path}" class="zoom" title="Open full size">'
            f'<img src="{path}" alt="{alt}" width="{css_w}" height="{h // 2}" loading="lazy"></a>'
            f'<figcaption>{alt}</figcaption></figure>')

body = re.sub(r'<p><img alt="(?P<alt>[^"]*)" src="(?P<src>[^"]+)"\s*/?></p>',
              lambda m: figure(type("M", (), {"group": lambda self, i: {1: m.group("src"), 2: m.group("alt")}[i]})()),
              body)
body = re.sub(r"<!-- screenshot: (.*?) -->", r'<p class="slot">Screenshot: \1</p>', body)

html = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>User guide — Keepit</title><link rel="icon" href="img/icon.png">
<meta name="description" content="How to use Keepit, the clipboard manager for macOS: history menu, hot keys, templates and placeholders, the Viewer, security, automation.">
<style>
:root{{color-scheme:light dark;--accent:#2F4FD1;--muted:#6b7280;--line:rgba(127,127,127,.25)}}
body{{font:17px/1.6 -apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;max-width:880px;margin:0 auto;padding:40px 24px 96px}}
h1{{font-size:40px;letter-spacing:-.5px;margin:.2em 0 .4em}}
h2{{font-size:30px;margin-top:2.4em;padding-top:.6em;border-top:1px solid var(--line)}}
h3{{font-size:21px;margin-top:1.8em}}
a{{color:var(--accent)}}
code{{font:.92em ui-monospace,SFMono-Regular,Menlo,monospace;background:rgba(127,127,127,.14);padding:1px 5px;border-radius:5px;white-space:nowrap}}
pre{{background:rgba(127,127,127,.12);padding:14px 18px;border-radius:12px;overflow:auto}}pre code{{background:none;padding:0;white-space:pre}}
table{{border-collapse:collapse;width:100%;margin:1em 0;font-size:15.5px}}th,td{{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}}th{{color:var(--muted);font-weight:600}}
hr{{border:0;border-top:1px solid var(--line);margin:2.5em 0}}
.shot{{margin:1.4em auto;width:100%}}.shot a{{display:block}}.shot img{{display:block;width:100%;height:auto;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.16);cursor:zoom-in}}
.shot figcaption{{font-size:14px;color:var(--muted);margin-top:8px;text-align:center}}
.slot{{border:2px dashed var(--line);border-radius:12px;padding:28px;text-align:center;color:var(--muted);font-size:15px}}
nav.top a{{margin-right:16px}}
#lb{{position:fixed;inset:0;background:rgba(0,0,0,.82);display:none;align-items:center;justify-content:center;padding:24px;z-index:10;cursor:zoom-out}}
#lb.on{{display:flex}}#lb img{{max-width:100%;max-height:100%;border-radius:8px;box-shadow:0 30px 80px rgba(0,0,0,.5)}}
</style></head>
<body><nav class="top"><a href="index.html">← keep.it.com</a><a href="support.html">Support</a><a href="https://github.com/andrey-insarov/Keepit">GitHub</a></nav>
{body}
<div id="lb" role="dialog" aria-label="Full-size screenshot"><img alt=""></div>
<script>
(function(){{
  var lb=document.getElementById('lb'),im=lb.querySelector('img');
  document.querySelectorAll('a.zoom').forEach(function(a){{a.addEventListener('click',function(e){{e.preventDefault();im.src=a.getAttribute('href');im.alt=a.querySelector('img').alt;lb.classList.add('on');}});}});
  function close(){{lb.classList.remove('on');im.src='';}}
  lb.addEventListener('click',close);document.addEventListener('keydown',function(e){{if(e.key==='Escape')close();}});
}})();
</script>
</body></html>"""
(site / "guide.html").write_text(html, encoding="utf-8")
print("docs/site/guide.html", len(html), "bytes;", body.count('class="shot"'), "figures")
