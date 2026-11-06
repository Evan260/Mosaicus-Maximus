extends Node
## The edits of the trailer and the short: each plays its recorded shots in order with their own sound under the music,
## with black caption cards, captions over shots and the end card. tools/trailer/make_trailer.py renders one at a time.

const FPS := 30.0
## One beat of the music, in seconds; every cut lands on a beat.
const BEAT := 0.857
const MUSIC := "res://assets/audio/music/solitary_expedition.ogg"
const MUSIC_DB := -1.0
## The game's tile clicks and harp notes are recorded beside the music, so they are raised to be heard under it.
const SOUND_DB := 8.5
const INK := Color(0.29, 0.18, 0.14)
const CREAM := Color(0.99, 0.95, 0.86)
## Where the scroll's line of text sits, from the top of its picture, so it is centred on the sheet between the rolls.
const SCROLL_TEXT_TOP := -1
const SCROLL_TEXT_HEIGHT := 54
## The story, told in order: the inheritance, the first floor for a bride-to-be who wants two doves, the floors that follow,
## the old floors under the town, and the promise that a floor can outlast Rome. A shot plays from `from` seconds into
## its recording; a card is black with one line of text.
const TRAILER := [
	{"card": "The Bay of Naples, AD 72.", "beats": 4},
	{"shot": "dawn", "from": 1.0, "beats": 5, "fade_in": 1.0},
	{"card": "Your uncle has left you\nhis mosaic workshop.", "beats": 4},
	{"shot": "client", "from": 1.0, "beats": 4},
	{"shot": "client", "from": 4.8, "beats": 5},
	{"shot": "design", "from": 1.6, "beats": 10},
	{"shot": "floor", "from": 0.9, "beats": 8},
	{"shot": "floor", "from": 11.5, "beats": 5},
	{"shot": "floor", "from": 19.2, "beats": 6},
	{"card": "Word gets around.", "beats": 3},
	{"shot": "sea", "from": 1.6, "beats": 3},
	{"shot": "villa", "from": 2.4, "beats": 3},
	{"shot": "apse", "from": 2.2, "beats": 3},
	{"card": "Under the old houses,\nfloors lie forgotten.", "beats": 3},
	{"shot": "dig", "from": 0.8, "beats": 6},
	{"shot": "dog", "from": 1.4, "beats": 3},
	{"shot": "night", "from": 1.0, "beats": 4},
	{"card": "Lay a floor that lasts\ntwo thousand years.", "beats": 4},
	{"end": "endcard", "from": 1.0, "beats": 7, "dim": 0.55},
]
## The short for phones: one floor laid close up, a stone at a time, then an old one dug up, with a caption on every shot.
const SHORT := [
	{"shot": "floor", "from": 0.9, "beats": 4, "caption": "POV: you lay Roman
mosaics for a living", "caption_at": 0.0},
	{"shot": "floor", "from": 4.5, "beats": 4, "caption": "one stone
at a time", "caption_at": 0.0},
	{"shot": "floor", "from": 8.2, "beats": 3, "caption": "until the whole
floor is down", "caption_at": 0.0},
	{"shot": "floor", "from": 11.5, "beats": 5, "caption": "then grout
and polish", "caption_at": 0.0},
	{"shot": "dig", "from": 0.8, "beats": 5, "caption": "and dig up floors
lost for centuries", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 6, "dim": 0.55},
]
## Yes, you can pet the dog, and every other breed too.
const PETS := [
	{"shot": "pet_hound", "from": 1.4, "beats": 4, "caption": "yes, you can
pet the dog", "caption_at": 0.0},
	{"shot": "pet_molossian", "from": 1.6, "beats": 3, "caption": "and the mastiff", "caption_at": 0.0},
	{"shot": "pet_sighthound", "from": 1.6, "beats": 3, "caption": "and the sighthound", "caption_at": 0.0},
	{"shot": "pet_lapdog", "from": 1.6, "beats": 3, "caption": "and the little one", "caption_at": 0.0},
	{"shot": "pet_sheepdog", "from": 1.6, "beats": 4, "caption": "and the fluffy one", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## An old floor dug up slowly, the picture under the dirt kept a secret until the end.
const GUESS := [
	{"shot": "guess_dig", "from": 0.6, "beats": 4, "caption": "we found an old
floor under a house", "caption_at": 0.0},
	{"shot": "guess_dig", "from": 4.0, "beats": 4, "caption": "guess what's
under the dirt", "caption_at": 0.0},
	{"shot": "guess_dig", "from": 7.4, "beats": 4, "caption": "any guesses?", "caption_at": 0.0},
	{"shot": "guess_dig", "from": 10.8, "beats": 3, "caption": "a guard dog.
of course.", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## No music: the stones, the sponge, the cloth, the trowel and the dog.
const ASMR := [
	{"shot": "floor", "from": 0.9, "beats": 8, "caption": "turn your
sound on", "caption_at": 0.0},
	{"shot": "floor", "from": 11.5, "beats": 5},
	{"shot": "guess_dig", "from": 1.3, "beats": 13},
	{"shot": "pet_hound", "from": 1.4, "beats": 4},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## The first floor a workshop lays, and one from its last chapter.
const FIRST_LAST := [
	{"shot": "first_pour", "from": 0.2, "beats": 6, "caption": "my first floor", "caption_at": 0.0},
	{"shot": "last_pour", "from": 1.2, "beats": 8, "caption": "my 50th floor", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## What four clients said once their floors were down, each shown in their own room.
const REVIEWS := [
	{"shot": "react_cornelia", "from": 1.5, "beats": 6, "caption": "Cornelia:
\"Not one thief since!
Mind you, there wasn't
one before either.\"", "caption_at": 0.0},
	{"shot": "react_gaius", "from": 1.5, "beats": 5, "caption": "Gaius of the baths:
\"Children try to pick
it up off the floor.\"", "caption_at": 0.0},
	{"shot": "react_trimalchio", "from": 1.5, "beats": 5, "caption": "Trimalchio:
\"A senator laughed so
hard he fell off
his couch. Perfect.\"", "caption_at": 0.0},
	{"shot": "react_livia", "from": 1.5, "beats": 5, "caption": "Livia, a bride-to-be:
\"Mother cried. Then she
asked who made it.\"", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## The town's forum floor, poured from one corner as the view pulls back to show how big it is.
const BIGGEST := [
	{"shot": "forum_pour", "from": 2.4, "beats": 3, "caption": "the town wanted
a bigger floor", "caption_at": 0.0},
	{"shot": "forum_pour", "from": 5.0, "beats": 3, "caption": "bigger", "caption_at": 0.0},
	{"shot": "forum_pour", "from": 7.6, "beats": 5, "caption": "the forum:
17,847 stones", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.55},
]
## How each cut is laid out: its frame, how many screen pixels make one overlay pixel, its caption size and where its
## text and logo sit in overlay pixels, and where in the music it starts.
const CUTS := {
	"trailer": {"edit": TRAILER, "size": Vector2i(1920, 1080), "pixel": 4, "caption_size": 20, "caption_y": 20, "logo_y": 44, "scroll_y": 158, "music_from": 0.0},
	"one_stone": {"edit": SHORT, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 41.1},
	"pet_the_dog": {"edit": PETS, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"guess_the_floor": {"edit": GUESS, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 20.0},
	"cozy_sounds": {"edit": ASMR, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0, "music": false, "sound_db": 10.0},
	"first_vs_last": {"edit": FIRST_LAST, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 41.1},
	"client_reviews": {"edit": REVIEWS, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 24, "caption_y": 50, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"biggest_floor": {"edit": BIGGEST, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 41.1},
}

var _shots_dir := ""
var _cut: Dictionary = CUTS["trailer"]
var _edit: Array = TRAILER
var _size := Vector2(1920, 1080)
var _frame := 0
var _starts: Array = []
var _total_frames := 0
var _picture: TextureRect
var _texture: ImageTexture
var _overlay: SubViewport
var _black: ColorRect
var _shade: ColorRect
var _card_text: Label
var _caption: Label
var _logo: TextureRect
var _scroll: TextureRect
var _wishlist: Label
var _music: AudioStreamPlayer
var _sound: AudioStreamPlayer
var _current := -1


func _ready() -> void:
	# The game's own systems start with this scene too: nothing may save, and only the trailer's own sound plays.
	Saves.enabled = false
	Audio.music_on = false
	RenderingServer.set_default_clear_color(Color.BLACK)
	for bus in ["Music", "Effects"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), true)
	var from := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--from="):
			from = float(arg.trim_prefix("--from="))
		elif arg.begins_with("--cut="):
			_cut = CUTS[arg.trim_prefix("--cut=")]
	_edit = _cut["edit"]
	_size = Vector2(_cut["size"])
	var t := 0
	for seg in _edit:
		_starts.append(t)
		t += int(round(float(seg["beats"]) * BEAT * FPS))
	_total_frames = t
	_build()
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC)
	add_child(_music)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	# A preview can start part way through, to look at one moment without rendering the whole trailer.
	_frame = int(from * FPS)
	if _cut.get("music", true):
		_music.play(float(_cut["music_from"]) + from)


func _build() -> void:
	_texture = ImageTexture.create_from_image(Image.create(int(_size.x), int(_size.y), false, Image.FORMAT_RGB8))
	_picture = TextureRect.new()
	_picture.texture = _texture
	_picture.size = _size
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_picture)
	# Cards and the end card are drawn in big pixels and scaled up, like the game.
	var area := _size / float(_cut["pixel"])
	_overlay = SubViewport.new()
	_overlay.size = Vector2i(area)
	_overlay.transparent_bg = true
	_overlay.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_overlay)
	var shown := TextureRect.new()
	shown.texture = _overlay.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.size = _size
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shown)
	_shade = ColorRect.new()
	_shade.color = Color(0.07, 0.05, 0.04, 0.0)
	_shade.size = area
	_overlay.add_child(_shade)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = area
	_overlay.add_child(_black)
	# The text is the interface's own pixel font at twice its size, still whole pixels, to read at a glance.
	_card_text = _label(Vector2(20, area.y / 2.0 - 40.0), area.x - 40.0, 80, 20)
	# Phones are read at arm's length, so the short's captions are drawn half as big again, outlined in ink.
	_caption = _label(Vector2(10, float(_cut["caption_y"])), area.x - 20.0, 120, int(_cut["caption_size"]))
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_caption.add_theme_color_override("font_outline_color", INK)
	_caption.add_theme_constant_override("outline_size", 4)
	_logo = TextureRect.new()
	_logo.texture = load("res://tools/trailer/logo.png")
	_logo.position = Vector2(roundf((area.x - _logo.texture.get_width()) / 2.0), float(_cut["logo_y"]))
	_overlay.add_child(_logo)
	_scroll = TextureRect.new()
	_scroll.texture = load("res://tools/trailer/scroll.png")
	_scroll.position = Vector2(roundf((area.x - _scroll.texture.get_width()) / 2.0), float(_cut["scroll_y"]))
	_overlay.add_child(_scroll)
	_wishlist = _label(_scroll.position + Vector2(0, SCROLL_TEXT_TOP), _scroll.texture.get_width(), SCROLL_TEXT_HEIGHT, 20)
	_wishlist.text = "Wishlist now on Steam"
	_wishlist.add_theme_color_override("font_color", INK)


func _label(at: Vector2, width: float, height: float, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiTheme.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = at
	l.size = Vector2(width, height)
	_overlay.add_child(l)
	return l


func _process(_delta: float) -> void:
	if _frame >= _total_frames:
		get_tree().quit()
		return
	var k := _starts.size() - 1
	while _starts[k] > _frame:
		k -= 1
	var seg: Dictionary = _edit[k]
	var local := float(_frame - _starts[k]) / FPS
	var length := float(seg["beats"]) * BEAT
	if k != _current:
		_current = k
		_start_segment(seg)
	_draw_segment(seg, local, length)
	# The music fades away over the end card's last seconds.
	var left := float(_total_frames - _frame) / FPS
	_music.volume_db = MUSIC_DB + linear_to_db(clampf(left / 3.0, 0.0001, 1.0))
	_frame += 1


func _start_segment(seg: Dictionary) -> void:
	_sound.stop()
	var name := String(seg.get("shot", seg.get("end", "")))
	if name == "":
		return
	var wav := _shots_dir.path_join(name).path_join("f.wav")
	if FileAccess.file_exists(wav):
		_sound.stream = AudioStreamWAV.load_from_file(wav)
		_sound.play(float(seg["from"]))


func _draw_segment(seg: Dictionary, local: float, length: float) -> void:
	var is_card := seg.has("card")
	var is_end := seg.has("end")
	_black.visible = is_card
	_card_text.visible = is_card
	_logo.visible = is_end
	_scroll.visible = is_end
	_wishlist.visible = is_end
	_shade.visible = is_end
	_caption.visible = seg.has("caption")
	if is_card:
		_card_text.text = String(seg["card"])
		# The line fades in and out on the black, so cards never jump.
		_card_text.modulate.a = clampf(minf(local / 0.35, (length - local) / 0.35), 0.0, 1.0)
		return
	var name := String(seg.get("shot", seg.get("end", "")))
	var index := int(round((float(seg["from"]) + local) * FPS))
	var path := _shots_dir.path_join(name).path_join("f%08d.png" % index)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGB8)
		_texture.update(img)
	var fade_in := float(seg.get("fade_in", 0.0))
	_picture.modulate = Color.WHITE * (clampf(local / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0)
	_picture.modulate.a = 1.0
	if seg.has("caption"):
		_caption.text = String(seg["caption"])
		# A caption opening a shot is there from its first frame; it fades out as the shot ends.
		var shown_at := float(seg.get("caption_at", 0.6))
		var appear := clampf((local - shown_at) / 0.4, 0.0, 1.0) if shown_at > 0.0 else 1.0
		_caption.modulate.a = minf(appear, clampf((length - local) / 0.3, 0.0, 1.0))
	if is_end:
		# The floor darkens a little behind the logo, which settles in first, then the scroll unrolls beneath it.
		_shade.color.a = clampf(local / 0.8, 0.0, 1.0) * float(seg.get("dim", 0.0))
		_logo.modulate.a = clampf((local - 0.4) / 0.8, 0.0, 1.0)
		_logo.position.y = float(_cut["logo_y"]) + roundf(4.0 * (1.0 - _logo.modulate.a))
		var s := clampf((local - 1.6) / 0.6, 0.0, 1.0)
		_scroll.modulate.a = s
		_wishlist.modulate.a = s
	# Sound from each shot fades in and out quickly at its cuts, so cuts never click.
	_sound.volume_db = float(_cut.get("sound_db", SOUND_DB)) + linear_to_db(clampf(minf(local / 0.08, (length - local) / 0.08), 0.0001, 1.0))
