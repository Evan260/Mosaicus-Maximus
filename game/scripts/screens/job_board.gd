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
	Ui.label(head, "Notices for day %d" % int(Game.state["day"]) + ("" if fest.is_empty() else ": the %s" % fest["name"]), "LightHeading")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var left := Story.jobs_left(Game.state)
	var busy: Dictionary = Game.state["active_job"]
	if not busy.is_empty():
		_closed(col, "A floor is waiting", ("Your picture panel is still on the bench. Finish it, or give it up at the workbench, before taking a job." if busy.get("kind", "") == "panel" else "%s's floor is still on your table. Finish it before taking another job." % busy.get("client_name", "The last client")),
			"Carry on with it", func() -> void: Nav.go("floor" if busy.get("kind", "") == "restoration" else "design_table", {"job": busy}), "brush")
	elif left <= 0:
		var why := "You can take one job a day." if int(Game.state["apprentices"]) == 0 else "You and your apprentices have taken every job you can manage today."
		if int(Game.state["apprentices"]) == 0:
			why += " An apprentice, from the workbench, lets you take two."
		_closed(col, "That's today's work done", why + " New notices go up in the morning.", "End the day", func() -> void: Nav.go("day_end"), "sun")
	else:
		Ui.label(head, "You can take %d more today" % left, "LightLabel")
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		var board: Array = Game.state["board"]
		if board.is_empty():
			Ui.label(col, "The board is bare. Come back tomorrow.", "LightLabel")
		for job in board:
			grid.add_child(_notice(job))
		Guide.note("board", "These are today's notices: each is someone who wants a new floor, with what they wish for and about what they'll pay. Pick one and click See him or See her.", "right")
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
	Ui.label(who, str(job.get("client_name", "")), "", 98).add_theme_font_size_override("font_size", 10)
	var room := Data.room(job.get("room", ""))
	Ui.label(who, "%s, %d by %d" % [room.get("name", ""), int(room.get("w", 0)), int(room.get("h", 0))], "MutedLabel")
	var kind := str(job.get("kind", "commission"))
	if bool(job.get("dog", false)):
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "paw")
		Ui.label(r, "Found by %s" % str((Game.state.get("dog", {}) as Dictionary).get("name", "your dog")), "", 110)
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
			Ui.label(col, "and %d more wish%s" % [wishes.size() - 2, "" if wishes.size() == 3 else "es"], "MutedLabel")
	var pay := Ui.hbox(col, 2)
	Ui.icon(pay, "coin")
	Ui.label(pay, ("Prize %s" if kind == "contest" else "About %s") % Ui.coins_text(int(job.get("budget", 0))))
	Ui.button(col, "See " + JobFactory.pronouns(job)["him"], func() -> void: Nav.go("client_visit", {"job": job}), "", true)
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
	Ui.label(col, "Your notebook", "Heading")
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
		Ui.label(text, str(c["name"]))
		var taste: Array = c.get("taste", [])
		Ui.label(text, ("Taste: " + " and ".join(taste.map(func(t: String) -> String: return Looks.TASTES[t]["text"]))) if bool(progress.get("taste_known", false)) else "Taste: not known yet", "MutedLabel", 250)
		var arc: Array = c.get("arc", [])
		Ui.label(text, "Their story: %d of %d floors" % [mini(int(progress.get("step", 0)), arc.size()), arc.size()], "MutedLabel")
	if met == 0:
		Ui.label(list, "You haven't laid a floor for any of the town's regulars yet. Their names go here once you have.", "", 280)
	Ui.button(col, "Close", func() -> void:
		_book.queue_free()
		_book = null, "tick").size_flags_horizontal = Control.SIZE_SHRINK_END
	_book.reset_size()
	_book.position = ((Nav.ui_size() - _book.size) * 0.5).floor()
