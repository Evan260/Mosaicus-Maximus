"""Writes game/scripts/startup_files.gd: the files a player's launch loads once the loading screen is up, which the
loading screen then loads in the background to fill its bar.

    python tools/list_startup_files.py

Run it after changing what the title loads. It starts the game as a player would, with no save, and lists every file
loaded after the loading screen begins until it hands over to the title, scripts and scenes aside, since they load with the game.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
OUT = GAME / "scripts" / "startup_files.gd"
GODOT = os.environ.get("GODOT", str(Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"))
LAUNCH = ["--boot", "--no-save"]
HEADER = "## The files the loading screen loads in the background to fill its bar, written by tools/list_startup_files.py.\n\n"
BEGIN = "Boot: loading the title's files"
END = "Boot: done"
LOADED = re.compile(r"Loading resource: (res://\S+)")


def write(paths: list[str]) -> None:
    body = "const FILES: Array[String] = [\n" + "".join(f'\t"{p}",\n' for p in paths) + "]\n" if paths else "const FILES: Array[String] = []\n"
    OUT.write_text(HEADER + body, encoding="utf-8", newline="\n")


def main() -> int:
    # The run starts from an empty list, so the list holds only what the game itself loads.
    write([])
    run = subprocess.run([GODOT, "--headless", "--verbose", "--path", str(GAME), "--quit-after", "900", "--", *LAUNCH],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    paths: list[str] = []
    started = False
    for line in run.stdout.splitlines():
        if BEGIN in line:
            started = True
        elif END in line:
            break
        elif started and (m := LOADED.search(line)):
            path = m.group(1)
            if path.startswith("res://.godot/") or path.endswith((".gd", ".gdc", ".tscn")) or path in paths:
                continue
            paths.append(path)
    if not started:
        print("The loading screen never began; the list is left empty.", file=sys.stderr)
        return 1
    write(paths)
    print(f"{len(paths)} files in {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
