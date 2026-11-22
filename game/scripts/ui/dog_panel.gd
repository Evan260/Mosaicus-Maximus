class_name DogPanel
extends PanelContainer
## Changing the workshop dog from the settings: breed, coat and name.


static func open(parent: Control) -> DogPanel:
	var p := DogPanel.new()
	p.theme_type_variation = "PagePanel"
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	var col := Ui.vbox(self, 4)
	Ui.window_head(col, self, "Your dog")
	var chooser := DogChooser.make(Game.state.get("dog", {}))
	col.add_child(chooser)
	var row := Ui.hbox(col, 4)
	var ok := Ui.button(row, "That's my dog", func() -> void:
		Game.state["dog"] = chooser.chosen()
		Saves.save()
		Nav.go("workshop"), "tick", true)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()


## While a phone's keyboard is up, the window rises until the dog's name being typed shows above it.
func _process(_delta: float) -> void:
	if Nav.phone:
		Ui.clear_keyboard(self, floorf((Nav.ui_size().y - size.y) * 0.5))
