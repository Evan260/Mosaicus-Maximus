extends "res://tests/test_case.gd"
## The game's rules, saves, layout and translations.

var game: Node = Game
var saves: Node = Saves
var data: Node = Data


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
				if not game.buy_shortfall(counts) or not game.take_stone(counts):
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
		if game.coins() > 220 and int(game.state["apprentices"]) < 1:
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


func test_every_breed_comes_in_three_coats() -> void:
	for breed in DogView.BREEDS:
		var coats := DogView.coats_for(breed)
		check(coats.size() >= 3, "the %s comes in at least three coats" % breed)
		check(breed == "hound" or coats.keys()[0] == "natural", "a %s saved in its natural coat keeps that look" % breed)
		var looks := {}
		for coat in coats:
			var v := DogView.make({"breed": breed, "coat": coat})
			v.play("sit")
			check(v.texture != null, "the %s in its %s coat has its pictures" % [breed, coat])
			var img := v.texture.get_image()
			img.convert(Image.FORMAT_RGBA8)
			looks[img.get_data().hex_encode()] = coat
			v.free()
		check(looks.size() == coats.size(), "each of the %s's coats looks different: %s" % [breed, looks.values()])
	var old := DogView.make({"breed": "lapdog", "coat": "natural"})
	old.play("sit")
	check(old.texture.resource_path.begins_with(DogView.DIR), "a lapdog saved in its natural coat is drawn as painted")
	old.free()



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
	var keys := ["floors", "stat", "chapter", "all_patterns", "stories", "story", "tastes", "library", "festivals"]
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


func test_festivals_theme_the_board() -> void:
	game.new_game("Festive")
	game.state["day"] = 5
	var f := Story.festival(game.state)
	check(not f.is_empty(), "day 5 is a festival")
	check(Story.festival({"day": 6}).is_empty(), "the day after is not")
	var tag := Story.festival_tag(game.state, f)
	Story.morning(game.state)
	var themed := (game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return str(j.get("festival", "")) == f["id"])
	check(not themed.is_empty(), "the townsfolk's notices are for the festival")
	for j in themed:
		check(tag in j["brief"]["tags"], "a festival notice asks for the festival's theme (%s)" % tag)
	check((game.state["pending_events"] as Array).any(func(e: Dictionary) -> bool: return e.get("kind", "") == "festival"), "a letter says it's a festival")
	var job: Dictionary = themed[0]
	var coins := int(game.state["coins"])
	var events := Story.finish_job(game.state, job, {"score": 0.95, "paid": 0, "reputation": 0})
	check(events.any(func(e: Dictionary) -> bool: return e.get("kind", "") == "festival"), "a fine festival floor wins the prize")
	check(int(game.state["coins"]) == coins + Story.festival_prize(game.state), "the prize is paid")
	job["id"] = "again"
	check(not Story.finish_job(game.state, job, {"score": 0.95}).any(func(e: Dictionary) -> bool: return e.get("kind", "") == "festival"), "only once a festival")


func test_the_dog_finds_digs() -> void:
	game.new_game("Digger")
	var found := 0
	for day in range(1, 60):
		game.state["day"] = day
		Story.morning(game.state)
		for j in game.state["board"]:
			if bool(j.get("dog", false)):
				found += 1
				check(j["kind"] == "restoration", "the dog finds old floors")
	check(found >= 3, "the dog finds a dig every so often (%d in two months)" % found)


func test_picture_panels() -> void:
	game.new_game("Bench")
	check(Story.can_make_panel(game.state), "the bench is free on a new day")
	var d := FloorDesign.for_room("panel")
	d.add("dolphin", 10, 10, 14)
	var panel := Story.finish_panel(game.state, {"kind": "panel"}, {"score": 0.9, "design": d.to_dict()})
	check(panel["motif"] == "dolphin" and (game.state["panels"] as Array).size() == 1, "a finished panel is kept in the workshop")
	check(not Story.can_make_panel(game.state), "one panel a day")
	check(Story.panel_value(game.state, 5) > Story.panel_value(game.state, 2), "a better panel sells for more")
	var floor := FloorDesign.for_room("vestibule")
	floor.add("dolphin", 24, 18, 14)
	var plain := Composer.stone_counts(floor)
	floor.placements[0]["panel"] = panel["id"]
	check(Composer.panel_mask(floor, 6).count(1) > 0, "a panel set into a floor has an area that comes laid")
	var with_panel := Composer.stone_counts(floor)
	var total := func(c: Dictionary) -> int:
		var n := 0
		for k in c:
			n += int(c[k])
		return n
	check(total.call(with_panel) < total.call(plain), "its stone is not bought again (%d against %d)" % [total.call(with_panel), total.call(plain)])


func test_bench_and_wall_rooms_are_kept_apart() -> void:
	check(not "panel" in Data.job_rooms(), "no client asks for the bench's square")
	check(not "niche" in Data.job_rooms(false) and "niche" in Data.job_rooms(), "a wall niche is never dug up or copied, but can be asked for")
	game.new_game("Rooms")
	Story.unlock(game.state, 4)
	for day in range(1, 40):
		game.state["day"] = day
		Story.morning(game.state)
		for j in game.state["board"]:
			check(j["room"] != "panel", "no notice for the bench's square (day %d)" % day)
			if j["kind"] in ["restoration", "copy"]:
				check(j["room"] != "niche", "no dig or copy of a wall niche (day %d)" % day)


func test_prelaid_tiles_count_as_laid() -> void:
	var d := FloorDesign.for_room("vestibule")
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	fv.prelay(PackedInt32Array([0, 1, 2, 3]))
	check(fv.laid == 4, "four tiles come laid")
	check(fv.stone_unplaced(layout.stone[0]) == int(fv._stone_total[layout.stone[0]]) - [0, 1, 2, 3].filter(func(i: int) -> bool: return layout.stone[i] == layout.stone[0]).size(), "and the tray counts them as placed")
	fv.free()


func test_floors_are_laid_from_stock() -> void:
	game.new_game("Stock")
	game.state["stock"] = {"limestone": 50}
	var counts := {"limestone": 120, "black_stone": 30}
	check(not game.take_stone(counts), "a floor can't be started without its stone in stock")
	check(int(game.state["stock"]["limestone"]) == 50, "and nothing is taken when it can't")
	var coins := int(game.coins())
	check(game.buy_shortfall(counts), "the stone it is short of can be bought in sacks")
	check(game.stock("limestone") == 150 and game.stock("black_stone") == 100, "whole sacks of 100 (%d limestone, %d black)" % [game.stock("limestone"), game.stock("black_stone")])
	check(int(game.coins()) == coins - game.sack_price("limestone") - game.sack_price("black_stone"), "paid at the merchant's price per sack")
	check(game.take_stone(counts) and game.stock("limestone") == 30 and game.stock("black_stone") == 70, "then the floor takes its stone and the rest stays in stock")


func test_everyone_has_their_own_face() -> void:
	var ids := {}
	var groups := ["townsfolk", "collectors", "finders"]
	for g in groups:
		for p in Data.people[g]:
			var face := str(p.get("portrait", p["id"]))
			check(not ids.has(face), "%s has a face of their own" % p["id"])
			ids[face] = true
			check(str(p.get("look", "")) != "", "%s is described for their portrait" % p["id"])
	for p in Data.people["townsfolk"]:
		check(str(p.get("trade", "")) != "", "%s has a trade" % p["name"])
	game.new_game("Faces")
	for day in range(1, 30):
		game.state["day"] = day
		Story.morning(game.state)
		var seen := {}
		for j in game.state["board"]:
			if j["kind"] == "commission" and j["client"] == "":
				var name := Ui.text(j["client_name"]).get_slice(",", 0)
				check(not seen.has(name), "%s is on the board only once (day %d)" % [name, day])
				seen[name] = true
	check(JobFactory.pronouns({"portrait": "gaia"})["he"] == "she" and JobFactory.pronouns({"portrait": "lucius"})["he"] == "he", "he or she by each person's own face")
	check(Data.face({"id": "nobody_yet", "woman": true}) in ["towns_2", "towns_4"], "someone not painted yet borrows a face of their sex")


func test_audit_fixes() -> void:
	game.new_game("Audit")
	Story.unlock(game.state, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var job := JobFactory._named("quintus", game.state, rng)
	game.state["clients"]["quintus"] = {"step": 1}
	job = JobFactory._named("quintus", game.state, rng)
	check(JobFactory.pronouns(job)["he"] == "he", "Quintus is always he, whoever else found his floor")
	var used := {}
	var a := JobFactory.copy(game.state, rng, used)
	var b := JobFactory.copy(game.state, rng, used)
	check(a["client_name"] != b["client_name"], "two copies on one board come from two collectors")
	game.new_game("Locked")
	check(not game.buy_shortfall({"blue_glass": 50}), "stone the merchant doesn't sell yet can't be bought")
	check(game.not_sold({"blue_glass": 50}) == ["blue_glass"], "and it is named as not sold")
	check(Stones.nearest("blue_glass", game.state["unlocked_stones"]) in game.state["unlocked_stones"], "a locked stone is swapped for one the workshop has")
	game.state["coins"] = 1000
	var swap := Pricing.cheaper_swap({"white_marble": 500}, ["limestone", "white_marble", "black_stone", "grey_stone"])
	check(swap.is_empty() or int(swap["saving"]) == Game.shortfall_cost({"white_marble": 500}) - Game.shortfall_cost({str(swap["to"]): 500}), "the swap hint counts what the sacks really cost (%s)" % [swap])


func test_upgrades_save_on_every_sack() -> void:
	game.new_game("Savings")
	Story.unlock(game.state, 4)
	var plain := {}
	for s in Stones.LIST:
		plain[s["id"]] = game.sack_price(s["id"])
	game.state["upgrades"] = ["cutting_bench"]
	for s in Stones.LIST:
		check(game.sack_price(s["id"]) < int(plain[s["id"]]), "the cutting bench saves on a sack of %s (%d against %d)" % [s["id"], game.sack_price(s["id"]), plain[s["id"]]])
	game.state["upgrades"] = ["glass_furnace"]
	for s in Stones.LIST:
		var glass: bool = s["material"] == Stones.Kind.GLASS
		check((game.sack_price(s["id"]) < int(plain[s["id"]])) == glass, "the glass furnace saves on %s only if it is glass" % s["id"])
	var third := float(plain["blue_glass"]) * (1.0 - Data.num("savings.glass_furnace", 0.33))
	check(absf(game.sack_price("blue_glass") - third) < 1.0, "the furnace takes a third off glass (%d)" % game.sack_price("blue_glass"))
	var furnace := int(game.sack_price("blue_glass"))
	game.state["upgrades"] = ["glass_furnace", "cutting_bench"]
	check(game.sack_price("blue_glass") < furnace, "and the bench saves on top of it (%d)" % game.sack_price("blue_glass"))


func test_one_apprentice_brings_one_more_job() -> void:
	game.new_game("Hands")
	check(Story.jobs_allowed(game.state) == 1, "one job a day alone")
	check(int(Data.upgrades["apprentice"].get("repeat", 1)) == 1, "the workbench hires one apprentice")
	game.state["apprentices"] = 1
	check(Story.jobs_allowed(game.state) == 2, "an apprentice brings a second job")
	game.state["apprentices"] = 3
	check(Story.jobs_allowed(game.state) == 2, "an old save with three apprentices still has two jobs a day")
	var coins := int(game.coins())
	var t := Story.end_day(game.state)
	var wage := int(Data.num("wage", 6))
	check(int(t["wages"]) == wage and game.coins() == coins - wage, "and pays one wage (%d)" % int(t["wages"]))


func test_a_crowded_floor_is_called_crowded() -> void:
	var d := FloorDesign.for_room("vestibule")
	for x in range(4, 48, 8):
		for y in range(4, 36, 8):
			d.add("lozenge", x, y, 14)
	var share: float = Looks.coverage(Composer.compose(d, Looks.PX), Stones.index(d.ground))["share"]
	check(share > Looks.ideal_fill([]).y, "the packed floor really is crowded (%.2f)" % share)
	var packed := Looks.judge(d)
	check(bool(packed["crowded"]) and Looks.complaint(packed, "fill") == Looks.COMPLAINTS["crowded"], "a crowded floor is called crowded, not bare")
	check(str(packed["hints"].get("fill", "")).begins_with("Too crowded"), "and its hint says so")
	var bare := Looks.judge(FloorDesign.for_room("vestibule"))
	check(not bool(bare["crowded"]) and Looks.complaint(bare, "fill") == Looks.COMPLAINTS["fill"], "a bare floor is called bare")


func test_a_niche_never_bans_the_stone_it_wants() -> void:
	game.new_game("Niche")
	Story.unlock(game.state, 4)
	var niches := 0
	var clashes := 0
	for seed in 3000:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var job := JobFactory._townsfolk(game.state, rng, false)
		if job["room"] == "niche":
			niches += 1
			check(Stones.LIST[Stones.index(job["brief"]["want_stones"][0])]["material"] in [Stones.Kind.GLASS, Stones.Kind.GOLD], "a niche wants glass or gold")
			for s in job["brief"]["ban_stones"]:
				if s in job["brief"]["want_stones"]:
					clashes += 1
	check(niches > 50, "niches are asked for (%d)" % niches)
	check(clashes == 0, "no niche notice both wants and bans a stone (%d of %d)" % [clashes, niches])


func test_the_festival_prize_is_in_the_takings() -> void:
	game.new_game("Garlands")
	game.state["day"] = 5
	Story.morning(game.state)
	var f := Story.festival(game.state)
	var themed := (game.state["board"] as Array).filter(func(j: Dictionary) -> bool: return str(j.get("festival", "")) == f["id"])
	check(not themed.is_empty(), "there is a festival notice to win with")
	if themed.is_empty():
		return
	var earned := int(game.state["stats"]["earned"])
	Story.finish_job(game.state, themed[0], {"score": 0.95, "paid": 0, "reputation": 0})
	var prize := Story.festival_prize(game.state)
	check(int(game.state["stats"]["earned"]) == earned + prize, "the prize counts as earned")
	check((game.state["ledger"] as Array).any(func(e: Dictionary) -> bool: return int(e["day"]) == 5 and int(e["amount"]) == prize), "the prize is in the ledger")
	var t := Story.end_day(game.state)
	check(int(t["earned"]) == prize, "the day's Earned line counts it (%d)" % int(t["earned"]))


func test_story_steps_wait_for_their_rooms() -> void:
	game.new_game("Livia")
	Story.unlock(game.state, 2)
	game.state["clients"]["livia"] = {"step": 1}
	var early := 0
	for seed in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if JobFactory.commission(game.state, rng, {}, false)["client"] == "livia":
			early += 1
	check(early == 0, "Livia's house with an atrium waits for the atrium (%d notices in chapter 2)" % early)
	Story.unlock(game.state, 3)
	var rooms := {}
	for seed in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var job := JobFactory.commission(game.state, rng, {}, false)
		if job["client"] == "livia":
			rooms[job["room"]] = true
	check(rooms.keys() == ["atrium"], "then her notice is for the atrium (%s)" % [rooms.keys()])
	for chapter in range(1, 5):
		game.new_game("Rooms")
		Story.unlock(game.state, chapter)
		for seed in 200:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var job := JobFactory.commission(game.state, rng, {}, false)
			if job["client"] != "":
				var step := int(job["arc_step"])
				check(job["room"] == JobFactory.step_room(job["client"], step) and int(Data.room(job["room"]).get("tier", 1)) <= chapter, "chapter %d: %s's step %d is in a room that is open (%s)" % [chapter, job["client"], step, job["room"]])


func test_ships_still_come_in_the_last_chapter() -> void:
	game.new_game("Harbour")
	game.state["seed"] = 11
	game.state["coins"] = 5000
	var first := ""
	for day in range(3, 40):
		game.state["day"] = day
		Story.morning(game.state)
		first = Story.ship_stone(game.state)
		if first != "":
			break
	check(first != "" and game.ship_sack_price() > game.sack_price(first), "a ship's new stone costs more than the shelves would (%s)" % first)
	check(game.buy_from_ship() and game.has_stone(first) and Story.ship_stone(game.state) == "", "buying it makes it the workshop's, and the ship has no more")
	game.new_game("Harbour")
	game.state["seed"] = 11
	game.state["coins"] = 5000
	Story.unlock(game.state, 4)
	var ships := 0
	for day in range(3, 40):
		game.state["day"] = day
		Story.morning(game.state)
		var cargo := Story.ship_stone(game.state)
		if cargo == "":
			continue
		ships += 1
		check(game.ship_sack_price() < game.sack_price(cargo), "in the last chapter a ship's %s is cheaper than the shelves' (%d against %d)" % [cargo, game.ship_sack_price(), game.sack_price(cargo)])
		if int(game.state["stats"].get("ship_stones", 0)) == 0:
			check(game.buy_from_ship() and Story.ship_stone(game.state) == "", "a sack can be bought off it, one to a ship")
	check(ships >= 2, "ships still come once the town has every stone (%d)" % ships)
	var award: Array = Achievements.all().filter(func(a: Dictionary) -> bool: return a["id"] == "ship_stone")
	check(not award.is_empty() and Achievements.met(award[0], game.state), "From over the sea can still be earned in the last chapter")


func test_the_board_keeps_its_promises_to_a_broke_workshop() -> void:
	game.new_game("Broke festival")
	game.state["coins"] = 0
	game.state["stock"] = {}
	# Day 35 is both a contest day and a festival.
	game.state["day"] = 35
	var tag := Story.festival_tag(game.state, Story.festival(game.state))
	Story.morning(game.state)
	var board: Array = game.state["board"]
	var contest: Array = board.filter(func(j: Dictionary) -> bool: return j["kind"] == "contest")
	check(not contest.is_empty(), "the contest is still held")
	check(not contest.is_empty() and not JobFactory.affordable(contest[0], game.state), "a contest needs money for its stone")
	check(board.filter(func(j: Dictionary) -> bool: return JobFactory.affordable(j, game.state)).size() >= 2, "there are still two jobs a broke workshop can do")
	check(tag == "" or board.any(func(j: Dictionary) -> bool: return j.has("festival")), "a festival notice stays up for the letter's promise")


func test_a_client_on_the_table_is_not_on_the_board() -> void:
	game.new_game("Busy")
	var seen := func() -> int:
		var n := 0
		for seed in 200:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			if JobFactory.commission(game.state, rng, {}, false)["client"] == "septimus":
				n += 1
		return n
	check(seen.call() > 0, "Septimus asks for a floor on a free morning")
	game.state["active_job"] = {"kind": "commission", "client": "septimus", "arc_step": 0}
	check(seen.call() == 0, "but not while his last one is still on the table")


func test_stone_counts_are_the_tiles_laid() -> void:
	var designs := {"corridor": RandomDesign.make("corridor", 3, _seeded_rng(4)), "niche": RandomDesign.make("niche", 4, _seeded_rng(2)),
		"sea": Samples.make("sea"), "apse": Samples.make("apse")}
	var fine := FloorDesign.for_room("vestibule")
	fine.set_border("key")
	fine.add("dolphin", 16, 18, 16)["fine"] = true
	fine.add("fish", 34, 18, 12)["panel"] = "test"
	fine.add("rosette", 34, 18, 5)
	designs["fine and panel"] = fine
	for name in designs:
		var d: FloorDesign = designs[name]
		var counts := Composer.stone_counts(d)
		var layout := MosaicLayout.new()
		layout.build(Composer.compose(d, 6), 6, Composer.fine_mask(d, 6))
		var fv := FloorView.new()
		add_child(fv)
		fv.setup(layout)
		fv.prelay(Composer.prelaid(layout, Composer.panel_mask(d, 6)))
		var same := true
		var stones := {}
		for st in fv.stones_used():
			stones[Stones.id_of(st)] = fv.stone_unplaced(st)
		for id in stones:
			same = same and int(counts.get(id, 0)) == int(stones[id])
		for id in counts:
			same = same and stones.has(id)
		check(same, "%s: the stone bought is the stone laid (%s against %s)" % [name, counts, stones])
		fv.free()
	check(Composer.stone_counts(fine) == Composer.stone_counts(FloorDesign.from_dict(fine.to_dict())), "a design counted again gives the same count")


func _seeded_rng(n: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	return rng


func test_masks_follow_the_order_motifs_are_laid_in() -> void:
	var px := 3
	for key in ["fine", "panel"]:
		var d := FloorDesign.for_room("vestibule")
		var under := d.add("dolphin", 24, 18, 16)
		under[key] = true if key == "fine" else "test"
		d.add("rosette", 24, 18, 7)
		var mask := Composer.fine_mask(d, px) if key == "fine" else Composer.panel_mask(d, px)
		var parts := Composer.part_map(d, px)
		var wrong := 0
		var over := 0
		for i in parts.size():
			if parts[i] >= Composer.PART_MOTIF + 8 and parts[i] < Composer.PART_MOTIF + 16:
				over += 1
				wrong += mask[i]
			elif parts[i] >= Composer.PART_MOTIF + 1 and parts[i] < Composer.PART_MOTIF + 7 and mask[i] == 0:
				wrong += 1
		check(over > 0 and wrong == 0, "a motif laid over a %s takes its place in the mask (%d pixels wrong)" % [key, wrong])


func test_part_map_marks_placements_past_the_last_code() -> void:
	var d := FloorDesign.for_room("vestibule")
	for n in Composer.MAX_PARTS + 1:
		d.add("rosette", 24, 18, 10)
	var px := 3
	var parts := Composer.part_map(d, px)
	var c := Composer.PART_COVERED
	check(c != Stones.NO_TILE and c != Composer.PART_GROUND and (c < Composer.PART_BORDER or c >= Composer.PART_BORDER + 4) and c < Composer.PART_MOTIF, "the covered code is a code of its own")
	check(parts[18 * px * d.w * px + 24 * px] == c, "the last placement covers the first, so the plan names no hidden one")
	check(not Array(parts).any(func(v: int) -> bool: return v >= Composer.PART_MOTIF and v < Composer.PART_MOTIF + 8), "nothing names the buried first rosette")


func test_a_tile_set_twice_is_laid_once() -> void:
	var d := FloorDesign.for_room("shop")
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	fv.setup_restoration(PackedInt32Array([40, 41]))
	fv._finish_channel(2)
	fv.repair_stone = layout.stone[40]
	var at := layout.pos[40] * FloorView.WORLD
	fv.repair(at, at, 0.6 * fv.tile_world())
	fv._process(1.0)
	fv.lift(at, at, 0.6 * fv.tile_world())
	fv.repair(at, at, 0.6 * fv.tile_world())
	fv._process(1.0)
	check(Array(fv.order).count(40) == 1, "a lifted tile set again is in the order once")
	fv.replay(fv.order, 1.0)
	fv._process(5.0)
	check(fv.laid == layout.tile_count(), "the time-lapse lays every tile once (%d of %d)" % [fv.laid, layout.tile_count()])
	fv.free()


func test_chalk_under_a_set_in_panel_is_rubbed_out() -> void:
	var d := FloorDesign.for_room("shop")
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	fv.prelay(PackedInt32Array([0, 1, 2]))
	fv._process(0.016)
	check(not fv._chalk_dirty, "the chalk a panel covers is cleared before anything is laid")
	fv.free()


func test_wipes_count_only_the_floor() -> void:
	var d := FloorDesign.new()
	d.w = 30
	d.h = 24
	d.shape = "apse"
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6)
	var fv := FloorView.new()
	add_child(fv)
	fv.setup(layout)
	fv.phase = FloorView.Phase.GROUT
	var cell := FloorView.WORLD * FloorView.STATE_DIV
	var sw := int(ceil(layout.w / float(FloorView.STATE_DIV)))
	var sh := int(ceil(layout.h / float(FloorView.STATE_DIV)))
	for ch in 2:
		for y in sh:
			for x in sw:
				var px := mini(x * FloorView.STATE_DIV, layout.w - 1)
				var py := mini(y * FloorView.STATE_DIV, layout.h - 1)
				if layout.labels[py * layout.w + px] != Stones.NO_TILE:
					var at := (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
					fv.paint(at, at, cell * 0.75, ch)
	check(fv.phase == FloorView.Phase.DONE, "grouting and polishing the floor itself finishes it, with the corners beside the apse left bare")
	fv.free()


func test_old_floors_keep_their_patterns_on_the_floor() -> void:
	var px := 2
	var worst := 1.0
	var at := ""
	for room in ["atrium", "nymphaeum", "temple"]:
		for seed in 12:
			var d := RandomDesign.make(room, 1 + seed % 4, _seeded_rng(seed))
			var by_code := PackedInt32Array()
			by_code.resize(256)
			for v in Composer.part_map(d, px):
				by_code[v] += 1
			for n in d.placements.size():
				var p: Dictionary = d.placements[n]
				if "frame" in Data.motif(p["motif"]).get("tags", []):
					continue
				var t := MotifLibrary.tiles(p["motif"], float(p["size"]))
				var mask := MotifLibrary.mask(p["motif"], Vector2i(maxi(1, int(t.x * px)), maxi(1, int(t.y * px))), 0, false)
				var full := mask.size() - mask.count(0)
				var shown := 0
				for r in range(1, 7):
					shown += by_code[Composer.PART_MOTIF + n * 8 + r]
				if float(shown) / maxf(1.0, full) < worst:
					worst = float(shown) / maxf(1.0, full)
					at = "%s seed %d, %s" % [room, seed, p["motif"]]
	check(worst > 0.9, "every motif of an old floor lies on the floor, clear of a pool or an apse (worst %.2f, %s)" % [worst, at])


# Translations ------------------------------------------------------------

const SHEET := "res://translations/strings.csv"


## The strings sheet as {english: {locale: text}}, or empty in an exported game, which keeps only the translations.
func _sheet() -> Dictionary:
	if not FileAccess.file_exists(SHEET):
		return {}
	var f := FileAccess.open(SHEET, FileAccess.READ)
	var header := f.get_csv_line()
	var rows := {}
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in range(1, header.size()):
			row[header[i]] = line[i]
		rows[line[0]] = row
	return rows


## The format codes in a string, sorted: %s, %d, %.1f and %% as Godot reads them, and {name} parts.
func _placeholders(s: String) -> Array:
	var out := []
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "%":
			var j := i + 1
			while j < s.length() and s[j] in "-0123456789.":
				j += 1
			if j < s.length() and s[j] in "sdifxXcv%":
				out.append(s.substr(i, j - i + 1))
				i = j + 1
				continue
		elif c == "{":
			var close := s.find("}", i)
			if close > i and s.substr(i + 1, close - i - 1).is_valid_ascii_identifier():
				out.append(s.substr(i, close - i + 1))
				i = close + 1
				continue
		i += 1
	out.sort()
	return out


## Every string literal passed to tr(), TranslationServer.translate() or Ui.say() in the game's scripts.
func _keys_in_scripts() -> Dictionary:
	var found := {}
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(file))
			for call in ["tr(\"", "translate(\"", "say(\""]:
				var at := text.find(call)
				while at >= 0:
					if call != "tr(\"" or at == 0 or not (text[at - 1].is_valid_identifier() or text[at - 1] == "."):
						var key := _literal(text, at + call.length())
						found[key] = "%s/%s" % [dir, file]
					at = text.find(call, at + 1)
	return found


## The string literal that starts at `from`, just after its opening quote, with its escapes undone.
func _literal(text: String, from: int) -> String:
	var out := ""
	var i := from
	while i < text.length() and text[i] != "\"":
		if text[i] == "\\" and i + 1 < text.length():
			i += 1
			out += {"n": "\n", "t": "\t"}.get(text[i], text[i])
		else:
			out += text[i]
		i += 1
	return out


func test_every_string_in_the_code_is_in_the_sheet() -> void:
	var sheet := _sheet()
	if sheet.is_empty():
		return
	var missing := []
	var keys := _keys_in_scripts()
	for key in keys:
		if not sheet.has(key):
			missing.append("%s (%s)" % [key, keys[key]])
	var built := []
	for id in Data.motif_order:
		built += [str(Data.motif(id)["name"]), Data.motif_lower(id), Data.motif_with_article(id), Brief.wish_key("must", id)]
	for s in Stones.LIST:
		built += [str(s["name"]), str(s["name"]).to_lower(), Brief.wish_key("want", s["id"]), Brief.wish_key("ban", s["id"])]
	for t in Brief.TAG_WORDS:
		built += [Brief.TAG_WORDS[t], Brief.wish_key("tag", t)]
	for id in Data.rooms:
		built += [str(Data.room(id)["name"]), str(Data.room(id)["name"]).to_lower()]
	for id in Data.border_order:
		built += [str(Data.borders[id]["name"]), str(Data.borders[id]["name"]).to_lower()]
	for id in Data.upgrade_order:
		built += [str(Data.upgrades[id]["name"]), str(Data.upgrades[id]["name"]).to_lower(), str(Data.upgrades[id]["text"])]
	for t in Looks.TASTES:
		built += [Looks.TASTES[t]["text"], Looks.TASTES[t]["likes"], Looks.TASTES[t]["also"]] + Looks.TASTE_SAID[t]
	for q in Looks.QUALITIES:
		built += [Looks.NAMES[q], Looks.ABOUT[q], Looks.PRAISE[q], Looks.COMPLAINTS[q]]
	for c in Data.client_order:
		var client := Data.client(c)
		built += [str(client["name"]), str(client["trade"]), str(client["greeting"])]
		for beat in client["arc"]:
			built += [str(beat["line"]), str(beat["after"])]
	for group in ["townsfolk", "collectors"]:
		for p in Data.people[group]:
			built.append(str(p["name"]))
			if p.has("trade"):
				built.append(str(p["trade"]))
	for p in Data.people["finders"]:
		built.append(str(p["who"]))
	for line in Data.names["wants"] + Data.names["gossip"]:
		built.append(str(line))
	for ch in Data.chapters:
		built += [str(ch["title"]), str(ch["text"])]
	for a in Data.achievements:
		built += [str(a["name"]), str(a["text"])]
	for f in Data.festivals:
		built += [str(f["name"]), str(f["text"])]
	for key in built:
		if not sheet.has(key):
			missing.append(key)
	check(missing.is_empty(), "every string the game shows is in the strings sheet (missing %s)" % ", ".join(missing.slice(0, 8)))


func test_every_language_has_every_string() -> void:
	var sheet := _sheet()
	if sheet.is_empty():
		return
	var gaps := {}
	for key in sheet:
		for loc in sheet[key]:
			if str(sheet[key][loc]).strip_edges() == "":
				gaps[loc] = int(gaps.get(loc, 0)) + 1
	check(gaps.is_empty(), "every language has every string (missing %s)" % str(gaps))
	check((sheet.values()[0] as Dictionary).size() == 14, "the sheet has all 14 languages")


func test_translations_keep_their_placeholders() -> void:
	var sheet := _sheet()
	var wrong := []
	for key in sheet:
		var want := _placeholders(key)
		for loc in sheet[key]:
			if _placeholders(str(sheet[key][loc])) != want:
				wrong.append("%s in %s" % [key, loc])
	check(wrong.is_empty(), "every translation keeps the English placeholders (%d wrong: %s)" % [wrong.size(), ", ".join(wrong.slice(0, 6))])


func test_every_language_is_offered() -> void:
	var have := TranslationServer.get_loaded_locales()
	for loc in SettingsPanel.NATIVE_NAMES:
		check(loc in have, "%s is loaded and offered in the settings" % loc)


func test_fonts_have_every_letter() -> void:
	var sheet := _sheet()
	var missing := {}
	for key in sheet:
		for loc in sheet[key]:
			var font := UiTheme.body_font(loc)
			for c in str(sheet[key][loc]):
				if c != "\n" and c != " " and not font.has_char(c.unicode_at(0)):
					missing[loc] = str(missing.get(loc, "")) + c
	for loc in SettingsPanel.NATIVE_NAMES:
		for c in str(SettingsPanel.NATIVE_NAMES[loc]):
			if c != " " and not UiTheme.body_font(loc).has_char(c.unicode_at(0)):
				missing[loc] = str(missing.get(loc, "")) + c
	check(missing.is_empty(), "every language's font draws all its letters (missing %s)" % str(missing))


func test_kept_words_follow_the_language() -> void:
	var rng := _seeded_rng(4)
	game.new_game("Words")
	var job := JobFactory.copy(game.state, rng)
	var english := Ui.text(job["line"])
	check(english.begins_with(Ui.text(Data.people["collectors"][0]["name"])) or english.contains("wants the famous floor"), "a copy's notice reads in English (%s)" % english)
	TranslationServer.set_locale("de")
	var german := Ui.text(job["line"])
	check(german != english and not german.contains("%") and not german.contains("{"), "the same notice reads in German once German is chosen (%s)" % german)
	check(Ui.coins_text(2) != "2 denarii" and Ui.coins_text(2).begins_with("2"), "money is counted in German too (%s)" % Ui.coins_text(2))
	TranslationServer.set_locale("en")
	check(Ui.text(job["line"]) == english, "and in English again")


func test_every_script_compiles() -> void:
	var broken := []
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var script: Script = load(dir.path_join(file))
				if script == null or not script.can_instantiate():
					broken.append(file)
	check(broken.is_empty(), "every script compiles (broken: %s)" % ", ".join(broken))


func test_a_picture_smaller_than_the_window_fades_at_its_edges() -> void:
	var e := EdgeFade.make()
	e.fit(Rect2(Vector2.ZERO, Nav.BASE), Nav.BASE)
	check(e.widths() == [0, 0, 0, 0], "a picture that fills the window keeps its edges as painted")
	e.fit(Rect2(Vector2(80, 0), Nav.BASE), Vector2(640, 270))
	check(e.widths() == [EdgeFade.FADE, 0, EdgeFade.FADE, 0], "in a wide window its sides fade and its top and bottom stay")
	e.fit(Rect2(Vector2(0, 5), Nav.BASE), Vector2(480, 280))
	check(e.widths() == [0, 5, 0, 5], "an edge never fades further than the room past it")
	e.free()


func test_the_interface_is_one_step_finer_than_what_fits() -> void:
	check(Nav.ui_scale_for(Vector2(1920, 1080)) == 3, "1080p draws the interface three times, 640 by 360")
	check(Nav.ui_scale_for(Vector2(2560, 1440)) == 4, "1440p draws it four times")
	check(Nav.ui_scale_for(Vector2(2560, 1080)) == 3, "an ultrawide 1080 screen goes by its height")
	check(Nav.ui_scale_for(Vector2(1280, 1024)) == 2, "a tall window goes by its width")
	check(Nav.ui_scale_for(Vector2(1280, 720)) == 1, "a small window still draws it at least once")
	check(Nav.ui_scale_for(Vector2(300, 200)) == 1, "a tiny window never goes below one")
	for size in [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3440, 1440), Vector2(1280, 1024), Vector2(1280, 720)]:
		var k := Nav.ui_scale_for(size, 1)
		check(size.x / k >= Nav.BASE.x and size.y / k >= Nav.BASE.y, "even the largest interface keeps 480 by 270 at %s" % size)


func test_the_pictures_fill_the_window_by_a_whole_scale() -> void:
	check(Nav.picture_scale_for(Vector2(1920, 1080)) == 4, "1080p shows the room exactly four times")
	check(Nav.picture_scale_for(Vector2(2560, 1440)) == 6, "1440p crops a little rather than leave a border")
	check(Nav.picture_scale_for(Vector2(1280, 720)) == 3, "720p crops a little too")
	check(Nav.picture_scale_for(Vector2(2560, 1080)) == 4, "an ultrawide screen would lose too much top and bottom, so it fits")
	check(Nav.picture_scale_for(Vector2(3440, 1440)) == 5, "so does a wider one")
	check(Nav.picture_scale_for(Vector2(1280, 1024)) == 2, "a tall window would lose too much of the sides, so it fits")


func test_the_interface_size_setting_steps_round_three_sizes() -> void:
	check(Settings.next_ui_step(0) == 1 and Settings.next_ui_step(1) == 2 and Settings.next_ui_step(2) == -1 and Settings.next_ui_step(-1) == 0, "Normal, Larger, Largest, Smaller, then Normal again")
	check(Nav.ui_scale_for(Vector2(1920, 1080), -1) == 2, "Smaller at 1080p is twice")
	check(Nav.ui_scale_for(Vector2(1920, 1080), 1) == 4, "Larger at 1080p is four times, as large as the room")
	check(Nav.ui_scale_for(Vector2(1280, 720), -1) == 1, "Smaller never goes below once")
	check(Nav.ui_scale_for(Vector2(1280, 720), 1) == 2, "Larger at 720p is twice")
	check(Nav.ui_scale_for(Vector2(2560, 1080), 1) == 4, "Larger stops where 480 by 270 still fits")
	check(SettingsPanel.UI_SIZES.size() == 4, "the setting offers four sizes")
	check(Nav.ui_scale_for(Vector2(2560, 1440), 2) == 5, "Largest at 1440p is five times")
	check(Nav.ui_scale_for(Vector2(1920, 1080), 2) == 4, "Largest stops where 480 by 270 still fits")


func test_the_players_own_music_is_found_in_their_folder() -> void:
	var folder := ProjectSettings.globalize_path(Audio.PLAYER_MUSIC_DIR)
	var had := DirAccess.dir_exists_absolute(folder)
	var before: Array = Audio.player_tracks()
	DirAccess.make_dir_recursive_absolute(folder)
	var made := ["zz_test_tune.ogg", "zz_test_notes.txt"]
	for f in made:
		FileAccess.open(folder.path_join(f), FileAccess.WRITE).store_string("x")
	var found: Array = Audio.player_tracks()
	check(found.has(folder.path_join("zz_test_tune.ogg")), "a music file in the folder is played")
	check(not found.has(folder.path_join("zz_test_notes.txt")), "anything that isn't music is left out")
	check(Audio._load_external(folder.path_join("zz_test_tune.ogg")) == null, "a file that can't be read is skipped")
	for f in DirAccess.get_files_at("res://assets/audio/music/"):
		if f.ends_with(".ogg"):
			check(Audio._load_external(ProjectSettings.globalize_path("res://assets/audio/music/" + f)) is AudioStreamOggVorbis, "a real Ogg file from outside the game's files plays")
			break
	for f in made:
		DirAccess.remove_absolute(folder.path_join(f))
	if not had:
		DirAccess.remove_absolute(folder)
	check(Audio.player_tracks().size() == before.size(), "the test leaves the folder as it was")


func test_floor_walls_have_no_doorway() -> void:
	var fv := FloorView.new()
	check(not "door_visible" in fv, "the wall below a floor is plain, with no doorway drawn in it")
	fv.free()


func test_centred_button_text_ignores_its_icon() -> void:
	var box := VBoxContainer.new()
	box.theme = UiTheme.build()
	add_child(box)
	var done := Ui.button(box, "Done", func() -> void: pass, "tick", true)
	var listed := Ui.button(box, "1. A chapter", func() -> void: pass, "lock")
	listed.alignment = HORIZONTAL_ALIGNMENT_LEFT
	await get_tree().process_frame
	var box_style := done.get_theme_stylebox("normal")
	var gap := done.get_theme_constant("h_separation")
	check(box_style.get_margin(SIDE_RIGHT) == box_style.get_margin(SIDE_LEFT) + done.icon.get_width() + gap, "a centred button keeps its icon's room on the right too, so the text sits in the middle")
	check(done.get_theme_stylebox("hover").get_margin(SIDE_RIGHT) == box_style.get_margin(SIDE_RIGHT), "and keeps it when hovered")
	check(not listed.has_theme_stylebox_override("normal"), "a left-aligned button keeps its icon as it is")
	box.free()


func test_title_new_workshop_text_is_centred() -> void:
	for n in range(1, 4):
		saves.delete(n)
	var title: Node = load("res://scripts/screens/title.gd").new()
	title._show_menu()
	await get_tree().process_frame
	var fresh: Button = null
	for b in title._menu.find_children("*", "Button", true, false):
		if (b as Button).text == "New workshop":
			fresh = b
	check(fresh != null and fresh.has_meta("centred"), "the title's New workshop button centres its text on the whole button, not beside its icon")
	title._menu.free()
	title.free()


func test_chapters_book_fits_every_spread() -> void:
	game.new_game("Book")
	for loc in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(loc)
		UiTheme.use_language()
		var holder := Control.new()
		holder.theme = UiTheme.build()
		add_child(holder)
		var book := ChaptersPanel.open(holder, Vector2(480, 270))
		check(book._marks.get_children().filter(func(c: Node) -> bool: return c is Button).size() == Data.chapters.size() + 1, "a bookmark for every chapter and one for the achievements (%s)" % loc)
		var listed := 0
		for pg in book._award_pages([]):
			listed += (pg as Array).size()
		check(listed == Achievements.all().size(), "the achievements spreads list every achievement (%s)" % loc)
		for n in range(-1, Data.chapters.size() + 1):
			book.chapter = n
			book._fill()
			await get_tree().process_frame
			await get_tree().process_frame
			for view in book._pages:
				var col := view.get_child(0) as Control
				check(col.size.y <= view.size.y + 0.5, "chapter %d's %s page fits without scrolling in %s (%d of %d)" % [n, "left" if view == book._pages[0] else "right", loc, col.size.y, view.size.y])
		check(book.get_combined_minimum_size().x <= 472 and book.get_combined_minimum_size().y <= 262, "the book fits a 480 by 270 interface (%s)" % loc)
		holder.free()
	TranslationServer.set_locale("en")
	UiTheme.use_language()


func test_escape_closes_the_top_window_first() -> void:
	game.new_game("Escape")
	var under := DogPanel.open(Nav.ui)
	var over := SettingsPanel.open(Nav.ui)
	check(Nav.close_top() and over.is_queued_for_deletion() and not under.is_queued_for_deletion(), "Escape closes the window on top first")
	check(Nav.close_top() and under.is_queued_for_deletion(), "and then the one under it")
	await get_tree().process_frame
	check(not Nav.close_top(), "with no window open there is nothing to close")
	var title: Node = load("res://scripts/screens/title.gd").new()
	title._show_new()
	check(title.go_back() and title._page == "menu", "Escape on a new workshop steps back to the title's menu")
	check(not title.go_back(), "and on the menu it never quits the game")
	await get_tree().process_frame
	title._menu.free()
	title.free()


func test_settings_fit_the_smallest_interface_in_every_language() -> void:
	game.new_game("Settings")
	for loc in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(loc)
		UiTheme.use_language()
		var panel := SettingsPanel.open(Nav.ui, true)
		for t in SettingsPanel.TABS:
			panel._show(t, true)
			await get_tree().process_frame
			await get_tree().process_frame
			var box := panel.get_theme_stylebox("panel")
			var chrome: float = panel._head.get_combined_minimum_size().y + panel._tab_row.get_combined_minimum_size().y + 6.0 + box.get_minimum_size().y
			check(chrome + SettingsPanel.TALLEST <= 262.0, "the settings window's %s tab is short enough for 480 by 270 in %s" % [t, loc])
			check(panel.get_combined_minimum_size().x <= 472.0, "the settings window's %s tab is narrow enough for 480 by 270 in %s (%d)" % [t, loc, panel.get_combined_minimum_size().x])
		panel.free()
	SettingsPanel.tab = "Sound"
	TranslationServer.set_locale("en")
	UiTheme.use_language()


func test_background_sound_quietens_behind_other_windows() -> void:
	var was: String = Settings.background_sound
	var loud: float = Settings.master
	Settings.master = 0.9
	var bus := AudioServer.get_bus_index("Master")
	Settings.background_sound = "muted"
	Settings._behind = true
	Settings.apply()
	check(AudioServer.get_bus_volume_db(bus) < -60.0, "muted behind other windows silences the game")
	Settings._behind = false
	Settings.apply()
	check(AudioServer.get_bus_volume_db(bus) > -60.0, "and the sound comes back with the focus")
	Settings.background_sound = was
	Settings.master = loud
	Settings.apply()


func test_a_save_is_checked_before_it_replaces_the_last() -> void:
	game.new_game("Safe write")
	game.state["coins"] = 11
	check(saves.save(3), "a save is written")
	check(not FileAccess.file_exists(saves.path_for(3) + ".tmp"), "and its temporary file is moved into place")
	game.state["coins"] = 12
	saves.save(3)
	check(FileAccess.file_exists(saves.path_for(3) + ".bak1"), "the save before it becomes the newest backup")
	game.new_game("Other")
	check(saves.load_slot(3) and int(game.state["coins"]) == 12, "the newest save loads")
	saves.delete(3)
	check(not FileAccess.file_exists(saves.path_for(3) + ".bak1") and saves.slots()[2].is_empty(), "deleting a workshop takes its backups too")


func test_a_floor_half_laid_comes_back_as_it_was() -> void:
	var design := Samples.make("sea")
	var layout := MosaicLayout.new()
	Composer.lay_out(design, layout)
	var a := FloorView.new()
	add_child(a)
	a.setup(layout)
	var half := PackedInt32Array()
	for i in layout.tile_count() / 2:
		half.append(i)
	a.prelay(half)
	a.paint(Vector2.ZERO, Vector2.ZERO, 10.0)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(a.snapshot()))
	var b := FloorView.new()
	add_child(b)
	b.setup(layout)
	b.restore(snap)
	check(b.laid == a.laid and b.order == a.order, "the tiles laid come back in their order (%d of %d)" % [b.laid, a.laid])
	check(b.phase == a.phase, "and the floor is at the same step")
	a.free()
	b.free()


func test_a_made_up_workshop_never_sends_achievements_to_steam() -> void:
	game.new_game("Steam")
	check(Awards.may_send() == saves.enabled, "a real workshop sends its achievements")
	game.state["_dev"] = true
	check(not Awards.may_send(), "one made up by a dev option never does")


func test_quitting_from_a_floor_clears_every_layer() -> void:
	game.new_game("Quit")
	game.state["guide_off"] = true
	Nav.go("floor")
	while Nav._busy or Nav.current == null or Nav.current.floor_view == null:
		await get_tree().process_frame
	await Nav.close()
	for k in 3:
		await get_tree().process_frame
	check(Nav.world.get_child_count() == 0 and Nav.ui.get_child_count() == 0 and Nav.pictures.get_child_count() == 0, "closing for the quit takes the screen's floor and interface with it")


func test_motif_pictures_are_loaded_before_any_worker_thread() -> void:
	MotifLibrary._cache.clear()
	data.reload()
	check(Data.motif_order.all(func(id: String) -> bool: return MotifLibrary._cache.has(id)), "every pattern's picture is loaded on the main thread with the data, since one loaded on a worker thread is left over at exit")
