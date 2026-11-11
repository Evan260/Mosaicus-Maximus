extends Node
## One file of tests: every method whose name starts with test_ is run by run_tests.gd, with the file in the scene tree
## so a test can wait for frames and add nodes.

var failures := 0
var passed := 0


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failures += 1
		print("FAIL: " + what)
