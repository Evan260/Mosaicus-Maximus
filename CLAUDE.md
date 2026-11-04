# Roman Mosaic Workshop: Claude Code Guide

A cozy craft and business game in Godot 4.7 (GDScript, 2D, GL Compatibility). You run a Roman mosaic workshop: design floors for clients, lay them tile by tile, grout and polish them, and restore old floors found under the town. The design is in `Overview.md`; the build plan is in `docs/superpowers/plans/2026-11-04-full-game.md`.

## Where things are

- `game/scripts/autoload/`: `Dev` (command-line options and screenshots), `Data` (everything in `game/data/*.json`), `Audio`, `Settings`, `Game` (the workshop's state), `Saves` (three slots, each with a `.bak`), `Nav` (screens and the two layers), `Tips` (tooltips at the interface's scale; give a control one with `Ui.tip_on`, never `tooltip_text`).
- `game/scripts/design/`: `Stones` (the 16 stones), `FloorDesign`, `Composer` (design to colour map), `MotifLibrary`, `BorderPainter`, `MosaicLayout` (colour map to tiles), `RandomDesign`, `Samples`.
- `game/scripts/floor/`: `FloorView` (every tile in two batches, plus grout, polish, dirt and repairs), `FloorScreen`, `FloorHud`.
- `game/scripts/business/`: `Brief` (wishes, and `judge` for a job's whole verdict), `Looks` (the five qualities clients see, tastes and stars), `Pricing`, `JobFactory` (commissions, copies, contests, restorations), `Story` (finishing jobs, chapters, days, ships, learned tastes), `Damage`, `Library` (kept floors in `user://library/`: picture, thumbnail, design and laying order).
- `game/scripts/screens/`: title, workshop, job board, client visit, design table, reveal, day end, town map, library.
- `game/scripts/ui/`: `UiTheme`, `Ui` helpers, `PlanView`, `MotifIcons`, `LoadingCard`, `SettingsPanel`, `Hotspot` (a clickable workshop piece that lights up), `DogView`, `DogChooser`, `DogPanel`.
- `tools/art/`: `make_ui.py` (interface art), `make_motifs.py` (the pattern book from `motif_sources/`), `pixellab.py` and `make_art.sh` (PixelLab art, costs logged in `ledger.csv`), `make_workshop.sh` (furniture inpainted into the empty room, one step per piece) and `make_workshop_layers.py` (cuts each piece out against the empty room into `assets/art/workshop/` with `layers.json`). The PixelLab token is in `.env`, never in code. `unused/` holds art the game no longer uses.
- `tools/audio/cut_sounds.py`: cuts the game's sounds from `tools/audio/downloads/`. Sources and licences are in `CREDITS.md`.

## Fixed decisions

- The interface is pixel art at 480 by 270, scaled up by a whole number by `Nav`. Floors render at full resolution in `Nav.world`.
- A tile is 6 design pixels; picture panels use half-size tiles through the composer's fine mask.
- Every balance number lives in `game/data/balance.json`. Pacing is checked by `test_pacing_report`.
- Briefs only ask for motifs, tags and stones the player has unlocked (`JobFactory.possible`).
- The workshop is one painted room with every piece cut out of it, so pieces share its light and pixel size. New pieces are inpainted into it, never drawn as separate sprites. A clickable piece's outline and click area come from a shape traced by hand in `SHAPES` in `make_workshop_layers.py`, because the inpainting also changes the shadows, wall and floor round it.
- The reveal shows the floor alone in its walls: no furniture or people.
- A floor's score is 30% wishes and 70% looks (`Looks.judge`), and the weakest quality pulls the looks down. The design table judges with only the taste the player knows (`Story.known_taste`); the reveal uses the client's real taste.
- The player lays every tile, one stone at a time: the brush lays only the stone picked in the tray, nothing is picked for them, and its places glow (`FloorView.guide`). Every floor tool is picked by the player too: the trowel to dig, a stone (one tile a click) or the chisel to mend, then Done, and the sponge and cloth to grout and polish. Mended stones travel to the reveal and library (`apply_stones`).
- `Nav.go` drops every listener the last screen connected to `Nav.resized` and `Game.changed`; inline functions left connected crashed the game on the next window resize.
- The clock runs while a workshop is played (`time` in balance.json). The workshop multiplies its room by `Daylight.light`, draws `SkyView` through the cut-out sky in `room.png`, and lights every workshop picture in its shader (`workshop_light.gdshaderinc`: the hour's daylight plus warm pools round the lamps). `room_sun.png` is the light map: red is painted sunlight, which fades at night, and green the outdoor view, which lamps don't light. A workshop picture's shader must multiply by the incoming `COLOR` and call `workshop_light`.
- Every restoration hides one unowned pattern from up to a chapter ahead, which finishing it adds to the book.
- The dogs are the Farmus Maximus dogs (`assets/art/dogs/`), shown at their own size.

## Running and checking

- Godot: `/c/Users/evand/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`
- After adding a class or any picture or sound: `--headless --path game --import`.
- Tests: `--headless --path game -- --run-tests` must print `ALL TESTS PASSED`.
- Whole-job check: `--path game -- --flow=FOLDER --no-save` plays one job through every screen and saves screenshots.
- Any screen alone: `--path game -- --screen=NAME --no-save --shot-at=3 --shot=OUT.png --quit`. Floors also take `--sample=sea|villa|apse|cave`, `--restore=0.3`, `--fill-at=SECONDS`, `--finish-demo`, `--zoom=`, `--center=x,y`.
- Pointing for screenshots: `--hover=X,Y` and `--click=X,Y` in interface pixels, at `--hover-at` and `--click-at` seconds. `--panel=new|settings|dog|upgrades` opens a panel on the title or workshop, `--pick=N` picks a motif on the design table, and `--library-dir=PATH` points the library at a test folder (with `--no-save` the library is off). `--drag=X0,Y0,X1,Y1` presses and drags (at `--drag-at`). `--hour=H` sets the workshop's clock, `--resize-at=S` resizes the window once, `--dig-done` skips a restoration's digging. `--kind=commission|copy|contest|restoration` gives the design table, client visit or reveal a test job of that kind.
- Recording: add `--write-movie OUT.avi --fixed-fps 60 --quit-after FRAMES` before `--`.
- Build: `--headless --path game --export-release "Windows" "../builds/windows/Roman Mosaic Workshop.exe"`. The Windows preset uses a trimmed engine, `tools/engine/slim.windows.template_release.x86_64.exe` (about 32 MB instead of 107 MB), copied from Farmus Maximus, which builds it with `tools/engine/build_template.py`; `tools/engine/slim_profile.py` records what it leaves out. It has no 3D, physics, regex or noise module, so the game makes its own noise (`SoftNoise`). Check a new build by running `--run-tests` and `--flow=FOLDER` in the exported exe.

## Conventions

- Markdown docs: no em dashes, dollar signs written as `\$`, prices in CAD.
- Comments only for a non-obvious reason, one line.
- Commit only when Evan asks; he is the only author.
