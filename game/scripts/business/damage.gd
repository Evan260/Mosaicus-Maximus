class_name Damage
## The gaps in an old floor: ragged patches where tiles have come loose and been lost over the centuries.


## Tiles missing from a floor, in patches, until about the given share of them is gone.
static func holes(layout: MosaicLayout, rng: RandomNumberGenerator, severity: float) -> PackedInt32Array:
	var n := layout.tile_count()
	var target := int(n * clampf(severity, 0.0, 0.9))
	var gone := {}
	var guard := 0
	while gone.size() < target and guard < 4000:
		guard += 1
		var centre := layout.pos[rng.randi() % n]
		var radius := rng.randf_range(1.5, 5.5) * layout.px
		for i in layout.tiles_near(centre, radius):
			if gone.size() >= target:
				break
			if rng.randf() < 0.82 or layout.pos[i].distance_to(centre) < radius * 0.5:
				gone[i] = true
	var out := PackedInt32Array()
	for i in gone:
		out.append(i)
	return out
