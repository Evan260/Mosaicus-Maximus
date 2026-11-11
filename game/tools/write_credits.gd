extends SceneTree
## Writes "Credits and licences.txt", which ships beside the game: who made it, the music, every recorded sound with its
## licence, the fonts, and the Godot engine's licence with the full licences of the libraries built into it. The MIT
## licence of Godot asks for its notice to go out with the game.
##   Godot --headless --path game --script res://tools/write_credits.gd -- --out=PATH

const CREDITS := "res://data/credits.json"


func _init() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("write_credits: give --out=PATH")
		quit(1)
		return
	var credits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CREDITS))
	var text := PackedStringArray(["MOSAICUS MAXIMUS", ""])
	for part in [["made_by", "Made by"], ["music", "Music"], ["sounds", "Sounds"], ["font", "Fonts"]]:
		var lines: Array = credits.get(part[0], [])
		if lines.is_empty():
			continue
		text.append(String(part[1]).to_upper())
		for line in lines:
			text.append("  " + String(line))
		text.append("")
	text.append("MADE WITH THE GODOT ENGINE")
	text.append("")
	text.append(Engine.get_license_text())
	text.append("")
	text.append("THIRD-PARTY LIBRARIES IN THE GODOT ENGINE")
	text.append("")
	for item in Engine.get_copyright_info():
		text.append(String(item.get("name", "")))
		for part in item.get("parts", []):
			for holder in part.get("copyright", []):
				text.append("  Copyright " + String(holder))
			text.append("  Licence: " + String(part.get("license", "")))
		text.append("")
	text.append("LICENCE TEXTS")
	text.append("")
	var licences: Dictionary = Engine.get_license_info()
	for name in licences:
		text.append("----- " + String(name) + " -----")
		text.append(String(licences[name]))
		text.append("")
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("write_credits: cannot write " + out)
		quit(1)
		return
	# Windows Notepad and every other editor read CRLF line endings correctly.
	f.store_string("\r\n".join(text).replace("\n", "\r\n").replace("\r\r\n", "\r\n"))
	f.close()
	print("wrote ", out)
	quit()
