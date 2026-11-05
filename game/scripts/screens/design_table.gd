extends Node
## The design table: the pattern book on the left, the floor plan in the middle, and the client's brief on the right.
## Opened with {job} for a commission, {free: true} for free design, or {design, job} to carry on with a design.
## Clicking any part of the plan picks it for colouring; a picked motif can be dragged, and resized by its corners.

const PART_NAMES := ["Band", "Pattern", "Second colour", "Trim"]
## How far the pointer moves, in interface pixels, before a press on the plan becomes a drag.
const DRAG_START := 3.0

var design: FloorDesign
var job := {}
var brief := {}
var free := false
var selected := -1
var role := ""
var tab := "patterns"

var _root: Control
var _desk: PanelContainer
var _book: PanelContainer
var _book_grid: GridContainer
var _tab_buttons := {}
var _plan_panel: PanelContainer
var _plan: PlanView
var _right: VBoxContainer
var _cost_panel: PanelContainer
var _brief_box: VBoxContainer
var _cost_label: Label
var _warn_label: Label
var _buy_button: Button
var _start: Button
var _bottom: PanelContainer
var _toolbar: PanelContainer
var _fine_button: Button
var _pair_button: Button
var _chips: HFlowContainer
var _palette: GridContainer
var _stone_buttons := {}
var _dirty := true
var _cost_dirty := true
var _since := 1.0
var _cost_since := 1.0
var _drag_offset := Vector2.INF
## The ground or border part under a press inside the picked motif's box: picked instead if the press doesn't drag.
var _ground_on_release := ""
var _moved := false
var _press_tile := Vector2.ZERO
var _anchor := Vector2.ZERO
var _grow := Vector2.ONE
var _counts := {}
## Laying out a big floor to count its stone exactly takes seconds, so it is counted on a worker thread while an estimate shows.
var _count_task := -1
var _count_box := {}
var _count_sig := ""
var _exact := {}
var _exact_sig := ""
var _tex: ImageTexture
var _chip_buttons := {}
var _target_tex: ImageTexture
var _parts := PackedByteArray()
var _parts_px := 1
var _hover_code := -1
## Designs as they were before each change, for undo, and the ones undone, for redo.
var _undo: Array = []
var _redo: Array = []
## The design as a drag began, kept only once the drag really changes something.
var _pending := {}
var _last_wheel := -10.0
var _undo_button: Button
var _redo_button: Button


func enter(args: Dictionary) -> void:
	job = args.get("job", {})
	if job.is_empty() and Dev.has("kind"):
		job = Dev.test_job(Dev.get_arg("kind"))
	brief = job.get("brief", {})
	free = bool(args.get("free", false)) or job.get("free", false)
	design = args.get("design", null)
	if design == null and job.has("design"):
		design = FloorDesign.from_dict(job["design"])
	if design == null:
		design = FloorDesign.for_room(job.get("room", Dev.get_arg("room", "study")))
	if Dev.has("sample") and design.placements.is_empty():
		design = Samples.make(Dev.get_arg("sample"))
	if not free:
		var kept := (Game.state.get("panels", []) as Array).map(func(p: Dictionary) -> String: return str(p["id"]))
		for p in design.placements:
			if str(p.get("panel", "")) != "" and not p["panel"] in kept:
				p.erase("panel")
	if Dev.has("tab"):
		tab = Dev.get_arg("tab")
		if Dev.has("panels"):
			Game.state["panels"] = [{"id": "p1", "motif": "dolphin", "stones": {}, "stars": 4, "size": 14}]
	_build()
	Nav.resized.connect(_layout_ui)
	_layout_ui()
	_fill_book()
	if Dev.has("panels"):
		_add_panel(Game.state["panels"][0])
	if Dev.has("add"):
		_add_motif(Dev.get_arg("add"), Vector2(design.w, design.h) * 0.5)
	if Dev.has("pick"):
		_select(int(Dev.num("pick", 0)))
	_refresh_chips()
	if not free and str(job.get("kind", "")) != "panel":
		Guide.note("design", "This is the design table. Drag patterns and pictures from the book onto the floor plan, and click any part to give it a stone. The stars show how much the client will like it. Then buy the stone and press Start laying.", "top")


func _process(delta: float) -> void:
	_since += delta
	_cost_since += delta
	if _dirty and _since > 0.07:
		_dirty = false
		_since = 0.0
		_recompose()
	if _cost_dirty and _cost_since > 0.35:
		_cost_dirty = false
		_cost_since = 0.0
		_recost()
	if _count_task >= 0 and WorkerThreadPool.is_task_completed(_count_task):
		_collect_count()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.ctrl_pressed and key.keycode == KEY_Z:
		if key.shift_pressed:
			_redo_step()
		else:
			_undo_step()
		return
	if key.ctrl_pressed and key.keycode == KEY_Y:
		_redo_step()
		return
	match key.keycode:
		KEY_R:
			_turn()
		KEY_F:
			_flip()
		KEY_M:
			_mirror()
		KEY_DELETE, KEY_BACKSPACE:
			_remove()
		KEY_EQUAL, KEY_KP_ADD:
			_resize(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_resize(-1)
		KEY_ESCAPE:
			_select(-1)


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(_root)
	_desk = Ui.panel(_root, "BoardPanel")
	_book = Ui.panel(_root, "PagePanel")
	var book_col := Ui.vbox(_book, 4)
	var head := Ui.hbox(book_col, 4)
	Ui.icon_button(head, "arrow_l", "Back to the title" if free else "Back to the workshop, keeping this design", _back).custom_minimum_size = Vector2(18, 18)
	var title := Ui.label(head, "Pattern book", "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tabs := Ui.hbox(book_col, 1)
	for t in [["patterns", "Patterns"], ["pictures", "Pictures"], ["borders", "Borders"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.add_theme_stylebox_override("normal", UiTheme.panel("tab_off", 4, 2))
		b.add_theme_stylebox_override("hover", UiTheme.panel("tab_off", 4, 2))
		b.add_theme_stylebox_override("pressed", UiTheme.panel("tab_on", 4, 2))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = t[0]
		b.pressed.connect(func() -> void:
			Audio.ui("page_turn", -10.0)
			tab = id
			_fill_book())
		tabs.add_child(b)
		_tab_buttons[id] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	book_col.add_child(scroll)
	_book_grid = GridContainer.new()
	_book_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_grid.columns = 4
	_book_grid.add_theme_constant_override("h_separation", 2)
	_book_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_book_grid)
	_plan_panel = Ui.panel(_root, "TabletPanel")
	_plan = PlanView.new()
	_plan.pressed_at.connect(_on_press)
	_plan.dragged_to.connect(_on_drag)
	_plan.released.connect(func() -> void:
		_drag_offset = Vector2.INF
		_pending = {}
		if _ground_on_release != "" and not _moved:
			selected = -1
			role = _ground_on_release
			_plan.selection = Rect2()
			_refresh_chips()
		_ground_on_release = "")
	_plan.wheeled.connect(_on_wheel)
	_plan.dropped.connect(_on_drop)
	_plan.hovered_at.connect(_on_hover)
	_plan.handle_grabbed.connect(_on_handle)
	_plan.handle_dragged.connect(_on_handle_drag)
	_plan_panel.add_child(_plan)
	_build_toolbar()
	_bottom = Ui.panel(_root, "PagePanel")
	var rows := Ui.vbox(_bottom, 3)
	var parts_row := Ui.hbox(rows, 4)
	Ui.label(parts_row, "Parts", "MutedLabel").custom_minimum_size.x = 34
	_chips = HFlowContainer.new()
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips.add_theme_constant_override("h_separation", 2)
	_chips.add_theme_constant_override("v_separation", 2)
	parts_row.add_child(_chips)
	var stones_row := Ui.hbox(rows, 4)
	Ui.label(stones_row, "Stones", "MutedLabel").custom_minimum_size.x = 34
	_palette = GridContainer.new()
	_palette.columns = mini(10, _stones_allowed().size())
	_palette.add_theme_constant_override("h_separation", 1)
	_palette.add_theme_constant_override("v_separation", 1)
	stones_row.add_child(_palette)
	for id in _stones_allowed():
		var b := Button.new()
		b.icon = MotifIcons.swatch(id, 10)
		Ui.tip_on(b, "%s, %s for a sack of 100 tiles" % [Stones.LIST[Stones.index(id)]["name"], Ui.coins_text(Game.sack_price(id))])
		b.custom_minimum_size = Vector2(15, 15)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_stylebox_override("normal", UiTheme.panel("slot", 3, 1))
		b.add_theme_stylebox_override("hover", UiTheme.panel("chip_off", 3, 1))
		b.add_theme_stylebox_override("pressed", UiTheme.panel("chip_on", 3, 1))
		b.add_theme_stylebox_override("hover_pressed", UiTheme.panel("chip_on", 3, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.toggle_mode = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sid: String = id
		b.pressed.connect(func() -> void: _apply_stone(sid))
		_palette.add_child(b)
		_stone_buttons[id] = b
	_right = Ui.vbox(_root, 5)
	var card := Ui.panel(_right, "CardPanel")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card_scroll := ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(card_scroll)
	_brief_box = Ui.vbox(card_scroll, 2)
	_cost_panel = Ui.panel(_root, "PagePanel")
	var cost_col := Ui.vbox(_cost_panel, 1)
	var history := Ui.hbox(cost_col, 3)
	_undo_button = Ui.icon_button(history, "undo", "Undo (Ctrl+Z)", _undo_step)
	_redo_button = Ui.icon_button(history, "redo", "Redo (Ctrl+Y)", _redo_step)
	_refresh_history()
	_cost_label = Ui.label(cost_col, "", "", 116)
	_buy_button = Ui.button(cost_col, "", _buy_stone, "sack")
	_buy_button.visible = false
	_warn_label = Ui.label(cost_col, "", "", 116)
	_warn_label.add_theme_color_override("font_color", UiTheme.RED)
	if free:
		var rooms := OptionButton.new()
		rooms.fit_to_longest_item = false
		rooms.clip_text = true
		rooms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Ui.tip_on(rooms, "The room to design a floor for")
		var ids := Data.rooms.keys()
		for i in ids.size():
			var r := Data.room(ids[i])
			rooms.add_item("%s, %d by %d" % [r["name"], int(r["w"]), int(r["h"])], i)
			if ids[i] == design.room:
				rooms.select(i)
		rooms.item_selected.connect(func(i: int) -> void:
			_remember()
			var fresh := FloorDesign.for_room(ids[i])
			fresh.ground = design.ground
			fresh.border = design.border
			fresh.placements = design.placements
			design = fresh
			_select(-1)
			_dirty = true
			_cost_dirty = true)
		_right.add_child(rooms)
	_start = Ui.button(_right, "Start laying", _start_laying, "brush", true)


## The little dark bar that floats above the picked motif, with what can be done to it.
func _build_toolbar() -> void:
	_toolbar = Ui.panel(_root, "TipPanel")
	var tools := Ui.hbox(_toolbar, 2)
	Ui.icon_button(tools, "rotate", "Turn a quarter (R)", _turn)
	Ui.icon_button(tools, "flip", "Mirror it (F)", _flip)
	_pair_button = Ui.button(tools, "Pair", _mirror)
	Ui.tip_on(_pair_button, "Add a mirrored copy on the other side of the room (M)")
	_fine_button = Ui.button(tools, "Small tiles", _toggle_fine)
	_fine_button.toggle_mode = true
	Ui.tip_on(_fine_button, "Lay this picture in tiles half the size, for finer detail")
	Ui.icon_button(tools, "trash", "Take it off the floor (Delete)", _remove)
	_toolbar.visible = false


func _layout_ui() -> void:
	var s := Nav.ui_size()
	_root.size = s
	Ui.put(_desk, Vector2.ZERO, s)
	var book_w := 134.0
	var right_w := 124.0
	var bottom_h := 72.0
	var cost_h := 116.0
	Ui.put(_book, Vector2(5, 5), Vector2(book_w, s.y - cost_h - 14))
	Ui.put(_cost_panel, Vector2(5, s.y - cost_h - 5), Vector2(book_w, cost_h))
	Ui.put(_right, Vector2(s.x - right_w - 5, 5), Vector2(right_w, s.y - 10))
	var plan_x := book_w + 9
	var plan_w := s.x - plan_x - right_w - 9
	Ui.put(_plan_panel, Vector2(plan_x, 5), Vector2(plan_w, s.y - bottom_h - 14))
	Ui.put(_bottom, Vector2(plan_x, s.y - bottom_h - 5), Vector2(plan_w, bottom_h))
	_place_toolbar.call_deferred()


## Keeps the toolbar just above the picked motif, or below it when it sits at the top of the plan.
func _place_toolbar() -> void:
	_toolbar.visible = selected >= 0
	if selected < 0:
		return
	_toolbar.reset_size()
	var box := _plan_panel.get_global_rect()
	var sel := _plan.selection_local()
	var at := _plan.get_global_rect().position + Vector2(sel.position.x + sel.size.x * 0.5 - _toolbar.size.x * 0.5, sel.position.y - _toolbar.size.y - 5)
	if at.y < box.position.y + 2:
		at.y = _plan.get_global_rect().position.y + sel.end.y + 5
	at.x = clampf(at.x, box.position.x + 2, box.end.x - _toolbar.size.x - 2)
	at.y = clampf(at.y, box.position.y + 2, box.end.y - _toolbar.size.y - 2)
	_toolbar.position = (at - _root.get_global_rect().position).floor()


func _motifs_allowed() -> Array:
	return Data.motif_order if free else Game.state["unlocked_motifs"]


func _stones_allowed() -> Array:
	if free:
		return Stones.LIST.map(func(s) -> String: return s["id"])
	return Game.state["unlocked_stones"]


func _fill_book() -> void:
	for c in _book_grid.get_children():
		c.queue_free()
	for k in _tab_buttons:
		_tab_buttons[k].button_pressed = k == tab
	if tab == "borders":
		_book_grid.columns = 1
		_add_border_slot("", "No border")
		for id in Data.border_order:
			_add_border_slot(id, Data.borders[id]["name"])
		return
	_book_grid.columns = 4
	if tab == "pictures" and _panels_open():
		for panel in Game.state["panels"]:
			_add_panel_slot(panel)
	for id in Data.motif_order:
		var m := Data.motif(id)
		var is_picture: bool = m.get("kind", "") == "picture"
		if is_picture != (tab == "pictures"):
			continue
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(28, 28)
		slot.icon = MotifIcons.motif(id, 22, _stones_for(id))
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.expand_icon = false
		slot.add_theme_stylebox_override("normal", UiTheme.panel("slot", 3, 2))
		slot.add_theme_stylebox_override("hover", UiTheme.panel("chip_off", 3, 2))
		slot.add_theme_stylebox_override("pressed", UiTheme.panel("slot", 3, 2))
		slot.add_theme_stylebox_override("disabled", UiTheme.panel("slot", 3, 2))
		var open := free or Game.has_motif(id)
		var shows := (m.get("tags", []) as Array).filter(func(t: String) -> bool: return Brief.TAG_WORDS.has(t)).map(func(t: String) -> String: return Brief.TAG_WORDS[t])
		var about := ("%s. Shows %s." % [m["name"], ", ".join(shows)]) if not shows.is_empty() else "%s." % m["name"]
		Ui.tip_on(slot, about + (" Drag it onto the floor, or click to add it." if open else " Unlocks in chapter %d, or dig one up." % int(m.get("tier", 1))))
		if not open:
			slot.disabled = true
			slot.modulate = Color(1, 1, 1, 0.35)
		else:
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var mid: String = id
			slot.pressed.connect(func() -> void: _add_motif(mid, Vector2(design.w, design.h) * 0.5))
			slot.set_drag_forwarding(func(_at: Vector2):
				slot.set_drag_preview(_drag_preview(mid))
				return {"motif": mid}, Callable(), Callable())
		_book_grid.add_child(slot)


## Whether this job can take a picture panel made at the bench: a client's floor or the contest, when there are any.
func _panels_open() -> bool:
	return not free and str(job.get("kind", "commission")) in ["commission", "contest"] and not (Game.state.get("panels", []) as Array).is_empty()


func _add_panel_slot(panel: Dictionary) -> void:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(28, 28)
	slot.icon = MotifIcons.motif(panel["motif"], 22, panel.get("stones", {}))
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_theme_stylebox_override("normal", UiTheme.panel("chip_on", 3, 2))
	slot.add_theme_stylebox_override("hover", UiTheme.panel("chip_on", 3, 2))
	slot.add_theme_stylebox_override("pressed", UiTheme.panel("chip_on", 3, 2))
	slot.add_theme_stylebox_override("disabled", UiTheme.panel("slot", 3, 2))
	var used := design.placements.any(func(p: Dictionary) -> bool: return str(p.get("panel", "")) == str(panel["id"]))
	Ui.tip_on(slot, "Your %s panel, %d stars. Click to set it into this floor: it comes laid already, and the client pays extra for it." % [Data.motif_name(panel["motif"]), int(panel.get("stars", 0))] if not used else "This panel is already in the floor.")
	slot.disabled = used
	if not used:
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pressed.connect(func() -> void: _add_panel(panel))
	_book_grid.add_child(slot)


func _add_panel(panel: Dictionary) -> void:
	_remember()
	var size := minf(float(panel.get("size", 14)), minf(design.w, design.h) * 0.9)
	var p := design.add(panel["motif"], design.w * 0.5, design.h * 0.5, size)
	p["stones"] = (panel.get("stones", {}) as Dictionary).duplicate()
	p["outline"] = str(panel.get("outline", ""))
	p["fine"] = bool(panel.get("fine", false))
	p["panel"] = panel["id"]
	Audio.ui("tab", -8.0)
	_select(design.placements.size() - 1)
	_fill_book()
	_dirty = true
	_cost_dirty = true


## A panel made at the bench keeps its size and stones; it can only be moved, turned or taken off.
func _is_panel(i: int) -> bool:
	return i >= 0 and i < design.placements.size() and str(design.placements[i].get("panel", "")) != ""


func _add_border_slot(id: String, name: String) -> void:
	var b := Button.new()
	b.text = name
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if id != "":
		b.icon = MotifIcons.border(id, 28)
		var open := free or Game.has_border(id)
		if not open:
			b.disabled = true
			Ui.tip_on(b, "%s: unlocks in chapter %d" % [name, int(Data.borders[id].get("tier", 1))])
	b.toggle_mode = true
	b.button_pressed = str(design.border.get("id", "")) == id
	b.pressed.connect(func() -> void:
		Audio.ui("click")
		_remember()
		design.set_border(id)
		if not free:
			design.border["stones"] = (design.border.get("stones", []) as Array).map(func(s: String) -> String: return Stones.nearest(s, _stones_allowed()))
		_dirty = true
		_cost_dirty = true
		_fill_book()
		_select(-1)
		for k in _chip_buttons:
			if str(k).begins_with("border"):
				role = k
				break
		_refresh_chips())
	_book_grid.add_child(b)


func _recompose() -> void:
	var px := clampi(int(360.0 / maxf(design.w, design.h * 1.4)), 2, 6)
	var img := Composer.picture(design, px)
	if _tex == null or _tex.get_size() != Vector2(img.get_size()):
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	_parts = Composer.part_map(design, px)
	_parts_px = px
	_plan.outline_width = maxf(1.0, roundf(px * 0.4))
	_plan.set_image(_tex, Vector2(design.w, design.h))
	_plan.selection = _rect_of(design.placements[selected]) if selected >= 0 else Rect2()
	_plan.resizable = not _is_panel(selected)
	_plan.chosen_part = _part_texture(_chosen_code())
	_hover_code = -1
	_plan.hover_part = null
	_plan.queue_redraw()
	_refresh_brief()
	_place_toolbar()


func _exit_tree() -> void:
	if _count_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_count_task)
		_count_task = -1


## Counts the stone the design needs: the exact count when it is in, or when exact is asked for; otherwise an estimate.
func _recost(exact := false) -> void:
	var sig := JSON.stringify(design.to_dict())
	if exact and sig != _exact_sig and _count_task >= 0 and _count_sig == sig:
		_collect_count()
	if sig == _exact_sig:
		_counts = _exact
	elif exact:
		_counts = Composer.stone_counts(design)
		_exact = _counts
		_exact_sig = sig
	else:
		_counts = Composer.stone_estimate(design)
		_count_later(sig)
	var tiles := 0
	for k in _counts:
		tiles += int(_counts[k])
	if free:
		_cost_label.text = "%d tiles\nFree design: no cost" % tiles
		_warn_label.text = ""
		_start.disabled = false
		return
	# A floor is laid only with stone in stock, bought from the merchant here or at the shelves.
	var need := _still_needed()
	var short := Game.short_of(need)
	var buy := Game.shortfall_cost(need) if not short.is_empty() else 0
	Ui.tip_on(_warn_label, "")
	if short.is_empty():
		_cost_label.text = "All the stone is in stock.\nYou have %s." % Ui.coins_text(Game.coins())
	else:
		var names := short.keys().map(func(id: String) -> String: return str(Stones.LIST[Stones.index(id)]["name"]).to_lower())
		_cost_label.text = "Short of %s.\nYou have %s." % [names[0] if names.size() == 1 else "%d stones" % names.size(), Ui.coins_text(Game.coins())]
	Ui.tip_on(_cost_label, "About %d tiles, laid from your stock. " % tiles + ("Short of: " + ", ".join(short.keys().map(func(id: String) -> String: return "%d %s" % [short[id], str(Stones.LIST[Stones.index(id)]["name"]).to_lower()])) + "." if not short.is_empty() else ""))
	var unsold := Game.not_sold(need)
	_buy_button.visible = not short.is_empty() and unsold.is_empty()
	_buy_button.text = "Buy it: %s" % Ui.coins_text(buy)
	_buy_button.disabled = buy > Game.coins()
	Ui.tip_on(_buy_button, "Buys whole sacks of 100 of every stone you're short of. What's left over stays in stock.")
	_warn_label.text = ""
	_start.disabled = not short.is_empty()
	if str(job.get("kind", "")) == "panel" and design.placements.is_empty():
		_start.disabled = true
		_warn_label.text = "Put a picture on the panel first."
		return
	if not unsold.is_empty():
		_warn_label.text = "%s isn't sold here yet." % Stones.LIST[Stones.index(unsold[0])]["name"]
	elif _start.disabled and buy <= Game.coins():
		_warn_label.text = "Buy the stone first."
	elif _start.disabled:
		var swap := Pricing.cheaper_swap(_counts, _stones_allowed())
		_warn_label.text = "Not enough denarii."
		Ui.tip_on(_warn_label, "" if swap.is_empty() else "%s instead of %s would save %s." % [Stones.LIST[Stones.index(swap["to"])]["name"], Stones.LIST[Stones.index(swap["from"])]["name"].to_lower(), Ui.coins_text(int(swap["saving"]))])


## The brief card: what the client asked for, what you know of their taste, and the stars the floor would earn now.
func _refresh_brief() -> void:
	for c in _brief_box.get_children():
		c.queue_free()
	var kind := str(job.get("kind", "commission"))
	var taste := [] if free else Story.known_taste(Game.state, job)
	var verdict := Brief.judge({} if free else job, design, taste)
	if free:
		Ui.label(_brief_box, "Free design", "Heading")
		Ui.label(_brief_box, "Design anything you like. Nobody pays, and nobody minds.", "", 112)
	elif kind == "contest":
		Ui.label(_brief_box, "The floor contest", "Heading")
		Ui.label(_brief_box, "Judged on looks alone. The rival's entries earn about %d stars." % Looks.stars(float(job.get("rival", 0.6))), "", 112)
	elif kind == "panel":
		Ui.label(_brief_box, "A picture panel", "Heading")
		Ui.label(_brief_box, "Lay a picture at the bench. Sell it to a collector, or set it into a client's floor later.", "", 112)
	elif kind == "copy":
		Ui.label(_brief_box, "Copy this floor", "Heading")
		if _target_tex == null:
			_target_tex = ImageTexture.create_from_image(Composer.picture(FloorDesign.from_dict(job["target"]), 3))
		var sketch := TextureRect.new()
		sketch.texture = _target_tex
		sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sketch.custom_minimum_size = Vector2(96, 62)
		Ui.tip_on(sketch, "Hold the pointer here to lay the sketch over your plan")
		sketch.mouse_entered.connect(func() -> void:
			_plan.peek = _target_tex
			_plan.queue_redraw())
		sketch.mouse_exited.connect(func() -> void:
			_plan.peek = null
			_plan.queue_redraw())
		_brief_box.add_child(sketch)
		Ui.label(_brief_box, "Likeness: %d%%" % int(round(float(verdict.get("likeness", 0.0)) * 100.0)))
	else:
		var who := Data.client(job.get("client", ""))
		Ui.label(_brief_box, str(job.get("client_name", who.get("name", "The client"))), "Heading", 112)
		var about := str(Data.room(job.get("room", "")).get("name", ""))
		if not taste.is_empty():
			about += ". Likes " + " and ".join(taste.map(func(t: String) -> String: return Looks.TASTES[t]["text"].trim_prefix("loves ").trim_prefix("likes ").trim_prefix("wants ")))
		elif str(job.get("client", "")) != "":
			about += ". Taste not known yet"
		Ui.label(_brief_box, about + ".", "MutedLabel", 112)
		for w in verdict["wishes"]:
			var row := Ui.hbox(_brief_box, 2)
			Ui.icon(row, "tick" if w["met"] else "cross")
			Ui.label(row, w["text"], "", 96)
			Ui.tip_on(row, Brief.help(w, _motifs_allowed()))
	_stars_row(verdict)




## Five stars filled to the verdict, a tick or cross for each thing clients look at, and the next thing to fix.
func _stars_row(verdict: Dictionary) -> void:
	var row := Ui.hbox(_brief_box, 1)
	var n := int(verdict["stars"])
	for k in 5:
		Ui.icon(row, "star").modulate = Color(1, 1, 1, 1.0 if k < n else 0.22)
	var looks: Dictionary = verdict.get("looks", {})
	if looks.is_empty():
		return
	var hints: Dictionary = looks["hints"]
	var worst := ""
	var checklist := Ui.vbox(_brief_box, 0)
	for id in Looks.QUALITIES:
		var good := float(looks["qualities"][id]) >= Looks.GOOD
		var line := Ui.hbox(checklist, 3)
		var mark := Ui.icon(line, "tick_small" if good else "cross_small")
		mark.custom_minimum_size = Vector2(10, 11)
		Ui.label(line, Looks.NAMES[id], "" if good else "MutedLabel")
		Ui.tip_on(line, Looks.ABOUT[id])
		if hints.has(id) and (worst == "" or float(looks["qualities"][id]) < float(looks["qualities"][worst])):
			worst = id
	if worst != "":
		Ui.label(_brief_box, "Next: " + hints[worst], "", 112)
	elif int(verdict["stars"]) < 5:
		Ui.label(_brief_box, "Next: meet every wish, and make each of these stronger still.", "", 112)


## The chips for every part of what is picked, a motif or the floor itself, with the chosen one raised in gold.
func _refresh_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	_chip_buttons.clear()
	if selected >= 0:
		var p: Dictionary = design.placements[selected]
		var m := Data.motif(p["motif"])
		_fine_button.visible = m.get("kind", "") == "picture" and (free or int(Game.state["chapter"]) >= 3) and not _is_panel(selected)
		_pair_button.visible = not _is_panel(selected)
		_fine_button.button_pressed = bool(p.get("fine", false))
		if _is_panel(selected):
			Ui.label(_chips, "From the bench, laid already", "MutedLabel")
		for r in ([] if _is_panel(selected) else MotifLibrary.roles_of(p["motif"])):
			_chip(str(r), MotifIcons.part(p["motif"], 18, r, p["stones"], p.get("outline", "")), _stone_of(selected, str(r)), "Part %d" % r)
		if p.get("outline", "") != "" and not _is_panel(selected):
			_chip("outline", MotifIcons.part(p["motif"], 18, 7, p["stones"], p["outline"]), p["outline"], "Outline")
		if role == "" or not role in _chip_buttons:
			role = _chip_buttons.keys()[0] if not _chip_buttons.is_empty() else ""
	else:
		_chip("ground", MotifIcons.floor_part(design, "ground", 18), design.ground, "Ground")
		if str(design.border.get("id", "")) != "":
			var parts := Composer.part_map(design, 2)
			for k in mini(4, (design.border["stones"] as Array).size()):
				# A stripe this kind of border never draws has nothing to colour, so it gets no chip.
				if not parts.has(Composer.PART_BORDER + k):
					continue
				_chip("border%d" % k, MotifIcons.floor_part(design, "border%d" % k, 18), design.border["stones"][k], "Border: " + PART_NAMES[k].to_lower())
		if not role in _chip_buttons:
			role = "ground"
	for k in _chip_buttons:
		_chip_buttons[k].button_pressed = k == role
	var current := _stone_of(selected, role)
	for id in _stone_buttons:
		_stone_buttons[id].button_pressed = id == current
	_plan.chosen_part = _part_texture(_chosen_code())
	_plan.queue_redraw()
	_place_toolbar.call_deferred()


func _chip(key: String, icon: Texture2D, stone_id: String, name: String) -> void:
	var b := Button.new()
	b.icon = icon
	b.toggle_mode = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(24, 24)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.panel("chip_off", 3, 2))
	b.add_theme_stylebox_override("hover", UiTheme.panel("chip_off", 3, 2))
	b.add_theme_stylebox_override("pressed", UiTheme.panel("chip_on", 3, 2))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.panel("chip_on", 3, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	Ui.tip_on(b, "%s: %s" % [name, Stones.LIST[Stones.index(stone_id)]["name"]])
	b.pressed.connect(func() -> void:
		Audio.ui("click", -10.0)
		role = key
		_refresh_chips())
	var code := _code_for(selected, key)
	b.mouse_entered.connect(func() -> void: _show_hover(code))
	b.mouse_exited.connect(func() -> void: _show_hover(-1))
	_chips.add_child(b)
	_chip_buttons[key] = b


## The stone a part is laid in now.
func _stone_of(placement: int, key: String) -> String:
	if placement >= 0:
		var p: Dictionary = design.placements[placement]
		if key == "outline":
			return str(p.get("outline", ""))
		return str(p["stones"].get(key, Data.motif(p["motif"]).get("stones", {}).get(key, "black_stone")))
	if key.begins_with("border"):
		var stones: Array = design.border.get("stones", [])
		var k := int(key.trim_prefix("border"))
		return str(stones[k]) if k < stones.size() else design.ground
	return design.ground


func _apply_stone(stone_id: String) -> void:
	if _is_panel(selected):
		Audio.ui("nope")
		return
	Audio.ui("click", -10.0)
	_remember()
	if selected >= 0:
		var p: Dictionary = design.placements[selected]
		if role == "outline":
			p["outline"] = stone_id
		elif role.is_valid_int():
			p["stones"][role] = stone_id
	elif role == "ground":
		design.ground = stone_id
	elif role.begins_with("border"):
		var k := int(role.trim_prefix("border"))
		var stones: Array = design.border["stones"]
		while stones.size() <= k:
			stones.append(design.ground)
		stones[k] = stone_id
	_dirty = true
	_cost_dirty = true
	_refresh_chips()




func _code_for(placement: int, key: String) -> int:
	if placement < 0:
		if key == "ground":
			return Composer.PART_GROUND
		if key.begins_with("border"):
			return Composer.PART_BORDER + int(key.trim_prefix("border"))
		return -1
	if placement >= Composer.MAX_PARTS or key == "":
		return -1
	return Composer.PART_MOTIF + placement * 8 + (7 if key == "outline" else int(key))


func _chosen_code() -> int:
	return _code_for(selected, role)


## The placement and part a code in the part map stands for: [-1, key] for the floor, [-2, ""] for nothing.
func _part_of(code: int) -> Array:
	if code == Composer.PART_GROUND:
		return [-1, "ground"]
	if code >= Composer.PART_BORDER and code < Composer.PART_BORDER + 4:
		return [-1, "border%d" % (code - Composer.PART_BORDER)]
	if code >= Composer.PART_MOTIF and code != Stones.NO_TILE:
		var r := (code - Composer.PART_MOTIF) % 8
		return [(code - Composer.PART_MOTIF) / 8, "outline" if r == 7 else str(r)]
	return [-2, ""]


func _code_at(tile: Vector2) -> int:
	var w := design.w * _parts_px
	var x := int(tile.x * _parts_px)
	var y := int(tile.y * _parts_px)
	if _parts.is_empty() or x < 0 or y < 0 or x >= w or y >= design.h * _parts_px:
		return -1
	return _parts[y * w + x]


## A picture the size of the plan, lit where one part is, for the plan to glow over.
func _part_texture(code: int) -> ImageTexture:
	if code < 0 or _parts.is_empty():
		return null
	var n := _parts.size()
	var rgba := PackedByteArray()
	rgba.resize(n * 4)
	var any := false
	for i in n:
		if _parts[i] == code:
			rgba[i * 4] = 255
			rgba[i * 4 + 1] = 236
			rgba[i * 4 + 2] = 160
			rgba[i * 4 + 3] = 255
			any = true
	if not any:
		return null
	return ImageTexture.create_from_image(Image.create_from_data(design.w * _parts_px, design.h * _parts_px, false, Image.FORMAT_RGBA8, rgba))


func _show_hover(code: int) -> void:
	if code == _hover_code:
		return
	_hover_code = code
	_plan.hover_part = _part_texture(code) if code != _chosen_code() else null
	_plan.queue_redraw()


func _on_hover(tile: Vector2) -> void:
	var pick := _pick_at(tile)
	_show_hover(_code_for(int(pick[0]), str(pick[1])) if int(pick[0]) != -2 else -1)


## What is under the pointer as [placement, part]: a motif within half a tile, one past the part map by its box, or the floor.
func _pick_at(tile: Vector2) -> Array:
	var code := _code_at(tile)
	var part := _part_of(code)
	if int(part[0]) >= 0:
		return part
	# A covered point is a motif past the part map's limit, so only the boxes can say which.
	if code != Composer.PART_COVERED:
		var near := _motif_near(tile)
		if not near.is_empty():
			return near
	for i in range(design.placements.size() - 1, Composer.MAX_PARTS - 1, -1):
		if _rect_of(design.placements[i]).has_point(tile):
			return [i, ""]
	return part




func _rect_of(p: Dictionary) -> Rect2:
	var t := MotifLibrary.tiles(p["motif"], float(p["size"]))
	if int(p.get("rot", 0)) % 2 == 1:
		t = Vector2(t.y, t.x)
	return Rect2(Vector2(float(p["x"]), float(p["y"])) - t * 0.5, t)


## The motif part within half a tile of a point, so a small motif is easy to click; empty if there is none.
func _motif_near(tile: Vector2) -> Array:
	for o in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
		var part := _part_of(_code_at(tile + o))
		if int(part[0]) >= 0:
			return part
	return []


func _hit(tile: Vector2) -> int:
	for i in range(design.placements.size() - 1, -1, -1):
		if _rect_of(design.placements[i]).has_point(tile):
			return i
	return -1


func _select(i: int) -> void:
	selected = i if i < design.placements.size() else -1
	role = ""
	_plan.selection = _rect_of(design.placements[selected]) if selected >= 0 else Rect2()
	_plan.resizable = not _is_panel(selected)
	_plan.queue_redraw()
	_refresh_chips()


## A click picks the part under the pointer; inside the picked motif's box it stays picked, so it drags from any point.
func _on_press(tile: Vector2, button: int) -> void:
	var part := _pick_at(tile)
	var hit := int(part[0])
	_ground_on_release = ""
	_moved = false
	_press_tile = tile
	if button == MOUSE_BUTTON_RIGHT:
		if hit >= 0:
			_select(hit)
			_remove()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	# Inside the picked motif's box, a press can still drag it from anywhere; a plain click there picks the floor.
	if selected >= 0 and _rect_of(design.placements[selected]).has_point(tile) and hit < 0:
		hit = selected
		_ground_on_release = str(part[1])
	if hit != selected:
		_select(hit)
	if hit >= 0:
		if int(part[0]) == hit:
			role = part[1]
		var p: Dictionary = design.placements[hit]
		_drag_offset = tile - Vector2(float(p["x"]), float(p["y"]))
		_pending = design.to_dict()
	elif str(part[1]) != "":
		role = part[1]
	Audio.ui("click", -14.0)
	_refresh_chips()


func _on_drag(tile: Vector2) -> void:
	if selected < 0 or _drag_offset == Vector2.INF:
		return
	if not _moved and (tile - _press_tile).length() * _plan.plan_rect().size.x / design.w < DRAG_START:
		return
	_moved = true
	var p: Dictionary = design.placements[selected]
	var c := (tile - _drag_offset).clamp(Vector2.ZERO, Vector2(design.w, design.h))
	var to := Vector2(snappedf(c.x, 0.5), snappedf(c.y, 0.5))
	if to == Vector2(float(p["x"]), float(p["y"])):
		return
	_commit_pending()
	p["x"] = to.x
	p["y"] = to.y
	_dirty = true
	_cost_dirty = true


## Grabbing a corner pins the opposite one, so the motif grows and shrinks from there, keeping its shape.
func _on_handle(corner: int) -> void:
	_ground_on_release = ""
	if selected < 0 or _is_panel(selected):
		return
	var r := _rect_of(design.placements[selected])
	var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	_anchor = cs[(corner + 2) % 4]
	_grow = ((cs[corner] as Vector2) - _anchor).sign()
	_pending = design.to_dict()


func _on_handle_drag(tile: Vector2) -> void:
	if selected < 0 or _is_panel(selected):
		return
	var p: Dictionary = design.placements[selected]
	var m := Data.motif(p["motif"])
	var shape := _rect_of(p).size
	var aspect := shape.x / maxf(shape.y, 0.001)
	var d := (tile - _anchor) * _grow
	var wide := maxf(d.x, d.y * aspect)
	var longest := maxf(wide, wide / aspect)
	longest = clampf(roundf(longest), float(m.get("min", 3)), minf(float(m.get("max", 60)), maxf(design.w, design.h)))
	var was := Vector3(float(p["size"]), float(p["x"]), float(p["y"]))
	p["size"] = longest
	var t := _rect_of(p).size
	var centre := _anchor + _grow * t * 0.5
	p["x"] = snappedf(centre.x, 0.5)
	p["y"] = snappedf(centre.y, 0.5)
	if Vector3(float(p["size"]), float(p["x"]), float(p["y"])) == was:
		return
	_commit_pending()
	_dirty = true
	_cost_dirty = true


func _on_wheel(steps: int, tile: Vector2) -> void:
	if selected < 0:
		var hit := int(_pick_at(tile)[0])
		if hit < 0:
			return
		_select(hit)
	var now := Time.get_ticks_msec() / 1000.0
	# A quick run of wheel turns is undone as one step.
	if _resize(steps, now - _last_wheel > 0.8):
		_last_wheel = now


func _on_drop(motif_id: String, tile: Vector2) -> void:
	_add_motif(motif_id, tile)


## The size in tiles a motif takes when it is first put on this floor.
func _starting_size(motif_id: String) -> float:
	var m := Data.motif(motif_id)
	# A picture needs a score of tiles across before its face and legs show, so it starts as the centrepiece.
	var share := 0.6 if m.get("kind", "") == "picture" else 0.34
	return roundf(clampf(minf(design.w, design.h) * share, float(m.get("min", 3)), minf(float(m.get("max", 60)), minf(design.w, design.h) * 0.95)))


## The motif as it will look once dropped, centred on the pointer, sized in interface pixels as the interface scales it.
func _drag_preview(motif_id: String) -> Control:
	var on_plan := _plan.plan_rect().size.x / design.w
	var side := maxi(4, int(round(_starting_size(motif_id) * on_plan)))
	var picture := TextureRect.new()
	picture.texture = MotifIcons.motif(motif_id, side)
	picture.position = -Vector2(side, side) * 0.5
	picture.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(picture)
	return holder


## A motif's own stones, each swapped for the nearest one the workshop has, as it will be laid; all of them in free design.
func _stones_for(motif_id: String) -> Dictionary:
	var stones := (Data.motif(motif_id).get("stones", {}) as Dictionary).duplicate()
	if not free:
		for k in stones:
			stones[k] = Stones.nearest(stones[k], _stones_allowed())
	return stones


func _add_motif(motif_id: String, at: Vector2) -> void:
	_remember()
	var m := Data.motif(motif_id)
	var p := design.add(motif_id, snappedf(at.x, 0.5), snappedf(at.y, 0.5), _starting_size(motif_id))
	p["fine"] = m.get("kind", "") == "picture" and (free or int(Game.state["chapter"]) >= 3)
	p["stones"] = _stones_for(motif_id)
	if not free:
		if str(p.get("outline", "")) != "":
			p["outline"] = Stones.nearest(p["outline"], _stones_allowed())
	Audio.ui("tab", -8.0)
	_select(design.placements.size() - 1)
	_dirty = true
	_cost_dirty = true


## Grows or shrinks the picked motif by about a tenth, one tile at a time when it is small; false if nothing changed.
func _resize(steps: int, remember := true) -> bool:
	if selected < 0 or _is_panel(selected):
		return false
	var p: Dictionary = design.placements[selected]
	var m := Data.motif(p["motif"])
	var size := float(p["size"])
	var to := clampf(size + steps * maxf(1.0, roundf(size * 0.1)), float(m.get("min", 3)), minf(float(m.get("max", 60)), maxf(design.w, design.h)))
	if to == size:
		return false
	if remember:
		_remember()
	p["size"] = to
	_dirty = true
	_cost_dirty = true
	return true


func _turn() -> void:
	if selected >= 0:
		_remember()
		var p: Dictionary = design.placements[selected]
		p["rot"] = (int(p.get("rot", 0)) + 1) % 4
		Audio.ui("click", -10.0)
		_dirty = true
		_cost_dirty = true


func _flip() -> void:
	if selected >= 0:
		_remember()
		var p: Dictionary = design.placements[selected]
		p["flip"] = not bool(p.get("flip", false))
		Audio.ui("click", -10.0)
		_dirty = true


## Adds a copy of the selected motif mirrored across the middle of the room, since Roman floors are usually symmetrical.
func _mirror() -> void:
	if selected < 0 or _is_panel(selected):
		return
	_remember()
	var copy: Dictionary = (design.placements[selected] as Dictionary).duplicate(true)
	copy["x"] = design.w - float(copy["x"])
	copy["flip"] = not bool(copy.get("flip", false))
	design.placements.append(copy)
	Audio.ui("tab", -8.0)
	_select(design.placements.size() - 1)
	_dirty = true
	_cost_dirty = true


func _toggle_fine() -> void:
	if selected >= 0:
		_remember()
		var p: Dictionary = design.placements[selected]
		p["fine"] = _fine_button.button_pressed
		_cost_dirty = true


func _remove() -> void:
	if selected < 0:
		return
	_remember()
	var was_panel := _is_panel(selected)
	design.placements.remove_at(selected)
	if was_panel:
		_fill_book()
	Audio.ui("rustle", -10.0)
	_select(-1)
	_dirty = true
	_cost_dirty = true


func _remember() -> void:
	_undo.push_back(design.to_dict())
	if _undo.size() > 100:
		_undo.pop_front()
	_redo.clear()
	_refresh_history()


func _commit_pending() -> void:
	if _pending.is_empty():
		return
	_undo.push_back(_pending)
	_pending = {}
	_redo.clear()
	_refresh_history()


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.push_back(design.to_dict())
	_restore(_undo.pop_back())


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.push_back(design.to_dict())
	_restore(_redo.pop_back())


func _restore(saved: Dictionary) -> void:
	design = FloorDesign.from_dict(saved)
	Audio.ui("page_turn", -14.0)
	_select(selected if selected < design.placements.size() else -1)
	_fill_book()
	_refresh_history()
	_dirty = true
	_cost_dirty = true


func _refresh_history() -> void:
	if _undo_button:
		_undo_button.disabled = _undo.is_empty()
		_redo_button.disabled = _redo.is_empty()


## Starts the exact count of the design as it stands, unless one is already under way; that one's end starts the next.
func _count_later(sig: String) -> void:
	if _count_task >= 0:
		return
	var snap := FloorDesign.from_dict(design.to_dict())
	var box := {}
	_count_box = box
	_count_sig = sig
	_count_task = WorkerThreadPool.add_task(func() -> void: box["counts"] = Composer.stone_counts(snap))


func _collect_count() -> void:
	WorkerThreadPool.wait_for_task_completion(_count_task)
	_count_task = -1
	_exact = _count_box.get("counts", {})
	_exact_sig = _count_sig
	if _exact_sig == JSON.stringify(design.to_dict()):
		_recost()
	else:
		_cost_dirty = true


## The stone the design needs from stock: all of it, or once laying has begun, only what it needs beyond the stone taken.
func _still_needed() -> Dictionary:
	if not job.get("stone_paid", false):
		return _counts
	if not job.has("stone_taken"):
		job["stone_taken"] = _counts.duplicate()
	var need := {}
	for id in _counts:
		var extra := int(_counts[id]) - int(job["stone_taken"].get(id, 0))
		if extra > 0:
			need[id] = extra
	return need


func _buy_stone() -> void:
	_recost(true)
	if Game.buy_shortfall(_still_needed()):
		Audio.ui("coins")
		Saves.save()
	else:
		Audio.ui("nope")
	_recost()


func _start_laying() -> void:
	_recost(true)
	if _start.disabled:
		Audio.ui("nope")
		return
	if not free:
		if not Game.take_stone(_still_needed()):
			Audio.ui("nope")
			return
		# Stone taken out of the design since laying began goes back into stock.
		for id in job.get("stone_taken", {}):
			var spare := int(job["stone_taken"][id]) - int(_counts.get(id, 0))
			if spare > 0:
				Game.add_stock(id, spare)
		job["stone_taken"] = _counts.duplicate()
		job["stone_paid"] = true
		job["design"] = design.to_dict()
		Game.state["active_job"] = job
		Saves.save()
	Nav.go("floor", {"design": design, "job": job if not free else {"free": true}})


func _back() -> void:
	if not free:
		job["design"] = design.to_dict()
		Game.state["active_job"] = job
	Nav.go("title" if free else "workshop")
