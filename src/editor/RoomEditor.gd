extends Node2D

# The room creator, opened with F1 on the title screen. Shows a blank 13x13 room to paint:
# pick a tool on the left (Eraser and Select on top, then tiles, traps and enemies in their
# own tabs, as scrolling grids of icons), left-click or drag on the floor to paint it,
# right-click to erase. Play builds the room on its own to test it (F1 there comes back here); Export
# writes it to a text file (and the clipboard) that can be turned into a room scene, and
# Open folder shows where the files went. Ctrl+Z undoes; Ctrl+Y or Ctrl+Shift+Z redo.
#
# A goblin or knight that's just been placed, or clicked with the Select tool, shows its
# detection radius as a circle; dragging the circle's edge (with any tool) resizes it. The
# filled half is the side it watches: it can't see behind itself.
#
# The Roaming buttons set what the selected goblin or knight does before it notices the
# player: None (stands still), Path or Area. Picking Path or Area switches to the Select
# tool. With a Path enemy selected, clicking or dragging on the floor draws its path (it
# walks there and back; finish on the enemy itself to make a loop it walks round);
# right-click a point to take it off. With an Area enemy selected,
# drag the box's edges or corners to grow or shrink it. Every roaming enemy's path or area
# shows faintly; the selected one's brightly.
#
# The Facing buttons set which way the selected goblin or knight faces when the room
# starts: Up, Down, Left, Right, or Auto, which turns it to face the player as they come
# into the room. Its sprite shows the facing; an Auto one is marked "auto".

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"
const PLAY_SCENE := "res://src/world/Overworld.tscn"
# Exports go in a room_designs folder: in the project when it's run from source, beside the
# game's executable in an exported build (where players can find it), and in the user data
# folder if neither can be written to (a read-only install folder, or inside a macOS app).
const EXPORT_FOLDER := "room_designs"
const EXPORT_DIR_FALLBACK := "user://room_designs"

const ZOOM := 2.5
const PANEL_WIDTH := 500.0 # Screen pixels; the room is centred in the space right of it
const FONT_SIZE := 26
const FACING_FONT_SIZE := 22 # Five buttons share the Facing row
const GRID_COLOR := Color(1, 1, 1, 0.08)
const HOVER_COLOR := Color(1, 0.9, 0.3, 0.9)
const ERASE_COLOR := Color(1, 0.3, 0.3, 0.9)
const SELECTED_COLOR := Color(0.95, 0.8, 0.35) # Background of the selected tool and clear condition
const RADIUS_LINE := Color(0.4, 0.85, 1.0, 0.8) # The selected enemy's detection circle
const RADIUS_LINE_HOT := Color(0.75, 0.95, 1.0, 1.0) # Its edge under the mouse, or being dragged
const RADIUS_FILL := Color(0.4, 0.85, 1.0, 0.12) # The half in front, where it can see
const RADIUS_GRAB := 4.0 # Room pixels either side of the circle's (or area's) edge that grab it
const ROAM_LINE := Color(0.55, 1.0, 0.45, 0.9) # The selected enemy's path or area
const ROAM_LINE_HOT := Color(0.85, 1.0, 0.75, 1.0) # An area edge under the mouse, or being dragged
const ROAM_FILL := Color(0.55, 1.0, 0.45, 0.12)
const ROAM_UNSELECTED := 0.35 # Alpha multiplier for the paths and areas of enemies not selected
const AUTO_MARK := Color(1, 0.9, 0.4, 0.95) # The "auto" over an enemy that turns to face the player
const AUTO_MARK_SIZE := 9 # Room pixels
const AUTO_MARK_RISE := 27.0 # Room pixels above the enemy's origin
const SELECT_TOOL := 1 # Index of Select in TOOLS
# The tool picker (see _build_tool_picker).
const TOOL_TAB_NAMES: Array[String] = ["Tiles", "Traps", "Enemies"]
# Special tiles that go in the Traps tab; the rest of the cells go in Tiles.
const TRAP_CELLS: Array[RoomDesign.Cell] = [RoomDesign.Cell.WIRES, RoomDesign.Cell.SPIKES,
	RoomDesign.Cell.CRACKED, RoomDesign.Cell.PLATE, RoomDesign.Cell.PASTE]
# What each special tile does, shown when hovering its tool.
const SPECIAL_TIPS := {
	RoomDesign.Cell.WIRES: "Exposed wires: spark, then shock whoever's on them. Swing into them while live to break them",
	RoomDesign.Cell.SPIKES: "Spikes: hurt on stepping on, and every second stood on",
	RoomDesign.Cell.CRACKED: "Cracked floor: gives way into a pit when stood on, then mends",
	RoomDesign.Cell.SLICK: "Slick floor: keeps your momentum, so you slide",
	RoomDesign.Cell.PLATE: "Pressure plate: shocks whoever steps on it. Swing into it while live to break it",
	RoomDesign.Cell.PASTE: "Thermal paste: holds whoever steps in; three rolls break free (enemies tear free on their third trip to its edge)",
	RoomDesign.Cell.SLOW: "Slow tile: slower walking, rolling and attacking",
	RoomDesign.Cell.FAST: "Speed tile: faster walking, rolling and attacking",
}
const TOOL_TABS_HEIGHT := 300.0 # Screen pixels, tabs included; each tab scrolls inside it
const TOOL_GRID_COLUMNS := 4
const TOOL_ICON_BUTTON := Vector2(100, 112)
const TOOL_ICON_SIZE := 72 # Widest the picture on a tool button gets
const TOOL_ICON_FONT_SIZE := 14
# Edges of a roaming area, as bits, for dragging them.
const EDGE_LEFT := 1
const EDGE_RIGHT := 2
const EDGE_TOP := 4
const EDGE_BOTTOM := 8
const NO_CELL := Vector2i(-1, -1)
# Floors dropdown items other than the floors themselves (whose ids are 1-10).
const FLOORS_ALL_ID := 100
const FLOORS_NONE_ID := 101

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
	ClearWhat.TILES: "  (pitfalls, rocks, traps)",
}

# Each tool: [label, what it paints ("cell", "object" or "erase"), value].
# The order is the order in each tab's grid; enemies are grouped by family.
const TOOLS := [
	["Eraser", "erase", null],
	["Select", "select", null],
	["Floor", "cell", RoomDesign.Cell.FLOOR],
	["Pitfall", "cell", RoomDesign.Cell.PIT],
	["Stalagmite", "cell", RoomDesign.Cell.STALAGMITE],
	["Switch", "object", "switch"],
	["Slick", "cell", RoomDesign.Cell.SLICK],
	["Slow", "cell", RoomDesign.Cell.SLOW],
	["Speed", "cell", RoomDesign.Cell.FAST],
	["Teleport 1", "cell", RoomDesign.Cell.TELEPORT_1],
	["Teleport 2", "cell", RoomDesign.Cell.TELEPORT_2],
	["Teleport 3", "cell", RoomDesign.Cell.TELEPORT_3],
	["Teleport 4", "cell", RoomDesign.Cell.TELEPORT_4],
	["Wires", "cell", RoomDesign.Cell.WIRES],
	["Spikes", "cell", RoomDesign.Cell.SPIKES],
	["Cracked", "cell", RoomDesign.Cell.CRACKED],
	["Plate", "cell", RoomDesign.Cell.PLATE],
	["Paste", "cell", RoomDesign.Cell.PASTE],
	["Goblin", "object", "goblin"],
	["Troll", "object", "troll"],
	["Orc", "object", "orc"],
	["Knight", "object", "knight"],
	["Dual Knight", "object", "dual_knight"],
	["Wizard", "object", "wizard"],
	["Warlock", "object", "warlock"],
	["Necromancer", "object", "necromancer"],
	["Wyrm", "object", "wyrm"],
	["Wyvern", "object", "wyvern"],
]

var design: RoomDesign
var tool := 3 # Index into TOOLS; starts on Pitfall
var _preview: Node2D # A blank room the design is painted onto
var _objects: Node2D # Sprites standing in for the design's enemies and switches
var _overlay: Node2D # Grid lines and the hovered cell
var _hover := Vector2i(-1, -1) # Floor index under the mouse, or off the floor
var _painting := 0 # Mouse button held down over the floor (MOUSE_BUTTON_LEFT/RIGHT), or 0
var _stroke_before := {} # The design as the current click-and-drag began, for its undo step
var _selected := NO_CELL # Floor index of the selected object, or NO_CELL
var _dragging_radius := false # Resizing the selected enemy's detection circle
var _edge_hot := false # The mouse is over the selected circle's edge
var _area_drag := 0 # EDGE_ bits of the selected roaming area being dragged, or 0
var _area_hot := 0 # EDGE_ bits of the selected roaming area under the mouse (or being dragged)
var _roam_buttons := {} # "none"/"path"/"area" -> its Button
var _facing_buttons := {} # One of RoomDesign.FACINGS -> its Button
var _undo_button: Button
var _redo_button: Button
var _sprite_cache := {} # Object kind -> AnimatedSprite2D to copy
var _tool_buttons: Array[Button] = [] # One per TOOLS entry, in its order
var _tool_tabs: TabContainer # The Tiles and Enemies tabs
var _info: Label
var _warning: Label
var _clear_buttons := {} # "none"/"enemies"/"switches" -> its Button
var _tileset_buttons: Array[Button] = [] # One per FloorTheme.ART_FLOORS, floor 1 first
var _floors_menu: MenuButton # Checklist of the floors the room can appear on
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
	FloorTheme.apply(_preview, design.preview_floor)
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
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed:
			get_viewport().gui_release_focus() # Out of a floor box, so keys reach the editor again
		if button.button_index == MOUSE_BUTTON_LEFT \
				&& (_drag_radius_button(button) || _drag_area_button(button)):
			return
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if button.pressed:
				_painting = button.button_index
				_stroke_before = design.snapshot()
				_update_hover()
				_apply(_hover, true)
			elif _painting == button.button_index:
				_painting = 0
				if _path_owner() != NO_CELL:
					design.simplify_path(_path_owner())
					_overlay.queue_redraw()
					_refresh_info()
				# A whole click-and-drag is one undo step.
				design.record(_stroke_before)
				_refresh_history()
	elif event is InputEventMouseMotion:
		_update_hover()
		if _dragging_radius:
			_resize_radius()
		elif _area_drag != 0:
			_resize_area()
		elif _painting != 0:
			_apply(_hover, false)
		_update_edge_hot()
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
	var what: String = TOOLS[tool][1]
	var path_owner := _path_owner()
	if what == "select" && _painting == MOUSE_BUTTON_LEFT:
		# Clicking the path's own enemy closes the loop back to where it starts, rather than
		# selecting it again.
		var closing := path_owner != NO_CELL && index == path_owner
		if clicked && design.objects.has(index) && !closing:
			_select(index)
		elif path_owner != NO_CELL && RoomDesign.in_floor(index):
			# Drawing the selected enemy's path.
			if design.add_path_point(path_owner, index):
				_overlay.queue_redraw()
				_refresh_info()
		elif clicked: # Clicking off the floor, or on empty floor, drops the selection
			_select(NO_CELL)
		return
	if !RoomDesign.in_floor(index):
		return
	# Right-clicking a point on the selected enemy's path takes it off, rather than erasing.
	if _painting == MOUSE_BUTTON_RIGHT && path_owner != NO_CELL \
			&& design.remove_path_point(path_owner, index):
		_overlay.queue_redraw()
		_refresh_info()
		return
	if _painting == MOUSE_BUTTON_RIGHT || what == "erase":
		design.erase(index)
	elif what == "cell":
		design.set_cell(index, TOOLS[tool][2])
	elif clicked:
		design.set_object(index, TOOLS[tool][2])
		_selected = index # A new enemy shows its circle straight away
	else:
		return
	design.paint(_preview, index)
	_refresh_objects()
	_refresh_info()

# --- Detection radius ---

func _select(index: Vector2i) -> void:
	_selected = index
	_update_edge_hot()
	_overlay.queue_redraw()
	_refresh_info()

# The selected object's cell, if it's a goblin or knight (which have a radius), else NO_CELL.
func _radius_owner() -> Vector2i:
	if design.objects.has(_selected) && RoomDesign.has_radius(design.objects[_selected]):
		return _selected
	return NO_CELL

# Room-local centre of the circle: the enemy's origin, which is what it measures from.
func _radius_centre(index: Vector2i) -> Vector2:
	return RoomDesign.object_origin(design.objects[index], index)

func _mouse_on_edge() -> bool:
	var enemy_cell := _radius_owner()
	if enemy_cell == NO_CELL:
		return false
	var distance := _overlay.get_local_mouse_position().distance_to(_radius_centre(enemy_cell))
	return absf(distance - design.radius_at(enemy_cell)) <= RADIUS_GRAB

# Starts or ends a drag of the circle's edge. True if `button` was used for that, so it
# doesn't also paint.
func _drag_radius_button(button: InputEventMouseButton) -> bool:
	if button.pressed && _painting == 0 && _mouse_on_edge():
		_dragging_radius = true
		_stroke_before = design.snapshot()
		return true
	if !button.pressed && _dragging_radius:
		_dragging_radius = false
		design.record(_stroke_before) # The whole drag is one undo step
		_refresh_history()
		_update_edge_hot()
		return true
	return false

# --- Roaming ---

# The selected object's cell, if it roams along a path, else NO_CELL.
func _path_owner() -> Vector2i:
	return _selected if design.roam_mode(_selected) == "path" else NO_CELL

# The selected object's cell, if it roams in an area, else NO_CELL.
func _area_owner() -> Vector2i:
	return _selected if design.roam_mode(_selected) == "area" else NO_CELL

# Sets the selected goblin or knight roaming `mode` ("none", "path" or "area").
func _set_roam(mode: String) -> void:
	if !design.objects.has(_selected) || !RoomDesign.can_roam(design.objects[_selected]):
		_refresh_info()
		return
	var before := design.snapshot()
	design.set_roam_mode(_selected, mode)
	design.record(before)
	if mode != "none":
		_select_tool(SELECT_TOOL) # So clicks draw the path rather than painting
	match mode:
		"path": _status.text = "Click or drag on the floor to draw its path; right-click a point to remove it"
		"area": _status.text = "Drag the box's edges or corners to resize the area it wanders in"
		_: _status.text = "It stands still until it notices the player"
	_overlay.queue_redraw()
	_update_edge_hot()
	_refresh_info()
	_refresh_history()

# --- Facing ---

# Sets which way the selected goblin or knight faces when the room starts (one of
# RoomDesign.FACINGS).
func _set_facing(facing: String) -> void:
	if !design.objects.has(_selected) || !RoomDesign.can_face(design.objects[_selected]):
		_refresh_info()
		return
	var before := design.snapshot()
	design.set_facing(_selected, facing)
	design.record(before)
	if facing == MeleeEnemy.AUTO_FACING:
		_status.text = "It turns to face the player as they come into the room"
	else:
		_status.text = "It faces %s when the room starts" % facing
	_refresh_objects()
	_refresh_info()
	_refresh_history()

# The EDGE_ bits of the selected area the mouse is over (within RADIUS_GRAB), or 0. If it's
# over both sides of a thin area, the nearer one.
func _area_edges_at_mouse() -> int:
	var enemy_cell := _area_owner()
	if enemy_cell == NO_CELL:
		return 0
	var rect := RoomDesign.area_pixels(design.area_rect(enemy_cell))
	var mouse := _overlay.get_local_mouse_position()
	if !rect.grow(RADIUS_GRAB).has_point(mouse):
		return 0
	var edges := 0
	var to_left := absf(mouse.x - rect.position.x)
	var to_right := absf(mouse.x - rect.end.x)
	if minf(to_left, to_right) <= RADIUS_GRAB:
		edges |= EDGE_LEFT if to_left < to_right else EDGE_RIGHT
	var to_top := absf(mouse.y - rect.position.y)
	var to_bottom := absf(mouse.y - rect.end.y)
	if minf(to_top, to_bottom) <= RADIUS_GRAB:
		edges |= EDGE_TOP if to_top < to_bottom else EDGE_BOTTOM
	return edges

# Starts or ends a drag of the selected area's edges. True if `button` was used for that.
func _drag_area_button(button: InputEventMouseButton) -> bool:
	if button.pressed && _painting == 0 && !_dragging_radius:
		var edges := _area_edges_at_mouse()
		if edges != 0:
			_area_drag = edges
			_stroke_before = design.snapshot()
			return true
	if !button.pressed && _area_drag != 0:
		_area_drag = 0
		design.record(_stroke_before) # The whole drag is one undo step
		_refresh_history()
		_update_edge_hot()
		return true
	return false

# Moves the dragged edges to the cell boundary nearest the mouse.
func _resize_area() -> void:
	var enemy_cell := _area_owner()
	if enemy_cell == NO_CELL:
		return
	var rect := design.area_rect(enemy_cell)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x # One past the last cell
	var bottom := rect.end.y
	var line := Vector2i((_overlay.get_local_mouse_position() / Room.CELL_SIZE).round()) \
		- Vector2i.ONE * Room.FLOOR_FIRST
	if _area_drag & EDGE_LEFT:
		left = line.x
	if _area_drag & EDGE_RIGHT:
		right = line.x
	if _area_drag & EDGE_TOP:
		top = line.y
	if _area_drag & EDGE_BOTTOM:
		bottom = line.y
	design.set_area(enemy_cell, Rect2i(left, top, right - left, bottom - top))
	_overlay.queue_redraw()
	_refresh_info()

func _draw_roams() -> void:
	for index: Vector2i in design.roams:
		var selected := index == _selected
		var tint := Color(1, 1, 1, 1.0 if selected else ROAM_UNSELECTED)
		if design.roam_mode(index) == "path":
			_draw_path(index, tint, selected)
		else:
			_draw_area(index, tint, selected)

func _draw_path(index: Vector2i, tint: Color, selected: bool) -> void:
	var points := PackedVector2Array([RoomDesign.cell_centre(index)])
	for cell: Vector2i in design.path_points(index):
		points.append(RoomDesign.cell_centre(cell))
	if points.size() > 1:
		_overlay.draw_polyline(points, ROAM_LINE * tint, 1.5 if selected else 1.0)
	for i in range(1, points.size()):
		_overlay.draw_circle(points[i], 2.5 if i == points.size() - 1 else 1.5, ROAM_LINE * tint)
	# Where the next click would add a point.
	if selected && TOOLS[tool][1] == "select" && _painting == 0 && RoomDesign.in_floor(_hover) \
			&& !design.objects.has(_hover):
		_overlay.draw_dashed_line(points[-1], RoomDesign.cell_centre(_hover), ROAM_LINE * Color(1, 1, 1, 0.5), 1.0, 3.0)

func _draw_area(index: Vector2i, tint: Color, selected: bool) -> void:
	var rect := RoomDesign.area_pixels(design.area_rect(index))
	_overlay.draw_rect(rect, ROAM_FILL * tint)
	_overlay.draw_rect(rect, ROAM_LINE * tint, false, 1.0)
	if !selected || _area_hot == 0:
		return
	# Light up the edges under the mouse.
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var sides := {EDGE_TOP: [0, 1], EDGE_RIGHT: [1, 2], EDGE_BOTTOM: [2, 3], EDGE_LEFT: [3, 0]}
	for edge: int in sides:
		if _area_hot & edge:
			_overlay.draw_line(corners[sides[edge][0]], corners[sides[edge][1]], ROAM_LINE_HOT, 2.0)

func _resize_radius() -> void:
	var enemy_cell := _radius_owner()
	if enemy_cell == NO_CELL:
		return
	design.set_radius(enemy_cell, _overlay.get_local_mouse_position().distance_to(_radius_centre(enemy_cell)))
	_overlay.queue_redraw()
	_refresh_info()

# Lights up the circle's edge, or the area's edges, and shows a resize cursor while the mouse
# is over them. The circle wins where they cross.
func _update_edge_hot() -> void:
	var idle := _painting == 0 && !_dragging_radius && _area_drag == 0
	var hot := _dragging_radius || (idle && _mouse_on_edge())
	var edges := _area_drag
	if idle && !hot:
		edges = _area_edges_at_mouse()
	if hot != _edge_hot || edges != _area_hot:
		_edge_hot = hot
		_area_hot = edges
		Input.set_default_cursor_shape(_edge_cursor())
		_overlay.queue_redraw()

func _edge_cursor() -> Input.CursorShape:
	if _edge_hot:
		return Input.CURSOR_DRAG
	var horizontal := _area_hot & (EDGE_LEFT | EDGE_RIGHT)
	var vertical := _area_hot & (EDGE_TOP | EDGE_BOTTOM)
	if horizontal && vertical:
		var falling := (_area_hot & EDGE_LEFT && _area_hot & EDGE_TOP) \
			|| (_area_hot & EDGE_RIGHT && _area_hot & EDGE_BOTTOM)
		return Input.CURSOR_FDIAGSIZE if falling else Input.CURSOR_BDIAGSIZE
	if horizontal:
		return Input.CURSOR_HSIZE
	if vertical:
		return Input.CURSOR_VSIZE
	return Input.CURSOR_ARROW

# Drops the selection if what was selected has gone (erased, undone, cleared).
func _check_selection() -> void:
	if _selected != NO_CELL && !design.objects.has(_selected):
		_selected = NO_CELL
	_update_edge_hot()

func _draw_radius() -> void:
	if design.objects.has(_selected):
		var rect := Rect2(Vector2(RoomDesign.tile_cell(_selected)) * Room.CELL_SIZE, Vector2.ONE * Room.CELL_SIZE)
		_overlay.draw_rect(rect, RADIUS_LINE_HOT, false, 1.0)
	var enemy_cell := _radius_owner()
	if enemy_cell == NO_CELL:
		return
	var centre := _radius_centre(enemy_cell)
	var radius := design.radius_at(enemy_cell)
	if radius <= 0:
		_overlay.draw_circle(centre, 1.5, RADIUS_LINE_HOT)
		return
	# The half it watches, facing the way it starts out. An Auto one's depends on the door
	# the player comes in by, so none is shaded.
	var facing := design.facing_at(enemy_cell)
	if facing != MeleeEnemy.AUTO_FACING:
		var ahead := Direction.to_vector(facing).angle()
		var points := PackedVector2Array([centre])
		for i in range(33):
			points.append(centre + Vector2.from_angle(ahead - PI / 2 + PI * i / 32.0) * radius)
		_overlay.draw_colored_polygon(points, RADIUS_FILL)
	var line := RADIUS_LINE_HOT if _edge_hot else RADIUS_LINE
	_overlay.draw_arc(centre, radius, 0, TAU, 96, line, 1.5 if _edge_hot else 1.0)

# --- Actions ---

func _undo() -> void:
	if _painting == 0 && !_dragging_radius && _area_drag == 0 && design.can_undo():
		design.undo()
		_redraw_design()
		_status.text = "Undone"

func _redo() -> void:
	if _painting == 0 && !_dragging_radius && _area_drag == 0 && design.can_redo():
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
	# Its tab comes to the front (the starting tool, as the editor opens).
	var tab := _tool_tab(index)
	if tab != "":
		_tool_tabs.current_tab = TOOL_TAB_NAMES.find(tab)
		(_tool_tabs.get_current_tab_control() as ScrollContainer).ensure_control_visible(_tool_buttons[index])
	_overlay.queue_redraw()

func _set_clear_by(condition: String) -> void:
	var before := design.snapshot()
	design.clear_by = condition
	design.record(before)
	_refresh_info()
	_refresh_history()

# Draws the room with `floor_number`'s tileset (and play-tests with it).
func _set_tileset(floor_number: int) -> void:
	design.preview_floor = floor_number
	FloorTheme.apply(_preview, floor_number)
	_refresh_tool_icons()
	_refresh_info()
	_status.text = "Showing the floor %d tileset" % floor_number

# An item in the floors dropdown: a floor's checkbox (its id is the floor), or tick all/none.
func _on_floor_item(id: int) -> void:
	var before := design.snapshot()
	match id:
		FLOORS_ALL_ID: design.floors = Room.ALL_FLOORS
		FLOORS_NONE_ID: design.floors = 0
		_: design.set_floor(id, !Room.allowed_on(id, design.floors))
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
	_draw_roams()
	_draw_radius()
	_draw_auto_marks()

# "auto" over each enemy that turns to face the player as they come in.
func _draw_auto_marks() -> void:
	var font := ThemeDB.fallback_font
	for index: Vector2i in design.facings:
		if design.facings[index] != MeleeEnemy.AUTO_FACING:
			continue
		var at := RoomDesign.object_origin(design.objects[index], index) - Vector2(0, AUTO_MARK_RISE)
		var width := font.get_string_size("auto", HORIZONTAL_ALIGNMENT_LEFT, -1, AUTO_MARK_SIZE).x
		_overlay.draw_string_outline(font, at - Vector2(width / 2, 0), "auto", HORIZONTAL_ALIGNMENT_LEFT,
			-1, AUTO_MARK_SIZE, 2, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, at - Vector2(width / 2, 0), "auto", HORIZONTAL_ALIGNMENT_LEFT,
			-1, AUTO_MARK_SIZE, AUTO_MARK)

func _refresh_objects() -> void:
	_check_selection()
	_overlay.queue_redraw()
	for child in _objects.get_children():
		child.free()
	for index: Vector2i in design.objects:
		var kind: String = design.objects[index]
		var marker := Node2D.new()
		marker.position = RoomDesign.object_origin(kind, index)
		var sprite := _sprite_for(kind)
		if RoomDesign.can_face(kind):
			# Standing the way it starts out; an Auto one as it waits before the player comes in.
			var facing := design.facing_at(index)
			if facing == MeleeEnemy.AUTO_FACING:
				facing = Direction.RIGHT
			if sprite.sprite_frames.has_animation("idle_" + facing):
				sprite.animation = "idle_" + facing
		marker.add_child(sprite)
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
		sprite.self_modulate = source.self_modulate # A troll's gold tint
		_sprite_cache[kind] = sprite
		scene.free()
	return (_sprite_cache[kind] as AnimatedSprite2D).duplicate()

func _refresh_info() -> void:
	_info.text = "Enemies: %d\nSwitches: %d" % [design.enemy_count(), design.count("switch")]
	if design.objects.has(_selected):
		var kind: String = design.objects[_selected]
		if RoomDesign.has_radius(kind):
			_info.text += "\nSelected %s: detection %d px\n(drag the circle's edge)" \
				% [kind, design.radius_at(_selected)]
		elif kind in ["wizard", "warlock", "necromancer", "wyrm", "wyvern"]:
			_info.text += "\nSelected %s: no detection\nradius (sees the whole room)" % kind
		match design.roam_mode(_selected):
			"path":
				_info.text += "\nRoams a path of %d points" % design.path_points(_selected).size()
			"area":
				var area := design.area_rect(_selected)
				_info.text += "\nRoams an area of %dx%d cells" % [area.size.x, area.size.y]
	var can_face := design.objects.has(_selected) && RoomDesign.can_face(design.objects[_selected])
	for facing: String in _facing_buttons:
		var button: Button = _facing_buttons[facing]
		button.disabled = !can_face
		button.set_pressed_no_signal(can_face && facing == design.facing_at(_selected))
	var can_roam := design.objects.has(_selected) && RoomDesign.can_roam(design.objects[_selected])
	for mode: String in _roam_buttons:
		var button: Button = _roam_buttons[mode]
		button.disabled = !can_roam
		button.set_pressed_no_signal(can_roam && mode == design.roam_mode(_selected))
	for condition: String in _clear_buttons:
		_clear_buttons[condition].button_pressed = condition == design.clear_by
	for i in range(_tileset_buttons.size()):
		_tileset_buttons[i].set_pressed_no_signal(design.preview_floor == i + 1)
	_floors_menu.text = design.floors_text() + "  ▾"
	var popup := _floors_menu.get_popup()
	for n in range(1, Room.FLOOR_CHOICES + 1):
		popup.set_item_checked(popup.get_item_index(n), Room.allowed_on(n, design.floors))
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

	_build_tool_picker(column)

	column.add_child(HSeparator.new())
	column.add_child(_tileset_row())
	column.add_child(_floors_row())
	column.add_child(HSeparator.new())
	_info = Label.new()
	column.add_child(_info)
	column.add_child(_facing_row())
	column.add_child(_roam_row())
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
	# Two to a row, so the panel fits the screen.
	var play_row := HBoxContainer.new()
	column.add_child(play_row)
	var file_row := HBoxContainer.new()
	column.add_child(file_row)
	var play := _add_button(play_row, "Play  (F5)", _play)
	var export := _add_button(play_row, "Export", _export)
	_open_folder = _add_button(file_row, "Open folder", _open_export_folder)
	_open_folder.disabled = true # Until something has been exported
	var clear_menu := _clear_menu()
	file_row.add_child(clear_menu)
	for control: Control in [play, export, _open_folder, clear_menu]:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(column, "Back  (Esc)", get_tree().change_scene_to_file.bind(TITLE_SCENE))

	var help := Label.new()
	help.theme = theme
	help.text = "Left click: paint    Right click: erase    Ctrl+Z: undo    Ctrl+Y: redo"
	help.position = Vector2(PANEL_WIDTH + 32, 24)
	layer.add_child(help)
	_status = Label.new()
	_status.theme = theme
	_status.position = Vector2(PANEL_WIDTH + 32, 1080 - 64)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size = Vector2(1920 - PANEL_WIDTH - 64, 48)
	layer.add_child(_status)

# The tools: Eraser and Select in a row on top, then a tab each for tiles and enemies (see
# _tool_tab), each a scrolling grid of icons.
func _build_tool_picker(column: VBoxContainer) -> void:
	_tool_buttons.resize(TOOLS.size())
	var group := ButtonGroup.new()
	var always := HBoxContainer.new()
	column.add_child(always)
	_tool_tabs = TabContainer.new()
	_tool_tabs.custom_minimum_size = Vector2(0, TOOL_TABS_HEIGHT)
	_tool_tabs.focus_mode = Control.FOCUS_NONE
	column.add_child(_tool_tabs)
	var grids := {}
	for tab: String in TOOL_TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tool_tabs.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = TOOL_GRID_COLUMNS
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		grids[tab] = grid
	for i in range(TOOLS.size()):
		var tab := _tool_tab(i)
		var button: Button
		if tab == "":
			button = _add_button(always, TOOLS[i][0], _select_tool.bind(i))
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			button = _icon_button(grids[tab], i)
		button.toggle_mode = true
		button.button_group = group
		_tool_buttons[i] = button
	_refresh_tool_icons()

# Which tab tool `i` sits in: "Traps" for TRAP_CELLS, "Tiles" for other ground and
# switches, "Enemies" for enemies, or "" for the tools that aren't things to place (Eraser,
# Select), which sit above the tabs. New cell kinds and objects land in a tab without
# listing them here.
func _tool_tab(i: int) -> String:
	match TOOLS[i][1]:
		"cell":
			return "Traps" if TOOLS[i][2] in TRAP_CELLS else "Tiles"
		"object":
			return "Tiles" if TOOLS[i][2] == "switch" else "Enemies"
	return ""

# A square button with the tool's picture over its name. The picture is filled in by
# _refresh_tool_icons.
func _icon_button(grid: GridContainer, i: int) -> Button:
	var button := _add_button(grid, TOOLS[i][0], _select_tool.bind(i))
	button.custom_minimum_size = TOOL_ICON_BUTTON
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.expand_icon = true
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Pixel art stays crisp
	button.add_theme_font_size_override("font_size", TOOL_ICON_FONT_SIZE)
	button.add_theme_constant_override("icon_max_width", TOOL_ICON_SIZE)
	button.clip_text = true
	button.tooltip_text = TOOLS[i][0]
	if TOOLS[i][1] == "cell":
		var kind: RoomDesign.Cell = TOOLS[i][2]
		if SPECIAL_TIPS.has(kind):
			button.tooltip_text = SPECIAL_TIPS[kind]
		elif kind in RoomDesign.TELEPORTS:
			button.tooltip_text = "Teleporter (%s): sends whoever steps on it to the other %s square" \
				% [RoomDesign.TELEPORT_NAMES[RoomDesign.TELEPORTS.find(kind)],
				RoomDesign.TELEPORT_NAMES[RoomDesign.TELEPORTS.find(kind)]]
	return button

# Puts each tile and enemy's picture on its button: the tile as the current tileset draws
# it (so it follows the Tileset buttons), or the first frame the enemy's scene shows, with
# its tint.
func _refresh_tool_icons() -> void:
	for i in range(TOOLS.size()):
		if _tool_tab(i) == "":
			continue
		var button := _tool_buttons[i]
		var tint := Color.WHITE
		if TOOLS[i][1] == "cell":
			button.icon = _tile_icon(TOOLS[i][2])
		else:
			var sprite := _sprite_for(TOOLS[i][2])
			var animation := sprite.animation
			if sprite.sprite_frames.has_animation("idle_down"): # Facing out of the button
				animation = "idle_down"
			button.icon = sprite.sprite_frames.get_frame_texture(animation, 0)
			tint = sprite.self_modulate
			sprite.free()
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
				"icon_hover_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(state, tint)

# One tile of `kind` cut from the preview room's tileset: a plain floor tile, a pit, or a
# stalagmite standing on its own. A special tile's comes from its own art.
func _tile_icon(kind: RoomDesign.Cell) -> Texture2D:
	if RoomDesign.is_special(kind):
		return SpecialTiles.icon(RoomDesign.SPECIAL_FRAMES[kind])
	var map_name := "Tiles"
	var source_id := Room.FLOOR
	match kind:
		RoomDesign.Cell.PIT:
			map_name = "Pitfalls"
			source_id = 0
		RoomDesign.Cell.STALAGMITE:
			map_name = "Stalagmites"
			source_id = Room.STALAGMITE_SOURCES[0]
	var tile_set: TileSet = (_preview.get_node(map_name) as TileMap).tile_set
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null || source.texture == null:
		return null
	var icon := AtlasTexture.new()
	icon.atlas = source.texture
	icon.region = source.get_tile_texture_region(Vector2i.ZERO)
	return icon

# "Tileset" and a button per floor with its own art.
func _tileset_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Tileset"
	row.add_child(label)
	var group := ButtonGroup.new()
	for floor_number in range(1, FloorTheme.ART_FLOORS + 1):
		var button := _add_button(row, "Floor %d" % floor_number, _set_tileset.bind(floor_number))
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Draw the room with floor %d's art (the play-test uses it too)" % floor_number
		_tileset_buttons.append(button)
	return row

# "Facing" and a button per spawn facing, for the selected goblin or knight (disabled
# otherwise).
func _facing_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Facing"
	row.add_child(label)
	var group := ButtonGroup.new()
	for facing: String in RoomDesign.FACINGS:
		var button := _add_button(row, facing.capitalize(), _set_facing.bind(facing))
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", FACING_FONT_SIZE)
		if facing == MeleeEnemy.AUTO_FACING:
			button.tooltip_text = "Turns to face the player as they come into the room"
		else:
			button.tooltip_text = "Faces %s when the room starts" % facing
		button.tooltip_text += " (select a goblin or knight first)"
		_facing_buttons[facing] = button
	return row

# "Roaming" and a button per mode, for the selected goblin or knight (disabled otherwise).
func _roam_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Roaming"
	row.add_child(label)
	var group := ButtonGroup.new()
	var tips := {
		"none": "Stands still until it notices the player",
		"path": "Walks a path you draw, there and back, until it notices the player",
		"area": "Wanders a box you size until it notices the player",
	}
	for mode: String in RoomDesign.ROAM_MODES:
		var button := _add_button(row, mode.capitalize(), _set_roam.bind(mode))
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = tips[mode] + " (select a goblin or knight first)"
		_roam_buttons[mode] = button
	return row

# "Floors [Every floor ▾]": a dropdown of checkboxes, one per floor, for the floors the room
# can appear on. It stays open while ticking, so several can be changed in one go.
func _floors_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Floors"
	row.add_child(label)
	_floors_menu = MenuButton.new()
	_floors_menu.flat = false # Drawn like the other buttons
	_floors_menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_floors_menu.focus_mode = Control.FOCUS_NONE
	_floors_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floors_menu.tooltip_text = "Floors this room can appear on (later floors follow Floor %d)" \
		% Room.FLOOR_CHOICES
	var popup := _floors_menu.get_popup()
	popup.add_theme_font_size_override("font_size", FONT_SIZE)
	popup.hide_on_checkable_item_selection = false
	popup.add_item("Every floor", FLOORS_ALL_ID)
	popup.add_item("No floors", FLOORS_NONE_ID)
	popup.add_separator()
	for n in range(1, Room.FLOOR_CHOICES + 1):
		popup.add_check_item("Floor %d" % n, n)
	popup.id_pressed.connect(_on_floor_item)
	row.add_child(_floors_menu)
	return row

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
