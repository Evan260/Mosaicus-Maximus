"""Make the Steam trailer and the vertical short for YouTube Shorts, Reels and TikTok: record each scripted shot in movie
mode, then cut them together with the cards, captions, the end card and the music, all in Godot, and keep an .mp4 copy
beside each .avi.

Usage:
  python tools/trailer/make_trailer.py              records any shot not yet recorded, then renders the trailer
  python tools/trailer/make_trailer.py shots floor  records just those shots again
  python tools/trailer/make_trailer.py render       renders from the shots already recorded
  python tools/trailer/make_trailer.py render 40    renders a preview from 40 seconds in, into recordings/content/
  Add --cut=NAME to any of these for one of the shorts, named in SHORTS below, whose shots are recorded in a tall
  1080x1920 frame.

Finished videos go to their own folders in marketing/recordings/videos/, beside each one's title, description and
thumbnail; the shot frames they are cut from are kept in marketing/recordings/content/, so a change to an edit renders
again in a minute or two. The shots are scripted in game/tools/trailer/shots.gd and the edits, with their cards,
captions and music, in game/tools/trailer/edit.gd. Every shot plays a fresh workshop that is never saved.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIDEOS = ROOT / "marketing" / "recordings" / "videos"
WORK = ROOT / "marketing" / "recordings" / "content"
FPS = 30
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
          / "ffmpeg-9.0.2-full_build/bin/ffmpeg.exe")
# name: seconds to record. The edit takes its part of each from edit.gd; a shot starts a moment early so its screen has
# opened and settled before the part that is used.
SHOTS = {
    "dawn": 8,
    "client": 13,
    "design": 11,
    "floor": 30,
    "sea": 6,
    "villa": 6,
    "apse": 6,
    "dig": 9,
    "dog": 6,
    "night": 7,
    "endcard": 9,
    "pet_hound": 6,
    "pet_molossian": 6,
    "pet_sighthound": 6,
    "pet_lapdog": 6,
    "pet_sheepdog": 6,
    "guess_dig": 15,
    "first_pour": 7,
    "last_pour": 10,
    "forum_pour": 14,
    "react_cornelia": 7,
    "react_gaius": 7,
    "react_trimalchio": 7,
    "react_livia": 7,
}
# Each cut's shots, its frame, where its shots are kept and where it is written.
CUTS = {
    "trailer": {"shots": ["dawn", "client", "design", "floor", "sea", "villa", "apse", "dig", "dog", "night", "endcard"],
                "size": (1920, 1080), "dir": WORK / "trailer_shots", "out": VIDEOS / "steam_trailer" / "steam_trailer.avi"},
}
# The shorts are all recorded in the tall frame and share their shots.
SHORTS = {
    "one_stone": ("one_stone_at_a_time", ["floor", "dig", "endcard"]),
    "pet_the_dog": ("pet_the_dog", ["pet_hound", "pet_molossian", "pet_sighthound", "pet_lapdog", "pet_sheepdog", "endcard"]),
    "guess_the_floor": ("guess_the_floor", ["guess_dig", "endcard"]),
    "cozy_sounds": ("cozy_sounds", ["floor", "guess_dig", "pet_hound", "endcard"]),
    "first_vs_last": ("first_vs_last", ["first_pour", "last_pour", "endcard"]),
    "client_reviews": ("client_reviews", ["react_cornelia", "react_gaius", "react_trimalchio", "react_livia", "endcard"]),
    "biggest_floor": ("biggest_floor", ["forum_pour", "endcard"]),
}
for _cut, (_folder, _shots) in SHORTS.items():
    CUTS[_cut] = {"shots": _shots, "size": (1080, 1920), "dir": WORK / "short_shots",
                  "out": VIDEOS / f"short_{_folder}" / f"short_{_folder}.avi"}


def godot(args, size):
    """Runs Godot at the cut's size, which movie mode takes from the project's window setting when it starts."""
    override = ROOT / "game" / "override.cfg"
    if override.exists():
        sys.exit(f"{override} already exists; move it aside first")
    override.write_text(f"[display]\n\nwindow/size/window_width_override={size[0]}\nwindow/size/window_height_override={size[1]}\n\n"
                        "[editor]\n\nmovie_writer/mjpeg_quality=0.95\n")
    try:
        subprocess.run([str(GODOT), "--path", str(ROOT / "game"), *args], check=True)
    finally:
        override.unlink()


def record(name, cut):
    folder = cut["dir"] / name
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    w, h = cut["size"]
    # A .png movie is written as numbered frames with the sound beside them in a .wav of the same name.
    godot(["--write-movie", str(folder / "f.png"), "--fixed-fps", str(FPS), "--quit-after", str(SHOTS[name] * FPS),
           "--", f"--window={w}x{h}", "--no-save", f"--trailer-shot={name}"], cut["size"])


def render(name, cut, start=0.0):
    """Renders the cut, or with a start time a preview from that moment on into the work folder."""
    out = WORK / "preview.avi" if start else cut["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    w, h = cut["size"]
    # The edit quits when it ends; the frame limit only stops a run whose script failed to load from going on forever.
    godot(["--write-movie", str(out), "--fixed-fps", str(FPS), "--quit-after", str(200 * FPS), "res://tools/trailer/edit.tscn",
           "--", f"--window={w}x{h}", "--no-save", f"--shots={cut['dir']}", f"--cut={name}", f"--from={start}"], cut["size"])
    if not start:
        mp4_copy(out)
    print(f"ready: {out}")


def mp4_copy(avi):
    """Writes an .mp4 beside the .avi: about a tenth of its size, and the format Instagram, TikTok and most upload pages
    want. Skipped without ffmpeg."""
    if not FFMPEG.exists():
        print("no ffmpeg, so no .mp4 copy")
        return
    subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(avi), "-c:v", "libx264", "-preset", "slow", "-crf", "16",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(avi.with_suffix(".mp4"))],
                   check=True)


def main():
    args = sys.argv[1:]
    name = "trailer"
    for a in args:
        if a.startswith("--cut="):
            name = a.split("=", 1)[1]
            if name not in CUTS:
                sys.exit(f"no cut named {name}; the cuts are {', '.join(CUTS)}")
    args = [a for a in args if not a.startswith("--cut=")]
    cut = CUTS[name]
    if args[:1] == ["shots"]:
        for shot in args[1:] or cut["shots"]:
            record(shot, cut)
        return
    if args[:1] != ["render"]:
        for shot in cut["shots"]:
            if not (cut["dir"] / shot / "f.wav").exists():
                record(shot, cut)
    render(name, cut, float(args[1]) if args[:1] == ["render"] and len(args) > 1 else 0.0)


if __name__ == "__main__":
    main()
