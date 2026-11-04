"""Cuts game sounds out of downloaded recordings in tools/audio/downloads.

Run: python tools/audio/cut_sounds.py
Tap recordings are split at every hit automatically, and the sharpest hits are kept as game/assets/audio/tiles/SET_N.wav.
Wiping recordings are cut into strokes in game/assets/audio/tools/, and harp notes are trimmed into game/assets/audio/harp/.
Sources and licences are listed in CREDITS.md.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt

ROOT = Path(__file__).resolve().parents[2]
DOWNLOADS = ROOT / "tools" / "audio" / "downloads"
TILES = ROOT / "game" / "assets" / "audio" / "tiles"
HARP = ROOT / "game" / "assets" / "audio" / "harp"
RATE = 44100

# set name: list of (recording, hits to keep, longest hit in seconds, (start, end) window or None, only the first hit of
# each bounce when this many seconds separate them or 0)
TAPS = {
    "stone": [("875424_16682330", 11, 0.16, None, 0), ("875428_16682330", 3, 0.2, None, 0)],
    "soft": [("329099_3035766", 8, 0.14, None, 0), ("391765_1421481", 6, 0.16, (0, 19.2), 0)],
    "glass": [("639754_12993943", 3, 0.14, (0, 1.9), 0), ("532149_5911297", 6, 0.12, None, 0.8)],
    "gold": [("558992_556505", 1, 0.4, None, 0), ("37225_43834", 4, 0.35, (0, 14), 0.8)],
}
# set name: list of (recording, (start, end), length of each stroke in seconds, strokes to keep)
STROKES = {
    "sponge": [("521948_311243", (0, 1.06), 0.33, 3), ("634141_522747", (4.0, 43.0), 0.6, 8)],
    "cloth": [("364363_5993052", (1.7, 14.6), 0.6, 10)],
}
# output name: (recording, start in seconds or None to start at the first sound, length in seconds, fade-out seconds)
NOTES = {
    "note_m59": ("373559_2475994", None, 3.0, 1.4),
    "note_m62": ("373565_2475994", None, 3.0, 1.4),
    "note_m65": ("373570_2475994", None, 3.0, 1.4),
    "note_m69": ("373556_2475994", None, 3.0, 1.4),
    "note_m72": ("373563_2475994", None, 3.0, 1.4),
    "note_m76": ("373568_2475994", None, 2.8, 1.3),
    "note_m79": ("373573_2475994", None, 2.6, 1.2),
    "note_m83": ("373560_2475994", None, 2.4, 1.1),
    "note_m86": ("373566_2475994", None, 2.2, 1.0),
    "note_m89": ("373571_2475994", None, 2.0, 0.9),
    "chord": ("218376_4070508", 3.7, 3.6, 1.6),
    "gliss": ("610703_7772719", None, 2.6, 0.9),
}
TOOLS = ROOT / "game" / "assets" / "audio" / "tools"


def read(name):
    """Any downloaded file as mono float samples at 44.1 kHz, decoded by ffmpeg."""
    src = next(DOWNLOADS.glob(name + ".*"), None) or DOWNLOADS / name
    if not src.exists():
        sys.exit(f"missing recording: {name}")
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(src), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def highpass(x, hz):
    return sosfiltfilt(butter(2, hz, "highpass", fs=RATE, output="sos"), x)


def envelope(x, ms=2.0):
    k = max(1, int(RATE * ms / 1000))
    return np.convolve(np.abs(x), np.ones(k) / k, mode="same")


def level(x, peak_db):
    m = np.max(np.abs(x))
    return x * (10 ** (peak_db / 20) / m) if m > 0 else x


def fade(x, fade_in=0.002, fade_out=0.02):
    n_in = min(len(x), int(RATE * fade_in))
    n_out = min(len(x), int(RATE * fade_out))
    x = x.copy()
    x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x


def find_hits(x, longest):
    """Start and end of every separate hit: a sharp rise well above the quiet between hits."""
    env = envelope(x)
    floor = np.percentile(env, 30)
    top = np.max(env)
    threshold = floor + (top - floor) * 0.08
    hits = []
    i = 0
    gap = int(RATE * 0.06)
    while i < len(env):
        if env[i] > threshold:
            start = max(0, i - int(RATE * 0.003))
            peak = start + int(np.argmax(env[start:start + int(RATE * 0.02)]))
            quiet = env[peak] * 0.03
            end = peak
            limit = min(len(env), start + int(RATE * longest))
            while end < limit and env[end] > max(quiet, floor * 1.5):
                end += 1
            hits.append((start, end, env[peak]))
            i = end + gap
        else:
            i += 1
    return hits


def sharpness(clip):
    """Peak over loudness: crisp, clean clicks score high; rumbles, scrapes and double hits score low."""
    rms = np.sqrt(np.mean(clip ** 2)) + 1e-9
    return np.max(np.abs(clip)) / rms


def first_sound(x):
    env = envelope(x, 5)
    above = np.nonzero(env > np.max(env) * 0.02)[0]
    return max(0, int(above[0]) - int(RATE * 0.005)) if len(above) else 0


def strokes(x, piece):
    """Cuts a stretch of wiping into strokes, splitting at the quietest moment near each expected boundary."""
    env = envelope(x, 25)
    n = int(RATE * piece)
    cuts = [0]
    while cuts[-1] + n * 1.5 < len(x):
        lo, hi = cuts[-1] + int(n * 0.6), min(len(x) - 1, cuts[-1] + int(n * 1.4))
        cuts.append(lo + int(np.argmin(env[lo:hi])))
    return [x[a:b] for a, b in zip(cuts, cuts[1:])]


def main():
    for folder in (TILES, HARP, TOOLS):
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("*.wav"):
            old.unlink()
    for set_name, sources in TAPS.items():
        cuts = []
        for name, keep, longest, window, bounce in sources:
            x = highpass(read(name), 150)
            if window:
                x = x[int(window[0] * RATE):int(window[1] * RATE)]
            hits = find_hits(x, longest)
            if bounce:
                firsts = []
                for h in hits:
                    if not firsts or h[0] - firsts[-1][0] > bounce * RATE:
                        firsts.append(h)
                hits = firsts
            clips = [x[s:e] for s, e, _ in hits if e - s > int(RATE * 0.012)]
            clips.sort(key=sharpness, reverse=True)
            print(f"{set_name}: {name} has {len(hits)} hits, keeping {min(keep, len(clips))}")
            cuts += clips[:keep]
        for k, clip in enumerate(cuts, 1):
            sf.write(TILES / f"{set_name}_{k}.wav", fade(level(clip, -1.0), 0.001, min(0.03, len(clip) / RATE * 0.4)), RATE, subtype="PCM_16")
    for set_name, sources in STROKES.items():
        cuts = []
        for name, (a, b), piece, keep in sources:
            x = highpass(read(name), 120)[int(a * RATE):int(b * RATE)]
            pieces = strokes(x, piece)
            pieces.sort(key=lambda c: np.sqrt(np.mean(c ** 2)), reverse=True)
            print(f"{set_name}: {name} gives {len(pieces)} strokes, keeping {min(keep, len(pieces))}")
            cuts += pieces[:keep]
        for k, clip in enumerate(cuts, 1):
            sf.write(TOOLS / f"{set_name}_{k}.wav", fade(level(clip, -2.0), 0.03, 0.08), RATE, subtype="PCM_16")
    for out, (name, start, length, fade_out) in NOTES.items():
        x = highpass(read(name), 60)
        a = first_sound(x) if start is None else int(start * RATE)
        clip = x[a:a + int(length * RATE)]
        sf.write(HARP / f"{out}.wav", fade(level(clip, -3.0), 0.002, fade_out), RATE, subtype="PCM_16")
        print(f"{out}: {name} from {a / RATE:.2f}s")


if __name__ == "__main__":
    main()
