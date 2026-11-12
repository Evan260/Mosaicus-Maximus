extends "res://tests/test_case.gd"
## Going from screen to screen and opening and closing windows, again and again, leaves nothing behind.

const ROUTE := ["title", "workshop", "job_board", "design_table", "floor", "reveal", "town_map", "library", "workshop"]


func test_screens_and_windows_leave_nothing_behind() -> void:
	# A track starting between the counts would add its playback to them.
	Audio.music_on = false
	Audio._music.stop()
	Game.new_game("Memory")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	# The title lays a different random floor each time, so every motif's picture is loaded into its cache first.
	for id in Data.motif_order:
		MotifLibrary.source(id)
	# The first two rounds fill the caches every later round reuses: fonts, pictures and the book's paper.
	for k in 2:
		await _round()
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for k in 3:
		await _round()
	var now := Performance.get_monitor(Performance.OBJECT_COUNT)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) <= nodes, "three more rounds of screens leave no extra nodes (%d before, %d after)" % [nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "and no nodes outside the tree (%d before, %d after)" % [orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) <= resources, "and no extra resources (%d before, %d after)" % [resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	check(now <= objects, "and no extra objects (%d before, %d after)" % [objects, now])
	Audio.music_on = true
	Nav.go("title")
	await _settle()


## Every screen once, with the workshop's windows opened and closed on the way, then time for sounds and fades to end.
func _round() -> void:
	for s in ROUTE:
		Nav.go(s, {"free": true} if s == "design_table" else {})
		await _settle()
		if s == "floor":
			while Nav.current.floor_view == null:
				await get_tree().process_frame
			Nav.current.floor_view.lay_rest(0.2)
			await get_tree().create_timer(0.8).timeout
		if s == "workshop":
			for open in [func() -> Control: return SettingsPanel.open(Nav.current._root, true),
					func() -> Control: return DogPanel.open(Nav.current._root),
					func() -> Control: return ChaptersPanel.open(Nav.current._root)]:
				Nav.current._show_panel(open.call())
				await get_tree().process_frame
				Nav.close_top()
				await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout


## Waits for the screen to finish fading in and for whatever it freed to go.
func _settle() -> void:
	await get_tree().process_frame
	while Nav._busy:
		await get_tree().process_frame
	for k in 3:
		await get_tree().process_frame


func test_turning_pages_leaves_nothing_behind() -> void:
	Audio.music_on = false
	Audio._music.stop()
	Game.new_game("Memory")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	var motion := Settings.reduced_motion
	Settings.reduced_motion = false
	Nav.go("workshop")
	await _settle()
	var book := _open_book()
	# The first two rounds fill the caches every later round reuses: fonts, pictures and the book's paper.
	for k in 2:
		book = await _turns(book)
	# The page and click sounds still playing would add their playbacks to the counts.
	await get_tree().create_timer(1.5).timeout
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for k in 2:
		book = await _turns(book)
	await get_tree().create_timer(1.5).timeout
	check(Nav.ui.find_children("*", "SubViewport", true, false).is_empty(), "every page's picture is freed once its leaf lands or is cut short")
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) <= nodes, "turning more pages leaves no extra nodes (%d before, %d after)" % [nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "and no nodes outside the tree (%d before, %d after)" % [orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) <= resources, "and no extra resources (%d before, %d after)" % [resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_COUNT) <= objects, "and no extra objects (%d before, %d after)" % [objects, Performance.get_monitor(Performance.OBJECT_COUNT)])
	Nav.close_top()
	Settings.reduced_motion = motion
	Audio.music_on = true
	Nav.go("title")
	await _settle()


func _open_book() -> ChaptersPanel:
	var book := ChaptersPanel.open(Nav.current._root)
	Nav.current._show_panel(book)
	return book


## Three chapters turned to and back, then two turns cut short by closing the book, one before its new page is
## pictured. Returns the book opened again after them.
func _turns(book: ChaptersPanel) -> ChaptersPanel:
	for n in [2, 3, 1]:
		book.turn_to(n)
		await _landed(book)
	for wait in [0, 3]:
		book.turn_to(2)
		for i in wait:
			await get_tree().process_frame
		Nav.close_top()
		await _settle()
		book = _open_book()
		await get_tree().process_frame
	return book


func _landed(book: ChaptersPanel) -> void:
	while book._turning:
		await get_tree().process_frame
	await _settle()
