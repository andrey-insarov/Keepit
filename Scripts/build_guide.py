#!/usr/bin/env python3
"""Render docs/GUIDE.md into docs/site/guide.html (run after editing the guide)."""
import re, pathlib, markdown
root = pathlib.Path(__file__).resolve().parent.parent
md = (root / "docs/GUIDE.md").read_text(encoding="utf-8")
body = markdown.markdown(md, extensions=["tables", "fenced_code", "toc"])
# Screenshot slots: "<!-- screenshot: ... -->" → a dashed placeholder until an image replaces it.
body = body.replace('src="site/img/', 'src="img/')
body = re.sub(r"<!-- screenshot: (.*?) -->", r'<p class="slot">Screenshot: \1</p>', body)
html = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>User guide — Keepit</title><link rel="icon" href="img/icon.png">
<meta name="description" content="How to use Keepit, the clipboard manager for macOS: history menu, hot keys, templates, placeholders, the Viewer, security and automation.">
<style>
:root{{color-scheme:light dark;--accent:#2F4FD1;--muted:#6b7280}}
body{{font:17px/1.6 -apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;max-width:860px;margin:0 auto;padding:48px 24px 96px}}
h1{{font-size:40px;letter-spacing:-.5px;margin:.2em 0 .4em}}h2{{margin-top:2.2em;padding-top:.4em;border-top:1px solid rgba(127,127,127,.25)}}h3{{margin-top:1.6em}}
a{{color:var(--accent)}}code{{font:.92em ui-monospace,SFMono-Regular,Menlo,monospace;background:rgba(127,127,127,.14);padding:1px 5px;border-radius:5px}}
pre{{background:rgba(127,127,127,.12);padding:14px 18px;border-radius:12px;overflow:auto}}pre code{{background:none;padding:0}}
table{{border-collapse:collapse;width:100%;margin:1em 0;font-size:15.5px}}th,td{{text-align:left;padding:8px 10px;border-bottom:1px solid rgba(127,127,127,.25);vertical-align:top}}th{{color:var(--muted);font-weight:600}}
.slot{{border:2px dashed rgba(127,127,127,.4);border-radius:12px;padding:28px;text-align:center;color:var(--muted);font-size:15px}}
img{{max-width:100%;border-radius:12px;box-shadow:0 16px 40px rgba(0,0,0,.18);display:block;margin:1.2em auto}}
nav.top a{{margin-right:16px}}.toc{{background:rgba(127,127,127,.08);border-radius:12px;padding:12px 24px}}
</style></head>
<body><nav class="top"><a href="index.html">← keep.it.com</a><a href="support.html">Support</a><a href="https://github.com/andrey-insarov/Keepit">GitHub</a></nav>
{body}
</body></html>"""
(root / "docs/site/guide.html").write_text(html, encoding="utf-8")
print("docs/site/guide.html", len(html), "bytes")
