class_name RandomDesign
## Floors invented by the game: the old floors found under the town for restoration, and the title screen's backdrop.
## Built the way Roman floors usually were: a border, a centrepiece, and matching pairs either side.


static func make(room_id: String, tier: int, rng: RandomNumberGenerator) -> FloorDesign:
	var d := FloorDesign.for_room(room_id)
	d.ground = "white_marble" if rng.randf() < 0.5 else "limestone"
	var borders := Data.border_order.filter(func(id) -> bool: return int(Data.borders[id].get("tier", 1)) <= tier)
	d.set_border(borders[rng.randi() % borders.size()])
	var patterns := []
	var pictures := []
	for id in Data.motif_order:
		var m := Data.motif(id)
		if int(m.get("tier", 1)) > tier or m.get("kind", "") == "letters":
			continue
		if m.get("kind", "") == "picture":
			pictures.append(id)
		elif not "frame" in m.get("tags", []):
			patterns.append(id)
	var short := minf(d.w, d.h)
	var inner := short - 2.0 * (int(d.border.get("width", 0)) + 2)
	var centre: String = pictures[rng.randi() % pictures.size()] if (not pictures.is_empty() and rng.randf() < 0.6) else patterns[rng.randi() % patterns.size()]
	if Data.motif(centre).get("kind", "") == "picture" and rng.randf() < 0.6:
		d.add("roundel", d.w * 0.5, d.h * 0.5, clampf(inner * 0.78, 12, 60))
		d.add(centre, d.w * 0.5, d.h * 0.5, clampf(inner * 0.5, 10, 40))
	else:
		d.add(centre, d.w * 0.5, d.h * 0.5, clampf(inner * 0.62, 10, 46))
	if d.w > d.h * 1.25 and inner > 14:
		var side: String = (pictures + patterns)[rng.randi() % (pictures.size() + patterns.size())]
		var s := clampf(inner * 0.42, 8, 30)
		d.add(side, d.w * 0.2, d.h * 0.5, s)
		d.add(side, d.w * 0.8, d.h * 0.5, s, 0, true)
	if inner > 18 and rng.randf() < 0.7:
		var corner: String = patterns[rng.randi() % patterns.size()]
		var cs := clampf(inner * 0.2, 6, 14)
		var bw := int(d.border.get("width", 0)) + 2
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var at: Vector2 = Vector2(d.w, d.h) * 0.5 + Vector2(d.w * 0.5 - bw - cs * 0.6, d.h * 0.5 - bw - cs * 0.6) * (c as Vector2)
			d.add(corner, at.x, at.y, cs)
	for p in d.placements:
		p["fine"] = tier >= 3 and Data.motif(p["motif"]).get("kind", "") == "picture"
	return d
