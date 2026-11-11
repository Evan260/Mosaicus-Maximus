extends Node
## Headless checks of the game's rules: Godot --headless --path game -- --run-tests
## A test that raises an engine error fails too, since a runtime error otherwise just ends the test quietly.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	Saves.dir = "user://test_saves"
	Saves.enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Saves.dir))
	for n in range(1, Saves.SLOTS + 1):
		Saves.delete(n)
	# The checks read the game's English, whatever language the computer is in.
	TranslationServer.set_locale("en")
	var passed := 0
	var failures := 0
	var only := Dev.get_arg("only", "")
	for file in ResourceLoader.list_directory("res://tests/"):
		if not file.begins_with("test_") or not file.ends_with(".gd") or file == "test_case.gd":
			continue
		if only != "" and not file.contains(only):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failures += 1
			print("FAIL: could not load " + file)
			continue
		var suite: Node = script.new()
		add_child(suite)
		for m in suite.get_method_list():
			if str(m["name"]).begins_with("test_"):
				var before := errors.count
				await suite.call(m["name"])
				if errors.count > before:
					failures += 1
					print("FAIL: %s %s raised an error" % [file, m["name"]])
		passed += suite.passed
		failures += suite.failures
		suite.free()
	OS.remove_logger(errors)
	print("%d passed" % passed)
	print("FAILURES: %d" % failures if failures else "ALL TESTS PASSED")
	Audio.quit(1 if failures else 0)


class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1
