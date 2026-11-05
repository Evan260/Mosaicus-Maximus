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
	var bw := int(d.border.get("width", 0)) + 2
	var inner := short - 2.0 * bw
	var centre: String = pictures[rng.randi() % pictures.size()] if (not pictures.is_empty() and rng.randf() < 0.6) else patterns[rng.randi() % patterns.size()]
	if d.shape == "pool" and d.pool.size() == 4:
		# The pool fills the room's middle, so the centrepiece lies on the open floor between the pool and the doorway.
		var front := d.h * (float(d.pool[1]) + float(d.pool[3]))
		var size := _fit(centre, clampf(inner * 0.62, 10, 46), Vector2(d.w - 2.0 * bw, d.h - bw - front) * 0.9)
		d.add(centre, d.w * 0.5, (front + d.h - bw) * 0.5, size)
	elif Data.motif(centre).get("kind", "") == "picture" and rng.randf() < 0.6:
		d.add("roundel", d.w * 0.5, d.h * 0.5, clampf(inner * 0.78, 12, 60))
		d.add(centre, d.w * 0.5, d.h * 0.5, clampf(inner * 0.5, 10, 40))
	else:
		d.add(centre, d.w * 0.5, d.h * 0.5, clampf(inner * 0.62, 10, 46))
	if d.w > d.h * 1.25 and inner > 14:
		var side: String = (pictures + patterns)[rng.randi() % (pictures.size() + patterns.size())]
		var s := clampf(inner * 0.42, 8, 30)
		if d.shape == "apse":
			s = _within_apse(d, side, Vector2(d.w * 0.2, d.h * 0.5), s, bw)
		d.add(side, d.w * 0.2, d.h * 0.5, s)
		d.add(side, d.w * 0.8, d.h * 0.5, s, 0, true)
	if inner > 18 and rng.randf() < 0.7:
		var corner: String = patterns[rng.randi() % patterns.size()]
		var cs := clampf(inner * 0.2, 6, 14)
		var low := d.h - bw - cs * 0.6
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var at: Vector2 = Vector2(d.w, d.h) * 0.5 + Vector2(d.w * 0.5 - bw - cs * 0.6, d.h * 0.5 - bw - cs * 0.6) * (c as Vector2)
			if d.shape == "apse" and c.y < 0:
				at.y = _below_apse(d, at, cs * 0.5, bw)
				if at.y + cs > low or not _clear_of(d, at, cs):
					continue
			d.add(corner, at.x, at.y, cs)
	for p in d.placements:
		p["fine"] = tier >= 3 and Data.motif(p["motif"]).get("kind", "") == "picture"
	return d


## The motif's size, at most the one given, small enough for the motif to fit inside an area of the floor.
static func _fit(id: String, size: float, area: Vector2) -> float:
	var t := MotifLibrary.tiles(id, 1.0)
	return minf(size, minf(area.x / t.x, area.y / t.y))


## How far down a square motif half wide in each direction must sit for its box to clear an apse's curve and border.
static func _below_apse(d: FloorDesign, at: Vector2, half: float, bw: int) -> float:
	var r := d.w * 0.5
	var reach := r - bw
	var dx := absf(at.x - r) + half
	return maxf(at.y, r + half - sqrt(maxf(reach * reach - dx * dx, 0.0)))


## The motif's size, at most the one given, small enough for its box at this spot to clear an apse's curve and border.
static func _within_apse(d: FloorDesign, id: String, at: Vector2, size: float, bw: int) -> float:
	var r := d.w * 0.5
	var reach := r - bw
	var t := MotifLibrary.tiles(id, 1.0) * 0.5
	var a := absf(at.x - r)
	var b := r - at.y
	if b + size * t.y <= 0.0:
		return size
	var qa := t.x * t.x + t.y * t.y
	var qb := 2.0 * (a * t.x + b * t.y)
	var qc := a * a + b * b - reach * reach
	return clampf((-qb + sqrt(maxf(qb * qb - 4.0 * qa * qc, 0.0))) / (2.0 * qa), 6.0, size)


## Whether a motif this size at this spot stays clear of every motif already on the floor.
static func _clear_of(d: FloorDesign, at: Vector2, size: float) -> bool:
	for p in d.placements:
		if at.distance_to(Vector2(float(p["x"]), float(p["y"]))) < (size + float(p["size"])) * 0.5:
			return false
	return true
