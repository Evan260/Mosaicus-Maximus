class_name Story
## How the workshop moves on: a finished job's money and reputation, clients' stories, new chapters, and each new day.


static func jobs_allowed(state: Dictionary) -> int:
	return 1 + (1 if int(state["apprentices"]) > 0 else 0)


static func jobs_left(state: Dictionary) -> int:
	return maxi(0, jobs_allowed(state) - int(state["jobs_today"]))


## Pins up the morning's notices, once a day, and sometimes brings a ship into the harbour.
static func morning(state: Dictionary) -> void:
	if int(state["board_day"]) != int(state["day"]):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(state["seed"]), int(state["day"]), 1])
		state["board"] = JobFactory.board(state, rng)
		state["board_day"] = state["day"]
		_ship(state, rng)


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
	state["floors"].append({"client": job.get("client", ""), "client_name": job.get("client_name", ""), "room": job.get("room", ""),
		"kind": job.get("kind", "commission"), "design": result.get("design", {}), "day": state["day"], "score": score, "paid": result.get("paid", 0)})
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
