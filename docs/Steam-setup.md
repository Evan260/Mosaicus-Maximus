# Mosaicus Maximus: Steam Setup

What has to happen on Steam's side before launch. The game already does its part: it records achievements in the save, and sends them to Steam whenever Steam is present. How builds get to Steam is in `Steam-publishing.md`.

## 1. Connect the game to Steam

GodotSteam is already in `game/addons/godotsteam/`, and `game/scripts/autoload/awards.gd` uses it whenever the game runs through Steam; without Steam, nothing breaks. Creating the app, its depots and launch options, testing with Valve's App ID 480 through a git-ignored `steam_appid.txt`, and uploading builds are all in `Steam-publishing.md`.

## 2. The store page

Everything the store page needs is in `store/steam_page`: the capsules, the library art, the page background, the icons, the twelve screenshots and the text (the short description, About This Game, tags, languages, system requirements and the AI content disclosure). Its `README.txt` says which file goes in which Steamworks slot, and lists what is still to decide, such as the price in CAD.

`python tools/steam/make_store_art.py` makes the pictures from the game itself: the capsules and library hero are mosaic floors the game lays at each picture's exact size, with the logo over them; the page background is the workshop at dusk; the screenshots are moments of the recorded trailer shots (any shot not yet recorded is recorded first). It writes only to `store/steam_page`, rendering the pieces it crops or combines into a temporary folder that it removes afterwards. Run it again after the art changes. The text files are written by hand.

## 3. Achievements

Enter each of these in Steamworks under Stats and Achievements, with exactly this API name. The list comes from `game/data/achievements.json`; regenerate this table if that list changes. Achievements earned before Steam was connected are sent the next time a screen opens with Steam running.

Each achievement also needs two 64 by 64 icons in Steamworks: one for when it is earned and a grey one for before. They are in `store/achievements`: `<API name>.jpg` is the earned icon and `<API name>_locked.jpg` the grey one, and `sheet.png` shows them all side by side. `python tools/art/make_achievement_icons.py` makes them from the game's own art; when an achievement is added, choose its picture in that script's `ART` list (it refuses to run until every achievement has one) and run it again.

| API name | Name | Description |
|---|---|---|
| `first_floor` | A first floor | Finish your first floor |
| `floors_10` | Steady hands | Finish 10 floors |
| `floors_50` | Master of the workshop | Finish 50 floors |
| `five_stars` | A masterpiece | Earn five stars for a floor |
| `five_stars_10` | Nothing but the best | Earn five stars ten times |
| `chapter_2` | Colour comes to town | Reach chapter 2 |
| `chapter_3` | Pictures in stone | Reach chapter 3 |
| `chapter_4` | Glass and gold | Reach chapter 4 |
| `first_dig` | Under the dirt | Restore an old floor |
| `digs_10` | Keeper of old floors | Restore 10 old floors |
| `all_patterns` | The full pattern book | Own every pattern and picture in the pattern book |
| `contest_win` | Crowned by the aediles | Win the town's floor contest |
| `contest_5` | The rival's despair | Win the floor contest five times |
| `perfect_copy` | Stone for stone | Copy a famous floor with a likeness of 95% or more |
| `first_story` | A friend for life | See a regular client's story through to the end |
| `all_stories` | The whole town | See every regular client's story through to the end |
| `all_tastes` | Just how you like it | Learn every regular client's taste |
| `temple` | For Venus | Lay the floor of the temple of Venus |
| `forum` | Beneath the forum | Restore the great floor under the forum |
| `earn_1000` | A full purse | Earn 1,000 denarii |
| `earn_10000` | Patron of the arts | Earn 10,000 denarii |
| `big_floor` | Ten thousand stones | Lay a floor of 10,000 tiles or more |
| `ship_stone` | From over the sea | Buy stone off a merchant ship |
| `good_dog` | Good dog | Pet your dog 25 times |
| `library_10` | A gallery of floors | Keep 10 floors in your library |
| `festival_prize` | Garlands for the winner | Win a festival prize |
| `all_festivals` | A year of feasts | Win the prize at every festival |
| `good_nose` | Good nose | Let your dog find an old floor |
| `first_panel` | A small masterpiece | Lay a picture panel at the workbench |
| `panel_set` | Set in stone | Set one of your picture panels into a client's floor |
| `wall_mosaic` | Glass on the wall | Make a wall mosaic for a fountain niche |

## 4. Steam Cloud

Use Auto-Cloud; the game needs no code for it. Each workshop slot is saved as `workshop_1.json`, `workshop_2.json` and `workshop_3.json`, each with three rotating backups (`workshop_1.json.bak1` to `.bak3`, and an older save's single `workshop_1.json.bak`). Add two root paths per platform, one for the saves and one for their backups:

| Platform | Root | Subdirectory | Pattern |
|---|---|---|---|
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak*` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak*` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak*` |

The patterns leave out `workshop_N.json.tmp`, which only exists while a save is being written. The library of kept floors (`library/`) and `settings.cfg` stay on each computer. If the save files are ever renamed, these patterns must change with them in `game/scripts/autoload/saves.gd`, or cloud saves quietly stop syncing.

## 5. Rich presence

Steam shows friends what the player is doing, such as "Laying a floor for Livia" or "Day 12 in the workshop". `game/scripts/autoload/awards.gd` sets `steam_display` to one of the tokens in `tools/steam/rich_presence.vdf` and fills in `%client%` (a client's own name, which reads the same in every language) or `%day%`. It tells Steam only when that changes, and never when Steam is not running.

The file holds every token in all fourteen of the game's languages. Upload it in Steamworks under Community, Rich Presence (for the main game and for the demo): choose the file and press Upload. Steam checks it there and shows any token a language is missing. After changing the tokens in `awards.gd`, change the file to match and upload it again; `test_steam_rich_presence_says_what_the_player_is_doing` checks that every language has every token with the same words filled in.

| Token | English |
|---|---|
| `#Status_Title` | Choosing a workshop |
| `#Status_Workshop` | Day %day% in the workshop |
| `#Status_Designing` | Designing a floor for %client% |
| `#Status_DesigningAny` | Designing a floor |
| `#Status_Laying` | Laying a floor for %client% |
| `#Status_LayingAny` | Laying a floor |
| `#Status_Restoring` | Restoring an old floor |
| `#Status_Contest` | Making a floor for the town contest |
| `#Status_Panel` | Making a picture panel |
| `#Status_FreeDesign` | In free design |
| `#Status_Town` | Walking round the town |
| `#Status_Library` | Looking through the library |

## 6. Demo

The demo is the same project exported with the `demo` export presets in `game/export_presets.cfg` (Windows on the trimmed engine with GodotSteam, macOS and Linux), which set the `demo` feature that `Game.is_demo()` reads. It plays chapters 1 and 2 (`demo.chapters` in `game/data/balance.json`) and ends where chapter 3 would open: the workshop shows an end card once, with thanks, a look at picture panels and glass and gold, and a Wishlist on Steam button. Anything past it, such as later patterns, borders and chapters, reads "In the full game". Its save sits in the same folder as the full game's, so progress carries over on the same computer, and the full game opens chapter 3 as soon as it loads that workshop.

Achievements work as in the full game: they are earned into the save, and since the demo app has none of its own on Steam, they reach Steam the first time the full game opens that workshop.

In Steamworks, the demo is an app of its own, linked to the main game:

1. On the main game's Steamworks page, under All Associated Packages, DLC, Demos and Tools, create a demo. Steam gives it its own App ID.
2. Set it up like the main game (steps 2 to 6 of the Steamworks setup in `Steam-publishing.md`): three depots, a `testing` branch, App Bundles Are Notarized, and these launch options:
   - `Mosaicus Maximus Demo.exe`, Windows
   - `Mosaicus Maximus.app`, macOS (Godot names the Mac app after the project, so the demo's app keeps the full game's name)
   - `Mosaicus Maximus Demo.x86_64`, Linux + SteamOS
3. Put its App ID and depots into `targets.demo` in `tools/steam/steam.json`.
4. Put the main game's App ID into `demo.store_app_id` in `game/data/balance.json`. The Wishlist on Steam buttons on the title and the end card stay hidden while it is 0, and `publish.py demo` refuses to upload until it matches the game's App ID in `steam.json`.
5. Upload the rich presence file to the demo too (section 5).
6. Upload it with `python tools/steam/publish.py demo`. As with the main game, the build goes live on `testing`, and you set it live on the default branch in Steamworks when the demo is ready to release.
