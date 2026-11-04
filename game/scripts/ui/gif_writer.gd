class_name GifWriter
extends RefCounted
## Writes a looping animated GIF from frames of palette indices, with the standard LZW compression.

var width := 0
var height := 0
var palette := PackedColorArray()
var _out := PackedByteArray()
var _min_code := 6


func begin(w: int, h: int, colours: PackedColorArray) -> void:
	width = w
	height = h
	palette = colours
	_out.clear()
	_out.append_array("GIF89a".to_ascii_buffer())
	_le16(w)
	_le16(h)
	_out.append(0xF0 | 5)
	_out.append(0)
	_out.append(0)
	for i in 64:
		var c: Color = palette[i] if i < palette.size() else Color.BLACK
		_out.append(c.r8)
		_out.append(c.g8)
		_out.append(c.b8)
	_out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	_out.append_array("NETSCAPE2.0".to_ascii_buffer())
	_out.append_array(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))


## Adds one frame of width by height palette indices, shown for the given hundredths of a second.
func add_frame(indices: PackedByteArray, delay_cs: int) -> void:
	_out.append_array(PackedByteArray([0x21, 0xF9, 0x04, 0x04]))
	_le16(delay_cs)
	_out.append_array(PackedByteArray([0x00, 0x00]))
	_out.append(0x2C)
	_le16(0)
	_le16(0)
	_le16(width)
	_le16(height)
	_out.append(0)
	_out.append(_min_code)
	var data := _lzw(indices)
	var i := 0
	while i < data.size():
		var n := mini(255, data.size() - i)
		_out.append(n)
		_out.append_array(data.slice(i, i + n))
		i += n
	_out.append(0)


func finish() -> PackedByteArray:
	_out.append(0x3B)
	return _out


func _le16(v: int) -> void:
	_out.append(v & 0xFF)
	_out.append((v >> 8) & 0xFF)


## LZW as GIF uses it: codes start one bit wider than the palette and grow to 12 bits, with a clear code to restart.
func _lzw(indices: PackedByteArray) -> PackedByteArray:
	var bytes := PackedByteArray()
	var clear := 1 << _min_code
	var eoi := clear + 1
	var init_bits := _min_code + 1
	var n_bits := init_bits
	var maxcode := (1 << n_bits) - 1
	var free_ent := eoi + 1
	var table := {}
	# Lambdas can't reassign captured locals, so the bit writer's state (bits, count, width, top code, clear) is an array.
	var state := [0, 0, n_bits, maxcode, false]
	var write := func(code: int) -> void:
		state[0] = state[0] | (code << state[1])
		state[1] += state[2]
		while state[1] >= 8:
			bytes.append(state[0] & 0xFF)
			state[0] = state[0] >> 8
			state[1] -= 8
	var output := func(code: int, free: int) -> void:
		write.call(code)
		if state[4]:
			state[2] = init_bits
			state[3] = (1 << state[2]) - 1
			state[4] = false
		elif free > state[3]:
			state[2] += 1
			state[3] = 4096 if state[2] == 12 else (1 << state[2]) - 1
	output.call(clear, free_ent)
	var ent := int(indices[0])
	for i in range(1, indices.size()):
		var c := int(indices[i])
		var key := (ent << 8) | c
		if table.has(key):
			ent = table[key]
			continue
		output.call(ent, free_ent)
		ent = c
		if free_ent < 4096:
			table[key] = free_ent
			free_ent += 1
		else:
			table.clear()
			free_ent = eoi + 1
			state[4] = true
			output.call(clear, free_ent)
	output.call(ent, free_ent)
	output.call(eoi, free_ent)
	if state[1] > 0:
		bytes.append(state[0] & 0xFF)
	return bytes
