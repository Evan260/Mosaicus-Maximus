"""Make the Steam store page's pictures: the capsules, the library art, the page background, the icons and the
screenshots, all made by the game itself.

The capsules and the library hero are finished mosaic floors laid by the game's own floor renderer at the picture's
exact size, with the logo laid over the floor's open ground at twice its pixel size, so its pixel art stays sharp
(the hero has no logo, since Steam lays the library logo over it). The page background is
the workshop at dusk, rendered at one screen pixel to the game pixel with no interface and enlarged three times. The
screenshots are moments of the trailer's recorded shots, 1920x1080 as the game draws them, which play a fresh
workshop that is never saved; any shot not yet recorded is recorded first with tools/trailer/make_trailer.py.

Usage: python tools/steam/make_store_art.py
Everything the layout crops or combines is rendered into a temporary folder that is removed afterwards; only the
finished files are written, to store/steam_page/ (see README.txt there for which file goes in which Steamworks slot).
"""
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "store" / "steam_page"
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
LOGO = ROOT / "game" / "tools" / "trailer" / "logo.png"
# The name without its laurel, for pictures too narrow for the laurel.
PLAIN_LOGO = LOGO.with_name("logo_plain.png")
# The square profile picture; the one in marketing/ has rounded corners, which a square store icon would show black.
PROFILE = ROOT / "tools" / "art" / "profile_square.png"
SHOTS = ROOT / "marketing" / "recordings" / "content" / "trailer_shots"
FPS = 30
sys.path.insert(0, str(ROOT / "tools" / "trailer"))
from make_logo import compact_name  # noqa: E402

# name: (trailer shot, seconds into it). Upload them in this order; the first few lead in the sidebar and in search.
SCREENSHOTS = {
    "01_the_workshop": ("dog", 1.0),
    "02_the_job_board": ("client", 3.0),
    "03_a_client_visits": ("client", 6.2),
    "04_the_design_table": ("design", 10.7),
    "05_laying_the_doves": ("floor", 3.3),
    "06_laying_the_flower": ("floor", 6.4),
    "07_grout_and_polish": ("floor", 13.5),
    "08_in_her_bedroom": ("floor", 22.0),
    "09_an_old_floor_dug_up": ("dig", 2.4),
    "10_a_villa_dining_room": ("villa", 5.8),
    "11_a_floor_of_the_sea": ("endcard", 4.0),
    "12_the_workshop_at_night": ("night", 3.0),
}

DOLPHIN = {"1": "blue_glass", "2": "grey_stone", "3": "white_marble", "4": "black_stone"}
FISH = {"1": "ochre_marble", "2": "terracotta", "3": "black_stone"}
WAVES = {"id": "wave", "width": 5, "margin": 1, "stones": ["white_marble", "blue_glass", "black_stone", "black_stone"]}
PICTURES = {"dolphin", "fish", "octopus", "peacock", "medusa", "lobster", "duck", "boat", "dove", "grapes", "lion",
            "horse", "stag", "lyre", "dog", "hare", "amphora", "loaves"}


def motif(name, x, y, size, stones=None, flip=False):
    """A placement on a floor. Pictures are laid in half-size tiles with a dark outline, as a picture panel is."""
    picture = name in PICTURES
    return {"motif": name, "x": x, "y": y, "size": size, "rot": 0, "flip": flip, "stones": stones or {},
            "outline": "black_stone" if picture else "", "fine": picture}


def grid(size, tile):
    """A floor's width and height in tiles for a picture of this size with tiles about this many pixels across; the
    floor fills the width exactly and is at least as tall as the picture."""
    w = round(size[0] / tile)
    return w, math.ceil(size[1] * w / size[0])


def floor(w, h, placements, border=None):
    return {"room": "panel", "w": w, "h": h, "shape": "rect", "pool": [], "ground": "white_marble",
            "border": border or WAVES, "placements": placements}


def sea_header(size):
    """Two dolphins leap at the logo's sides, over two fish and a scallop shell."""
    w, h = grid(size, 7.5)
    return floor(w, h, [
        motif("dolphin", 16.5, 12.5, 21, DOLPHIN), motif("dolphin", w - 16.5, 12.5, 21, DOLPHIN, True),
        motif("fish", 34, 40, 13, FISH, True), motif("fish", w - 34, 40, 13, FISH), motif("shell", w / 2, 41, 11)])


def plain_ground(size):
    """Open white ground inside a plain blue band, where the name fills the picture."""
    w, h = grid(size, 6.0)
    return floor(w, h, [], {"id": "plain", "width": 2, "margin": 1, "stones": ["white_marble"] + ["blue_glass"] * 3})


def sea_main(size):
    """Dolphins beside the logo, and under it an octopus between two fish."""
    w, h = grid(size, 9.0)
    return floor(w, h, [
        motif("dolphin", 19, 19, 22, DOLPHIN), motif("dolphin", w - 19, 19, 22, DOLPHIN, True),
        motif("octopus", w / 2, 50, 27),
        motif("fish", w / 2 - 34, 52, 16, FISH, True), motif("fish", w / 2 + 34, 52, 16, FISH),
        motif("shell", 16, 60, 10), motif("shell", w - 16, 60, 10)])


TALL_LOGO_TOP = 70


def villa_tall(size):
    """A villa's floor under the logo: a peacock in a roundel over two bunches of grapes, in a braided border. It is
    always 100 tiles across, since a picture much bigger than its own drawing shows that drawing's blocks."""
    w, h = grid(size, size[0] / 100)
    # The roundel and the grapes under it are centred together in the ground between the logo and the border.
    below_logo = (TALL_LOGO_TOP + logo("plain").height) / (size[0] / w)
    free = h - 8 - below_logo
    ring = min(60, free - 25)
    top = below_logo + (free - ring - 22) / 2
    placements = [motif("roundel", w / 2, top + ring / 2, ring), motif("peacock", w / 2, top + ring / 2, ring * 0.62)]
    for x in (w * 0.3, w * 0.7):
        placements.append(motif("grapes", x, top + ring + 13.5, 17, flip=x > w / 2))
    return floor(w, h, placements, {"id": "braid", "width": 6, "margin": 1,
                                    "stones": ["white_marble", "red_marble", "ochre_marble", "black_stone"]})


def sea_hero(size):
    """A long sea floor with no logo, since Steam lays the library logo over it: an octopus in the middle, with
    dolphins, fish and shells either side."""
    w, h = grid(size, 16.0)
    mid = h / 2
    placements = [motif("octopus", w / 2, mid, 44)]
    for side in (-1, 1):
        flip = side < 0
        placements += [
            motif("dolphin", w / 2 + side * 48, mid - 6, 34, DOLPHIN, flip),
            motif("shell", w / 2 + side * 78, mid - 16, 12),
            motif("fish", w / 2 + side * 78, mid + 10, 20, FISH, flip),
            motif("dolphin", w / 2 + side * 99, mid - 4, 26, DOLPHIN, flip)]
    return floor(w, h, placements, {**WAVES, "width": 6})


# name: (size, design, logo, the logo's top in pixels or None to centre it). The logo is laid over each floor at
# twice its pixel size.
CAPSULES = {
    "header_capsule_920x430.png": ((920, 430), sea_header, "full", 46),
    "small_capsule_462x174.png": ((462, 174), plain_ground, "compact", None),
    "main_capsule_1232x706.png": ((1232, 706), sea_main, "full", 60),
    "vertical_capsule_748x896.png": ((748, 896), villa_tall, "full", TALL_LOGO_TOP),
    "library_capsule_600x900.png": ((600, 900), villa_tall, "plain", TALL_LOGO_TOP),
}


def godot(*args):
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--", "--no-save", *args], check=True,
                   capture_output=True)


def render_floor(tmp, name, design, size):
    """The game lays the floor and saves it at the picture's width; the floor is cropped evenly to its height."""
    spec = tmp / f"{name}.json"
    spec.write_text(json.dumps(design))
    path = tmp / f"{name}.png"
    full = (size[0], round(design["h"] * size[0] / design["w"]))
    # Godot can stumble while quitting after the picture is saved, so the picture itself is what counts.
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--", "--no-save", f"--icon={path}",
                    f"--icon-design={spec}", f"--icon-res={full[0]}x{full[1]}"], capture_output=True)
    if not path.exists():
        sys.exit(f"the game did not render the {name} floor")
    img = Image.open(path).convert("RGBA")
    top = (img.height - size[1]) // 2
    print("rendered", name)
    return img.crop((0, top, size[0], top + size[1]))


def render_workshop(tmp, name, hour):
    """The furnished workshop at an hour of the day, one screen pixel to the game pixel, without the interface."""
    path = tmp / f"{name}.png"
    godot("--screen=workshop", "--no-hud", "--no-mouse", "--furnished", f"--hour={hour}", "--window=480x270",
          "--shot-at=2", f"--shot={path}", "--quit")
    print("rendered", name)
    return Image.open(path).convert("RGB")


def logo(kind, scale=2):
    """The logo trimmed to its drawn pixels, enlarged scale times."""
    if kind == "compact":
        pic = compact_name()
    else:
        pic = Image.open(PLAIN_LOGO if kind == "plain" else LOGO).convert("RGBA")
    pic = pic.crop(pic.getbbox())
    return pic.resize((pic.width * scale, pic.height * scale), Image.NEAREST)


def enlarge(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def make_capsules(tmp):
    for name, (size, design, kind, top) in CAPSULES.items():
        base = render_floor(tmp, Path(name).stem, design(size), size)
        mark = logo(kind)
        at = ((size[0] - mark.width) // 2, (size[1] - mark.height) // 2 if top is None else top)
        base.alpha_composite(mark, at)
        base.convert("RGB").save(OUT / name)
    # Steam's library header is the same picture as the store's header capsule.
    Image.open(OUT / "header_capsule_920x430.png").save(OUT / "library_header_920x430.png")
    size = (3840, 1240)
    render_floor(tmp, "hero", sea_hero(size), size).convert("RGB").save(OUT / "library_hero_3840x1240.png")


def make_page_background(tmp):
    """The workshop at dusk behind the store page's text, three times its pixel size and darkened."""
    room = enlarge(render_workshop(tmp, "dusk", 18.5), 3)
    left = (room.width - 1438) // 2
    room = room.crop((left, 0, left + 1438, 810))
    room.point(lambda v: int(v * 0.5)).save(OUT / "page_background_1438x810.png")


def make_logo_and_icons():
    mark = logo("full", 4)
    canvas = Image.new("RGBA", (1280, mark.height), (0, 0, 0, 0))
    canvas.alpha_composite(mark, ((1280 - mark.width) // 2, 0))
    canvas.save(OUT / "library_logo_1280_transparent.png")
    icon = Image.open(PROFILE).convert("RGB")
    icon.resize((184, 184), Image.LANCZOS).save(OUT / "community_icon_184x184.jpg", quality=95)
    icon.save(OUT / "app_icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])


def make_screenshots():
    missing = sorted({shot for shot, _ in SCREENSHOTS.values() if not (SHOTS / shot / "f.wav").exists()})
    if missing:
        subprocess.run([sys.executable, str(ROOT / "tools" / "trailer" / "make_trailer.py"), "shots", *missing], check=True)
    folder = OUT / "screenshots"
    folder.mkdir(parents=True, exist_ok=True)
    # A screenshot no longer in the list is taken off the page.
    for old in folder.glob("*.png"):
        if old.stem not in SCREENSHOTS:
            old.unlink()
    for name, (shot, seconds) in SCREENSHOTS.items():
        frame = SHOTS / shot / f"f{round(seconds * FPS):08d}.png"
        Image.open(frame).convert("RGB").save(folder / f"{name}.png")
        print(f"{name}: {shot} at {seconds} s")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        tmp = Path(folder)
        make_capsules(tmp)
        make_page_background(tmp)
    make_logo_and_icons()
    make_screenshots()
    print("laid out", OUT)


if __name__ == "__main__":
    main()
