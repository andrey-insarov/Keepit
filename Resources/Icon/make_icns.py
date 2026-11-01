#!/usr/bin/env python3
"""Render icon.svg → PNGs at all macOS sizes → AppIcon.icns (and a 512px preview).
Needs Playwright with Chromium (used by the CI/dev container); on a Mac you can instead run
`iconutil -c icns AppIcon.iconset` after rendering the PNGs with any tool."""
import struct, pathlib, asyncio, sys
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).parent
SIZES = [16, 32, 64, 128, 256, 512, 1024]
# ICNS type codes for PNG payloads (sizes are the pixel sizes of the PNG).
# Same layout as Apple's iconutil: 16/32 px as uncompressed-ish ARGB (ic04/ic05, PackBits),
# everything else as PNG. No icp4/icp5/icp6 — several system renderers (e.g. the Touch ID
# sheet) treat those legacy types as raw RGB and draw PNG payloads as colour noise.
TYPES = {128: b"ic07", 256: b"ic08", 512: b"ic09", 1024: b"ic10",
         "16@2x": b"ic11", "32@2x": b"ic12", "256@2x": b"ic13", "512@2x": b"ic14"}
ARGB_TYPES = {16: b"ic04", 32: b"ic05"}

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

def packbits(b: bytes) -> bytes:
    """ICNS flavour of PackBits (as used by is32/il32/ic04/ic05)."""
    out = bytearray()
    i, n = 0, len(b)
    while i < n:
        run = 1
        while i + run < n and run < 130 and b[i + run] == b[i]:
            run += 1
        if run >= 3:
            out += bytes([run - 3 + 0x80, b[i]])
            i += run
            continue
        lit = i
        while i < n and (i - lit) < 128:
            r = 1
            while i + r < n and r < 3 and b[i + r] == b[i]:
                r += 1
            if r >= 3:
                break
            i += 1
        out += bytes([i - lit - 1]) + b[lit:i]
    return bytes(out)

def argb_entry(png: bytes) -> bytes:
    import io
    from PIL import Image
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    px = im.tobytes()
    chans = [bytes(px[c::4]) for c in (3, 0, 1, 2)]      # A, R, G, B
    return b"ARGB" + b"".join(packbits(c) for c in chans)

def write_icns(pngs, out):
    entries = []
    for size, code in ARGB_TYPES.items():
        data = argb_entry(pngs[size])
        entries.append(code + struct.pack(">I", 8 + len(data)) + data)
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
