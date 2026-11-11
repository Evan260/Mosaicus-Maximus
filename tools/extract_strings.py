"""Collect every player-facing string into game/translations/strings.csv for translators.

The interface wraps most of its text in tr("...") or TranslationServer.translate("..."), and words kept in the save to
be read later, such as a job's notice, in Ui.say("..."). Other text sits in the
scripts' own tables, such as the tastes or the town's districts, and Godot translates it where a label or button shows
it, so every string literal that reads like words is collected too; a row nobody sees costs nothing. Names, lines and
letters come from game/data/*.json, and the forms the game builds from them (a motif's name inside a sentence, with its
article, or in a client's wish) are added as their own rows, since other languages change the words round them.
Existing translations are kept, new strings are added with the English filled in, and rows for text the game no longer
has are dropped.
Usage: python tools/extract_strings.py
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "game"
OUT = ROOT / "translations" / "strings.csv"
# Fields of game/data/*.json that the player reads. "look" describes a portrait for the art tools and is never shown.
DATA_FIELDS = {"name", "title", "text", "trade", "greeting", "line", "after", "who", "wants", "gossip"}

LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Lines that pass strings to the engine, or to the ledger nobody reads, rather than to the player.
ENGINE_LINE = re.compile(r"Audio\.|AudioServer|get_node|res://|user://|push_|print|has_method|connect\(|add_theme|"
                         r"set_stylebox|set_color|set_constant|set_icon|set_font|set_type_variation|find_children|Engine\.|"
                         r"\.bus\b|path_join|InputMap|is_action|load\(|\.name = |spend\(|earn\(|\"what\":|Dev\.")
# Names that stay as they are in every language: the game's own, the player's default name, theme names and buses.
KEEP = {"Mosaicus Maximus", "Steam", "Lucia", "Dev", "Hant", "Heading", "Label", "Button", "Master", "Effects", "World"}
# Scripts whose text only the developer sees.
DEV_SCRIPTS = {"dev.gd"}


def unescape(s):
    """The string as GDScript reads it: escapes such as \\n and \\" undone, and letters such as ñ left alone."""
    return s.encode("latin-1", "backslashreplace").decode("unicode_escape")


def reads_like_words(s):
    """True for a string a player could read: a capitalised word or phrase, or a phrase of lower-case words such as a
    taste, and never an engine class name such as VBoxContainer or a pixel pattern such as YKYKY."""
    if s in KEEP or s != s.strip() or not re.search(r"[a-z]{2,}", s):
        return False
    if re.match(r"[A-Z]", s):
        return " " in s or not re.search(r"[A-Z]", s[1:])
    return " " in s and not re.search(r"[_/]|\.png|\.gd", s)


def from_scripts():
    found = []
    pattern = re.compile(r'\b(?:tr|TranslationServer\.translate|say)\(\s*"((?:[^"\\]|\\.)*)"')
    for f in sorted((ROOT / "scripts").rglob("*.gd")):
        text = f.read_text(encoding="utf-8")
        for m in pattern.finditer(text):
            found.append(unescape(m.group(1)))
        if f.name in DEV_SCRIPTS:
            continue
        for line in text.splitlines():
            if line.lstrip().startswith("#") or ENGINE_LINE.search(line):
                continue
            for m in LITERAL.finditer(line.split(" # ")[0]):
                s = unescape(m.group(1))
                if reads_like_words(s):
                    found.append(s)
    return found


def native_names():
    """The language picker shows each language in its own words, so those names are never translated."""
    text = (ROOT / "scripts" / "ui" / "settings_panel.gd").read_text(encoding="utf-8")
    block = re.search(r"const NATIVE_NAMES := \{(.*?)\}", text, re.S).group(1)
    return set(re.findall(r':\s*"([^"]+)"', block))


def read(name):
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


def from_data():
    found = []

    def walk(node, key=""):
        if isinstance(node, dict):
            for k, v in node.items():
                walk(v, k)
        elif isinstance(node, list):
            for v in node:
                walk(v, key)
        elif isinstance(node, str) and key in DATA_FIELDS:
            found.append(node)

    for f in sorted((ROOT / "data").glob("*.json")):
        walk(json.loads(f.read_text(encoding="utf-8")))
    return [f for f in found if f and f not in KEEP]


def derived():
    """The forms the game builds from names, as Data, Stones and Brief build them."""
    found = []
    stones = re.findall(r'"name": "([^"]+)"', (ROOT / "scripts" / "design" / "stones.gd").read_text(encoding="utf-8"))
    brief = (ROOT / "scripts" / "business" / "brief.gd").read_text(encoding="utf-8")
    tags = re.findall(r':\s*"([^"]+)"', re.search(r"const TAG_WORDS := \{(.*?)\}", brief, re.S).group(1))
    for s in stones:
        found += [s, s.lower(), "Uses " + s.lower(), "No " + s.lower()]
    found += tags + ["Shows " + t for t in tags]
    for m in read("motifs.json"):
        lower = m.get("lower", m["name"].lower())
        found += [lower, m.get("a", ("an " if lower[:1] in "aeiou" else "a ") + lower)]
        found.append("Has " + found[-1])
    for name in ["rooms.json", "borders.json", "upgrades.json"]:
        found += [r["name"].lower() for r in read(name)]
    return found


def main():
    rows = {}
    languages = ["en"]
    if OUT.exists():
        with OUT.open(encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            languages = header[1:]
            for r in reader:
                rows[r[0]] = r[1:]
    wanted = set(from_scripts() + from_data() + derived()) - native_names()
    rows = {k: v for k, v in rows.items() if k in wanted}
    for s in wanted:
        if s not in rows:
            rows[s] = [s] + [""] * (len(languages) - 1)
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["keys"] + languages)
        for key in sorted(rows):
            w.writerow([key] + rows[key])
    print(f"{len(rows)} strings in {OUT.relative_to(ROOT.parent)} for {', '.join(languages)}")


if __name__ == "__main__":
    main()
