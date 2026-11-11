class_name Brief
## What a client asks for, and how well a design meets it.
## A brief is a dictionary: {tags, want_stones, ban_stones, must, border, min_motifs, budget, room}.

const TAG_WORDS := {
	"sea": "something from the sea", "garden": "something from a garden", "animals": "an animal",
	"feast": "something to eat or drink", "hunt": "a hunting scene", "myth": "something from the old stories",
	"geometric": "a geometric pattern", "guard": "a guard dog to warn off thieves", "music": "music",
	"luck": "a charm for good luck", "wine": "something to do with wine", "bread": "bread", "games": "the races or games",
	"trade": "ships and trade", "words": "words",
}


## Each wish with whether the design meets it, and a score from 0 to 1; stone wishes count only stone that shows.
static func score(brief: Dictionary, design: FloorDesign, shown: Array = []) -> Dictionary:
	var wishes := []
	var stones := shown if not shown.is_empty() else stones_shown(Composer.compose(design, Looks.PX))
	var tags := {}
	var motifs := {}
	for p in design.placements:
		motifs[p["motif"]] = true
		for t in Data.motif(p["motif"]).get("tags", []):
			tags[t] = true
	for t in brief.get("tags", []):
		wishes.append({"text": TranslationServer.translate(wish_key("tag", t)), "met": tags.has(t), "kind": "tag", "value": t})
	for m in brief.get("must", []):
		wishes.append({"text": TranslationServer.translate(wish_key("must", m)), "met": motifs.has(m), "kind": "must", "value": m})
	for s in brief.get("want_stones", []):
		wishes.append({"text": TranslationServer.translate(wish_key("want", s)), "met": s in stones, "kind": "want", "value": s})
	for s in brief.get("ban_stones", []):
		wishes.append({"text": TranslationServer.translate(wish_key("ban", s)), "met": not s in stones, "kind": "ban", "value": s})
	if bool(brief.get("border", false)):
		wishes.append({"text": TranslationServer.translate("A border round the edge"), "met": str(design.border.get("id", "")) != "", "kind": "border"})
	var need := int(brief.get("min_motifs", 0))
	if need > 0:
		wishes.append({"text": TranslationServer.translate("At least %d pictures or patterns") % need, "met": design.placements.size() >= need, "kind": "count", "value": need})
	if wishes.is_empty():
		return {"wishes": [], "score": 1.0}
	var met := 0
	for w in wishes:
		if w["met"]:
			met += 1
	return {"wishes": wishes, "score": float(met) / wishes.size()}


## A wish in English, the key of its translation: a whole phrase, since other languages change the words round a name.
static func wish_key(kind: String, value: String) -> String:
	match kind:
		"tag":
			return "Shows " + TAG_WORDS.get(value, value)
		"must":
			return "Has " + Data.motif_with_article(value)
		"want":
			return "Uses " + str(Stones.LIST[Stones.index(value)]["name"]).to_lower()
		"ban":
			return "No " + str(Stones.LIST[Stones.index(value)]["name"]).to_lower()
	return value


## A theme's words in the player's language: "something from the sea".
static func tag_words(tag: String) -> String:
	return TranslationServer.translate(TAG_WORDS.get(tag, tag))


## How to meet a wish, for its tooltip: for a theme, which patterns in the book show it.
static func help(wish: Dictionary, unlocked: Array) -> String:
	match str(wish.get("kind", "")):
		"tag":
			var tag := str(wish["value"])
			var have := []
			var later := []
			for id in Data.motif_order:
				if tag in Data.motif(id).get("tags", []):
					(have if id in unlocked else later).append(Data.motif_title(id))
			var comma := String(TranslationServer.translate(", "))
			var text: String = TranslationServer.translate("In your pattern book: %s.") % comma.join(have) if not have.is_empty() else TranslationServer.translate("Nothing in your pattern book shows this yet.")
			return text + (Ui.sentence_gap() + TranslationServer.translate("Later: %s.") % comma.join(later) if not later.is_empty() else "")
		"must":
			var id := str(wish["value"])
			if Data.motif(id).get("kind", "") == "picture":
				return TranslationServer.translate("Find the %s on the Pictures page of the pattern book.") % Data.motif_name(id)
			return TranslationServer.translate("Find the %s on the Patterns page of the pattern book.") % Data.motif_name(id)
		"want":
			return TranslationServer.translate("Give any part of the floor this stone: pick a part, then the stone.")
		"ban":
			return TranslationServer.translate("Don't let this stone show anywhere, borders and outlines included.")
		"border":
			return TranslationServer.translate("Pick one on the Borders page of the pattern book.")
		"count":
			return TranslationServer.translate("Put at least %d pictures or patterns on the floor.") % int(wish["value"])
	return ""


## Every stone that appears in a composed floor.
static func stones_shown(img: Image) -> Array:
	var data := img.get_data()
	var by_colour := Stones.lookup()
	var seen := {}
	for i in range(0, data.size(), 3):
		var s: int = by_colour.get((data[i] << 16) | (data[i + 1] << 8) | data[i + 2], Stones.NO_TILE)
		if s != Stones.NO_TILE:
			seen[s] = true
	return seen.keys().map(func(s: int) -> String: return Stones.id_of(s))


## The verdict on a design for a job: {wishes, looks, score, stars}, plus likeness for a copy, under the taste given.
static func judge(job: Dictionary, design: FloorDesign, taste: Array) -> Dictionary:
	if str(job.get("kind", "")) == "copy" and job.has("target"):
		var like := likeness(FloorDesign.from_dict(job["target"]), design)
		var s := clampf((like - 0.35) / 0.55, 0.0, 1.0)
		return {"wishes": [], "looks": {}, "likeness": like, "score": s, "stars": Looks.stars(s)}
	var looks := Looks.judge(design, taste)
	var wished := score(job.get("brief", {}), design, looks["shown"])
	var total: float = looks["beauty"]
	if not (wished["wishes"] as Array).is_empty():
		total = 0.3 * float(wished["score"]) + 0.7 * float(looks["beauty"])
	return {"wishes": wished["wishes"], "looks": looks, "score": total, "stars": Looks.stars(total)}


## How closely a design matches the floor it copies, stone by stone, with plain ground counting a quarter as much.
static func likeness(target: FloorDesign, design: FloorDesign) -> float:
	var a := Composer.compose(target, Looks.PX).get_data()
	var b := Composer.compose(design, Looks.PX).get_data()
	if a.size() != b.size():
		return 0.0
	var ground := Stones.map_colour(target.ground)
	var g := PackedByteArray([ground.r8, ground.g8, ground.b8])
	var met := 0.0
	var total := 0.0
	for i in range(0, a.size(), 3):
		if a[i] == 255 and a[i + 1] == 0 and a[i + 2] == 255:
			continue
		var plain := a[i] == g[0] and a[i + 1] == g[1] and a[i + 2] == g[2]
		var w := 0.25 if plain else 1.0
		total += w
		if a[i] == b[i] and a[i + 1] == b[i + 1] and a[i + 2] == b[i + 2]:
			met += w
	return met / maxf(total, 1.0)
