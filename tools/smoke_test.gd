extends SceneTree

# Headless smoke test: loads every script and scene under res://src, then boots the
# game from its main scene and runs it for a few seconds. Exits with code 1 if any
# error was logged along the way.
#
#   Godot_console.exe --headless --path . -s res://tools/smoke_test.gd

const RUN_FRAMES = 240

class ErrorCounter extends Logger:
	var errors = 0
	var unique = {} # "message @ script:line" -> count
	var _mutex = Mutex.new()

	func _log_error(_function, file, line, code, rationale, _editor_notify, error_type, script_backtraces):
		if error_type == ERROR_TYPE_WARNING:
			return
		var where = "%s:%d" % [file, line]
		for bt in script_backtraces:
			if bt.get_frame_count() > 0:
				where = "%s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
				break
		var key = "%s @ %s" % [rationale if rationale != "" else code, where]
		_mutex.lock()
		errors += 1
		unique[key] = unique.get(key, 0) + 1
		_mutex.unlock()

	func _log_message(_message, _error):
		pass

var counter = ErrorCounter.new()
var frames = 0

func _initialize():
	OS.add_logger(counter)
	var paths = []
	_collect("res://src", paths)
	for path in paths:
		_check(path)
	print("Loaded ", paths.size(), " scripts/scenes")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

func _physics_process(_delta):
	frames += 1
	if frames < RUN_FRAMES:
		return false
	print("Ran ", frames, " frames from ", current_scene.scene_file_path if current_scene else "<no scene>")
	if counter.errors > 0:
		for key in counter.unique:
			printerr("  x%d  %s" % [counter.unique[key], key])
		printerr("SMOKE TEST FAILED: ", counter.errors, " error(s), ", counter.unique.size(), " unique")
		quit(1)
	else:
		print("SMOKE TEST PASSED")
		quit(0)
	return true

func _check(path):
	var res = load(path)
	if res == null:
		_fail("LOAD FAILED", path)
	elif res is GDScript and not res.can_instantiate():
		_fail("SCRIPT ERROR", path)
	elif res is PackedScene:
		var inst = res.instantiate()
		if inst == null:
			_fail("INSTANTIATE FAILED", path)
		else:
			inst.free()

func _fail(what, path):
	counter.errors += 1
	counter.unique["%s @ %s" % [what, path]] = 1

func _collect(dir_path, out):
	var dir = DirAccess.open(dir_path)
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir_path + "/" + f)
	for d in dir.get_directories():
		_collect(dir_path + "/" + d, out)
