extends SceneTree

# Zips each export folder given on the command line into builds/InfiniteLabyrinth-<folder>.zip,
# with the folder's files at the top of the zip (no folder inside), the way release zips have
# always been laid out. Run by tools/export_builds.sh; done in Godot so it works the same on
# every OS without needing a zip tool installed.
#
#   godot --headless --path . -s res://tools/zip_builds.gd -- builds/Windows64 builds/Linux64

const ZIP_PREFIX := "InfiniteLabyrinth-"


func _init() -> void:
	var folders := OS.get_cmdline_user_args()
	if folders.is_empty():
		push_error("Give the export folders to zip, e.g. builds/Windows64.")
		quit(1)
		return
	for folder in folders:
		if not _zip_folder(folder):
			quit(1)
			return
	quit(0)


func _zip_folder(folder: String) -> bool:
	var dir_path := ProjectSettings.globalize_path("res://" + folder)
	var files := DirAccess.get_files_at(dir_path)
	if files.is_empty():
		push_error("Nothing to zip in %s." % folder)
		return false
	var zip_path := dir_path.get_base_dir().path_join(ZIP_PREFIX + dir_path.get_file() + ".zip")
	var zip := ZIPPacker.new()
	if zip.open(zip_path) != OK:
		push_error("Couldn't create %s." % zip_path)
		return false
	for file in files:
		var bytes := FileAccess.get_file_as_bytes(dir_path.path_join(file))
		zip.start_file(file)
		zip.write_file(bytes)
		zip.close_file()
	zip.close()
	print("%s: %s" % [zip_path.get_file(), ", ".join(files)])
	return true
