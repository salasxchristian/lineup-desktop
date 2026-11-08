"""Draws the Lineup app icon (see the "App icon" artboard on the design canvas) and writes the
macOS AppIcon set and the Windows .ico.

    python3 -m venv /tmp/icon-venv && /tmp/icon-venv/bin/pip install pillow
    /tmp/icon-venv/bin/python -I tool/make_icon.py

The 1024 grid: a near-black tile 824 px at a 100 px margin with corner 186, a signal red mark
440 px with corner 124, and a 120 px live dot in the tile's color.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TILE = (0x11, 0x12, 0x15, 255)
RED = (0xF2, 0x55, 0x5A, 255)
S = 4  # supersampling


def rounded(size, box, radius, fill):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=fill)
    return layer


def shadow(size, box, radius, color, blur, dy):
    x0, y0, x1, y1 = box
    layer = rounded(size, (x0, y0 + dy, x1, y1 + dy), radius, color)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def icon(margin=100):
    """The icon at 1024 px. margin=100 is macOS's grid; Windows uses a smaller one."""
    n = 1024 * S
    size = (n, n)
    m = margin * S
    tile = (m, m, n - m, n - m)
    corner = 186 * S * (1024 - 2 * margin) / 824
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.alpha_composite(shadow(size, tile, corner, (0, 0, 0, 140), 20 * S, 12 * S))
    img.alpha_composite(rounded(size, tile, corner, TILE))
    # A hairline so the tile doesn't vanish on a dark desktop.
    ImageDraw.Draw(img).rounded_rectangle(tile, radius=corner, outline=(255, 255, 255, 18), width=2 * S)

    scale = (1024 - 2 * margin) / 824
    half = 220 * S * scale
    c = n / 2
    mark = (c - half, c - half, c + half, c + half)
    img.alpha_composite(shadow(size, mark, 124 * S * scale, (242, 85, 90, 80), 28 * S * scale, 12 * S * scale))
    img.alpha_composite(rounded(size, mark, 124 * S * scale, RED))
    dot = 60 * S * scale
    ImageDraw.Draw(img).ellipse((c - dot, c - dot, c + dot, c + dot), fill=TILE)
    return img.resize((1024, 1024), Image.LANCZOS)


def main():
    mac = icon(margin=100)
    out = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        mac.resize((px, px), Image.LANCZOS).save(out / f"app_icon_{px}.png")

    win = icon(margin=40)
    win.save(ROOT / "windows/runner/resources/app_icon.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    mac.save(ROOT / "tool/app_icon_1024.png")
    print("wrote", out, "and windows/runner/resources/app_icon.ico", file=sys.stderr)


if __name__ == "__main__":
    main()
