class_name DogChooser
extends HBoxContainer
## Choosing the workshop dog: its breed, its coat and its name, with the dog wagging in a little window beside them.

signal changed(dog: Dictionary)

var dog := {}
var _view: DogView
var _breed_label: Label
var _coat_label: Label
var _coat_row: HBoxContainer
var _controls: VBoxContainer
var _name: LineEdit


static func make(start: Dictionary) -> DogChooser:
	var c := DogChooser.new()
	c.dog = start.duplicate()
	if not c.dog.has("breed"):
		c.dog = {"breed": "hound", "coat": "golden", "name": ""}
	c._build()
	return c


func _build() -> void:
	add_theme_constant_override("separation", 6)
	var window := Ui.panel(self, "SlotPanel")
	window.custom_minimum_size = Vector2(120, 58)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(116, 54)
	window.add_child(holder)
	_view = DogView.make(dog)
	holder.add_child(_view)
	_view.play("happy")
	_view.position = Vector2(28, -8)
	_controls = Ui.vbox(self, 3)
	_controls.custom_minimum_size.x = 112
	_breed_label = _chooser(func(by: int) -> void: _step_breed(by))
	_coat_label = _chooser(func(by: int) -> void: _step_coat(by))
	_coat_row = _coat_label.get_parent() as HBoxContainer
	_name = LineEdit.new()
	_name.max_length = 14
	_name.text = str(dog.get("name", ""))
	_name.custom_minimum_size = Vector2(112, 20)
	_name.text_changed.connect(func(t: String) -> void:
		dog["name"] = t.strip_edges()
		changed.emit(dog))
	_controls.add_child(_name)
	_refresh()


## The dog's name as typed, or the suggested one shown faded in the box when it was left empty.
func chosen() -> Dictionary:
	var out := dog.duplicate()
	if str(out.get("name", "")) == "":
		out["name"] = _suggested()
	return out


func _suggested() -> String:
	return DogView.NAMES[hash(str(dog["breed"]) + str(dog["coat"])) % DogView.NAMES.size()]


func _chooser(step: Callable) -> Label:
	var row := Ui.hbox(_controls, 2)
	Ui.icon_button(row, "arrow_l", "", func() -> void: step.call(-1)).custom_minimum_size = Vector2(18, 18)
	var label := Ui.label(row, "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.icon_button(row, "arrow_r", "", func() -> void: step.call(1)).custom_minimum_size = Vector2(18, 18)
	return label


func _step_breed(by: int) -> void:
	var keys := DogView.BREEDS.keys()
	var i := posmod(keys.find(dog["breed"]) + by, keys.size())
	dog["breed"] = keys[i]
	dog["coat"] = DogView.coats_for(keys[i]).keys()[0]
	_refresh()


func _step_coat(by: int) -> void:
	var keys := DogView.coats_for(dog["breed"]).keys()
	dog["coat"] = keys[posmod(keys.find(dog["coat"]) + by, keys.size())]
	_refresh()


func _refresh() -> void:
	_breed_label.text = DogView.BREEDS[dog["breed"]]
	var coats := DogView.coats_for(dog["breed"])
	_coat_label.text = coats.get(dog["coat"], "")
	for c in _coat_row.get_children():
		if c is Button:
			(c as Button).disabled = coats.size() < 2
	_name.placeholder_text = _suggested()
	_view.set_look(dog["breed"], dog["coat"])
	_view.play("happy")
	var size := _view.texture.get_size()
	_view.position = (Vector2(116, 54) - size) * 0.5 + Vector2(0, -6)
	_view.position = _view.position.floor()
	changed.emit(dog)
