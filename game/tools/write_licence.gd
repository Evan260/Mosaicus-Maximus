extends SceneTree
## Writes the engine's licence notice beside a build: --headless --script res://tools/write_licence.gd -- --out=PATH


func _init() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("Roman Mosaic Workshop is made with the Godot Engine.\n\n" + Engine.get_license_text() + "\n")
	f.close()
	quit()
