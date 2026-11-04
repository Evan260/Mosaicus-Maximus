"""Draws the test floor's design as a colour map: one pixel colour per stone, six pixels to a tile.

Run: python tools/make_test_design.py
Writes game/designs/test_floor.png, which the game turns into tiles.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "designs" / "test_floor.png"

P = 6  # design pixels per tile
W, H = 100, 70  # floor size in tiles

# These exact colours are the stones the game knows; see STONES in game/scripts/stones.gd.
CREAM = (226, 214, 188)
BLACK = (44, 40, 42)
WHITE = (240, 236, 226)
TERRA = (168, 86, 54)
RED = (146, 50, 46)
OCHRE = (200, 148, 66)
GREEN = (86, 112, 70)
BLUE = (54, 92, 136)
GOLD = (212, 174, 74)

ys, xs = np.mgrid[0:H * P, 0:W * P]
x = (xs + 0.5) / P
y = (ys + 0.5) / P
img = np.zeros((H * P, W * P, 3), np.uint8)
img[:] = CREAM


def paint(mask, colour):
    img[mask] = colour


inset = np.minimum(np.minimum(x, W - x), np.minimum(y, H - y))

# The frame: a black line, a white band carrying a black key pattern, and another black line.
paint((inset >= 3) & (inset < 4), BLACK)
band = (inset >= 4) & (inset < 11)
paint(band, WHITE)
along = np.where(np.minimum(y, H - y) <= np.minimum(x, W - x), x, y)
s = np.mod(along - 4, 8)
top = (inset >= 5) & (inset < 6) & (s < 5)
bottom = (inset >= 9) & (inset < 10) & ((s >= 4) | (s < 1))
upright = (inset >= 5) & (inset < 10) & ((s < 1) | ((s >= 4) & (s < 5)))
corner = ((x < 11) | (x > W - 11)) & ((y < 11) | (y > H - 11))
paint(band & ~corner & (top | bottom | upright), BLACK)
cx = np.where(x < W / 2, x, W - x)
cy = np.where(y < H / 2, y, H - y)
ring = corner & (np.maximum(np.abs(cx - 7.5), np.abs(cy - 7.5)) < 2.5) & (np.maximum(np.abs(cx - 7.5), np.abs(cy - 7.5)) >= 1.5)
paint(ring, BLACK)
paint(corner & (np.maximum(np.abs(cx - 7.5), np.abs(cy - 7.5)) < 0.5 + 0.5), TERRA)
paint((inset >= 11) & (inset < 12), BLACK)

# The medallion: black rings around a crest of blue waves, and a rosette at the centre.
mx, my = W / 2, H / 2
r = np.hypot(x - mx, y - my)
th = np.arctan2(y - my, x - mx)
paint((r >= 20) & (r < 21), BLACK)
paint((r >= 15.5) & (r < 20), WHITE)
phase = np.mod(th * 16 / (2 * np.pi), 1.0)
crest = np.where(phase < 0.72, (phase / 0.72) ** 1.6, 1 - (phase - 0.72) / 0.28)
paint((r >= 15.5) & (r < 15.5 + 1.2 + 3.0 * crest), BLUE)
paint((r >= 14.5) & (r < 15.5), BLACK)
paint(r < 14.5, WHITE)
rho = 12.5 * np.abs(np.cos(4 * th)) ** 0.7
petal = np.mod(np.round(th / (np.pi / 4)), 2) == 0
paint((r < rho) & petal, RED)
paint((r < rho) & ~petal, OCHRE)
paint((r < rho * 0.5) & petal, OCHRE)
paint((r < rho * 0.5) & ~petal, RED)
paint(r < 3.5, TERRA)
paint(r < 2.5, GOLD)

# Ivy leaves in the corners of the inner field, outlined in black and pointing outward.
for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
    lx = W / 2 - sx * (W / 2 - 20)
    ly = H / 2 - sy * (H / 2 - 20)
    ux, uy = -sx / np.sqrt(2), -sy / np.sqrt(2)
    u = (x - lx) * ux + (y - ly) * uy
    v = -(x - lx) * uy + (y - ly) * ux
    t = (u + 3.5) / 9.0
    width = 3.4 * np.sin(np.pi * np.clip(t, 0, 1)) ** 0.75 * (1 - 0.35 * t)
    leaf = (t > 0) & (t < 1) & (np.abs(v) < width)
    t2 = (u + 2.4) / 7.0
    inner = (t2 > 0) & (t2 < 1) & (np.abs(v) < 3.4 * np.sin(np.pi * np.clip(t2, 0, 1)) ** 0.75 * (1 - 0.35 * t2) - 1.0)
    paint(leaf, BLACK)
    paint(inner, GREEN)

# Two dolphins arching beside the medallion, each facing it.
for side in (-1, 1):
    ax = W / 2 + side * 30.5
    ay = H / 2 + 7.0
    R = 8.0
    dx, dy = (x - ax) * -side, y - ay
    ang = np.arctan2(-dy, dx)  # 0 at the front, pi/2 straight up
    rad = np.hypot(dx, dy)
    t = (np.pi * 0.92 - ang) / (np.pi * 0.84)  # 0 at the tail, 1 at the snout
    body_r = 0.45 + 2.5 * np.sin(np.pi * np.clip(t * 0.62 + 0.12, 0, 1)) ** 0.7
    body_r = np.where(t > 0.88, 0.6 + (1 - t) * 9, body_r)
    body = (t >= 0) & (t <= 1) & (np.abs(rad - R) < body_r)
    belly = body & (rad - R < -0.2) & (t > 0.2) & (t < 0.85)
    tail_x = ax - side * R * np.cos(np.pi * 0.92)
    tail_y = ay - R * np.sin(np.pi * 0.92)
    tx, ty = (x - tail_x) * -side, y - tail_y
    fluke = (ty > -0.2) & (ty < 3.2) & (np.abs(tx + 0.3 * ty) < 0.4 + 0.9 * ty) & (np.abs(tx + 0.3 * ty) > 0.45 * ty - 0.4)
    fin_t = (ang > np.pi * 0.48) & (ang < np.pi * 0.62)
    fin = fin_t & (rad > R) & (rad < R + 2.2 + 3.5 * (ang - np.pi * 0.48)) & (rad - R < 4.2 - 9 * np.abs(ang - np.pi * 0.52))
    eye_a = np.pi * 0.92 - 0.8 * np.pi * 0.84
    eye_x = ax - side * R * np.cos(eye_a)
    eye_y = ay - (R + 0.6) * np.sin(eye_a)
    paint(body | fluke | fin, BLUE)
    paint(belly, WHITE)
    paint(np.hypot(x - eye_x, y - eye_y) < 0.75, BLACK)

OUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(img).save(OUT)
print(OUT, img.shape[1], "x", img.shape[0])
