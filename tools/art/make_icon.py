"""Make the game's icon from a picture of a small mosaic the game renders itself.

The game lays the mosaic with its own floor renderer and saves it:
  Godot --path game -- --no-save --icon=RENDER.png
Then: python tools/art/make_icon.py RENDER.png
Writes game/icon.png (the window's icon) and game/icon.ico (the exe's and the taskbar's, in every size Windows asks for),
rounded into a tile with a dark rim as Fishus Maximus's is, its corners and rim worked out on a 64 pixel grid so they
step in the same blocks. With --profile SQUARE.png it rounds the marketing profile picture the same way instead:
  python tools/art/make_icon.py --profile tools/art/profile_square.png   (writes marketing/profile_picture.png)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIZES = [16, 24, 32, 48, 64, 128, 256]
GRID = 64
CORNER = 11
RIM = (38, 34, 48)


def rounded(square: Image.Image, size: int = 256) -> Image.Image:
    ys, xs = np.mgrid[0:GRID, 0:GRID]
    cx = np.clip(xs, CORNER, GRID - 1 - CORNER)
    cy = np.clip(ys, CORNER, GRID - 1 - CORNER)
    tile = (xs - cx) ** 2 + (ys - cy) ** 2 <= CORNER ** 2
    inner = tile.copy()
    inner[1:, :] &= tile[:-1, :]
    inner[:-1, :] &= tile[1:, :]
    inner[:, 1:] &= tile[:, :-1]
    inner[:, :-1] &= tile[:, 1:]
    inner[0, :] = inner[-1, :] = inner[:, 0] = inner[:, -1] = False
    tile, rim = (np.array(Image.fromarray(m).resize((size, size), Image.NEAREST)) for m in (tile, tile & ~inner))
    art = np.array(square.convert("RGBA").resize((size, size), Image.LANCZOS))
    art[~tile] = 0
    art[rim] = (*RIM, 255)
    return Image.fromarray(art)


def main():
    if sys.argv[1] == "--profile":
        square = Image.open(sys.argv[2])
        rounded(square, square.width).save(ROOT / "marketing" / "profile_picture.png")
        print("wrote marketing/profile_picture.png")
        return
    render = Image.open(sys.argv[1]).convert("RGBA")
    big = rounded(render)
    big.save(ROOT / "game" / "icon.png")
    frames = [big.resize((s, s), Image.LANCZOS) for s in SIZES]
    frames[-1].save(ROOT / "game" / "icon.ico", sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
    print("wrote game/icon.png and game/icon.ico")


if __name__ == "__main__":
    main()
