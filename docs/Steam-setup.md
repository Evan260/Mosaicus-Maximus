# Mosaicus Maximus: Steam Setup

What has to happen on Steam's side before launch. The game already does its part: it records achievements in the save, and sends them to Steam whenever Steam is present.

## 1. Connect the game to Steam

1. Create the app in Steamworks and note its App ID.
2. Add GodotSteam (the GDExtension build for Godot 4.7) to `game/addons/`. The game looks for its `Steam` object and uses it when it is there (`game/scripts/autoload/awards.gd`); without it, nothing breaks.
3. While testing outside Steam, put a file named `steam_appid.txt` holding the App ID next to the game's executable.

## 2. Achievements

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

## 3. Steam Cloud

Use Auto-Cloud; the game needs no code for it. Each workshop slot is saved as `workshop_1.json`, `workshop_2.json` and `workshop_3.json`, each with one backup (`workshop_1.json.bak` and so on). Add two root paths per platform, one for the saves and one for their backups:

| Platform | Root | Subdirectory | Pattern |
|---|---|---|---|
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| macOS | `MacAppSupport` | `Godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Mosaicus Maximus` | `workshop_*.json` |
| Linux | `LinuxXdgDataHome` | `godot/app_userdata/Mosaicus Maximus` | `workshop_*.json.bak` |

The library of kept floors (`library/`) and `settings.cfg` stay on each computer. If the save files are ever renamed, these patterns must change with them in `game/scripts/autoload/saves.gd`, or cloud saves quietly stop syncing.
