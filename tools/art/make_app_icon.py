"""Make the game's icon from a picture of a small mosaic the game renders itself.

The game lays the mosaic with its own floor renderer and saves it:
  Godot --path game -- --no-save --icon=RENDER.png
Then: python tools/art/make_app_icon.py RENDER.png
Writes game/icon.png (the window's icon) and game/icon.ico (the exe's and the taskbar's, in every size Windows asks for).
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIZES = [16, 24, 32, 48, 64, 128, 256]


def main():
    render = Image.open(sys.argv[1]).convert("RGBA")
    big = render.resize((256, 256), Image.LANCZOS)
    big.save(ROOT / "game" / "icon.png")
    big.save(ROOT / "game" / "icon.ico", sizes=[(s, s) for s in SIZES])
    print("wrote game/icon.png and game/icon.ico")


if __name__ == "__main__":
    main()
