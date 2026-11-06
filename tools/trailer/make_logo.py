"""Draw the Mosaicus Maximus logo as pixel art on the game's own pixel grid, for the trailer's end card and the Steam page.

The letters are Cinzel (SIL Open Font License, kept beside this script), a typeface drawn from Roman inscriptions,
rendered large and sampled down to whole pixels, then shaded by hand rules: sunlit gold on top, deeper ochre below,
a carved edge, a dark outline and a little depth underneath, with a laurel sprig curling out from each side.

It also draws the parchment scroll the end card's "Wishlist" line is written on.

Usage: python tools/trailer/make_logo.py
Writes game/tools/trailer/logo.png, logo_plain.png (the name without the laurel) and scroll.png at 1 pixel per game
pixel; the trailer shows them 4 times larger, like the game.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "game" / "tools" / "trailer" / "logo.png"
SCROLL_OUT = OUT.with_name("scroll.png")
PLAIN_OUT = OUT.with_name("logo_plain.png")
PARCHMENT, PARCHMENT_SHADE, PARCHMENT_LIGHT = (252, 242, 219), (226, 204, 166), (255, 250, 236)
ROLL, ROLL_SHADE, ROLL_LIGHT = (214, 186, 140), (172, 136, 92), (240, 222, 186)
CAP = 27
SUPER = 8
LINES = ["MOSAICUS", "MAXIMUS"]
LINE_GAP = 7
TRACKING = 2
DEPTH = 3

OUTLINE = (58, 34, 26)
DEPTH_DARK = (112, 58, 28)
DEPTH_LIGHT = (142, 76, 34)
EDGE_TOP = (255, 247, 214)
EDGE_LOW = (168, 88, 34)
BANDS = [(255, 232, 160), (250, 212, 110), (240, 182, 72), (224, 150, 52), (204, 122, 42)]
LEAF_DARK, LEAF_MID, LEAF_LIGHT = (52, 86, 46), (86, 128, 62), (138, 172, 88)


def glyph_line(text):
    """One line of capitals as a coverage mask with letters a little apart, CAP pixels tall."""
    font = ImageFont.truetype(str(HERE / "Cinzel.ttf"), 10)
    font.set_variation_by_axes([900])
    cap = font.getbbox("H")
    size = int(10 * CAP * SUPER / (cap[3] - cap[1]))
    font = ImageFont.truetype(str(HERE / "Cinzel.ttf"), size)
    font.set_variation_by_axes([900])
    top = font.getbbox("H")[1]
    widths = [font.getbbox(ch)[2] for ch in text]
    total = sum(widths) + TRACKING * SUPER * (len(text) - 1)
    canvas = Image.new("L", (total + SUPER * 4, CAP * SUPER + SUPER * 2), 0)
    d = ImageDraw.Draw(canvas)
    x = SUPER * 2
    for ch, w in zip(text, widths):
        d.text((x, SUPER - top), ch, font=font, fill=255)
        x += w + TRACKING * SUPER
    small = canvas.resize((canvas.width // SUPER, canvas.height // SUPER), Image.BOX)
    mask = np.array(small) > 110
    cols = np.nonzero(mask.any(0))[0]
    rows = np.nonzero(mask.any(1))[0]
    return mask[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def sprig(length, flip):
    """A laurel branch: a curving stem with alternate pointed leaves, shaded and outlined like the letters, growing
    outwards from the name and sweeping up at its tip."""
    w, h = length + 14, 40
    leaf = np.zeros((h, w), np.uint8)
    stem = []
    for i in range(length):
        t = i / (length - 1)
        stem.append((i + 4.0, h - 12.0 - 18.0 * t ** 1.8))
    for k, (sx, sy) in enumerate(stem[:-3]):
        leaf[int(round(sy)), int(round(sx))] = 4
    # Leaves alternate above and below the stem, each leaning towards the tip, the newest smallest.
    for n, k in enumerate(range(2, length - 2, 4)):
        sx, sy = stem[k]
        nx, ny = stem[min(k + 2, length - 1)]
        along = math.atan2(ny - sy, nx - sx)
        side = -1 if n % 2 == 0 else 1
        angle = along + side * 0.75
        size = 8.5 - 3.0 * k / length
        for y in range(h):
            for x in range(w):
                dx, dy = x - sx, y - sy
                u = dx * math.cos(angle) + dy * math.sin(angle)
                v = -dx * math.sin(angle) + dy * math.cos(angle)
                if 0 <= u <= size and abs(v) <= 1.9 * math.sin(math.pi * u / size) + 0.2:
                    # The half of each leaf facing up catches the light, and so does its tip.
                    lit = v * math.cos(angle) < 0 or u > size * 0.7
                    leaf[y, x] = max(leaf[y, x], 3 if lit else 2)
    ex, ey = stem[-1]
    for j in range(4):
        x, y = int(round(ex - 2 + j)), int(round(ey - j * 0.6))
        if 0 <= y < h and 0 <= x < w:
            leaf[y, x] = 3
    solid = leaf > 0
    ring = np.zeros_like(solid)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring &= ~solid
    img = np.zeros((h, w, 4), np.uint8)
    img[ring] = (*OUTLINE, 255)
    img[leaf == 2] = (*LEAF_MID, 255)
    img[leaf == 3] = (*LEAF_LIGHT, 255)
    img[leaf == 4] = (*LEAF_DARK, 255)
    pic = Image.fromarray(img, "RGBA")
    return pic.transpose(Image.FLIP_LEFT_RIGHT) if flip else pic


def shade(mask):
    """Gold letters with a carved edge, depth below and a dark outline, as an RGBA image."""
    h, w = mask.shape
    pad = 2
    H, W = h + DEPTH + pad * 2, w + pad * 2
    body = np.zeros((H, W), bool)
    body[pad:pad + h, pad:pad + w] = mask
    depth = np.zeros_like(body)
    for d in range(1, DEPTH + 1):
        depth[d:, :] |= body[:-d, :]
    depth &= ~body
    solid = body | depth
    ring = np.zeros_like(solid)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring &= ~solid
    out = np.zeros((H, W, 4), np.uint8)
    out[ring] = (*OUTLINE, 255)
    rows = np.arange(H)[:, None].repeat(W, 1)
    out[depth & (rows % 2 == 0)] = (*DEPTH_DARK, 255)
    out[depth & (rows % 2 == 1)] = (*DEPTH_DARK, 255)
    # The depth is lit a little along its top edge, where it meets the letter face.
    above_body = np.zeros_like(depth)
    above_body[1:, :] = body[:-1, :]
    out[depth & above_body] = (*DEPTH_LIGHT, 255)
    band = np.clip(((rows - pad) * len(BANDS)) // max(1, h), 0, len(BANDS) - 1)
    for i, c in enumerate(BANDS):
        out[body & (band == i)] = (*c, 255)
    up_empty = np.zeros_like(body)
    up_empty[1:, :] = ~body[:-1, :]
    up_empty[0, :] = True
    left_empty = np.zeros_like(body)
    left_empty[:, 1:] = ~body[:, :-1]
    down_empty = np.zeros_like(body)
    down_empty[:-1, :] = ~body[1:, :]
    out[body & down_empty] = (*EDGE_LOW, 255)
    out[body & (up_empty | left_empty)] = (*EDGE_TOP, 255)
    return Image.fromarray(out, "RGBA")


def scroll(width=286, height=44, roll=13, sheet_inset=7):
    """A parchment scroll: a toned sheet between two rolled ends, each a shaded cylinder whose spiral shows at its
    top and bottom, with a fine inner border, ink outline and a soft shadow beneath."""
    W, H = width, height
    img = np.zeros((H + 3, W, 4), np.uint8)

    def put(x, y, c, a=255):
        if 0 <= x < W and 0 <= y < H + 3:
            img[y, x] = (*c, a)

    top, bottom = sheet_inset, H - sheet_inset
    left, right = roll - 3, W - roll + 3
    # The sheet: lightest across its middle, deepening towards its rolled-in edges, with faint fibres in the paper.
    tones = [(214, 186, 140), (232, 210, 168), (244, 228, 194), (251, 241, 216), (253, 246, 226)]
    rng = np.random.default_rng(7)
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            t = 1.0 - abs((y - top) / max(1, bottom - top) - 0.5) * 2.0
            edge = min(x - left, right - x)
            t = min(t, edge / 5.0)
            c = tones[min(len(tones) - 1, int(t * len(tones)))]
            if rng.random() < 0.05 and 1 < y - top < bottom - top - 1:
                c = tuple(max(0, v - 14) for v in c)
            put(x, y, c)
    for x in range(left, right + 1):
        put(x, top - 1, OUTLINE)
        put(x, bottom + 1, OUTLINE)
        # A soft shadow falls below the sheet.
        put(x, bottom + 2, (40, 24, 18), 90)
        put(x, bottom + 3, (40, 24, 18), 40)
    # A fine inner border, drawn in faded ink, with a small diamond at each end.
    border = (170, 120, 76)
    for x in range(left + 14, right - 13):
        put(x, top + 3, border)
        put(x, bottom - 3, border)
    mid = (top + bottom) // 2
    for cx in (left + 9, right - 9):
        for dy in range(-2, 3):
            w = 2 - abs(dy)
            for dx in range(-w, w + 1):
                put(cx + dx, mid + dy, (226, 160, 60) if abs(dx) + abs(dy) < 2 else (150, 92, 44))
    # The rolled ends: cylinders lit down their left third, standing taller than the sheet, with a spiral at each cap.
    shades = [(120, 80, 48), (176, 132, 86), (222, 190, 140), (240, 216, 172), (226, 198, 152), (204, 170, 122),
              (186, 148, 102), (168, 128, 84), (150, 110, 70), (134, 94, 58), (120, 80, 48)]
    for x0 in (0, W - roll):
        for y in range(2, H - 1):
            for i in range(roll):
                put(x0 + i, y, shades[int(i * len(shades) / roll)])
        for y in range(2, H - 1):
            put(x0, y, OUTLINE)
            put(x0 + roll - 1, y, OUTLINE)
        for cap_y, step in ((2, 1), (H - 2, -1)):
            # Each cap is a flat ellipse of rolled paper with its spiral drawn in.
            for i in range(1, roll - 1):
                put(x0 + i, cap_y - step, OUTLINE)
                put(x0 + i, cap_y, (244, 228, 194))
                put(x0 + i, cap_y + step, (214, 186, 140))
            put(x0, cap_y, (0, 0, 0), 0)
            put(x0 + roll - 1, cap_y, (0, 0, 0), 0)
        for i in range(roll):
            put(x0 + i, H + 1, (40, 24, 18), 80)
    # Gold knobs crown the rod at both ends of each roll, as on a Roman scroll.
    knob_rows = ["...X...", "..XaX..", ".XabbX.", "XabbbcX", ".XbccX.", "..XXX.."]
    knob_colours = {"X": OUTLINE, "a": (255, 240, 186), "b": (240, 186, 82), "c": (196, 120, 40)}
    knob = len(knob_rows) - 1
    out = np.zeros((H + 3 + 2 * knob, W, 4), np.uint8)
    out[knob:knob + H + 3] = img
    for x0 in (0, W - roll):
        cx = x0 + roll // 2 - 3
        for k, row in enumerate(knob_rows):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                c = knob_colours[ch]
                out[k + 2, cx + i] = (*c, 255)
                # The lower knob is the same one turned over, lit the same way from above.
                below = knob + H - 3 + (len(knob_rows) - 1 - k)
                out[below, cx + i] = (*(knob_colours["b"] if ch == "a" else c), 255)
    return Image.fromarray(out, "RGBA")


def main():
    lines = [shade(glyph_line(t)) for t in LINES]
    width = max(l.width for l in lines)
    sprig_len = 34
    total_w = width + 2 * (sprig_len + 4)
    total_h = sum(l.height for l in lines) + LINE_GAP + 12
    logo = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    y = 3
    tops = []
    for l in lines:
        logo.alpha_composite(l, ((total_w - l.width) // 2, y))
        tops.append((y, l))
        y += l.height + LINE_GAP
    # The name alone, without the laurel, for pictures too narrow for it.
    logo.crop(logo.getbbox()).save(PLAIN_OUT)
    # A sprig grows out from each side of the second line, the way a victor's laurel frames a name.
    y2, second = tops[1]
    left = sprig(sprig_len, True)
    right = sprig(sprig_len, False)
    mid = y2 + second.height - left.height + 6
    logo.alpha_composite(left, ((total_w - second.width) // 2 - left.width + 2, mid))
    logo.alpha_composite(right, ((total_w + second.width) // 2 - 2, mid))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    logo.save(OUT)
    scroll().save(SCROLL_OUT)
    print(f"logo: {OUT} ({logo.width} x {logo.height} game pixels), and {SCROLL_OUT.name}")


if __name__ == "__main__":
    main()
