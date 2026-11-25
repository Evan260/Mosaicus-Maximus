extends "res://tests/test_case.gd"
## Layouts that hold on every screen, interface and text size and language: the reveal's floor and wrapped list lines.

## Computer windows: 720p, the Steam Deck, a 1366 by 768 laptop, the game's own window, 1080p, 16:10, 21:9, 1440p, 4K.
const DESKTOP := [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1366, 768), Vector2i(1440, 810), Vector2i(1920, 1080),
	Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
## Phones (16:9, 20:9, the preview, the iPhone) and tablets (16:9, 16:10, 4:3, the 13 inch iPad, the 4:3 preview).
const PHONE := [Vector2i(1920, 1080), Vector2i(2424, 1080), Vector2i(1212, 540), Vector2i(2868, 1320), Vector2i(2560, 1440),
	Vector2i(2560, 1600), Vector2i(2048, 1536), Vector2i(2752, 2064), Vector2i(1024, 768)]
const BULLETS := "•·●▪"


func test_the_reveal_shows_the_whole_floor_beside_the_card() -> void:
	var was := [get_window().size, Nav.phone, Nav.phone_preview, Settings.ui_scale_step, Settings.large_text]
	for phone in [false, true]:
		Nav.phone = phone
		Nav.phone_preview = phone
		for loc in ["en", "de", "ru"]:
			TranslationServer.set_locale(loc)
			UiTheme.use_language()
			# The bedroom is painted; the temple has no painting yet, so its floor shows alone in its walls.
			for room in ["bedroom", "temple"]:
				get_window().size = Vector2i(1920, 1080)
				Settings.ui_scale_step = 0
				Nav.refit()
				await _open_reveal(room)
				var reveal: Node = Nav.current
				var bad := []
				for wh in (PHONE if phone else DESKTOP):
					for step in ([-1, 0] if phone else [-1, 0, 1, 2]):
						for large in [false, true]:
							get_window().size = wh
							Settings.ui_scale_step = step
							Settings.large_text = large
							Nav.refit()
							UiTheme.fit_touch()
							for k in 2:
								await get_tree().process_frame
							var where := "%s size %d%s" % [wh, step, " large text" if large else ""]
							var card: Control = reveal._card
							var held := card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
							var shown := _floor_on_screen(reveal)
							var ui := float(Nav.scale_factor())
							var screen := Rect2(Nav.safe_top_left * ui, Nav.ui_size() * ui)
							if shown.intersects(held):
								bad.append("%s: the card %s covers the floor %s" % [where, held, shown])
							if not screen.grow(0.5).encloses(shown):
								bad.append("%s: the floor %s reaches past the screen %s" % [where, shown, screen])
							if reveal._room:
								var t: Transform2D = reveal._room.get_global_transform_with_canvas()
								var k := t.get_scale().x
								if k < 1.0 or absf(k - roundf(k)) > 0.001 or absf(t.origin.x - roundf(t.origin.x)) > 0.01 or absf(t.origin.y - roundf(t.origin.y)) > 0.01:
									bad.append("%s: the room is drawn %.3f times at %s, not a whole number of screen pixels" % [where, k, t.origin])
				var what := "%s in %s on a %s" % ["the bedroom" if room == "bedroom" else "a floor with no painted room", loc, "phone" if phone else "computer"]
				check(bad.is_empty(), "the reveal shows the whole floor clear of the card for %s (%d problems: %s)" % [what, bad.size(), "; ".join(bad.slice(0, 3))])
				var unhung := _unhung_lines(Nav.ui)
				check(unhung.is_empty(), "the reveal's checklist hangs its wrapped lines in %s: %s" % [loc, unhung])
	get_window().size = was[0]
	Nav.phone = was[1]
	Nav.phone_preview = was[2]
	Settings.ui_scale_step = was[3]
	Settings.large_text = was[4]
	TranslationServer.set_locale("en")
	UiTheme.use_language()
	Nav.refit()
	UiTheme.fit_touch()
	Nav.go("title")
	await _settle()


func test_wrapped_list_lines_hang_under_their_words() -> void:
	var was := [get_window().size, Settings.large_text]
	get_window().size = Vector2i(1920, 1080)
	Nav.refit()
	var wrapped := {}
	for loc in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(loc)
		UiTheme.use_language()
		for large in [false, true]:
			Settings.large_text = large
			Game.new_game("Lists")
			Game.state["story_seen"].append("intro")
			Game.state["guide_off"] = true
			var job := _long_notices()
			for screen in ["job_board", "client_visit", "design_table"]:
				Nav.go(screen, {} if screen == "job_board" else {"job": job})
				await _settle()
				var unhung := _unhung_lines(Nav.ui)
				check(unhung.is_empty(), "every wrapped line on the %s in %s%s starts under its words, not its bullet: %s" % [screen, loc, " with large text" if large else "", unhung])
				var wine := TranslationServer.translate(Brief.wish_key("tag", "wine"))
				for l: Label in Nav.ui.find_children("*", "Label", true, false):
					if l.is_visible_in_tree() and l.text.contains(wine) and l.get_line_count() > 1:
						wrapped[loc] = true
	check(wrapped.has("de") and wrapped.has("ru"), "the wine wish wraps in German and Russian, so the lines above were really checked wrapping: %s" % [wrapped.keys()])
	get_window().size = was[0]
	Settings.large_text = was[1]
	TranslationServer.set_locale("en")
	UiTheme.use_language()
	Nav.refit()
	Nav.go("title")
	await _settle()


## Opens the reveal of a floor in `room` for a commission, once its floor is laid out and its card has slid in.
func _open_reveal(room: String) -> void:
	Game.new_game("Reveal")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	var job := Dev.test_job("commission")
	Nav.go("reveal", {"design": Samples.moved(Samples.make("villa"), room), "job": job})
	await _settle()
	while Nav.current._card == null:
		await get_tree().process_frame
	for k in 3:
		await get_tree().process_frame
	for t in get_tree().get_processed_tweens():
		t.custom_step(100.0)
	await get_tree().process_frame


## The finished floor's rectangle in screen pixels: its shape in the painted room, or the floor and walls shown alone.
func _floor_on_screen(reveal: Node) -> Rect2:
	if reveal._room:
		var shape: ColorRect = reveal._room.find_children("*", "ColorRect", false, false)[0]
		return shape.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, shape.size)
	var f: FloorView = reveal._floor
	var wall := Vector2.ONE * FloorView.WALL * f.tile_world()
	return f.get_global_transform_with_canvas() * Rect2(-wall, f.size_world() + wall * 2.0)


## Pins up a festival commission with long wishes and a restoration hiding a pattern, and returns the commission.
func _long_notices() -> Dictionary:
	var job := Dev.test_job("commission")
	job["brief"] = {"tags": ["wine", "feast", "guard", "myth"], "ban_stones": ["black_stone"]}
	job["festival"] = "vinalia"
	var dig := Dev.test_job("restoration")
	dig["discovery"] = "dolphin"
	Game.state["board"] = [job, dig]
	Game.state["board_day"] = Game.state["day"]
	return job


## Each wrapped list line under `root` whose later lines start under its bullet, or whose bullet leaves its first line.
func _unhung_lines(root: Node) -> Array:
	var bad := []
	for l: Label in root.find_children("*", "Label", true, false):
		if not l.is_visible_in_tree() or l.is_queued_for_deletion():
			continue
		var text := l.text.strip_edges()
		if text.length() > 1 and BULLETS.contains(text.left(1)) and l.get_line_count() > 1:
			bad.append(text.left(40))
		elif text.length() == 1 and BULLETS.contains(text):
			var words := l.get_parent().get_child(l.get_index() + 1) as Label if l.get_index() + 1 < l.get_parent().get_child_count() else null
			if words == null or words.get_global_rect().position.x < l.get_global_rect().end.x:
				bad.append("a bullet with no words to its right")
			elif absf(l.get_global_rect().position.y - words.get_global_rect().position.y) > 0.5:
				bad.append("the bullet of '%s' below its first line" % words.text.left(30))
	return bad


func _settle() -> void:
	await get_tree().process_frame
	while Nav._busy:
		await get_tree().process_frame
	for k in 3:
		await get_tree().process_frame
