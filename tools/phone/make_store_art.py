"""Make the phone app stores' pictures: the Google Play icon, feature graphic and phone and tablet screenshots, and
the App Store icon and iPhone and iPad screenshots, all made by the game itself so the pixel art stays exact.

Screenshots are taken with the phone interface (--phone) at each store's exact size, so the game picks its own whole
number scales for that screen's shape, as it would on the device. The first job's design, laying and reveal and the
dug-up floor are the trailer's scripted shots, which play a fresh workshop the same way every time; the laying and the
dig are caught in a burst of frames, and the frame kept is the one where the flower is mostly laid or the dirt half
gone. The other scenes open a made-up workshop (--demo-state or --max-state with --seed=1), so the morning's notices
are the same every time and the real save is never touched. The icons are the game's icon mosaic laid
at the icon's exact size, and the feature graphic is a sea floor laid at its exact size with the logo laid over it at
twice its pixel size, as the Steam capsules are.

Usage: python tools/phone/make_store_art.py
Writes store/google_play/ and store/app_store/ (see README.txt in each for which file goes where). The renders are
made in a temporary folder that is removed when it finishes.
"""
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PLAY = ROOT / "store" / "google_play"
APPLE = ROOT / "store" / "app_store"
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
_spec = importlib.util.spec_from_file_location("steam_store_art", ROOT / "tools" / "steam" / "make_store_art.py")
steam = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(steam)

# The trailer's shots move the brush a step a frame for 30 frames a second, so they are played at that fixed rate.
FPS = 30
# Nothing is saved, the real mouse lights nothing up, and no achievement card slides in over a picture.
QUIET = ["--no-save", "--no-mouse", "--achievement", "--achievement-at=999"]
# A made-up workshop with the same seed every time, so the morning's notices are the same in every picture.
CHAPTER_3 = ["--demo-state", "--seed=1"]
EVERYTHING = ["--max-state", "--seed=1"]
# name: flags. Each is one scene, taken at every size that lists it.
SCENES = {
    # Any --panel puts away the morning's letters, which would cover the room; "none" opens no window in their place.
    "the_workshop": [*CHAPTER_3, "--screen=workshop", "--furnished", "--hour=16.5", "--panel=none"],
    "a_client_visits": [*EVERYTHING, "--screen=client_visit", "--kind=commission"],
    "designing_her_floor": ["--trailer-shot=design", "--shot-at=13"],
    "laying_the_stones": ["--trailer-shot=floor"],
    "in_her_bedroom": ["--trailer-shot=floor", "--shot-at=26"],
    "the_town": [*EVERYTHING, "--screen=town_map"],
    "a_villa_dining_room": [*EVERYTHING, "--screen=town_map", "--visit", "--room=villa_dining", "--shot-at=5"],
    "festival_day": [*CHAPTER_3, "--screen=job_board", "--day=25"],
    "an_old_floor_dug_up": ["--trailer-shot=dig"],
}
PHONE = ["the_workshop", "a_client_visits", "designing_her_floor", "laying_the_stones", "in_her_bedroom", "the_town",
         "a_villa_dining_room", "festival_day"]
TABLET = ["the_workshop", "designing_her_floor", "a_villa_dining_room", "the_town"]
# folder: (window size, scenes in upload order).
SETS = {
    PLAY / "phone_screenshots": ((1920, 1080), PHONE),
    PLAY / "tablet_7_inch_screenshots": ((1920, 1080), TABLET),
    PLAY / "tablet_10_inch_screenshots": ((2560, 1440), TABLET),
    APPLE / "iphone_6.9_inch_screenshots": ((2868, 1320), PHONE),
    # A 4:3 screen shows the workshop, the town and the villa small between dark bands, so the iPad leaves them out.
    APPLE / "ipad_13_inch_screenshots": ((2752, 2064), ["designing_her_floor", "laying_the_stones", "in_her_bedroom",
                                                        "a_client_visits", "an_old_floor_dug_up", "festival_day"]),
}
# The floor takes longer to set out on some runs, so these two are caught in a burst of frames: name: (first and last
# second, seconds between frames).
BURSTS = {"laying_the_stones": (5.0, 11.0, 0.1), "an_old_floor_dug_up": (1.5, 9.0, 0.25)}
FEATURE = (1024, 500)
FEATURE_LOGO_TOP = 40


def godot(size, flags, pictures):
    # A fixed rate keeps the visit to a floor waiting on its walk over, so only the trailer's shots are played at one.
    fixed = ["--fixed-fps", str(FPS)] if any(f.startswith("--trailer-shot") for f in flags) else []
    args = [str(GODOT), "--path", str(ROOT / "game"), *fixed, "--max-fps", str(FPS), "--quit-after", str(60 * FPS),
            "--", *QUIET, "--phone", f"--window={size[0]}x{size[1]}", *flags, "--quit"]
    # Godot can stumble while quitting after the picture is saved, so the pictures themselves are what count.
    subprocess.run(args, capture_output=True, timeout=180)
    for path in pictures:
        if not path.exists():
            sys.exit(f"the game did not render {path.name}")


def shoot(path, size, name):
    """Takes one picture of a scene with the game, once the scene has settled, at the given window size."""
    if name in BURSTS:
        shoot_burst(path, size, name)
    else:
        godot(size, ["--shot-at=3", *SCENES[name], f"--shot={path}"], [path])
    # The stores take no alpha channel in a screenshot.
    Image.open(path).convert("RGB").save(path)
    print("rendered", path.name)


def colours(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return rgb[..., 0], rgb[..., 1], rgb[..., 2]


def red_tiles(path):
    """How many pixels of the picture are red marble tiles, which the flower is laid in."""
    r, g, b = colours(path)
    return int(((r - g >= 72) & (r >= 120) & (b < g + 40)).sum())


def dirt(path):
    """How many pixels of the picture are the brown dirt over a buried floor."""
    r, g, b = colours(path)
    return int(((r - b >= 40) & (r >= 110) & (r <= 190) & (g - b >= 15) & (r - g >= 15) & (r - g <= 45)).sum())


def pick_laying(frames):
    """The first frame with seven tenths of the flower's tiles down, before the view pulls back from it."""
    red = [red_tiles(f) for f in frames]
    return next(f for f, n in zip(frames, red) if n >= 0.7 * max(red))


def pick_dig(frames):
    """The first frame with the dirt more than half scraped away, which uncovers the guard dog but not yet the words."""
    left = [dirt(f) for f in frames]
    buried = left.index(max(left))
    return next(f for f, n in zip(frames[buried:], left[buried:]) if n <= 0.45 * left[buried])


def shoot_burst(path, size, name):
    start, end, gap = BURSTS[name]
    count = round((end - start) / gap) + 1
    prefix = path.with_name(path.stem + "_burst")
    frames = [Path(f"{prefix}_{k:02d}.png") for k in range(count)]
    godot(size, [*SCENES[name], f"--burst={prefix}", f"--burst-start={start}", f"--burst-gap={gap}",
                 f"--burst-count={count}"], frames)
    shutil.copyfile((pick_laying if name == "laying_the_stones" else pick_dig)(frames), path)
    for f in frames:
        f.unlink()


def screenshots(tmp):
    """Renders each scene once at each size, then lays the pictures out in every folder that lists them."""
    renders = {(size, name): tmp / f"{name}_{size[0]}x{size[1]}.png" for size, names in SETS.values() for name in names}
    with ThreadPoolExecutor(3) as pool:
        list(pool.map(lambda job: shoot(job[1], *job[0]), renders.items()))
    for folder, (size, names) in SETS.items():
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("*.png"):
            old.unlink()
        for k, name in enumerate(names, 1):
            shutil.copyfile(renders[(size, name)], folder / f"{k:02d}_{name}.png")


def sea_feature(size):
    """Dolphins leap at the logo's sides, and under it an octopus swims between two fish and two scallop shells."""
    w, h = steam.grid(size, 7.5)
    mid = w / 2
    return steam.floor(w, h, [
        steam.motif("dolphin", 16, 13, 21, steam.DOLPHIN), steam.motif("dolphin", w - 16, 13, 21, steam.DOLPHIN, True),
        steam.motif("octopus", mid, 43.5, 24),
        steam.motif("fish", mid - 30, 45.5, 13, steam.FISH, True), steam.motif("fish", mid + 30, 45.5, 13, steam.FISH),
        steam.motif("shell", mid - 50, 46.5, 10), steam.motif("shell", mid + 50, 46.5, 10)])


def feature_graphic(tmp):
    art = steam.render_floor(tmp, "feature", sea_feature(FEATURE), FEATURE)
    mark = steam.logo("full")
    art.alpha_composite(mark, ((art.width - mark.width) // 2, FEATURE_LOGO_TOP))
    art.convert("RGB").save(PLAY / "feature_graphic_1024x500.png")


def icon(tmp, side):
    """The game's icon mosaic, laid by the game at the icon's exact size, square and opaque to every edge."""
    path = tmp / f"icon_{side}.png"
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--", "--no-save", f"--icon={path}",
                    f"--icon-res={side}x{side}"], capture_output=True, timeout=120)
    if not path.exists():
        sys.exit("the game did not render the icon")
    print("rendered the icon at", side)
    return Image.open(path).convert("RGBA")


def icons(tmp):
    icon(tmp, 512).save(PLAY / "icon_512.png")
    # Apple refuses an icon with an alpha channel, even a fully opaque one.
    icon(tmp, 1024).convert("RGB").save(APPLE / "icon_1024.png")


def main():
    PLAY.mkdir(parents=True, exist_ok=True)
    APPLE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        tmp = Path(folder)
        icons(tmp)
        feature_graphic(tmp)
        screenshots(tmp)
    print("laid out", PLAY, "and", APPLE)


if __name__ == "__main__":
    main()
