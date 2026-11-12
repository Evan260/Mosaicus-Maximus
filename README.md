# Mosaicus Maximus

A cozy craft and business game about running a mosaic workshop in a Roman harbour town in AD 72, made for Steam (Windows, Mac, Linux and Steam Deck), in 14 languages.

Clients come to your door with a floor to lay: a guard dog for the entrance, an octopus for the bathhouse, a dining room strewn with the scraps of a feast. You compose the design, buy the stone, and lay it by sweeping a brush so hundreds of tiles cascade into place, then grout it, polish it and watch the client's face at the reveal. Floors buried under the town are dug out and mended the same way, and each one teaches you a pattern nobody has seen in years.

There are no timers and no failure.

## Playing it

The game is made with Godot 4.7. With `GODOT` standing for the Godot executable:

```
GODOT --path game
```

Add `-- --max-state` for a workshop with every chapter open and the best of everything. It is never saved.

## The project

| Folder | What is in it |
|---|---|
| `game/` | The Godot project: scenes, GDScript, shaders, art, sound and the data files |
| `game/data/` | Every number and name in the game, from `motifs.json` to `balance.json` |
| `game/tests/` | Automated checks |
| `docs/` | The Steam setup and publishing, and the release builds |
| `tools/` | Scripts for art, sound, translations, exporting and publishing |
| `store/`, `marketing/` | The Steam page, the achievements and the pictures |
| `builds/` | Exported builds (not kept in git) |

The whole game is described in [Overview.md](Overview.md).

## Checking changes

```
GODOT --headless --path game -- --run-tests
```

It has to print `ALL TESTS PASSED`. After adding or changing any picture or sound, run `GODOT --headless --path game --import`, or the game keeps using the old file.

## Builds

`python tools/export.py` exports Windows, Mac and Linux into `builds/`, each with its credits file beside it. `python tools/steam/publish.py playtest` builds and uploads to Steam; see [Steam publishing](docs/Steam-publishing.md) for the one-time setup.

Pushing a version tag such as `v1.0.0` makes GitHub test the game, build it for Windows, Mac and Linux, sign and notarize the Mac app and attach every build to a release; see [Release builds](docs/Release-builds.md).

## Art and sound

Scenes are pixel art at 480 by 270, painted with PixelLab and drawn or finished by the Python scripts in `tools/art/`. The floors themselves are drawn by code, one small irregular stone at a time. Every sound is a CC0 recording, cut to length by `tools/audio/cut_sounds.py`, and the music is a harp pack by Mythago Music. Everything shipped with the game is credited in [CREDITS.md](CREDITS.md).
