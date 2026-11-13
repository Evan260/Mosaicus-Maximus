class_name SettingsPanel
extends PanelContainer
## Settings in four tabs, Sound, Display, Gameplay and Keys, opened from the title and the workshop.

const UI_SIZES := {-1: "Smaller", 0: "Normal", 1: "Larger", 2: "Largest"}
const TABS := ["Sound", "Display", "Gameplay", "Keys"]
## The page's width, and the most it grows downwards before it scrolls, so changing tab never makes the window jump.
const WIDTH := 270.0
const TALLEST := 196.0

## Each language's name in that language, for the language list.
const NATIVE_NAMES := {"en": "English", "fr": "Français", "de": "Deutsch", "es": "Español", "it": "Italiano", "pt_BR": "Português (BR)",
	"pl": "Polski", "tr": "Türkçe", "ru": "Русский", "uk": "Українська", "ja": "日本語", "ko": "한국어", "zh_CN": "简体中文", "zh_TW": "繁體中文"}

## The keys each screen reads, under the screen's heading.
const KEYS := [
	["Everywhere", [["Close a window or go back", "Esc"], ["Full screen", "F11"]]],
	["At the design table", [["Undo", "Ctrl+Z"], ["Redo", "Ctrl+Y"], ["Turn a quarter", "R"], ["Mirror it", "F"],
		["Add a mirrored copy on the other side of the room", "M"], ["Take it off the floor", "Delete"], ["Make it bigger or smaller", "+  -"]]],
	["On the floor", [["Smaller or bigger brush", "[  ]"], ["Next stone", "Tab"], ["Pick a stone in the tray", "1 - 9"],
		["Show or hide the chalk sketch", "C"]]],
]
## What only a controller does, listed under the keys while one is plugged in.
const PAD_ONLY := ["With a controller", [["Move the pointer", "pad_lstick"], ["Click, or hold to drag", "pad_a"],
	["Scroll a list, zoom, or size a motif", "pad_dpad_updown", "pad_rstick"]]]

## The tab last open, shown again the next time the window opens.
static var tab := "Sound"

var _in_game := false
var _tabs := {}
var _scroll: ScrollContainer
var _page: VBoxContainer
var _head: Control
var _tab_row: Control


static func open(parent: Control, in_game: bool = false) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.theme_type_variation = "PagePanel"
	p._in_game = in_game
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	var col := Ui.vbox(self, 3)
	_head = Ui.window_head(col, self, "Settings")
	var row := Ui.tab_row(col)
	_tab_row = row
	for t in TABS:
		_tabs[t] = Ui.tab_button(row, t, func() -> void: _show(t, true))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	_page = Ui.vbox(margin, 4)
	_page.custom_minimum_size.x = _widest()
	if Dev.has("settings-tab"):
		tab = Dev.get_arg("settings-tab")
	_show(tab if tab in TABS else "Sound", true)
	Settings.changed.connect(func() -> void: _show(tab, false))
	Nav.resized.connect(_place)


## Lays out a tab's page, from the top when it is newly opened, or where it was when a setting changed.
func _show(t: String, from_top: bool) -> void:
	tab = t
	for k in _tabs:
		(_tabs[k] as Button).button_pressed = k == t
	var scrolled := 0 if from_top else _scroll.scroll_vertical
	_fill(t)
	_place.call_deferred()
	(func() -> void: _scroll.scroll_vertical = scrolled).call_deferred()


func _fill(t: String) -> void:
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	match t:
		"Sound":
			_sound()
		"Display":
			_display()
		"Gameplay":
			_gameplay()
		"Keys":
			_keys()


## The width of the widest tab's page, which every tab takes, so the window keeps one size as the tabs change.
func _widest() -> float:
	var most := WIDTH
	for t in TABS:
		_fill(t)
		most = maxf(most, _page.get_combined_minimum_size().x)
	return most


func _sound() -> void:
	_slider(tr("Everything"), Settings.master, func(v: float) -> void: Settings.master = v)
	_slider(tr("Music"), Settings.music, func(v: float) -> void: Settings.music = v)
	_slider(tr("Effects"), Settings.effects, func(v: float) -> void: Settings.effects = v)
	var own := Ui.setting(_page, tr("Your own music"), tr("Open folder"), Audio.open_music_folder, WIDTH)
	Ui.tip_on(own, "Music you put in this folder (.ogg, .mp3 or .wav) plays between the game's own tracks.")
	var quiet := {"full": "Full volume", "quieter": "Quieter", "muted": "Muted"}
	Ui.setting(_page, tr("While you use other windows"), tr(quiet.get(Settings.background_sound, "Full volume")), func() -> void:
		Settings.set_value("background_sound", {"full": "quieter", "quieter": "muted"}.get(Settings.background_sound, "full")), WIDTH)


func _display() -> void:
	Ui.setting(_page, tr("Interface size"), tr(UI_SIZES[Settings.ui_scale_step]), Settings.cycle_ui_size, WIDTH)
	Ui.on_off(_page, tr("Full screen (F11)"), Settings.fullscreen, Settings.toggle_fullscreen, WIDTH)


func _gameplay() -> void:
	_languages()
	var notes := Settings.guide and not (_in_game and bool(Game.state.get("guide_off", false)))
	Ui.on_off(_page, tr("Your uncle's notes"), notes, func() -> void:
		if _in_game:
			Game.state["guide_off"] = notes
		Settings.set_value("guide", not notes), WIDTH)
	Ui.on_off(_page, tr("Tips when you point at a button"), Settings.tooltips, func() -> void: Settings.set_value("tooltips", not Settings.tooltips), WIDTH)
	Ui.on_off(_page, tr("Larger text for messages"), Settings.large_text, func() -> void: Settings.set_value("large_text", not Settings.large_text), WIDTH)
	Ui.on_off(_page, tr("Reduced motion"), Settings.reduced_motion, func() -> void: Settings.set_value("reduced_motion", not Settings.reduced_motion), WIDTH)
	Ui.on_off(_page, tr("Show hints on the floor"), Settings.hints, func() -> void: Settings.set_value("hints", not Settings.hints), WIDTH)
	if _in_game:
		Ui.setting(_page, tr("Your dog"), tr("Change"), func() -> void:
			queue_free()
			DogPanel.open(get_parent()), WIDTH)


## Each key in a chip, with the controller button that does the same beside it while a controller is plugged in.
func _keys() -> void:
	var pad := Pad.connected()
	for group in KEYS:
		Ui.label(_page, tr(group[0]), "Heading", WIDTH)
		for pair in group[1]:
			var chip := _key_row(pair[0])
			var key := Ui.label(chip, tr(pair[1]))
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if pad:
				for glyph in Pad.GLYPHS.get(pair[1], []):
					_glyph(chip, glyph)
	if pad:
		Ui.label(_page, tr(PAD_ONLY[0]), "Heading", WIDTH)
		for row in PAD_ONLY[1]:
			var chip := _key_row(row[0])
			chip.alignment = BoxContainer.ALIGNMENT_CENTER
			for glyph in row.slice(1):
				_glyph(chip, glyph)


## A line of the keys window: what it does on the left, and on the right a chip for the key and button that do it.
func _key_row(what: String) -> HBoxContainer:
	var row := Ui.hbox(_page, 6)
	var l := Ui.label(row, tr(what), "", WIDTH - 76.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := Ui.panel(row, "SlotPanel")
	chip.custom_minimum_size.x = 70
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.hbox(chip, 2)


func _glyph(parent: Control, glyph: String) -> void:
	var t := Ui.texture(parent, PadGlyph.picture(glyph))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Keeps the window centred, with its page as tall as fits the interface.
func _place() -> void:
	if not is_inside_tree():
		return
	var box := get_theme_stylebox("panel")
	var chrome := _head.get_combined_minimum_size().y + _tab_row.get_combined_minimum_size().y + 6.0 + box.get_minimum_size().y
	_scroll.custom_minimum_size = Vector2(0, minf(TALLEST, Nav.ui_size().y - 8.0 - chrome))
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()


## Every translated language, named in its own words and letters, so a player can find theirs whatever is showing.
func _languages() -> void:
	var locales := TranslationServer.get_loaded_locales()
	if locales.size() < 2:
		return
	Ui.label(_page, tr("Language"), "Heading")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_page.add_child(grid)
	var order := NATIVE_NAMES.keys().filter(func(loc: String) -> bool: return loc in locales)
	var now := UiTheme.language()
	for loc in order:
		var b := Ui.button(grid, NATIVE_NAMES[loc], func() -> void:
			if loc != now:
				Settings.set_language(loc))
		b.toggle_mode = true
		b.button_pressed = loc == now
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size.x = 86
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiTheme.body_font(loc))
		b.add_theme_font_size_override("font_size", UiTheme.text_size(loc))


## A volume slider with its name on the left and how loud it is on the right.
func _slider(label: String, value: float, apply: Callable) -> void:
	var row := Ui.hbox(_page, 6)
	Ui.label(row, label).custom_minimum_size.x = 76
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(120, 16)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(s)
	var amount := Ui.label(row, "%d%%" % roundi(value * 100.0))
	amount.custom_minimum_size.x = 28
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		amount.text = "%d%%" % roundi(v * 100.0)
		apply.call(v)
		Settings.apply()
		Settings.save(false))
