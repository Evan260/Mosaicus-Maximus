"""Paint a portrait for everyone in game/data/people.json who doesn't have one yet, in the same style as the regulars'.

Usage: python tools/art/make_portraits.py [--dry-run]
Writes game/assets/art/portraits/<id>.png. People whose entry names an existing "portrait" already have their face.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PORTRAITS = ROOT / "game" / "assets" / "art" / "portraits"


def everyone():
    people = json.loads((ROOT / "game" / "data" / "people.json").read_text(encoding="utf-8"))
    out = []
    for group in ("townsfolk", "collectors", "finders"):
        out += people.get(group, [])
    out += [people[k] for k in ("neighbour", "herald") if k in people]
    return out


def main():
    dry = "--dry-run" in sys.argv
    missing = [p for p in everyone() if "portrait" not in p and not (PORTRAITS / f"{p['id']}.png").exists()]
    print(f"{len(missing)} portraits to paint")
    for p in missing:
        out = PORTRAITS / f"{p['id']}.png"
        description = f"head and shoulders portrait of {p['look']}, ancient Rome, front view, friendly expression, cozy pixel art, warm light"
        if dry:
            print(" ", out.name, "-", p["look"])
            continue
        for attempt in range(4):
            subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "pixellab.py"), "pixen", description, "64x64",
                            "--out", str(out.relative_to(ROOT)), "--transparent", "--outline", "single color black outline",
                            "--detail", "medium detail", "--view", "side", "--raw"], cwd=ROOT, timeout=200)
            if out.exists():
                print("made", out.name)
                break


if __name__ == "__main__":
    main()
