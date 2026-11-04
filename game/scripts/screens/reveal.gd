extends Node
## The reveal: the finished floor in its room, with light running across the new stone.
## The client says what they think, pays, and the workshop's story moves on.

const JobBoard := preload("res://scripts/screens/job_board.gd")

var job := {}
var design: FloorDesign
var result := {}
var _floor: FloorView
var _cam: Camera2D
var _card: PanelContainer
var _note: Label
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


func enter(args: Dictionary) -> void:
	job = args.get("job", {})
	design = args.get("design", null)
	if design == null and job.has("design"):
		design = FloorDesign.from_dict(job["design"])
	if design == null and Dev.has("kind"):
		design = Samples.make(Dev.get_arg("sample", "villa"))
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
		_task = WorkerThreadPool.add_task(func() -> void: layout.build(Composer.compose(d, 6), 6, Composer.fine_mask(d, 6)))
	else:
		_setup()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_setup()


func _setup() -> void:
	_floor = FloorView.new()
	Nav.world.add_child(_floor)
	_floor.setup(_layout)
	_floor.show_finished()
	_floor.apply_stones(_stones)
	_floor.shine(0.9, 1.8)
	var size := _floor.size_world()
	_cam = Camera2D.new()
	Nav.world.add_child(_cam)
	_cam.make_current()
	var vp := get_viewport().get_visible_rect().size
	var wall := FloorView.WALL * _floor.tile_world()
	var area := size + Vector2.ONE * wall * 1.2
	var fit := minf(vp.x * 0.54 / area.x, vp.y * 0.92 / area.y)
	_cam.zoom = Vector2.ONE * fit * 1.5
	_cam.position = size * 0.5 + Vector2(vp.x * 0.21 / fit, 0)
	_cam.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_cam, "zoom", _cam.zoom / 1.5, 2.2)
	_build_card()
	Audio.glissando()


func _build_card() -> void:
	var free: bool = job.get("free", false)
	var kind := str(job.get("kind", "commission"))
	if kind == "contest":
		_paid = int(job.get("budget", 0)) if _won else 0
		_rep = int(Data.num("contest.win_reputation", 8) if _won else Data.num("contest.lose_reputation", 2))
	elif not free:
		var asked := int(job.get("asked", job.get("budget", 0)))
		_paid = Pricing.payment(asked, _score, float(job.get("expected", 0.5)))
		_rep = Pricing.reputation(_score, _layout.tile_count())
	_card = Ui.panel(Nav.ui, "PagePanel")
	var col := Ui.vbox(_card, 3)
	if not free:
		var top := Ui.hbox(col, 6)
		top.add_child(JobBoard._portrait(job.get("portrait", ""), 40))
		var who := Ui.vbox(top, 2)
		Ui.label(who, "The judges" if kind == "contest" else str(job.get("client_name", "")), "Heading", 110)
		_star_row(who, int(_verdict["stars"]))
	else:
		Ui.label(col, "Your floor", "Heading")
		_star_row(col, int(_verdict["stars"]))
	Ui.label(col, _reaction(), "", 190)
	if kind == "contest":
		Ui.label(col, "Your floor: %d stars. The rival's: %d stars." % [int(_verdict["stars"]), Looks.stars(float(job.get("rival", 0.6)))], "MutedLabel", 190)
	elif kind == "copy":
		Ui.label(col, "Likeness: %d%%" % int(round(float(_verdict.get("likeness", 0.0)) * 100.0)), "MutedLabel")
	for w in _verdict.get("wishes", []):
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "tick" if w["met"] else "cross")
		Ui.label(r, w["text"], "", 170)
	if _first_taste:
		var r := Ui.hbox(col, 2)
		Ui.icon(r, "book")
		Ui.label(r, "Noted: %s." % " and ".join((Data.client(job["client"])["taste"] as Array).map(func(t: String) -> String: return Looks.TASTES[t]["text"])), "MutedLabel", 170)
	var found := str(job.get("discovery", ""))
	if found != "" and not found in Game.state["unlocked_motifs"]:
		var r := Ui.hbox(col, 3)
		Ui.texture(r, MotifIcons.motif(found, 16))
		Ui.label(r, "New in your pattern book: the %s" % str(Data.motif(found).get("name", found)).to_lower(), "", 140)
	if not free:
		var pay := Ui.hbox(col, 4)
		Ui.icon(pay, "coin")
		Ui.label(pay, ("Prize %d d" % _paid if _won else "No prize") if kind == "contest" else "Paid %d d" % _paid)
		Ui.icon(pay, "laurel")
		Ui.label(pay, ("+%d reputation" % _rep) if _rep >= 0 else "%d reputation" % _rep)
		if _paid > 0:
			_coin_shower()
	_keep = Ui.button(col, "Keep in my library", _keep_it, "book")
	Ui.tip_on(_keep, "Keeps a picture of this floor, and the way you laid it, in your library")
	Ui.button(col, "Back to the workshop" if not free else "Back", _finish, "arrow_r", true)
	_note = Ui.label(col, "", "MutedLabel", 190)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.5).set_delay(1.4)
	var place := func() -> void:
		var s := Nav.ui_size()
		_card.reset_size()
		_card.position = Vector2(s.x - _card.size.x - 6, floorf((s.y - _card.size.y) * 0.5))
	Nav.resized.connect(place)
	place.call_deferred()


func _star_row(parent: Node, n: int) -> void:
	var stars := Ui.hbox(parent, 1)
	for k in 5:
		Ui.icon(stars, "star").modulate = Color(1, 1, 1, 1.0 if k < n else 0.2)


## What the client says: their story's next line when it went well, and a word on what they noticed most.
func _reaction() -> String:
	var kind := str(job.get("kind", "commission"))
	var looks: Dictionary = _verdict.get("looks", {})
	if job.get("free", false):
		return "Laid, grouted and polished. " + (str(Looks.PRAISE[looks["best"]]) if not looks.is_empty() else "")
	if kind == "contest":
		if _won:
			return "\"The prize goes to your workshop! %s\" The rival's foreman storms off." % Looks.PRAISE[looks["best"]]
		return "\"The rival's floor wins this time. %s\"" % Looks.complaint(looks, looks["worst"])
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
	var said := ""
	if _score >= expected:
		if step >= 0 and not c.is_empty() and step < (c.get("arc", []) as Array).size():
			said = str(c["arc"][step].get("after", "Wonderful."))
		elif int(_verdict["stars"]) >= 5:
			var happy := ["It's beautiful. I'll tell everyone.", "Better than I imagined. Here, with a little extra.", "The neighbours will be so jealous."]
			said = happy[hash(job.get("id", "")) % happy.size()]
		else:
			said = "Yes. That's what I wanted."
		if not looks.is_empty():
			said += " " + (str(Looks.PRAISE[looks["best"]]) if int(_verdict["stars"]) >= 4 else Looks.complaint(looks, looks["worst"]))
	elif _score >= Data.num("reputation.unhappy_below", 0.45):
		said = "It's... fine. It isn't quite what I hoped for, so I won't pay the full price."
		if not looks.is_empty():
			said += " " + Looks.complaint(looks, looks["worst"])
	else:
		said = "This isn't what I asked for at all. I'll pay for the stone and your time, and no more."
	if _first_taste and not looks.is_empty():
		var t: String = c["taste"][0]
		var pleased := float(looks["qualities"][Looks.TASTES[t]["quality"]]) >= 0.7
		said += " " + str(Looks.TASTE_SAID[t][0 if pleased else 1])
	return "\"%s\"" % said


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
	get_tree().create_timer(1.7).timeout.connect(func() -> void: Audio.ui("coins"))


func _keep_it() -> void:
	_keep.disabled = true
	_keep.text = "Keeping it..."
	var picture: Image = await Library.photograph(_layout, self, _stones)
	var info := {"room": design.room, "tiles": _layout.tile_count(), "stars": int(_verdict["stars"])}
	if not job.get("free", false):
		info["client_name"] = str(job.get("client_name", ""))
		info["workshop"] = str(Game.state.get("name", ""))
		info["day"] = int(Game.state.get("day", 0))
	info["stones"] = _stones
	Library.add(design, _order, picture, info)
	_keep.text = "Kept in your library"
	_keep.icon = UiTheme.icon("tick")
	Audio.ui("page_turn", -8.0)


func _finish() -> void:
	if job.get("free", false):
		Game.state["gallery"].append(design.to_dict())
		Nav.go("title")
		return
	if _paid > 0:
		Game.earn(_paid, "Floor for " + str(job.get("client_name", "")))
	var events := Story.finish_job(Game.state, job, {"score": _score, "paid": _paid, "reputation": _rep, "design": design.to_dict(), "tiles": _layout.tile_count()})
	for e in events:
		Game.state["pending_events"].append(e)
	Saves.save()
	Nav.go("workshop")
