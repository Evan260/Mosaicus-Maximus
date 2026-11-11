extends Node
## Times the heaviest scenes one after another and writes what each costs: --bench=OUT.md [--bench-seconds=S]
## Frames run unlimited, without vsync, so a frame's time is what it costs rather than the monitor's wait.

var out := ""
var seconds := 5.0
var _rows: Array = []
var _sampling := false
var _frames := PackedFloat32Array()
var _proc := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _draws := PackedFloat32Array()
var _last_usec := 0
var _vp_rid: RID


func _ready() -> void:
	out = Dev.get_arg("bench", "user://bench.md")
	seconds = Dev.num("bench-seconds", 5.0)
	Saves.enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _sampling and _last_usec > 0:
		_frames.append((now - _last_usec) / 1000.0)
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_last_usec = now


func _run() -> void:
	Game.new_game("Bench")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	await _go("title", {}, "Title floor", 7.0)
	Dev.args["max-state"] = ""
	Dev.make_state()
	Game.state["hour"] = 22.0
	Game.state["pending_events"].clear()
	await _go("workshop", {}, "Workshop at night, lamps lit", 1.5)
	await _measure_book()
	await _go("design_table", {"job": Dev.test_job("commission"), "design": _busy_design()}, "Design table, 16 motifs", 2.0)
	Dev.args["auto-lay"] = ""
	Dev.args["auto-lay-seconds"] = str(seconds)
	Dev.args["finish-auto-lay"] = ""
	Dev.args["fill-at"] = str(seconds + 0.8)
	Dev.args["fill-seconds"] = "1.5"
	await _go("floor", {"design": Samples.make("villa")}, "Floor laying (villa, auto-lay)", 0.6)
	for k in ["auto-lay", "auto-lay-seconds", "fill-at", "fill-seconds"]:
		Dev.args.erase(k)
	var floor_view: FloorView = Nav.current.floor_view
	await _until(func() -> bool: return floor_view.phase != FloorView.Phase.LAY, 20.0)
	await _sample("Floor grouting and polishing", 0.3)
	await _until(func() -> bool: return floor_view.phase == FloorView.Phase.DONE, 20.0)
	await _wait(3.0)
	var cam: Camera2D = get_viewport().get_camera_2d()
	cam.zoom = Vector2.ONE * 0.2
	await _sample("Floor finished, zoomed out", 0.5)
	Dev.args.erase("finish-auto-lay")
	Dev.args["kind"] = "commission"
	Dev.args["sample"] = "villa"
	await _go("reveal", {}, "Reveal in the client's room", 3.0)
	Dev.args.erase("kind")
	Dev.args.erase("sample")
	await _go("town_map", {}, "Town map", 1.5)
	Dev.args["visit"] = ""
	Dev.args["room"] = "villa_dining"
	await _go("town_map", {}, "Town map, visiting a floor", 3.0)
	Dev.args.erase("visit")
	Dev.args.erase("room")
	_write()
	get_tree().quit()


## A floor table with sixteen motifs on it, the most a busy floor has.
func _busy_design() -> FloorDesign:
	var d := FloorDesign.for_room("villa_dining")
	d.set_border("braid")
	var ids: Array = Data.motif_order.slice(0, 16)
	for i in ids.size():
		d.add(ids[i], d.w * (0.12 + 0.25 * (i % 4)), d.h * (0.14 + 0.24 * (i / 4)), 12)
	return d


## The chapters book on the workshop, turning a page every 0.7 seconds while it is timed.
func _measure_book() -> void:
	var book := ChaptersPanel.open(Nav.current._root)
	Nav.current._show_panel(book)
	await _wait(1.0)
	var turning := func() -> void:
		book.turn_to(1 + (book.chapter % Data.chapters.size()))
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.timeout.connect(turning)
	add_child(timer)
	timer.start()
	await _sample("Chapters book, turning pages", 0.0)
	timer.queue_free()
	book.queue_free()
	await _wait(0.5)


func _go(screen: String, args: Dictionary, label: String, warm: float) -> void:
	Nav.go(screen, args)
	await get_tree().process_frame
	while Nav._busy:
		await get_tree().process_frame
	await _sample(label, warm)


func _until(done: Callable, most: float) -> void:
	var left := most
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _sample(label: String, warm: float) -> void:
	await _wait(warm)
	_frames.clear()
	_proc.clear()
	_gpu.clear()
	_draws.clear()
	_last_usec = 0
	_sampling = true
	await _wait(seconds)
	_sampling = false
	var sorted := _frames.duplicate()
	sorted.sort()
	var worst := sorted.slice(int(sorted.size() * 0.99))
	_rows.append({
		"scene": label,
		"frames": _frames.size(),
		"avg_ms": _mean(_frames),
		"worst1_ms": _mean(worst),
		"process_ms": _mean(_proc),
		"gpu_ms": _mean(_gpu),
		"draw_calls": _mean(_draws),
		"canvas_items": _canvas_items(get_tree().root),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	})
	print("bench: ", label, " ", _rows[-1]["avg_ms"], " ms")


func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v in a:
		t += v
	return t / a.size()


func _canvas_items(n: Node) -> int:
	var count := 1 if n is CanvasItem and (n as CanvasItem).is_visible_in_tree() else 0
	for c in n.get_children():
		count += _canvas_items(c)
	return count


func _write() -> void:
	var size := DisplayServer.window_get_size()
	var lines := ["# Mosaicus Maximus benchmark", "",
		"%s, window %dx%d, %s s a scene, %s, screen %d Hz" % [Time.get_datetime_string_from_system(), size.x, size.y, seconds,
			RenderingServer.get_video_adapter_name(), DisplayServer.screen_get_refresh_rate()], "",
		"Slowest process ms is Godot's TIME_PROCESS, the slowest frame's script and engine work in each second, averaged.", "",
		"| Scene | Frames | Avg ms | 1% worst ms | Slowest process ms | GPU ms | Draw calls | Canvas items | Objects | Nodes | Orphans | Resources | Static MB | Texture MB | Video MB |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
	for r in _rows:
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.0f | %d | %d | %d | %d | %d | %.1f | %.1f | %.1f |" % [r["scene"], r["frames"],
			r["avg_ms"], r["worst1_ms"], r["process_ms"], r["gpu_ms"], r["draw_calls"], r["canvas_items"], r["objects"], r["nodes"],
			r["orphans"], r["resources"], r["static_mb"], r["texture_mb"], r["video_mb"]])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("bench written to ", out)
