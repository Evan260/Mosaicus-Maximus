"""Build the game for Windows, macOS and Linux, each into its own folder with "Credits and licences.txt" beside it.

  builds/windows/   Mosaicus Maximus.exe, the GodotSteam libraries, and the launcher that opens a workshop with
                    everything unlocked, which never saves
  builds/macos/     Mosaicus Maximus.zip, Godot's own zip of the .app, which keeps the app's file permissions
  builds/linux/     Mosaicus Maximus.x86_64 and the GodotSteam libraries
With --demo it builds the free demo instead, from the demo presets, into builds/windows-demo/, builds/macos-demo/ and
builds/linux-demo/, without the launcher.

Usage:
  python tools/export.py                      every platform
  python tools/export.py windows linux        only those
  python tools/export.py --demo               the demo for every platform
  python tools/export.py macos --mac-share    the Mac build straight into ~/MacShare/Mosaicus Maximus for testing on a Mac
GODOT may name the Godot console exe; the WinGet install is used otherwise.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = "Mosaicus Maximus"
GODOT = os.environ.get("GODOT", str(Path.home() / "AppData/Local/Microsoft/WinGet/Packages"
    / "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"))
# The Godot export preset and the file it writes, for each platform.
PRESETS = {
    "windows": ("Windows", f"{GAME}.exe"),
    "macos": ("macOS", f"{GAME}.zip"),
    "linux": ("Linux", f"{GAME}.x86_64"),
}
# The demo is the same project exported with the "demo" feature, which stops where chapter 3 would open.
DEMO_PRESETS = {
    "windows": ("Windows demo", f"{GAME} Demo.exe"),
    "macos": ("macOS demo", f"{GAME} Demo.zip"),
    "linux": ("Linux demo", f"{GAME} Demo.x86_64"),
}
CREDITS_FILE = "Credits and licences.txt"
LAUNCHER = f"{GAME} - everything unlocked.bat"
MAC_SHARE = Path.home() / "MacShare" / GAME


def godot(*args):
    result = subprocess.run([GODOT, "--headless", "--path", str(ROOT / "game"), *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    if result.returncode != 0:
        sys.exit(f"Godot failed: {' '.join(args)}\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return result


def export(platform, folder, demo=False):
    """Exports one platform of the game or the demo into folder, with the credits beside it, and for the full game on
    Windows the everything-unlocked launcher."""
    preset, name = (DEMO_PRESETS if demo else PRESETS)[platform]
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / name
    target.unlink(missing_ok=True)
    result = godot("--export-release", preset, str(target))
    if not target.exists() or "ERROR:" in result.stdout + result.stderr:
        sys.exit(f"the {platform} export failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    # Godot's licence and those of the libraries in it ask for their notices to ship with the game.
    godot("--script", "res://tools/write_credits.gd", "--", f"--out={folder / CREDITS_FILE}")
    if platform == "windows" and not demo:
        (folder / LAUNCHER).write_bytes((
            "@echo off\r\n"
            f"rem Starts {GAME} with every chapter open and the best of everything. It never saves, so your own workshops stay as they are.\r\n"
            f'start "" "%~dp0{name}" -- --max-state\r\n').encode("ascii"))
    print(f"built {platform}{' demo' if demo else ''}: {target}")
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("platforms", nargs="*", help="windows, macos or linux; every platform when none is given")
    parser.add_argument("--mac-share", action="store_true", help=f"put the Mac build in {MAC_SHARE}")
    parser.add_argument("--demo", action="store_true", help="build the free demo")
    args = parser.parse_args()
    unknown = [p for p in args.platforms if p not in PRESETS]
    if unknown:
        parser.error(f"unknown platform {', '.join(unknown)}; choose from {', '.join(PRESETS)}")
    godot("--import")
    for platform in args.platforms or PRESETS:
        folder = ROOT / "builds" / (f"{platform}-demo" if args.demo else platform)
        if platform == "macos" and args.mac_share:
            folder = MAC_SHARE.with_name(f"{GAME} Demo") if args.demo else MAC_SHARE
        export(platform, folder, args.demo)


if __name__ == "__main__":
    main()
