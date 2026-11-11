class_name ChaptersPanel
extends PanelContainer
## Every chapter of the workshop's story, opened from the laurel in the workshop's top bar: the chapters down the left,
## and on the right what the chosen one brings and, for the next one, how close it is.

const DETAIL_WIDTH := 280.0
const LIST_WIDTH := 140.0

var _detail: VBoxContainer


static func open(parent: Control) -> ChaptersPanel:
	var p := ChaptersPanel.new()
	p.theme_type_variation = "PagePanel"
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	var now := int(Game.state["chapter"])
	var body := Ui.hbox(self, 6)
	var list := Ui.vbox(body, 2)
	list.custom_minimum_size.x = LIST_WIDTH
	Ui.label(list, "Chapters", "Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	var start := mini(now + 1, Data.chapters.size())
	for ch in Data.chapters:
		var n := int(ch["n"])
		var b := Ui.button(list, "%d. %s" % [n, tr(ch["title"])], func() -> void: _show(n), "tick" if n < now else "laurel" if n == now else "lock")
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = n == start
	Ui.label(list, "Every finished floor earns reputation, and better floors earn more. Enough reputation opens the next chapter.", "MutedLabel", LIST_WIDTH)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(gap)
	Ui.button(list, "Done", func() -> void: queue_free(), "tick", true)
	var card := Ui.panel(body, "CardPanel")
	_detail = Ui.vbox(card, 1)
	_detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 150)
	_show(start)


func _show(n: int) -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var st := Game.state
	var now := int(st["chapter"])
	var ch := Data.chapter(n)
	Ui.label(_detail, tr("Chapter %d: %s") % [n, tr(ch["title"])], "Heading", DETAIL_WIDTH)
	if n < now:
		Ui.label(_detail, "Done. It brought:", "MutedLabel", DETAIL_WIDTH)
	elif n == now:
		Ui.label(_detail, "You are here. It brought:", "MutedLabel", DETAIL_WIDTH)
	elif n == now + 1:
		var from := int(Data.chapter(now)["reputation"])
		_detail.add_child(_progress(int(st["reputation"]) - from, int(ch["reputation"]) - from))
		Ui.label(_detail, tr("Reputation %d of %d: %d more to go.") % [int(st["reputation"]), int(ch["reputation"]), int(ch["reputation"]) - int(st["reputation"])], "", DETAIL_WIDTH)
		Ui.label(_detail, "It brings:", "MutedLabel", DETAIL_WIDTH)
	else:
		Ui.label(_detail, tr("Opens at %d reputation. It brings:") % int(ch["reputation"]), "MutedLabel", DETAIL_WIDTH)
	for line in Story.chapter_unlocks(n):
		Ui.label(_detail, line, "", DETAIL_WIDTH)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()


func _progress(have: int, need: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(DETAIL_WIDTH, 5)
	bar.max_value = need
	bar.value = clampi(have, 0, need)
	bar.add_theme_stylebox_override("background", _flat(Color8(196, 172, 128)))
	bar.add_theme_stylebox_override("fill", _flat(UiTheme.GOLD))
	return bar


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	return s
