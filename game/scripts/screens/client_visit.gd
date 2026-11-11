extends Node
## The client at the counter: what they want, and the price. Slide the coins to set your price and watch their face.

const JobBoard := preload("res://scripts/screens/job_board.gd")

var job := {}
var _root: Control
var _desk: PanelContainer
var _card: PanelContainer
var _speech: Label
var _price: HSlider
var _price_label: Label
var _mood: Label
var _expect: Label
var _shake: Button
var _buttons: HBoxContainer
var _wishes: ScrollContainer
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
	_desk = Ui.panel(_root, "BoardPanel")
	_card = Ui.panel(_root, "PagePanel")
	var row := Ui.hbox(_card, 8)
	var left := Ui.vbox(row, 4)
	left.add_child(JobBoard._portrait(job.get("portrait", ""), 64))
	Ui.label(left, Ui.text(job.get("client_name", "")), "Heading", 90)
	var room := Data.room(job.get("room", ""))
	Ui.label(left, tr("%s, %d by %d tiles") % [Data.room_title(job.get("room", "")), int(room.get("w", 0)), int(room.get("h", 0))], "MutedLabel", 90)
	var right := Ui.vbox(row, 4)
	var bubble := Ui.panel(right, "CardPanel")
	_speech = Ui.label(bubble, _opening_line(), "", 290)
	var she: bool = JobFactory.pronouns(job)["he"] == "she"
	if kind == "commission":
		var wishes := Brief.score(job.get("brief", {}), FloorDesign.new())["wishes"] as Array
		if not wishes.is_empty():
			Ui.label(right, "What she wants" if she else "What he wants", "Heading", 290)
		_wishes = ScrollContainer.new()
		_wishes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(_wishes)
		var list := Ui.vbox(_wishes, 1)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for w in wishes:
			Ui.tip_on(Ui.label(list, "• " + str(w["text"]), "", 290), Brief.help(w, Game.state["unlocked_motifs"]))
		var known := Story.known_taste(Game.state, job)
		if not known.is_empty() and not bool(job.get("taste_said", false)):
			Ui.label(list, (tr("From your notebook: she %s.") if she else tr("From your notebook: he %s.")) % Looks.tastes_words(known), "MutedLabel", 290)
		_wishes.visible = list.get_child_count() > 0
	elif kind == "copy":
		var sketch := TextureRect.new()
		sketch.texture = ImageTexture.create_from_image(Composer.picture(FloorDesign.from_dict(job["target"]), 3))
		sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sketch.custom_minimum_size = Vector2(150, 76)
		right.add_child(sketch)
		Ui.label(right, "She pays for likeness: the closer the copy, the more." if she else "He pays for likeness: the closer the copy, the more.", "MutedLabel", 290)
	var budget := int(job.get("budget", 0))
	if kind == "contest":
		Ui.label(right, tr("The prize is %s. You pay for your own stone.") % Ui.coins_text(budget), "", 290)
		job["asked"] = 0
		job["expected"] = 0.0
		_shake = Ui.button(right, "Enter the contest", _take, "tick", true)
		Ui.button(right, "Not this time", _decline, "cross")
	elif restore:
		Ui.label(right, (tr("She pays %s, and supplies the stone for any repairs.") if she else tr("He pays %s, and supplies the stone for any repairs.")) % Ui.coins_text(budget), "", 230)
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
	Nav.resized.connect(_place)
	_place.call_deferred()
	Audio.play("rustle", -8.0)
	if str(job.get("kind", "commission")) in ["commission", "copy"]:
		Guide.note("visit", "The client says what she wants. Slide the coins to set your price: the more you ask, the more she expects, and ask too much and she'll haggle. Then shake on it." if she else "The client says what he wants. Slide the coins to set your price: the more you ask, the more he expects, and ask too much and he'll haggle. Then shake on it.", "bottom_right")
	else:
		Guide.note("visit", "Read what's wanted here, then take the job or turn it down.", "bottom_right")


## The card in the middle, with the wish list only as tall as fits, so the price and buttons always show.
func _place() -> void:
	var s := Nav.ui_size()
	_root.size = s
	Ui.put(_desk, Vector2.ZERO, s)
	if _wishes:
		fit_list(_card, _wishes, s.y - 8.0)
	_card.reset_size()
	_card.position = ((s - _card.size) * 0.5).floor()


## Gives a card's scrolling list as many whole lines as fit once the card fits in the height; the rest scroll.
static func fit_list(card: Control, scroll: ScrollContainer, height: float) -> void:
	scroll.custom_minimum_size.y = 0.0
	var spare := height - card.get_combined_minimum_size().y
	var list := scroll.get_child(0) as BoxContainer
	var gap := float(list.get_theme_constant("separation"))
	var shown := 0.0
	var bottom := -gap
	for c in list.get_children():
		bottom += gap + (c as Control).get_combined_minimum_size().y
		if bottom > spare:
			break
		shown = bottom
	scroll.custom_minimum_size.y = shown


func _opening_line() -> String:
	var greeting := Ui.text(job.get("greeting", ""))
	var step := int(job.get("arc_step", -1))
	var line := Ui.text(job.get("line", ""))
	if step == 0 and greeting != "":
		return greeting + "\n\n" + line
	return line


func _update_price() -> void:
	var asked := int(_price.value)
	var budget := int(job.get("budget", 1))
	_price_label.text = Ui.coins_text(asked)
	var chance := _chance(asked)
	var expected := Pricing.expectation(asked, budget)
	if _offer > 0 and asked <= _offer:
		_mood.text = tr("\"%s. That's what I said.\"") % Ui.coins_text(_offer)
	elif chance > 0.85:
		_mood.text = "\"That seems fair.\""
	elif chance > 0.55:
		_mood.text = "\"Hmm. That's more than I'd hoped.\""
	elif chance > 0.25:
		_mood.text = "\"That's a lot of money for a floor.\""
	else:
		_mood.text = "\"You must be joking.\""
	var she: bool = JobFactory.pronouns(job)["he"] == "she"
	if expected > 0.75:
		_expect.text = "At this price she'll expect nearly every wish met." if she else "At this price he'll expect nearly every wish met."
	elif expected > 0.55:
		_expect.text = "At this price she'll expect most of her wishes." if she else "At this price he'll expect most of his wishes."
	else:
		_expect.text = "At this price she'll be happy with a fair attempt." if she else "At this price he'll be happy with a fair attempt."


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
	Audio.play("nope")
	_patience -= 1
	if _patience > 0:
		_offer = maxi(budget, int(round(lerpf(budget, asked, 0.35))))
		_speech.text = tr("\"%s? No, no. I could go to %s, and that's generous.\"") % [Ui.coins_text(asked), Ui.coins_text(_offer)]
		_price.value = _offer
		_update_price()
		_place.call_deferred()
		return
	_done = true
	_speech.text = tr("\"%s? That's twice now. I'll try the workshop up on the hill.\"") % Ui.coins_text(asked)
	Story.refuse(Game.state, job)
	Saves.save()
	for c in _buttons.get_children():
		c.queue_free()
	_price.editable = false
	Ui.button(_buttons, "Back to the job board", func() -> void: Nav.go("job_board"), "arrow_l", true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place.call_deferred()


func _take() -> void:
	if _done:
		return
	_done = true
	Audio.play("coins", -8.0)
	Game.state["active_job"] = job
	Game.state["board"] = (Game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return j.get("id", "") != job.get("id", ""))
	Saves.save()
	if job.get("kind", "") == "restoration":
		Nav.go("floor", {"job": job})
	else:
		Nav.go("design_table", {"job": job})


func _decline() -> void:
	if _done:
		return
	_done = true
	Story.refuse(Game.state, job)
	Saves.save()
	Nav.go("job_board")
