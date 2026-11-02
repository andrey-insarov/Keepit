#!/usr/bin/env python3
"""Render the Markdown pages in docs/ into docs/site/*.html with the keep.it.com shell.

  docs/GUIDE.md    → guide.html      docs/SECURITY.md → security.html
  docs/SUPPORT.md  → support.html    docs/PRIVACY.md  → privacy.html

Every screenshot is a 2× Retina capture; it is shown at half its pixel width so all of them share one
physical scale, and a click opens the full-size file in a lightbox. Pages with more than a few
headings get a sticky table of contents in a side column. Inline code that is only a key
combination (`⌃⌥1`, `⌥M`, `⌘V`) is rendered as a keycap.
"""
import re, pathlib, html, markdown
from PIL import Image

import datetime, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
site = root / "docs/site"
DATE = datetime.date.today().isoformat()

SITE = "https://keep.it.com/"

# (source, output, <title>, meta description, sidebar TOC?, schema.org type, breadcrumb label)
PAGES = [
    ("GUIDE.md", "guide.html", "Keepit User Guide – Clipboard Manager for Mac",
     "How to use Keepit, the free clipboard manager for Mac: clipboard history menu, hot keys, templates and placeholders, the Viewer, encryption and Touch ID, automation.", True, "TechArticle", "User guide"),
    ("SECURITY.md", "security.html", "Keepit Security – Encrypted Clipboard Manager for Mac",
     "What Keepit stores and where, how the clipboard history is encrypted (AES-256-GCM, Touch ID), which permissions it needs and why, and how to verify a download.", True, "TechArticle", "Security"),
    ("SUPPORT.md", "support.html", "Keepit Support",
     "How to get help with Keepit, the clipboard manager for Mac, and quick answers to the usual questions.", False, "WebPage", "Support"),
    ("PRIVACY.md", "privacy.html", "Keepit Privacy Policy",
     "Keepit's privacy policy: the app collects, transmits and shares nothing; everything stays on your Mac.", False, "WebPage", "Privacy policy"),
    ("CLIPBOARD-HISTORY-MAC.md", "clipboard-history-mac.html", "How to See Clipboard History on a Mac (2026)",
     "macOS keeps only the last thing you copied. Here is what Finder's Show Clipboard can do, and how to get a searchable clipboard history on your Mac with a free, open-source app.", False, "HowTo", "Clipboard history on a Mac"),
    ("PASTE-AS-PLAIN-TEXT-MAC.md", "paste-as-plain-text-mac.html", "How to Paste as Plain Text on a Mac",
     "The macOS shortcut for pasting without formatting (Paste and Match Style, ⌥⇧⌘V), how to remap it per app, and a one-key plain-text paste that works in every app.", False, "HowTo", "Paste as plain text on a Mac"),
    ("CLEAR-CLIPBOARD-MAC.md", "clear-clipboard-mac.html", "How to Clear the Clipboard on a Mac",
     "Ways to empty the macOS clipboard — copy an empty selection, pbcopy from Terminal — and how to clear or pause a clipboard history.", False, "HowTo", "Clear the clipboard on a Mac"),
]

HEADER = """<header><div class="wrap">
  <a class="brand" href="index.html"><img src="img/icon.png" alt="">Keepit</a>
  <nav><a href="index.html#features">Features</a><a href="guide.html">Guide</a><a href="security.html">Security</a><a href="support.html">Support</a><a class="gh" href="https://github.com/andrey-insarov/Keepit">GitHub</a></nav>
</div></header>"""

FOOTER = """<footer><div class="wrap">
  <span>© 2026 UK Intis Telecom LTD · Keepit is MIT-licensed</span>
  <span><a href="privacy.html">Privacy policy</a> · <a href="security.html">Security</a> · <a href="support.html">Support</a> · <a href="https://github.com/andrey-insarov/Keepit/blob/main/CHANGELOG.md">Changelog</a> · <a href="https://it.com">it.com</a></span>
</div></footer>"""

CSS = """
:root{--paper:#fbfbfd;--ink:#0f1222;--ink-2:#4b4f63;--ink-3:#8a8ea3;--blue:#2f4fd1;--blue-deep:#1f3aa6;--blue-tint:#eef2ff;--line:#e3e5ef;--key:#fff;--key-edge:#cfd2de;--win:#fff;--sel:#2f5cf0}
@media(prefers-color-scheme:dark){:root{--paper:#0c0d14;--ink:#f2f3f8;--ink-2:#b7bacb;--ink-3:#7c8097;--blue:#7d9bff;--blue-deep:#a9bdff;--blue-tint:#151b35;--line:#23263a;--key:#1b1e2e;--key-edge:#3a3e56;--win:#1a1c28;--sel:#3d6bff}}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:72px}
body{margin:0;background:var(--paper);color:var(--ink);-webkit-font-smoothing:antialiased;font:17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Helvetica,Arial,sans-serif}
a{color:var(--blue);text-decoration:none}a:hover{text-decoration:underline}
:focus-visible{outline:3px solid var(--sel);outline-offset:3px;border-radius:6px}
.wrap{max-width:1080px;margin:0 auto;padding:0 24px}
header{position:sticky;top:0;z-index:20;backdrop-filter:saturate(180%) blur(18px);background:color-mix(in srgb,var(--paper) 78%,transparent);border-bottom:1px solid var(--line)}
header .wrap{display:flex;align-items:center;justify-content:space-between;height:56px}
.brand{display:flex;align-items:center;gap:10px;font-weight:650;color:var(--ink);font-size:17px}.brand img{width:26px;height:26px;border-radius:6px}
nav{display:flex;gap:24px}nav a{color:var(--ink-2);font-size:15px}nav a:hover{color:var(--ink);text-decoration:none}
@media(max-width:700px){nav a:not(.gh){display:none}}
main.wrap{display:grid;grid-template-columns:230px minmax(0,1fr);gap:56px;padding-top:48px;padding-bottom:96px}
main.wrap.narrow{grid-template-columns:minmax(0,1fr);max-width:820px}
aside{position:sticky;top:76px;align-self:start;max-height:calc(100vh - 96px);overflow:auto;font-size:14px;line-height:1.45;padding-right:8px}
aside .ttl{font-weight:650;color:var(--ink);margin:0 0 10px;font-size:13px}
aside ol{list-style:none;margin:0;padding:0}aside li{margin:0}
aside a{display:block;color:var(--ink-2);padding:4px 0 4px 12px;border-left:2px solid var(--line)}
aside a:hover{color:var(--ink);text-decoration:none}aside a.on{color:var(--blue);border-left-color:var(--blue)}
aside ol ol a{padding-left:24px;font-size:13px;color:var(--ink-3)}
@media(max-width:900px){main.wrap{grid-template-columns:minmax(0,1fr);gap:0}aside{position:static;max-height:none;margin-bottom:32px;padding:16px 18px;border:1px solid var(--line);border-radius:14px;background:var(--win)}aside ol ol{display:none}}
article{max-width:72ch;min-width:0}
article h1{font-size:clamp(34px,5vw,52px);line-height:1.05;letter-spacing:-.03em;font-weight:750;margin:0 0 .5em}
article h1+p{font-size:19px;color:var(--ink-2)}
article h2{font-size:30px;line-height:1.15;letter-spacing:-.02em;font-weight:700;margin:2.2em 0 .6em;padding-top:1em;border-top:1px solid var(--line)}
article h3{font-size:20px;font-weight:650;margin:1.8em 0 .5em}
article p,article li{color:var(--ink);}article li{margin:.25em 0}
article hr{border:0;border-top:1px solid var(--line);margin:2.5em 0}
code{font:.9em ui-monospace,"SF Mono",Menlo,monospace;background:color-mix(in srgb,var(--ink) 7%,transparent);padding:2px 6px;border-radius:6px;white-space:nowrap}
pre{background:var(--blue-tint);padding:14px 18px;border-radius:12px;overflow:auto;font-size:14px;line-height:1.6;max-width:100%}pre code{background:none;padding:0;white-space:pre-wrap;word-break:break-word}
kbd.k{display:inline-block;min-width:1.7em;padding:0 .4em;text-align:center;font:600 .82em/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text",Helvetica,Arial,sans-serif;color:var(--ink);background:var(--key);border:1px solid var(--key-edge);border-bottom-width:2px;border-radius:6px;white-space:nowrap;vertical-align:baseline}
.tbl{overflow-x:auto;margin:1.2em 0}table{border-collapse:collapse;width:100%;font-size:15.5px}th,td{text-align:left;padding:9px 12px 9px 0;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--ink-3);font-weight:600;font-size:14px}td code{display:inline-block;margin:1px 0}
td:first-child{white-space:nowrap}@media(max-width:600px){td:first-child{white-space:normal}}
figure.shot{margin:1.6em 0;width:100%}figure.shot a{display:block}figure.shot img{display:block;width:100%;height:auto;border-radius:10px;border:1px solid var(--line);box-shadow:0 12px 32px -8px rgba(15,18,34,.25);cursor:zoom-in}
figure.shot figcaption{font-size:14px;color:var(--ink-3);margin-top:8px}
.slot{border:2px dashed var(--line);border-radius:12px;padding:28px;text-align:center;color:var(--ink-3);font-size:15px}
.contents{display:none}
.fb{margin:1.4em 0 2em;padding:22px 24px;border:1px solid var(--line);border-radius:16px;background:var(--win);display:grid;gap:14px}
.fb label{display:grid;gap:6px;font-size:14px;font-weight:600;color:var(--ink-2)}.fb .row2{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:600px){.fb .row2{grid-template-columns:1fr}}
.fb .hint{font-weight:400;color:var(--ink-3)}
.fb input[type=text],.fb input[type=email],.fb select,.fb textarea{font:16px/1.4 inherit;color:var(--ink);background:#fff;border:1px solid var(--line);border-radius:10px;padding:10px 12px;width:100%;box-sizing:border-box}
.fb textarea{resize:vertical;min-height:140px}.fb input:focus,.fb select:focus,.fb textarea:focus{outline:2px solid var(--blue);outline-offset:1px;border-color:transparent}
.fb input[type=file]{font-size:14px;color:var(--ink-2)}
.fb .btn{justify-self:start;display:inline-flex;align-items:center;padding:12px 22px;border-radius:12px;font-weight:600;font-size:16px;line-height:1;border:0;cursor:pointer;background:var(--blue);color:#fff}
.fb .btn[disabled]{opacity:.6;cursor:default}.fb-err{color:#c0392b;font-size:14px;margin:0}.fb-ok{color:var(--ink);font-weight:600;margin:0}
footer{border-top:1px solid var(--line);padding:36px 0 64px;color:var(--ink-3);font-size:14px}
footer .wrap{display:flex;flex-wrap:wrap;gap:12px 28px;justify-content:space-between}footer a{color:var(--ink-2)}
#lb{position:fixed;inset:0;background:rgba(5,7,20,.86);display:none;align-items:center;justify-content:center;padding:24px;z-index:30;cursor:zoom-out}
#lb.on{display:flex}#lb img{max-width:100%;max-height:100%;border-radius:8px;box-shadow:0 30px 80px rgba(0,0,0,.5)}
"""

JS = """
(function(){
  var lb=document.getElementById('lb'),im=lb.querySelector('img');
  document.querySelectorAll('a.zoom').forEach(function(a){a.addEventListener('click',function(e){e.preventDefault();im.src=a.getAttribute('href');im.alt=a.querySelector('img').alt;lb.classList.add('on');});});
  function close(){lb.classList.remove('on');im.src='';}
  lb.addEventListener('click',close);document.addEventListener('keydown',function(e){if(e.key==='Escape')close();});
  var links=[].slice.call(document.querySelectorAll('aside a')),heads=links.map(function(a){return document.getElementById(a.getAttribute('href').slice(1));});
  if(links.length&&'IntersectionObserver' in window){
    var cur=null;function mark(id){links.forEach(function(a){a.classList.toggle('on',a.getAttribute('href')==='#'+id);});}
    var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){cur=e.target.id;mark(cur);}});},{rootMargin:'-70px 0px -70% 0px'});
    heads.forEach(function(h){if(h)io.observe(h);});
  }
})();
"""

KEY_RE = re.compile(r"^[⌃⌥⌘⇧]{1,3}(?:[A-Z0-9⌫]|[1-9]|0)$|^[⌃⌥⌘⇧]$|^⌥[A-Z]$")


def file_hash(p) -> str:
    import hashlib
    try:
        return hashlib.sha1(p.read_bytes()).hexdigest()[:8]
    except OSError:
        return "0"


def figure(src: str, alt: str) -> str:
    path = src.replace("site/", "", 1)                # docs/*.md links are relative to docs/
    try:
        w, h = Image.open(site / path).size
    except OSError:
        w, h = 1200, 800
    css_w, css_h = w // 2, h // 2
    url = path + "?v=" + file_hash(site / path)      # content hash: a changed picture gets a new URL
    return (f'<figure class="shot" style="max-width:{css_w}px">'
            f'<a href="{url}" class="zoom" title="Open full size">'
            f'<img src="{url}" alt="{alt}" width="{css_w}" height="{css_h}" loading="lazy"></a>'
            f'<figcaption>{alt}</figcaption></figure>')


def keycaps(body: str) -> str:
    def rep(m):
        txt = html.unescape(m.group(1))
        return f'<kbd class="k">{m.group(1)}</kbd>' if KEY_RE.match(txt) else m.group(0)
    return re.sub(r"<code>([^<]{1,6})</code>", rep, body)


def toc_html(tokens, depth=0) -> str:
    if not tokens or depth > 1:
        return ""
    items = "".join(f'<li><a href="#{t["id"]}">{t["name"]}</a>{toc_html(t["children"], depth + 1)}</li>'
                    for t in tokens if t["level"] in (2, 3))
    return f"<ol>{items}</ol>" if items else ""


def json_ld(out_name: str, title: str, description: str, kind: str, crumb: str, headline: str) -> str:
    url = SITE + out_name
    crumbs = {"@type": "BreadcrumbList", "itemListElement": [
        {"@type": "ListItem", "position": 1, "name": "Keepit", "item": SITE},
        {"@type": "ListItem", "position": 2, "name": crumb, "item": url}]}
    page = {"@type": kind, "@id": url, "url": url, "name": headline, "headline": headline, "description": description,
            "inLanguage": "en", "isPartOf": {"@id": SITE + "#site"}, "about": {"@id": SITE + "#app"},
            "author": {"@id": SITE + "#org"}, "publisher": {"@id": SITE + "#org"},
            "image": SITE + "img/social-preview.png", "dateModified": DATE}
    import json
    return '<script type="application/ld+json">' + json.dumps({"@context": "https://schema.org", "@graph": [page, crumbs]}, ensure_ascii=False) + '</script>'


def modified(src_name: str) -> str:
    """Last commit date of the source file (today for files not committed yet)."""
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cs", "--", f"docs/{src_name}"], cwd=root, capture_output=True, text=True).stdout.strip()
        return out or DATE
    except OSError:
        return DATE


TURNSTILE_SITE_KEY = "1x00000000000000000000AA"   # public site key; the test key passes always — replace with the real one


def render(src_name: str, out_name: str, title: str, description: str, with_toc: bool, kind: str, crumb: str) -> None:
    global DATE
    DATE = modified(src_name)
    md_text = (root / "docs" / src_name).read_text(encoding="utf-8")
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc"])
    md_text = md_text.replace('__TURNSTILE_SITE_KEY__', TURNSTILE_SITE_KEY)
    body = md.convert(md_text)
    body = re.sub(r'<p><img alt="([^"]*)" src="([^"]+)"\s*/?></p>', lambda m: figure(m.group(2), m.group(1)), body)
    body = re.sub(r"<!-- screenshot: (.*?) -->", r'<p class="slot">Screenshot: \1</p>', body)
    body = re.sub(r"<p><strong>Contents</strong></p>\s*<ul>.*?</ul>\s*<hr\s*/?>", "", body, count=1, flags=re.S)
    body = keycaps(body)
    body = body.replace('<table>', '<div class="tbl"><table>').replace('</table>', '</table></div>')
    headline = tokens0 = (md.toc_tokens[0]["name"] if md.toc_tokens and md.toc_tokens[0]["level"] == 1 else title)
    tokens = [t for t in md.toc_tokens if t["level"] == 1]
    sections = tokens[0]["children"] if tokens else md.toc_tokens
    toc = toc_html(sections) if with_toc else ""
    aside = f'<aside aria-label="Contents"><p class="ttl">On this page</p>{toc}</aside>' if toc else ""
    main_cls = "wrap" if toc else "wrap narrow"
    page = (f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<title>{title}</title><link rel="icon" href="img/icon.png"><link rel="apple-touch-icon" href="img/icon.png">\n'
            f'<meta name="description" content="{description}">\n'
            f'<link rel="canonical" href="{SITE}{out_name}">'
            f'<meta property="og:type" content="article"><meta property="og:site_name" content="Keepit">'
            f'<meta property="og:title" content="{title}"><meta property="og:description" content="{description}">'
            f'<meta property="og:image" content="{SITE}img/social-preview.png"><meta property="og:url" content="{SITE}{out_name}">'
            f'<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{title}"><meta name="twitter:description" content="{description}"><meta name="twitter:image" content="{SITE}img/social-preview.png">'
            f'<meta name="theme-color" content="#fbfbfd" media="(prefers-color-scheme: light)"><meta name="theme-color" content="#0c0d14" media="(prefers-color-scheme: dark)">\n'
            f'{json_ld(out_name, title, description, kind, crumb, headline)}\n'
            f'<style>{CSS}</style></head>\n<body>{HEADER}\n<main class="{main_cls}">{aside}<article>{body}</article></main>\n{FOOTER}\n'
            f'<div id="lb" role="dialog" aria-label="Full-size screenshot"><img alt=""></div>\n'
            f'<script>{JS}</script>\n</body></html>')
    (site / out_name).write_text(page, encoding="utf-8")
    print(out_name, len(page), "bytes;", body.count('class="shot"'), "figures;", body.count('<kbd'), "keycaps")


def write_sitemap() -> None:
    urls = [("", "1.0", "weekly", modified("../docs/site/index.html"))] + [(p[1], "0.8" if p[5] != "WebPage" else "0.3", "monthly", modified(p[0])) for p in PAGES]
    body = "".join(f"<url><loc>{SITE}{u}</loc><lastmod>{d}</lastmod><changefreq>{f}</changefreq><priority>{pr}</priority></url>" for u, pr, f, d in urls)
    (site / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{body}</urlset>\n', encoding="utf-8")
    (site / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE}sitemap.xml\n", encoding="utf-8")


for p in PAGES:
    render(*p)
write_sitemap()
print("sitemap.xml, robots.txt")
