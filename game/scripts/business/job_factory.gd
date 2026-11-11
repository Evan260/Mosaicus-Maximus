class_name JobFactory
## The notices pinned to the job board each morning: commissions from named clients and townsfolk, and restorations.
## Every board has a few jobs the player can afford, however little money is left.

# The regular clients' portraits that show a woman, and the two old townsfolk faces of women; people.json has the rest.
const WOMEN := ["cornelia", "livia", "valeria", "towns_2", "towns_4"]


static func board(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var count := int(Data.num("board.jobs", 4)) + (1 if "courtyard" in state["upgrades"] else 0)
	var jobs := []
	var used := {}
	for k in count:
		var job: Dictionary
		var roll := rng.randf()
		var digs := Data.num("board.restoration_chance", 0.35)
		if k > 0 and roll < digs:
			job = restoration(state, rng)
		elif k > 0 and int(state["day"]) >= 2 and roll < digs + Data.num("board.copy_chance", 0.15):
			job = copy(state, rng, used)
		else:
			job = commission(state, rng, used, false)
		job["id"] = "%d_%d" % [int(state["day"]), k]
		jobs.append(job)
	var fest := Story.festival(state)
	var tag := Story.festival_tag(state, fest) if not fest.is_empty() else ""
	if tag != "":
		# The townsfolk keep the festival, so there is always one of them on the board that day.
		if not jobs.any(func(j: Dictionary) -> bool: return j["kind"] == "commission" and j["client"] == ""):
			var extra := _townsfolk(state, rng, false)
			extra["id"] = "%d_festival" % int(state["day"])
			jobs.append(extra)
		for job in jobs:
			if job["kind"] == "commission" and job["client"] == "":
				# First, so the notice shows the festival's wish before any other.
				job["brief"]["tags"].erase(tag)
				job["brief"]["tags"].push_front(tag)
				job["budget"] = int(job["budget"] * Data.num("festival.pay_scale", 1.25))
				job["festival"] = fest["id"]
				job["line"] = [job["line"], Ui.say("It's the %s, after all!", [fest["name"]])]
	if int(state["day"]) % int(Data.num("contest.every", 7)) == 0:
		var entry := contest(state, rng)
		entry["id"] = "%d_contest" % int(state["day"])
		jobs.push_front(entry)
	var need := int(Data.num("board.min_affordable", 2))
	# The contest and one festival notice, an affordable one if any, are never swapped, since the day promises them.
	var spare := []
	var festive := []
	for i in jobs.size():
		if jobs[i]["kind"] != "contest":
			(festive if jobs[i].has("festival") else spare).append(i)
	festive.sort_custom(func(a: int, b: int) -> bool: return affordable(jobs[a], state) and not affordable(jobs[b], state))
	spare += festive.slice(1)
	for k in spare:
		if jobs.filter(func(j: Dictionary) -> bool: return affordable(j, state)).size() >= need:
			break
		if not affordable(jobs[k], state):
			var fresh := restoration(state, rng, true)
			for _try in 6:
				if not jobs.any(func(j: Dictionary) -> bool: return str(j["client_name"]) == str(fresh["client_name"]) and j["room"] == fresh["room"]):
					break
				fresh = restoration(state, rng, true)
			jobs[k] = fresh
			jobs[k]["id"] = "%d_r%d" % [int(state["day"]), k]
	return jobs


## Whether the player could lay at least the plainest floor for this job with what they have; only a restoration's stone is supplied.
static func affordable(job: Dictionary, state: Dictionary) -> bool:
	if job.get("kind", "") == "restoration":
		return true
	var r := Data.room(job["room"])
	var tiles := int(r.get("w", 40)) * int(r.get("h", 30)) * Composer.TILES_PER_SQUARE
	var cheapest := INF
	for id in state["unlocked_stones"]:
		cheapest = minf(cheapest, Data.stone_price(id))
	var have := 0
	for id in state["stock"]:
		have += int(state["stock"][id])
	return maxf(0.0, tiles - have) * cheapest <= int(state["coins"])


static func commission(state: Dictionary, rng: RandomNumberGenerator, used: Dictionary, small: bool) -> Dictionary:
	var chapter := int(state["chapter"])
	var busy := str((state.get("active_job", {}) as Dictionary).get("client", ""))
	var named := []
	for id in Data.client_order:
		var c := Data.client(id)
		var progress: Dictionary = state["clients"].get(id, {})
		var step := int(progress.get("step", 0))
		if int(c.get("chapter", 1)) > chapter or used.has(id) or id == busy or step >= (c.get("arc", []) as Array).size():
			continue
		if int(progress.get("away_until", 0)) > int(state["day"]):
			continue
		var beat: Dictionary = c["arc"][step]
		if int(beat.get("chapter", 1)) > chapter or int(Data.room(step_room(id, step)).get("tier", 1)) > chapter or not possible(beat, state):
			continue
		named.append(id)
	if not small and not named.is_empty() and rng.randf() < 0.65:
		var id: String = named[rng.randi() % named.size()]
		used[id] = true
		return _named(id, state, rng)
	return _townsfolk(state, rng, small, used)


static func _named(id: String, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var c := Data.client(id)
	var step := int(state["clients"].get(id, {}).get("step", 0))
	var beat: Dictionary = c["arc"][step]
	var room := step_room(id, step)
	if bool(beat.get("restoration", false)):
		var job := restoration(state, rng)
		var d := RandomDesign.make(room, 4, rng)
		job.merge({"client": id, "client_name": c["name"], "portrait": c.get("portrait", ""), "woman": str(c.get("portrait", "")) in WOMEN, "room": room, "design": d.to_dict(),
			"severity": 0.3, "budget": int(_area(room) * 0.14), "arc_step": step, "line": beat.get("line", ""), "greeting": c.get("greeting", ""),
			"text": Ui.say("%s needs the floor under the forum restored.", [c["name"]])}, true)
		return job
	var brief := {"tags": beat.get("tags", []), "must": beat.get("must", []), "want_stones": beat.get("want_stones", []),
		"ban_stones": (c.get("hates", []) as Array).duplicate(), "border": bool(beat.get("border", false)), "min_motifs": int(beat.get("min_motifs", 0))}
	if brief["want_stones"].is_empty() and rng.randf() < 0.5:
		var loved := (c.get("loves", []) as Array).filter(func(s) -> bool: return s in state["unlocked_stones"] and not Stones.is_ground(Stones.index(s)))
		if not loved.is_empty():
			brief["want_stones"] = [loved[rng.randi() % loved.size()]]
	var b: Array = c.get("budget", [80, 120])
	var area := _area(room)
	var budget := int(rng.randi_range(int(b[0]), int(b[1])) * clampf(area / 1600.0, 0.8, Data.num("budget.named_scale_max", 1.8)))
	return {"kind": "commission", "client": id, "client_name": c["name"], "trade": c.get("trade", ""), "portrait": c.get("portrait", ""),
		"room": room, "brief": brief, "budget": budget, "arc_step": step, "line": beat.get("line", c.get("greeting", "")), "taste": c.get("taste", []),
		"greeting": c.get("greeting", ""), "text": Ui.say("%s, %s, wants a new floor for the %s.", [c["name"], c.get("trade", ""), str(Data.room(room).get("name", room)).to_lower()])}


## The room a client's story step is set in: the step's own, or the client's room for that step, the last for any after.
static func step_room(id: String, step: int) -> String:
	var c := Data.client(id)
	var rooms: Array = c.get("rooms", [])
	return str(c["arc"][step].get("room", rooms[mini(step, rooms.size() - 1)]))


static func _townsfolk(state: Dictionary, rng: RandomNumberGenerator, small: bool, used: Dictionary = {}) -> Dictionary:
	var names: Dictionary = Data.names
	var who := person(rng, used)
	used[who["id"]] = true
	var first: String = who["name"]
	var trade: String = who["trade"]
	var chapter := int(state["chapter"])
	var rooms := Data.job_rooms().filter(func(r) -> bool: return int(Data.room(r).get("tier", 1)) <= chapter and r != "forum" and r != "temple")
	if small:
		rooms.sort_custom(func(a, b) -> bool: return _area(a) < _area(b))
		rooms = rooms.slice(0, 2)
	var room: String = rooms[rng.randi() % rooms.size()]
	var tags := {}
	for t in names.get("likes", {}).get(trade, []):
		tags[t] = true
	var pool := ["geometric", "garden", "animals", "sea", "feast"]
	if chapter >= 3:
		pool += ["hunt", "myth", "music"]
	pool = pool.filter(func(t: String) -> bool: return tag_open(t, state))
	for t in tags.keys():
		if not tag_open(t, state):
			tags.erase(t)
	while tags.size() < (1 if rng.randf() < 0.6 else 2) and not pool.is_empty():
		tags[pool[rng.randi() % pool.size()]] = true
	var brief := {"tags": tags.keys(), "must": [], "want_stones": [], "ban_stones": [], "border": rng.randf() < 0.3, "min_motifs": 0}
	var colours := (state["unlocked_stones"] as Array).filter(func(s) -> bool: return not Stones.is_ground(Stones.index(s)))
	var wall := bool(Data.room(room).get("wall", false))
	if rng.randf() < 0.45 and not colours.is_empty():
		brief["want_stones"] = [colours[rng.randi() % colours.size()]]
	if wall:
		var glass := (state["unlocked_stones"] as Array).filter(func(s: String) -> bool: return Stones.LIST[Stones.index(s)]["material"] in [Stones.Kind.GLASS, Stones.Kind.GOLD])
		if not glass.is_empty():
			brief["want_stones"] = [glass[rng.randi() % glass.size()]]
	if rng.randf() < 0.25 and colours.size() > 1:
		var ban: String = colours[rng.randi() % colours.size()]
		if not ban in brief["want_stones"]:
			brief["ban_stones"] = [ban]
	var wealth := float(names.get("wealth", {}).get(trade, 1.0))
	var rate := Data.num("budget.per_tile", 0.038) + Data.num("budget.per_tile_per_chapter", 0.012) * chapter
	var budget := int(_area(room) * rate * wealth * rng.randf_range(0.88, 1.15))
	var want := str(names["wants"][rng.randi() % names["wants"].size()])
	if wall:
		want = "{name} wants a wall mosaic that glitters in the fountain niche."
	var room_name := str(Data.room(room).get("name", room)).to_lower()
	var taste := []
	var line: Array = [Ui.say(want, {"name": first, "room": room_name})]
	if rng.randf() < Data.num("board.townsfolk_taste", 0.7):
		var t: String = Looks.TASTES.keys()[rng.randi() % Looks.TASTES.size()]
		taste = [t]
		line.append(Ui.say(Looks.TASTES[t]["also"], [first]))
	return {"kind": "commission", "client": "", "client_name": Ui.say("%s, %s", [first, trade]), "trade": trade, "portrait": Data.face(who), "woman": who["woman"],
		"room": room, "brief": brief, "budget": budget, "arc_step": -1, "line": line, "greeting": "", "taste": taste, "taste_said": true,
		"text": Ui.say(want, {"name": Ui.say("%s, %s,", [first, trade]), "room": room_name})}


## A collector wants a famous floor copied from a rubbing, in a room small enough to copy in one go.
static func copy(state: Dictionary, rng: RandomNumberGenerator, used: Dictionary = {}) -> Dictionary:
	var chapter := int(state["chapter"])
	var rooms := Data.job_rooms(false).filter(func(r) -> bool: return int(Data.room(r).get("tier", 1)) <= chapter and _area(r) <= 2600.0)
	var room: String = rooms[rng.randi() % rooms.size()]
	var target := _only_unlocked(RandomDesign.make(room, chapter, rng), state)
	var places := ["Alexandria", "the House of the Faun in Pompeii", "the old palace at Antioch", "a villa on Capri", "the baths at Ostia"]
	var collectors: Array = (Data.people.get("collectors", []) as Array).filter(func(p: Dictionary) -> bool: return not used.has(p["id"]))
	if collectors.is_empty():
		collectors = Data.people.get("collectors", [{"id": "collector", "name": "A collector", "woman": false}])
	var who: Dictionary = collectors[rng.randi() % collectors.size()]
	used[who["id"]] = true
	var first: String = who["name"]
	var place: String = places[rng.randi() % places.size()]
	var rate := Data.num("budget.per_tile", 0.038) + Data.num("budget.per_tile_per_chapter", 0.012) * chapter
	var budget := int(_area(room) * rate * Data.num("budget.copy_scale", 1.3) * rng.randf_range(0.9, 1.1))
	return {"kind": "copy", "client": "", "client_name": Ui.say("%s, a collector", [first]), "trade": "a collector", "portrait": Data.face(who), "woman": who["woman"],
		"room": room, "brief": {}, "target": target.to_dict(), "budget": budget, "arc_step": -1, "taste": [], "greeting": "",
		"line": Ui.say("%s wants the famous floor from %s copied, stone for stone. Here is a painted sketch of it.", [first, place]),
		"text": Ui.say("%s wants a famous floor copied.", [first])}


## The town's floor contest: no client and no brief, judged on looks alone against the rival workshop's entry.
static func contest(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var chapter := int(state["chapter"])
	var rooms := ["changing_room", "dining_room", "atrium", "villa_dining"].filter(func(r) -> bool: return int(Data.room(r).get("tier", 1)) <= chapter)
	if rooms.is_empty():
		rooms = ["study"]
	var room: String = rooms[rooms.size() - 1]
	var rival := minf(Data.num("contest.rival_cap", 0.86), Data.num("contest.rival_base", 0.52) + Data.num("contest.rival_per_chapter", 0.07) * chapter + rng.randf_range(-0.04, 0.04))
	var prize := int(Data.num("contest.prize", 100) + Data.num("contest.prize_per_chapter", 50) * chapter)
	return {"kind": "contest", "client": "", "client_name": "The town's floor contest", "trade": "", "portrait": Data.face(Data.people.get("herald", {})), "woman": false,
		"room": room, "brief": {}, "budget": prize, "arc_step": -1, "taste": [], "rival": rival, "greeting": "",
		"line": Ui.say("The aediles are holding the floor contest again. The judges look at nothing but how a floor looks, and the rival workshop has entered. The winner takes %s.", [Ui.coins(prize)]),
		"text": Ui.say("The floor contest: the finest new floor wins %s.", [Ui.coins(prize)])}


## Swaps any stone or border the player can't use yet for the nearest one they can, so a copy can always be made.
static func _only_unlocked(d: FloorDesign, state: Dictionary) -> FloorDesign:
	var near := func(id: String) -> String:
		if id in state["unlocked_stones"]:
			return id
		var best: String = state["unlocked_stones"][0]
		for st in state["unlocked_stones"]:
			if Stones.difference(id, st) < Stones.difference(id, best):
				best = st
		return best
	d.ground = near.call(d.ground)
	if not str(d.border.get("id", "")) in state["unlocked_borders"]:
		d.set_border(state["unlocked_borders"][0] if not (state["unlocked_borders"] as Array).is_empty() else "")
	d.border["stones"] = (d.border.get("stones", []) as Array).map(near)
	d.placements = d.placements.filter(func(p: Dictionary) -> bool: return p["motif"] in state["unlocked_motifs"])
	for p in d.placements:
		var stones := {}
		for k in MotifLibrary.roles_of(p["motif"]):
			stones[str(k)] = near.call(str(p["stones"].get(str(k), Data.motif(p["motif"])["stones"].get(str(k), "black_stone"))))
		p["stones"] = stones
		if str(p.get("outline", "")) != "":
			p["outline"] = near.call(p["outline"])
		p["fine"] = bool(p.get("fine", false)) and int(state["chapter"]) >= 3
	return d


## An old floor found under the town. The client supplies the stone for repairs, so there is always something affordable to do.
static func restoration(state: Dictionary, rng: RandomNumberGenerator, small: bool = false) -> Dictionary:
	var chapter := int(state["chapter"])
	var rooms := Data.job_rooms(false).filter(func(r) -> bool: return int(Data.room(r).get("tier", 1)) <= chapter and r != "forum")
	if small:
		rooms.sort_custom(func(a, b) -> bool: return _area(a) < _area(b))
		rooms = rooms.slice(0, 2)
	var room: String = rooms[rng.randi() % rooms.size()]
	var age_tier := clampi(chapter + (1 if rng.randf() < 0.3 else 0), 1, 4)
	var design := RandomDesign.make(room, age_tier, rng)
	var found := _hide_a_pattern(design, state, rng)
	var finders: Array = Data.people.get("finders", [])
	if finders.is_empty():
		finders = [{"id": "finder", "who": "Workmen", "woman": false}]
	var finder: Dictionary = finders[rng.randi() % finders.size()]
	var who: String = finder["who"]
	var budget := int(_area(room) * (Data.num("budget.per_tile", 0.038) + Data.num("budget.per_tile_per_chapter", 0.012) * chapter) * 0.9 * rng.randf_range(0.9, 1.1))
	return {"kind": "restoration", "client": "", "client_name": who, "trade": "", "portrait": Data.face(finder), "woman": finder["woman"],
		"room": room, "brief": {}, "budget": budget, "arc_step": -1, "design": design.to_dict(), "severity": rng.randf_range(0.18, 0.28 + 0.05 * chapter),
		"line": [Ui.say("%s found an old floor under the dirt. Can you bring it back?", [who]), "Part of it looks like no pattern anyone in town has seen in years." if found != "" else ""],
		"greeting": "", "discovery": found, "text": Ui.say("%s found an old floor. Clean it and mend it.", [who])}


## Puts an unowned pattern from up to a chapter ahead at the heart of an old floor; restoring it adds it to the book.
static func _hide_a_pattern(design: FloorDesign, state: Dictionary, rng: RandomNumberGenerator) -> String:
	var ahead := int(state["chapter"]) + 1
	var unknown := Data.motif_order.filter(func(id: String) -> bool:
		var m := Data.motif(id)
		return not id in state["unlocked_motifs"] and int(m.get("tier", 1)) <= ahead and m.get("kind", "") != "letters" and not "frame" in m.get("tags", []))
	var heart := -1
	for i in design.placements.size():
		if "frame" in Data.motif(design.placements[i]["motif"]).get("tags", []):
			continue
		if heart < 0 or float(design.placements[i]["size"]) > float(design.placements[heart]["size"]):
			heart = i
	if unknown.is_empty() or heart < 0:
		return ""
	var pick: String = unknown[rng.randi() % unknown.size()]
	var old_id: String = design.placements[heart]["motif"]
	for p in design.placements:
		if p["motif"] == old_id:
			p["motif"] = pick
			p["stones"] = (Data.motif(pick)["stones"] as Dictionary).duplicate()
			p["outline"] = Data.motif(pick).get("outline", "")
	return pick


## Whether the player could meet a brief or story step with what they have unlocked.
static func possible(brief: Dictionary, state: Dictionary) -> bool:
	for m in brief.get("must", []):
		if not m in state["unlocked_motifs"]:
			return false
	for t in brief.get("tags", []):
		if not tag_open(t, state):
			return false
	for s in brief.get("want_stones", []):
		if not s in state["unlocked_stones"]:
			return false
	return true


static func tag_open(tag: String, state: Dictionary) -> bool:
	for id in state["unlocked_motifs"]:
		if tag in Data.motif(id).get("tags", []):
			return true
	return false


## "he", "him" and "his", or "she", "her" and "her", for the person a job shows: as the job says, or by their portrait.
static func pronouns(job: Dictionary) -> Dictionary:
	var woman := bool(job["woman"]) if job.has("woman") else is_woman(str(job.get("portrait", "")))
	if woman:
		return {"he": "she", "him": "her", "his": "her"}
	return {"he": "he", "him": "him", "his": "his"}


## Whether a portrait shows a woman: a regular client's, or anyone in town's.
static func is_woman(portrait: String) -> bool:
	if portrait in WOMEN:
		return true
	for group in ["townsfolk", "collectors", "finders"]:
		for p in Data.people.get(group, []):
			if str(p.get("portrait", p["id"])) == portrait:
				return bool(p["woman"])
	return bool(Data.people.get("neighbour", {}).get("woman", false)) and portrait == "neighbour"


## One of the townsfolk not already on today's board, each with their own name, trade and face.
static func person(rng: RandomNumberGenerator, used: Dictionary = {}) -> Dictionary:
	var everyone: Array = Data.people.get("townsfolk", [])
	var free := everyone.filter(func(p: Dictionary) -> bool: return not used.has(p["id"]))
	if free.is_empty():
		free = everyone
	return free[rng.randi() % free.size()]


static func _area(room_id: String) -> float:
	var r := Data.room(room_id)
	return float(int(r.get("w", 40)) * int(r.get("h", 30)))
