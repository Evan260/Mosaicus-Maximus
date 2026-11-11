extends Node
## The end of the day: a wax tablet with the day's takings and costs, and a line of town gossip.


func enter(_args: Dictionary) -> void:
	var t := Story.end_day(Game.state)
	Story.morning(Game.state)
	Saves.save()
	var root := Ui.panel(Nav.ui, "TabletPanel")
	var col := Ui.vbox(root, 4)
	var head := Ui.label(col, tr("The end of day %d") % int(t["day"]), "LightHeading")
	head.add_theme_font_size_override("font_size", UiTheme.heading_size(true))
	for line in [["Earned", t["earned"]], ["Spent", t["spent"]], ["Wages", t["wages"]]]:
		var r := Ui.hbox(col, 4)
		Ui.label(r, str(line[0]), "LightLabel").custom_minimum_size.x = 80
		Ui.label(r, Ui.coins_text(int(line[1])), "LightLabel")
	var purse := Ui.hbox(col, 4)
	Ui.icon(purse, "coin")
	Ui.label(purse, tr("%s in the purse") % Ui.coins_text(int(t["coins"])), "LightLabel")
	var rep := Ui.hbox(col, 4)
	Ui.icon(rep, "laurel")
	Ui.label(rep, tr("Reputation %d") % int(t["reputation"]), "LightLabel")
	var ahead := Story.next_chapter_line(Game.state)
	if ahead != "":
		Ui.label(col, ahead, "LightLabel", 240)
	if str(t.get("gossip", "")) != "":
		Ui.label(col, "In the tavern tonight:", "LightHeading")
		Ui.label(col, str(t["gossip"]), "LightLabel", 240)
	Ui.button(col, tr("Sleep, and start day %d") % (int(t["day"]) + 1), func() -> void: Nav.go("workshop"), "sun", true)
	var place := func() -> void:
		root.reset_size()
		root.position = ((Nav.ui_size() - root.size) * 0.5).floor()
	Nav.resized.connect(place)
	place.call_deferred()
	Audio.play("page_turn", -6.0)
