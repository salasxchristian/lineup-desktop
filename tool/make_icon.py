"""Draws the Lineup app icon (see the "App icon" artboard on the design canvas) and writes the
macOS AppIcon set and the Windows .ico.

    python3 -m venv /tmp/icon-venv && /tmp/icon-venv/bin/pip install pillow
    /tmp/icon-venv/bin/python -I tool/make_icon.py

The 1024 grid: a near-black tile 824 px at a 100 px margin with corner 186, holding an old
school TV in signal red: a 572 x 424 body with corner 92, a dark CRT screen with a glare, two
knobs and a speaker grille on the right, rabbit ear antennas and two feet.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TILE = (0x11, 0x12, 0x15, 255)
RED = (0xF2, 0x55, 0x5A, 255)
RED_DARK = (0xB8, 0x3B, 0x41, 255)
SCREEN = (0x14, 0x16, 0x1A, 255)
GLASS_TOP = (0x2A, 0x2E, 0x36, 255)
EARS = (0xE6, 0xE7, 0xEA, 255)
S = 4  # supersampling
DY = 18  # nudges the TV down so body, ears and feet sit centered in the tile


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
    scale = (1024 - 2 * margin) / 824
    corner = 186 * S * scale
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.alpha_composite(shadow(size, tile, corner, (0, 0, 0, 140), 20 * S, 12 * S))
    img.alpha_composite(rounded(size, tile, corner, TILE))
    # A hairline so the tile doesn't vanish on a dark desktop.
    ImageDraw.Draw(img).rounded_rectangle(tile, radius=corner, outline=(255, 255, 255, 18), width=2 * S)

    def p(x, y):
        """A point on the 1024 grid, scaled about the center for this margin."""
        return ((512 + (x - 512) * scale) * S, (512 + (y + DY - 512) * scale) * S)

    def box(x0, y0, x1, y1):
        return (*p(x0, y0), *p(x1, y1))

    def r(v):
        return v * S * scale

    draw = ImageDraw.Draw(img)

    # Rabbit ears, drawn first so the body covers their roots.
    for tip in ((372, 194), (660, 172)):
        draw.line((*p(512, 330), *p(*tip)), fill=EARS, width=round(r(20)))
        tx, ty = p(*tip)
        draw.ellipse((tx - r(22), ty - r(22), tx + r(22), ty + r(22)), fill=EARS)
    draw.ellipse(box(446, 312, 578, 392), fill=RED_DARK)

    # Feet.
    for x in (296, 676):
        draw.rounded_rectangle(box(x, 750, x + 52, 812), radius=r(16), fill=RED_DARK)

    body = box(226, 352, 798, 776)
    img.alpha_composite(shadow(size, body, r(92), (242, 85, 90, 70), r(28), r(12)))
    img.alpha_composite(rounded(size, body, r(92), RED))
    draw = ImageDraw.Draw(img)

    # The CRT: a dark screen with a soft lip and a glare in its top left.
    draw.rounded_rectangle(box(262, 388, 642, 740), radius=r(76), fill=RED_DARK)
    screen = box(274, 400, 630, 728)
    # Glass a shade lighter than the tile, brightest at the top, so it reads as a screen and not a hole.
    glass = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    top, bottom = round(screen[1]), round(screen[3])
    for y in range(top, bottom + 1):
        t = (y - top) / (bottom - top)
        gd.line((screen[0], y, screen[2], y), fill=tuple(round(a + (b - a) * t) for a, b in zip(GLASS_TOP, SCREEN)))
    mask = rounded(size, screen, r(66), (255, 255, 255, 255)).getchannel("A")
    img.paste(glass, (0, 0), mask)
    glare = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glare)
    gd.arc(box(310, 432, 560, 690), start=192, end=258, fill=(255, 255, 255, 70), width=round(r(18)))
    img.alpha_composite(glare.filter(ImageFilter.GaussianBlur(r(3))))
    draw = ImageDraw.Draw(img)

    # Knobs, each with a pointer, then the speaker grille.
    for cy, rad, angle in ((474, 40, (0, -1)), (578, 30, (1, -1))):
        cx, cyy = p(716, cy)
        draw.ellipse((cx - r(rad), cyy - r(rad), cx + r(rad), cyy + r(rad)), fill=TILE)
        k = r(rad * 0.62) / (2 ** 0.5 if angle[0] else 1)
        draw.line((cx, cyy, cx + angle[0] * k, cyy + angle[1] * k), fill=EARS, width=round(r(8)))
    for y in (652, 682, 712):
        draw.rounded_rectangle(box(684, y, 748, y + 12), radius=r(6), fill=RED_DARK)

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
