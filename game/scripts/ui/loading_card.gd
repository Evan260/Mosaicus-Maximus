class_name LoadingCard
extends Control
## A small card in the middle of the screen while something slow is worked out, with a row of tiles ticking along.

var _label: Label
var _card: PanelContainer
var _dots: Array[ColorRect] = []
var _t := 0.0


func show_text(text: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "PagePanel"
	add_child(card)
	_card = card
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	card.add_child(col)
	_label = Label.new()
	_label.theme_type_variation = "Heading"
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	col.add_child(row)
	var colours := [Color8(50, 46, 48), Color8(240, 234, 222), Color8(172, 88, 56), Color8(206, 152, 70), Color8(50, 96, 150), Color8(226, 186, 82)]
	for c in colours:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(5, 5)
		r.color = c
		row.add_child(r)
		_dots.append(r)
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	var s := Nav.ui_size()
	size = s
	_card.reset_size()
	_card.position = ((s - _card.size) * 0.5).floor()


func _process(delta: float) -> void:
	_t += delta
	for i in _dots.size():
		_dots[i].modulate.a = 0.35 + 0.65 * maxf(0.0, sin(_t * 5.0 - i * 0.7))
