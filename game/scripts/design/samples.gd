class_name Samples
## Finished designs used behind the title screen and for checking the composer by eye.


static func make(sample: String) -> FloorDesign:
	match sample:
		"sea":
			var d := FloorDesign.for_room("changing_room")
			d.ground = "white_marble"
			d.set_border("wave")
			d.add("octopus", d.w * 0.5, d.h * 0.5, 15)
			d.add("dolphin", d.w * 0.22, d.h * 0.32, 12)
			d.add("dolphin", d.w * 0.78, d.h * 0.32, 12, 0, true)
			d.add("fish", d.w * 0.25, d.h * 0.72, 9)
			d.add("fish", d.w * 0.75, d.h * 0.72, 9, 0, true)
			_colour_all(d, {"dolphin": {"1": "blue_glass", "2": "grey_stone", "3": "white_marble", "4": "black_stone"}})
			return d
		"villa":
			var d := FloorDesign.for_room("villa_dining")
			d.ground = "white_marble"
			d.set_border("braid")
			d.add("roundel", d.w * 0.5, d.h * 0.5, 30)
			d.add("medusa", d.w * 0.5, d.h * 0.5, 20)
			d.add("peacock", d.w * 0.2, d.h * 0.5, 18)
			d.add("peacock", d.w * 0.8, d.h * 0.5, 18, 0, true)
			for c in [[0.13, 0.2], [0.87, 0.2], [0.13, 0.8], [0.87, 0.8]]:
				d.add("grapes", d.w * c[0], d.h * c[1], 9)
			for p in d.placements:
				p["fine"] = Data.motif(p["motif"]).get("kind", "") == "picture"
			return d
		"apse":
			var d := FloorDesign.for_room("nymphaeum")
			d.ground = "white_marble"
			d.set_border("ivy")
			d.add("sun", d.w * 0.5, d.h * 0.45, 22)
			d.add("shell", d.w * 0.25, d.h * 0.75, 12)
			d.add("shell", d.w * 0.75, d.h * 0.75, 12)
			return d
	var d := FloorDesign.for_room("vestibule")
	d.set_border("double")
	d.add("dog", d.w * 0.5, d.h * 0.36, 17)
	d.add("cave_canem", d.w * 0.5, d.h * 0.7, 29)
	return d


static func _colour_all(d: FloorDesign, by_motif: Dictionary) -> void:
	for p in d.placements:
		if by_motif.has(p["motif"]):
			p["stones"] = (by_motif[p["motif"]] as Dictionary).duplicate()
