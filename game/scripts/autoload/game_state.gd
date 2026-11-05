extends Node
## The workshop being played: money, reputation, stone in stock, what is unlocked, and every floor laid so far.

signal changed

const VERSION := 1

var state := {}


func _ready() -> void:
	state = defaults()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"name": "",
		"dog": {"breed": "hound", "coat": "golden", "name": "Rufus"},
		"day": 1,
		"hour": 8.0,
		"coins": int(Data.num("start.coins", 150)),
		"reputation": 0,
		"chapter": 1,
		"stock": (Data.value("start.stock", {}) as Dictionary).duplicate(),
		"unlocked_stones": _stones_of_tier(1),
		"unlocked_motifs": _motifs_of_tier(1),
		"unlocked_borders": _borders_of_tier(1),
		"apprentices": 0,
		"upgrades": [],
		"decorations": [],
		"floors": [],
		"gallery": [],
		"clients": {},
		"rival": {"reputation": 4.0, "stolen": 0},
		"refusals": 0,
		"board": [],
		"board_day": 0,
		"active_job": {},
		"jobs_today": 0,
		"seed": randi(),
		"story_seen": [],
		"pending_events": [],
		"achievements": [],
		"panels": [],
		"stats": {"earned": 0, "five_stars": 0, "restorations": 0, "contests_won": 0, "perfect_copies": 0, "biggest": 0, "ship_stones": 0, "pets": 0},
		"ledger": [],
		"played_seconds": 0.0,
	}


## The clock runs while a workshop is being played, from morning until the day is ended.
func _process(delta: float) -> void:
	if str(state.get("name", "")) == "" or Nav.current_name in ["", "title", "day_end", "library"]:
		return
	state["hour"] = minf(float(state.get("hour", 8.0)) + delta / Data.num("time.seconds_per_hour", 40.0), Data.num("time.latest", 23.5))


func new_game(workshop_name: String, dog: Dictionary = {}) -> void:
	state = defaults()
	state["name"] = workshop_name
	if not dog.is_empty():
		state["dog"] = dog.duplicate()
	changed.emit()


func to_dict() -> Dictionary:
	return state.duplicate(true)


## Loads a saved workshop. Anything the save lacks, such as a key added in a later version, takes its default.
func from_dict(d: Dictionary) -> void:
	var fresh := defaults()
	for k in d:
		fresh[k] = _whole(d[k])
	state = fresh
	changed.emit()


## JSON reads every number as a decimal, so whole numbers become whole again, keeping counts and money exact.
func _whole(v):
	if v is float and v == floorf(v) and absf(v) < 1.0e15:
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _whole(v[k])
		return out
	if v is Array:
		return v.map(_whole)
	return v


func coins() -> int:
	return int(state["coins"])


func earn(amount: int, what: String) -> void:
	state["coins"] = coins() + amount
	bump("earned", amount)
	_log(what, amount)
	changed.emit()


## Adds to one of the running counts in the save.
func bump(stat: String, by: int = 1) -> void:
	if not state.has("stats"):
		state["stats"] = defaults()["stats"]
	state["stats"][stat] = int(state["stats"].get(stat, 0)) + by


func spend(amount: int, what: String) -> bool:
	if amount > coins():
		return false
	state["coins"] = coins() - amount
	_log(what, -amount)
	changed.emit()
	return true


func stock(stone_id: String) -> int:
	return int(state["stock"].get(stone_id, 0))


func add_stock(stone_id: String, tiles: int) -> void:
	state["stock"][stone_id] = stock(stone_id) + tiles
	changed.emit()


## Takes the stone a floor needs from stock, buying whatever is short at the merchant's price. False if it can't be paid.
func take_stone(counts: Dictionary) -> bool:
	var cost := shortfall_cost(counts)
	if cost > coins():
		return false
	if cost > 0:
		spend(cost, "Stone for the floor")
	for id in counts:
		state["stock"][id] = maxi(0, stock(id) - int(counts[id]))
	changed.emit()
	return true


func shortfall_cost(counts: Dictionary) -> int:
	var cost := 0.0
	for id in counts:
		var short := maxi(0, int(counts[id]) - stock(id))
		cost += short * stone_price(id)
	return int(ceil(cost))


## A stone's price per tile after the workshop's upgrades.
func stone_price(id: String) -> float:
	var p := Data.stone_price(id)
	if "cutting_bench" in state["upgrades"]:
		p *= 0.9
	if "glass_furnace" in state["upgrades"] and Stones.LIST[Stones.index(id)]["material"] == Stones.Kind.GLASS:
		p *= 0.67
	return p


func has_stone(id: String) -> bool:
	return id in state["unlocked_stones"]


func has_motif(id: String) -> bool:
	return id in state["unlocked_motifs"]


func has_border(id: String) -> bool:
	return id in state["unlocked_borders"]


## A generator for anything that should come out the same when a day is replayed, such as that morning's notices.
func day_rng(salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(state["seed"]), int(state["day"]), salt])
	return r


func _log(what: String, amount: int) -> void:
	state["ledger"].append({"day": state["day"], "what": what, "amount": amount})
	if state["ledger"].size() > 300:
		state["ledger"] = state["ledger"].slice(-300)


func _stones_of_tier(t: int) -> Array:
	var out := []
	for s in Stones.LIST:
		if int(s["tier"]) <= t:
			out.append(s["id"])
	return out


func _motifs_of_tier(t: int) -> Array:
	var out := []
	for id in Data.motif_order:
		if int(Data.motif(id).get("tier", 1)) <= t:
			out.append(id)
	return out


func _borders_of_tier(t: int) -> Array:
	var out := []
	for id in Data.border_order:
		if int(Data.borders[id].get("tier", 1)) <= t:
			out.append(id)
	return out
