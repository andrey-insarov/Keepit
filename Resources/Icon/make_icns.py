#!/usr/bin/env python3
"""Render icon.svg → PNGs at all macOS sizes → AppIcon.icns (and a 512px preview).
Needs Playwright with Chromium (used by the CI/dev container); on a Mac you can instead run
`iconutil -c icns AppIcon.iconset` after rendering the PNGs with any tool."""
import struct, pathlib, asyncio, sys
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).parent
SIZES = [16, 32, 64, 128, 256, 512, 1024]
# ICNS type codes for PNG payloads (sizes are the pixel sizes of the PNG).
# No icp4/icp5 (16/32 px): some system components (e.g. the Touch ID dialog) read those two
# types as raw 24-bit RGB and render PNG payloads as noise. macOS downscales ic11 instead.
TYPES = {64: b"icp6", 128: b"ic07", 256: b"ic08", 512: b"ic09", 1024: b"ic10",
         "32@2x": b"ic11", "64@2x": b"ic12", "256@2x": b"ic13", "512@2x": b"ic14"}

async def render():
    svg = (HERE / "icon.svg").read_text()
    pngs = {}
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for s in SIZES:
            page = await browser.new_page(viewport={"width": s, "height": s}, device_scale_factor=1)
            html = f"<html><body style='margin:0;background:transparent'>{svg.replace('width=\"1024\" height=\"1024\"', f'width=\"{s}\" height=\"{s}\"')}</body></html>"
            await page.set_content(html)
            pngs[s] = await page.screenshot(omit_background=True, clip={"x": 0, "y": 0, "width": s, "height": s})
            await page.close()
        await browser.close()
    return pngs

def write_icns(pngs, out):
    entries = []
    for key, code in TYPES.items():
        size = key if isinstance(key, int) else int(key.split("@")[0]) * 2
        data = pngs[size]
        entries.append(code + struct.pack(">I", 8 + len(data)) + data)
    body = b"".join(entries)
    out.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)

def main():
    pngs = asyncio.run(render())
    iconset = HERE / "AppIcon.iconset"
    iconset.mkdir(exist_ok=True)
    for s in [16, 32, 128, 256, 512]:
        (iconset / f"icon_{s}x{s}.png").write_bytes(pngs[s])
        (iconset / f"icon_{s}x{s}@2x.png").write_bytes(pngs[s * 2])
    (HERE / "preview-512.png").write_bytes(pngs[512])
    write_icns(pngs, HERE / "AppIcon.icns")
    print("wrote", HERE / "AppIcon.icns", sum(len(v) for v in pngs.values()), "bytes of PNG")

if __name__ == "__main__":
    main()
