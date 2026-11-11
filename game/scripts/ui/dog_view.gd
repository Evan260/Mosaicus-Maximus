class_name DogView
extends TextureRect
## The workshop dog, drawn in the interface: it sleeps in its basket, gets up to be petted, wags, and lies down again.
## Breeds and coats are the ones from Farmus Maximus, each breed in several coats.

signal stood_up

const DIR := "res://assets/art/dogs/"
const BREEDS := {"hound": "Farm hound", "molossian": "Mastiff", "sighthound": "Sighthound", "lapdog": "Lapdog", "sheepdog": "Sheepdog"}
const COATS := {"golden": "Golden", "black": "Black", "chocolate": "Chocolate", "cream": "Cream", "grey": "Grey", "red": "Red"}
## Every breed's coats; the first is the look its pictures are drawn in, and "natural" keeps that id for old saves.
const BREED_COATS := {
	"hound": COATS,
	"molossian": {"natural": "Brown", "fawn": "Fawn", "grey": "Grey", "black": "Black"},
	"sighthound": {"natural": "Fawn", "black": "Black and white", "grey": "Grey and white"},
	"lapdog": {"natural": "White", "apricot": "Apricot", "grey": "Grey", "black": "Black"},
	"sheepdog": {"natural": "Grey and white", "black": "Black and white", "brown": "Brown and white"},
}
const NAMES := ["Rufus", "Fido", "Lupa", "Ferox", "Celer", "Nox", "Bella", "Argos"]
const WAG_TIME := 2.6
## Each animation: the folder, its frames in order, frames a second, and whether it loops.
const ANIMS := {
	"sleep": ["sleep", [4, 5, 6, 7, 8], 3.0, true],
	"get_up": ["sleep", [3, 2, 1, 0], 9.0, false],
	"lie_down": ["sleep", [0, 1, 2, 3], 6.0, false],
	"happy": ["happy", [1, 2, 3, 4, 5, 6, 7, 8], 12.0, true],
	"sit": ["sit", [3, 4, 5, 6, 7, 8], 4.0, true],
}

var breed := "hound"
var coat := "golden"
## Each picture pixel drawn this many interface pixels wide; the workshop uses 2 to match the room's painting.
var zoom := 1
var anim := ""
var _frame := 0
var _clock := 0.0
var _wag_left := 0.0
var _frames := {}


static func make(dog: Dictionary, zoom_by: int = 1) -> DogView:
	var d := DogView.new()
	d.breed = str(dog.get("breed", "hound"))
	d.coat = str(dog.get("coat", "golden"))
	d.zoom = zoom_by
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.stretch_mode = TextureRect.STRETCH_KEEP
	d._load()
	return d


static func coats_for(breed_id: String) -> Dictionary:
	return BREED_COATS.get(breed_id, COATS)


func set_look(breed_id: String, coat_id: String) -> void:
	breed = breed_id
	coat = coat_id
	_load()
	play(anim if anim != "" else "sleep")


func play(name: String) -> void:
	anim = name
	_frame = 0
	_clock = 0.0
	_show()


## A sleeping dog gets up first; a dog already up just keeps wagging a little longer.
func pet() -> void:
	_wag_left = WAG_TIME
	if anim in ["sleep", "lie_down"]:
		play("get_up")
	elif anim != "get_up":
		play("happy")


## Where the sleeping dog's body sits in its picture, so every breed can be laid in the middle of the basket.
func sleeping_centre() -> Vector2:
	return Rect2(_frames["sleep"][4].get_image().get_used_rect()).get_center()


func is_up() -> bool:
	return anim in ["get_up", "happy"]


func _process(delta: float) -> void:
	if anim == "":
		return
	var a: Array = ANIMS[anim]
	_clock += delta
	var step := 1.0 / float(a[2])
	while _clock >= step:
		_clock -= step
		_frame += 1
		if _frame >= (a[1] as Array).size():
			if a[3]:
				_frame = 0
			else:
				_frame -= 1
				_finished()
				return
		_show()
	if anim == "happy" and _wag_left > 0.0:
		_wag_left -= delta
		if _wag_left <= 0.0:
			play("lie_down")


func _finished() -> void:
	match anim:
		"get_up":
			stood_up.emit()
			play("happy")
		"lie_down":
			play("sleep")


func _show() -> void:
	var a: Array = ANIMS[anim]
	texture = _frames[a[0]][(a[1] as Array)[_frame]]


func _load() -> void:
	_frames.clear()
	for folder in ["sleep", "happy", "sit"]:
		var list := []
		for i in 9:
			list.append(_prepare(load("%s%s/%s/frame_%02d.png" % [DIR, breed, folder, i])))
		_frames[folder] = list


## The picture in the chosen coat and size. Only the breed's own fur colours change, so the collar, eyes and markings stay.
func _prepare(tex: Texture2D) -> Texture2D:
	var coats := coats_for(breed)
	var recolour: bool = breed in BREED_COATS and coats.has(coat) and coat != coats.keys()[0]
	if not recolour and zoom == 1:
		return tex
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	if recolour:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, pixel(breed, coat, c))
	if zoom > 1:
		img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## One pixel of a breed in one of its coats.
static func pixel(breed_id: String, coat_id: String, c: Color) -> Color:
	match breed_id:
		"hound":
			if c.h >= 0.02 and c.h <= 0.16 and c.s >= 0.3:
				return _shift(c, coat_id)
		"molossian":
			if c.h < 0.04 or c.h > 0.12:
				return c
			# The low, dark pixels are the black mask and outline, which stay dark in every coat.
			var body := c.s >= 0.27 and c.v >= 0.32
			match coat_id:
				"fawn":
					if body: return Color.from_hsv(0.095, c.s * 0.95, minf(1.0, c.v * 1.4), c.a)
				"grey":
					return Color.from_hsv(0.6, 0.07 if body else 0.06, c.v * (0.92 if body else 1.0), c.a)
				"black":
					if body: return Color.from_hsv(0.07, 0.2, c.v * 0.42 + 0.05, c.a)
		"sighthound":
			# The olive tinge on its tail is part of the coat too.
			if coat_id == "natural" or c.h < 0.02 or c.h > 0.2:
				return c
			if c.s >= 0.4 or (c.s >= 0.3 and c.v < 0.45):
				return _shift(c, coat_id)
			if c.v >= 0.6:
				# Its pale muzzle, chest and feet turn white beside a dark coat.
				return Color.from_hsv(0.1, c.s * 0.4, minf(1.0, c.v * 1.03), c.a)
		"lapdog":
			var fur := (c.h >= 0.05 and c.h <= 0.13 and c.s < 0.4) or (c.s < 0.05 and c.v > 0.95)
			if not fur:
				return c
			match coat_id:
				"apricot": return Color.from_hsv(0.075, minf(1.0, c.s * 1.6 + 0.2), c.v * 0.96, c.a)
				"grey": return Color.from_hsv(0.6, 0.05, c.v * 0.75, c.a)
				"black": return Color.from_hsv(0.62, 0.1, 0.07 + c.v * 0.3, c.a)
		"sheepdog":
			# Only the grey fur changes; its white coat stays white.
			if c.h < 0.04 or c.h > 0.13 or c.s >= 0.2 or c.v > 0.66:
				return c
			match coat_id:
				"black": return Color.from_hsv(0.62, 0.1, 0.06 + c.v * 0.38, c.a)
				"brown": return Color.from_hsv(0.06, 0.5, c.v * 0.78, c.a)
	return c


static func _shift(c: Color, coat_id: String) -> Color:
	match coat_id:
		"black":
			return Color.from_hsv(c.h, c.s * 0.25, c.v * 0.32 + 0.05, c.a)
		"chocolate":
			return Color.from_hsv(0.055, c.s * 0.8, c.v * 0.62, c.a)
		"cream":
			return Color.from_hsv(0.1, c.s * 0.22, 0.74 + c.v * 0.24, c.a)
		"grey":
			return Color.from_hsv(0.6, c.s * 0.08, c.v * 0.82, c.a)
		"red":
			return Color.from_hsv(0.032, c.s * 0.92, c.v * 0.7, c.a)
	return c
