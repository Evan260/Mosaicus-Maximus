class_name Looks
## How a floor looks, in five things anyone can see: symmetry, a centrepiece, how full it is, its colours and its
## frame. Each runs from 0 to 1, and a client's taste changes what they ask of each and how much it counts.

const QUALITIES := ["symmetry", "centre", "fill", "colour", "frame"]
const NAMES := {"symmetry": "Both halves match", "centre": "A big centrepiece", "fill": "Well filled", "colour": "Good colours", "frame": "A border"}
## What each quality means, for the tooltip on its line of the checklist.
const ABOUT := {
	"symmetry": "The floor mirrors itself across one of the dotted middle lines: pictures sit on a line, or in matching pairs either side.",
	"centre": "One pattern clearly bigger than the rest sits where the dotted lines cross.",
	"fill": "About a quarter to a half of the floor is pattern, spread over all four corners of the room.",
	"colour": "Two to five colours, each standing out from the plain ground.",
	"frame": "A border runs round the edge, in stones that stand out from the ground.",
}
const WEIGHTS := {"symmetry": 1.0, "centre": 1.0, "fill": 1.0, "colour": 0.8, "frame": 0.6}
## Each taste, what a client says about it, and which quality it makes count for more.
const TASTES := {
	"mirrored": {"text": "loves a floor that mirrors itself", "quality": "symmetry"},
	"big_centre": {"text": "wants one big centrepiece", "quality": "centre"},
	"busy": {"text": "likes a floor full of pictures", "quality": "fill"},
	"calm": {"text": "likes plenty of plain floor", "quality": "fill"},
	"colourful": {"text": "loves lots of colour", "quality": "colour"},
	"few_colours": {"text": "likes two or three colours, no more", "quality": "colour"},
	"framed": {"text": "wants a strong border", "quality": "frame"},
}
const TASTE_WEIGHT := 2.5
## A quality at or above this gets a tick on the design table.
const GOOD := 0.7
const PX := 2


## Judges a design: {qualities: {id: value}, hints: {id: text}, beauty: 0 to 1, best: id, worst: id, crowded: too much pattern}.
static func judge(design: FloorDesign, taste: Array = []) -> Dictionary:
	var img := Composer.compose(design, PX)
	var counts := _counts(img)
	var ground := Stones.index(design.ground)
	var cover := coverage(img, ground)
	var crowded: bool = float(cover["share"]) > ideal_fill(taste).y
	var q := {
		"symmetry": symmetry(design),
		"centre": _centre(design, "big_centre" in taste),
		"fill": _fill(cover, taste),
		"colour": _colour(counts, ground, taste),
		"frame": _frame(design, "framed" in taste),
	}
	var total := 0.0
	var weight := 0.0
	for id in QUALITIES:
		var w: float = WEIGHTS[id]
		for t in taste:
			if TASTES.has(t) and TASTES[t]["quality"] == id:
				w *= TASTE_WEIGHT
		total += w * float(q[id])
		weight += w
	var best := ""
	var worst := ""
	for id in QUALITIES:
		if best == "" or float(q[id]) > float(q[best]):
			best = id
		if worst == "" or float(q[id]) < float(q[worst]):
			worst = id
	# The weakest quality pulls the whole down, so one strong point can't carry a floor that is bare or lopsided.
	var beauty := 0.7 * total / weight + 0.3 * float(q[worst])
	var shown := []
	for st in counts:
		if st != Stones.NO_TILE:
			shown.append(Stones.id_of(st))
	return {"qualities": q, "hints": _hints(q, crowded, ground, taste, counts), "beauty": beauty, "best": best, "worst": worst, "shown": shown, "crowded": crowded}


## How far motifs answer each other across a middle line, weighed by size; a pair in other stones counts a little less.
static func symmetry(design: FloorDesign) -> float:
	if design.placements.is_empty():
		return 0.0
	var scores := []
	for axis in [0, 1]:
		var met := 0.0
		var total := 0.0
		for p in design.placements:
			var w := pow(float(p["size"]), 2.0)
			total += w
			met += w * _mirrored(design, p, axis)
		scores.append(met / maxf(total, 0.001))
	return 0.75 * maxf(scores[0], scores[1]) + 0.25 * minf(scores[0], scores[1])


static func _mirrored(design: FloorDesign, p: Dictionary, axis: int) -> float:
	var span := float(design.w if axis == 0 else design.h)
	var at := Vector2(float(p["x"]), float(p["y"]))
	var along := at.x if axis == 0 else at.y
	if absf(along - span * 0.5) <= 0.75:
		return 1.0
	var want := Vector2(span - at.x, at.y) if axis == 0 else Vector2(at.x, span - at.y)
	var best := 0.0
	for o in design.placements:
		if o == p or o["motif"] != p["motif"] or absf(float(o["size"]) - float(p["size"])) > 1.0:
			continue
		if Vector2(float(o["x"]), float(o["y"])).distance_to(want) > 1.25:
			continue
		best = maxf(best, 1.0 if o["stones"] == p["stones"] else 0.6)
	return best


## The best single motif for catching the eye: big, and close to the middle. A pool takes the middle in an atrium.
static func _centre(design: FloorDesign, demanding: bool) -> float:
	if design.shape == "pool":
		return 1.0
	var mid := Vector2(design.w, design.h) * 0.5
	var short := minf(design.w, design.h)
	var best := 0.0
	for p in design.placements:
		var close := 1.0 - clampf(Vector2(float(p["x"]), float(p["y"])).distance_to(mid) / (short * 0.22), 0.0, 1.0)
		var big := clampf(float(p["size"]) / (short * (0.55 if demanding else 0.42)), 0.0, 1.0)
		best = maxf(best, close * sqrt(big))
	return best


## The share of the floor that isn't plain ground, and how evenly it is spread over the four quarters of the room.
static func coverage(img: Image, ground: int) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var by_colour := Stones.lookup()
	var busy := [0, 0, 0, 0]
	var area := [0, 0, 0, 0]
	for y in h:
		for x in w:
			var i := (y * w + x) * 3
			var s: int = by_colour.get((data[i] << 16) | (data[i + 1] << 8) | data[i + 2], ground)
			if s == Stones.NO_TILE:
				continue
			var quarter := (1 if x >= w / 2 else 0) + (2 if y >= h / 2 else 0)
			area[quarter] += 1
			if s != ground:
				busy[quarter] += 1
	var shares := []
	for k in 4:
		shares.append(float(busy[k]) / maxf(1.0, area[k]))
	var all_busy := 0
	var all_area := 0
	for k in 4:
		all_busy += busy[k]
		all_area += area[k]
	return {"share": float(all_busy) / maxf(1.0, all_area), "lowest": shares.min(), "highest": shares.max()}


static func ideal_fill(taste: Array) -> Vector2:
	if "busy" in taste:
		return Vector2(0.42, 0.75)
	if "calm" in taste:
		return Vector2(0.1, 0.3)
	return Vector2(0.24, 0.55)


static func _fill(c: Dictionary, taste: Array) -> float:
	var ideal := ideal_fill(taste)
	var f: float = c["share"]
	var amount := 1.0
	if f < ideal.x:
		amount = f / ideal.x
	elif f > ideal.y:
		amount = clampf(1.0 - (f - ideal.y) / (1.0 - ideal.y) * 1.6, 0.15, 1.0)
	var even := 1.0 - clampf((float(c["highest"]) - float(c["lowest"])) / maxf(float(c["highest"]), 0.01), 0.0, 1.0) * 0.7
	return amount * (0.7 + 0.3 * even)


static func ideal_colours(taste: Array) -> Vector2i:
	if "colourful" in taste:
		return Vector2i(4, 8)
	if "few_colours" in taste:
		return Vector2i(1, 3)
	return Vector2i(2, 5)


## Enough colours, but not so many they fight, and each standing out from the ground.
static func _colour(counts: Dictionary, ground: int, taste: Array) -> float:
	var total := 0
	for s in counts:
		total += int(counts[s])
	var used := []
	for s in counts:
		if s != ground and s != Stones.NO_TILE and counts[s] >= total * 0.01:
			used.append(s)
	if used.is_empty():
		return 0.0
	var ideal := ideal_colours(taste)
	var n := used.size()
	var amount := 1.0
	if n < ideal.x:
		amount = 0.45 + 0.55 * float(n - 1) / maxf(1.0, ideal.x - 1)
	elif n > ideal.y:
		amount = maxf(0.3, 1.0 - 0.18 * (n - ideal.y))
	var contrast := 0.0
	var weight := 0
	for s in used:
		contrast += Stones.difference(Stones.id_of(ground), Stones.id_of(s)) * counts[s]
		weight += counts[s]
	return amount * (0.55 + 0.45 * clampf(contrast / maxf(1.0, weight) / 0.25, 0.0, 1.0))


static func _frame(design: FloorDesign, demanding: bool) -> float:
	if str(design.border.get("id", "")) == "":
		return 0.0 if demanding else 0.3
	var best := 0.0
	for s in design.border.get("stones", []):
		best = maxf(best, Stones.difference(design.ground, str(s)))
	var bold := clampf(best / 0.2, 0.0, 1.0)
	var width := clampf(float(design.border.get("width", 2)) / (5.0 if demanding else 3.0), 0.0, 1.0)
	return 0.5 + 0.3 * bold + 0.2 * width


static func _counts(img: Image) -> Dictionary:
	var data := img.get_data()
	var by_colour := Stones.lookup()
	var out := {}
	for i in img.get_width() * img.get_height():
		var s: int = by_colour.get((data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2], 0)
		out[s] = out.get(s, 0) + 1
	return out


## What to do about every quality that falls short, said plainly enough to act on.
static func _hints(q: Dictionary, crowded: bool, ground: int, taste: Array, counts: Dictionary) -> Dictionary:
	var out := {}
	if q["symmetry"] < GOOD:
		out["symmetry"] = "Make both halves match: put each picture on a dotted line, or give it a twin on the other side with Pair."
	if q["centre"] < GOOD:
		out["centre"] = "Put one big pattern where the dotted lines cross, bigger than the rest."
	if q["fill"] < GOOD:
		out["fill"] = "Too crowded. Make things smaller, or take some away." if crowded else "Too much plain floor. Add more, or make them bigger."
	if q["colour"] < GOOD:
		var total := 0
		for st in counts:
			total += int(counts[st])
		var used := counts.keys().filter(func(st: int) -> bool: return st != ground and st != Stones.NO_TILE and counts[st] >= total * 0.01).size()
		var ideal := ideal_colours(taste)
		if used < ideal.x:
			out["colour"] = "Add another colour: pick a part and give it a new stone."
		elif used > ideal.y:
			out["colour"] = "Too many colours at once. Use fewer stones."
		else:
			out["colour"] = "Some parts are hard to see. Pick stones that stand out from the ground."
	if q["frame"] < GOOD:
		out["frame"] = "Add a border from the Borders page." if q["frame"] <= 0.3 else "Make the border bolder, in stones that stand out from the ground."
	return out


## Stars from a score of 0 to 1.
static func stars(score: float) -> int:
	if score >= 0.88:
		return 5
	if score >= 0.74:
		return 4
	if score >= 0.58:
		return 3
	if score >= 0.4:
		return 2
	return 1


const PRAISE := {
	"symmetry": "Every side answers the other.",
	"centre": "That centrepiece! It's the first thing anyone sees.",
	"fill": "Just the right amount of pattern.",
	"colour": "The colours sing together.",
	"frame": "The border frames it beautifully.",
}
const COMPLAINTS := {
	"symmetry": "It feels a little lopsided.",
	"centre": "My eye doesn't know where to look.",
	"fill": "It feels a little bare.",
	"crowded": "It's rather crowded.",
	"colour": "The colours don't quite sit together.",
	"frame": "It wants a border, I think.",
}
## What a client says about their own taste the first time, when the floor did and didn't please it.
const TASTE_SAID := {
	"mirrored": ["And it mirrors itself, just as I like.", "I do like a floor that mirrors itself, you know."],
	"big_centre": ["One great centrepiece, just as I like.", "I like one big piece in the middle, you know."],
	"busy": ["So much to look at, just as I like.", "I like a floor full of pictures, you know."],
	"calm": ["Plenty of plain floor, just as I like.", "I like plenty of plain floor, you know."],
	"colourful": ["All those colours, just as I like.", "I love lots of colour, you know."],
	"few_colours": ["Just a few colours, as I like.", "Two or three colours are plenty for me, you know."],
	"framed": ["And a fine strong border, as I like.", "I like a strong border, you know."],
}


## The complaint about a quality, telling a crowded floor from a bare one.
static func complaint(looks: Dictionary, id: String) -> String:
	if id == "fill" and bool(looks.get("crowded", false)):
		return COMPLAINTS["crowded"]
	return COMPLAINTS.get(id, "")
