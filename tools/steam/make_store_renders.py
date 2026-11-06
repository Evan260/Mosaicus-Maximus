"""Save the Steam store page's screenshots: moments of the game exactly as it draws them at 1920x1080, picked from the
trailer's recorded shots, which play a fresh workshop that is never saved.

Usage: python tools/steam/make_store_renders.py
Any shot not yet recorded is recorded first with tools/trailer/make_trailer.py. Writes marketing/store_renders/.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "marketing" / "recordings" / "content" / "trailer_shots"
OUT = ROOT / "marketing" / "store_renders"
FPS = 30
# name: (trailer shot, seconds into it).
SCREENSHOTS = {
    "shot_01_the_workshop": ("dog", 1.0),
    "shot_02_the_job_board": ("client", 3.0),
    "shot_03_a_client_visits": ("client", 6.2),
    "shot_04_the_design_table": ("design", 10.7),
    "shot_05_laying_the_doves": ("floor", 3.3),
    "shot_06_laying_the_flower": ("floor", 6.4),
    "shot_07_grout_and_polish": ("floor", 13.5),
    "shot_08_in_her_bedroom": ("floor", 22.0),
    "shot_09_an_old_floor_dug_up": ("dig", 2.4),
    "shot_10_a_villa_dining_room": ("villa", 5.8),
    "shot_11_a_floor_of_the_sea": ("endcard", 4.0),
    "shot_12_the_workshop_at_night": ("night", 3.0),
}


def main():
    missing = sorted({shot for shot, _ in SCREENSHOTS.values() if not (SHOTS / shot / "f.wav").exists()})
    if missing:
        subprocess.run([sys.executable, str(ROOT / "tools" / "trailer" / "make_trailer.py"), "shots", *missing], check=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (shot, seconds) in SCREENSHOTS.items():
        frame = SHOTS / shot / f"f{round(seconds * FPS):08d}.png"
        shutil.copyfile(frame, OUT / f"{name}.png")
        print(f"{name}: {shot} at {seconds} s")


if __name__ == "__main__":
    main()
