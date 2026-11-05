extends SceneTree
## Writes the credits and the engine's licence notice beside a build: --headless --script res://tools/write_licence.gd -- --out=PATH

const CREDITS := """Mosaicus Maximus

Music: Bard's Tales: Peaceful Harp Music Pack (LITE edition) by Amos Chab (Mythago Music),
https://mythagomusic.itch.io/bards-tales-peaceful-harp-music-pack-lite

Fonts: Silkscreen by Jason Kottke and Fusion Pixel by TakWolf, both under the SIL Open Font
Licence 1.1, https://openfontlicense.org

Sounds: recordings from Freesound and Kenney, all CC0.

"""


func _init() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(CREDITS + "Mosaicus Maximus is made with the Godot Engine.\n\n" + Engine.get_license_text() + "\n")
	f.close()
	quit()
