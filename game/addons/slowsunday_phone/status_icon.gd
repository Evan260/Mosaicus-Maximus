@tool
extends RefCounted
## Turns a picture into a status-bar icon: white where the picture is and clear elsewhere, with its darkest parts,
## such as windows and doors, cut out so the shape still reads at 24 pixels.

## Status-bar icons are 24 dp; these are its sizes in pixels at each screen density.
const DENSITIES := {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
const DARK := 0.4
const WORK_SIZE := 256


## The white shape, square with a margin, or null for an empty picture.
static func shape(source: Image) -> Image:
	var img := source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x == 0 or used.size.y == 0:
		return null
	img = img.get_region(used)
	var side := maxi(img.get_width(), img.get_height())
	if side > WORK_SIZE:
		var f := float(WORK_SIZE) / side
		img.resize(maxi(1, roundi(img.get_width() * f)), maxi(1, roundi(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
		side = maxi(img.get_width(), img.get_height())
	var w := img.get_width()
	var h := img.get_height()
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	var dark := PackedByteArray()
	dark.resize(w * h)
	var solid := 0
	var dark_count := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var i := y * w + x
			alpha[i] = c.a
			if c.a > 0.5:
				solid += 1
				if c.get_luminance() < DARK:
					dark[i] = 1
					dark_count += 1
	if dark_count * 2 > solid:
		# A picture that is mostly dark is a silhouette already and keeps its whole shape.
		dark.fill(0)
	else:
		# Opening the dark areas drops thin outlines and keeps only windows and doors wide enough to show.
		var r := maxi(1, roundi(side / 100.0))
		dark = _morph(_morph(dark, w, h, r, false), w, h, r, true)
	alpha = _drop_specks(alpha, dark, w, h)
	var pad := roundi(side / 12.0)
	var size := side + pad * 2
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1, 0))
	var ox := (size - w) / 2
	var oy := (size - h) / 2
	for y in h:
		for x in w:
			var i := y * w + x
			out.set_pixel(ox + x, oy + y, Color(1, 1, 1, 0.0 if dark[i] else alpha[i]))
	return out


## The shape at one size in pixels.
static func at_size(white_shape: Image, pixels: int) -> Image:
	var img := white_shape.duplicate() as Image
	img.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
	for y in pixels:
		for x in pixels:
			var a := img.get_pixel(x, y).a
			# Lanczos leaves a faint ring around the shape that the status bar would draw as a halo.
			img.set_pixel(x, y, Color(1, 1, 1, 0.0 if a < 0.08 else a))
	return img


## Whether the picture fills its own outline, as an app icon tile does, so the shape is only a rounded square.
static func is_tile(source: Image) -> bool:
	var img := source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x == 0 or used.size.y == 0:
		return false
	var solid := 0
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.5:
				solid += 1
	return solid > used.size.x * used.size.y * 0.85


## Clears the scraps that cutting out the dark parts leaves, such as the rim of a dark pot, which show as stray dots.
static func _drop_specks(alpha: PackedFloat32Array, dark: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	var out := alpha.duplicate()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var total := 0
	for i in w * h:
		if alpha[i] > 0.5 and dark[i] == 0:
			total += 1
	var smallest := maxi(4, total / 250)
	for start in w * h:
		if seen[start] == 1 or alpha[start] <= 0.5 or dark[start] == 1:
			continue
		var part := PackedInt32Array([start])
		seen[start] = 1
		var k := 0
		while k < part.size():
			var i := part[k]
			k += 1
			var x := i % w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if n >= 0 and n < w * h and seen[n] == 0 and alpha[n] > 0.5 and dark[n] == 0:
					seen[n] = 1
					part.append(n)
		if part.size() < smallest:
			for i in part:
				out[i] = 0.0
	return out


## Shrinks or grows the marked pixels by r in every direction, one axis at a time.
static func _morph(src: PackedByteArray, w: int, h: int, r: int, grow: bool) -> PackedByteArray:
	return _pass(_pass(src, w, h, r, grow, Vector2i(1, 0)), w, h, r, grow, Vector2i(0, 1))


static func _pass(src: PackedByteArray, w: int, h: int, r: int, grow: bool, step: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v := 0 if grow else 1
			for d in range(-r, r + 1):
				var px := x + step.x * d
				var py := y + step.y * d
				var s := src[py * w + px] if px >= 0 and px < w and py >= 0 and py < h else 0
				if grow and s == 1:
					v = 1
					break
				if not grow and s == 0:
					v = 0
					break
			out[y * w + x] = v
	return out
