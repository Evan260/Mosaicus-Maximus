extends Node
## Opens the title screen, or the screen named with --screen= for checking it on its own, or a trailer shot.


func _ready() -> void:
	if Dev.has("run-tests"):
		add_child(load("res://tests/run_tests.gd").new())
		return
	if Dev.has("flow"):
		add_child(load("res://tests/flow_bot.gd").new())
		return
	if Dev.has("bench"):
		add_child(load("res://tests/bench.gd").new())
		return
	if Dev.has("trailer-shot"):
		add_child(load("res://tools/trailer/shots.gd").new())
		return
	if Dev.made_up():
		Dev.make_state()
	# A player's launch fades into the title from the loading screen; checks with flags start on the screen unless --boot asks.
	if Dev.args.is_empty() or Dev.has("boot"):
		add_child(load("res://scripts/ui/boot_cover.gd").new())
	Nav.go.call_deferred(Dev.get_arg("screen", "workshop" if Dev.made_up() else "title"), {})
