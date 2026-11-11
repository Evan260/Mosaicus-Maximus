class_name UiTheme
## The interface's look: pixel fonts drawn without smoothing, and panels and buttons from the art in assets/ui.

const DIR := "res://assets/ui/"
const INK := Color8(58, 38, 30)
const CREAM := Color8(242, 230, 204)
const MUTED := Color8(140, 110, 84)
const GOLD := Color8(236, 196, 96)
const RED := Color8(168, 52, 44)
const GREEN := Color8(78, 110, 52)
const WAX_LO := Color8(68, 44, 32)
## Languages Silkscreen has every letter for; the rest draw their headings in the body font.
const SILKSCREEN := ["en", "fr", "de", "es", "it", "pt"]
## Languages drawn in Fusion Pixel's 8-pixel Chinese, Japanese and Korean fonts, whose Latin letters match them.
const HAN := {"ja": "ja", "ko": "ko", "zh_CN": "zh_hans", "zh_TW": "zh_tw"}
const FONTS := "res://assets/fonts/"

static var _theme: Theme
## Each language's fonts, made once and kept, since text drawn with a font that is then thrown away shows as blocks.
static var _bodies := {}
static var _titles := {}


## The font for running text in the current language, or in the language given.
static func body_font(locale: String = "") -> Font:
	var loc := _locale(locale)
	if not _bodies.has(loc):
		var ten := _crisp(load(FONTS + "fusion-pixel-10px-proportional-latin.ttf.woff2"))
		if HAN.has(loc):
			var han := _crisp(load(FONTS + "fusion-pixel-8px-proportional-%s.ttf.woff2" % HAN[loc]))
			han.fallbacks = [ten]
			_bodies[loc] = han
		else:
			_bodies[loc] = ten
	return _bodies[loc]


## Silkscreen, the blocky capitals used for headings, where it has the language's letters; otherwise the body font.
static func title_font(locale: String = "") -> Font:
	var loc := _locale(locale)
	if not loc.get_slice("_", 0) in SILKSCREEN:
		return body_font(loc)
	if not _titles.has(loc):
		var f := _crisp(load(FONTS + "Silkscreen-Regular.ttf"))
		f.fallbacks = [body_font(loc)]
		_titles[loc] = f
	return _titles[loc]


## The pixel size running text is drawn at, which is the size its pixel font is drawn for.
static func text_size(locale: String = "") -> int:
	return 8 if HAN.has(_locale(locale)) else 10


## A heading's pixel size, or twice that for a title: Silkscreen is drawn at 8, other fonts at their own size.
static func heading_size(big: bool = false) -> int:
	var n := 8 if _locale("").get_slice("_", 0) in SILKSCREEN else text_size()
	return n * 2 if big else n


## The language showing now, as the game names its translations: "zh_CN" for any simplified Chinese.
static func language() -> String:
	return _locale("")


static func _locale(locale: String) -> String:
	var loc := locale if locale != "" else TranslationServer.get_locale()
	if loc.begins_with("zh"):
		return "zh_TW" if loc.contains("TW") or loc.contains("Hant") or loc.contains("HK") else "zh_CN"
	return loc


static func icon(name: String) -> Texture2D:
	var path := DIR + "icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func panel(name: String, margin: int, content: int = -1) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(DIR + name + ".png")
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	var c := margin if content < 0 else content
	s.content_margin_left = c
	s.content_margin_right = c
	s.content_margin_top = c
	s.content_margin_bottom = c
	return s


static func build() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	_set_fonts(t)
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 0)
	for state in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		t.set_stylebox(state[0], "Button", panel(state[1], 5, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color8(120, 110, 100))
	t.set_constant("h_separation", "Button", 3)
	t.set_type_variation("MainButton", "Button")
	for state in [["normal", "button_main"], ["hover", "button_main_hover"], ["pressed", "button_main_pressed"], ["disabled", "button_disabled"]]:
		t.set_stylebox(state[0], "MainButton", panel(state[1], 5, 4))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "MainButton", CREAM)
	for variant in [["BoardPanel", "board", 8, 9], ["TabletPanel", "tablet", 8, 9], ["PagePanel", "page", 6, 8], ["CardPanel", "card", 5, 5], ["TipPanel", "tooltip", 4, 4], ["SlotPanel", "slot", 3, 2]]:
		t.set_type_variation(variant[0], "PanelContainer")
		t.set_stylebox("panel", variant[0], panel(variant[1], variant[2], variant[3]))
	t.set_type_variation("Heading", "Label")
	t.set_color("font_color", "Heading", INK)
	t.set_type_variation("LightLabel", "Label")
	t.set_color("font_color", "LightLabel", CREAM)
	t.set_type_variation("LightHeading", "Label")
	t.set_color("font_color", "LightHeading", GOLD)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_stylebox("panel", "TooltipPanel", panel("tooltip", 4, 4))
	t.set_color("font_color", "TooltipLabel", CREAM)
	var grab := load(DIR + "icons/coin.png") as Texture2D
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_stylebox("slider", "HSlider", strip("track"))
	t.set_stylebox("grabber_area", "HSlider", strip("track_fill"))
	t.set_stylebox("grabber_area_highlight", "HSlider", strip("track_fill"))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("font_selected_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.5))
	t.set_stylebox("normal", "LineEdit", panel("slot", 3, 4))
	t.set_stylebox("focus", "LineEdit", panel("slot_focus", 3, 4))
	t.set_color("caret_color", "LineEdit", INK)
	for state in ["normal", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckButton", _padded(StyleBoxEmpty.new()))
	for state in ["hover", "hover_pressed"]:
		t.set_stylebox(state, "CheckButton", panel("row_hover", 3, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", INK)
	for icon_name in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		t.set_icon(icon_name, "CheckButton", load(DIR + "toggle_on.png"))
	for icon_name in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		t.set_icon(icon_name, "CheckButton", load(DIR + "toggle_off.png"))
	t.set_constant("h_separation", "CheckButton", 6)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _flat(Color(WAX_LO, 0.35), 2))
		t.set_stylebox("scroll_focus", bar, _flat(Color(WAX_LO, 0.35), 2))
		t.set_stylebox("grabber", bar, _flat(Color8(124, 84, 50), 2))
		t.set_stylebox("grabber_highlight", bar, _flat(Color8(150, 104, 64), 2))
		t.set_stylebox("grabber_pressed", bar, _flat(Color8(176, 128, 82), 2))
	_theme = t
	return t


## Switches the shared theme to the current language's fonts; every control drawn with it follows.
static func use_language() -> void:
	if _theme:
		_set_fonts(_theme)


static func _set_fonts(t: Theme) -> void:
	t.default_font = body_font()
	t.default_font_size = text_size()
	for v in ["Heading", "LightHeading"]:
		t.set_font("font", v, title_font())
		t.set_font_size("font_size", v, heading_size())


## A slider's groove: stretched along its length, six pixels tall.
static func strip(name: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(DIR + name + ".png")
	s.texture_margin_left = 3
	s.texture_margin_right = 3
	s.texture_margin_top = 2
	s.texture_margin_bottom = 2
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.content_margin_left = 0
	s.content_margin_right = 0
	return s


## A plain rounded bar, for scroll bars: thin enough at the interface's scale to stay out of the way.
static func _flat(c: Color, thick: int) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = c
	f.set_corner_radius_all(1)
	f.content_margin_left = thick
	f.content_margin_right = thick
	f.content_margin_top = thick
	f.content_margin_bottom = thick
	return f


static func _padded(s: StyleBox) -> StyleBox:
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func _crisp(source: FontFile) -> FontFile:
	var font: FontFile = source.duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
