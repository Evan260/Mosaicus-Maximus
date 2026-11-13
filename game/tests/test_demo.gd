extends "res://tests/test_case.gd"
## The demo's limits: it plays the first two chapters, shows its end card once where chapter 3 would open, says "In the
## full game" for what lies past it, and its workshop opens the next chapter at once in the full game.

var game: Node = Game


func test_the_demo_stops_where_chapter_3_would_open() -> void:
	game.acts_as_demo = true
	game.new_game("Demo")
	var st: Dictionary = game.state
	check(game.last_chapter() == 2 and game.in_full_game(3) and not game.in_full_game(2), "the demo plays chapters 1 and 2")
	st["reputation"] = int(Data.chapter(2)["reputation"])
	var events := Story.check_chapters(st)
	check(int(st["chapter"]) == 2 and events.size() == 1 and events[0]["kind"] == "chapter", "chapter 2 opens in the demo as usual")
	check(Story.next_chapter_line(st).contains("finishes the demo"), "and says how much more reputation finishes the demo")
	st["reputation"] = int(Data.chapter(3)["reputation"]) + 5
	events = Story.check_chapters(st)
	check(int(st["chapter"]) == 2, "chapter 3 never opens in the demo")
	check(events.size() == 1 and events[0]["kind"] == "demo_end", "reaching it brings the demo's end card")
	check(Story.check_chapters(st).is_empty(), "and only once")
	check(Story.next_chapter_line(st) == "Chapter 3 is in the full game", "after which chapter 3 reads as in the full game")
	check(not "pink_marble" in st["unlocked_stones"] and not "lion" in st["unlocked_motifs"], "no chapter 3 stone or pattern is unlocked")
	Story.unlock(st, 4)
	check(int(st["chapter"]) == 2 and not "gold" in st["unlocked_stones"], "nothing can unlock past the demo, not even a dev option")
	game.acts_as_demo = false
	events = Story.check_chapters(st)
	check(int(st["chapter"]) == 3 and events.size() == 1 and events[0]["kind"] == "chapter", "the same workshop in the full game opens chapter 3 at once")


func test_the_demo_never_offers_what_lies_past_it() -> void:
	game.acts_as_demo = true
	game.new_game("Demo")
	var st: Dictionary = game.state
	Story.unlock(st, 2)
	st["day"] = 9
	var rng := RandomNumberGenerator.new()
	for i in 40:
		rng.seed = i
		var job := JobFactory.restoration(st, rng)
		check(int(Data.motif(str(job.get("discovery", "rosette"))).get("tier", 1)) <= 2, "a dig in the demo hides no pattern from past it (seed %d)" % i)
		st.erase("ship")
		st["day"] = 9 + i * 3
		Story._ship(st, rng)
		if st.has("ship"):
			check(Stones.LIST[Stones.index(st["ship"]["stone"])]["tier"] <= 2, "a ship in the demo brings no stone from past it (seed %d)" % i)
	check(DemoEnd.store_app_id() == 0 and DemoEnd.wishlist_button(null) == null, "the wishlist button hides while the game has no App ID")
	game.acts_as_demo = false


func test_free_design_in_the_demo_keeps_to_its_chapters() -> void:
	game.acts_as_demo = true
	game.new_game("Demo")
	Nav.go("design_table", {"free": true})
	while Nav.current_name != "design_table" or Nav._busy:
		await get_tree().process_frame
	var table: Node = Nav.current
	check(not "gold" in table._stones_allowed() and "red_marble" in table._stones_allowed(), "the demo's free design has the demo's stones only")
	check(not "lion" in table._motifs_allowed() and "dolphin" in table._motifs_allowed(), "and its patterns")
	check(not table._fine_open(), "and no small tiles, which chapter 3 brings")
	check(table._locked_tip(3) == "In the full game", "a later pattern says it is in the full game")
	game.acts_as_demo = false
	check(table._fine_open() and "gold" in table._stones_allowed(), "the full game's free design has everything")
	check(str(table._locked_tip(3)) != "In the full game", "and a locked pattern there names its chapter")
	Nav.go("title")
	while Nav._busy:
		await get_tree().process_frame


func test_the_end_card_shows_once_and_is_not_kept_as_a_letter() -> void:
	game.acts_as_demo = true
	game.new_game("Demo")
	game.state["guide_off"] = true
	game.state["story_seen"].append("intro")
	Story.unlock(game.state, 2)
	game.state["reputation"] = int(Data.chapter(3)["reputation"])
	Nav.go("workshop")
	while Nav.current_name != "workshop" or Nav._busy:
		await get_tree().process_frame
	await get_tree().process_frame
	var cards := Nav.ui.find_children("*", "DemoEnd", true, false)
	check(cards.size() == 1, "the workshop shows the demo's end card")
	check(Nav.window_open(), "as a window, which Escape closes")
	Nav.close_top()
	await get_tree().process_frame
	check(Nav.ui.find_children("*", "DemoEnd", true, false).filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).is_empty(), "Carry on closes it")
	check((game.state["pending_events"] as Array).is_empty(), "it waits in the save no longer")
	check((game.state["letters"] as Array).all(func(e: Dictionary) -> bool: return e.get("kind", "") != "demo_end"), "and is not kept with the letters")
	check(bool(game.state["demo_over"]), "the workshop remembers the demo is over")
	game.acts_as_demo = false
	Nav.go("title")
	while Nav._busy:
		await get_tree().process_frame
