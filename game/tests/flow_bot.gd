extends Node
## Plays one whole job through the real screens and saves a screenshot at each step: --flow=OUTPUT_FOLDER


var out := ""
var problems := 0


func _ready() -> void:
	out = Dev.get_arg("flow", "user://flow")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	Saves.enabled = false
	Game.new_game("Flow bot")
	Game.state["story_seen"].append("intro")
	await _go("workshop", {}, "1_workshop")
	await _go("job_board", {}, "2_job_board")
	Story.morning(Game.state)
	var job: Dictionary = (Game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return j["kind"] == "commission")[0]
	await _go("client_visit", {"job": job}, "3_client_visit")
	job = (job as Dictionary).duplicate(true)
	job["asked"] = job["budget"]
	job["expected"] = 0.5
	Game.state["active_job"] = job
	var design := FloorDesign.for_room(job["room"])
	design.set_border("key" if job["brief"].get("border", false) else "plain")
	var tags: Array = job["brief"].get("tags", [])
	var musts: Array = job["brief"].get("must", [])
	for id in Data.motif_order:
		var m := Data.motif(id)
		var wanted: bool = id in musts
		for t in tags:
			wanted = wanted or t in m.get("tags", [])
		if wanted and Game.has_motif(id) and design.placements.size() < 3:
			design.add(id, design.w * (0.3 + 0.2 * design.placements.size()), design.h * 0.5, minf(design.w, design.h) * 0.3)
	# Like the design table, every motif is laid in the nearest stone the workshop has.
	for p in design.placements:
		for k in p["stones"]:
			p["stones"][k] = Stones.nearest(p["stones"][k], Game.state["unlocked_stones"])
		if str(p.get("outline", "")) != "":
			p["outline"] = Stones.nearest(p["outline"], Game.state["unlocked_stones"])
	for s in job["brief"].get("want_stones", []):
		if not design.placements.is_empty():
			design.placements[0]["stones"]["1"] = s
	job["design"] = design.to_dict()
	await _go("design_table", {"job": job}, "4_design_table")
	_check_corner_drag(Nav.current)
	_check_undo(Nav.current)
	var coins_before := Game.coins()
	await _go("floor", {"design": design, "job": job}, "5_floor_chalk", 3.0)
	var screen: Node = Nav.current
	screen.floor_view.lay_rest(1.0)
	await _wait(2.4)
	await _shot("6_floor_laid")
	screen.floor_view._finish_channel(0)
	await _wait(0.6)
	await _shot("7_floor_grouted")
	screen.floor_view._finish_channel(1)
	await _wait(5.5)
	if Nav.current_name != "reveal":
		_problem("the finished floor did not open the reveal (on %s)" % Nav.current_name)
		Audio.quit(1)
		return
	await _wait(3.0)
	await _shot("8_reveal")
	Nav.current._finish()
	await _wait(1.5)
	await _shot("9_workshop_after")
	if (Game.state["floors"] as Array).size() != 1:
		_problem("the floor was not recorded")
	if Game.coins() <= coins_before:
		_problem("the client did not pay: %d before, %d after" % [coins_before, Game.coins()])
	print("flow: %d d before laying, %d d after, reputation %d, %d problems" % [coins_before, Game.coins(), int(Game.state["reputation"]), problems])
	Audio.quit(1 if problems else 0)


func _go(screen: String, args: Dictionary, shot_name: String, settle: float = 1.2) -> void:
	Nav.go(screen, args)
	await _wait(settle)
	await _shot(shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))


func _problem(what: String) -> void:
	problems += 1
	print("PROBLEM: " + what)


## Dragging a corner handle grows the motif while the opposite corner stays where it was.
func _check_corner_drag(table: Node) -> void:
	if table.design.placements.is_empty():
		return
	table._select(0)
	var before: Rect2 = table._rect_of(table.design.placements[0])
	table._on_handle(2)
	table._on_handle_drag(before.end + Vector2(4, 4))
	var after: Rect2 = table._rect_of(table.design.placements[0])
	if after.size.x <= before.size.x or after.position.distance_to(before.position) > 0.6:
		_problem("dragging a corner did not resize from the opposite corner: %s to %s" % [before, after])
	table._on_handle(0)
	table._on_handle_drag(after.end - Vector2(2.5, 2.5))
	var small: Rect2 = table._rect_of(table.design.placements[0])
	var least := float(Data.motif(table.design.placements[0]["motif"]).get("min", 3))
	if maxf(small.size.x, small.size.y) > least + 0.5:
		_problem("a motif could not be shrunk to its smallest, %d tiles: %s" % [least, small])
	table._select(-1)


## Undo takes back the last change and redo puts it back.
func _check_undo(table: Node) -> void:
	var before: int = table.design.placements.size()
	table._add_motif("star", Vector2(table.design.w, table.design.h) * 0.5)
	table._undo_step()
	if table.design.placements.size() != before:
		_problem("undo did not take back an added motif")
	table._redo_step()
	if table.design.placements.size() != before + 1:
		_problem("redo did not put the motif back")
	table._undo_step()
