#!/usr/bin/env python3
"""Render the Markdown pages in docs/ into docs/site/*.html with the keep.it.com shell.

  docs/GUIDE.md    → guide.html      docs/SECURITY.md → security.html
  docs/SUPPORT.md  → support.html    docs/PRIVACY.md  → privacy.html

Every screenshot is a 2× Retina capture; it is shown at half its pixel width so all of them share one
physical scale, and a click opens the full-size file in a lightbox. Pages with more than a few
headings get a sticky table of contents in a side column. Inline code that is only a key
combination (`⌃⌥1`, `⌥M`, `⌘V`) is rendered as a keycap.

Translations (docs/i18n/<lang>/): the landing, the guide and support exist in the languages listed
in LANGS; privacy, security and the how-tos stay English. For each language:

  site.json     the shell's words (navigation, footer, "On this page"…), and the <title>,
                description and breadcrumb of the translated pages
  landing.json  [English fragment, translation] pairs applied to docs/site/index.html in order;
                a fragment that is no longer in the English page is reported and left English
  GUIDE.md,     the translated Markdown; its first line names the English file's blob it was
  SUPPORT.md    translated from (<!-- source: GUIDE.md <git blob sha> -->) and the build warns
                when the English file has changed since. Headings keep the English page's ids
                (by position), so /ru/guide#backup and /guide#backup are the same section.

Output: docs/site/<slug>/index.html, guide.html, support.html → keep.it.com/<slug>/, /<slug>/guide…
A screenshot img/guide/<slug>/x.png, if present, replaces img/guide/x.png on that language's pages.
"""
import re, pathlib, html, json, markdown
import markdown.extensions.toc
from PIL import Image

import datetime, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
site = root / "docs/site"
i18n = root / "docs/i18n"
DATE = datetime.date.today().isoformat()

SITE = "https://keep.it.com/"

# Languages of the site, in switcher order. slug = URL folder (lowercase); hreflang = BCP 47 tag.
LANGS = [
    # code      slug       hreflang   native name            og:locale  direction
    ("en",      "",        "en",      "English",             "en_US",   "ltr"),
    ("ru",      "ru",      "ru",      "Русский",             "ru_RU",   "ltr"),
    ("uk",      "uk",      "uk",      "Українська",          "uk_UA",   "ltr"),
    ("de",      "de",      "de",      "Deutsch",             "de_DE",   "ltr"),
    ("fr",      "fr",      "fr",      "Français",            "fr_FR",   "ltr"),
    ("es",      "es",      "es",      "Español",             "es_ES",   "ltr"),
    ("pt-BR",   "pt-br",   "pt-BR",   "Português (Brasil)",  "pt_BR",   "ltr"),
    ("ja",      "ja",      "ja",      "日本語",               "ja_JP",   "ltr"),
    ("zh-Hans", "zh-hans", "zh-Hans", "简体中文",             "zh_CN",   "ltr"),
    ("ar",      "ar",      "ar",      "العربية",              "ar_AR",   "rtl"),
]
LANG = {l[0]: dict(code=l[0], slug=l[1], hreflang=l[2], name=l[3], og=l[4], dir=l[5]) for l in LANGS}
TRANSLATED = {"GUIDE.md": "guide.html", "SUPPORT.md": "support.html"}   # + the landing


def active_langs() -> list:
    """English plus every language that has a site.json."""
    return ["en"] + [c for c, *_ in LANGS[1:] if (i18n / c / "site.json").exists()]


def prefix(lang: str) -> str:
    return "/" + LANG[lang]["slug"] if lang != "en" else ""


def page_url(out_name: str, lang: str = "en") -> str:
    """Public URL of a rendered page. Cloudflare Pages serves guide.html at /guide and redirects
    /guide.html there (308), so canonical, sitemap, JSON-LD and every internal link use the
    extensionless form; the files on disk keep their .html names."""
    name = "" if out_name == "index.html" else out_name.removesuffix(".html")
    return SITE + (LANG[lang]["slug"] + "/" if lang != "en" else "") + name

# (source, output, <title>, meta description, sidebar TOC?, schema.org type, breadcrumb label)
PAGES = [
    ("GUIDE.md", "guide.html", "Keepit User Guide – Clipboard Manager for Mac",
     "How to use Keepit, the free clipboard manager for Mac: the history menu, hot keys, templates and placeholders, the Viewer, encryption and Touch ID.", True, "TechArticle", "User guide"),
    ("SECURITY.md", "security.html", "Keepit Security – Encrypted Clipboard Manager for Mac",
     "What Keepit stores and where, how the history is encrypted (AES-256-GCM, Touch ID), which permissions it needs and why, and how to verify a download.", True, "TechArticle", "Security"),
    ("SUPPORT.md", "support.html", "Keepit Support – Help with the Mac Clipboard Manager",
     "How to get help with Keepit, the clipboard manager for Mac, and quick answers to the usual questions.", False, "WebPage", "Support"),
    ("PRIVACY.md", "privacy.html", "Keepit Privacy Policy",
     "Keepit's privacy policy: the app collects and shares nothing. No account, no Keepit server; optional backups go encrypted to a folder you choose.", False, "WebPage", "Privacy policy"),
    ("CLIPBOARD-HISTORY-MAC.md", "clipboard-history-mac.html", "How to See Clipboard History on a Mac (2026)",
     "macOS 26 keeps a short clipboard history in Spotlight (⌘Space, ⌘4); older versions keep one item. How to open it and get a full, searchable history.", False, "HowTo", "Clipboard history on a Mac"),
    ("PASTE-AS-PLAIN-TEXT-MAC.md", "paste-as-plain-text-mac.html", "How to Paste as Plain Text on a Mac",
     "The Mac shortcut for pasting without formatting (⌥⇧⌘V), how to remap it per app, and a one-key plain-text paste that works in every app.", False, "HowTo", "Paste as plain text on a Mac"),
    ("CLEAR-CLIPBOARD-MAC.md", "clear-clipboard-mac.html", "How to Clear the Clipboard on a Mac",
     "Three things to clear on a Mac: the system clipboard (pbcopy in Terminal), Spotlight's clipboard history in macOS 26, and a clipboard manager's history.", False, "HowTo", "Clear the clipboard on a Mac"),
]

# The shell's words in English; a language's site.json "ui" overrides them key by key.
UI_EN = {
    "features": "Features", "privacy": "Privacy", "install": "Install", "guide": "Guide",
    "security": "Security", "support": "Support", "menu": "Menu",
    "copyright": "© 2026 UK Intis Telecom LTD · Keepit is MIT-licensed",
    "privacy_policy": "Privacy policy", "changelog": "Changelog",
    "on_this_page": "On this page", "contents": "Contents",
    "open_full_size": "Open full size", "full_size_screenshot": "Full-size screenshot",
    "language": "Language", "in_english": "",
    "translated_note": "",   # e.g. "Translated from English. <a href=\"{en}\">Original</a>."
}


def load_site(lang: str) -> dict:
    if lang == "en":
        return {"ui": dict(UI_EN), "pages": {}}
    data = json.loads((i18n / lang / "site.json").read_text(encoding="utf-8"))
    ui = dict(UI_EN)
    ui.update(data.get("ui", {}))
    data["ui"] = ui
    return data


def en_only(ui: dict) -> str:
    """Marker after a link to a page that exists only in English (" (in English)")."""
    return f'<span class="en-only"> {ui["in_english"]}</span>' if ui["in_english"] else ""


def localize_links(fragment: str, lang: str) -> str:
    """Links to the landing, the guide and support point to this language's copies; everything
    else (security, privacy, how-tos, v2, external) stays as it is."""
    if lang == "en":
        return fragment
    p = prefix(lang)
    fragment = re.sub(r'href="/(guide|support)(#[^"]*)?"', lambda m: f'href="{p}/{m.group(1)}{m.group(2) or ""}"', fragment)
    fragment = re.sub(r'href="/(#[^"]*)?"', lambda m: f'href="{p}/{m.group(1) or ""}"', fragment)
    return fragment


# One flag per language for the picker in the header. A flag stands for a country, not a language,
# so these are the conventional choices; the native name beside it in the list is what identifies it.
# Drawn as SVG (viewBox 20×14) so they look the same everywhere: Windows has no flag emoji.
# At 22 px wide they are simplified: no coat of arms for Spain, a plain band for Brazil's motto,
# strokes standing for the inscription and the sword for Saudi Arabia.
def _star(cx: float, cy: float, r: float, rot: float = -90) -> str:
    import math
    pts = []
    for i in range(10):
        a = math.radians(rot + i * 36)
        rr = r if i % 2 == 0 else r * 0.382
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return f'<polygon fill="#ffde00" points="{" ".join(pts)}"/>'


FLAG = {
    "en": '<path fill="#012169" d="M0 0h20v14H0z"/><path stroke="#fff" stroke-width="2.8" d="m0 0 20 14M20 0 0 14"/>'
          '<path stroke="#c8102e" stroke-width="1" d="m0 0 20 14M20 0 0 14"/><path stroke="#fff" stroke-width="4.6" d="M10 0v14M0 7h20"/>'
          '<path stroke="#c8102e" stroke-width="2.6" d="M10 0v14M0 7h20"/>',
    "ru": '<path fill="#fff" d="M0 0h20v14H0z"/><path fill="#0039a6" d="M0 4.67h20V14H0z"/><path fill="#d52b1e" d="M0 9.33h20V14H0z"/>',
    "uk": '<path fill="#0057b7" d="M0 0h20v14H0z"/><path fill="#ffd700" d="M0 7h20v7H0z"/>',
    "de": '<path d="M0 0h20v14H0z"/><path fill="#d00" d="M0 4.67h20V14H0z"/><path fill="#ffce00" d="M0 9.33h20V14H0z"/>',
    "fr": '<path fill="#fff" d="M0 0h20v14H0z"/><path fill="#0055a4" d="M0 0h6.67v14H0z"/><path fill="#ef4135" d="M13.33 0H20v14h-6.67z"/>',
    "es": '<path fill="#aa151b" d="M0 0h20v14H0z"/><path fill="#f1bf00" d="M0 3.5h20v7H0z"/>',
    "pt-BR": '<path fill="#009c3b" d="M0 0h20v14H0z"/><path fill="#ffdf00" d="M10 1.6 18 7l-8 5.4L2 7z"/><circle cx="10" cy="7" r="3.1" fill="#002776"/>'
             '<path fill="none" stroke="#fff" stroke-width=".7" d="M7.1 6.2c2-.5 4.3.1 5.8 1.6"/>',
    "ja": '<path fill="#fff" d="M0 0h20v14H0z"/><circle cx="10" cy="7" r="4.2" fill="#bc002d"/>',
    "zh-Hans": '<path fill="#de2910" d="M0 0h20v14H0z"/>' + _star(3.5, 3.6, 2.2) + _star(7, 1.5, .75, -60) + _star(8.4, 2.9, .75, -30)
               + _star(8.4, 5, .75, 0) + _star(7, 6.4, .75, 30),
    "ar": '<path fill="#006c35" d="M0 0h20v14H0z"/><path fill="none" stroke="#fff" stroke-linecap="round" stroke-width=".9" '
          'd="M5 4.2h3.2M9.4 4.2h1.4M12 4.2h3M5.6 6.1h2.2M9 6.1h5.6M6.2 8h7.6"/>'
          '<path fill="none" stroke="#fff" stroke-linecap="round" stroke-width=".8" d="M5.2 10.4h9.2M14.4 10.4l.9-.5M5.2 9.9v1"/>',
}


def flag_svg(code: str) -> str:
    return f'<svg class="fl" viewBox="0 0 20 14" aria-hidden="true">{FLAG.get(code, "")}</svg>'


def langpick_html(lang: str, ui: dict, page: str | None) -> str:
    """The language picker in the header: the current flag, and a list of flag + native name
    linking to the same page in every active language. Empty for pages that exist in English only."""
    if not page or len(active_langs()) < 2:
        return ""
    items = []
    for code in active_langs():
        h, name = LANG[code]["hreflang"], LANG[code]["name"]
        label = f'{flag_svg(code)}<span lang="{h}">{name}</span>'
        if code == lang:
            items.append(f'<b aria-current="true">{label}</b>')
        else:
            href = page_url(page, code).removeprefix(SITE.rstrip("/"))
            items.append(f'<a href="{href}" hreflang="{h}">{label}</a>')
    return (f'<details class="lpick"><summary aria-label="{ui["language"]}: {LANG[lang]["name"]}">'
            f'{flag_svg(lang)}'
            '<svg class="chev" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 4.5 6 8l3.5-3.5"/></svg>'
            f'</summary><div class="links" dir="ltr">{"".join(items)}</div></details>')


def header_html(lang: str, ui: dict, page: str | None = None) -> str:
    h = f"""<header><div class="wrap">
  <a class="brand" href="/"><img src="/img/icon.png?v=a1519b94" alt="">Keepit</a>
  <nav><a href="/#features">{ui['features']}</a><a href="/guide">{ui['guide']}</a><a href="/security">{ui['security']}</a><a href="/support">{ui['support']}</a><a class="gh" href="https://github.com/andrey-insarov/Keepit">GitHub</a>__LPICK__<details class="mnav"><summary aria-label="{ui['menu']}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg></summary><div class="links"><a href="/#features">{ui['features']}</a><a href="/#privacy">{ui['privacy']}</a><a href="/#install">{ui['install']}</a><a href="/guide">{ui['guide']}</a><a href="/security">{ui['security']}</a><a href="/support">{ui['support']}</a></div></details></nav>
</div></header>"""
    # the picker goes in after localize_links: its links point at other languages on purpose
    return localize_links(h, lang).replace("__LPICK__", langpick_html(lang, ui, page))


def switcher_html(lang: str, page: str) -> str:
    """Language links to the same page in every active language (page: index.html, guide.html…)."""
    items = []
    for code in active_langs():
        name = LANG[code]["name"]
        if code == lang:
            items.append(f'<b lang="{LANG[code]["hreflang"]}">{name}</b>')
        else:
            href = page_url(page, code).removeprefix(SITE.rstrip("/"))
            items.append(f'<a href="{href}" lang="{LANG[code]["hreflang"]}" hreflang="{LANG[code]["hreflang"]}">{name}</a>')
    return '<span class="langs">' + " · ".join(items) + "</span>" if len(items) > 1 else ""


def footer_html(lang: str, ui: dict, page: str | None) -> str:
    eo = en_only(ui)
    langs = switcher_html(lang, page) if page else ""
    f = f"""<footer><div class="wrap">
  <span>{ui['copyright']}</span>
  <span><a href="/privacy">{ui['privacy_policy']}</a>{eo} · <a href="/security">{ui['security']}</a>{eo} · <a href="/support">{ui['support']}</a> · <a href="https://github.com/andrey-insarov/Keepit/blob/main/CHANGELOG.md">{ui['changelog']}</a> · <a href="https://it.com">it.com</a></span>
__LANGS__</div></footer>"""
    # the language links go in after localize_links: they point at other languages on purpose
    return localize_links(f, lang).replace("__LANGS__", "  " + langs + "\n" if langs else "")


def alternates_html(page: str) -> str:
    """hreflang links for a page that exists in several languages; x-default is English."""
    langs = active_langs()
    if len(langs) < 2:
        return ""
    links = [f'<link rel="alternate" hreflang="{LANG[c]["hreflang"]}" href="{page_url(page, c)}">' for c in langs]
    links.append(f'<link rel="alternate" hreflang="x-default" href="{page_url(page, "en")}">')
    return "".join(links)


CSS = """
:root{--paper:#fbfbfd;--ink:#0f1222;--ink-2:#4b4f63;--ink-3:#696d84;--blue:#2f4fd1;--blue-deep:#1f3aa6;--blue-tint:#eef2ff;--line:#e3e5ef;--key:#fff;--key-edge:#cfd2de;--win:#fff;--sel:#2f5cf0}
@media(prefers-color-scheme:dark){:root{--paper:#0c0d14;--ink:#f2f3f8;--ink-2:#b7bacb;--ink-3:#8e92a9;--blue:#7d9bff;--blue-deep:#a9bdff;--blue-tint:#151b35;--line:#23263a;--key:#1b1e2e;--key-edge:#3a3e56;--win:#1a1c28;--sel:#3d6bff}}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:72px;-webkit-text-size-adjust:100%}
body{margin:0;background:var(--paper);color:var(--ink);-webkit-font-smoothing:antialiased;font:17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Helvetica,Arial,sans-serif}
a{color:var(--blue);text-decoration:none}a:hover{text-decoration:underline}
:focus-visible{outline:3px solid var(--sel);outline-offset:3px;border-radius:6px}
.wrap{max-width:1080px;margin:0 auto;padding:0 24px}
header{position:sticky;top:0;z-index:20;-webkit-backdrop-filter:saturate(180%) blur(18px);backdrop-filter:saturate(180%) blur(18px);background:color-mix(in srgb,var(--paper) 78%,transparent);border-bottom:1px solid var(--line)}
header .wrap{display:flex;align-items:center;justify-content:space-between;height:56px}
.brand{display:flex;align-items:center;gap:12px;font-weight:650;color:var(--ink);font-size:20px}.brand img{width:44px;height:44px;border-radius:10px}
nav{display:flex;gap:24px;align-items:center}nav>a{color:var(--ink-2);font-size:15px}nav>a:hover{color:var(--ink);text-decoration:none}
.mnav{display:none;position:relative}.mnav summary{list-style:none;cursor:pointer;width:40px;height:40px;display:flex;align-items:center;justify-content:center;border-radius:10px;color:var(--ink)}
.mnav summary::-webkit-details-marker{display:none}.mnav summary svg{width:22px;height:22px}.mnav[open] summary{background:color-mix(in srgb,var(--ink) 8%,transparent)}
.mnav .links{position:absolute;right:0;top:48px;min-width:210px;padding:6px;border-radius:14px;background:var(--win);border:1px solid var(--line);box-shadow:0 20px 50px rgba(0,0,0,.18);display:grid}
.mnav .links a{display:block;padding:11px 14px;border-radius:9px;font-size:16px;color:var(--ink)}.mnav .links a:hover{background:var(--blue-tint);text-decoration:none}
@media(max-width:700px){nav{gap:10px}nav>a:not(.gh){display:none}.mnav{display:block;margin-right:-8px}}
main.wrap{display:grid;grid-template-columns:230px minmax(0,1fr);gap:56px;padding-top:48px;padding-bottom:96px}
main.wrap.narrow{grid-template-columns:minmax(0,1fr);max-width:820px}
aside{position:sticky;top:76px;align-self:start;max-height:calc(100vh - 96px);overflow:auto;font-size:14px;line-height:1.45;padding-right:8px}
aside .ttl{font-weight:650;color:var(--ink);margin:0 0 10px;font-size:13px}
aside ol{list-style:none;margin:0;padding:0}aside li{margin:0}
aside a{display:block;color:var(--ink-2);padding:4px 0 4px 12px;border-left:2px solid var(--line)}
aside a:hover{color:var(--ink);text-decoration:none}aside a.on{color:var(--blue);border-left-color:var(--blue)}
aside ol ol a{padding-left:24px;font-size:13px;color:var(--ink-3)}
@media(max-width:900px){main.wrap{grid-template-columns:minmax(0,1fr);gap:0;padding-top:32px;padding-bottom:64px}aside{position:static;max-height:none;margin-bottom:32px;padding:16px 18px;border:1px solid var(--line);border-radius:14px;background:var(--win)}aside ol ol{display:none}}
article{max-width:72ch;min-width:0}
article h1{font-size:clamp(34px,5vw,52px);line-height:1.05;letter-spacing:-.03em;font-weight:750;margin:0 0 .5em}
article h1+p{font-size:19px;color:var(--ink-2)}
article h2{font-size:30px;line-height:1.15;letter-spacing:-.02em;font-weight:700;margin:2.2em 0 .6em;padding-top:1em;border-top:1px solid var(--line)}
article h3{font-size:20px;font-weight:650;margin:1.8em 0 .5em}
article p,article li{color:var(--ink);}article li{margin:.25em 0}
article hr{border:0;border-top:1px solid var(--line);margin:2.5em 0}
code{font:.9em ui-monospace,"SF Mono",Menlo,monospace;background:color-mix(in srgb,var(--ink) 7%,transparent);padding:2px 6px;border-radius:6px;white-space:nowrap}
@media(max-width:600px){code{white-space:normal;overflow-wrap:anywhere}}
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
.fb input[type=text],.fb input[type=email],.fb select,.fb textarea{font:16px/1.4 inherit;color:var(--ink);background:var(--win);border:1px solid var(--line);border-radius:10px;padding:10px 12px;width:100%;box-sizing:border-box}
.fb textarea{resize:vertical;min-height:140px}.fb input:focus,.fb select:focus,.fb textarea:focus{outline:2px solid var(--blue);outline-offset:1px;border-color:transparent}
.fb input[type=file]{font-size:14px;color:var(--ink-2)}
.fb-list{list-style:none;margin:-6px 0 0;padding:0;display:grid;gap:6px}.fb-list li{font-size:14px;color:var(--ink-2);display:flex;align-items:center;gap:10px}.fb-list button{font:inherit;font-size:13px;color:var(--blue);background:none;border:0;padding:0;cursor:pointer}.fb-list button:hover{text-decoration:underline}
.fb .btn{justify-self:start;display:inline-flex;align-items:center;padding:12px 22px;border-radius:12px;font-weight:600;font-size:16px;line-height:1;border:0;cursor:pointer;background:var(--blue);color:#fff}
.fb .btn[disabled]{opacity:.6;cursor:default}.fb-err{color:#c0392b;font-size:14px;margin:0}.fb-legal{font-size:13px;margin:-6px 0 0}.fb-ok{color:var(--ink);margin:0;padding:18px 20px;border-radius:12px;background:var(--blue-tint);line-height:1.5}
footer{border-top:1px solid var(--line);padding:36px 0 64px;color:var(--ink-3);font-size:14px}
footer .wrap{display:flex;flex-wrap:wrap;gap:12px 28px;justify-content:space-between}footer a{color:var(--ink-2)}
#lb{position:fixed;inset:0;background:rgba(5,7,20,.86);display:none;align-items:center;justify-content:center;padding:24px;z-index:30;cursor:zoom-out}
#lb.on{display:flex}#lb img{max-width:100%;max-height:100%;border-radius:8px;box-shadow:0 30px 80px rgba(0,0,0,.5)}
"""

# Only on translated pages: the language line, the "translated from English" note, and the
# right-to-left mirror of every rule above that has a side in it (Arabic).
CSS_I18N = """
.langs{flex-basis:100%;display:flex;flex-wrap:wrap;gap:4px 10px}.langs b{color:var(--ink);font-weight:600}.en-only{color:var(--ink-3)}
.tr-note{font-size:14px;color:var(--ink-3);margin:0 0 1.6em}
code,kbd,pre{direction:ltr;unicode-bidi:isolate}
.lpick{position:relative}.lpick summary{list-style:none;cursor:pointer;height:40px;padding:0 8px;display:flex;align-items:center;gap:5px;border-radius:10px;color:var(--ink-2,var(--ink))}
.lpick summary::-webkit-details-marker{display:none}.lpick summary .chev{width:11px;height:11px;opacity:.7}.lpick[open] summary,.lpick summary:hover{background:color-mix(in srgb,var(--ink) 8%,transparent)}
.lpick .fl{flex:none;width:23px;height:16px;border-radius:3px;box-shadow:0 0 0 1px color-mix(in srgb,var(--ink) 16%,transparent)}
.lpick .links{position:absolute;right:0;top:48px;z-index:30;min-width:220px;padding:6px;border-radius:14px;background:var(--win);border:1px solid var(--line);box-shadow:0 20px 50px rgba(0,0,0,.18);display:grid}
.lpick .links a,.lpick .links b{display:flex;align-items:center;gap:10px;padding:9px 12px;border-radius:9px;font-size:15px;font-weight:400;color:var(--ink);white-space:nowrap}
.lpick .links a:hover{background:var(--blue-tint);text-decoration:none}.lpick .links b{font-weight:600;background:color-mix(in srgb,var(--ink) 6%,transparent)}
@media(max-width:700px){.lpick .links{right:-48px;max-height:70vh;overflow:auto}.lpick .links a,.lpick .links b{padding:11px 12px;font-size:16px}}
[dir=rtl] .lpick .links{right:auto;left:0}
@media(max-width:700px){[dir=rtl] .lpick .links{left:-48px}}
[dir=rtl] .mnav .links{right:auto;left:0}
@media(max-width:700px){[dir=rtl] .mnav{margin-right:0;margin-left:-8px}}
[dir=rtl] aside{padding-right:0;padding-left:8px}
[dir=rtl] aside a{padding:4px 12px 4px 0;border-left:0;border-right:2px solid var(--line)}
[dir=rtl] aside a.on{border-right-color:var(--blue)}
[dir=rtl] aside ol ol a{padding-left:0;padding-right:24px}
[dir=rtl] th,[dir=rtl] td{text-align:right;padding:9px 0 9px 12px}
[dir=rtl] .fb .btn{justify-self:end}
"""

JS = """
(function(){
  document.querySelectorAll('.mnav,.lpick').forEach(function(mn){mn.querySelectorAll('a').forEach(function(a){a.addEventListener('click',function(){mn.removeAttribute('open');});});document.addEventListener('click',function(e){if(mn.open&&!mn.contains(e.target))mn.removeAttribute('open');});mn.addEventListener('toggle',function(){if(mn.open)document.querySelectorAll('.mnav,.lpick').forEach(function(o){if(o!==mn)o.removeAttribute('open');});});});
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


def figure(src: str, alt: str, lang: str = "en", ui: dict = UI_EN) -> str:
    path = src.replace("site/", "", 1)                # docs/*.md links are relative to docs/
    if lang != "en":                                  # a screenshot of this language, when there is one
        own = re.sub(r"^img/guide/", f"img/guide/{LANG[lang]['slug']}/", path)
        if own != path and (site / own).exists():
            path = own
    try:
        w, h = Image.open(site / path).size
    except OSError:
        w, h = 1200, 800
    css_w, css_h = w // 2, h // 2
    url = "/" + path + "?v=" + file_hash(site / path)  # absolute: the same file from /guide and /ru/guide; content hash: a changed picture gets a new URL
    return (f'<figure class="shot" style="max-width:{css_w}px">'
            f'<a href="{url}" class="zoom" title="{ui["open_full_size"]}">'
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


def json_ld(out_name: str, title: str, description: str, kind: str, crumb: str, headline: str, lang: str = "en") -> str:
    url = page_url(out_name, lang)
    crumbs = {"@type": "BreadcrumbList", "itemListElement": [
        {"@type": "ListItem", "position": 1, "name": "Keepit", "item": page_url("index.html", lang)},
        {"@type": "ListItem", "position": 2, "name": crumb, "item": url}]}
    page = {"@type": kind, "@id": url, "url": url, "name": headline, "headline": headline, "description": description,
            "inLanguage": LANG[lang]["hreflang"], "isPartOf": {"@id": SITE + "#site"}, "about": {"@id": SITE + "#app"},
            "author": {"@id": SITE + "#org"}, "publisher": {"@id": SITE + "#org"},
            "image": SITE + "img/social-preview.png?v=57583ec3", "dateModified": DATE}
    if lang != "en":
        page["translationOfWork"] = {"@id": page_url(out_name, "en")}
    return '<script type="application/ld+json">' + json.dumps({"@context": "https://schema.org", "@graph": [page, crumbs]}, ensure_ascii=False) + '</script>'


def modified(src_path: str) -> str:
    """Last commit date of a file under docs/ (today for files not committed yet)."""
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cs", "--", f"docs/{src_path}"], cwd=root, capture_output=True, text=True).stdout.strip()
        return out or DATE
    except OSError:
        return DATE


def blob(path: pathlib.Path) -> str:
    return subprocess.run(["git", "hash-object", str(path)], cwd=root, capture_output=True, text=True).stdout.strip()


TURNSTILE_SITE_KEY = "0x4AAAAAAFxKO-1Iq_maRhEF"   # public Turnstile site key for keep.it.com
EUROMETRICS_WEBSITE_ID = "0ab7fe20-0c05-4061-b037-c033dc46c1e1"   # keep.it.com in EuroMetrics (Settings → Websites → Tracking Code); public
# Cookieless page-view counting (EuroMetrics, EU-hosted). Counts only on keep.it.com, honours Do Not Track,
# drops query strings; data-no-storage keeps it from touching localStorage/sessionStorage/cookies (EuroMetrics,
# attribute available since 5 Nov 2026). Allowed in the CSP in docs/site/_headers; disclosed in docs/PRIVACY.md section 6.
ANALYTICS = ('<script defer src="https://app.eurometrics.eu/script.js?v=7cfd3b4c27be" data-website-id="' + EUROMETRICS_WEBSITE_ID +
             '" data-domains="keep.it.com" data-do-not-track="true" data-exclude-search="true" data-no-storage="true"></script>')

WARNINGS: list[str] = []


def english_ids(src_name: str) -> list:
    """(level, id) of every heading of the English page, in order."""
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc"])
    md.convert((root / "docs" / src_name).read_text(encoding="utf-8"))
    out = []
    def walk(tokens):
        for t in tokens:
            out.append((t["level"], t["id"]))
            walk(t["children"])
    walk(md.toc_tokens)
    return out


def translated_source(src_name: str, lang: str) -> str:
    """The translated Markdown, after checking it was made from the current English file."""
    path = i18n / lang / src_name
    text = path.read_text(encoding="utf-8")
    m = re.match(r"<!-- source: (\S+) ([0-9a-f]{40}) -->\n", text)
    if not m or m.group(1) != src_name:
        raise SystemExit(f"{path}: the first line must be <!-- source: {src_name} <git blob sha of docs/{src_name}> -->")
    if m.group(2) != blob(root / "docs" / src_name):
        WARNINGS.append(f"{lang}/{src_name}: docs/{src_name} has changed since this translation (blob {m.group(2)[:8]}); update it")
    return text[m.end():]


def render(src_name: str, out_name: str, title: str, description: str, with_toc: bool, kind: str, crumb: str, lang: str = "en") -> None:
    global DATE
    data = load_site(lang)
    ui = data["ui"]
    ids = None
    if lang == "en":
        DATE = modified(src_name)
        md_text = (root / "docs" / src_name).read_text(encoding="utf-8")
    else:
        DATE = modified(f"i18n/{lang}/{src_name}")
        meta = data["pages"][src_name]
        title, description, crumb = meta["title"], meta["description"], meta["crumb"]
        md_text = translated_source(src_name, lang)
        ids = english_ids(src_name)
    queue = list(ids or [])
    def slugify(value, separator):                     # translated headings take the English ids, in order
        if ids is None:
            return markdown.extensions.toc.slugify(value, separator)
        return queue.pop(0)[1] if queue else markdown.extensions.toc.slugify(value, separator)
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc"], extension_configs={"toc": {"slugify": slugify}})
    md_text = md_text.replace('__TURNSTILE_SITE_KEY__', TURNSTILE_SITE_KEY)
    body = md.convert(md_text)
    if ids is not None:
        got = []
        def walk(tokens):
            for t in tokens:
                got.append(t["level"]); walk(t["children"])
        walk(md.toc_tokens)
        if got != [lv for lv, _ in ids]:
            WARNINGS.append(f"{lang}/{src_name}: headings differ from the English page ({len(got)} vs {len(ids)}); anchors may not match")
    body = re.sub(r'<p><img alt="([^"]*)" src="([^"]+)"\s*/?></p>', lambda m: figure(m.group(2), m.group(1), lang, ui), body)
    body = re.sub(r"<!-- screenshot: (.*?) -->", r'<p class="slot">Screenshot: \1</p>', body)
    body = re.sub(r"<p><strong>Contents</strong></p>\s*<ul>.*?</ul>\s*<hr\s*/?>", "", body, count=1, flags=re.S)
    body = keycaps(body)
    body = body.replace('<table>', '<div class="tbl"><table>').replace('</table>', '</table></div>')
    body = localize_links(body, lang)
    if lang != "en" and ui["translated_note"]:     # under the page's h1
        note = '<p class="tr-note">' + ui["translated_note"].replace("{en}", page_url(out_name, "en").removeprefix(SITE.rstrip("/"))) + "</p>"
        body = re.sub(r"(</h1>)", r"\1" + note.replace("\\", "\\\\"), body, count=1)
    headline = (md.toc_tokens[0]["name"] if md.toc_tokens and md.toc_tokens[0]["level"] == 1 else title)
    tokens = [t for t in md.toc_tokens if t["level"] == 1]
    sections = tokens[0]["children"] if tokens else md.toc_tokens
    toc = toc_html(sections) if with_toc else ""
    aside = f'<aside aria-label="{ui["contents"]}"><p class="ttl">{ui["on_this_page"]}</p>{toc}</aside>' if toc else ""
    main_cls = "wrap" if toc else "wrap narrow"
    multi = src_name in TRANSLATED
    L = LANG[lang]
    dir_attr = ' dir="rtl"' if L["dir"] == "rtl" else ""
    url = page_url(out_name, lang)
    page = (f'<!DOCTYPE html><html lang="{L["hreflang"]}"{dir_attr}><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<title>{title}</title><link rel="icon" href="/img/icon.png?v=a1519b94"><link rel="apple-touch-icon" href="/img/icon.png?v=a1519b94">\n'
            f'<meta name="description" content="{description}">\n'
            f'<link rel="canonical" href="{url}">'
            + (alternates_html(out_name) if multi else "") +
            f'<meta property="og:type" content="article"><meta property="og:site_name" content="Keepit"><meta property="og:locale" content="{L["og"]}">'
            f'<meta property="og:title" content="{title}"><meta property="og:description" content="{description}">'
            f'<meta property="og:image" content="{SITE}img/social-preview.png?v=57583ec3"><meta property="og:url" content="{url}">'
            f'<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{title}"><meta name="twitter:description" content="{description}"><meta name="twitter:image" content="{SITE}img/social-preview.png?v=57583ec3">'
            f'<meta name="theme-color" content="#fbfbfd" media="(prefers-color-scheme: light)"><meta name="theme-color" content="#0c0d14" media="(prefers-color-scheme: dark)">\n'
            f'{json_ld(out_name, title, description, kind, crumb, headline, lang)}\n'
            f'{ANALYTICS}\n<style>{CSS}{CSS_I18N if len(active_langs()) > 1 else ""}</style></head>\n<body>{header_html(lang, ui, out_name if multi else None)}\n<main class="{main_cls}">{aside}<article>{body}</article></main>\n{footer_html(lang, ui, out_name if multi else None)}\n'
            f'<div id="lb" role="dialog" aria-label="{ui["full_size_screenshot"]}"><img alt=""></div>\n'
            f'<script>{JS}</script>\n</body></html>')
    stray = re.findall(r'href="(?:\.\./|/)?[a-z0-9/-]+\.html[^"]*"', page)
    if stray:
        raise SystemExit(f"{out_name}: internal links must not end in .html (Cloudflare Pages redirects them): {sorted(set(stray))}")
    out = site / (L["slug"] + "/" if lang != "en" else "") / out_name
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(out.relative_to(site), len(page), "bytes;", body.count('class="shot"'), "figures;", body.count('<kbd'), "keycaps")


# ---- the landing ------------------------------------------------------------------------------

def fill_marker(page: str, name: str, content: str) -> str:
    """Replace what is between <!--i18n:name--> and <!--/i18n:name--> in a hand-written page."""
    pat = re.compile(rf"(<!--i18n:{name}-->).*?(<!--/i18n:{name}-->)", re.S)
    if not pat.search(page):
        raise SystemExit(f"index.html: marker <!--i18n:{name}--> … <!--/i18n:{name}--> not found")
    return pat.sub(lambda m: m.group(1) + content + m.group(2), page, count=1)


def landing_for(lang: str, english: str) -> str:
    """The English landing with this language's alternates/switcher, then its translation."""
    page = fill_marker(english, "alternates", alternates_html("index.html"))
    css = f"<style>{CSS_I18N}</style>" if len(active_langs()) > 1 else ""
    page = fill_marker(page, "css", css)
    if lang == "en":
        page = fill_marker(page, "lpick", langpick_html(lang, UI_EN, "index.html"))
        return fill_marker(page, "switcher", switcher_html(lang, "index.html"))
    L = LANG[lang]
    pairs = json.loads((i18n / lang / "landing.json").read_text(encoding="utf-8"))
    for en, tr in pairs:
        if en not in page:
            WARNINGS.append(f"{lang}/landing.json: no longer in index.html, left in English: {en[:70]!r}")
            continue
        page = page.replace(en, tr)
    url = page_url("index.html", lang)
    page = page.replace('<html lang="en">', f'<html lang="{L["hreflang"]}"' + (' dir="rtl"' if L["dir"] == "rtl" else "") + '>', 1)
    page = page.replace('<link rel="canonical" href="https://keep.it.com/">', f'<link rel="canonical" href="{url}">', 1)
    page = page.replace('<meta property="og:url" content="https://keep.it.com/">', f'<meta property="og:url" content="{url}"><meta property="og:locale" content="{L["og"]}">', 1)
    page = re.sub(r'(src|href)="img/', r'\1="/img/', page)                 # the page lives one folder down
    page = page.replace('<a class="brand" href="#">', '<a class="brand" href="/">', 1)
    page = re.sub(r',\s*\{"@type":"FAQPage".*?\]\}\s*\n', "\n", page, count=1, flags=re.S)   # the FAQ answers stay in the English page's data
    page = page.replace('"url":"https://keep.it.com/","name":"Keepit","publisher"', f'"url":"https://keep.it.com/","name":"Keepit","inLanguage":["en"{"".join(", " + json.dumps(LANG[c]["hreflang"]) for c in active_langs()[1:])}],"publisher"', 1)
    page = localize_links(page, lang)
    page = fill_marker(page, "lpick", langpick_html(lang, load_site(lang)["ui"], "index.html"))
    return fill_marker(page, "switcher", switcher_html(lang, "index.html"))   # after localize_links: other languages on purpose


def write_landings() -> None:
    src = site / "index.html"
    english = src.read_text(encoding="utf-8")
    english = landing_for("en", english)
    src.write_text(english, encoding="utf-8")
    for lang in active_langs()[1:]:
        out = site / LANG[lang]["slug"] / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        page = landing_for(lang, english)
        stray = re.findall(r'href="(?:\.\./|/)?[a-z0-9/-]+\.html[^"]*"', page)
        if stray:
            raise SystemExit(f"{out}: internal links must not end in .html: {sorted(set(stray))}")
        out.write_text(page, encoding="utf-8")
        print(out.relative_to(site), len(page), "bytes")


def write_sitemap() -> None:
    urls = [("index.html", "1.0", "weekly", modified("site/index.html"), "en")]
    urls += [(p[1], "0.8" if p[5] != "WebPage" else "0.3", "monthly", modified(p[0]), "en") for p in PAGES]
    for lang in active_langs()[1:]:
        urls.append(("index.html", "0.9", "weekly", modified(f"i18n/{lang}/landing.json"), lang))
        for src, out in TRANSLATED.items():
            urls.append((out, "0.7" if out == "guide.html" else "0.3", "monthly", modified(f"i18n/{lang}/{src}"), lang))
    multi = {"index.html"} | set(TRANSLATED.values())
    def alts(page):
        if page not in multi or len(active_langs()) < 2:
            return ""
        return "".join(f'<xhtml:link rel="alternate" hreflang="{LANG[c]["hreflang"]}" href="{page_url(page, c)}"/>' for c in active_langs()) + \
               f'<xhtml:link rel="alternate" hreflang="x-default" href="{page_url(page, "en")}"/>'
    body = "".join(f"<url><loc>{page_url(p, l)}</loc>{alts(p)}<lastmod>{d}</lastmod><changefreq>{f}</changefreq><priority>{pr}</priority></url>" for p, pr, f, d, l in urls)
    ns = ' xmlns:xhtml="http://www.w3.org/1999/xhtml"' if len(active_langs()) > 1 else ""
    (site / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"{ns}>{body}</urlset>\n', encoding="utf-8")
    (site / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE}sitemap.xml\n", encoding="utf-8")


for p in PAGES:
    render(*p)
for lang in active_langs()[1:]:
    for p in PAGES:
        if p[0] in TRANSLATED:
            render(*p, lang=lang)
write_landings()
write_sitemap()
print("sitemap.xml, robots.txt")
for w in WARNINGS:
    print("WARNING:", w)
