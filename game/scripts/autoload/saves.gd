extends Node
## Three save slots. The workshop being played is saved every minute and when the window closes. Each save is written
## to a temporary file, read back, and only then moved over the last one, which goes to the backups first.

const SLOTS := 3
const BACKUPS := 3
## Seconds the newest backup must have aged before the backups move along, so each really is an older copy.
const BACKUP_EVERY := 300.0
const AUTOSAVE_EVERY := 60.0

var dir := "user://"
var slot := 0
## Off for scripted runs, so recordings and screenshots never overwrite a real workshop.
var enabled := true
var _timer := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--auto-lay" in str(args) or "--no-save" in args or Dev.made_up():
		enabled = false
		Library.enabled = false
	if Dev.has("library-dir"):
		Library.dir = Dev.get_arg("library-dir")
		Library.enabled = true


func path_for(n: int) -> String:
	return dir.path_join("workshop_%d.json" % n)


## Whether a workshop is open to be saved by itself: one is being played, and the title screen is not showing.
func playing() -> bool:
	return enabled and slot >= 1 and str(Game.state.get("name", "")) != "" and not Nav.current_name in ["", "title"]


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_EVERY:
		_timer = 0.0
		if playing():
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and playing():
		save()


func save(n: int = -1) -> bool:
	if n < 0:
		n = slot
	if n < 1 or n > SLOTS or not enabled:
		return false
	if Nav.current and Nav.current.has_method("before_save"):
		Nav.current.before_save()
	var path := path_for(n)
	var tmp := path + ".tmp"
	if not _write(tmp, JSON.stringify(Game.to_dict(), "\t")):
		return false
	_rotate_backups(path)
	if not _move(tmp, path):
		return false
	slot = n
	_timer = 0.0
	return true


## Writes a file and reads it back, so a full disk or a failed write is caught before it can replace anything.
func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var stored := f.store_string(text)
	f.close()
	if not stored or FileAccess.get_file_as_string(path) != text:
		push_error("Could not write %s" % path)
		return false
	return true


func _move(from: String, to: String) -> bool:
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err != OK:
		push_error("Could not move %s to %s: %s" % [from, to, error_string(err)])
	return err == OK


## Moves each backup one along, the save itself becoming the newest, once the newest backup has aged.
func _rotate_backups(path: String) -> void:
	var newest := path + ".bak1"
	if FileAccess.file_exists(newest) and Time.get_unix_time_from_system() - FileAccess.get_modified_time(newest) < BACKUP_EVERY:
		return
	if _read(path).is_empty():
		return
	# Renaming rather than copying leaves each older copy's contents untouched on the disk.
	for i in range(BACKUPS - 1, 0, -1):
		var older := "%s.bak%d" % [path, i]
		if FileAccess.file_exists(older) and not _move(older, "%s.bak%d" % [path, i + 1]):
			return
	_move(path, newest)


## The files a slot is read from, best first: the save, a whole .tmp left newer by a close mid-move, then the backups.
func _candidates(n: int) -> Array:
	var list := [path_for(n)]
	var tmp := path_for(n) + ".tmp"
	if FileAccess.file_exists(tmp) and not _read(tmp).is_empty() and FileAccess.get_modified_time(tmp) >= FileAccess.get_modified_time(path_for(n)):
		list.push_front(tmp)
	for i in range(1, BACKUPS + 1):
		list.append("%s.bak%d" % [path_for(n), i])
	# The single backup kept before there were three.
	list.append(path_for(n) + ".bak")
	return list


## Loads a slot, falling back to its backups when the main file is missing or unreadable. False if none works.
func load_slot(n: int) -> bool:
	for path in _candidates(n):
		var d := _read(path)
		if not d.is_empty():
			Game.from_dict(d)
			slot = n
			_timer = 0.0
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
	for path in _candidates(n) + [path_for(n) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if n == slot:
		slot = 0


## What the title screen shows for each slot: an empty dictionary for a free slot.
func slots() -> Array:
	var out := []
	for n in range(1, SLOTS + 1):
		var d := {}
		for path in _candidates(n):
			d = _read(path)
			if not d.is_empty():
				break
		out.append({} if d.is_empty() else {"name": d.get("name", ""), "day": d.get("day", 1), "chapter": d.get("chapter", 1), "floors": (d.get("floors", []) as Array).size(), "dog": d.get("dog", {})})
	return out


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and parsed.has("version") else {}
