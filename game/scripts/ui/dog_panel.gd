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
