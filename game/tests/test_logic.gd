extends Node
## Headless checks of the game's rules: Godot --headless --path game -- --run-tests

var failures := 0
var passed := 0
var game: Node
var saves: Node
var data: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game
	data = Data
	saves = Saves
	saves.dir = "user://test_saves"
	saves.enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.dir))
	for n in range(1, 4):
		saves.delete(n)
	for t in get_method_list():
		if str(t["name"]).begins_with("test_"):
			await call(t["name"])
	print("%d passed" % passed)
	print("FAILURES: %d" % failures if failures else "ALL TESTS PASSED")
	get_tree().quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failures += 1
		print("FAIL: " + what)


func test_save_roundtrip() -> void:
	game.new_game("Test workshop")
	game.state["coins"] = 321
	game.add_stock("gold", 40)
	game.state["floors"].append({"client": "felix", "score": 0.8})
	var before: Dictionary = game.to_dict()
	check(saves.save(2), "saves to slot 2")
	game.new_game("Other")
	check(saves.load_slot(2), "loads slot 2")
	var after: Dictionary = game.to_dict()
	for k in before:
		check(JSON.stringify(game._whole(before[k])) == JSON.stringify(game._whole(after[k])), "slot 2 keeps " + k)


func test_corrupt_save_falls_back() -> void:
	game.new_game("Backup test")
	game.state["coins"] = 77
	saves.save(1)
	game.state["coins"] = 78
	saves.save(1)
	var f := FileAccess.open(saves.path_for(1), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(saves.load_slot(1), "a corrupt slot loads from its backup")
	check(int(game.state["coins"]) == 77, "the backup holds the save before the last one")
	check(saves.load_slot(2), "the corrupt slot leaves slot 2 alone")


func test_missing_slot() -> void:
	game.new_game("Missing test")
	game.state["coins"] = 5
	check(not saves.load_slot(3), "an empty slot does not load")
	check(int(game.state["coins"]) == 5, "a failed load leaves the workshop as it was")


func test_old_save_fills_new_keys() -> void:
	game.from_dict({"version": 1, "name": "Old", "coins": 9})
	check(game.state.has("unlocked_borders") and int(game.state["coins"]) == 9, "an old save gains keys it lacked and keeps its own")


func test_motif_mask_roles() -> void:
	var m := MotifLibrary.mask("dolphin", Vector2i(60, 40), 0, false)
	var seen := {}
	for v in m:
		seen[v] = true
	check(seen.has(1) and seen.size() >= 3, "a dolphin mask has several colour areas")
	var ok := true
	for v in seen:
		ok = ok and v >= 0 and v <= 6
	check(ok, "mask roles stay between 0 and 6")
	var turned := MotifLibrary.mask("dolphin", Vector2i(40, 60), 1, true)
	check(turned.size() == 2400, "a turned mask has the turned size")


func test_border_lengths() -> void:
	for size in [Vector2i(100, 70), Vector2i(41, 23)]:
		for b in data.border_order:
			var d := FloorDesign.new()
			d.w = size.x
			d.h = size.y
			d.set_border(b)
			var img := Composer.compose(d, 3)
			var ground := Stones.map_colour("limestone")
			var band_has_stone := false
			var inner_clean := true
			var bw := int(d.border["width"])
			for y in img.get_height():
				for x in img.get_width():
					var tx := (x + 0.5) / 3.0
					var ty := (y + 0.5) / 3.0
					var inset := minf(minf(tx, size.x - tx), minf(ty, size.y - ty))
					var c := img.get_pixel(x, y)
					if inset > 1.0 and inset < 1.0 + bw and not c.is_equal_approx(ground):
						band_has_stone = true
					if inset > 2.5 + bw and not c.is_equal_approx(ground):
						inner_clean = false
			check(band_has_stone, "border %s lays stones in its band on a %s floor" % [b, size])
			check(inner_clean, "border %s leaves the inner field empty on a %s floor" % [b, size])


func test_compose_empty() -> void:
	var d := FloorDesign.new()
	d.w = 30
	d.h = 20
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	check(layout.tile_count() > 500, "an empty design still lays a plain floor")


func test_compose_off_plan() -> void:
	var d := FloorDesign.new()
	d.w = 30
	d.h = 20
	d.add("rosette", 29.0, -2.0, 14.0)
	d.add("dolphin", -30.0, 10.0, 12.0)
	var img := Composer.compose(d, 6)
	check(img.get_width() == 180 and img.get_height() == 120, "a motif off the floor clips without changing the floor's size")


func test_stone_counts() -> void:
	var d := FloorDesign.for_room("study")
	d.set_border("key")
	d.add("rosette", d.w * 0.5, d.h * 0.5, 18.0)
	d.add("dolphin", d.w * 0.2, d.h * 0.5, 9.0)
	var counts := Composer.stone_counts(d)
	var total := 0
	for k in counts:
		total += int(counts[k])
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var real := layout.tile_count()
	check(absf(total - real) / real < 0.05, "costing estimate %d is within 5%% of the %d tiles laid" % [total, real])


func test_apse_shape() -> void:
	var d := FloorDesign.new()
	d.w = 40
	d.h = 34
	d.shape = "apse"
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var r := d.w * 0.5
	var outside := 0
	for p in layout.pos:
		var t := p / 6.0
		if t.y < r and Vector2(t.x - r, t.y - r).length() > r + 0.3:
			outside += 1
	check(outside == 0, "no tiles lie outside an apse's curve (%d did)" % outside)
	check(layout.tile_count() > 800, "an apse room still lays its floor")


func test_layout_threaded() -> void:
	var d := FloorDesign.new()
	d.w = 200
	d.h = 140
	d.set_border("key")
	d.add("rosette", 100, 70, 40)
	var layout := MosaicLayout.new()
	var task := WorkerThreadPool.add_task(func() -> void: layout.build(Composer.compose(d, 6), 6))
	var frames := 0
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
		frames += 1
	WorkerThreadPool.wait_for_task_completion(task)
	check(layout.tile_count() > 25000, "a 200 by 140 floor lays out on a worker thread (%d tiles)" % layout.tile_count())
	check(frames > 3, "the game keeps running while it does (%d frames)" % frames)


func test_board_never_empty() -> void:
	game.new_game("Refuser")
	for day in 30:
		Story.morning(game.state)
		var board: Array = game.state["board"]
		var affordable := board.filter(func(j: Dictionary) -> bool: return JobFactory.affordable(j, game.state))
		check(board.size() >= 3, "day %d has %d notices" % [day + 1, board.size()])
		check(affordable.size() >= 2, "day %d has %d affordable notices" % [day + 1, affordable.size()])
		for j in board.duplicate():
			Story.refuse(game.state, j)
		Story.end_day(game.state)
	game.new_game("Broke")
	game.state["coins"] = 0
	game.state["stock"] = {}
	Story.morning(game.state)
	var broke: Array = (game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return JobFactory.affordable(j, game.state))
	check(broke.size() >= 2, "a workshop with no money still has %d jobs it can do" % broke.size())


func test_brief_scoring() -> void:
	var d := FloorDesign.for_room("changing_room")
	d.add("dolphin", 20, 20, 12)
	d.placements[0]["stones"]["1"] = "blue_glass"
	var brief := {"tags": ["sea"], "want_stones": ["blue_glass"], "ban_stones": ["red_marble"]}
	check(is_equal_approx(Brief.score(brief, d)["score"], 1.0), "a dolphin in blue glass with no red meets a sea brief")
	d.placements.clear()
	check(Brief.score(brief, d)["score"] < 0.5, "taking the dolphin away loses the brief")


func test_price_curve() -> void:
	var at := Pricing.accept_chance(100, 100, 0)
	var high := Pricing.accept_chance(300, 100, 0)
	check(at > 0.8, "asking the budget is accepted %.2f of the time" % at)
	check(high < 0.1, "asking three times the budget is accepted %.2f of the time" % high)
	check(Pricing.accept_chance(140, 100, 80) > Pricing.accept_chance(140, 100, 0), "reputation makes a high price easier")
	check(Pricing.payment(100, 1.0, 0.5) > 100, "a delighted client tips")
	check(Pricing.payment(100, 0.2, 0.6) < 100 and Pricing.payment(100, 0.2, 0.6) >= 55, "a poor floor pays less, but never nothing")


func test_cannot_afford_offers_cheaper() -> void:
	game.new_game("Poor")
	game.state["coins"] = 10
	var counts := {"gold": 400, "limestone": 1000}
	var swap := Pricing.cheaper_swap(counts, ["limestone", "black_stone", "white_marble", "grey_stone", "ochre_marble", "gold"])
	check(swap.get("from", "") == "gold", "the costliest stone is the one to swap")
	check(swap.get("to", "") != "" and swap.get("saving", 0) > 100, "a cheaper stone saves real money")


func test_chapters_unlock_in_order() -> void:
	game.new_game("Climber")
	var seen := []
	for rep in [20, 60, 150, 260]:
		game.state["reputation"] = rep
		for e in Story.check_chapters(game.state):
			seen.append(e["n"])
	check(seen == [2, 3, 4], "chapters open in order: %s" % str(seen))
	var gold := 0
	for s in game.state["unlocked_stones"]:
		if s == "gold":
			gold += 1
	check(gold == 1, "each stone is unlocked once")
	check("medusa" in game.state["unlocked_motifs"], "chapter 4 opens its motifs")


func test_arc_progress() -> void:
	game.new_game("Story")
	var job := {"client": "felix", "arc_step": 0, "id": "x"}
	Story.finish_job(game.state, job, {"score": 0.9, "paid": 100, "reputation": 5})
	check(int(game.state["clients"]["felix"]["step"]) == 1, "a good floor moves a client's story on")
	Story.finish_job(game.state, {"client": "cornelia", "arc_step": 0, "id": "y"}, {"score": 0.9})
	check(int(game.state["clients"]["felix"]["step"]) == 1, "another client's job leaves Felix's story alone")


func test_damage_repairable() -> void:
	var d := FloorDesign.for_room("study")
	d.add("rosette", d.w * 0.5, d.h * 0.5, 16)
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	for sev in [0.2, 0.4, 0.6]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var holes := Damage.holes(layout, rng, sev)
		var share := float(holes.size()) / layout.tile_count()
		check(absf(share - sev) < 0.05, "severity %.1f removes %.2f of the tiles" % [sev, share])
		var known := true
		for i in holes:
			known = known and layout.stone[i] >= 0 and layout.stone[i] < Stones.LIST.size()
		check(known, "every missing tile's original stone is known")


func test_repair_score() -> void:
	check(Stones.difference("limestone", "limestone") == 0.0, "a stone matches itself exactly")
	check(Stones.difference("limestone", "white_marble") < Stones.difference("limestone", "black_stone"), "a near colour scores better than a far one")


## Plays 60 days as a keen player who meets every brief, and prints when each chapter opens, to tune the pacing.
func test_pacing_report() -> void:
	game.new_game("Pacer")
	var opened := {}
	var lowest := 999999
	for day in 60:
		Story.morning(game.state)
		for _k in Story.jobs_allowed(game.state):
			var board: Array = (game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return JobFactory.affordable(j, game.state))
			if board.is_empty():
				break
			board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["budget"]) > int(b["budget"]))
			var job: Dictionary = board[0]
			var r := Data.room(job["room"])
			var tiles := int(int(r["w"]) * int(r["h"]) * 1.07)
			if job["kind"] != "restoration":
				var counts := {"limestone": int(tiles * 0.7), "black_stone": int(tiles * 0.15)}
				var colour := "ochre_marble" if int(game.state["chapter"]) >= 2 else "grey_stone"
				if int(game.state["chapter"]) >= 4:
					colour = "blue_glass"
				counts[colour] = int(tiles * 0.15)
				if not game.take_stone(counts):
					continue
			# A keen player's floors earn about four stars; a contest is won when that beats the rival's entry.
			var score := 0.8
			var paid := Pricing.payment(int(job["budget"]), score, 0.5)
			var rep := Pricing.reputation(score, tiles)
			if job["kind"] == "contest":
				var won := score >= float(job["rival"])
				paid = int(job["budget"]) if won else 0
				rep = int(Data.num("contest.win_reputation", 8) if won else Data.num("contest.lose_reputation", 2))
			game.earn(paid, "job")
			Story.finish_job(game.state, job, {"score": score, "paid": paid, "reputation": rep})
		if game.coins() > 220 and int(game.state["apprentices"]) < 2:
			game.spend(90, "apprentice")
			game.state["apprentices"] = int(game.state["apprentices"]) + 1
		lowest = mini(lowest, game.coins())
		for n in range(2, 5):
			if int(game.state["chapter"]) >= n and not opened.has(n):
				opened[n] = int(game.state["day"])
		Story.end_day(game.state)
	print("pacing: chapters opened on days %s, %d floors, %d d at the end, lowest purse %d d" % [str(opened), (game.state["floors"] as Array).size(), game.coins(), lowest])
	check(opened.has(4), "a keen player reaches chapter 4 within 60 days")
	check(lowest >= 0, "the purse never goes below nothing")


func test_briefs_always_possible() -> void:
	for chapter in range(1, 5):
		game.new_game("Brief check")
		Story.unlock(game.state, chapter)
		for day in 20:
			Story.morning(game.state)
			for j in game.state["board"]:
				if j["kind"] == "commission":
					check(JobFactory.possible(j["brief"], game.state), "chapter %d day %d: %s asks only for what can be made" % [chapter, day, j["client_name"]])
			Story.end_day(game.state)


func test_timelapse_gif() -> void:
	var d := FloorDesign.for_room("vestibule")
	d.add("rosette", d.w * 0.5, d.h * 0.5, 14)
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var gif := Timelapse.make(layout, PackedInt32Array(), 120)
	check(gif.size() > 1000 and gif.slice(0, 6).get_string_from_ascii() == "GIF89a" and gif[gif.size() - 1] == 0x3B, "a time-lapse is a complete GIF (%d bytes)" % gif.size())
	var f := FileAccess.open("user://test_timelapse.gif", FileAccess.WRITE)
	f.store_buffer(gif)
	f.close()


func test_part_map_finds_each_part() -> void:
	var d := FloorDesign.for_room("vestibule")
	d.set_border("plain")
	d.add("roundel", d.w * 0.5, d.h * 0.5, 12)
	d.placements[0]["stones"] = {"1": "white_marble", "2": "white_marble"}
	var px := 3
	var parts := Composer.part_map(d, px)
	var at := func(tx: float, ty: float) -> int: return parts[int(ty * px) * d.w * px + int(tx * px)]
	check(at.call(d.w * 0.5, d.h * 0.5 - 5.5) == Composer.PART_MOTIF + 1, "the roundel's ring is its part 1, even when both parts share a stone")
	var edge: int = at.call(1.5, d.h * 0.5)
	check(edge >= Composer.PART_BORDER and edge < Composer.PART_BORDER + 4, "the plain border is a border part (%d)" % edge)
	check(at.call(d.w * 0.25, d.h * 0.5) == Composer.PART_GROUND, "open floor is the ground")
	check(parts.size() == d.w * d.h * px * px, "the part map covers the whole plan")


func test_small_motifs_allowed() -> void:
	check(int(Data.motif("rosette").get("min", 99)) <= 3, "patterns can shrink to 3 tiles")
	check(int(Data.motif("dolphin").get("min", 99)) <= 6, "pictures can shrink to 6 tiles")


func test_library_keeps_and_forgets() -> void:
	Library.dir = "user://test_library/"
	Library.enabled = true
	for e in Library.entries():
		Library.remove(e)
	var d := FloorDesign.for_room("vestibule")
	d.add("star", d.w * 0.5, d.h * 0.5, 10)
	var picture := Image.create(40, 30, false, Image.FORMAT_RGBA8)
	picture.fill(Color.WHITE)
	var order := PackedInt32Array([5, 3, 9])
	var id := Library.add(d, order, picture, {"room": "vestibule", "tiles": 3})
	var kept := Library.entries()
	check(kept.size() == 1 and kept[0]["id"] == id, "a kept floor is in the library")
	check(Library.order_of(kept[0]) == order, "the laying order comes back as it was kept")
	check(Library.picture(kept[0], true) != null, "a kept floor has a thumbnail")
	check(FloorDesign.from_dict(kept[0]["design"]).placements.size() == 1, "the design is kept with it")
	Library.remove(kept[0])
	check(Library.entries().is_empty(), "a removed floor leaves the library")


func test_new_game_keeps_the_dog() -> void:
	Game.new_game("Test", {"breed": "lapdog", "coat": "natural", "name": "Pip"})
	check(Game.state["dog"]["name"] == "Pip" and Game.state["dog"]["breed"] == "lapdog", "the chosen dog is kept")
	Game.from_dict({"version": 1, "name": "Old"})
	check(Game.state["dog"]["breed"] == "hound", "an old save gets the farm hound")
	for breed in DogView.BREEDS:
		var v := DogView.make({"breed": breed, "coat": DogView.coats_for(breed).keys()[0]})
		v.play("sleep")
		check(v.texture != null and v.sleeping_centre().x > 0.0, "the %s has its pictures" % breed)
		v.free()



func _framed_room() -> FloorDesign:
	var d := FloorDesign.for_room("dining_room")
	d.set_border("key")
	return d


func test_looks_reward_a_composed_floor() -> void:
	var bare := FloorDesign.for_room("dining_room")
	var lopsided := FloorDesign.for_room("dining_room")
	lopsided.add("fish", 10, 10, 8)
	var composed := _framed_room()
	composed.add("rosette", composed.w * 0.5, composed.h * 0.5, 26)
	composed.placements[0]["stones"] = {"1": "black_stone", "2": "grey_stone", "3": "white_marble", "4": "black_stone"}
	composed.add("dolphin", composed.w * 0.2, composed.h * 0.5, 14)
	composed.add("dolphin", composed.w * 0.8, composed.h * 0.5, 14, 0, true)
	var a := Looks.judge(bare)
	var b := Looks.judge(lopsided)
	var c := Looks.judge(composed)
	check(float(a["beauty"]) < 0.3, "a bare floor looks plain (%.2f)" % a["beauty"])
	check(float(c["beauty"]) > float(b["beauty"]) + 0.2, "a framed, mirrored floor with a centrepiece beats one lopsided picture (%.2f against %.2f)" % [c["beauty"], b["beauty"]])
	check(float(c["qualities"]["symmetry"]) > 0.9, "a centred motif and a mirrored pair are symmetrical (%.2f)" % c["qualities"]["symmetry"])
	check(float(b["qualities"]["symmetry"]) < 0.3, "one picture in a corner is not (%.2f)" % b["qualities"]["symmetry"])
	check(float(c["qualities"]["centre"]) > 0.8, "a big motif in the middle is a centrepiece (%.2f)" % c["qualities"]["centre"])
	check(Looks.stars(float(c["beauty"])) >= 4, "the composed floor earns at least four stars (%.2f)" % c["beauty"])
	check(b["hints"].has("symmetry") and b["hints"].has("frame"), "the lopsided floor is told to mirror and frame itself")


func test_taste_changes_the_verdict() -> void:
	var calm := FloorDesign.for_room("dining_room")
	calm.set_border("plain")
	calm.add("rosette", calm.w * 0.5, calm.h * 0.5, 12)
	var plain := Looks.judge(calm, ["calm"])
	var busy := Looks.judge(calm, ["busy"])
	check(float(plain["beauty"]) > float(busy["beauty"]), "a mostly plain floor pleases a calm taste more than a busy one (%.2f against %.2f)" % [plain["beauty"], busy["beauty"]])


func test_copy_likeness() -> void:
	game.new_game("Copier")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var job := JobFactory.copy(game.state, rng)
	var target := FloorDesign.from_dict(job["target"])
	check(Brief.likeness(target, FloorDesign.from_dict(job["target"])) > 0.99, "a perfect copy is a perfect likeness")
	check(Brief.likeness(target, FloorDesign.for_room(target.room)) < 0.6, "an empty floor is a poor copy")
	for st in target.stones_used():
		check(st in game.state["unlocked_stones"], "the copy only needs stone the player has (%s)" % st)
	for p in target.placements:
		check(p["motif"] in game.state["unlocked_motifs"], "the copy only needs motifs the player has (%s)" % p["motif"])
	check(float(Brief.judge(job, target, [])["score"]) > 0.95, "a perfect copy earns full marks")


func test_digs_teach_new_patterns() -> void:
	game.new_game("Digger")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var job := JobFactory.restoration(game.state, rng)
	var found: String = job.get("discovery", "")
	check(found != "" and not found in game.state["unlocked_motifs"], "an old floor hides a pattern the player doesn't own (%s)" % found)
	check(int(Data.motif(found).get("tier", 9)) <= 2, "the hidden pattern is at most a chapter ahead")
	var used := FloorDesign.from_dict(job["design"]).placements.map(func(p: Dictionary) -> String: return p["motif"])
	check(found in used, "the hidden pattern is really on the old floor")
	job["id"] = "dig"
	Story.finish_job(game.state, job, {"score": 0.8, "paid": 50, "reputation": 3})
	check(found in game.state["unlocked_motifs"], "restoring the floor adds its pattern to the book")


func test_contests_and_ships() -> void:
	game.new_game("Town")
	var contests := 0
	var ships := 0
	for day in 28:
		Story.morning(game.state)
		for j in game.state["board"]:
			if j["kind"] == "contest":
				contests += 1
				check(int(game.state["day"]) % 7 == 0, "the contest is held on a seventh day (day %d)" % game.state["day"])
		var cargo := Story.ship_stone(game.state)
		if cargo != "":
			ships += 1
			check(not cargo in game.state["unlocked_stones"], "a ship brings a stone the town can't usually get (%s)" % cargo)
		Story.end_day(game.state)
	check(contests == 4, "four contests in four weeks (%d)" % contests)
	check(ships >= 2, "ships come in every few days (%d in four weeks)" % ships)


func test_tastes_are_learned() -> void:
	game.new_game("Learner")
	var job := {"kind": "commission", "client": "septimus", "taste": ["mirrored"], "arc_step": 0, "id": "s1"}
	check(Story.known_taste(game.state, job).is_empty(), "a regular's taste is unknown before their first floor")
	Story.finish_job(game.state, job, {"score": 0.8, "paid": 60, "reputation": 3})
	check(Story.known_taste(game.state, job) == ["mirrored"], "after a floor their taste is in the notebook")
	var stranger := {"kind": "commission", "client": "", "taste": ["calm"], "taste_said": true}
	check(Story.known_taste(game.state, stranger) == ["calm"], "townsfolk say their taste when they visit")


func test_board_has_no_twin_notices() -> void:
	for seed in 12:
		game.new_game("Twins")
		game.state["seed"] = seed
		Story.morning(game.state)
		var seen := {}
		for j in game.state["board"]:
			var key := "%s|%s" % [j["client_name"], j["room"]]
			check(not seen.has(key), "seed %d: the board has two notices from %s" % [seed, key])
			seen[key] = true


func test_banned_stone_only_counts_when_seen() -> void:
	var d := FloorDesign.for_room("study")
	d.set_border("key")
	d.border["stones"] = ["white_marble", "black_stone", "black_stone", "grey_stone"]
	var wishes: Array = Brief.score({"ban_stones": ["grey_stone"]}, d)["wishes"]
	check(wishes[0]["met"], "a stone kept for a border stripe that is never drawn doesn't break \"no grey stone\"")
	d.border["stones"][1] = "grey_stone"
	check(not Brief.score({"ban_stones": ["grey_stone"]}, d)["wishes"][0]["met"], "grey that shows does break it")


func test_mending_sets_one_tile_and_lifts_it() -> void:
	var d := FloorDesign.for_room("vestibule")
	d.add("rosette", d.w * 0.5, d.h * 0.5, 14)
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	var holes := PackedInt32Array([10, 11, 12, 200, 201])
	fv.setup_restoration(holes)
	check(fv.coverage() > 0.15 and fv.coverage() < 0.85, "an old floor is only partly buried (%.2f clear)" % fv.coverage())
	fv._finish_channel(2)
	check(fv.phase == FloorView.Phase.REPAIR, "a cleared floor with gaps goes on to mending")
	var at := layout.pos[200] * FloorView.WORLD
	check(fv.repair(at, at, 0.6 * fv.tile_world()) == 0, "nothing is set before a stone is picked")
	fv.repair_stone = 3
	check(fv.repair(at, at, 0.6 * fv.tile_world()) == 1 and fv.repaired.has(200), "a click sets exactly one tile, in the gap under it")
	fv.now += 1.0
	check(fv.lift(at, at, 0.6 * fv.tile_world()) == 1 and not fv.repaired.has(200), "the chisel lifts it out again")
	check(not fv.repairs_done(), "the mending isn't done while a gap is empty")
	fv.free()


func test_achievements_are_earned_once() -> void:
	Library.dir = "user://test_library/"
	var keys := ["floors", "stat", "chapter", "all_patterns", "stories", "story", "tastes", "library"]
	var ids := {}
	for a in Achievements.all():
		check(not ids.has(a["id"]) and str(a["name"]) != "" and str(a["text"]) != "", "achievement %s has a unique id, a name and a line" % a["id"])
		ids[a["id"]] = true
		check(keys.filter(func(k: String) -> bool: return a.has(k)).size() == 1, "achievement %s has one condition" % a["id"])
	game.new_game("Laurels")
	check(Achievements.check(game.state).is_empty(), "a new workshop has earned nothing")
	var job := {"kind": "commission", "client": "", "id": "a1"}
	Story.finish_job(game.state, job, {"score": 0.95, "paid": 80, "reputation": 40, "tiles": 900})
	var fresh := Achievements.check(game.state).map(func(a: Dictionary) -> String: return a["id"])
	check("first_floor" in fresh and "five_stars" in fresh, "the first floor, at five stars, earns both (%s)" % [fresh])
	check("chapter_2" in fresh, "reaching chapter 2 is an achievement")
	check(Achievements.check(game.state).is_empty(), "nothing is earned twice")
	game.earn(1000, "test")
	check(Achievements.check(game.state).map(func(a: Dictionary) -> String: return a["id"]) == ["earn_1000"], "earning 1,000 denarii in all counts the floor's pay too")
	for i in 25:
		game.bump("pets")
	check(Achievements.check(game.state).map(func(a: Dictionary) -> String: return a["id"]) == ["good_dog"], "25 pets for the dog")


func test_chapters_say_what_they_bring() -> void:
	game.new_game("Chapters")
	check(Story.next_chapter_line(game.state) == "35 more reputation opens chapter 2: Colour comes to town", "a new workshop knows how far chapter 2 is (%s)" % Story.next_chapter_line(game.state))
	check(Story.next_chapter_line(game.state, 40).begins_with("Enough reputation for chapter 2"), "the reveal can count the floor's reputation before it is saved")
	var text := ""
	for n in range(2, Data.chapters.size() + 1):
		var lines := Story.chapter_unlocks(n)
		check(not lines.is_empty(), "chapter %d brings something" % n)
		text += "\n".join(lines) + "\n"
	for s in Stones.LIST.filter(func(s: Dictionary) -> bool: return int(s["tier"]) > 1):
		check(str(s["name"]).to_lower() in text, "%s is named in the chapter it comes with" % s["name"])
	check(Story.chapter_unlocks(2)[0] == "Stone: terracotta, red marble, ochre marble, green marble and brown stone", "stone is listed by name (%s)" % Story.chapter_unlocks(2)[0])
	Story.unlock(game.state, Data.chapters.size())
	check(Story.next_chapter_line(game.state) == "", "nothing is ahead after the last chapter")
	game.new_game("Chapters")
	check(Story.next_chapter_line(game.state, 8, true) == "27 more reputation for chapter 2", "the reveal's line is short enough for one line")


func test_motif_names_read_well() -> void:
	check(Data.motif_with_article("loaves") == "loaves", "loaves take no article")
	check(Data.motif_with_article("amphora") == "an amphora", "a vowel takes an")
	check(Data.motif_with_article("dolphin") == "a dolphin", "the rest take a")
	check(Data.motif_name("knot") == "Solomon's knot" and Data.motif_name("medusa") == "Medusa", "names keep their capitals")
	var b := Brief.score({"must": ["loaves"]}, FloorDesign.for_room("vestibule"))
	check(b["wishes"][0]["text"] == "Has loaves", "the wish reads %s" % b["wishes"][0]["text"])


func test_floor_maps_into_a_room() -> void:
	var corners := [Vector2(44, 0), Vector2(144, 0), Vector2(166, 58), Vector2(22, 58)]
	var rows := Perspective.to_floor(corners)
	var want := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in 4:
		check(Perspective.apply(rows, corners[k]).distance_to(want[k]) < 0.001, "corner %d of the room is corner %d of the floor" % [k, k])
	var mid := Perspective.apply(rows, Vector2(94, 29))
	check(mid.y > 0.5, "halfway down the picture is past the floor's middle, since the back is drawn smaller (%.2f)" % mid.y)
	check(RoomView.has_room("study"), "the study has a painting")


func test_gaps_are_counted_down() -> void:
	var d := FloorDesign.for_room("vestibule")
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	fv.setup_restoration(PackedInt32Array([10, 11, 200]))
	fv._finish_channel(2)
	check(fv.gaps_left() == 3, "three gaps to fill")
	fv.repair_stone = 0
	var at := layout.pos[200] * FloorView.WORLD
	fv.repair(at, at, 0.6 * fv.tile_world())
	check(fv.gaps_left() == 2, "a set tile counts one gap off (%d left)" % fv.gaps_left())
	fv.free()


func test_mending_brush_can_be_widened() -> void:
	var d := FloorDesign.for_room("vestibule")
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	var near := layout.tiles_near(layout.pos[200], 2.0 * layout.px)
	fv.setup_restoration(near)
	fv._finish_channel(2)
	fv.repair_stone = 3
	var at := layout.pos[200] * FloorView.WORLD
	var set := fv.repair(at, at, 2.6 * fv.tile_world())
	check(near.size() > 1 and set == near.size(), "a wide mending brush fills every gap under it (%d of %d)" % [set, near.size()])
	fv.now += 1.0
	check(fv.lift(at, at, 2.6 * fv.tile_world()) == near.size(), "and a wide chisel lifts them all out again")
	var screen: Node = load("res://scripts/floor/floor_screen.gd").new()
	screen.floor_view = fv
	var one: float = screen.brush_radius()
	screen.grow_brush(2.0)
	check(screen.brush_radius() > one * 2.0, "the bigger brush button widens the mending brush")
	check(screen.brush_tiles == 4.0, "while the laying brush keeps its own size")
	screen.grow_brush(-5.0)
	check(is_equal_approx(screen.brush_radius(), one), "and the smaller one brings it back to a single gap")
	screen.free()
	fv.free()


func test_lamps_are_out_by_day() -> void:
	check(Daylight.lamps_lit(12.0) == 0.0 and Daylight.lamps_lit(9.0) == 0.0, "no lamps burn in daylight")
	check(Daylight.lamps_lit(22.0) == 1.0, "they burn fully at night")
	var dusk := Daylight.lamps_lit(17.5)
	check(dusk > 0.0 and dusk < 1.0, "they are being lit at dusk (%.2f)" % dusk)
