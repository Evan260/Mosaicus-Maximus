extends Node
## The client at the counter: what they want, and the price. Slide the coins to set your price and watch their face.

const JobBoard := preload("res://scripts/screens/job_board.gd")

var job := {}
var _root: Control
var _card: PanelContainer
var _speech: Label
var _price: HSlider
var _price_label: Label
var _mood: Label
var _expect: Label
var _shake: Button
var _buttons: HBoxContainer
var _done := false
## How many more times the client will hear a price they think too high before walking out.
var _patience := 2
## The client's own offer after turning a price down; asking that or less is always accepted.
var _offer := 0


func enter(args: Dictionary) -> void:
	job = (args.get("job", {}) as Dictionary).duplicate(true)
	if job.is_empty() and Dev.has("kind"):
		job = Dev.test_job(Dev.get_arg("kind"))
	if job.is_empty():
		Story.morning(Game.state)
		job = (Game.state["board"][int(Dev.num("job", 0))] as Dictionary).duplicate(true)
	var kind := str(job.get("kind", "commission"))
	var restore := kind == "restoration"
	_root = Control.new()
	Nav.ui.add_child(_root)
	var desk := Ui.panel(_root, "BoardPanel")
	_card = Ui.panel(_root, "PagePanel")
	var row := Ui.hbox(_card, 8)
	var left := Ui.vbox(row, 4)
	left.add_child(JobBoard._portrait(job.get("portrait", ""), 64))
	Ui.label(left, str(job.get("client_name", "")), "Heading", 90)
	var room := Data.room(job.get("room", ""))
	Ui.label(left, "%s, %d by %d tiles" % [room.get("name", ""), int(room.get("w", 0)), int(room.get("h", 0))], "MutedLabel", 90)
	var right := Ui.vbox(row, 5)
	var bubble := Ui.panel(right, "CardPanel")
	_speech = Ui.label(bubble, _opening_line(), "", 290)
	if kind == "commission":
		var wishes := Brief.score(job.get("brief", {}), FloorDesign.new())["wishes"] as Array
		if not wishes.is_empty():
			Ui.label(right, "What they want", "Heading")
			for w in wishes:
				Ui.tip_on(Ui.label(right, "• " + str(w["text"]), "", 290), Brief.help(w, Game.state["unlocked_motifs"]))
		var known := Story.known_taste(Game.state, job)
		if not known.is_empty() and not bool(job.get("taste_said", false)):
			Ui.label(right, "From your notebook: they " + " and ".join(known.map(func(t: String) -> String: return Looks.TASTES[t]["text"])) + ".", "MutedLabel", 290)
	elif kind == "copy":
		var sketch := TextureRect.new()
		sketch.texture = ImageTexture.create_from_image(Composer.compose(FloorDesign.from_dict(job["target"]), 3))
		sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sketch.custom_minimum_size = Vector2(150, 76)
		right.add_child(sketch)
		Ui.label(right, "They pay for likeness: the closer the copy, the more.", "MutedLabel", 290)
	var budget := int(job.get("budget", 0))
	if kind == "contest":
		Ui.label(right, "The prize is %d d. You pay for your own stone." % budget, "", 290)
		job["asked"] = 0
		job["expected"] = 0.0
		_shake = Ui.button(right, "Enter the contest", _take, "tick", true)
		Ui.button(right, "Not this time", _decline, "cross")
	elif restore:
		Ui.label(right, "They pay %d d, and supply the stone for any repairs." % budget, "", 230)
		job["asked"] = budget
		job["expected"] = 0.5
		_shake = Ui.button(right, "Take the job", _take, "tick", true)
		Ui.button(right, "Turn it down", _decline, "cross")
	else:
		var price_row := Ui.hbox(right, 4)
		Ui.label(price_row, "Your price:")
		_price = HSlider.new()
		_price.min_value = int(budget * 0.7)
		_price.max_value = int(budget * 1.6)
		_price.step = 1
		_price.value = budget
		_price.custom_minimum_size = Vector2(110, 12)
		_price.value_changed.connect(func(_v: float) -> void: _update_price())
		price_row.add_child(_price)
		_price_label = Ui.label(price_row, "")
		_mood = Ui.label(right, "", "", 290)
		_expect = Ui.label(right, "", "MutedLabel", 290)
		_buttons = Ui.hbox(right, 4)
		_shake = Ui.button(_buttons, "Shake on it", _shake_on_it, "tick", true)
		_shake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Ui.button(_buttons, "Turn it down", _decline, "cross")
		_update_price()
	var place := func() -> void:
		var s := Nav.ui_size()
		_root.size = s
		Ui.put(desk, Vector2.ZERO, s)
		_card.reset_size()
		_card.position = ((s - _card.size) * 0.5).floor()
	Nav.resized.connect(place)
	place.call_deferred()
	Audio.ui("rustle", -8.0)


func _opening_line() -> String:
	var greeting: String = job.get("greeting", "")
	var step := int(job.get("arc_step", -1))
	var line: String = job.get("line", "")
	if step == 0 and greeting != "":
		return greeting + "\n\n" + line
	return line


func _update_price() -> void:
	var asked := int(_price.value)
	var budget := int(job.get("budget", 1))
	_price_label.text = "%d d" % asked
	var chance := _chance(asked)
	var expected := Pricing.expectation(asked, budget)
	if _offer > 0 and asked <= _offer:
		_mood.text = "\"%d d. That's what I said.\"" % _offer
	elif chance > 0.85:
		_mood.text = "\"That seems fair.\""
	elif chance > 0.55:
		_mood.text = "\"Hmm. That's more than I'd hoped.\""
	elif chance > 0.25:
		_mood.text = "\"That's a lot of money for a floor.\""
	else:
		_mood.text = "\"You must be joking.\""
	if expected > 0.75:
		_expect.text = "At this price they'll expect nearly every wish met."
	elif expected > 0.55:
		_expect.text = "At this price they'll expect most of their wishes."
	else:
		_expect.text = "At this price they'll be happy with a fair attempt."


func _chance(asked: int) -> float:
	if _offer > 0 and asked <= _offer:
		return 1.0
	return Pricing.accept_chance(asked, int(job.get("budget", 1)), int(Game.state["reputation"]))


## Asking too much gets a counter-offer the first times, which the slider moves to; after that the client walks out.
func _shake_on_it() -> void:
	if _done:
		return
	var asked := int(_price.value)
	var budget := int(job.get("budget", 1))
	var rng := Game.day_rng(hash(job.get("id", "")) + asked + _patience * 7919)
	if rng.randf() <= _chance(asked):
		job["asked"] = asked
		job["expected"] = Pricing.expectation(asked, budget)
		_take()
		return
	Audio.ui("nope")
	_patience -= 1
	if _patience > 0:
		_offer = maxi(budget, int(round(lerpf(budget, asked, 0.35))))
		_speech.text = "\"%d d? No, no. I could go to %d d, and that's generous.\"" % [asked, _offer]
		_price.value = _offer
		_update_price()
		return
	_done = true
	_speech.text = "\"%d d? That's twice now. I'll try the workshop up on the hill.\"" % asked
	Story.refuse(Game.state, job)
	Saves.save()
	for c in _buttons.get_children():
		c.queue_free()
	_price.editable = false
	Ui.button(_buttons, "Back to the job board", func() -> void: Nav.go("job_board"), "arrow_l", true).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _take() -> void:
	_done = true
	Audio.ui("coins", -8.0)
	Game.state["active_job"] = job
	Game.state["board"] = (Game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return j.get("id", "") != job.get("id", ""))
	Saves.save()
	if job.get("kind", "") == "restoration":
		Nav.go("floor", {"job": job})
	else:
		Nav.go("design_table", {"job": job})


func _decline() -> void:
	Story.refuse(Game.state, job)
	Saves.save()
	Nav.go("job_board")
