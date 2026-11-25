extends "res://tests/test_case.gd"
## Phones and tablets: the interface's scale and insets, fingertip targets, held fingers, pinches, the back gesture and
## the keyboard.


func test_phones_draw_the_interface_as_large_as_it_fits() -> void:
	check(Nav.phone_ui_scale(Vector2(2424, 1080), 0) == 4, "a Pixel 9a draws the interface at four times, 606 by 270")
	check(Nav.phone_ui_scale(Vector2(2424, 1080), 2) == 4, "Larger can't push it past what fits")
	check(Nav.phone_ui_scale(Vector2(2424, 1080), -1) == 3, "Smaller still makes it smaller")
	check(Nav.phone_ui_scale(Vector2(2560, 1600), 0) == 5, "a 16:10 tablet draws it at five times")
	check(Nav.phone_ui_scale(Vector2(2048, 1536), 0) == 4, "a 4:3 tablet at four times")
	check(Nav.phone_ui_scale(Vector2(1212, 540), 0) == 2, "the phone preview at twice")


func test_the_interface_clears_the_camera_and_rounded_corners() -> void:
	var insets: Array = Nav.phone_insets(Vector2(2424, 1080), Rect2(136, 0, 2288, 1080), 4)
	check(insets[0] == Vector2(34, 0), "the left clears the camera cutout: %s" % insets[0])
	check(insets[1] == Vector2(10, 0), "the right clears the rounded corners: %s" % insets[1])
	insets = Nav.phone_insets(Vector2(2048, 1536), Rect2(0, 0, 2048, 1536), 4)
	check(insets[0].x == insets[1].x and insets[0].x > 0.0, "a tablet keeps the same room at both sides: %s" % [insets])


func test_a_fingertip_target_is_about_seven_millimetres() -> void:
	check(Nav.touch_px_for(420.0, 4) == 29, "a Pixel 9a's fingertip is 29 interface pixels at four times: %d" % Nav.touch_px_for(420.0, 4))
	check(Nav.touch_px_for(420.0, 3) > Nav.touch_px_for(420.0, 4), "a smaller interface needs more of its pixels for the same finger")
	check(Nav.preview_dpi(Vector2(1212, 540), 2) == 210.0, "the phone preview reads as a Pixel 9a")
	check(Nav.touch_px_for(Nav.preview_dpi(Vector2(1024, 768), 2), 2) < 24, "a tablet preview reads as a tablet, whose pixels are larger")


func test_a_finger_held_still_asks_rather_than_taps() -> void:
	check(not Touch.is_hold(0.2, 0.0, 30.0), "a quick touch is a tap")
	check(Touch.is_hold(0.5, 10.0, 30.0), "a finger resting in place for half a second is held")
	check(not Touch.is_hold(0.5, 60.0, 30.0), "a finger that slid away is not held")
	check(Touch.is_tap(5.0, 30.0, false), "a short touch that stayed put taps")
	check(not Touch.is_tap(5.0, 30.0, true), "lifting a held finger does not tap as well")
	check(not Touch.is_tap(60.0, 30.0, false), "a finger slid away does not tap")


func test_a_tip_on_a_phone_leaves_out_its_key() -> void:
	check(Touch.drop_key_hint("Turn a quarter (R)") == "Turn a quarter", "a letter key goes")
	check(Touch.drop_key_hint("Undo (Ctrl+Z)") == "Undo", "a shortcut goes")
	check(Touch.drop_key_hint("Bigger brush ( ] )") == "Bigger brush", "a bracket key goes")
	check(Touch.drop_key_hint("White marble (1)") == "White marble", "a stone's number key goes")
	check(Touch.drop_key_hint("全屏（F11）") == "全屏", "a key in full-width brackets goes")
	check(Touch.drop_key_hint("Lay it (in half-size tiles)") == "Lay it (in half-size tiles)", "words in brackets stay")
	check(Touch.drop_key_hint("No key here") == "No key here", "a tip without a key is left alone")


func test_the_back_gesture_steps_back_one_place() -> void:
	check(Touch.back_from("title") == "background", "on the title the game is put away")
	check(Touch.back_from("workshop") == "title", "the workshop goes back to the title")
	check(Touch.back_from("client_visit") == "job_board", "a client's visit goes back to the job board, without turning the job down")
	check(Touch.back_from("reveal") == "carry_on" and Touch.back_from("day_end") == "carry_on", "the reveal and the day's end carry on, as their one button does")


func test_one_finger_brushes_only_once_it_moves_or_rests() -> void:
	check(not Touch.brush_starts(0.03, 2.0, 30.0), "a finger just down waits, in case a second one follows for a pinch")
	check(Touch.brush_starts(0.03, 40.0, 30.0), "a finger that sweeps away brushes at once")
	check(Touch.brush_starts(Touch.BRUSH_WAIT, 0.0, 30.0), "a finger resting a moment brushes where it rests")


func test_two_fingers_pan_and_zoom_about_their_middle() -> void:
	var view := Vector2(1200, 540)
	var moved: Array = Touch.pinch_camera(Vector2(500, 300), 2.0, view, Vector2(400, 200), Vector2(600, 200), Vector2(430, 200), Vector2(630, 200), 0.2, 6.0)
	check(moved[1] == 2.0 and (moved[0] as Vector2).is_equal_approx(Vector2(485, 300)), "two fingers sliding together pan the floor with them: %s" % [moved])
	var a := Vector2(300, 250)
	var b := Vector2(500, 250)
	var spread: Array = Touch.pinch_camera(Vector2(500, 300), 2.0, view, a, b, a - Vector2(100, 0), b + Vector2(100, 0), 0.2, 6.0)
	check(is_equal_approx(spread[1], 4.0), "spreading the fingers to twice as far apart zooms in twice: %s" % spread[1])
	var before := Vector2(500, 300) + ((a + b) * 0.5 - view * 0.5) / 2.0
	var after: Vector2 = spread[0] + ((a + b) * 0.5 - view * 0.5) / float(spread[1])
	check(before.is_equal_approx(after), "the point between the fingers stays under them: %s, %s" % [before, after])
	var far: Array = Touch.pinch_camera(Vector2.ZERO, 5.0, view, a, b, a - Vector2(400, 0), b + Vector2(400, 0), 0.2, 6.0)
	check(far[1] == 6.0, "the zoom stops at the floor's closest")
	check(is_equal_approx(Touch.pinch_factor(a, b, a - Vector2(50, 0), b + Vector2(50, 0)), 1.5), "the pinch's factor is how much farther apart the fingers are")


func test_a_motifs_corners_are_a_fingertip_without_hiding_its_middle() -> void:
	check(Touch.handle_reach(true, 0.0, 40.0) == PlanView.HANDLE and Touch.handle_reach(false, 0.0, 40.0) == PlanView.HANDLE, "a mouse keeps the small corners")
	check(Touch.handle_reach(false, 29.0, 12.0) == 14.5, "beside a small motif a finger finds its corner from half a fingertip away")
	check(Touch.handle_reach(true, 29.0, 12.0) == 5.0, "inside a small motif the corners stay small, so it can still be dragged")
	check(Touch.handle_reach(true, 29.0, 200.0) == 14.5, "inside a large motif they are a fingertip")


func test_a_text_field_rises_above_the_keyboard() -> void:
	check(Touch.clear_keyboard(100.0, 60.0, 80.0, INF) == 100.0, "with no keyboard nothing moves")
	check(Touch.clear_keyboard(100.0, 60.0, 80.0, 150.0) == 66.0, "the window rises until the field shows just above the keyboard")
	check(Touch.clear_keyboard(100.0, 60.0, 80.0, 400.0) == 100.0, "a field already above the keyboard stays where it is")
	check(Touch.clear_keyboard(100.0, 60.0, 80.0, 30.0) == -54.0, "a keyboard up high lifts the field near the top")
	check(Touch.clear_keyboard(100.0, 60.0, 80.0, 10.0) == -58.0, "but the field never rises past the top of the screen")


func test_a_phones_buttons_are_a_fingertip_tall() -> void:
	check(UiTheme.button_pad_for(0, 12.0) == 4, "a computer keeps the buttons' own padding")
	check(UiTheme.button_pad_for(29, 12.0) == 9, "a phone pads a line of text to a fingertip")
	check(UiTheme.button_pad_for(10, 12.0) == 4, "and never pads less than a computer does")


func test_a_phones_interface_size_only_goes_smaller() -> void:
	check(Settings.next_ui_step(0, true) == -1 and Settings.next_ui_step(-1, true) == 0, "a phone switches between Normal and Smaller")
	check(Settings.next_ui_step(2, true) == -1, "a size kept from Larger goes to Smaller")
	check(Settings.next_ui_step(0) == 1 and Settings.next_ui_step(2) == -1, "a computer still steps through all four")


## Turns the phone preview on at a phone's shape, and returns what to put back.
func _as_phone(window: Vector2i) -> Array:
	var was := [Nav.phone, Nav.phone_preview, get_window().size]
	Nav.phone = true
	Nav.phone_preview = true
	get_window().size = window
	Nav.refit()
	UiTheme.fit_touch()
	return was


func _back_from_phone(was: Array) -> void:
	Nav.phone = was[0]
	Nav.phone_preview = was[1]
	get_window().size = was[2]
	Nav.refit()
	UiTheme.fit_touch()
	Nav.go("title")
	await _settle()


func _settle() -> void:
	await get_tree().process_frame
	while Nav._busy:
		await get_tree().process_frame
	for k in 3:
		await get_tree().process_frame


## Every button showing under `root` that is smaller than a fingertip, by name and size.
func _small_buttons(root: Node) -> Array:
	var finger := float(Nav.touch_px())
	var small := []
	for b: BaseButton in root.find_children("*", "BaseButton", true, false):
		if not b.is_visible_in_tree():
			continue
		var s := b.get_global_rect().size
		if s.x < finger - 0.5 or s.y < finger - 0.5:
			small.append("%s %s '%s'" % [b.get_class(), s, b.text if b is Button else ""])
	return small


func test_every_button_on_a_phone_is_a_fingertip() -> void:
	Game.new_game("Fingers")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	Story.unlock(Game.state, 3)
	var was := _as_phone(Vector2i(1212, 540))
	check(Nav.touch_px() == 29, "the preview's fingertip is 29 interface pixels (%d)" % Nav.touch_px())
	for screen in ["title", "workshop", "job_board", "design_table", "floor", "town_map", "library"]:
		Nav.go(screen, {"free": true} if screen == "design_table" else {})
		await _settle()
		if screen == "floor":
			while Nav.current.floor_view == null:
				await get_tree().process_frame
			await _settle()
		if screen == "design_table":
			Nav.current._add_motif("dolphin", Vector2(Nav.current.design.w, Nav.current.design.h) * 0.5)
			for k in 4:
				await get_tree().process_frame
		var small := _small_buttons(Nav.ui)
		check(small.is_empty(), "every button on the %s is a fingertip on a phone (%s)" % [screen, ", ".join(small.slice(0, 6))])
		if screen == "workshop":
			for open in [func() -> Control: return SettingsPanel.open(Nav.current._root, true),
					func() -> Control: return ChaptersPanel.open(Nav.current._root),
					func() -> Control: return DogPanel.open(Nav.current._root)]:
				var panel: Control = open.call()
				Nav.current._show_panel(panel)
				for k in 3:
					await get_tree().process_frame
				small = _small_buttons(panel)
				check(small.is_empty(), "every button in the %s is a fingertip (%s)" % [panel.get_class(), ", ".join(small.slice(0, 6))])
				var inside := Rect2(Vector2.ZERO, Nav.ui_size()).grow(0.5).encloses(Rect2(panel.position, panel.size))
				check(inside, "the %s fits the phone's screen: %s in %s" % [panel.get_class(), Rect2(panel.position, panel.size), Nav.ui_size()])
				Nav.close_top()
				await get_tree().process_frame
	await _back_from_phone(was)


func test_desktop_only_choices_are_hidden_on_a_phone() -> void:
	var was := _as_phone(Vector2i(1212, 540))
	Nav.go("title")
	await _settle()
	var texts := Nav.ui.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(not "Quit" in texts, "a phone's title has no Quit")
	var settings := SettingsPanel.open(Nav.ui)
	await get_tree().process_frame
	texts = settings.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(not "Keys" in texts, "a phone has no keys to list")
	for tab in ["Sound", "Display"]:
		settings._show(tab, true)
		await get_tree().process_frame
		var words := settings.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		check(not words.has("Full screen (F11)") and not words.has("Your own music") and not words.has("While you use other windows"), "the %s tab leaves out full screen, the music folder and other windows" % tab)
	settings.queue_free()
	await _back_from_phone(was)


func test_a_phone_links_the_privacy_policy_in_the_settings() -> void:
	var tab: String = SettingsPanel.tab
	var opener: Callable = SettingsPanel.open_url
	var opened := []
	SettingsPanel.open_url = func(url: String) -> void: opened.append(url)
	SettingsPanel.tab = "Gameplay"
	var settings := SettingsPanel.open(Nav.ui)
	await get_tree().process_frame
	check(_setting_button(settings, "Privacy policy") == null, "a computer's settings look as they always have, with no privacy policy")
	settings.queue_free()
	var was := _as_phone(Vector2i(1212, 540))
	settings = SettingsPanel.open(Nav.ui)
	await get_tree().process_frame
	var link := _setting_button(settings, "Privacy policy")
	check(link != null and link.text == tr("Open"), "a phone's gameplay settings link the privacy policy, as the stores ask")
	if link:
		link.pressed.emit()
	check(opened == ["https://evan260.github.io/slowsunday/privacy.html"], "which opens the policy's page: %s" % [opened])
	settings.queue_free()
	SettingsPanel.open_url = opener
	SettingsPanel.tab = tab
	await _back_from_phone(was)


## The button beside a setting's name, or null when the settings show no such row.
func _setting_button(settings: Control, text: String) -> Button:
	for l: Label in settings.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion() and l.text == tr(text):
			for b in l.get_parent().get_children():
				if b is Button:
					return b
	return null


func test_two_fingers_on_the_floor_zoom_without_laying_and_one_finger_lays() -> void:
	Game.new_game("Pinch")
	Game.state["guide_off"] = true
	var was := _as_phone(Vector2i(1212, 540))
	Nav.go("floor")
	await _settle()
	while Nav.current.floor_view == null:
		await get_tree().process_frame
	await _settle()
	var floor_screen: Node = Nav.current
	var fv: FloorView = floor_screen.floor_view
	var mid := Vector2(get_window().size) * 0.5
	# The stone of the tile under the middle of the screen, which the finger sweeps over after the pinch.
	var near := fv.layout.tiles_near(floor_screen._to_world(mid) / FloorView.WORLD, 12.0)
	var stone: int = fv.layout.stone[near[0]] if not near.is_empty() else fv.stones_used()[0]
	floor_screen.select_stone(stone)
	var left := fv.stone_unplaced(stone)
	var zoom: float = floor_screen.cam.zoom.x
	_touch(0, mid - Vector2(40, 0), true)
	await get_tree().process_frame
	_touch(1, mid + Vector2(40, 0), true)
	for i in range(1, 6):
		_drag(0, mid - Vector2(40 + i * 12, 0))
		_drag(1, mid + Vector2(40 + i * 12, 0))
		await get_tree().process_frame
	_touch(0, mid - Vector2(100, 0), false)
	_touch(1, mid + Vector2(100, 0), false)
	await get_tree().process_frame
	check(floor_screen.cam.zoom.x > zoom * 2.0, "spreading two fingers zooms the floor in (%.2f to %.2f)" % [zoom, floor_screen.cam.zoom.x])
	check(fv.stone_unplaced(stone) == left, "and lays nothing where the first finger touched down")
	_touch(0, mid, true)
	for i in range(1, 8):
		_drag(0, mid + Vector2(i * 10, 0))
		await get_tree().process_frame
	_touch(0, mid + Vector2(70, 0), false)
	await get_tree().process_frame
	check(fv.stone_unplaced(stone) < left, "one finger sweeping lays tiles")
	await _back_from_phone(was)


func test_the_back_gesture_closes_then_leaves() -> void:
	Game.new_game("Back")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	var was := _as_phone(Vector2i(1212, 540))
	var saving := Saves.enabled
	Saves.enabled = false
	Nav.go("workshop")
	await _settle()
	Nav.current._show_panel(SettingsPanel.open(Nav.current._root, true))
	await get_tree().process_frame
	Nav.back_gesture()
	await get_tree().process_frame
	check(Nav.current_name == "workshop" and not Nav.window_open(), "the first back closes the open window and stays in the workshop")
	Nav.back_gesture()
	await _settle()
	check(Nav.current_name == "title", "the next back goes to the title")
	Saves.enabled = saving
	await _back_from_phone(was)


func test_two_fingers_on_the_plan_size_the_picked_motif() -> void:
	Game.new_game("Plan")
	Game.state["guide_off"] = true
	var was := _as_phone(Vector2i(1212, 540))
	Nav.go("design_table", {"free": true})
	await _settle()
	var table: Node = Nav.current
	table._add_motif("rosette", Vector2(table.design.w, table.design.h) * 0.5)
	for k in 6:
		await get_tree().process_frame
	var size := float(table.design.placements[0]["size"])
	var plan: Control = table._plan
	var mid := plan.get_global_transform_with_canvas() * (plan.size * 0.5)
	_touch(0, mid - Vector2(20, 0), true)
	await get_tree().process_frame
	_touch(1, mid + Vector2(20, 0), true)
	await get_tree().process_frame
	for i in range(1, 6):
		_drag(0, mid - Vector2(20 + i * 8, 0))
		_drag(1, mid + Vector2(20 + i * 8, 0))
		await get_tree().process_frame
	_touch(0, mid - Vector2(60, 0), false)
	_touch(1, mid + Vector2(60, 0), false)
	for k in 3:
		await get_tree().process_frame
	var p: Dictionary = table.design.placements[0]
	check(float(p["size"]) > size * 1.5, "spreading two fingers on the plan makes the picked motif bigger (%.0f to %.0f)" % [size, float(p["size"])])
	check(Vector2(float(p["x"]), float(p["y"])) == Vector2(table.design.w, table.design.h) * 0.5, "and leaves it where it was")
	table._undo_step()
	check(float(table.design.placements[0]["size"]) == size, "one undo takes the whole pinch back")
	await _back_from_phone(was)


func test_a_finger_held_on_a_button_shows_its_tip_without_pressing_it() -> void:
	var was := _as_phone(Vector2i(1212, 540))
	var hits := [0]
	var b := Ui.button(Nav.ui, "Go", func() -> void: hits[0] += 1)
	Ui.tip_on(b, "Goes somewhere (G)")
	b.position = Vector2(100, 100)
	await get_tree().process_frame
	var at := b.get_global_transform_with_canvas() * (b.size * 0.5)
	_touch(0, at, true)
	await get_tree().create_timer(Touch.HOLD_SECONDS + 0.2).timeout
	check(Tips._panel.visible and Tips._label.text == "Goes somewhere", "a held finger shows the button's tip, without its key: '%s'" % Tips._label.text)
	_touch(0, at, false)
	await get_tree().process_frame
	check(hits[0] == 0, "and lifting it does not press the button")
	_touch(0, at, true)
	await get_tree().process_frame
	_touch(0, at, false)
	await get_tree().process_frame
	check(hits[0] == 1, "a quick tap still presses it")
	b.queue_free()
	await _back_from_phone(was)


func test_a_finger_scrolls_a_list_without_pressing_what_it_began_on() -> void:
	var was := _as_phone(Vector2i(1212, 540))
	var hits := [0]
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 40)
	scroll.size = Vector2(120, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Nav.ui.add_child(scroll)
	var list := Ui.vbox(scroll, 2)
	for k in 12:
		Ui.button(list, "Row %d" % k, func() -> void: hits[0] += 1).custom_minimum_size.x = 100
	for k in 3:
		await get_tree().process_frame
	var first: Button = list.get_child(0)
	var at := first.get_global_transform_with_canvas() * (first.size * 0.5)
	_touch(0, at, true)
	for i in range(1, 7):
		await get_tree().process_frame
		_drag(0, at - Vector2(0, i * 12))
	await get_tree().process_frame
	_touch(0, at - Vector2(0, 72), false)
	for k in 2:
		await get_tree().process_frame
	check(scroll.scroll_vertical > 20, "dragging a finger up the list scrolls it (%d)" % scroll.scroll_vertical)
	check(hits[0] == 0, "and presses neither the button it began on nor the one it ended on")
	scroll.queue_free()
	await _back_from_phone(was)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = at
	t.pressed = down
	Input.parse_input_event(t)


func _drag(index: int, at: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = at
	Input.parse_input_event(d)
