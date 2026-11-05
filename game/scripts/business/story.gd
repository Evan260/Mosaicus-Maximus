class_name Story
## How the workshop moves on: a finished job's money and reputation, clients' stories, new chapters, and each new day.


static func jobs_allowed(state: Dictionary) -> int:
	return 1 + (1 if int(state["apprentices"]) > 0 else 0)


static func jobs_left(state: Dictionary) -> int:
	return maxi(0, jobs_allowed(state) - int(state["jobs_today"]))


## Pins up the morning's notices, once a day, and sometimes brings a ship into the harbour or the dog finds a dig.
static func morning(state: Dictionary) -> void:
	if int(state["board_day"]) != int(state["day"]):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(state["seed"]), int(state["day"]), 1])
		state["board"] = JobFactory.board(state, rng)
		state["board_day"] = state["day"]
		var f := festival(state)
		var tag := festival_tag(state, f) if not f.is_empty() else ""
		if tag != "":
			state["pending_events"].append({"kind": "festival", "title": "The %s" % f["name"],
				"text": "%s Floors that show %s pay more today, and the finest wins the festival prize of %s." % [f["text"], Brief.TAG_WORDS.get(tag, tag), Ui.coins_text(festival_prize(state))]})
		_ship(state, rng)
		_dog_dig(state, rng)


## The festival held today, or nothing: one every few days, each in turn.
static func festival(state: Dictionary) -> Dictionary:
	var every := int(Data.num("festival.every", 10))
	var day := int(state["day"])
	if Data.festivals.is_empty() or day % every != int(Data.num("festival.on", 5)) % every:
		return {}
	return Data.festivals[(day / every) % Data.festivals.size()]


## What a festival's floors should show: its first theme the player has a pattern for, or nothing.
static func festival_tag(state: Dictionary, f: Dictionary) -> String:
	for t in f.get("tags", []):
		if JobFactory.tag_open(t, state):
			return t
	return ""


static func festival_prize(state: Dictionary) -> int:
	return int(Data.num("festival.prize", 60) + Data.num("festival.prize_per_chapter", 30) * int(state["chapter"]))


## Some mornings the dog digs a hole next door and finds an old floor, which goes up on the board.
static func _dog_dig(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var day := int(state["day"])
	if day < 3 or day - int(state.get("dog_dig_day", -99)) < int(Data.num("dog.dig_gap", 4)) or rng.randf() > Data.num("dog.dig_chance", 0.2):
		return
	var dog := str((state.get("dog", {}) as Dictionary).get("name", "The dog"))
	var job := JobFactory.restoration(state, rng, true)
	var neighbour: Dictionary = Data.people.get("neighbour", {})
	job.merge({"id": "%d_dog" % day, "client_name": "Your neighbour", "dog": true, "portrait": Data.face(neighbour), "woman": bool(neighbour.get("woman", true)),
		"line": "%s dug a hole in the yard next door, and at the bottom of it is an old floor. Your neighbour would like it brought back." % dog,
		"text": "%s found an old floor next door." % dog}, true)
	state["board"].append(job)
	state["dog_dig_day"] = day
	var stats: Dictionary = state.get("stats", {})
	stats["dog_digs"] = int(stats.get("dog_digs", 0)) + 1
	state["stats"] = stats
	state["pending_events"].append({"kind": "dog", "title": "%s found something" % dog,
		"text": "%s came home covered in dirt. Next door, at the bottom of a fresh hole, is the corner of an old mosaic floor. It's on the job board." % dog})


## A merchant ship with a stone the town can't usually get, one chapter ahead, sold today only.
static func _ship(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var day := int(state["day"])
	if day < 3 or day - int(state.get("ship", {}).get("day", -9)) < 3 or rng.randf() > Data.num("ship.chance", 0.3):
		return
	var cargo := Stones.LIST.filter(func(st: Dictionary) -> bool: return int(st["tier"]) <= int(state["chapter"]) + 1 and not st["id"] in state["unlocked_stones"])
	if cargo.is_empty():
		return
	var stone: Dictionary = cargo[rng.randi() % cargo.size()]
	var ports := ["Alexandria", "Carthage", "Athens", "Antioch", "Massilia"]
	var port: String = ports[rng.randi() % ports.size()]
	state["ship"] = {"day": day, "stone": stone["id"], "port": port}
	state["pending_events"].append({"kind": "ship", "title": "A ship in the harbour",
		"text": "A ship from %s has come in with %s. The stone merchant has it today only; buy a sack and it's yours to use from now on." % [port, str(stone["name"]).to_lower()]})


## The stone a ship brought today, or nothing.
static func ship_stone(state: Dictionary) -> String:
	var ship: Dictionary = state.get("ship", {})
	return str(ship.get("stone", "")) if int(ship.get("day", -1)) == int(state["day"]) else ""


## What the player knows of a job's client's taste: what townsfolk said, or what a named client showed before.
static func known_taste(state: Dictionary, job: Dictionary) -> Array:
	if bool(job.get("taste_said", false)):
		return job.get("taste", [])
	var id: String = job.get("client", "")
	if id != "" and bool(state["clients"].get(id, {}).get("taste_known", false)):
		return Data.client(id).get("taste", [])
	return []


## Records a finished job and returns what it set off: a client's story moving on, or a new chapter.
## result: {score, paid, reputation, tiles, design}
static func finish_job(state: Dictionary, job: Dictionary, result: Dictionary) -> Array:
	var events := []
	var score := float(result.get("score", 0.0))
	state["reputation"] = int(state["reputation"]) + int(result.get("reputation", 0))
	var stars := Looks.stars(score)
	state["floors"].append({"client": job.get("client", ""), "client_name": job.get("client_name", ""), "room": job.get("room", ""),
		"kind": job.get("kind", "commission"), "design": result.get("design", {}), "day": state["day"], "score": score, "paid": result.get("paid", 0),
		"stars": stars, "tiles": int(result.get("tiles", 0)), "portrait": job.get("portrait", ""), "woman": JobFactory.pronouns(job)["he"] == "she", "stones": result.get("stones", {})})
	var stats: Dictionary = state.get("stats", {})
	if stars >= 5:
		stats["five_stars"] = int(stats.get("five_stars", 0)) + 1
	if job.get("kind", "") == "restoration":
		stats["restorations"] = int(stats.get("restorations", 0)) + 1
	if bool(Data.room(job.get("room", "")).get("wall", false)):
		stats["walls"] = int(stats.get("walls", 0)) + 1
	if bool(result.get("won", false)):
		stats["contests_won"] = int(stats.get("contests_won", 0)) + 1
	if float(result.get("likeness", 0.0)) >= 0.95:
		stats["perfect_copies"] = int(stats.get("perfect_copies", 0)) + 1
	stats["biggest"] = maxi(int(stats.get("biggest", 0)), int(result.get("tiles", 0)))
	state["stats"] = stats
	var f := festival(state)
	if not f.is_empty() and str(job.get("festival", "")) == str(f["id"]) and stars >= int(Data.num("festival.stars", 4)) and int(state.get("festival_won", -1)) != int(state["day"]):
		var prize := festival_prize(state)
		state["festival_won"] = state["day"]
		state["coins"] = int(state["coins"]) + prize
		stats["earned"] = int(stats.get("earned", 0)) + prize
		state["reputation"] = int(state["reputation"]) + int(Data.num("festival.reputation", 4))
		var won: Array = stats.get("festivals", [])
		if not f["id"] in won:
			won.append(f["id"])
		stats["festivals"] = won
		events.append({"kind": "festival", "title": "The %s prize" % f["name"],
			"text": "The judges of the %s walked the town all day, and they chose your floor. The prize of %s is yours." % [f["name"], Ui.coins_text(prize)]})
	var found: String = job.get("discovery", "")
	if found != "" and not found in state["unlocked_motifs"]:
		state["unlocked_motifs"].append(found)
	var id: String = job.get("client", "")
	if id != "":
		var progress: Dictionary = state["clients"].get(id, {"step": 0})
		progress["taste_known"] = true
		progress["floors"] = int(progress.get("floors", 0)) + 1
		var c := Data.client(id)
		if score >= 0.5 and int(job.get("arc_step", -1)) == int(progress.get("step", 0)):
			var beat: Dictionary = c["arc"][progress["step"]]
			events.append({"kind": "arc", "client": id, "text": beat.get("after", "")})
			progress["step"] = int(progress["step"]) + 1
		elif score < Data.num("reputation.unhappy_below", 0.45):
			progress["away_until"] = int(state["day"]) + 5
			state["rival"]["stolen"] = int(state["rival"].get("stolen", 0)) + 1
			events.append({"kind": "unhappy", "client": id, "text": "%s will try the rival workshop for a while." % c.get("name", id)})
		state["clients"][id] = progress
	state["jobs_today"] = int(state["jobs_today"]) + 1
	state["active_job"] = {}
	state["board"] = (state["board"] as Array).filter(func(j: Dictionary) -> bool: return j.get("id", "") != job.get("id", ""))
	events += check_chapters(state)
	return events


static func check_chapters(state: Dictionary) -> Array:
	var events := []
	for ch in Data.chapters:
		var n := int(ch["n"])
		if n > int(state["chapter"]) and int(state["reputation"]) >= int(ch["reputation"]):
			unlock(state, n)
			events.append({"kind": "chapter", "n": n, "title": ch["title"], "text": ch["text"]})
	return events


## What opening chapter n adds to the workshop, one line for each kind of thing.
static func chapter_unlocks(n: int) -> Array:
	var lines := []
	var stones := Stones.LIST.filter(func(s: Dictionary) -> bool: return int(s["tier"]) == n).map(func(s: Dictionary) -> String: return str(s["name"]).to_lower())
	if not stones.is_empty():
		lines.append("Stone: " + _list(stones))
	var motifs := Data.motif_order.filter(func(id: String) -> bool: return int(Data.motif(id).get("tier", 1)) == n)
	if not motifs.is_empty():
		lines.append("Patterns: " + _list(motifs.map(func(id: String) -> String: return Data.motif_name(id))))
	var borders := Data.border_order.filter(func(id: String) -> bool: return int(Data.borders[id].get("tier", 1)) == n)
	if not borders.is_empty():
		lines.append("Borders: " + _list(borders.map(func(id: String) -> String: return str(Data.borders[id].get("name", id)).to_lower())))
	if n == 3:
		lines.append("Small tiles, half the size, for faces and fine detail")
	var rooms := Data.job_rooms().filter(func(id: String) -> bool: return int(Data.room(id).get("tier", 1)) == n)
	if not rooms.is_empty():
		lines.append("Rooms: " + _list(rooms.map(func(id: String) -> String: return str(Data.room(id).get("name", id)).to_lower())))
	var clients := Data.client_order.filter(func(id: String) -> bool: return int(Data.client(id).get("chapter", 1)) == n)
	if not clients.is_empty():
		lines.append("Clients: " + _list(clients.map(func(id: String) -> String: return str(Data.client(id)["name"]))))
	var upgrades := Data.upgrade_order.filter(func(id: String) -> bool: return int(Data.upgrades[id].get("chapter", 1)) == n)
	if not upgrades.is_empty() and n > 1:
		lines.append("To buy: " + _list(upgrades.map(func(id: String) -> String: return str(Data.upgrades[id]["name"]).to_lower())))
	return lines


## How far off the next chapter is, counting `extra` reputation not yet added to the save. Empty after the last chapter.
static func next_chapter_line(state: Dictionary, extra: int = 0, brief: bool = false) -> String:
	var next := Data.chapter(int(state["chapter"]) + 1)
	if next.is_empty():
		return ""
	var n := int(next["n"])
	var short := int(next["reputation"]) - int(state["reputation"]) - extra
	if short <= 0:
		return "Enough for chapter %d!" % n if brief else "Enough reputation for chapter %d: %s!" % [n, next["title"]]
	return "%d more reputation for chapter %d" % [short, n] if brief else "%d more reputation opens chapter %d: %s" % [short, n, next["title"]]


static func _list(names: Array, most: int = 5) -> String:
	if names.size() > most:
		return ", ".join(names.slice(0, most - 1)) + " and %d more" % (names.size() - most + 1)
	if names.size() == 1:
		return str(names[0])
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


## Opens a chapter: its stones, motifs and borders join the workshop, each only once.
static func unlock(state: Dictionary, n: int) -> void:
	state["chapter"] = maxi(int(state["chapter"]), n)
	for s in Stones.LIST:
		if int(s["tier"]) <= n and not s["id"] in state["unlocked_stones"]:
			state["unlocked_stones"].append(s["id"])
	for id in Data.motif_order:
		if int(Data.motif(id).get("tier", 1)) <= n and not id in state["unlocked_motifs"]:
			state["unlocked_motifs"].append(id)
	for id in Data.border_order:
		if int(Data.borders[id].get("tier", 1)) <= n and not id in state["unlocked_borders"]:
			state["unlocked_borders"].append(id)


## What a collector pays for a picture panel: more for more stars, and more as the workshop's name grows.
static func panel_value(state: Dictionary, stars: int) -> int:
	var base := Data.num("panel.value", 30) + Data.num("panel.value_per_chapter", 20) * int(state["chapter"])
	return int(base * (0.4 + 0.16 * stars))


## Keeps a finished picture panel in the workshop: its biggest picture, with its stones, is what a floor shows of it.
static func finish_panel(state: Dictionary, job: Dictionary, result: Dictionary) -> Dictionary:
	var d := FloorDesign.from_dict(result.get("design", {}))
	var main := {}
	for p in d.placements:
		var picture: bool = Data.motif(p["motif"]).get("kind", "") == "picture"
		if main.is_empty() or (picture and Data.motif(main["motif"]).get("kind", "") != "picture") or (picture == (Data.motif(main["motif"]).get("kind", "") == "picture") and float(p["size"]) > float(main["size"])):
			main = p
	var stars := Looks.stars(float(result.get("score", 0.0)))
	var panel := {"id": "panel_%d_%d" % [int(state["day"]), (state.get("panels", []) as Array).size()], "motif": main.get("motif", "rosette"),
		"stones": main.get("stones", {}), "outline": main.get("outline", ""), "fine": bool(main.get("fine", false)), "size": float(main.get("size", 14)),
		"stars": stars, "score": float(result.get("score", 0.0)), "day": state["day"], "design": result.get("design", {})}
	var panels: Array = state.get("panels", [])
	panels.append(panel)
	state["panels"] = panels
	state["panel_day"] = state["day"]
	state["active_job"] = {}
	var stats: Dictionary = state.get("stats", {})
	stats["panels_made"] = int(stats.get("panels_made", 0)) + 1
	state["stats"] = stats
	return panel


## Whether the bench is free for a picture panel today: one a day, and not while a job is on the table.
static func can_make_panel(state: Dictionary) -> bool:
	return int(state.get("panel_day", -1)) != int(state["day"]) and (state["active_job"] as Dictionary).is_empty()


## A client turned away, or one who refused the price, goes to the rival for a few days.
static func refuse(state: Dictionary, job: Dictionary) -> void:
	state["refusals"] = int(state["refusals"]) + 1
	state["rival"]["reputation"] = float(state["rival"].get("reputation", 0)) + 0.5
	var id: String = job.get("client", "")
	if id != "":
		var progress: Dictionary = state["clients"].get(id, {"step": 0})
		progress["away_until"] = int(state["day"]) + 3
		state["clients"][id] = progress
	state["board"] = (state["board"] as Array).filter(func(j: Dictionary) -> bool: return j.get("id", "") != job.get("id", ""))


## Closes the day: pays the apprentices, lets the rival grow, and returns the day's tally for the wax tablet.
static func end_day(state: Dictionary) -> Dictionary:
	var day := int(state["day"])
	var wages := int(state["apprentices"]) * int(Data.num("wage", 6))
	var paid := mini(wages, int(state["coins"]))
	state["coins"] = int(state["coins"]) - paid
	if paid > 0:
		state["ledger"].append({"day": day, "what": "Apprentices' wages", "amount": -paid})
	state["rival"]["reputation"] = float(state["rival"].get("reputation", 0)) + Data.num("rival.reputation_per_day", 0.6)
	var earned := 0
	var spent := 0
	for e in state["ledger"]:
		if int(e["day"]) == day:
			if int(e["amount"]) > 0:
				earned += int(e["amount"])
			else:
				spent -= int(e["amount"])
	var gossip: Array = Data.names.get("gossip", [""])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(state["seed"]), day, 7])
	state["day"] = day + 1
	state["jobs_today"] = 0
	state["hour"] = Data.num("time.start", 8.0)
	return {"day": day, "earned": earned, "spent": spent, "wages": paid, "coins": state["coins"], "reputation": state["reputation"],
		"gossip": gossip[rng.randi() % gossip.size()] if not gossip.is_empty() else ""}
