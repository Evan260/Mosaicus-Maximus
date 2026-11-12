"""Build the game and upload it to Steam, so everyone on the chosen branch gets the update automatically.

Usage:
  python tools/steam/publish.py playtest            upload to the Playtest app, live on its test branch
  python tools/steam/publish.py game                upload to the main game, live on its test branch
  python tools/steam/publish.py playtest --note "Faster floor setting"
  python tools/steam/publish.py game --dry-run      build, sign and lay out every platform, but do not upload

The Steam account, app and depot ids are in tools/steam/steam.json; a depot left at 0 is skipped, and a dry run with
no ids yet builds every platform. tools/export.py exports each platform here on Windows, then tools/steam/wsl_build.sh
takes over inside WSL: a Mac app copied through Windows loses its file permissions and will not open, so the builds are
laid out, the Mac app signed and notarized, and the upload made with Valve's Linux steamcmd there.
docs/Steam-publishing.md has the one-time setup.
Steam only lets a script make a build live on a branch other than the default one, so testers choose that branch
once in the game's Properties, Betas; builds for the default branch are set live on the Steamworks site.
"""
import argparse
import datetime
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import export  # noqa: E402  (tools/export.py)

ROOT = Path(__file__).resolve().parents[2]
CONFIG = Path(__file__).with_name("steam.json")
WSL_HOME = "mosaicus-steam"


def fail(text):
    sys.exit("publish: " + text)


def wsl_path(path):
    return "/mnt/" + path.drive[0].lower() + path.as_posix()[2:]


def wsl(*args):
    return subprocess.run(["wsl.exe", "--", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")


def vdf(target, depots, note, content, output):
    mapped = "\n".join(
        f'''\t\t"{depot}"
\t\t{{
\t\t\t"FileMapping"
\t\t\t{{
\t\t\t\t"LocalPath" "{platform}/*"
\t\t\t\t"DepotPath" "."
\t\t\t\t"recursive" "1"
\t\t\t}}
\t\t}}''' for platform, depot in depots.items())
    return f'''"AppBuild"
{{
\t"AppID" "{target["app_id"]}"
\t"Desc" "{note}"
\t"ContentRoot" "{content}"
\t"BuildOutput" "{output}"
\t"SetLive" "{target["branch"]}"
\t"Depots"
\t{{
{mapped}
\t}}
}}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=["playtest", "game"])
    parser.add_argument("--note", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    target = config["targets"][args.target]
    depots = {platform: depot for platform, depot in target["depots"].items() if depot}
    if not target["app_id"] or not depots:
        if not args.dry_run:
            fail(f"set the {args.target} app id and depot ids in {CONFIG} first (see docs/Steam-publishing.md)")
        depots = dict(target["depots"])
        print("note: no Steam ids yet, so the dry run builds every platform")
    if not config["account"] and not args.dry_run:
        fail(f"set the Steam account that uploads builds in {CONFIG} first")
    home = wsl("sh", "-c", "echo $HOME").stdout.strip()
    if not home:
        fail("WSL does not answer; check that Ubuntu is installed (wsl --list)")
    if not args.dry_run and wsl("test", "-x", f"{home}/{WSL_HOME}/steamcmd/steamcmd.sh").returncode != 0:
        fail("WSL is not set up for uploads yet; run tools/steam/wsl_setup.sh once (see docs/Steam-publishing.md)")
    stage = ROOT / "builds" / "steam" / args.target
    if stage.exists():
        shutil.rmtree(stage)
    export.godot("--import")
    for platform in depots:
        export.export(platform, stage / platform)
    work = f"{home}/{WSL_HOME}/{args.target}"
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    note = f"{datetime.date.today()} {commit} {args.note}".strip().replace('"', "'")
    (stage / "app_build.vdf").write_text(vdf(target, depots, note, f"{work}/content", f"{work}/output"), newline="\n")
    command = ["bash", wsl_path(Path(__file__).with_name("wsl_build.sh")), wsl_path(stage), work, config["account"]]
    if args.dry_run:
        command.append("--dry-run")
    result = wsl(*command)
    print(result.stdout[-3000:], result.stderr[-2000:], sep="\n")
    if result.returncode != 0:
        fail("the WSL half stopped; the lines above say why")
    if args.dry_run:
        return
    if "Successfully finished AppID" not in result.stdout:
        fail("the upload did not finish; if steamcmd asked for a password or a Steam Guard code, log in by hand once "
             "(see docs/Steam-publishing.md) and run this again")
    print(f"uploaded and live on the '{target['branch']}' branch of app {target['app_id']}")


if __name__ == "__main__":
    main()
