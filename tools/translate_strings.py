"""Fill in the game's translations with Azure AI Translator, the same service Farmus Maximus uses.

Reads game/translations/strings.csv (one row per English string, one column per language), sends only the empty
cells to Azure, and writes the answers back, saving after each language so an interrupted run loses nothing.
Placeholders such as %s, %d, %.1f and {name} are shielded so they come back exactly as they went in.

Usage:
    python tools/translate_strings.py                    every language below
    python tools/translate_strings.py --languages fr,ja  just those
    python tools/translate_strings.py --dry-run          count what is missing and what it would cost, send nothing
    python tools/translate_strings.py --redo fr          clear one language's cells first, then translate it afresh
    add --yes to skip the cost confirmation

The key comes from AZURE_TRANSLATOR_KEY and AZURE_TRANSLATOR_REGION (default "canadacentral"), set in the shell or in
the git-ignored .env at the repository root. Azure's free tier covers 2 million characters a month; one full run of
every language is far under that. Run tools/extract_strings.py first so new strings are in the sheet, then reimport
the project in Godot so each column becomes a translation file.
"""
import csv
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "game" / "translations" / "strings.csv"
ENDPOINT = "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&to={to}&textType=html"
# Godot's locale code for each column, and the code Azure knows the language by.
LANGUAGES = {
    "fr": "fr", "de": "de", "es": "es", "it": "it", "pt_BR": "pt", "pl": "pl", "tr": "tr", "ru": "ru", "uk": "uk",
    "ja": "ja", "ko": "ko", "zh_CN": "zh-Hans", "zh_TW": "zh-Hant",
}
# Azure takes at most 100 texts and 10,000 characters a request; staying under both leaves room for the shielding.
MAX_TEXTS, MAX_CHARS = 50, 9000
USD_PER_MILLION = 10.0
# Godot's own format codes, so a percent sign in a sentence such as "95% or more" is translated as words.
PLACEHOLDER = re.compile(r"%[-0-9.]*[sdifxXcv%]|\{[A-Za-z0-9_]*\}")


def read_env():
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def shield(text):
    """The text as HTML, with each placeholder wrapped so the translator leaves it alone."""
    parts, last = [], 0
    for m in PLACEHOLDER.finditer(text):
        parts.append(html.escape(text[last:m.start()], quote=False))
        parts.append(f'<span class="notranslate">{html.escape(m.group(0), quote=False)}</span>')
        last = m.end()
    parts.append(html.escape(text[last:], quote=False))
    return "".join(parts)


def unshield(text):
    text = re.sub(r'<span class="notranslate">(.*?)</span>', r"\1", text)
    return html.unescape(text)


def batches(texts):
    batch, size = [], 0
    for t in texts:
        if batch and (len(batch) >= MAX_TEXTS or size + len(t) > MAX_CHARS):
            yield batch
            batch, size = [], 0
        batch.append(t)
        size += len(t)
    if batch:
        yield batch


def translate(batch, to, key, region):
    body = json.dumps([{"Text": t} for t in batch]).encode("utf-8")
    for attempt in range(6):
        req = urllib.request.Request(ENDPOINT.format(to=to), data=body, method="POST", headers={
            "Ocp-Apim-Subscription-Key": key, "Ocp-Apim-Subscription-Region": region,
            "Content-Type": "application/json; charset=UTF-8"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return [item["translations"][0]["text"] for item in json.load(r)]
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise SystemExit(f"Azure answered {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
            wait = float(e.headers.get("Retry-After") or min(120, 5 * 2 ** attempt))
            print(f"  busy, waiting {wait:.0f} s")
            time.sleep(wait)
    raise SystemExit("Azure stayed busy; try again later")


def load():
    with CSV_PATH.open(encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    return rows[0], rows[1:]


def save(header, rows):
    with CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    args = sys.argv[1:]
    wanted = list(LANGUAGES)
    if "--languages" in args:
        wanted = args[args.index("--languages") + 1].split(",")
        unknown = [w for w in wanted if w not in LANGUAGES]
        if unknown:
            raise SystemExit(f"Unknown language {unknown}; choose from {', '.join(LANGUAGES)}")
    header, rows = load()
    for lang in wanted:
        if lang not in header:
            header.append(lang)
            for r in rows:
                r.append("")
    for r in rows:
        r.extend([""] * (len(header) - len(r)))
    if "--redo" in args:
        redo = args[args.index("--redo") + 1]
        col = header.index(redo)
        for r in rows:
            r[col] = ""
    todo = {lang: [r for r in rows if not r[header.index(lang)].strip()] for lang in wanted}
    chars = sum(len(r[0]) for missing in todo.values() for r in missing)
    for lang, missing in todo.items():
        print(f"{lang:6} {len(missing):4} strings to translate")
    print(f"{chars:,} characters, about ${chars / 1e6 * USD_PER_MILLION:.2f} at Azure's paid rate (free within 2M a month)")
    if "--dry-run" in args or chars == 0:
        return
    read_env()
    key = os.environ.get("AZURE_TRANSLATOR_KEY")
    if not key:
        raise SystemExit("Set AZURE_TRANSLATOR_KEY (and AZURE_TRANSLATOR_REGION) in the shell or in .env first")
    region = os.environ.get("AZURE_TRANSLATOR_REGION", "canadacentral")
    if "--yes" not in args and input("Translate now? [y/N] ").strip().lower() != "y":
        return
    for lang, missing in todo.items():
        if not missing:
            continue
        col = header.index(lang)
        done = 0
        for batch in batches(missing):
            answers = translate([shield(r[0]) for r in batch], LANGUAGES[lang], key, region)
            for r, a in zip(batch, answers):
                r[col] = unshield(a)
            done += len(batch)
            print(f"  {lang}: {done}/{len(missing)}")
        save(header, rows)
        # A placeholder that did not survive would show raw or crash a format call, so it is cleared to be redone.
        for r in missing:
            if sorted(PLACEHOLDER.findall(r[0])) != sorted(PLACEHOLDER.findall(r[col])):
                print(f"  {lang}: placeholders changed in {r[0]!r} -> {r[col]!r}; left empty")
                r[col] = ""
        save(header, rows)
    print("Done. Reimport the project in Godot so every language column becomes a translation file.")


if __name__ == "__main__":
    main()
