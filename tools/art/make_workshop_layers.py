"""Cuts the workshop's furniture out of the inpainted rooms, one layer a piece, so the game can light each up on hover.

Run: python tools/art/make_workshop_layers.py [--debug OUT.png] [--redo-wide]
Reads tools/art/sources/workshop/ (made by make_workshop.sh); writes game/assets/art/workshop/room.png, a picture per
piece, and layers.json with where each sits. Only the pixels that really changed are kept, so the wall around a piece
stays the empty room's wall and no patch shows where the painting was done.

The room carries on past the painting at the sides, above and below, painted once by PixelLab into wide.png, which is
kept; --redo-wide paints it again (it costs about 50 cents).
"""
import base64
import io
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

import pixellab

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/art/sources"
D = SRC / "workshop"
OUT = ROOT / "game/assets/art/workshop"
SCALE = 2
PAD = 2
# Each piece: the painting it was made in and the mask it was painted through. Later pieces sit on top.
PIECES = [
    ("board", "step1", ["board"]),
    ("shelves", "step2", ["shelves"]),
    ("table", "step4", ["table"]),
    ("scrolls", "step5", ["scrolls"]),
    ("bed", "step8", ["bed"]),
    ("bench", "step7", ["bench2"]),
    ("amphorae", "up_amphorae", ["amphorae"]),
    ("plants", "up_plants", ["plants"]),
    ("lamps", "up_lamps", ["lamp_a", "lamp_b"]),
]
THRESHOLD = 26
# The lamps' flames in room pixels (half the FLAMES in workshop.gd), and how far their glow reaches. The hanging lamp is
# all glow below its chain, so unlit only the chain is left.
FLAMES = [(54, 63, "stand"), (162, 28, "hanging")]
FLAME_REACH = 8
# The painting came back with blank edges, filled from their neighbours (the floor carried down at the bottom).
FLOOR_END = 132
EDGE = 2
# Each painting also nudged the wall and the pieces beside it, so every piece is cut to its own frame.
CLIP = {
    "board": (60, 29, 100, 78),
    "shelves": (102, 44, 145, 106),
    "table": (60, 98, 133, 136),
    "scrolls": (146, 32, 173, 75),
    "bed": (136, 108, 190, 136),
    "bench": (166, 62, 215, 111),
    "plants": (144, 78, 168, 108),
}
# The outline and the clickable area of each piece, traced by hand in room pixels, since the paintings also changed
# the shadows, wall and floor around each piece. Rectangles are (left, top, right, bottom), right and bottom excluded.
SHAPES = {
    "board": [("rect", 60, 37, 100, 77), ("rect", 65, 32, 67, 37), ("rect", 94, 32, 96, 37)],
    "shelves": [("rect", 105, 46, 143, 101)],
    "scrolls": [("rect", 149, 33, 173, 70)],
    "bench": [("rect", 170, 84, 215, 111), ("rect", 170, 68, 180, 80), ("rect", 182, 69, 209, 80)],
    "table": [("rect", 62, 100, 134, 127), ("rect", 62, 127, 70, 132), ("rect", 118, 127, 134, 132)],
    "bed": [("ellipse", 140, 109, 186, 131)],
}


# How far the room carries on past the painting, in room pixels: enough for a 21:9 screen. The ceiling at the top fades
# into the dark instead.
SIDE = 52
BELOW = 16
WIDE_WORDS = ("more of the same cozy Roman workshop room carrying on: plain warm plaster walls with a red painted band "
              "along their foot, terracotta tiled floor, dark wooden ceiling beams above, plain and empty, no furniture, "
              "no doors, no windows, seen straight on from the front, warm cozy pixel art, same style and light as the room")


def grow(mask, n=1):
    return cv2.dilate(mask.astype(np.uint8), np.ones((2 * n + 1, 2 * n + 1), np.uint8)) > 0


def paint_tile(img, rect, mask, words, fill=True):
    """Repaints the mask's part of one tile of the picture through PixelLab, without the rest of the room as context,
    since with it PixelLab paints small copies of the room into the area. The tile holds the room's own pixels beside
    the area, so PixelLab carries on what it sees; a new area is first filled with the average colour round it, and a
    join is repainted over what is there."""
    x0, y0, x1, y1 = rect
    tile = img[y0:y1, x0:x1].copy()
    m = mask[y0:y1, x0:x1]
    if fill:
        tile[m] = tile[grow(m, 2) & ~m].mean(axis=0).astype(np.uint8)
    r = pixellab.call("POST", "/inpaint-image-pro-flash", {
        "image": pixellab.png_b64(Image.fromarray(tile)),
        "mask_image": pixellab.png_b64(Image.fromarray((m * 255).astype(np.uint8)).convert("RGB")),
        "description": words, "no_background": False, "output_method": "Modify current layer"})
    job = pixellab.wait(r["background_job_id"]) if "background_job_id" in r else r
    data = pixellab.first_image(job.get("last_response", job))
    if not data:
        sys.exit(json.dumps(job)[:1500])
    out = np.array(Image.open(io.BytesIO(base64.b64decode(data))).convert("RGB").resize((x1 - x0, y1 - y0), Image.NEAREST))
    img[y0:y1, x0:x1][m] = out[m]
    print(f"painted {rect}")


def box(shape, x0, y0, x1, y1):
    m = np.zeros(shape, bool)
    m[y0:y1, x0:x1] = True
    return m


def widen(empty):
    """The empty room with its margins painted, cached in wide.png; the painting itself is always laid in again.
    The left margin is painted whole, which brings a wall and a corner like the room's own beside the doorway's stone
    post; painted a band at a time it came back as a flat pillar. The right margin and the floor below are painted a
    band at a time outwards, each tile reaching back over what is painted, so the sunlit wall and the tiles run on."""
    h, w = empty.shape[:2]
    W, H = w + 2 * SIDE, h + BELOW
    cached = D / "wide.png"
    if "--redo-wide" in sys.argv or not cached.exists():
        before = pixellab.balance()
        wide = np.zeros((H, W, 3), np.uint8)
        wide[:h, SIDE:SIDE + w] = empty
        paint_tile(wide, (0, 0, SIDE + 76, h), box(wide.shape, 0, 0, SIDE, h), WIDE_WORDS)
        for x in (SIDE + w + 16, SIDE + w + 32, W):
            paint_tile(wide, (x - 64, 0, x, h), box(wide.shape, x - 16 if x < W else SIDE + w + 32, 0, x, h), WIDE_WORDS)
        for tx in (0, W // 2 - 8):
            paint_tile(wide, (tx, H - 64, tx + W // 2 + 8, H), box(wide.shape, tx and W // 2, h, tx + W // 2 + 8, H), WIDE_WORDS)
        # The joins: the floor under the doorway's post, where the left margin meets the floor below, and the middle
        # of the floor below, each painted again over what is there with both sides in the tile.
        paint_tile(wide, (SIDE - 32, H - 64, SIDE + 32, H), box(wide.shape, SIDE - 8, h - 24, SIDE, H), WIDE_WORDS, fill=False)
        paint_tile(wide, (0, H - 48, 64, H), box(wide.shape, 0, h - 6, SIDE, h + 8), WIDE_WORDS, fill=False)
        paint_tile(wide, (W // 2 - 32, H - 64, W // 2 + 32, H), box(wide.shape, W // 2 - 8, h, W // 2 + 8, H), WIDE_WORDS, fill=False)
        wide[:h, SIDE:SIDE + w] = empty
        # PixelLab paints in steps of four pixels, so a row below the last whole step takes the row above's colours.
        for y in range(H // 4 * 4, H):
            wide[y] = wide[y - 1]
        Image.fromarray(wide).save(cached)
        pixellab.record("inpaint", str(cached.relative_to(ROOT)), before, pixellab.balance())
    wide = np.array(Image.open(cached).convert("RGB"))
    wide[:h, SIDE:SIDE + w] = empty
    return wide


def flames_mask(painted, empty):
    """What shows only while the lamps are lit: each flame and the glow painted round it on the wall."""
    ys, xs = np.mgrid[0:empty.shape[0], 0:empty.shape[1]]
    bright = painted.astype(np.int16).sum(axis=2)
    lit = np.zeros(empty.shape[:2], bool)
    for fx, fy, kind in FLAMES:
        near = (xs - fx) ** 2 + (ys - fy) ** 2 <= FLAME_REACH ** 2
        if kind == "stand":
            lit |= near & (bright > 470) & (bright - empty.astype(np.int16).sum(axis=2) > 30)
        else:
            lit |= near & (ys >= fy - 2)
    return lit


def load(name):
    return np.asarray(Image.open(D / f"{name}.png").convert("RGB")).astype(np.int16)


def silhouette(painted, empty, area):
    diff = np.abs(painted - empty).max(axis=2)
    keep = ((diff > THRESHOLD) & area).astype(np.uint8)
    keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(keep, 8)
    largest = max([stats[i][4] for i in range(1, n)], default=0)
    for i in range(1, n):
        if stats[i][4] < max(12, largest * 0.08):
            keep[labels == i] = 0
    # Holes inside a piece are pixels that happen to match the wall; they belong to the piece.
    flood = keep.copy()
    h, w = flood.shape
    cv2.floodFill(flood, np.zeros((h + 2, w + 2), np.uint8), (0, 0), 1)
    keep = keep | (1 - flood)
    return (keep > 0) & area


def sky_and_sun(empty, margins=False):
    """Where the sky shows through the door and window, cut out so the game can draw its own; and how sunlit each
    pixel of wall and floor is, from 0 to 255, so the sunlight can fade at night."""
    r, g, b = empty[..., 0], empty[..., 1], empty[..., 2]
    sky = ((b > r + 35) & (b > 140)).astype(np.uint8)
    # Closing takes in the painted white specks of cloud, but must not swallow the dark glazing bars between panes.
    sky = (cv2.morphologyEx(sky, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0) & (0.299 * r + 0.587 * g + 0.114 * b > 90)
    light = 0.299 * r + 0.587 * g + 0.114 * b
    h = empty.shape[0]
    rows = np.arange(h)[:, None]
    # The back wall ends where the floor starts; the two are lit to different brightness, so each has its own scale.
    wall = np.clip((light - 190.0) / 35.0, 0.0, 1.0)
    floor = np.clip((light - 125.0) / 35.0, 0.0, 1.0) * (r > 180)
    sun = np.where(rows < 102, wall, floor)
    if margins:
        return sky, sun * 255
    sun[14:117, 8:31] = 0
    sun[:4] = 0
    sun[16:54, 170:212] = 0
    return sky, sun * 255


def shape_mask(name, size):
    """The hand-traced shape of a piece as a mask over the whole room."""
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for kind, x0, y0, x1, y1 in SHAPES[name]:
        if kind == "rect":
            d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=255)
        else:
            d.ellipse((x0, y0, x1 - 1, y1 - 1), fill=255)
    return np.asarray(mask) > 127


def main():
    empty = np.asarray(Image.open(SRC / "workshop_bg.png").convert("RGB")).astype(np.int16).copy()
    empty[FLOOR_END:] = empty[FLOOR_END - (empty.shape[0] - FLOOR_END):FLOOR_END]
    empty[:EDGE] = empty[EDGE]
    empty[:, :EDGE] = empty[:, EDGE:EDGE + 1]
    empty[:, -EDGE:] = empty[:, -EDGE - 1:-EDGE]
    OUT.mkdir(parents=True, exist_ok=True)
    h, w = empty.shape[:2]
    wide = widen(empty.astype(np.uint8)).astype(np.int16)
    inside = (slice(0, h), slice(SIDE, SIDE + w))
    sky, sun = sky_and_sun(empty)
    # The margins are lit by the same rule as the painting, reading the wall and floor from the wide room's own rows.
    _, wide_sun = sky_and_sun(wide, margins=True)
    wide_sun[inside] = sun
    wide_sky = np.zeros(wide.shape[:2], bool)
    wide_sky[inside] = sky
    room = np.dstack([wide.astype(np.uint8), np.where(wide_sky, 0, 255).astype(np.uint8)])
    size = (wide.shape[1] * SCALE, wide.shape[0] * SCALE)
    Image.fromarray(room, "RGBA").resize(size, Image.NEAREST).save(OUT / "room.png")
    # The light map: red is painted sunlight, which fades at night; green is the view outdoors, which lamps don't reach.
    outside = np.zeros(wide_sun.shape, np.uint8)
    outside[14:117, SIDE + 8:SIDE + 31] = 255
    outside[23:47, SIDE + 181:SIDE + 202] = 255
    light_map = np.dstack([wide_sun.astype(np.uint8), outside, np.zeros(wide_sun.shape, np.uint8)])
    Image.fromarray(light_map, "RGB").resize(size, Image.NEAREST).save(OUT / "room_sun.png")
    # The room's own place is kept with the pieces', which are all measured from the painting's corner.
    layers = {"room": [-SIDE * SCALE, 0, size[0], size[1]]}
    debug = empty.copy()
    for name, painting, masks in PIECES:
        area = np.zeros(empty.shape[:2], bool)
        for m in masks:
            area |= np.asarray(Image.open(D / f"mask_{m}.png").convert("L")) > 127
        if name in CLIP:
            x0, y0, x1, y1 = CLIP[name]
            clip = np.zeros_like(area)
            clip[y0:y1, x0:x1] = True
            area &= clip
        area[FLOOR_END:] = False
        area[:EDGE] = False
        area[:, :EDGE] = False
        area[:, -EDGE:] = False
        painted = load(painting)
        keep = silhouette(painted, empty, area)
        shape = shape_mask(name, (empty.shape[1], empty.shape[0])) if name in SHAPES else None
        ys, xs = np.nonzero(keep if shape is None else keep | shape)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        rgba = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        rgba[..., :3] = painted[y0:y1, x0:x1]
        rgba[..., 3] = keep[y0:y1, x0:x1] * 255
        if name == "lamps":
            # The flames and their glow go in a layer of their own, so the game shows them only while the lamps are
            # lit; unlit, the bare wall shows round each lamp.
            lit = flames_mask(painted, empty) & keep
            flame = rgba.copy()
            flame[..., 3] = lit[y0:y1, x0:x1] * 255
            save_padded(flame, x1 - x0, y1 - y0, OUT / "lamps_flame.png")
            rgba[..., 3] = (keep & ~lit)[y0:y1, x0:x1] * 255
        save_padded(rgba, x1 - x0, y1 - y0, OUT / f"{name}.png")
        if shape is not None:
            outline = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
            outline[..., 3] = shape[y0:y1, x0:x1] * 255
            save_padded(outline, x1 - x0, y1 - y0, OUT / f"{name}_shape.png")
        layers[name] = [int(x0) * SCALE - PAD, int(y0) * SCALE - PAD, int(x1 - x0) * SCALE + 2 * PAD, int(y1 - y0) * SCALE + 2 * PAD]
        debug[keep] = painted[keep]
        print(f"{name}: {keep.sum()} pixels at {layers[name]}")
    (OUT / "layers.json").write_text(json.dumps(layers, indent=1))
    basket_front()
    if "--outlines" in sys.argv:
        show_outlines(sys.argv[sys.argv.index("--outlines") + 1])
    if "--debug" in sys.argv:
        Image.fromarray(debug.astype(np.uint8)).resize((empty.shape[1] * 6, empty.shape[0] * 6), Image.NEAREST).save(sys.argv[sys.argv.index("--debug") + 1])



def basket_front():
    """The basket's woven front wall, everything below the blanket, drawn over the dog so it lies inside the basket."""
    bed = np.asarray(Image.open(OUT / "bed.png").convert("RGBA")).copy()
    rgb = bed[..., :3].astype(np.int16)
    # The blanket's reds have hardly any green; the wicker's reddish browns all have more.
    blanket = (rgb[..., 1] < 60) & (rgb[..., 0] - rgb[..., 1] > 70) & (bed[..., 3] > 0)
    rows = np.nonzero(blanket.any(axis=1))[0]
    middle = int(rows.mean())
    ys = np.arange(bed.shape[0])[:, None]
    lowest = np.where(blanket.any(axis=0), bed.shape[0] - 1 - np.argmax(blanket[::-1], axis=0), middle)
    # Smoothed across neighbouring columns, so a stray red stitch low in the wicker leaves no gap in the wall.
    padded = np.pad(lowest, 4, mode="edge")
    lowest = np.array([int(np.median(padded[x:x + 9])) for x in range(lowest.size)])
    front = ys > lowest[None, :]
    bed[..., 3] = np.where(front, bed[..., 3], 0)
    Image.fromarray(bed, "RGBA").save(OUT / "bed_front.png")


def save_padded(rgba, w, h, path):
    # A clear margin round each piece leaves room for the outline drawn when the mouse is over it.
    im = Image.fromarray(rgba, "RGBA").resize((w * SCALE, h * SCALE), Image.NEAREST)
    padded = Image.new("RGBA", (im.width + 2 * PAD, im.height + 2 * PAD), (0, 0, 0, 0))
    padded.paste(im, (PAD, PAD))
    padded.save(path)


def show_outlines(path):
    """The furnished room with every traced shape outlined, for checking the tracing by eye."""
    room = Image.open(OUT / "room.png").convert("RGBA")
    layers = json.loads((OUT / "layers.json").read_text())
    dx, dy = -layers["room"][0], -layers["room"][1]
    for name in [n for n in layers if n != "room"]:
        room.alpha_composite(Image.open(OUT / f"{name}.png").convert("RGBA"), (layers[name][0] + dx, layers[name][1] + dy))
    pic = np.asarray(room).copy()
    for name in SHAPES:
        a = np.asarray(Image.open(OUT / f"{name}_shape.png"))[..., 3] > 127
        x, y = layers[name][0] + dx, layers[name][1] + dy
        edge = np.zeros_like(a)
        edge[1:-1, 1:-1] = ~a[1:-1, 1:-1] & (a[:-2, 1:-1] | a[2:, 1:-1] | a[1:-1, :-2] | a[1:-1, 2:])
        ys, xs = np.nonzero(edge)
        ok = (ys + y < pic.shape[0]) & (xs + x < pic.shape[1])
        pic[ys[ok] + y, xs[ok] + x] = [255, 230, 120, 255]
    Image.fromarray(pic).resize((pic.shape[1] * 3, pic.shape[0] * 3), Image.NEAREST).save(path)


if __name__ == "__main__":
    main()
