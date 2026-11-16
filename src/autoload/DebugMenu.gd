extends CanvasLayer

# Debug menu, debug builds only. F2 opens it over the game (pausing it) and closes it
# again. Tabs hold the Tuning values plus a Progress tab for the running floor (health,
# coins, keys, arrows, time, upgrade levels). Every row has its own Reset; Reset all
# resets every row. Tuning rows reset to the shipped value, Progress rows to what they
# were when the menu was opened. Export writes every Tuning value, changed ones marked,
# to a tuning_exports folder (like the room creator's export) and copies it to the
# clipboard.

const EXPORT_FOLDER := "tuning_exports"
const EXPORT_DIR_FALLBACK := "user://tuning_exports"
const LAYER := 100 # Above every game and menu layer

const FONT_SIZE := 24
const TITLE_SIZE := 40
const NAME_WIDTH := 560.0
const VALUE_WIDTH := 240.0
const DEFAULT_WIDTH := 280.0
const MARGIN := 48

const GRADIENT_TOP := Color(0.03, 0.04, 0.1, 0.85)
const GRADIENT_BOTTOM := Color(0.12, 0.03, 0.1, 0.7)
const TAB_PANEL := Color(0, 0, 0, 0.3) # Behind the rows; translucent like the background
const BUTTON := Color(0.22, 0.24, 0.33)
const BUTTON_HOVER := Color(0.32, 0.35, 0.48)
const BUTTON_PRESSED := Color(0.95, 0.8, 0.35)
const BUTTON_DISABLED := Color(0.15, 0.16, 0.21)
const FIELD := Color(0.09, 0.1, 0.14)
const FIELD_FOCUS := Color(0.95, 0.8, 0.35)
const CHANGED := Color(1, 0.85, 0.35) # Names of rows that differ from their reset value
const DIM := Color(1, 1, 1, 0.55)

const PROGRESS_TAB := "Progress"

# One editable row. Tuning rows read and write a Tuning key; Progress rows go through
# getter and setter, which reach into the running game.
class Row:
	var key := "" # Tuning key, or "" for a Progress row
	var getter: Callable
	var setter: Callable
	var reset_to: Variant # Shipped value (Tuning) or value when the menu opened (Progress)
	var reset_word := "default"
	var kind := TYPE_FLOAT # TYPE_FLOAT, TYPE_INT or TYPE_BOOL
	var name_label: Label
	var spin: SpinBox
	var check: CheckButton
	var reset_label: Label
	var reset_button: Button

var _root: Control
var _tabs: TabContainer
var _progress_box: VBoxContainer
var _status: Label
var _open_folder: Button
var _rows: Array[Row] = []
var _rows_by_key := {} # Tuning key -> Row
var _progress_rows: Array[Row] = []
var _paused_by_menu := false # The menu paused the tree, so closing it unpauses
var _export_dir := ""

func _ready() -> void:
	if !OS.is_debug_build():
		queue_free()
		return
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	Tuning.changed.connect(_on_tuning_changed)

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null && key.pressed && !key.echo && key.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()

func open() -> void:
	_paused_by_menu = !get_tree().paused
	get_tree().paused = true
	_build_progress()
	for row in _rows:
		_refresh(row)
	_status.text = ""
	visible = true

func close() -> void:
	visible = false
	get_viewport().gui_release_focus()
	if _paused_by_menu:
		get_tree().paused = false
	_paused_by_menu = false

# --- Rows ---

func _make_row(parent: Control, label: String, kind: int, min_value: float, max_value: float,
		step: float, tooltip := "") -> Row:
	var row := Row.new()
	row.kind = kind
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	parent.add_child(line)

	row.name_label = Label.new()
	row.name_label.text = label
	row.name_label.custom_minimum_size.x = NAME_WIDTH
	row.name_label.tooltip_text = tooltip
	row.name_label.mouse_filter = Control.MOUSE_FILTER_PASS # For the tooltip
	line.add_child(row.name_label)

	if kind == TYPE_BOOL:
		row.check = CheckButton.new()
		row.check.custom_minimum_size.x = VALUE_WIDTH
		row.check.toggled.connect(func(on: bool) -> void: _edit(row, on))
		line.add_child(row.check)
	else:
		row.spin = SpinBox.new()
		row.spin.min_value = min_value
		row.spin.max_value = max_value
		row.spin.step = step
		row.spin.rounded = kind == TYPE_INT
		row.spin.allow_greater = true # The range is a guide; debugging may need more
		row.spin.select_all_on_focus = true
		row.spin.custom_minimum_size.x = VALUE_WIDTH
		row.spin.value_changed.connect(func(value: float) -> void: _edit(row, value))
		line.add_child(row.spin)

	row.reset_label = Label.new()
	row.reset_label.custom_minimum_size.x = DEFAULT_WIDTH
	row.reset_label.add_theme_color_override("font_color", DIM)
	line.add_child(row.reset_label)

	row.reset_button = _button(line, "Reset", func() -> void: _reset(row))
	_rows.append(row)
	return row

func _tuning_row(parent: Control, field: Array) -> void:
	var key: String = field[1]
	var default: Variant = Tuning.default_of(key)
	var row := _make_row(parent, field[2], typeof(default), field[3], field[4], field[5], field[6])
	row.key = key
	row.getter = Tuning.get.bind(key)
	row.setter = func(value: Variant) -> void: Tuning.set_value(key, value)
	row.reset_to = default
	_rows_by_key[key] = row

# open_ended lets the spin box go past max_value.
func _progress_row(label: String, kind: int, max_value: float, step: float, open_ended: bool,
		getter: Callable, setter: Callable) -> void:
	var row := _make_row(_progress_box, label, kind, 0, max_value, step)
	row.spin.allow_greater = open_ended
	row.getter = getter
	row.setter = setter
	row.reset_to = getter.call()
	row.reset_word = "was"
	row.reset_label.tooltip_text = "Progress rows reset to their value when the menu opened"
	_progress_rows.append(row)

# The control changed: convert to the row's type, apply, and redraw the row.
func _edit(row: Row, value: Variant) -> void:
	match row.kind:
		TYPE_INT: value = roundi(value)
		TYPE_BOOL: value = bool(value)
		_: value = float(value)
	row.setter.call(value)
	_refresh(row)

func _reset(row: Row) -> void:
	row.setter.call(row.reset_to)
	_refresh(row)

func _reset_all() -> void:
	for row in _rows:
		_reset(row)
	_status.text = "Everything reset"

func _refresh(row: Row) -> void:
	var value: Variant = row.getter.call()
	if row.check != null:
		row.check.set_pressed_no_signal(value)
		row.check.text = "On" if value else "Off"
	else:
		row.spin.set_value_no_signal(value)
	var changed := !_same(value, row.reset_to)
	row.name_label.add_theme_color_override("font_color", CHANGED if changed else Color.WHITE)
	row.reset_label.text = "%s %s" % [row.reset_word, _format(row.reset_to)]
	row.reset_button.disabled = !changed

func _on_tuning_changed(key: String) -> void:
	if _rows_by_key.has(key):
		_refresh(_rows_by_key[key])
	if key == "base_health":
		_sync_hearts()

static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT || typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b

static func _format(value: Variant) -> String:
	if typeof(value) == TYPE_BOOL:
		return "on" if value else "off"
	if typeof(value) == TYPE_FLOAT:
		return String.num(value, 3)
	return str(value)

# --- Progress tab: the running floor ---

# Rebuilt on every open, since the floor (and so the player) may have changed since.
func _build_progress() -> void:
	for row in _progress_rows:
		_rows.erase(row)
	_progress_rows.clear()
	for child in _progress_box.get_children():
		child.queue_free()

	var player := Game.player
	if player == null || !is_instance_valid(player):
		var note := Label.new()
		note.text = "Start a run to edit health, coins, keys, arrows and time."
		note.add_theme_color_override("font_color", DIM)
		_progress_box.add_child(note)
		return

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	_progress_box.add_child(actions)
	_button(actions, "Full heal", _full_heal)
	_button(actions, "Kill enemies in this room", _kill_room_enemies)
	_button(actions, "Next floor", _next_floor)

	_progress_row("Health", TYPE_FLOAT, player.max_health(), 0.5, false,
		func() -> float: return Game.player.health,
		func(value: float) -> void:
			Game.player.health = value
			Game.health_changed.emit(value))
	_progress_row("Coins (this floor)", TYPE_INT, 10000, 1, true,
		func() -> int: return Game.coins,
		func(value: int) -> void: Game.add_coins(value - Game.coins))
	_progress_row("Keys", TYPE_INT, 3, 1, false,
		func() -> int: return Game.keys,
		func(value: int) -> void: Game.add_keys(value - Game.keys))
	_progress_row("Arrows", TYPE_INT, 99, 1, true,
		func() -> int: return Game.arrows,
		func(value: int) -> void: Game.add_arrows(value - Game.arrows))
	_progress_row("Time left (s)", TYPE_INT, Tuning.time_limit(), 1, true,
		func() -> int: return ceili(Game.player.level_countdown.time_left),
		func(value: int) -> void:
			if value > 0:
				Game.player.level_countdown.start(value))
	_progress_row("Floor (art changes next floor)", TYPE_INT, 10, 1, true,
		func() -> int: return Game.overworld.floor_number,
		func(value: int) -> void:
			Game.overworld.floor_number = maxi(value, 1)
			SaveData.floor_number = maxi(value, 1)
			SaveData.save())
	for upgrade: Array in [["health_level", "Health upgrade"], ["damage_level", "Damage (crit) upgrade"],
			["time_level", "Time upgrade (next floor)"], ["looting_level", "Looting upgrade"]]:
		var field: String = upgrade[0]
		_progress_row(upgrade[1], TYPE_INT, UpgradeMenu.MAX_LEVEL, 1, false,
			func() -> int: return SaveData.get(field),
			func(value: int) -> void: _set_upgrade(field, value))
	_refresh_progress()

func _set_upgrade(field: String, value: int) -> void:
	SaveData.set(field, clampi(value, 0, UpgradeMenu.MAX_LEVEL))
	SaveData.save()
	match field:
		"health_level": _sync_hearts()
		"damage_level":
			for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
				enemy.critical_chance = SaveData.damage_level

# Max health changed: resize the heart row and keep health within it.
func _sync_hearts() -> void:
	var player := Game.player
	if player == null || !is_instance_valid(player):
		return
	for hearts: Node in get_tree().get_nodes_in_group("hearts"):
		hearts.set_max_hearts(player.max_health())
	player.health = minf(player.health, player.max_health())
	Game.health_changed.emit(player.health)
	for row in _progress_rows:
		if row.name_label.text == "Health":
			row.spin.max_value = player.max_health()
			_refresh(row)

func _full_heal() -> void:
	Game.player.health = Game.player.max_health()
	Game.health_changed.emit(Game.player.health)
	_refresh_progress()
	_status.text = "Healed to %s hearts" % Game.player.max_health()

func _kill_room_enemies() -> void:
	var killed := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		# The boss's death ends the run, so it is left out.
		if enemy.is_queued_for_deletion() || enemy.scene_file_path.get_file() == "Boss.tscn":
			continue
		if enemy.room.room_id == Game.player.current_room:
			enemy.die()
			killed += 1
	_refresh_progress()
	_status.text = "Killed %d enem%s" % [killed, "y" if killed == 1 else "ies"]

# Ends the floor as the end room does: on to the upgrade menu, then the next floor.
func _next_floor() -> void:
	close()
	SaveData.floor_number = Game.overworld.floor_number + 1
	Game.upgrade_menu.show_menu()

func _refresh_progress() -> void:
	for row in _progress_rows:
		_refresh(row)

# --- Export ---

func _export() -> void:
	var text := _export_text()
	DisplayServer.clipboard_set(text)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_name := "tuning_%s.txt" % stamp
	var error := OK
	for dir in _export_dirs():
		error = _write(dir.path_join(file_name), text)
		if error == OK:
			_export_dir = dir
			_open_folder.disabled = false
			_status.text = "Exported to %s (also copied to the clipboard)" % dir.path_join(file_name)
			return
	_status.text = "Couldn't save the file (%s), but it's copied to the clipboard" % error_string(error)

# Changed values first, then every value by tab, each with its default and where it lives.
func _export_text() -> String:
	var changed: PackedStringArray = []
	var all: PackedStringArray = []
	var category := ""
	for field: Array in Tuning.FIELDS:
		var key: String = field[1]
		if field[0] != category:
			category = field[0]
			all.append("\n[%s]" % category)
		var value: Variant = Tuning.get(key)
		var is_changed := !_same(value, Tuning.default_of(key))
		var line := "%s %s = %s  (default %s; %s)" % ["*" if is_changed else " ", key,
			_format(value), _format(Tuning.default_of(key)), field[6]]
		all.append(line)
		if is_changed:
			changed.append(line)
	var lines: PackedStringArray = [
		"# Infinite Labyrinth tuning export, %s" % Time.get_datetime_string_from_system(false, true),
		"# key = value  (default; where the value lives in the code). * marks a changed value.",
		"",
		"[Changed]",
	]
	if changed.is_empty():
		lines.append("  (none; every value is at its default)")
	lines.append_array(changed)
	lines.append_array(all)
	return "\n".join(lines) + "\n"

# Folders to try exporting to, best first, as absolute paths. Same rules as the room
# creator: the project folder from the editor, beside the executable in a build.
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

# --- Layout ---

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # Clicks stay off the game underneath
	_root.theme = _make_theme()
	add_child(_root)

	var gradient := Gradient.new()
	gradient.set_color(0, GRADIENT_TOP)
	gradient.set_color(1, GRADIENT_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0.3, 1)
	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title := Label.new()
	title.text = "Debug menu"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	header.add_child(title)
	var hint := Label.new()
	hint.text = "F2 to close. Hover a name to see where it lives in the code."
	hint.add_theme_color_override("font_color", DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(hint)
	_button(header, "Reset all", _reset_all)
	_button(header, "Export", _export)
	_open_folder = _button(header, "Open folder", _open_export_folder)
	_open_folder.disabled = true
	_button(header, "Close", close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_progress_box = _add_tab(PROGRESS_TAB)
	var boxes := {}
	for field: Array in Tuning.FIELDS:
		var category: String = field[0]
		if !boxes.has(category):
			boxes[category] = _add_tab(category)
		_tuning_row(boxes[category], field)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

# A tab holding a scrolling column of rows; returns the column.
func _add_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	return box

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

# Opaque buttons, fields and tabs over the translucent background.
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, _box(BUTTON))
		theme.set_stylebox("hover", type, _box(BUTTON_HOVER))
		theme.set_stylebox("pressed", type, _box(BUTTON_HOVER))
		theme.set_stylebox("hover_pressed", type, _box(BUTTON_HOVER))
		theme.set_stylebox("disabled", type, _box(BUTTON_DISABLED))
		theme.set_stylebox("focus", type, _box(Color.TRANSPARENT, FIELD_FOCUS))
		theme.set_color("font_disabled_color", type, Color(1, 1, 1, 0.3))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED))
	theme.set_color("font_pressed_color", "Button", Color.BLACK)
	theme.set_stylebox("normal", "LineEdit", _box(FIELD))
	theme.set_stylebox("focus", "LineEdit", _box(Color.TRANSPARENT, FIELD_FOCUS))
	theme.set_stylebox("read_only", "LineEdit", _box(FIELD))
	theme.set_stylebox("panel", "TabContainer", _box(TAB_PANEL))
	theme.set_stylebox("tab_selected", "TabContainer", _box(BUTTON_PRESSED))
	theme.set_stylebox("tab_unselected", "TabContainer", _box(BUTTON))
	theme.set_stylebox("tab_hovered", "TabContainer", _box(BUTTON_HOVER))
	theme.set_stylebox("tab_focus", "TabContainer", _box(Color.TRANSPARENT, FIELD_FOCUS))
	theme.set_color("font_selected_color", "TabContainer", Color.BLACK)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", Color(1, 1, 1, 0.85))
	theme.set_stylebox("panel", "TooltipPanel", _box(FIELD, FIELD_FOCUS))
	return theme

func _box(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if border.a > 0:
		box.border_color = border
		box.set_border_width_all(2)
	return box
