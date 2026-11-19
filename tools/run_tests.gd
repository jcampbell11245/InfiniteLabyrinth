extends SceneTree

# Runs every test in tools/tests (files named test_*.gd, extending tools/tests/test_case.gd)
# and exits with code 1 if any expectation failed or any error was logged. CI runs it on
# every pull request; run it yourself before pushing:
#
#   godot --headless --path . -s res://tools/run_tests.gd
#
# Pass a word after -- to run only the test files whose name contains it:
#
#   godot --headless --path . -s res://tools/run_tests.gd -- time

const TESTS_DIR := "res://tools/tests/"

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var where := "%s:%d" % [file, line]
		for bt in script_backtraces:
			if bt.get_frame_count() > 0:
				where = "%s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
				break
		_mutex.lock()
		errors.append("%s @ %s" % [rationale if rationale != "" else code, where])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out

var counter := ErrorCounter.new()

func _initialize() -> void:
	OS.add_logger(counter)
	_run.call_deferred()

func _run() -> void:
	# Let the autoloads finish their _ready first.
	await process_frame
	var only := ""
	if OS.get_cmdline_user_args().size() > 0:
		only = OS.get_cmdline_user_args()[0]
	var passed := 0
	var failed: Array[String] = []
	for file_name in ResourceLoader.list_directory(TESTS_DIR):
		if !file_name.begins_with("test_") || !file_name.ends_with(".gd") || file_name == "test_case.gd":
			continue
		if only != "" && !file_name.contains(only):
			continue
		var script := load(TESTS_DIR + file_name) as GDScript
		if script == null || !script.can_instantiate():
			failed.append("%s: doesn't compile" % file_name)
			continue
		for method in script.get_script_method_list():
			var method_name: String = method.name
			if !method_name.begins_with("test_"):
				continue
			var case: RefCounted = script.new()
			case.tree = self
			counter.take() # Errors from before this test aren't its own
			await case.call(method_name)
			var problems: Array[String] = case.failures.duplicate()
			for error in counter.take():
				problems.append("error logged: " + error)
			_reset_tuning()
			var label := "%s %s" % [file_name.get_basename(), method_name]
			if problems.is_empty():
				passed += 1
				print("PASS  ", label)
			else:
				print("FAIL  ", label)
				for problem in problems:
					print("        ", problem)
				failed.append(label)
	_leave_game()
	await process_frame
	print("")
	if failed.is_empty():
		print("TESTS PASSED: %d" % passed)
		quit(0)
	else:
		printerr("TESTS FAILED: %d of %d" % [failed.size(), failed.size() + passed])
		quit(1)

# Tuning (and its cheats) back to the shipped values, and normal speed.
func _reset_tuning() -> void:
	root.get_node("Tuning").reset_all()
	root.get_node("Juice").end_time_effects()
	paused = false

func _leave_game() -> void:
	if current_scene != null:
		current_scene.queue_free()
