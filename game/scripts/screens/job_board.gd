extends Node
## The job board: this morning's notices pinned to the wood. Picking one brings the client in.

var _root: PanelContainer
var _book: PanelContainer


func enter(_args: Dictionary) -> void:
	if Dev.has("day"):
		Game.state["day"] = int(Dev.num("day", 1))
	Story.morning(Game.state)
	_root = Ui.panel(Nav.ui, "BoardPanel")
	var col := Ui.vbox(_root, 5)
	var head := Ui.hbox(col, 6)
	var fest := Story.festival(Game.state)
	Ui.label(head, tr("Notices for day %d") % int(Game.state["day"]) if fest.is_empty() else tr("Notices for day %d: the %s") % [int(Game.state["day"]), tr(fest["name"])], "LightHeading")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var left := Story.jobs_left(Game.state)
	var busy: Dictionary = Game.state["active_job"]
	if not busy.is_empty():
		_closed(col, "A floor is waiting", ("Your picture panel is still on the bench. Finish it, or give it up at the workbench, before taking a job." if busy.get("kind", "") == "panel" else tr("%s's floor is still on your table. Finish it before taking another job.") % Ui.text(busy.get("client_name", "The last client"))),
			"Carry on with it", func() -> void: Nav.go("floor" if busy.get("kind", "") == "restoration" else "design_table", {"job": busy}), "brush")
	elif left <= 0:
		var why := ["You can take one job a day.", "An apprentice, from the workbench, lets you take two."] if int(Game.state["apprentices"]) == 0 else ["You and your apprentice have taken every job you can manage today."]
		_closed(col, "That's today's work done", Ui.text(why + ["New notices go up in the morning."]), "End the day", func() -> void: Nav.go("day_end"), "sun")
	else:
		Ui.label(head, tr("You can take %d more today") % left, "LightLabel")
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.alignment = FlowContainer.ALIGNMENT_CENTER
		scroll.add_child(grid)
		var board: Array = Game.state["board"]
		if board.is_empty():
			Ui.label(col, "The board is bare. Come back tomorrow.", "LightLabel")
		for job in board:
			grid.add_child(_notice(job))
		Guide.note("board", "These are today's notices. Each one shows a client's wishes for a new floor and about what the job pays. Pick one and click See him or See her.", "bottom_left")
	var foot := Ui.hbox(col, 4)
	foot.alignment = BoxContainer.ALIGNMENT_END
	Ui.button(foot, "Notebook", _open_notebook, "book")
	Ui.button(foot, "Back to the workshop", func() -> void: Nav.go("workshop"), "arrow_l")
	var place := func() -> void:
		var s := Nav.ui_size()
		_root.position = Vector2(6, 6)
		_root.size = s - Vector2(12, 12)
	Nav.resized.connect(place)
	place.call()


## In place of the notices when no job can be taken: why, and the one thing to do next.
func _closed(parent: Node, title: String, text: String, action: String, go: Callable, icon_name: String) -> void:
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(room)
	var card := Ui.panel(room, "CardPanel")
	var col := Ui.vbox(card, 5)
	Ui.label(col, title, "Heading")
	Ui.label(col, text, "", 240)
	Ui.button(col, action, go, icon_name, true).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var centre := func() -> void:
		card.reset_size()
		card.position = ((room.size - card.size) * 0.5).floor()
	room.resized.connect(centre)
	centre.call_deferred()


func _notice(job: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(150, 0)
	var col := Ui.vbox(card, 2)
	var top := Ui.hbox(col, 4)
	var portrait := _portrait(job.get("portrait", ""), 32)
	top.add_child(portrait)
	var who := Ui.vbox(top, 0)
	Ui.label(who, Ui.text(job.get("client_name", "")), "", 98)
	var room := Data.room(job.get("room", ""))
	Ui.label(who, tr("%s, %d by %d") % [Data.room_title(job.get("room", "")), int(room.get("w", 0)), int(room.get("h", 0))], "MutedLabel", 98)
	var kind := str(job.get("kind", "commission"))
	if bool(job.get("dog", false)):
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "paw")
		var dog := str((Game.state.get("dog", {}) as Dictionary).get("name", ""))
		Ui.label(r, tr("Found by %s") % tr(dog) if dog != "" else tr("Found by your dog"), "", 110)
	if str(job.get("festival", "")) != "":
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "laurel")
		Ui.label(r, "For the festival: pays more today", "", 110)
	if kind == "restoration":
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "trowel")
		Ui.label(r, "Restoration: clean and mend", "", 110)
		if str(job.get("discovery", "")) != "":
			Ui.label(col, "• Hides a pattern you don't know", "", 140)
	elif kind == "copy":
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "eye")
		Ui.label(r, "Copy a famous floor, stone for stone", "", 110)
	elif kind == "contest":
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "laurel")
		Ui.label(r, "Judged on looks alone, against the rival", "", 110)
	else:
		var wishes := Brief.score(job.get("brief", {}), FloorDesign.new())["wishes"] as Array
		for w in wishes.slice(0, 2):
			Ui.label(col, "• " + str(w["text"]), "", 140)
		if wishes.size() > 2:
			Ui.label(col, tr("and 1 more wish") if wishes.size() == 3 else tr("and %d more wishes") % (wishes.size() - 2), "MutedLabel", 140)
	var pay := Ui.hbox(col, 2)
	Ui.icon(pay, "coin")
	Ui.label(pay, (tr("Prize %s") if kind == "contest" else tr("About %s")) % Ui.coins_text(int(job.get("budget", 0))))
	Ui.button(col, "See her" if JobFactory.pronouns(job)["he"] == "she" else "See him", func() -> void: Nav.go("client_visit", {"job": job}), "", true)
	return card


static func _portrait(name: String, size: int) -> Control:
	var path := "res://assets/art/portraits/%s.png" % name
	var frame := PanelContainer.new()
	frame.theme_type_variation = "SlotPanel"
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(path) if ResourceLoader.exists(path) else UiTheme.icon("person")
	frame.add_child(t)
	return frame


## Every named client met so far: their portrait, what you know of their taste, and how far their story has gone.
func _open_notebook() -> void:
	if _book:
		_book.queue_free()
	_book = Ui.panel(Nav.ui, "PagePanel")
	var col := Ui.vbox(_book, 4)
	Ui.window_head(col, _book, "Your notebook", _close_notebook)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := Ui.vbox(scroll, 4)
	var met := 0
	for id in Data.client_order:
		var progress: Dictionary = Game.state["clients"].get(id, {})
		if progress.is_empty():
			continue
		met += 1
		var c := Data.client(id)
		var row := Ui.hbox(list, 6)
		row.add_child(_portrait(c.get("portrait", ""), 28))
		var text := Ui.vbox(row, 0)
		Ui.label(text, tr(str(c["name"])))
		var taste: Array = c.get("taste", [])
		Ui.label(text, (tr("Taste: %s") % Looks.tastes_words(taste)) if bool(progress.get("taste_known", false)) else tr("Taste: not known yet"), "MutedLabel", 250)
		var arc: Array = c.get("arc", [])
		Ui.label(text, tr("Their story: %d of %d floors") % [mini(int(progress.get("step", 0)), arc.size()), arc.size()], "MutedLabel", 250)
	if met == 0:
		Ui.label(list, "You haven't laid a floor for any of the town's regulars yet. Their names go here once you have.", "", 280)
	_book.reset_size()
	_book.position = ((Nav.ui_size() - _book.size) * 0.5).floor()


func _close_notebook() -> void:
	if _book:
		_book.queue_free()
	_book = null


## Escape with nothing open goes back to the workshop.
func go_back() -> bool:
	Nav.go("workshop")
	return true
