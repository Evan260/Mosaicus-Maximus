extends Node
## The reveal: the finished floor in the client's room, with light running across the new stone.
## The client comes in on the left to say what they think and pay, and the workshop's story moves on.

const JobBoard := preload("res://scripts/screens/job_board.gd")
const ClientVisit := preload("res://scripts/screens/client_visit.gd")
## How far the card keeps from the screen's edge, and a floor shown without its room from the card and the edges.
const MARGIN := 6.0
## What the Keep button says before, while and after keeping the floor.
const KEEP_WORDS := ["Keep", "Keeping...", "Kept"]

var job := {}
var design: FloorDesign
var result := {}
var _floor: FloorView
var _cam: Camera2D
var _card: PanelContainer
var _keep: Button
var _task := -1
var _layout: MosaicLayout
var _paid := 0
var _rep := 0
var _score := 0.0
var _verdict := {}
var _won := false
var _first_taste := false
var _order := PackedInt32Array()
## The stones the player mended gaps with, by tile, so a restored floor is shown as they left it.
var _stones := {}
var _room: RoomView
var _panel_bonus := 0
var _wrap := 190.0
var _wishes: ScrollContainer
var _done := false
var _zoom_out: Tween
var _slide: Tween
## Keep and Back beside a room, side by side or stacked.
var _buttons: BoxContainer
## Where the card sits once it has slid in, in interface pixels.
var _card_rect := Rect2()
## The guide's note on the first reveal, which the floor keeps clear of while it shows.
var _note: Guide


func enter(args: Dictionary) -> void:
	job = args.get("job", {})
	design = args.get("design", null)
	if design == null and job.has("design"):
		design = FloorDesign.from_dict(job["design"])
	if design == null and Dev.has("kind"):
		design = Samples.make(Dev.get_arg("sample", "villa"))
		if Dev.has("room"):
			design = Samples.moved(design, Dev.get_arg("room"))
		job = Dev.test_job(Dev.get_arg("kind"))
	if design == null:
		design = Samples.make(Dev.get_arg("sample", "sea"))
		job = {"client": "gaius", "client_name": "Gaius of the baths", "portrait": "gaius", "asked": 200, "expected": 0.5, "arc_step": 0, "brief": {"tags": ["sea"], "want_stones": ["blue_glass"]}, "id": "demo", "taste": ["colourful"]}
	_score = float(args.get("repair_score", -1.0))
	if _score >= 0.0:
		_verdict = {"wishes": [], "looks": {}, "score": _score, "stars": Looks.stars(_score)}
	else:
		_verdict = Brief.judge({} if job.get("free", false) else job, design, job.get("taste", []))
		_score = float(_verdict["score"])
	if job.get("kind", "") == "contest":
		_won = float(_verdict["looks"].get("beauty", 0.0)) >= float(job.get("rival", 0.6))
	var id := str(job.get("client", ""))
	_first_taste = id != "" and not (Data.client(id).get("taste", []) as Array).is_empty() and not bool(Game.state["clients"].get(id, {}).get("taste_known", false))
	_order = args.get("order", PackedInt32Array())
	_stones = args.get("stones", {})
	_layout = args.get("layout", null)
	if _layout == null:
		var d := design
		var layout := MosaicLayout.new()
		_layout = layout
		_task = WorkerThreadPool.add_task(func() -> void:
			layout.build(Composer.compose(d, 6), 6, Composer.fine_mask(d, 6))
			FloorView.prepare(layout))
	else:
		_setup()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_setup()


func _setup() -> void:
	if RoomView.has_room(design.room):
		_setup_room()
		return
	_floor = FloorView.new()
	Nav.world.add_child(_floor)
	_floor.setup(_layout)
	_floor.show_finished()
	_floor.apply_stones(_stones)
	_floor.shine(0.9, 1.8)
	_cam = Camera2D.new()
	Nav.world.add_child(_cam)
	_cam.make_current()
	_build_card()
	Audio.glissando()


## Fits the floor and its walls into the screen left of the card and below the guide's note, the first time zooming out to it from closer in.
func _frame_floor() -> void:
	var ui := float(Nav.scale_factor())
	var wall := Vector2.ONE * FloorView.WALL * _floor.tile_world()
	var drawn := Rect2(-wall, _floor.size_world() + wall * 2.0)
	var safe := Rect2(Nav.safe_top_left * ui, Nav.ui_size() * ui)
	var free := Rect2(safe.position, Vector2((Nav.safe_top_left.x + _card_rect.position.x) * ui - safe.position.x, safe.size.y)).grow(-MARGIN * ui)
	var note := _note_rect()
	if note.has_area():
		free = free.grow_side(SIDE_TOP, minf(0.0, free.position.y - (Nav.safe_top_left.y + note.end.y + MARGIN) * ui))
	var fit := minf(free.size.x / drawn.size.x, free.size.y / drawn.size.y)
	_cam.position = drawn.get_center() - (free.get_center() - get_viewport().get_visible_rect().size * 0.5) / fit
	if _zoom_out == null:
		_cam.zoom = Vector2.ONE * fit * 1.5
		_zoom_out = _cam.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_zoom_out.tween_property(_cam, "zoom", Vector2.ONE * fit, 2.2)
		return
	_zoom_out.kill()
	_cam.zoom = Vector2.ONE * fit


## The floor in the client's painted room, set right of centre so the client's card has the left side.
func _setup_room() -> void:
	_room = RoomView.new()
	Nav.pictures.add_child(_room)
	_room.setup(design.room, _layout, _stones)
	_floor = _room.floor_view
	_floor.shine(0.9, 1.8)
	_room.modulate.a = 0.0
	_room.create_tween().tween_property(_room, "modulate:a", 1.0, 0.6)
	_wrap = 156.0
	_build_card()
	Audio.glissando()


func _build_card() -> void:
	var kind := str(job.get("kind", "commission"))
	# A panel at the bench is shown like free design: nobody pays for it yet.
	var free: bool = job.get("free", false) or kind == "panel"
	if kind == "contest":
		_paid = int(job.get("budget", 0)) if _won else 0
		_rep = int(Data.num("contest.win_reputation", 8) if _won else Data.num("contest.lose_reputation", 2))
	elif not free:
		var asked := int(job.get("asked", job.get("budget", 0)))
		_paid = Pricing.payment(asked, _score, float(job.get("expected", 0.5)))
		_rep = Pricing.reputation(_score, _layout.tile_count())
		_panel_bonus = _panels_bonus()
		_paid += _panel_bonus
	_card = Ui.panel(Nav.ui, "PagePanel")
	var col := Ui.vbox(_card, 3)
	if not free:
		var top := Ui.hbox(col, 6)
		top.add_child(JobBoard._portrait(job.get("portrait", ""), 40))
		var who := Ui.vbox(top, 2)
		Ui.label(who, tr("The judges") if kind == "contest" else Ui.text(job.get("client_name", "")), "Heading", 110)
		_star_row(who, int(_verdict["stars"]))
	else:
		Ui.label(col, "Your picture panel" if kind == "panel" else "Your floor", "Heading")
		_star_row(col, int(_verdict["stars"]))
	Ui.label(col, _reaction(), "", _wrap)
	if kind == "contest":
		Ui.label(col, tr("Your floor: %d stars. The rival's: %d stars.") % [int(_verdict["stars"]), Looks.stars(float(job.get("rival", 0.6)))], "MutedLabel", _wrap)
	elif kind == "copy":
		Ui.label(col, tr("Likeness: %d%%") % int(round(float(_verdict.get("likeness", 0.0)) * 100.0)), "MutedLabel", _wrap)
	_wishes = ScrollContainer.new()
	_wishes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_wishes)
	var list := Ui.vbox(_wishes, 1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for w in _verdict.get("wishes", []):
		var r := Ui.hbox(list, 2)
		Ui.icon(r, "tick" if w["met"] else "cross")
		Ui.label(r, w["text"], "", _wrap - 20)
	if _first_taste:
		var r := Ui.hbox(list, 2)
		Ui.icon(r, "book")
		Ui.label(r, tr("Noted: %s.") % Looks.tastes_words(Data.client(job["client"])["taste"]), "MutedLabel", _wrap - 20)
	_wishes.visible = list.get_child_count() > 0
	var found := str(job.get("discovery", ""))
	if found != "" and not found in Game.state["unlocked_motifs"]:
		var r := Ui.hbox(col, 3)
		Ui.texture(r, MotifIcons.motif(found, 16))
		Ui.label(r, tr("New in your pattern book: %s") % Data.motif_a(found), "", _wrap - 50)
	if kind == "panel":
		Ui.label(col, tr("Your picture panel is ready. A collector would pay about %s for it at the workbench, or you can set it into a client's floor from the Pictures page of the pattern book.") % Ui.coins_text(Story.panel_value(Game.state, int(_verdict["stars"]))), "", _wrap)
	if _panel_bonus > 0:
		var r := Ui.hbox(col, 3)
		Ui.icon(r, "star")
		Ui.label(r, tr("Your picture panel: +%s") % Ui.coins_text(_panel_bonus), "", _wrap - 20)
	if not free:
		var pay := Ui.hbox(col, 4)
		Ui.icon(pay, "coin")
		Ui.label(pay, (tr("Prize %s") % Ui.coins_text(_paid) if _won else tr("No prize")) if kind == "contest" else tr("Paid %s") % Ui.coins_text(_paid))
		Ui.icon(pay, "laurel")
		Ui.label(pay, (tr("+%d reputation") % _rep) if _rep >= 0 else tr("%d reputation") % _rep)
		var ahead := Story.next_chapter_line(Game.state, _rep, true)
		if ahead != "":
			Ui.label(col, ahead, "MutedLabel", _wrap)
		if _paid > 0:
			_coin_shower()
	var buttons: BoxContainer = col
	if _room:
		_buttons = BoxContainer.new()
		_buttons.add_theme_constant_override("separation", 3)
		col.add_child(_buttons)
		buttons = _buttons
	_keep = Ui.button(buttons, "Keep" if _room else "Keep in my library", _keep_it, "book")
	Ui.tip_on(_keep, "Keeps a picture of this floor, and the way you laid it, in your library")
	var back := Ui.button(buttons, "Back" if job.get("free", false) else "Back to the workshop", _finish, "arrow_r", true)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.5).set_delay(1.4)
	if not free:
		_note = Guide.note("reveal", "The client pays you, and your reputation grows. Enough reputation opens the next chapter, with new stone and patterns.", "top_right" if _room else "top_left")
	if _note:
		_note.item_rect_changed.connect(_place_floor)
		_note.tree_exiting.connect(_place_floor)
	Nav.resized.connect(_place_card)
	_place_card.call_deferred()


## Sets the card at its side of the screen, the guide's note beside it, and the floor clear of both; beside a room the card slides in the first time.
func _place_card() -> void:
	var s := Nav.ui_size()
	_stack_buttons(s.y - 8.0)
	_lay_out_card(s.y - 8.0)
	_card.reset_size()
	_card_rect = Rect2(MARGIN if _room else s.x - _card.size.x - MARGIN, floorf((s.y - _card.size.y) * 0.5), _card.size.x, _card.size.y)
	_card.position = _card_rect.position
	if _room and _slide == null:
		_card.position.x = -_card.size.x
		_slide = _card.create_tween()
		_slide.tween_property(_card, "position:x", _card_rect.position.x, 0.6).set_delay(1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _note_open():
		# The note may take the top two thirds of the screen beside the card, so the floor keeps at least the last third.
		var left := _card_rect.end.x + MARGIN if _room else MARGIN
		var right := s.x - MARGIN if _room else _card_rect.position.x - MARGIN
		_note.keep_within(Rect2(left, MARGIN, right - left, floorf(s.y * 2.0 / 3.0) - MARGIN))
	_place_floor()


## Stacks Keep and Back when side by side they would make the card wider than its words need, unless stacking hides some of the checklist in `height` without drawing the room any larger.
func _stack_buttons(height: float) -> void:
	if _buttons == null:
		return
	# Keep is as wide as its longest word, so pressing it never widens the card.
	var said := _keep.text
	var widest := 0.0
	_keep.custom_minimum_size.x = 0.0
	for word in KEEP_WORDS:
		_keep.text = word
		widest = maxf(widest, _keep.get_combined_minimum_size().x)
	_keep.text = said
	_keep.custom_minimum_size.x = widest
	var col := _buttons.get_parent() as Control
	col.custom_minimum_size.x = 0.0
	var words := 0.0
	for c: Control in col.get_children():
		if c != _buttons and c.visible:
			words = maxf(words, c.get_combined_minimum_size().x)
	_buttons.vertical = false
	var row := _buttons.get_combined_minimum_size().x
	if row <= words:
		return
	var side := _lay_out_card(height)
	var tallest := maxf(height, side["tall"])
	_buttons.vertical = true
	var narrow := _lay_out_card(height)
	if narrow["tall"] <= tallest and narrow["shown"] >= side["shown"]:
		return
	# A wider stacked card showing some of the checklist wins only where it draws the room larger, and the most of the checklist at that size.
	var pick := -1.0
	var best := side
	var w := words + 10.0
	while w < row:
		col.custom_minimum_size.x = w
		var card := _lay_out_card(height)
		if card["tall"] <= tallest and (card["shown"] > 0.0 or side["shown"] <= 0.0) and (card["scale"] > best["scale"] or (pick > 0.0 and card["scale"] == best["scale"] and card["shown"] > best["shown"])):
			pick = w
			best = card
		w += 10.0
	col.custom_minimum_size.x = maxf(pick, 0.0)
	_buttons.vertical = pick > 0.0


## Lays the card out at once, so its words wrap at its new width, and fits its checklist into `height`: how much of the checklist shows, how tall the card is and the room's scale beside it.
func _lay_out_card(height: float) -> Dictionary:
	_card.reset_size()
	for c: Container in [_card] + _card.find_children("*", "Container", true, false):
		c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for l: Label in _card.find_children("*", "Label", true, false):
		l.get_minimum_size()
	ClientVisit.fit_list(_card, _wishes, height)
	var box := _card.get_combined_minimum_size()
	return {"shown": _wishes.custom_minimum_size.y, "tall": box.y, "scale": _room.scale_beside(Rect2(MARGIN, 0.0, box.x, 1.0)) if _room else 0}


## The room or the floor alone, clear of the card and of the guide's note while it shows.
func _place_floor() -> void:
	if not _card_rect.has_area():
		return
	if _room:
		_room.keep_clear_of(_card_rect, _note_rect())
	else:
		_frame_floor()


func _note_open() -> bool:
	return is_instance_valid(_note) and not _note.is_queued_for_deletion()


## The guide's note in interface pixels, or an empty rectangle once it is closed or when there is none.
func _note_rect() -> Rect2:
	return Rect2(_note.position, _note.size) if _note_open() else Rect2()


func _star_row(parent: Node, n: int) -> void:
	var stars := Ui.hbox(parent, 1)
	for k in 5:
		Ui.icon(stars, "star").modulate = Color(1, 1, 1, 1.0 if k < n else 0.2)


## What the client says: their story's next line when it went well, and a word on what they noticed most.
func _reaction() -> String:
	var kind := str(job.get("kind", "commission"))
	var looks: Dictionary = _verdict.get("looks", {})
	if job.get("free", false) or kind == "panel":
		return Ui.text(["Laid, grouted and polished.", Looks.praise(looks["best"]) if not looks.is_empty() else ""])
	if kind == "contest":
		if _won:
			return tr("\"The prize goes to your workshop! %s\" The rival's foreman storms off.") % Looks.praise(looks["best"])
		return tr("\"The rival's floor wins this time. %s\"") % Looks.complaint(looks, looks["worst"])
	if kind == "copy":
		var like := float(_verdict.get("likeness", 0.0))
		if like >= 0.85:
			return "\"It's as if I were standing in the original.\""
		if like >= 0.65:
			return "\"Close. A few stones are not where they were in the original.\""
		return "\"This is not the floor I showed you.\""
	var expected := float(job.get("expected", 0.5))
	var step := int(job.get("arc_step", -1))
	var c := Data.client(job.get("client", ""))
	var said := []
	if _score >= expected:
		if step >= 0 and not c.is_empty() and step < (c.get("arc", []) as Array).size():
			said.append(str(c["arc"][step].get("after", "Wonderful.")))
		elif int(_verdict["stars"]) >= 5:
			var happy := ["It's beautiful. I'll tell everyone.", "Better than I imagined. Here, with a little extra.", "The neighbours will be so jealous."]
			said.append(happy[hash(job.get("id", "")) % happy.size()])
		else:
			said.append("Yes. That's what I wanted.")
		if not looks.is_empty():
			said.append(Looks.praise(looks["best"]) if int(_verdict["stars"]) >= 4 else Looks.complaint(looks, looks["worst"]))
	elif _score >= Data.num("reputation.unhappy_below", 0.45):
		said.append("It's... fine. It isn't quite what I hoped for, so I won't pay the full price.")
		if not looks.is_empty():
			said.append(Looks.complaint(looks, looks["worst"]))
	else:
		said.append("This isn't what I asked for at all. I'll pay for the stone and your time, and no more.")
	if _first_taste and not looks.is_empty():
		var t: String = c["taste"][0]
		var pleased := float(looks["qualities"][Looks.TASTES[t]["quality"]]) >= 0.7
		said.append(Looks.taste_said(t, pleased))
	return tr("\"%s\"") % Ui.text(said)


func _coin_shower() -> void:
	var s := Nav.ui_size()
	for i in mini(18, 4 + _paid / 20):
		var c := TextureRect.new()
		c.texture = UiTheme.icon("coin")
		c.position = Vector2(randf_range(s.x * 0.12, s.x * 0.5), -20)
		Nav.ui.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(1.6 + i * 0.06)
		tw.tween_property(c, "position:y", s.y * 0.55 + randf() * 20.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.5).set_delay(0.3)
		tw.tween_callback(c.queue_free)
	get_tree().create_timer(1.7).timeout.connect(func() -> void: Audio.play("coins"))


func _keep_it() -> void:
	_keep.disabled = true
	_keep.text = "Keeping..." if _room else "Keeping it..."
	var picture: Image = await Library.photograph(_layout, self, _stones)
	var info := {"room": design.room, "tiles": _layout.tile_count(), "stars": int(_verdict["stars"])}
	if not job.get("free", false):
		info["client_name"] = job.get("client_name", "")
		info["workshop"] = str(Game.state.get("name", ""))
		info["day"] = int(Game.state.get("day", 0))
	info["stones"] = _stones
	Library.add(design, _order, picture, info)
	_keep.text = "Kept" if _room else "Kept in your library"
	_keep.icon = UiTheme.icon("tick")
	Audio.play("page_turn", -8.0)


## What the client adds for the picture panels from the bench set into the floor.
func _panels_bonus() -> int:
	var total := 0
	for p in design.placements:
		for panel in Game.state.get("panels", []):
			if str(p.get("panel", "")) == str(panel["id"]):
				total += int(Story.panel_value(Game.state, int(panel.get("stars", 0))) * Data.num("panel.set_scale", 1.3))
	return total


## A phone's back gesture does what Back to the workshop does, once the card is there to show what was paid.
func carry_on() -> void:
	if _keep != null:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if job.get("kind", "") == "panel":
		Story.finish_panel(Game.state, job, {"score": _score, "design": design.to_dict()})
		Saves.save()
		Nav.go("workshop")
		return
	if job.get("free", false):
		Game.state["gallery"].append(design.to_dict())
		Nav.go("title")
		return
	if _paid > 0:
		Game.earn(_paid, "Floor for " + Ui.text(job.get("client_name", "")))
	var events := Story.finish_job(Game.state, job, {"score": _score, "paid": _paid, "reputation": _rep, "design": design.to_dict(), "tiles": _layout.tile_count(),
		"won": _won, "likeness": float(_verdict.get("likeness", 0.0)), "stones": _stones})
	for e in events:
		Game.state["pending_events"].append(e)
	var used := design.placements.map(func(p: Dictionary) -> String: return str(p.get("panel", ""))).filter(func(id: String) -> bool: return id != "")
	if not used.is_empty():
		Game.state["panels"] = (Game.state.get("panels", []) as Array).filter(func(p: Dictionary) -> bool: return not p["id"] in used)
		Game.bump("panels_set", used.size())
	Saves.save()
	Nav.go("workshop")


func _exit_tree() -> void:
	Nav.leave_task(_task)
	_task = -1
