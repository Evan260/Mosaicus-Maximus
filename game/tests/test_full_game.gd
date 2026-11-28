extends "res://tests/test_case.gd"
## The one purchase that opens the whole game on a phone: what the store says decides whether the workshop plays by
## the demo's limits, the answer is kept so it holds without a connection, and a computer sells and locks nothing.

const CACHE := "user://test_store.cfg"
const PRICE := "CA$4.99"
## A reviewer's code of the tests' own, since the game's real one is kept only as a hash.
const REVIEW_CODE := "QX7P-29HD-MM4F"

## What each test listens to on FullGame, let go of when the test is done.
var _listening: Array[Callable] = []


func _full() -> Node:
	return get_tree().root.get_node_or_null("FullGame")


## FullGame with a fake store that has answered nothing yet, and a cache of its own.
func _shop() -> FakeStore:
	var full := _full()
	_forget()
	full.cache_path = CACHE
	var store := FakeStore.new()
	full.use_store(store)
	return store


## FullGame with a fake store, taking the tests' own reviewer code.
func _reviewer_shop() -> FakeStore:
	var store := _shop()
	_full().review_hash = (_full().package_name + ":" + REVIEW_CODE.replace("-", "")).sha256_text()
	return store


func _forget() -> void:
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)


func _done() -> void:
	var full := _full()
	for c in _listening:
		full.finished.disconnect(c)
	_listening.clear()
	full.use_store(null)
	full.cache_path = "user://store.cfg"
	full.review_hash = str(ProjectSettings.get_setting("slowsunday/review_code_sha256", ""))
	_forget()
	for card in Nav.ui.find_children("*", "StoreCard", true, false):
		card.queue_free()
	Game.new_game("Test")


func _results() -> Array:
	var heard := []
	var listen := func(result: String) -> void: heard.append(result)
	_full().finished.connect(listen)
	_listening.append(listen)
	return heard


func test_a_computer_sells_nothing_and_locks_nothing() -> void:
	var full := _full()
	check(full != null, "FullGame is an autoload")
	if full == null:
		return
	check(not Engine.has_singleton("SlowSundayPhone") and not full.sold_here(), "a computer has no store to buy the full game from")
	check(not full.locked() and not Game.is_demo(), "so the full game plays in full")
	var holder := Control.new()
	check(DemoEnd.unlock_button(holder) == null, "and offers no unlock")
	check(DemoEnd.full_game_button(holder) == DemoEnd.wishlist_button(holder), "where the demo stops it offers the Steam wishlist as before")
	holder.free()
	full.buy()
	full.restore()
	check(not full.locked(), "and buying or restoring does nothing at all")


func test_the_store_is_asked_for_the_price_once_it_connects() -> void:
	var store := _shop()
	check(store.calls.has(["billing_start"]), "the store's connection is opened at start")
	check(_full().price() == "", "the price is blank until the store says it")
	store.billing_connected.emit()
	check(store.calls.has(["query_price", "full_game"]), "once connected, the full game's price is asked for")
	store.price_found.emit("full_game", PRICE)
	check(_full().price() == PRICE, "and the store's own price text is kept (%s)" % _full().price())
	store.price_found.emit("other", "CA$1.00")
	check(_full().price() == PRICE, "a price for another product is not taken")
	_done()


func test_the_app_store_sells_it_under_the_games_own_id() -> void:
	var id := "com.slowsunday.example.full_game"
	check(_full().get_script().apple_product("com.slowsunday.example") == id, "the App Store's id is the game's bundle id followed by .full_game")
	var store := _shop()
	_full().use_store(store, id)
	store.billing_connected.emit()
	check(store.calls.has(["query_price", id]), "the App Store is asked for the price under the game's own id")
	store.purchase_finished.emit("full_game", "purchased")
	check(_full().locked(), "Google Play's id opens nothing there")
	store.owned_found.emit(PackedStringArray([id]))
	check(_full().owned() and not _full().locked(), "the game's own id opens the full game")
	_done()


func test_a_pending_purchase_waits_for_the_payment() -> void:
	var store := _shop()
	var heard := _results()
	_full().buy()
	store.purchase_finished.emit("full_game", "pending")
	check(_full().locked(), "a purchase waiting for payment does not unlock anything yet")
	check(heard == ["pending"], "and the game hears that it waits (%s)" % str(heard))
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(not _full().locked(), "once the payment goes through the store lists it and the game opens")
	check(heard == ["pending", "purchased"], "with the thank-you then (%s)" % str(heard))
	_done()


func test_a_cancelled_or_failed_purchase_leaves_it_locked() -> void:
	var store := _shop()
	var heard := _results()
	for status in ["cancelled", "error", "unavailable"]:
		_full().buy()
		store.purchase_finished.emit("full_game", status)
		check(_full().locked(), "a purchase that ended %s leaves the game locked" % status)
	check(heard == ["cancelled", "error", "unavailable"], "and each ending is passed on (%s)" % str(heard))
	store.purchase_finished.emit("other", "purchased")
	check(_full().locked(), "buying some other product unlocks nothing")
	_done()


func test_restoring_asks_the_store_what_was_bought() -> void:
	var store := _shop()
	var heard := _results()
	_full().restore()
	check(store.calls.has(["query_owned"]), "restoring asks the store again what the player owns")
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(not _full().locked() and heard == ["restored"], "a purchase found unlocks the game and says so (%s)" % str(heard))
	store = _shop()
	heard = _results()
	_full().restore()
	store.owned_found.emit(PackedStringArray())
	check(_full().locked() and heard == ["not_found"], "with nothing bought it says none was found (%s)" % str(heard))
	heard.clear()
	_full().restore()
	store.billing_unavailable.emit("Billing service unavailable on device.")
	check(heard == ["unavailable"], "and a store that cannot be reached says that (%s)" % str(heard))
	heard.clear()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(heard.is_empty() and not _full().locked(), "a later answer at start unlocks quietly, as on a new phone")
	_done()


func test_the_answer_is_kept_for_when_the_store_cannot_be_reached() -> void:
	var store := _shop()
	store.purchase_finished.emit("full_game", "purchased")
	check(FileAccess.file_exists(CACHE), "owning the full game is written down")
	var full := _full()
	var offline := FakeStore.new()
	full.use_store(offline)
	offline.billing_unavailable.emit("Network is down")
	check(full.owned() and not full.locked(), "so a later start without a connection still has the full game")
	offline.owned_found.emit(PackedStringArray())
	check(full.locked(), "a store that no longer lists it, as after a refund, locks it again")
	full.use_store(FakeStore.new())
	check(full.locked(), "and that is written down too")
	_done()


func test_not_owned_plays_by_the_demos_limits() -> void:
	var store := _shop()
	check(_full().sold_here() and _full().locked(), "a phone that has not bought the full game is locked")
	check(Game.is_demo(), "so the workshop plays by the demo's limits")
	check(Game.last_chapter() == 2 and Game.in_full_game(3), "the first two chapters, with chapter 3 in the full game")
	Game.new_game("Phone")
	Game.state["reputation"] = int(Data.chapter(3)["reputation"]) + 5
	var events := Story.check_chapters(Game.state)
	check(int(Game.state["chapter"]) == 2 and events.any(func(e: Dictionary) -> bool: return e["kind"] == "demo_end"), "and the demo's end card where chapter 3 would open")
	store.owned_found.emit(PackedStringArray())
	check(_full().locked(), "a store that lists nothing owned keeps it locked")
	_done()


func test_owned_opens_everything() -> void:
	var store := _shop()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(_full().owned() and not _full().locked(), "a store that lists the full game unlocks it")
	check(not Game.is_demo() and Game.last_chapter() == Data.chapters.size(), "and every chapter is open to the workshop")
	_done()


func test_buying_unlocks_at_once_and_keeps_the_workshop() -> void:
	var store := _shop()
	var heard := _results()
	Game.new_game("Phone")
	Story.unlock(Game.state, 2)
	Game.state["reputation"] = int(Data.chapter(3)["reputation"]) + 5
	Game.state["coins"] = 1234
	Story.check_chapters(Game.state)
	check(int(Game.state["chapter"]) == 2 and bool(Game.state.get("demo_over", false)), "the workshop has come as far as the demo goes")
	var workshop := JSON.stringify(Game.to_dict())
	_full().buy()
	check(store.calls.has(["buy", "full_game"]), "buying opens the store's purchase for the full game")
	store.purchase_finished.emit("full_game", "purchased")
	check(_full().owned() and not Game.is_demo(), "a finished purchase opens the full game straight away")
	check(JSON.stringify(Game.to_dict()) == workshop, "with the workshop exactly as it was")
	check(heard == ["purchased"], "and the game hears it was bought, to say thank you (%s)" % str(heard))
	var events := Story.check_chapters(Game.state)
	check(int(Game.state["chapter"]) == 3 and events.size() == 1 and events[0]["kind"] == "chapter", "so chapter 3 opens for it")
	_done()


func test_the_unlock_button_shows_the_price_and_buys() -> void:
	var store := _shop()
	var holder := Control.new()
	var b := DemoEnd.unlock_button(holder)
	check(b != null and b.text == tr("Unlock the full game"), "before the store answers the button has no price (%s)" % (b.text if b else "none"))
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	b = DemoEnd.unlock_button(holder)
	check(b != null and b.text == tr("Unlock the full game: %s") % PRICE, "then it shows the store's price (%s)" % (b.text if b else "none"))
	check(DemoEnd.full_game_button(holder) != null, "a phone that sells the full game offers it where the demo stops")
	if b:
		b.pressed.emit()
	check(store.calls.has(["buy", "full_game"]), "pressing it buys the full game")
	store.purchase_finished.emit("full_game", "purchased")
	check(DemoEnd.unlock_button(holder) == null and DemoEnd.full_game_button(holder) == null, "and once it is owned there is nothing left to offer")
	await get_tree().process_frame
	holder.free()
	_done()


func test_the_title_offers_the_unlock_and_says_thank_you() -> void:
	var store := _shop()
	store.billing_connected.emit()
	await _go("title")
	check(_button(Nav.ui, "Unlock the full game") != null, "before the store says its price the title offers the full game without one")
	# App Review refuses a game that calls itself a demo, so a phone selling the full game never shows the word.
	check(_label(Nav.ui, "Demo") == null, "and does not say Demo where the full game is sold")
	store.price_found.emit("full_game", PRICE)
	await get_tree().process_frame
	var unlock := _button(Nav.ui, "Unlock the full game: %s" % PRICE)
	check(unlock != null, "then with the store's price")
	if unlock:
		unlock.pressed.emit()
	check(store.calls.has(["buy", "full_game"]), "pressing it buys the full game")
	store.purchase_finished.emit("full_game", "purchased")
	await get_tree().process_frame
	check(_button(Nav.ui, "Unlock the full game: %s" % PRICE) == null, "and the title stops offering it once bought")
	check(_label(Nav.ui, "Demo") == null, "and no longer says Demo")
	check(_cards_saying("Thank you for buying the full game!") == 1, "and a card thanks the player")
	_done()


func test_a_phones_title_has_room_for_the_unlock() -> void:
	var store := _shop()
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	var was := [Nav.phone, Nav.phone_preview, get_window().size]
	Nav.phone = true
	Nav.phone_preview = true
	get_window().size = Vector2i(1212, 540)
	Nav.refit()
	UiTheme.fit_touch()
	for n in [1, 2]:
		Game.new_game("Phone %d" % n)
		Saves.save(n)
	await _go("title")
	await get_tree().process_frame
	await get_tree().process_frame
	var unlock := _button(Nav.ui, "Unlock the full game: %s" % PRICE)
	var fresh := _button(Nav.ui, "New workshop")
	check(unlock != null and fresh != null and unlock.get_parent() == fresh.get_parent(), "a phone's title puts the unlock beside New workshop")
	var menu: Control = Nav.current._menu
	check(menu.size.y <= Nav.ui_size().y, "so the menu fits a phone's short screen with two workshops (%d of %d)" % [menu.size.y, Nav.ui_size().y])
	for n in [1, 2]:
		Saves.delete(n)
	Nav.phone = was[0]
	Nav.phone_preview = was[1]
	get_window().size = was[2]
	Nav.refit()
	UiTheme.fit_touch()
	await _go("title")
	_done()


func test_buying_at_the_demos_end_opens_chapter_3_at_once() -> void:
	var store := _shop()
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	Game.new_game("Phone")
	Game.state["guide_off"] = true
	Game.state["story_seen"].append("intro")
	Story.unlock(Game.state, 2)
	Game.state["reputation"] = int(Data.chapter(3)["reputation"])
	await _go("workshop")
	await get_tree().process_frame
	var card := _shown(Nav.ui, "DemoEnd")
	check(card != null, "a locked phone's workshop shows the demo's end card")
	var unlock := _button(card, "Unlock the full game: %s" % PRICE) if card else null
	check(unlock != null, "which offers the full game where the Steam demo asks for a wishlist")
	if unlock:
		unlock.pressed.emit()
	store.purchase_finished.emit("full_game", "purchased")
	await get_tree().process_frame
	check(_shown(Nav.ui, "DemoEnd") == null, "buying it closes the end card")
	check(int(Game.state["chapter"]) == 3, "and opens chapter 3 there and then")
	var pending: Array = Game.state["pending_events"]
	check(not pending.is_empty() and pending[0]["kind"] == "chapter" and int(pending[0]["n"]) == 3 and is_instance_valid(Nav.current._popup), "with its letter showing")
	check(_cards_saying("Thank you for buying the full game!") == 1, "under a card thanking the player")
	Nav.close_top()
	await get_tree().process_frame
	check(_cards_saying("Thank you for buying the full game!") == 0 and is_instance_valid(Nav.current._popup), "which closes first, leaving the letter")
	await _go("title")
	_done()


func test_free_design_offers_everything_once_bought() -> void:
	var store := _shop()
	await _go("design_table", {"free": true})
	var table: Node = Nav.current
	check(not "gold" in table._stones_allowed() and not table._fine_open(), "a locked phone's free design keeps to the demo")
	store.purchase_finished.emit("full_game", "purchased")
	await get_tree().process_frame
	await _go_on("design_table")
	await get_tree().process_frame
	table = Nav.current
	check(table.free and "gold" in table._stones_allowed() and table._fine_open(), "buying lays the table out again with everything")
	check(_cards_saying("Thank you for buying the full game!") == 1, "and the thanks show over it")
	await _go("title")
	_done()


func test_phones_offer_to_restore_a_purchase_in_the_settings() -> void:
	var store := _shop()
	var was: String = SettingsPanel.tab
	SettingsPanel.tab = "Gameplay"
	var panel := SettingsPanel.open(Nav.ui)
	await get_tree().process_frame
	var restore := _button(panel, "Restore purchase")
	check(restore != null and _label(panel, "Already bought the full game?") != null, "a phone that has not bought the full game offers to restore a purchase")
	if restore:
		restore.pressed.emit()
	check(store.calls.has(["query_owned"]), "which asks the store what was bought")
	store.owned_found.emit(PackedStringArray(["full_game"]))
	await get_tree().process_frame
	check(_button(panel, "Restore purchase") == null, "once it is owned the settings stop offering it")
	check(_cards_saying("The full game is unlocked again. Welcome back!") == 1, "and a card says it is unlocked again")
	panel.free()
	SettingsPanel.tab = was
	_done()


func test_each_answer_from_the_store_has_its_message() -> void:
	var store := _shop()
	var said := {
		"pending": "Your purchase is waiting for its payment. The full game opens as soon as it goes through.",
		"error": "The purchase did not go through. Please try again later.",
		"unavailable": "The store cannot be reached right now. Please try again later.",
	}
	for status in said:
		store.purchase_finished.emit("full_game", status)
		check(_cards_saying(said[status]) == 1, "a purchase that ended %s says so" % status)
		Nav.close_top()
		await get_tree().process_frame
	store.purchase_finished.emit("full_game", "cancelled")
	check(_shown(Nav.ui, "StoreCard") == null, "and closing the store's sheet says nothing")
	_full().restore()
	store.owned_found.emit(PackedStringArray())
	check(_cards_saying("No purchase of the full game was found for this account.") == 1, "a restore that finds nothing says so")
	_done()


func test_a_computer_shows_nothing_of_the_store() -> void:
	check(not _full().sold_here(), "a computer has no store")
	await _go("title")
	check(_button(Nav.ui, "Unlock the full game") == null and _label(Nav.ui, "Demo") == null, "so the title offers nothing to buy and is not the demo")
	var was: String = SettingsPanel.tab
	SettingsPanel.tab = "Gameplay"
	var panel := SettingsPanel.open(Nav.ui)
	await get_tree().process_frame
	check(_button(panel, "Restore purchase") == null, "and the settings offer no restore")
	panel.free()
	SettingsPanel.tab = was
	Game.acts_as_demo = true
	await _go("title")
	check(_label(Nav.ui, "Demo") != null and _button(Nav.ui, "Unlock the full game") == null, "the Steam demo is the demo, with no unlock")
	Game.acts_as_demo = false
	await _go("title")


func test_the_game_keeps_only_a_hash_of_its_reviewer_code() -> void:
	var hash := str(ProjectSettings.get_setting("slowsunday/review_code_sha256", ""))
	check(hash.length() == 64 and hash.is_valid_hex_number(), "project.godot holds the SHA-256 of Google Play's reviewer code (%s)" % hash)
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var package := ""
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") == "Android release":
			package = str(presets.get_value(section + ".options", "package/unique_name", ""))
	check(package != "" and _full().package_name == package, "hashed after the package name Google Play knows (%s, %s)" % [_full().package_name, package])


func test_the_reviewer_code_opens_the_full_game_and_is_kept() -> void:
	var store := _reviewer_shop()
	Game.new_game("Reviewer")
	Story.unlock(Game.state, 2)
	Game.state["reputation"] = int(Data.chapter(3)["reputation"]) + 5
	Game.state["coins"] = 1234
	Story.check_chapters(Game.state)
	check(int(Game.state["chapter"]) == 2 and bool(Game.state.get("demo_over", false)), "the workshop has come as far as the demo goes")
	var workshop := JSON.stringify(Game.to_dict())
	check(_full().redeem(REVIEW_CODE), "Google Play's reviewer code is taken")
	check(not _full().locked() and not Game.is_demo(), "and opens the full game at once, as buying it does")
	check(JSON.stringify(Game.to_dict()) == workshop, "with the workshop exactly as it was")
	var events := Story.check_chapters(Game.state)
	check(int(Game.state["chapter"]) == 3 and events.size() == 1 and events[0]["kind"] == "chapter", "so chapter 3 opens for it")
	check(not store.calls.any(func(c: Array) -> bool: return c[0] == "buy"), "and nothing bought")
	_full().use_store(FakeStore.new())
	check(not _full().locked(), "a later start keeps the full game open before the store has said anything")
	_done()


func test_the_app_store_build_has_no_reviewer_code() -> void:
	var store := _reviewer_shop()
	_full().use_store(store, "com.slowsunday.example.full_game")
	var opened := false
	for i in 5:
		opened = _full().review_tap(10.0 + i * 0.1) or opened
	check(not opened, "five quick taps open no code box on the App Store, where Apple allows no way in but buying")
	check(not _full().redeem(REVIEW_CODE) and _full().locked(), "and Google Play's reviewer code opens nothing there")
	_done()


func test_the_reviewer_code_may_be_typed_in_lower_case_with_spaces_or_dashes() -> void:
	for typed in ["qx7p-29hd-mm4f", "QX7P 29HD MM4F", "qx7p29hdmm4f", " Qx7P - 29hD - mM4f "]:
		_reviewer_shop()
		check(_full().redeem(typed) and not _full().locked(), "\"%s\" is taken" % typed)
		_done()


func test_a_wrong_reviewer_code_opens_nothing() -> void:
	_reviewer_shop()
	for typed in ["", "QX7P-29HD-MM4G", "QX7P-29HD", "QX7P-29HD-MM4F-2", "QX7P_29HD_MM4F"]:
		check(not _full().redeem(typed), "\"%s\" is not taken" % typed)
	check(_full().locked() and not FileAccess.file_exists(CACHE), "the game stays locked with nothing written down")
	_full().review_hash = ("com.slowsunday.othergame:" + REVIEW_CODE.replace("-", "")).sha256_text()
	check(not _full().redeem(REVIEW_CODE), "and another game's code is not taken here")
	_done()


func test_the_store_saying_not_owned_never_locks_a_reviewers_phone_again() -> void:
	var store := _reviewer_shop()
	_full().redeem(REVIEW_CODE)
	store.owned_found.emit(PackedStringArray())
	check(not _full().locked(), "the store listing nothing owned, since the reviewer bought nothing, leaves the full game open")
	var later := FakeStore.new()
	_full().use_store(later)
	later.owned_found.emit(PackedStringArray())
	check(not _full().locked() and not Game.is_demo(), "and so does its answer at the next start")
	_done()


func test_only_five_quick_taps_open_the_reviewer_box() -> void:
	_reviewer_shop()
	var full := _full()
	var opened := []
	for i in 5:
		opened.append(full.review_tap(i * 1.0))
	check(not opened.has(true), "five taps a second apart open nothing (%s)" % str(opened))
	opened.clear()
	for t in [10.0, 10.5, 11.0, 11.5]:
		opened.append(full.review_tap(t))
	check(not opened.has(true), "nor do four quick ones (%s)" % str(opened))
	check(full.review_tap(12.5), "a fifth within three seconds opens it")
	check(not full.review_tap(12.6), "and the count starts again after it")
	_done()


func test_five_quick_taps_on_the_version_open_the_reviewer_box() -> void:
	_reviewer_shop()
	var was := await _screen_sized_title()
	_tap_version(4)
	await get_tree().process_frame
	check(_review_box() == null, "four taps on the version number open nothing")
	_tap_version(1)
	await get_tree().process_frame
	var field := _review_box()
	check(field != null, "a fifth within three seconds opens the box for Google Play's reviewer code")
	check(field != null and field.has_focus(), "with the field ready to type in, which brings up a phone's keyboard")
	check(_button(Nav.ui, "OK") != null and _button(Nav.ui, "Cancel") != null, "with OK and Cancel")
	_button(Nav.ui, "Cancel").pressed.emit()
	await get_tree().process_frame
	check(_review_box() == null and _button(Nav.ui, "Unlock the full game") != null, "Cancel goes back to the title's menu")
	await _test_sized_title(was)
	_done()


func test_the_version_opens_no_box_on_a_computer_or_once_the_full_game_is_owned() -> void:
	var was := await _screen_sized_title()
	_tap_version(5)
	await get_tree().process_frame
	check(_review_box() == null, "a computer, which sells nothing, opens no box")
	var store := _reviewer_shop()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	await _go("title")
	_tap_version(5)
	await get_tree().process_frame
	check(_review_box() == null, "nor does a phone that owns the full game")
	await _test_sized_title(was)
	_done()


func test_the_reviewer_box_takes_the_right_code_and_refuses_a_wrong_one() -> void:
	_reviewer_shop()
	var was := await _screen_sized_title()
	_tap_version(5)
	await get_tree().process_frame
	var field := _review_box()
	if field == null:
		check(false, "the box opens")
		await _test_sized_title(was)
		_done()
		return
	field.text = "QX7P-29HD-MM4G"
	_button(Nav.ui, "OK").pressed.emit()
	check(_label(Nav.ui, "That code isn't right.") != null, "a wrong code says so")
	check(_full().locked() and _review_box() != null, "and leaves the box open and the game locked")
	field.text = "qx7p 29hd mm4f"
	_button(Nav.ui, "OK").pressed.emit()
	await get_tree().process_frame
	check(not _full().locked() and not Game.is_demo(), "the right code opens the full game at once")
	check(_review_box() == null and _button(Nav.ui, "Unlock the full game") == null, "and the title's menu comes back without the unlock")
	await _test_sized_title(was)
	_done()


## The title in a window a screen's size, since the tests' own small window puts the menu over the version number; returns the size to go back to.
func _screen_sized_title() -> Vector2i:
	var was := get_window().size
	get_window().size = Vector2i(1440, 810)
	Nav.refit()
	await _go("title")
	return was


func _test_sized_title(was: Vector2i) -> void:
	get_window().size = was
	Nav.refit()
	await _go("title")


## Taps the title's version number `n` times, each pressed and lifted where it shows, as a finger does.
func _tap_version(n: int) -> void:
	var version: Control = Nav.current._version
	for i in n:
		for down in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = down
			b.position = version.get_global_rect().get_center() * Nav.scale_factor()
			b.global_position = b.position
			get_viewport().push_input(b)


## The field for the reviewer's code, leaving out a page on its way out.
func _review_box() -> LineEdit:
	for f: LineEdit in Nav.ui.find_children("ReviewCode", "LineEdit", true, false):
		var gone := false
		var n: Node = f
		while n != null:
			gone = gone or n.is_queued_for_deletion()
			n = n.get_parent()
		if not gone and f.is_visible_in_tree():
			return f
	return null

func _go(screen: String, args := {}) -> void:
	Nav.go(screen, args)
	await _go_on(screen)


func _go_on(screen: String) -> void:
	while Nav.current_name != screen or Nav._busy:
		await get_tree().process_frame


func _button(node: Node, text: String) -> Button:
	if node == null:
		return null
	for b: Button in node.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.is_visible_in_tree() and (b.text == text or b.text == tr(text)):
			return b
	return null


func _label(node: Node, text: String) -> Label:
	for l: Label in node.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion() and l.is_visible_in_tree() and (l.text == text or l.text == tr(text)):
			return l
	return null


func _shown(node: Node, type: String) -> Node:
	for c in node.find_children("*", type, true, false):
		if not c.is_queued_for_deletion():
			return c
	return null


func _cards_saying(text: String) -> int:
	return Nav.ui.find_children("*", "StoreCard", true, false).filter(func(c: Node) -> bool:
		return not c.is_queued_for_deletion() and _label(c, text) != null).size()


## The SlowSundayPhone plugin's purchase methods and signals, answered by hand.
class FakeStore:
	signal billing_connected
	signal billing_unavailable(message: String)
	signal price_found(product_id: String, price: String)
	signal purchase_finished(product_id: String, status: String)
	signal owned_found(product_ids: PackedStringArray)

	var calls: Array = []

	func billing_start() -> void:
		calls.append(["billing_start"])

	func billing_ready() -> bool:
		return true

	func query_price(product_id: String) -> void:
		calls.append(["query_price", product_id])

	func buy(product_id: String) -> void:
		calls.append(["buy", product_id])

	func query_owned() -> void:
		calls.append(["query_owned"])
