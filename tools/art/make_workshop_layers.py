"""Cuts the workshop's furniture out of the inpainted rooms, one layer a piece, so the game can light each up on hover.

Run: python tools/art/make_workshop_layers.py [--debug OUT.png]
Reads tools/art/sources/workshop/ (made by make_workshop.sh); writes game/assets/art/workshop/room.png, a picture per
piece, and layers.json with where each sits. Only the pixels that really changed are kept, so the wall around a piece
stays the empty room's wall and no patch shows where the painting was done.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

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


def sky_and_sun(empty):
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
    sky, sun = sky_and_sun(empty)
    room = np.dstack([empty.astype(np.uint8), np.where(sky, 0, 255).astype(np.uint8)])
    Image.fromarray(room, "RGBA").resize((empty.shape[1] * SCALE, empty.shape[0] * SCALE), Image.NEAREST).save(OUT / "room.png")
    # The light map: red is painted sunlight, which fades at night; green is the view outdoors, which lamps don't reach.
    outside = np.zeros(sun.shape, np.uint8)
    outside[14:117, 8:31] = 255
    outside[23:47, 181:202] = 255
    light_map = np.dstack([sun.astype(np.uint8), outside, np.zeros(sun.shape, np.uint8)])
    Image.fromarray(light_map, "RGB").resize((empty.shape[1] * SCALE, empty.shape[0] * SCALE), Image.NEAREST).save(OUT / "room_sun.png")
    layers = {}
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
        save_padded(rgba, x1 - x0, y1 - y0, OUT / f"{name}.png")
        if shape is not None:
            outline = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
            outline[..., 3] = shape[y0:y1, x0:x1] * 255
            save_padded(outline, x1 - x0, y1 - y0, OUT / f"{name}_shape.png")
        layers[name] = [int(x0) * SCALE - PAD, int(y0) * SCALE - PAD, int(x1 - x0) * SCALE + 2 * PAD, int(y1 - y0) * SCALE + 2 * PAD]
        debug[keep] = painted[keep]
        print(f"{name}: {keep.sum()} pixels at {layers[name]}")
    (OUT / "layers.json").write_text(json.dumps(layers, indent=1))
    if "--outlines" in sys.argv:
        show_outlines(sys.argv[sys.argv.index("--outlines") + 1])
    if "--debug" in sys.argv:
        Image.fromarray(debug.astype(np.uint8)).resize((empty.shape[1] * 6, empty.shape[0] * 6), Image.NEAREST).save(sys.argv[sys.argv.index("--debug") + 1])



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
    for name in layers:
        room.alpha_composite(Image.open(OUT / f"{name}.png").convert("RGBA"), tuple(layers[name][:2]))
    pic = np.asarray(room).copy()
    for name in SHAPES:
        a = np.asarray(Image.open(OUT / f"{name}_shape.png"))[..., 3] > 127
        x, y = layers[name][:2]
        edge = np.zeros_like(a)
        edge[1:-1, 1:-1] = ~a[1:-1, 1:-1] & (a[:-2, 1:-1] | a[2:, 1:-1] | a[1:-1, :-2] | a[1:-1, 2:])
        ys, xs = np.nonzero(edge)
        ok = (ys + y < pic.shape[0]) & (xs + x < pic.shape[1])
        pic[ys[ok] + y, xs[ok] + x] = [255, 230, 120, 255]
    Image.fromarray(pic).resize((pic.shape[1] * 3, pic.shape[0] * 3), Image.NEAREST).save(path)


if __name__ == "__main__":
    main()
