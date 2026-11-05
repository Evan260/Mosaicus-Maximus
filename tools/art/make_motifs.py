"""Makes the pattern book: every motif as a picture of numbered colour areas ("roles") the player can give stones to.

Run: python tools/art/make_motifs.py
Geometric motifs and the guard dog are drawn here. Other figures come from PixelLab pictures in
tools/art/motif_sources, reduced to a few flat colours. Writes game/assets/art/motifs/*.png and game/data/motifs.json.
Role colours: 1 red, 2 green, 3 blue, 4 yellow, 5 magenta, 6 cyan; clear pixels lay no tile.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "tools" / "art" / "motif_sources"
OUT = ROOT / "game" / "assets" / "art" / "motifs"
DATA = ROOT / "game" / "data" / "motifs.json"
ROLE_RGB = [(0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0), (255, 0, 255), (0, 255, 255)]
N = 128

# id, name, tier, tags, default stones per role, cost per tile, smallest and largest size in tiles, outline stone
GEOMETRIC = [
    ("rosette", "Rosette", 1, ["geometric", "garden"], ["black_stone", "grey_stone", "white_marble", "black_stone"], 1.0),
    ("star", "Eight-point star", 1, ["geometric"], ["black_stone", "white_marble", "grey_stone", "black_stone"], 1.0),
    ("wheel", "Wheel", 1, ["geometric", "games"], ["black_stone", "white_marble", "grey_stone", "black_stone"], 1.0),
    ("lozenge", "Lozenge", 1, ["geometric"], ["black_stone", "grey_stone", "white_marble", "black_stone"], 0.9),
    ("knot", "Solomon's knot", 1, ["geometric", "luck"], ["black_stone", "grey_stone", "white_marble", "black_stone"], 1.1),
    ("roundel", "Roundel frame", 1, ["frame"], ["black_stone", "white_marble", "grey_stone", "black_stone"], 0.8),
    ("square_frame", "Square frame", 1, ["frame"], ["black_stone", "white_marble", "grey_stone", "black_stone"], 0.8),
    ("flower", "Four-petal flower", 2, ["garden", "geometric"], ["red_marble", "green_marble", "ochre_marble", "terracotta"], 1.0),
    ("shell", "Scallop shell", 2, ["sea"], ["pink_marble", "terracotta", "ochre_marble", "brown_stone"], 1.1),
    ("pelta", "Pelta shield", 2, ["geometric", "myth"], ["terracotta", "black_stone", "ochre_marble", "red_marble"], 1.0),
    ("wave_ring", "Ring of waves", 2, ["sea", "frame"], ["blue_glass", "white_marble", "black_stone", "blue_glass"], 1.2),
    ("sun", "Sunburst", 4, ["myth", "geometric"], ["gold", "yellow_marble", "ochre_marble", "terracotta"], 1.6),
]
FIGURES = [
    ("dog", "Guard dog", 1, ["guard", "animals"]),
    ("dolphin", "Dolphin", 1, ["sea", "animals"]),
    ("fish", "Fish", 1, ["sea", "feast", "animals"]),
    ("dove", "Dove", 2, ["garden", "animals"]),
    ("loaves", "Loaves", 2, ["feast", "bread"]),
    ("amphora", "Amphora", 2, ["feast", "wine"]),
    ("duck", "Duck", 2, ["garden", "animals", "sea"]),
    ("hare", "Hare", 2, ["garden", "hunt", "animals"]),
    ("lion", "Lion", 3, ["hunt", "animals", "myth"]),
    ("stag", "Stag", 3, ["hunt", "animals"]),
    ("horse", "Horse", 3, ["hunt", "animals", "games"]),
    ("boat", "Ship", 3, ["sea", "trade"]),
    ("grapes", "Grapes", 3, ["feast", "wine", "garden"]),
    ("lyre", "Lyre", 3, ["music", "myth"]),
    ("octopus", "Octopus", 3, ["sea", "animals"]),
    ("peacock", "Peacock", 4, ["garden", "animals", "myth"]),
    ("medusa", "Medusa", 4, ["myth", "luck"]),
    ("lobster", "Lobster", 4, ["sea", "feast"]),
]
# Colours set by hand where the nearest stone gets them wrong: purple grapes, a bay horse, a clay amphora.
OVERRIDES = {"grapes": {1: "wine_marble", 2: "red_marble"}, "dolphin": {2: "white_marble"},
             "horse": {1: "brown_stone", 2: "terracotta", 5: "red_marble"}, "amphora": {1: "terracotta"}}
# Pictures drawn so dark that they would merge with their black outline, so their light and shade are spread out first.
DARK = {"amphora", "horse", "peacock"}
STONES = {
    "limestone": ((224, 210, 180), 1), "black_stone": ((50, 46, 48), 1), "white_marble": ((240, 234, 222), 1),
    "grey_stone": ((140, 134, 126), 1), "terracotta": ((172, 88, 56), 2), "red_marble": ((152, 54, 48), 2),
    "ochre_marble": ((206, 152, 70), 2), "green_marble": ((90, 118, 74), 2), "brown_stone": ((116, 80, 54), 2),
    "pink_marble": ((226, 172, 144), 3), "wine_marble": ((110, 38, 38), 3), "yellow_marble": ((230, 204, 104), 3),
    "blue_glass": ((50, 96, 150), 4), "turquoise_glass": ((60, 156, 158), 4), "green_glass": ((58, 136, 80), 4),
    "gold": ((226, 186, 82), 4),
}


def grid():
    ys, xs = np.mgrid[0:N, 0:N]
    x = (xs + 0.5) / N * 2 - 1
    y = (ys + 0.5) / N * 2 - 1
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def draw_geometric(motif_id):
    x, y, r, th = grid()
    roles = np.zeros((N, N), np.uint8)
    if motif_id == "rosette":
        roles[r < 0.96] = 4
        roles[r < 0.86] = 0
        rho = 0.84 * np.abs(np.cos(4 * th)) ** 0.75
        petal = np.mod(np.round(th / (np.pi / 4)), 2) == 0
        roles[(r < rho) & petal] = 1
        roles[(r < rho) & ~petal] = 2
        roles[(r < rho * 0.45)] = 3
        roles[r < 0.16] = 1
    elif motif_id == "star":
        sq1 = np.maximum(np.abs(x), np.abs(y)) < 0.66
        xr, yr = (x + y) / np.sqrt(2), (y - x) / np.sqrt(2)
        sq2 = np.maximum(np.abs(xr), np.abs(yr)) < 0.66
        roles[sq1 | sq2] = 1
        roles[(np.maximum(np.abs(x), np.abs(y)) < 0.44) & (np.maximum(np.abs(xr), np.abs(yr)) < 0.44)] = 2
        roles[r < 0.2] = 3
    elif motif_id == "wheel":
        roles[(r < 0.95) & (r > 0.75)] = 1
        spoke = np.abs(np.sin(3 * th)) * r < 0.1
        roles[(r <= 0.75) & spoke] = 1
        roles[(r <= 0.75) & ~spoke] = 2
        roles[r < 0.26] = 1
        roles[r < 0.12] = 3
    elif motif_id == "lozenge":
        d = np.abs(x) * 0.7 + np.abs(y)
        roles[d < 0.95] = 1
        roles[d < 0.68] = 2
        roles[d < 0.38] = 3
    elif motif_id == "knot":
        for k, angle in enumerate((np.pi / 4, -np.pi / 4)):
            xr = x * np.cos(angle) + y * np.sin(angle)
            yr = -x * np.sin(angle) + y * np.cos(angle)
            e = np.hypot(xr / 0.92, yr / 0.42)
            band = (e > 0.62) & (e < 1.0)
            over = (np.sign(xr * yr) > 0) if k == 0 else (np.sign(xr * yr) <= 0)
            roles[band & ((roles == 0) | over)] = 1 + k
        roles[r < 0.12] = 3
    elif motif_id == "roundel":
        roles[(r < 1.0) & (r > 0.86)] = 1
        roles[(r <= 0.86) & (r > 0.78)] = 2
        roles[(r <= 0.78) & (r > 0.72)] = 1
    elif motif_id == "square_frame":
        m = np.maximum(np.abs(x), np.abs(y))
        roles[(m < 1.0) & (m > 0.86)] = 1
        roles[(m <= 0.86) & (m > 0.78)] = 2
        roles[(m <= 0.78) & (m > 0.72)] = 1
    elif motif_id == "flower":
        for k in range(4):
            a = k * np.pi / 2
            cx, cy = 0.45 * np.cos(a), 0.45 * np.sin(a)
            roles[np.hypot(x - cx, y - cy) < 0.43] = 1
        leaf_th = np.mod(th + np.pi / 4, np.pi / 2) - np.pi / 4
        roles[(roles == 0) & (r < 0.95) & (np.abs(leaf_th - 0) > 0.5) & (r > 0.55) & (np.abs(np.sin(2 * th + np.pi / 2)) > 0.9)] = 2
        roles[r < 0.22] = 3
        roles[r < 0.1] = 4
    elif motif_id == "shell":
        fan = (y < 0.55) & (r < 0.95) & (th < -0.05) & (th > -np.pi + 0.05)
        yy = y - 0.55
        rr = np.hypot(x, yy)
        tt = np.arctan2(yy, x)
        fan = (rr < 1.35) & (yy < 0) & (tt > -np.pi + 0.35) & (tt < -0.35)
        rib = np.mod(np.floor((tt + np.pi) / (np.pi / 9)), 2) == 0
        roles[fan & rib] = 1
        roles[fan & ~rib] = 2
        roles[(np.abs(x) < 0.3) & (yy >= 0) & (yy < 0.3)] = 3
    elif motif_id == "pelta":
        outer = (np.hypot(x, y + 0.15) < 0.95) & (y < 0.45)
        bite = np.hypot(x, y - 0.75) < 0.75
        roles[outer & ~bite] = 1
        for cx in (-0.48, 0.48):
            roles[np.hypot(x - cx, y + 0.2) < 0.16] = 3
        roles[(np.abs(x) < 0.12) & (y > -0.85) & (y < 0.05)] = 2
    elif motif_id == "wave_ring":
        phase = np.mod(th * 12 / (2 * np.pi), 1.0)
        crest = np.where(phase < 0.72, (phase / 0.72) ** 1.6, 1 - (phase - 0.72) / 0.28)
        ring = (r > 0.7) & (r < 0.98)
        roles[ring] = 2
        roles[ring & (r < 0.72 + 0.24 * crest)] = 1
        roles[(r >= 0.98) & (r < 1.0)] = 3
        roles[(r > 0.66) & (r <= 0.7)] = 3
    elif motif_id == "sun":
        rays = np.abs(np.sin(8 * th)) > 0.6
        roles[(r < 0.95) & rays] = 1
        roles[(r < 0.95) & ~rays & (r < 0.75)] = 2
        roles[r < 0.5] = 4
        roles[r < 0.4] = 1
    return roles


def nearest_stone(rgb, tier):
    best, best_d = None, 1e9
    for sid, (c, t) in STONES.items():
        if t > tier or sid == "limestone":
            continue
        d = sum((a - b) ** 2 for a, b in zip(rgb, c))
        if d < best_d:
            best, best_d = sid, d
    return best


def figure_roles(src, tier, dark=False):
    """A PixelLab picture redrawn in real stones: each pixel takes the nearest stone the motif's chapter allows, and
    only the five commonest stones are kept. Its thin black outline is dropped; the game adds a tile-wide one."""
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3] > 128
    smooth = np.array(Image.fromarray(arr[:, :, :3]).filter(ImageFilter.MedianFilter(3))).astype(np.float64)
    lum = arr[:, :, :3].astype(np.float64) @ np.array([0.3, 0.59, 0.11])
    outline = alpha & (lum < 42)
    # A first-chapter picture also takes the next chapter's stones, which the workshop swaps for its own when it is laid.
    palette_tier = 2 if tier <= 1 else tier
    allowed = [s for s, (c, t) in STONES.items() if t <= palette_tier and s != "limestone"]
    cols = np.array([STONES[s][0] for s in allowed], np.float64)
    weight = np.array([2.0, 4.0, 3.0])
    if dark:
        clear = ~alpha
        rim = np.zeros_like(alpha)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            rim |= np.roll(np.roll(clear, dy, axis=0), dx, axis=1)
        outline = outline & rim
        lum_in = lum[alpha & ~outline]
        ordered = np.sort(lum_in)
        rank = (np.searchsorted(ordered, lum, "left") + np.searchsorted(ordered, lum, "right")) * 0.5 / max(1, lum_in.size)
        target = 45 + np.clip(rank, 0.0, 1.0) * 170
        own = smooth @ np.array([0.3, 0.59, 0.11])
        smooth = np.clip(smooth * (target / np.maximum(own, 1.0))[:, :, None], 0, 255)
        # Pure black has no colour to brighten, so it is lifted to the same lightness in grey.
        smooth = np.clip(smooth + (target - smooth @ np.array([0.3, 0.59, 0.11]))[:, :, None], 0, 255)
    inside = alpha & ~outline
    d = (((smooth[:, :, None, :] - cols[None, None, :, :]) ** 2) * weight).sum(-1)
    nearest = np.argmin(d, axis=2)
    counts = sorted(((int(np.sum(inside & (nearest == k))), k) for k in range(len(allowed))), reverse=True)
    keep = [k for n, k in counts[:5] if n > 25]
    remap = {}
    for k in range(len(allowed)):
        if k in keep:
            remap[k] = keep.index(k) + 1
        else:
            dd = [(((cols[k] - cols[j]) ** 2) * weight).sum() for j in keep]
            remap[k] = keep[int(np.argmin(dd))] if keep else 0
            remap[k] = keep.index(remap[k]) + 1 if keep else 0
    roles = np.zeros(nearest.shape, np.uint8)
    for k, r in remap.items():
        roles[inside & (nearest == k)] = r
    stones = [allowed[k] for k in keep]
    fill = inside | outline
    for _ in range(3):
        missing = fill & (roles == 0)
        if not missing.any():
            break
        padded = np.pad(roles, 1)
        best = np.zeros_like(roles)
        best_n = np.zeros_like(roles, dtype=np.int32)
        for role in range(1, len(keep) + 1):
            n = sum((padded[1 + dy:1 + dy + roles.shape[0], 1 + dx:1 + dx + roles.shape[1]] == role).astype(np.int32)
                    for dy in (-1, 0, 1) for dx in (-1, 0, 1))
            better = n > best_n
            best[better] = role
            best_n[better] = n[better]
        roles[missing & (best > 0)] = best[missing & (best > 0)]
    roles = majority(roles, fill)
    roles = merge_specks(roles, 14)
    roles = majority(roles, fill)
    ys, xs = np.nonzero(roles)
    roles = roles[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return roles, stones


def draw_dog():
    """A Molossian guard dog in profile, drawn in shapes broad enough for whole tiles: a grey coat, the far legs in black
    so all four legs show, a red collar, and an open red mouth with white teeth. In black and white the reds turn black."""
    from PIL import ImageDraw
    w, h = 120, 84
    layers = []

    def shape(role, draw):
        layer = Image.new("L", (w * 4, h * 4), 0)
        draw(ImageDraw.Draw(layer), lambda pts: [(x * 4, y * 4) for x, y in pts])
        layers.append((role, np.array(layer.resize((w, h), Image.BOX)) > 127))

    def poly(role, pts):
        shape(role, lambda d, sc: d.polygon(sc(pts), fill=255))

    def oval(role, cx, cy, rx, ry):
        shape(role, lambda d, sc: d.ellipse(sc([(cx - rx, cy - ry), (cx + rx, cy + ry)]), fill=255))

    def band(role, a, b, width):
        shape(role, lambda d, sc: d.line(sc([a, b]), fill=255, width=int(width * 4)))

    # Shapes are painted back to front, so the far legs go first and the body covers their tops.
    poly(2, [(63, 40), (75, 42), (77, 72), (82, 80), (69, 81), (66, 72)])
    poly(2, [(36, 40), (49, 42), (46, 57), (40, 65), (42, 76), (47, 81), (34, 81), (32, 64), (36, 54)])
    shape(1, lambda d, sc: d.line(sc([(20, 30), (11, 25), (6, 15), (8, 6)]), fill=255, width=7 * 4, joint="curve"))
    oval(1, 8, 6, 3.5, 3.5)
    oval(1, 50, 33, 28, 11)
    oval(1, 76, 35, 12, 12)
    oval(1, 27, 34, 12, 11)
    poly(1, [(72, 38), (86, 38), (94, 71), (103, 80), (89, 81), (84, 73)])
    poly(1, [(16, 32), (37, 37), (34, 53), (26, 63), (27, 75), (33, 81), (18, 81), (17, 62), (13, 48)])
    poly(1, [(64, 28), (78, 8), (94, 10), (90, 34), (76, 42)])
    oval(1, 91, 14, 12, 11)
    poly(1, [(92, 5), (113, 6), (119, 12), (100, 18)])
    poly(1, [(92, 20), (112, 27), (110, 33), (92, 30)])
    poly(1, [(80, 8), (85, 0), (93, 5)])
    poly(3, [(99, 17), (119, 11), (111, 28), (93, 21)])
    poly(5, [(101, 19), (116, 14), (109, 25), (96, 22)])
    oval(2, 92, 10, 2.2, 2.2)
    band(4, (72, 20), (88, 33), 6)
    poly(3, [(88, 77), (102, 77), (103, 81), (88, 81)])
    poly(3, [(18, 77), (32, 77), (33, 81), (18, 81)])

    roles = np.zeros((h, w), np.uint8)
    for role, mask in layers:
        roles[mask] = role
    roles = majority(roles, roles > 0)
    ys, xs = np.nonzero(roles)
    roles = roles[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return roles, ["grey_stone", "black_stone", "white_marble", "red_marble", "red_marble"]


# Pictures drawn here rather than taken from a PixelLab picture.
DRAWN = {"dog": draw_dog}


def majority(roles, fill):
    """Smooths away single stray pixels, which would make slivers too small for a tile."""
    out = roles.copy()
    padded = np.pad(roles, 1)
    h, w = roles.shape
    for role in np.unique(roles):
        if role == 0:
            continue
        n = sum((padded[1 + dy:1 + dy + h, 1 + dx:1 + dx + w] == role).astype(np.int32) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        out[(n >= 6) & fill] = role
    return out


def merge_specks(roles, min_area):
    """Patches smaller than about a tile join whichever colour surrounds them most."""
    from scipy import ndimage
    out = roles.copy()
    for role in [r for r in np.unique(roles) if r]:
        lab, n = ndimage.label(out == role)
        for k in range(1, n + 1):
            patch = lab == k
            if patch.sum() >= min_area:
                continue
            ring = ndimage.binary_dilation(patch) & ~patch & (out > 0)
            if ring.any():
                vals, counts = np.unique(out[ring], return_counts=True)
                out[patch] = vals[np.argmax(counts)]
    return out


def save_roles(roles, path):
    h, w = roles.shape
    img = np.zeros((h, w, 4), np.uint8)
    for role in range(1, 7):
        img[roles == role] = ROLE_RGB[role] + (255,)
    Image.fromarray(img).save(path)


def letters():
    """CAVE over CANEM in blocky capitals, each pixel of the font a whole tile, so every stroke is one full row."""
    from PIL import ImageDraw, ImageFont
    font = ImageFont.truetype(str(ROOT / "game" / "assets" / "fonts" / "Silkscreen-Regular.ttf"), 8)
    lines = ["CAVE", "CANEM"]
    w = int(max(font.getlength(s) for s in lines)) + 2
    im = Image.new("L", (w, 20), 0)
    draw = ImageDraw.Draw(im)
    for k, s in enumerate(lines):
        draw.text(((w - font.getlength(s)) // 2, k * 10), s, 255, font=font)
    a = np.array(im) > 128
    ys, xs = np.nonzero(a)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    roles = np.zeros(a.shape, np.uint8)
    roles[a] = 1
    return np.kron(roles, np.ones((4, 4), np.uint8))


# How a motif is named inside a sentence, where lower case or "a" in front would read wrongly.
SAID = {"knot": {"lower": "Solomon's knot"}, "cave_canem": {"lower": "CAVE CANEM", "a": "the words CAVE CANEM"}, "loaves": {"a": "loaves"}, "grapes": {"a": "grapes"}, "medusa": {"lower": "Medusa", "a": "Medusa's head"}}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    motifs = []
    for mid, name, tier, tags, stones, cost in GEOMETRIC:
        roles = draw_geometric(mid)
        save_roles(roles, OUT / f"{mid}.png")
        used = sorted(int(r) for r in np.unique(roles) if r)
        motifs.append({"id": mid, "name": name, "kind": "pattern", "file": f"res://assets/art/motifs/{mid}.png", "tier": tier,
                       "tags": tags, "stones": {str(r): stones[r - 1] for r in used}, "cost": cost, "aspect": 1.0,
                       "min": 3, "max": 60, "outline": ""})
    for mid, name, tier, tags in FIGURES:
        src = SOURCES / f"{mid}.png"
        if not src.exists():
            print("missing source", src)
            continue
        roles, stones = DRAWN[mid]() if mid in DRAWN else figure_roles(src, tier, mid in DARK)
        for role, stone in OVERRIDES.get(mid, {}).items():
            if role <= len(stones):
                stones[role - 1] = stone
        save_roles(roles, OUT / f"{mid}.png")
        h, w = roles.shape
        motifs.append({"id": mid, "name": name, "kind": "picture", "file": f"res://assets/art/motifs/{mid}.png", "tier": tier,
                       "tags": tags, "stones": {str(r): s for r, s in enumerate(stones, 1)}, "cost": 1.3, "aspect": round(w / h, 3),
                       "min": 6, "max": 70, "outline": "black_stone"})
    roles = letters()
    save_roles(roles, OUT / "cave_canem.png")
    h, w = roles.shape
    motifs.append({"id": "cave_canem", "name": "CAVE CANEM", "kind": "letters", "file": "res://assets/art/motifs/cave_canem.png",
                   "tier": 1, "tags": ["guard", "words"], "stones": {"1": "black_stone"}, "cost": 1.2, "aspect": round(w / h, 3),
                   "min": w // 8, "max": w // 4 * 2, "outline": ""})
    order = {m["id"]: i for i, m in enumerate(motifs)}
    motifs.sort(key=lambda m: (m["tier"], order[m["id"]]))
    for m in motifs:
        m.update(SAID.get(m["id"], {}))
    DATA.write_text(json.dumps(motifs, indent="\t"))
    sheet = Image.new("RGBA", (8 * 70, ((len(motifs) + 7) // 8) * 70), (236, 224, 198, 255))
    for i, m in enumerate(motifs):
        im = Image.open(OUT / f"{m['id']}.png").convert("RGBA")
        im.thumbnail((64, 64), Image.NEAREST)
        sheet.alpha_composite(im, ((i % 8) * 70 + 3, (i // 8) * 70 + 3))
    sheet.save(ROOT / "tools" / "art" / "motif_sheet.png")
    stone_sheet = Image.new("RGBA", sheet.size, (236, 224, 198, 255))
    for i, m in enumerate(motifs):
        roles = np.array(Image.open(OUT / f"{m['id']}.png").convert("RGBA"))
        img = np.zeros(roles.shape, np.uint8)
        for role in range(1, 7):
            hit = np.all(roles[:, :, :3] == ROLE_RGB[role], axis=2) & (roles[:, :, 3] > 0)
            stone = m["stones"].get(str(role))
            if stone:
                img[hit] = STONES[stone][0] + (255,)
        im = Image.fromarray(img)
        im.thumbnail((64, 64), Image.NEAREST)
        stone_sheet.alpha_composite(im, ((i % 8) * 70 + 3, (i // 8) * 70 + 3))
    stone_sheet.save(ROOT / "tools" / "art" / "motif_stone_sheet.png")
    print(len(motifs), "motifs")


if __name__ == "__main__":
    main()
