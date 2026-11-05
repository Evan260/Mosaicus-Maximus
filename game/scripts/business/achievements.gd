class_name Achievements
## The workshop's achievements, from data/achievements.json: which are earned, judged from the save's stats and
## floors. Earned ones are kept in the save, and the Awards layer shows them and hands them to Steam.


static func all() -> Array:
	return Data.achievements


## Every achievement newly earned, added to the save in the order they were met.
static func check(state: Dictionary) -> Array:
	var have: Array = state.get("achievements", [])
	var fresh := []
	for a in all():
		if not a["id"] in have and met(a, state):
			have.append(a["id"])
			fresh.append(a)
	state["achievements"] = have
	return fresh


static func met(a: Dictionary, state: Dictionary) -> bool:
	var stats: Dictionary = state.get("stats", {})
	if a.has("floors"):
		return (state["floors"] as Array).size() >= int(a["floors"])
	if a.has("stat"):
		return float(stats.get(a["stat"], 0)) >= float(a["at"])
	if a.has("chapter"):
		return int(state["chapter"]) >= int(a["chapter"])
	if a.has("all_patterns"):
		return Data.motif_order.all(func(id: String) -> bool: return id in state["unlocked_motifs"])
	if a.has("stories"):
		var done := stories_done(state)
		return done >= (Data.client_order.size() if int(a["stories"]) < 0 else int(a["stories"]))
	if a.has("story"):
		return story_done(state, str(a["story"]))
	if a.has("tastes"):
		return Data.client_order.all(func(id: String) -> bool: return bool(state["clients"].get(id, {}).get("taste_known", false)))
	if a.has("library"):
		return Library.count() >= int(a["library"])
	if a.has("festivals"):
		var won := (stats.get("festivals", []) as Array).size()
		return won >= (Data.festivals.size() if int(a["festivals"]) < 0 else int(a["festivals"]))
	return false


static func story_done(state: Dictionary, id: String) -> bool:
	return int(state["clients"].get(id, {}).get("step", 0)) >= (Data.client(id).get("arc", []) as Array).size()


static func stories_done(state: Dictionary) -> int:
	return Data.client_order.filter(func(id: String) -> bool: return story_done(state, id)).size()
