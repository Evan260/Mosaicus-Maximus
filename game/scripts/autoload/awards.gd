extends CanvasLayer
## Achievements as they are earned: a parchment card with a laurel slides in at the top right on any screen, one after
## another and only once no window is open, stays five seconds unless clicked away, and each is handed to Steam when the
## game runs through Steam. Earned ones live in the save, so ones earned without Steam are sent the next time it is there.
## It also keeps the player's Steam rich presence, what friends see they are doing, from tools/steam/rich_presence.vdf.

const HOLD := 5.0
const CHECK_EVERY := 1.0

var _steam: Object = null
var _root: Control
var _queue: Array = []
var _card: PanelContainer
var _tween: Tween
var _wait := 0.0
## Set while a card waits for the open windows to close, so only one wait runs at a time.
var _held := false
## The rich presence last given to Steam, so Steam hears only of a change.
var _presence := {}


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
		var steam := Engine.get_singleton("Steam")
		var started: Dictionary = steam.call("steamInitEx")
		# Status 0 is a running Steam client that owns the game; any other leaves achievements in the save.
		if int(started.get("status", -1)) == 0:
			_steam = steam
		else:
			print_verbose("Steam is not available: ", started.get("verbal", ""))
	Nav.screen_changed.connect(func(_s: String) -> void: _sync())


func _fit() -> void:
	var k := Nav.scale_factor()
	transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)


func _process(delta: float) -> void:
	if _steam:
		_steam.call("run_callbacks")
	_wait += delta
	if _wait < CHECK_EVERY:
		return
	_wait = 0.0
	_update_presence()
	if str(Game.state.get("name", "")) == "" or Dev.has("run-tests") or Dev.has("achievement"):
		return
	for a in Achievements.check(Game.state):
		_unlock_on_steam(str(a["id"]))
		_queue.append(a)
		if _card == null:
			_next()


## Sends every achievement in the save to Steam, so ones earned before Steam was available still count.
func _sync() -> void:
	for id in Game.state.get("achievements", []):
		_unlock_on_steam(str(id))


## Tells Steam what the player is doing, only when it has changed, and never without Steam running.
func _update_presence() -> void:
	if _steam == null or not may_send():
		return
	var now := presence(Nav.current_name, Nav._args, Game.state)
	if now == _presence:
		return
	_presence = now
	_steam.call("clearRichPresence")
	for key in now:
		_steam.call("setRichPresence", key, now[key])


## What Steam shows friends: a `steam_display` token from tools/steam/rich_presence.vdf, with the words it fills in.
static func presence(screen: String, args: Dictionary, st: Dictionary) -> Dictionary:
	var job: Dictionary = args.get("job", {})
	if bool(args.get("free", false)) or bool(job.get("free", false)):
		return {"steam_display": "#Status_FreeDesign"}
	match screen:
		"", "title":
			return {"steam_display": "#Status_Title"}
		"library":
			return {"steam_display": "#Status_Library"}
		"town_map":
			return {"steam_display": "#Status_Town"}
		"design_table", "floor":
			match str(job.get("kind", "commission")):
				"restoration":
					return {"steam_display": "#Status_Restoring"}
				"contest":
					return {"steam_display": "#Status_Contest"}
				"panel":
					return {"steam_display": "#Status_Panel"}
			var tokens := ["#Status_Designing", "#Status_DesigningAny"] if screen == "design_table" else ["#Status_Laying", "#Status_LayingAny"]
			var who := first_name(job)
			if who == "":
				return {"steam_display": tokens[1]}
			return {"steam_display": tokens[0], "client": who}
	if str(st.get("name", "")) == "":
		return {"steam_display": "#Status_Title"}
	return {"steam_display": "#Status_Workshop", "day": str(int(st.get("day", 1)))}


## A client's own name, the same in every language, since Steam fills it into each language's words as it is.
static func first_name(job: Dictionary) -> String:
	var id := str(job.get("client", ""))
	if id != "":
		return id.capitalize()
	var named: Variant = job.get("client_name", "")
	if named is Dictionary and str(named.get("say", "")) in ["%s, %s", "%s, a collector"]:
		return str(named["args"][0])
	return ""


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


## Slides in the next card waiting, once no window is open, since a card would cover the window.
func _next() -> void:
	if _queue.is_empty() or _held:
		return
	if Nav.window_open():
		_held = true
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			_held = false
			if _card == null:
				_next())
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
	Audio.play("coins", -10.0)
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
