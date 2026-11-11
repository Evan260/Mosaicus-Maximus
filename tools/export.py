"""Build the Windows game into builds/windows/: the exe, "Credits and licences.txt", and the launcher that opens a
workshop with everything unlocked, which never saves.

Usage: python tools/export.py   (GODOT may name the Godot console exe; the WinGet install is used otherwise)
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "windows"
GAME = "Mosaicus Maximus"
GODOT = os.environ.get("GODOT", str(Path.home() / "AppData/Local/Microsoft/WinGet/Packages"
    / "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"))
LAUNCHER = f"""@echo off
rem Starts {GAME} with every chapter open and the best of everything. It never saves, so your own workshops stay as they are.
start "" "%~dp0{GAME}.exe" -- --max-state
"""


def godot(*args):
    if subprocess.run([GODOT, "--headless", "--path", str(ROOT / "game"), *args]).returncode != 0:
        sys.exit(f"Godot failed: {' '.join(args)}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    godot("--import")
    godot("--export-release", "Windows", str(OUT / f"{GAME}.exe"))
    godot("--script", "res://tools/write_credits.gd", "--", f"--out={OUT / 'Credits and licences.txt'}")
    (OUT / f"{GAME} - everything unlocked.bat").write_text(LAUNCHER.replace("\n", "\r\n"), encoding="ascii", newline="")
    print(f"built {OUT}")


if __name__ == "__main__":
    main()
