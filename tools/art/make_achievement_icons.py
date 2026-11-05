"""Make the Steam achievement icons: a 64 by 64 picture for each achievement, and a grey one for before it is earned.

Each icon is a framed tile. Patterns and pictures from the pattern book are laid as a little mosaic in the game's own
stone colours; the rest use a client's portrait, the dog, or one of the interface icons, enlarged by whole steps so the
pixel art stays crisp. Steamworks takes JPG files, so the tiles have no transparency.

Usage: python tools/art/make_achievement_icons.py
Writes store/achievements/<id>.jpg and <id>_locked.jpg, plus store/achievements/sheet.png to look them over.
"""
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1].parent
GAME = ROOT / "game"
OUT = ROOT / "store" / "achievements"
SIZE = 64
INNER = 54
CELL = 4

INK = (74, 46, 36)
GOLD = (214, 160, 72)
GOLD_LIGHT = (246, 214, 140)
GOLD_DARK = (150, 98, 44)
CREAM = (250, 238, 210)
PARCH = (232, 210, 162)
GROUT = (176, 160, 132)

# The picture for each achievement: "motif:<id>" for a mosaic of a pattern book motif (with "@<stone>" for a ground other
# than limestone), "icon:<name>" for an interface icon, "portrait:<client>", "dog", "piece:<workshop piece>", or
# "draw:<name>" for a drawing below.
ART = {
    "first_floor": "motif:rosette",
    "floors_10": "motif:star",
    "floors_50": "motif:knot@white_marble",
    "five_stars": "icon:star",
    "five_stars_10": "draw:five_stars",
    "chapter_2": "motif:flower",
    "chapter_3": "motif:grapes",
    "chapter_4": "motif:sun@blue_glass",
    "first_dig": "icon:trowel",
    "digs_10": "motif:medusa",
    "all_patterns": "motif:peacock",
    "contest_win": "icon:laurel",
    "contest_5": "motif:lion",
    "perfect_copy": "icon:eye",
    "first_story": "portrait:septimus",
    "all_stories": "draw:townsfolk",
    "all_tastes": "icon:book",
    "temple": "portrait:valeria",
    "forum": "portrait:quintus",
    "earn_1000": "icon:coin",
    "earn_10000": "icon:sack",
    "big_floor": "draw:big_floor",
    "ship_stone": "motif:boat",
    "good_dog": "dog",
    "library_10": "piece:scrolls",
}


def stone_colours():
    """Each stone's tile colour, read from the game's own list so the icons match the floors."""
    text = (GAME / "scripts" / "design" / "stones.gd").read_text(encoding="utf-8")
    found = re.findall(r'"id": "(\w+)".*?"tile": Color8\((\d+), (\d+), (\d+)\)', text)
    return {sid: (int(r), int(g), int(b)) for sid, r, g, b in found}


STONES = stone_colours()
MOTIFS = {m["id"]: m for m in json.loads((GAME / "data" / "motifs.json").read_text(encoding="utf-8"))}
# Role colour bits (red 1, green 2, blue 4) to role numbers, as in motif_library.gd.
CODE_TO_ROLE = {1: 1, 2: 2, 4: 3, 3: 4, 5: 5, 6: 6}


def res(path):
    return GAME / path.replace("res://", "")


def crop(img):
    return img.crop(img.getbbox())


def fit(img, room=INNER):
    """The picture at the largest whole-number scale that fits the room, or shrunk smoothly if even 1x is too big."""
    scale = min(room // img.width, room // img.height)
    if scale >= 1:
        return img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    ratio = min(room / img.width, room / img.height)
    return img.resize((max(1, round(img.width * ratio)), max(1, round(img.height * ratio))), Image.LANCZOS)


def mosaic(motif_id, cells=13, seed=0, ground="limestone"):
    """A motif laid in square tiles with grout between them, on a plain ground, filling the inside of the frame."""
    m = MOTIFS[motif_id]
    src = np.array(Image.open(res(m["file"])).convert("RGBA"))
    code = (src[..., 0] > 127) * 1 + (src[..., 1] > 127) * 2 + (src[..., 2] > 127) * 4
    code[src[..., 3] < 128] = 0
    h, w = code.shape
    k = cells / max(w, h)
    mw, mh = max(1, round(w * k)), max(1, round(h * k))
    n = INNER // CELL
    ox, oy = (n - mw) // 2, (n - mh) // 2
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (INNER, INNER), GROUT + (255,))
    px = img.load()
    for cy in range(n):
        for cx in range(n):
            colour = STONES[ground]
            mx, my = cx - ox, cy - oy
            if 0 <= mx < mw and 0 <= my < mh:
                role = CODE_TO_ROLE.get(int(code[min(h - 1, int((my + 0.5) / k)), min(w - 1, int((mx + 0.5) / k))]), 0)
                if role:
                    colour = STONES[m["stones"].get(str(role), "black_stone")]
            shade = 1.0 + rng.uniform(-0.06, 0.06)
            c = tuple(max(0, min(255, int(v * shade))) for v in colour) + (255,)
            for y in range(CELL - 1):
                for x in range(CELL - 1):
                    px[cx * CELL + x, cy * CELL + y] = c
    return img


def icon_art(name):
    return crop(Image.open(GAME / "assets" / "ui" / "icons" / f"{name}.png").convert("RGBA"))


def portrait(client, room=INNER):
    img = Image.open(GAME / "assets" / "art" / "portraits" / f"{client}.png").convert("RGBA")
    return img if img.width <= room else img.resize((room, room), Image.LANCZOS)


def drawing(name):
    canvas = Image.new("RGBA", (INNER, INNER), (0, 0, 0, 0))
    if name == "five_stars":
        star = fit(icon_art("star"), 16)
        for i, (x, y) in enumerate(((1, 20), (11, 8), (19, 2), (27, 8), (37, 20))):
            canvas.alpha_composite(star, (x, y))
        laurel = fit(icon_art("laurel"), 28)
        canvas.alpha_composite(laurel, ((INNER - laurel.width) // 2, INNER - laurel.height - 1))
        return canvas
    if name == "townsfolk":
        for client, x, y in (("cornelia", 0, 2), ("felix", 28, 2), ("marcus", 14, 26)):
            canvas.alpha_composite(portrait(client, 26), (x, y))
        return canvas
    if name == "big_floor":
        return mosaic("wave_ring", 13, 2)
    raise ValueError(name)


def picture(achievement_id):
    kind, _, what = ART[achievement_id].partition(":")
    if kind == "motif":
        motif, _, ground = what.partition("@")
        return mosaic(motif, 13, len(achievement_id), ground or "limestone")
    if kind == "icon":
        return fit(icon_art(what), 48)
    if kind == "portrait":
        return portrait(what)
    if kind == "dog":
        return fit(crop(Image.open(GAME / "assets" / "art" / "dogs" / "hound" / "sit" / "frame_00.png").convert("RGBA")))
    if kind == "piece":
        return fit(crop(Image.open(GAME / "assets" / "art" / "workshop" / f"{what}.png").convert("RGBA")))
    return drawing(what)


def tile():
    img = Image.new("RGBA", (SIZE, SIZE), INK + (255,))
    px = img.load()
    for y in range(1, SIZE - 1):
        for x in range(1, SIZE - 1):
            ring = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            if ring == 1:
                px[x, y] = GOLD_LIGHT + (255,) if x < SIZE - 3 and y < SIZE - 3 and (x == 1 or y == 1) else GOLD + (255,)
            elif ring == 2:
                px[x, y] = GOLD_DARK + (255,) if (x == SIZE - 3 or y == SIZE - 3) else GOLD + (255,)
            elif ring == 3:
                px[x, y] = INK + (255,)
            else:
                t = (y - 4) / (SIZE - 8)
                px[x, y] = tuple(int(CREAM[i] + (PARCH[i] - CREAM[i]) * t) for i in range(3)) + (255,)
    return img


def icon(achievement_id):
    pic = picture(achievement_id)
    img = tile()
    img.alpha_composite(pic, ((SIZE - pic.width) // 2, (SIZE - pic.height) // 2))
    return img.convert("RGB")


def locked(img):
    grey = ImageEnhance.Color(img).enhance(0.0)
    return ImageEnhance.Brightness(ImageEnhance.Contrast(grey).enhance(0.8)).enhance(0.55)


def main():
    ids = [a["id"] for a in json.loads((GAME / "data" / "achievements.json").read_text(encoding="utf-8"))]
    missing = [i for i in ids if i not in ART]
    if missing:
        raise SystemExit(f"no picture chosen for {missing}; add them to ART")
    OUT.mkdir(parents=True, exist_ok=True)
    cell = SIZE * 2 + 12
    sheet = Image.new("RGB", (4 * cell, ((len(ids) + 3) // 4) * (SIZE + 8)), (40, 30, 26))
    for n, i in enumerate(ids):
        img = icon(i)
        img.save(OUT / f"{i}.jpg", quality=95)
        dim = locked(img)
        dim.save(OUT / f"{i}_locked.jpg", quality=95)
        col, row = n % 4, n // 4
        sheet.paste(img, (col * cell, row * (SIZE + 8)))
        sheet.paste(dim, (col * cell + SIZE + 4, row * (SIZE + 8)))
    sheet.save(OUT / "sheet.png")
    print(f"wrote {len(ids) * 2} icons to {OUT}")


if __name__ == "__main__":
    main()
