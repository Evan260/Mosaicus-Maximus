extends CanvasLayer
## Achievements as they are earned: a parchment card with a laurel slides in at the top right on any screen, one after
## another, stays five seconds unless clicked away, and each is handed to Steam when the game runs through Steam. Earned
## ones live in the save, so ones earned without Steam are sent the next time it is there.

const HOLD := 5.0
const CHECK_EVERY := 1.0

var _steam: Object = null
var _root: Control
var _queue: Array = []
var _card: PanelContainer
var _tween: Tween
var _wait := 0.0


func _ready() -> void:
	layer = 58
	_root = Control.new()
	_root.theme = UiTheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	Nav.resized.connect(_fit)
	_fit()
	# GodotSteam adds a "Steam" singleton; without it (the editor, or a build outside Steam) achievements stay in the save.
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		_steam.call("steamInit")
	Nav.screen_changed.connect(func(_s: String) -> void: _sync())


func _fit() -> void:
	var k := Nav.scale_factor()
	transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)


func _process(delta: float) -> void:
	if _steam:
		_steam.call("run_callbacks")
	_wait += delta
	if _wait < CHECK_EVERY or str(Game.state.get("name", "")) == "" or Dev.has("run-tests") or Dev.has("achievement"):
		return
	_wait = 0.0
	for a in Achievements.check(Game.state):
		_unlock_on_steam(str(a["id"]))
		_queue.append(a)
		if _card == null:
			_next()


## Sends every achievement in the save to Steam, so ones earned before Steam was available still count.
func _sync() -> void:
	for id in Game.state.get("achievements", []):
		_unlock_on_steam(str(id))


## Only a real workshop sends achievements: never one made up by a test or a dev option such as --max-state.
func may_send() -> bool:
	return Saves.enabled and not Dev.has("panel") and not Dev.has("achievement") and not Game.state.get("_dev", false)


## Shows an achievement's card in turn with any others waiting, without earning it.
func show_card(a: Dictionary) -> void:
	_queue.append(a)
	if _card == null:
		_next()


func _unlock_on_steam(id: String) -> void:
	if _steam and may_send():
		_steam.call("setAchievement", id)
		_steam.call("storeStats")


func _next() -> void:
	if _queue.is_empty():
		return
	var a: Dictionary = _queue.pop_front()
	_card = Ui.panel(_root, "PagePanel")
	var row := Ui.hbox(_card, 6)
	Ui.icon(row, "laurel")
	var col := Ui.vbox(row, 0)
	Ui.label(col, "Achievement", "MutedLabel")
	var big := Settings.message_scale()
	Ui.label(col, tr(str(a["name"])), "Heading", 150 * big).add_theme_font_size_override("font_size", UiTheme.heading_size() * big)
	Ui.label(col, tr(str(a["text"])), "", 150 * big).add_theme_font_size_override("font_size", UiTheme.text_size() * big)
	_card.reset_size()
	var s := Nav.ui_size()
	var shown := Vector2(s.x - _card.size.x - 6, 46)
	_card.position = shown if Settings.reduced_motion else Vector2(s.x + 4, shown.y)
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_leave(0.0))
	Audio.ui("coins", -10.0)
	_tween = _card.create_tween()
	if not Settings.reduced_motion:
		_tween.tween_property(_card, "position", shown, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_leave(HOLD)


## Slides the card back out after `wait` seconds, or at once when it is clicked, and brings on the next.
func _leave(wait: float) -> void:
	if wait == 0.0:
		_tween.kill()
		_tween = _card.create_tween()
	var card := _card
	_tween.tween_interval(wait)
	if not Settings.reduced_motion:
		_tween.tween_property(card, "position:x", Nav.ui_size().x + 4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		card.queue_free()
		if _card == card:
			_card = null
			_next())
