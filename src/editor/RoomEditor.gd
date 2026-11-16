extends Node2D

# The room creator, opened with F1 on the title screen. Shows a blank 13x13 room to paint:
# pick a tool on the left, left-click or drag on the floor to paint it, right-click to
# erase. Play builds the room on its own to test it (F1 there comes back here); Export
# writes it to a text file (and the clipboard) that can be turned into a room scene, and
# Open folder shows where the files went. Ctrl+Z undoes; Ctrl+Y or Ctrl+Shift+Z redo.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"
const PLAY_SCENE := "res://src/world/Overworld.tscn"
# Exports go in a room_designs folder: in the project when it's run from source, beside the
# game's executable in an exported build (where players can find it), and in the user data
# folder if neither can be written to (a read-only install folder, or inside a macOS app).
const EXPORT_FOLDER := "room_designs"
const EXPORT_DIR_FALLBACK := "user://room_designs"

const ZOOM := 2.5
const PANEL_WIDTH := 420.0 # Screen pixels; the room is centred in the space right of it
const FONT_SIZE := 26
const GRID_COLOR := Color(1, 1, 1, 0.08)
const HOVER_COLOR := Color(1, 0.9, 0.3, 0.9)
const ERASE_COLOR := Color(1, 0.3, 0.3, 0.9)
const SELECTED_COLOR := Color(0.95, 0.8, 0.35) # Background of the selected tool and clear condition

# The Clear menu's items, and what each says it cleared.
enum ClearWhat { EVERYTHING, ENEMIES, TILES }
const CLEAR_LABELS := {
	ClearWhat.EVERYTHING: "Everything",
	ClearWhat.ENEMIES: "Enemies",
	ClearWhat.TILES: "Tiles",
}
const CLEAR_HINTS := {
	ClearWhat.EVERYTHING: "",
	ClearWhat.ENEMIES: "  (switches stay)",
	ClearWhat.TILES: "  (pitfalls and stalagmites)",
}

# Each tool: [label, what it paints ("cell", "object" or "erase"), value].
const TOOLS := [
	["Floor", "cell", RoomDesign.Cell.FLOOR],
	["Pitfall", "cell", RoomDesign.Cell.PIT],
	["Stalagmite", "cell", RoomDesign.Cell.STALAGMITE],
	["Goblin", "object", "goblin"],
	["Knight", "object", "knight"],
	["Wizard", "object", "wizard"],
	["Switch", "object", "switch"],
	["Eraser", "erase", null],
]

var design: RoomDesign
var tool := 1 # Index into TOOLS; starts on Pitfall
var _preview: Node2D # A blank room the design is painted onto
var _objects: Node2D # Sprites standing in for the design's enemies and switches
var _overlay: Node2D # Grid lines and the hovered cell
var _hover := Vector2i(-1, -1) # Floor index under the mouse, or off the floor
var _painting := 0 # Mouse button held down over the floor (MOUSE_BUTTON_LEFT/RIGHT), or 0
var _stroke_before := {} # The design as the current click-and-drag began, for its undo step
var _undo_button: Button
var _redo_button: Button
var _sprite_cache := {} # Object kind -> AnimatedSprite2D to copy
var _tool_buttons: Array[Button] = []
var _info: Label
var _warning: Label
var _clear_buttons := {} # "none"/"enemies"/"switches" -> its Button
var _status: Label
var _open_folder: Button
var _export_dir := "" # Absolute folder the last export went to

func _ready() -> void:
	Overworld.test_design = null
	Music.stop_all()
	if RoomDesign.current == null:
		RoomDesign.current = RoomDesign.new()
	design = RoomDesign.current

	_preview = (load(RoomDesign.BLANK_ROOM) as PackedScene).instantiate()
	# Only the room's tiles are wanted; its script would run the game's room logic.
	_preview.set_script(null)
	for unwanted in ["Void", "RoomDetection", "GoblinDeath", "KnightDeath"]:
		_preview.get_node(unwanted).free()
	add_child(_preview)
	FloorTheme.apply(_preview, SaveData.floor_number)
	design.paint_all(_preview)

	_objects = Node2D.new()
	_objects.z_index = 5
	_preview.add_child(_objects)
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	_preview.add_child(_overlay)

	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * ZOOM
	var room_centre := (Vector2(Room.LEFT_WALL, Room.TOP_WALL)
		+ Vector2.ONE * (Room.FLOOR_FIRST + RoomDesign.SIZE + 1)) * Room.CELL_SIZE / 2.0
	camera.position = room_centre - Vector2(PANEL_WIDTH / 2.0 / ZOOM, 0)
	add_child(camera)

	_build_ui()
	_refresh_objects()
	_refresh_info()
	_refresh_history()
	_select_tool(tool)

func _exit_tree() -> void:
	# The cached sprites are never in the tree, so nothing else frees them.
	for sprite: AnimatedSprite2D in _sprite_cache.values():
		sprite.free()
	_sprite_cache.clear()

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if button.pressed:
				_painting = button.button_index
				_stroke_before = design.snapshot()
				_update_hover()
				_apply(_hover, true)
			elif _painting == button.button_index:
				_painting = 0
				# A whole click-and-drag is one undo step.
				design.record(_stroke_before)
				_refresh_history()
	elif event is InputEventMouseMotion:
		_update_hover()
		if _painting != 0:
			_apply(_hover, false)
	elif event is InputEventKey && event.pressed && !event.echo:
		var key_event := event as InputEventKey
		var key := key_event.keycode
		if key_event.is_command_or_control_pressed():
			if key == KEY_Z && !key_event.shift_pressed:
				_undo()
			elif key == KEY_Y || (key == KEY_Z && key_event.shift_pressed):
				_redo()
		elif key == KEY_ESCAPE:
			get_tree().change_scene_to_file(TITLE_SCENE)
		elif key == KEY_F5:
			_play()
		elif key >= KEY_1 && key < KEY_1 + TOOLS.size():
			_select_tool(key - KEY_1)

func _update_hover() -> void:
	var tiles: TileMap = _preview.get_node("Tiles")
	var index := RoomDesign.floor_index(tiles.local_to_map(tiles.get_local_mouse_position()))
	if !RoomDesign.in_floor(index):
		index = Vector2i(-1, -1)
	if index != _hover:
		_hover = index
		_overlay.queue_redraw()

# Paints the current tool (or erases, while the right button is held) on `index`.
# Objects go down on a click only, so a drag doesn't fill the floor with goblins.
func _apply(index: Vector2i, clicked: bool) -> void:
	if !RoomDesign.in_floor(index):
		return
	var what: String = TOOLS[tool][1]
	if _painting == MOUSE_BUTTON_RIGHT || what == "erase":
		design.erase(index)
	elif what == "cell":
		design.set_cell(index, TOOLS[tool][2])
	elif clicked:
		design.set_object(index, TOOLS[tool][2])
	else:
		return
	design.paint(_preview, index)
	_refresh_objects()
	_refresh_info()

# --- Actions ---

func _undo() -> void:
	if _painting == 0 && design.can_undo():
		design.undo()
		_redraw_design()
		_status.text = "Undone"

func _redo() -> void:
	if _painting == 0 && design.can_redo():
		design.redo()
		_redraw_design()
		_status.text = "Redone"

# Redraws everything from the design, after it changed wholesale (undo, redo, clear).
func _redraw_design() -> void:
	design.paint_all(_preview)
	_refresh_objects()
	_refresh_info()
	_refresh_history()

func _refresh_history() -> void:
	_undo_button.disabled = !design.can_undo()
	_redo_button.disabled = !design.can_redo()

func _play() -> void:
	Overworld.test_design = design
	get_tree().change_scene_to_file(PLAY_SCENE)

func _export() -> void:
	var text := design.to_text()
	DisplayServer.clipboard_set(text)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_name := "room_%s.txt" % stamp
	var error := OK
	for dir in _export_dirs():
		error = _write(dir.path_join(file_name), text)
		if error == OK:
			_export_dir = dir
			_open_folder.disabled = false
			_status.text = "Exported to %s (also copied to the clipboard)" % dir.path_join(file_name)
			return
	_status.text = "Couldn't save the file (%s), but it's copied to the clipboard" % error_string(error)

# Folders to try exporting to, best first, as absolute paths.
func _export_dirs() -> PackedStringArray:
	var dirs := PackedStringArray()
	if OS.has_feature("editor"):
		dirs.append(ProjectSettings.globalize_path("res://").path_join(EXPORT_FOLDER))
	elif !OS.has_feature("macos"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join(EXPORT_FOLDER))
	dirs.append(ProjectSettings.globalize_path(EXPORT_DIR_FALLBACK))
	return dirs

func _write(path: String, text: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK && error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

func _open_export_folder() -> void:
	if _export_dir != "":
		OS.shell_open(_export_dir)

# Clears what the Clear menu's item `what` names (a ClearWhat).
func _clear(what: int) -> void:
	var before := design.snapshot()
	match what:
		ClearWhat.EVERYTHING: design.clear()
		ClearWhat.ENEMIES: design.clear_enemies()
		ClearWhat.TILES: design.clear_tiles()
	design.record(before)
	_redraw_design()
	_status.text = "Cleared %s (Ctrl+Z to undo)" % (CLEAR_LABELS[what] as String).to_lower()

func _select_tool(index: int) -> void:
	tool = index
	for i in range(_tool_buttons.size()):
		_tool_buttons[i].button_pressed = i == index
	_overlay.queue_redraw()

func _set_clear_by(condition: String) -> void:
	var before := design.snapshot()
	design.clear_by = condition
	design.record(before)
	_refresh_info()
	_refresh_history()

# --- Drawing ---

func _draw_overlay() -> void:
	var size := Room.CELL_SIZE
	var first := Vector2.ONE * Room.FLOOR_FIRST * size
	var length := RoomDesign.SIZE * size
	for i in range(RoomDesign.SIZE + 1):
		_overlay.draw_line(first + Vector2(i * size, 0), first + Vector2(i * size, length), GRID_COLOR)
		_overlay.draw_line(first + Vector2(0, i * size), first + Vector2(length, i * size), GRID_COLOR)
	if RoomDesign.in_floor(_hover):
		var colour := ERASE_COLOR if TOOLS[tool][1] == "erase" else HOVER_COLOR
		var rect := Rect2(Vector2(RoomDesign.tile_cell(_hover)) * size, Vector2.ONE * size)
		_overlay.draw_rect(rect, colour, false, 1.0)

func _refresh_objects() -> void:
	for child in _objects.get_children():
		child.free()
	for index: Vector2i in design.objects:
		var kind: String = design.objects[index]
		var marker := Node2D.new()
		marker.position = RoomDesign.object_origin(kind, index)
		marker.add_child(_sprite_for(kind))
		_objects.add_child(marker)

# A still copy of the first frame `kind`'s scene shows, placed as it is in the scene.
func _sprite_for(kind: String) -> AnimatedSprite2D:
	if !_sprite_cache.has(kind):
		var scene: Node = (load(RoomDesign.OBJECT_SCENES[kind]) as PackedScene).instantiate()
		var source: AnimatedSprite2D = scene.get_node("AnimatedSprite2D")
		# The scene's root can be scaled too (enemies are 0.75), so that's folded in.
		var root_scale: Vector2 = (scene as Node2D).scale
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = source.sprite_frames
		sprite.animation = source.animation
		sprite.position = source.position * root_scale
		sprite.offset = source.offset
		sprite.scale = source.scale * root_scale
		sprite.centered = source.centered
		sprite.flip_h = source.flip_h
		_sprite_cache[kind] = sprite
		scene.free()
	return (_sprite_cache[kind] as AnimatedSprite2D).duplicate()

func _refresh_info() -> void:
	_info.text = "Enemies: %d\nSwitches: %d" % [design.enemy_count(), design.count("switch")]
	for condition: String in _clear_buttons:
		_clear_buttons[condition].button_pressed = condition == design.clear_by
	_warning.text = design.clear_problem()
	_warning.visible = _warning.text != ""

# --- UI ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	var panel := PanelContainer.new()
	panel.theme = theme
	panel.position = Vector2.ZERO
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 1080)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Room Creator"
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)

	var group := ButtonGroup.new()
	for i in range(TOOLS.size()):
		var button := _add_button(column, "%d  %s" % [i + 1, TOOLS[i][0]], _select_tool.bind(i))
		button.toggle_mode = true
		button.button_group = group
		_tool_buttons.append(button)

	column.add_child(HSeparator.new())
	_info = Label.new()
	column.add_child(_info)
	var clear_label := Label.new()
	clear_label.text = "Room clears by:"
	column.add_child(clear_label)
	var choices := HBoxContainer.new()
	column.add_child(choices)
	var clear_group := ButtonGroup.new()
	for condition: String in ["none", "enemies", "switches"]:
		var button := _add_button(choices, condition.capitalize(), _set_clear_by.bind(condition))
		button.toggle_mode = true
		button.button_group = clear_group
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_clear_buttons[condition] = button
	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
	_warning.add_theme_font_size_override("font_size", 20)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_warning)
	column.add_child(HSeparator.new())
	var history := HBoxContainer.new()
	column.add_child(history)
	_undo_button = _add_button(history, "Undo", _undo)
	_redo_button = _add_button(history, "Redo", _redo)
	for button in [_undo_button, _redo_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.tooltip_text = "Ctrl+Z"
	_redo_button.tooltip_text = "Ctrl+Y or Ctrl+Shift+Z"
	_add_button(column, "Play  (F5)", _play)
	_add_button(column, "Export", _export)
	_open_folder = _add_button(column, "Open folder", _open_export_folder)
	_open_folder.disabled = true # Until something has been exported
	column.add_child(_clear_menu())
	_add_button(column, "Back  (Esc)", get_tree().change_scene_to_file.bind(TITLE_SCENE))

	var help := Label.new()
	help.theme = theme
	help.text = "Left click: paint    Right click: erase    1-%d: pick a tool    Ctrl+Z: undo    Ctrl+Y: redo" % TOOLS.size()
	help.position = Vector2(PANEL_WIDTH + 32, 24)
	layer.add_child(help)
	_status = Label.new()
	_status.theme = theme
	_status.position = Vector2(PANEL_WIDTH + 32, 1080 - 64)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size = Vector2(1920 - PANEL_WIDTH - 64, 48)
	layer.add_child(_status)

# The Clear button, which opens a menu: clear everything, just the enemies, or just the tiles.
func _clear_menu() -> MenuButton:
	var menu := MenuButton.new()
	menu.text = "Clear  ▾"
	menu.flat = false # Drawn like the other buttons
	menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.focus_mode = Control.FOCUS_NONE
	var popup := menu.get_popup()
	popup.add_theme_font_size_override("font_size", FONT_SIZE)
	for what: int in CLEAR_LABELS:
		popup.add_item(CLEAR_LABELS[what] + CLEAR_HINTS[what], what)
	popup.id_pressed.connect(_clear)
	return menu

func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE # Keys belong to the editor, not a focused button
	# The selected tool or clear condition stands out; the default pressed look is a shade darker.
	var selected := StyleBoxFlat.new()
	selected.bg_color = SELECTED_COLOR
	selected.set_content_margin_all(4)
	selected.content_margin_left = 6
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
