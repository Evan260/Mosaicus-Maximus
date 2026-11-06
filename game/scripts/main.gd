extends Node
## Opens the title screen, or the screen named with --screen= for checking it on its own, or a trailer shot.


func _ready() -> void:
	if Dev.has("run-tests"):
		add_child(load("res://tests/test_logic.gd").new())
		return
	if Dev.has("flow"):
		add_child(load("res://tests/flow_bot.gd").new())
		return
	if Dev.has("trailer-shot"):
		add_child(load("res://tools/trailer/shots.gd").new())
		return
	Nav.go.call_deferred(Dev.get_arg("screen", "title"), {})
