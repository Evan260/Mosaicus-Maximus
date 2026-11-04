extends Node
## Three save slots. Each save first moves the previous file aside as a backup, so a bad write never loses a workshop.

const SLOTS := 3

var dir := "user://"
var slot := 0
## Off for scripted runs, so recordings and screenshots never overwrite a real workshop.
var enabled := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo" in str(args) or "--no-save" in args:
		enabled = false
		Library.enabled = false
	if Dev.has("library-dir"):
		Library.dir = Dev.get_arg("library-dir")
		Library.enabled = true


func path_for(n: int) -> String:
	return dir.path_join("workshop_%d.json" % n)


func save(n: int = -1) -> bool:
	if n < 0:
		n = slot
	if n < 1 or n > SLOTS or not enabled:
		return false
	var path := path_for(n)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(Game.to_dict(), "\t"))
	f.close()
	slot = n
	return true


## Loads a slot, falling back to its backup when the main file is missing or unreadable. False if neither works.
func load_slot(n: int) -> bool:
	for path in [path_for(n), path_for(n) + ".bak"]:
		var d := _read(path)
		if not d.is_empty():
			Game.from_dict(d)
			slot = n
			return true
	return false


## The first slot with no workshop in it, or 0 when all three are taken.
func free_slot() -> int:
	var info := slots()
	for n in range(1, SLOTS + 1):
		if (info[n - 1] as Dictionary).is_empty():
			return n
	return 0


func delete(n: int) -> void:
	for path in [path_for(n), path_for(n) + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## What the title screen shows for each slot: an empty dictionary for a free slot.
func slots() -> Array:
	var out := []
	for n in range(1, SLOTS + 1):
		var d := _read(path_for(n))
		if d.is_empty():
			d = _read(path_for(n) + ".bak")
		out.append({} if d.is_empty() else {"name": d.get("name", ""), "day": d.get("day", 1), "chapter": d.get("chapter", 1), "floors": (d.get("floors", []) as Array).size(), "dog": d.get("dog", {})})
	return out


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and parsed.has("version") else {}
