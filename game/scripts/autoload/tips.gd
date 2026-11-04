extends CanvasLayer
## Tooltips drawn in the interface's own pixels, so they grow with the window like everything else.
## A control asks for one with Ui.tip(control, text); the text is read every frame, so it can change while shown.

const DELAY := 0.35
const WRAP := 170.0

var _root: Control
var _panel: PanelContainer
var _label: Label
var _owner: Control
var _wait := 0.0


func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.theme = UiTheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = Ui.panel(_root, "TipPanel")
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Ui.label(_panel, "", "LightLabel")
	_panel.visible = false
	Nav.resized.connect(_fit)
	_fit()


func _fit() -> void:
	var k := Nav.scale_factor()
	transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)


func _process(delta: float) -> void:
	var owner := _tip_owner(get_viewport().gui_get_hovered_control())
	if owner == null or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or get_viewport().gui_is_dragging():
		_owner = null
		_panel.visible = false
		_wait = 0.0
		return
	if owner != _owner:
		_owner = owner
		_wait = 0.0
		_panel.visible = false
	_wait += delta
	if _wait < DELAY:
		return
	_show(str(owner.get_meta("tip")))


func _tip_owner(c: Control) -> Control:
	var n: Node = c
	for i in 4:
		if not n is Control:
			return null
		if n.has_meta("tip") and str(n.get_meta("tip")) != "" and (n as Control).is_visible_in_tree():
			return n
		n = n.get_parent()
	return null


func _show(text: String) -> void:
	var lines := _wrap(text)
	if _label.text != lines or not _panel.visible:
		_label.text = lines
		_panel.visible = true
		_panel.reset_size()
	var mouse := Nav.to_ui(get_viewport().get_mouse_position())
	var room := Nav.ui_size()
	var pos := mouse + Vector2(8, 12)
	if pos.x + _panel.size.x > room.x - 2:
		pos.x = mouse.x - _panel.size.x - 4
	if pos.y + _panel.size.y > room.y - 2:
		pos.y = mouse.y - _panel.size.y - 4
	_panel.position = pos.max(Vector2(2, 2)).floor()


## Breaks a tip into lines by hand, since a wrapping label in a self-sizing panel measures itself before it has a width.
func _wrap(text: String) -> String:
	var font := UiTheme.body_font()
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TEXT).x > WRAP:
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return "\n".join(out)
