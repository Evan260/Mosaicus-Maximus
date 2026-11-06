"""Make the YouTube channel banner: a long mosaic floor laid by the game itself, with the logo in the middle of it.

The banner is 2560x1440, but computers and phones show only a strip across its middle (1546x423 at the narrowest,
2560x423 at the widest) and only televisions show the whole of it. So the logo sits in the middle of that strip with a
dolphin on each side of it inside the narrowest strip, fish beyond them for wide screens, and the rest of the floor,
with its border of running waves and a few rosettes, for televisions.

Usage: python tools/trailer/make_banner.py
Writes marketing/youtube_banner.png.
"""
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
LOGO = ROOT / "game" / "tools" / "trailer" / "logo.png"
OUT = ROOT / "marketing" / "youtube_banner.png"
SIZE = (2560, 1440)
STRIP = (508, 931)
# A tile is 24 screen pixels here, so the floor is this many tiles across and down.
TILES = (106, 60)
LOGO_SCALE = 2


def motif(name, x, y, size, stones=None, flip=False):
    picture = name in ("dolphin", "fish")
    # Pictures are laid in half-size tiles, as a picture panel would be, so their shapes read finely.
    return {"motif": name, "x": x, "y": y, "size": size, "rot": 0, "flip": flip, "stones": stones or {},
            "outline": "black_stone" if picture else "", "fine": picture}


def design():
    w, h = TILES
    middle = h / 2
    dolphin = {"1": "blue_glass", "2": "grey_stone", "3": "white_marble", "4": "black_stone"}
    fish = {"1": "grey_stone", "2": "green_marble", "3": "black_stone"}
    rosette = {"1": "black_stone", "2": "terracotta", "3": "white_marble", "4": "black_stone"}
    placements = [
        motif("dolphin", 30.5, middle, 15, dolphin),
        motif("dolphin", w - 30.5, middle, 15, dolphin, True),
        motif("fish", 12.5, middle, 10, fish),
        motif("fish", w - 12.5, middle, 10, fish, True),
    ]
    for x in (w * 0.2, w * 0.4, w * 0.6, w * 0.8):
        for y in (12.0, h - 12.0):
            placements.append(motif("rosette", round(x * 2) / 2, y, 9, rosette))
    return {"room": "panel", "w": w, "h": h, "shape": "rect", "pool": [], "ground": "white_marble",
            "border": {"id": "wave", "width": 5, "margin": 1, "stones": ["white_marble", "blue_glass", "black_stone", "black_stone"]},
            "placements": placements}


def main():
    with tempfile.TemporaryDirectory() as tmp:
        spec = Path(tmp) / "banner.json"
        spec.write_text(json.dumps(design()))
        render = Path(tmp) / "floor.png"
        subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--", "--no-save", f"--icon={render}",
                        f"--icon-design={spec}", f"--icon-res={SIZE[0]}x{SIZE[1]}"])
        # Godot can stumble while quitting after the picture is saved, so the picture itself is what counts.
        if not render.exists():
            raise SystemExit("the game did not render the floor")
        banner = Image.open(render).convert("RGBA")
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.resize((logo.width * LOGO_SCALE, logo.height * LOGO_SCALE), Image.NEAREST)
    at = ((SIZE[0] - logo.width) // 2, (STRIP[0] + STRIP[1] - logo.height) // 2)
    banner.alpha_composite(logo, at)
    banner.convert("RGB").save(OUT)
    print(f"banner: {OUT}")


if __name__ == "__main__":
    main()
