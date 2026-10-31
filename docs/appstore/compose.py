#!/usr/bin/env python3
"""Frame raw window captures into 2560×1600 App Store screenshots with a caption.
Usage: python3 compose.py   (reads raw/<name>.png, writes out/<nn>-<name>.png). Needs Playwright+Chromium."""
import asyncio, base64, pathlib
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).parent
SHOTS = [
    # (file, headline, subline, layout: "right" = text left + image right, "top" = text above image)
    ("menu", "Everything you copied,\none hot key away", "Press ⌥C in any app. Pick with the mouse or type 1–9, A–Z — it's pasted where you were typing.", "right"),
    ("viewer", "Browse, edit, organize", "History and templates in one tree — edit text in place, inspect every clipboard format, drag items into templates.", "top"),
    ("preferences", "Private by design", "Password-protected, AES-256 encrypted, unlocked with Touch ID. Locks when the screen does. Password managers are never recorded.", "right"),
]

CSS = """
* { box-sizing: border-box; margin: 0; }
body { width: 2560px; height: 1600px; overflow: hidden; font-family: -apple-system, "SF Pro Display", "Helvetica Neue", Arial, sans-serif;
       background: radial-gradient(1200px 900px at 15% 10%, #6F9BFF 0%, #3D5FE0 45%, #22399F 100%); color: #fff; position: relative; }
.badge { position: absolute; top: 64px; left: 96px; display: flex; align-items: center; gap: 24px; font-size: 40px; font-weight: 600; letter-spacing: .2px; opacity: .95; }
.badge img { width: 88px; height: 88px; border-radius: 20px; box-shadow: 0 12px 30px rgba(0,0,0,.25); }
h1 { font-size: 104px; line-height: 1.04; font-weight: 700; letter-spacing: -1.5px; white-space: pre-line; }
p  { font-size: 40px; line-height: 1.35; font-weight: 400; opacity: .92; margin-top: 36px; }
.shot { position: absolute; border-radius: 24px; box-shadow: 0 50px 120px rgba(0,0,0,.45), 0 0 0 2px rgba(255,255,255,.12); }
.right .text { position: absolute; left: 96px; top: 300px; width: 1000px; }
.right .shot { right: 96px; top: 50%; transform: translateY(-50%); max-width: 1280px; max-height: 1380px; }
.top .text { position: absolute; left: 96px; top: 200px; width: 2368px; }
.top .text h1 { font-size: 92px; }
.top .text p { margin-top: 16px; font-size: 38px; }
.top .shot { left: 50%; transform: translateX(-50%); top: 470px; max-width: 2368px; max-height: 1070px; }
.foot { position: absolute; right: 96px; top: 84px; font-size: 32px; opacity: .85; font-weight: 500; }
.right .foot { right: auto; top: auto; left: 96px; bottom: 64px; }
"""

async def main():
    icon = base64.b64encode((HERE.parent.parent / "Resources/Icon/preview-512.png").read_bytes()).decode()
    async with async_playwright() as p:
        b = await p.chromium.launch()
        page = await b.new_page(viewport={"width": 2560, "height": 1600}, device_scale_factor=1)
        for i, (name, h1, sub, layout) in enumerate(SHOTS, 1):
            img = base64.b64encode((HERE / "raw" / f"{name}.png").read_bytes()).decode()
            html = f"""<html><head><style>{CSS}</style></head><body class="{layout}">
              <div class="badge"><img src="data:image/png;base64,{icon}">Keepit – Clipboard Manager</div>
              <div class="text"><h1>{h1}</h1><p>{sub}</p></div>
              <img class="shot" src="data:image/png;base64,{img}">
              <div class="foot">keep.it.com · free &amp; open source</div>
            </body></html>"""
            await page.set_content(html)
            await page.wait_for_timeout(200)
            out = HERE / "out" / f"{i:02d}-{name}.png"
            await page.screenshot(path=str(out), clip={"x": 0, "y": 0, "width": 2560, "height": 1600})
            print("wrote", out)
        await b.close()

asyncio.run(main())
