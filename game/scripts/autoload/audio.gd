extends Node
## Every sound in the game: tile clicks, harp notes, tool strokes, interface sounds and the harp music.
## Each named sound can have several recorded cuts, and one is picked at random each time.

const TILES_DIR := "res://assets/audio/tiles/"
const HARP_DIR := "res://assets/audio/harp/"
const TOOLS_DIR := "res://assets/audio/tools/"
const UI_DIR := "res://assets/audio/ui/"
const MUSIC_DIR := "res://assets/audio/music/"
## The player's own music, beside the saves, played between the game's tracks; Settings opens it.
const PLAYER_MUSIC_DIR := "user://music/"
const MUSIC_TYPES := ["ogg", "mp3", "wav"]
const MUSIC_GAP := Vector2(40.0, 110.0)  # quiet between tracks, so the harp never wears thin
const SWIPE_GAP := 0.2
const VOICES := 32
const CLICK_GAP := 0.014
const CLICKS_PER_FRAME := 3
const SCALE := [0, 2, 4, 7, 9]  # a major pentatonic scale, so any run of notes sounds pleasant
const TOP_STEP := 14

# Which set of recorded clicks each kind of stone uses.
const CLICK_SET := {
	Stones.Kind.LIMESTONE: "soft",
	Stones.Kind.TERRACOTTA: "soft",
	Stones.Kind.BLACK_STONE: "stone",
	Stones.Kind.MARBLE: "stone",
	Stones.Kind.GLASS: "glass",
	Stones.Kind.GOLD: "gold",
}

var _clicks := {}
var _notes := {}
var _chord: AudioStream
var _gliss: AudioStream
var _players: Array[AudioStreamPlayer] = []
var _melody: Array[bool] = []  # which voices are playing a note of the run, so they can be cut short
var _last_land := -10.0
var _next := 0
var _clock := 0.0
var _last_click := -1.0
var _queue: Array = []
var _rng := RandomNumberGenerator.new()
var _ui := {}
var _music: AudioStreamPlayer
var _tracks: Array = []
var _last_track := ""
var _music_wait := 3.0
var music_on := true


func _ready() -> void:
	_rng.randomize()
	for set_name in ["stone", "soft", "glass", "gold"]:
		_clicks[set_name] = _load_numbered(TILES_DIR + set_name)
	for midi in range(48, 97):
		var s := _load(HARP_DIR + "note_m%d" % midi)
		if s:
			_notes[midi] = s
	for set_name in ["sponge", "cloth"]:
		_clicks[set_name] = _load_numbered(TOOLS_DIR + set_name)
	_chord = _load(HARP_DIR + "chord")
	_gliss = _load(HARP_DIR + "gliss")
	for n in ["click", "coins", "nope", "page_turn", "dog", "rustle", "tab"]:
		_ui[n] = _load_numbered(UI_DIR + n)
		var single := _load(UI_DIR + n)
		if single:
			_ui[n].append(single)
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.ends_with(".ogg") or f.ends_with(".ogg.import"):
			var path := MUSIC_DIR + f.trim_suffix(".import")
			if not path in _tracks:
				_tracks.append(path)
	var master := AudioServer.get_bus_index("Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.5
	AudioServer.add_bus_effect(master, limiter)
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var b := AudioServer.bus_count - 1
			AudioServer.set_bus_name(b, bus_name)
			AudioServer.set_bus_send(b, "Master")
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.finished.connect(func() -> void: _music_wait = _rng.randf_range(MUSIC_GAP.x, MUSIC_GAP.y))
	add_child(_music)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_players.append(p)
		_melody.append(false)


func _process(delta: float) -> void:
	_clock += delta
	if music_on and not _music.playing and not _tracks.is_empty():
		_music_wait -= delta
		if _music_wait <= 0.0:
			var track := _pick_track()
			if track:
				_music.stream = track
				_music.play()
			else:
				_music_wait = 30.0
	if _clock - _last_land > 0.25:
		for k in VOICES:
			if _melody[k] and _players[k].playing:
				_players[k].volume_db -= delta * 70.0
				if _players[k].volume_db < -45.0:
					_players[k].stop()
	var i := 0
	while i < _queue.size():
		var q: Array = _queue[i]
		if q[0] <= _clock:
			_play(q[1], q[2], q[3])
			_queue.remove_at(i)
		else:
			i += 1


## A track at random from the game's music and the player's own folder, which is looked at afresh each time, never the
## one just played while there is another.
func _pick_track() -> AudioStream:
	var choices: Array = _tracks + player_tracks()
	if choices.size() > 1:
		choices.erase(_last_track)
	var pick: String = choices[_rng.randi() % choices.size()]
	_last_track = pick
	return load(pick) if pick.begins_with("res://") else _load_external(pick)


## The music files in the player's own folder, as full paths.
static func player_tracks() -> Array:
	var out := []
	var folder := ProjectSettings.globalize_path(PLAYER_MUSIC_DIR)
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.get_extension().to_lower() in MUSIC_TYPES:
				out.append(folder.path_join(file))
	return out


## Reads a music file from outside the game's own files; an unreadable file gives nothing and is skipped.
static func _load_external(path: String) -> AudioStream:
	if not _sounds_like_music(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


## Whether a file starts as its kind of music file does, so a misnamed one is skipped before the engine complains.
static func _sounds_like_music(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head := f.get_buffer(4)
	if head.size() < 4:
		return false
	match path.get_extension().to_lower():
		"ogg":
			return head.get_string_from_ascii() == "OggS"
		"wav":
			return head.get_string_from_ascii() == "RIFF"
		"mp3":
			return head.slice(0, 3).get_string_from_ascii() == "ID3" or (head[0] == 0xFF and head[1] & 0xE0 == 0xE0)
	return false


## Opens the player's music folder in the file explorer, making it first if need be.
func open_music_folder() -> void:
	var folder := ProjectSettings.globalize_path(PLAYER_MUSIC_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


## Tiles touched down this frame: a few clicks across it, the rest dropped so the sound stops when the tiles do.
func on_landed(stones: PackedInt32Array) -> void:
	_last_land = _clock
	var n := stones.size()
	var horizon := _clock + 0.02
	for k in mini(n, CLICKS_PER_FRAME):
		var at := maxf(_clock + k * 0.006, _last_click + CLICK_GAP)
		if at > horizon:
			break
		var variants: Array = _clicks[CLICK_SET[Stones.LIST[stones[_rng.randi() % n]]["material"]]]
		if variants.is_empty():
			continue
		_last_click = at
		var vol := -4.0 - _rng.randf() * 3.0 - (2.0 if n > 6 else 0.0)
		_queue.append([at, variants[_rng.randi() % variants.size()], vol, 0.95 + _rng.randf() * 0.1])


var _last_swipe := -1.0


## The sponge or cloth moving across the floor: one stroke sound at a time, quieter where it passes over finished floor.
func swipe(set_name: String, fresh: bool) -> void:
	if _clock - _last_swipe < SWIPE_GAP or _clicks[set_name].is_empty():
		return
	_last_swipe = _clock
	var variants: Array = _clicks[set_name]
	_queue.append([_clock, variants[_rng.randi() % variants.size()], -6.0 if fresh else -14.0, 0.94 + _rng.randf() * 0.12])


## An interface sound by name: click, coins, nope, page_turn, dog, rustle or tab.
func ui(sound: String, db: float = -6.0) -> void:
	var variants: Array = _ui.get(sound, [])
	if variants.is_empty():
		return
	_queue.append([_clock, variants[_rng.randi() % variants.size()], db, 0.96 + _rng.randf() * 0.08])


func set_volumes(master_v: float, music_v: float, effects_v: float) -> void:
	for pair in [["Master", master_v], ["Music", music_v], ["Effects", effects_v]]:
		var b := AudioServer.get_bus_index(pair[0])
		if b >= 0:
			AudioServer.set_bus_volume_db(b, linear_to_db(maxf(float(pair[1]), 0.0001)))


func chord() -> void:
	if _chord:
		_queue.append([_clock, _chord, -11.0, 1.0])
		return
	for k in [5, 7, 8]:
		_queue.append([_clock + (k - 5) * 0.03, null, -8.0, k])


func glissando() -> void:
	if _gliss:
		_queue.append([_clock + 0.25, _gliss, -4.0, 1.0])
		return
	for k in TOP_STEP + 1:
		_queue.append([_clock + 0.25 + k * 0.05, null, -9.0, k])


## A note of the scale, from the recorded harp note nearest in pitch, retuned to it. Step 0 is middle C.
func _note_stream(step: int) -> Array:
	var target := 60 + _semitones(step)
	var best := -1
	for m in _notes:
		if best < 0 or absi(m - target) < absi(best - target):
			best = m
	if best < 0:
		return [null, 1.0]
	return [_notes[best], pow(2.0, (target - best) / 12.0)]


func _semitones(step: int) -> int:
	return SCALE[step % SCALE.size()] + 12 * (step / SCALE.size())


func _play(stream, db: float, pitch_or_step: float) -> void:
	var is_note: bool = stream == null
	var pitch := pitch_or_step
	if stream == null:
		var found := _note_stream(int(pitch_or_step))
		stream = found[0]
		pitch = found[1]
		if stream == null:
			return
	var p := _players[_next]
	_melody[_next] = is_note
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _load_numbered(prefix: String) -> Array:
	var out := []
	for k in range(1, 40):
		var s := _load("%s_%d" % [prefix, k])
		if s == null:
			break
		out.append(s)
	return out


func _load(base: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext)
	return null
