extends RefCounted

# Base for the automated tests in tools/tests (run by tools/run_tests.gd). A test file
# extends this and defines methods named test_*; each runs in turn, and may await (for
# frames, timers or signals) through `tree`. Check things with the expect_* helpers: a
# failed expectation is recorded and the test carries on, so one run reports everything.
#
# Tests that need the game running call boot_floor() first, which changes the scene to a
# fresh floor and waits for it to settle. Tuning is reset after every test.

var tree: SceneTree
var failures: Array[String] = [] # Messages from the current test's failed expectations

func expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)

func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) || actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])

func expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s (±%s), got %s" % [message, expected, tolerance, actual])

# An autoload by name (Game, Tuning, SaveData, Juice...). Looked up at run time so test
# scripts compile before the autoloads exist.
func autoload(autoload_name: String) -> Node:
	return tree.root.get_node(autoload_name)

# Changes to a new floor and waits until the player is in it.
func boot_floor() -> void:
	tree.change_scene_to_file("res://src/world/Overworld.tscn")
	for i in 30:
		await tree.process_frame

# Waits `seconds` of real time, however slow the game is running.
func wait_real(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout
