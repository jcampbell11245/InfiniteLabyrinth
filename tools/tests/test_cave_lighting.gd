extends "res://tools/tests/test_case.gd"

# Cave lighting (CaveLighting): the cave is darkened except in the start and end rooms,
# the player carries a light, and the Tuning values reach the lights live.

func lighting() -> CaveLighting:
	for child in tree.current_scene.get_children():
		if child is CaveLighting:
			return child
	return null

# The colour the unlit cave is multiplied by (white: not darkened).
func ambient() -> Color:
	return lighting().ambient_color()

func player_light() -> PointLight2D:
	return autoload("Game").player.get_node(NodePath(CaveLighting.LIGHT_NAME))

# A generated room on this floor, which should be dark.
func cave_room_id() -> int:
	for id: int in (tree.current_scene as Overworld).rooms_by_id:
		if !(id in CaveLighting.BRIGHT_ROOMS) && id != Constants.BOSS_ROOM:
			return id
	return -1

# Tells the lighting the player walked into `id` and waits for the fade to finish.
func enter_room(id: int) -> void:
	autoload("Game").room_entered.emit(id)
	await wait_real(CaveLighting.BRIGHT_FADE_TIME + 0.2)

func test_start_room_is_bright_and_the_cave_is_dark() -> void:
	await boot_floor()
	expect(lighting() != null, "the floor has cave lighting")
	expect_equal(autoload("Game").player.current_room, Constants.START_ROOM, "the floor starts in the start room")
	expect_equal(ambient(), Color.WHITE, "the start room isn't darkened")
	await enter_room(cave_room_id())
	expect(ambient().v < 1.0, "the rest of the cave is darkened")
	expect(player_light().enabled && player_light().energy > 0.0, "the player's light is on in the cave")
	await enter_room(Constants.END_ROOM)
	expect_equal(ambient(), Color.WHITE, "the end room isn't darkened")

func test_tuning_applies_live() -> void:
	await boot_floor()
	await enter_room(cave_room_id())
	var tuning := autoload("Tuning")
	var before := player_light().texture_scale
	tuning.set_value("light_player_radius", tuning.light_player_radius * 2.0)
	expect_near(player_light().texture_scale, before * 2.0, 0.001, "doubling the radius doubles the light")
	tuning.set_value("lighting_enabled", false)
	expect_equal(ambient(), Color.WHITE, "lighting off shows the cave at full brightness")
	expect(!player_light().enabled, "lighting off turns the player's light off")

func test_dropped_loot_does_not_glow() -> void:
	await boot_floor()
	var coin: Node2D = (load("res://src/effects/CoinPickup.gd") as GDScript).new()
	var arrow: Node2D = (load("res://src/effects/ArrowPickup.gd") as GDScript).new()
	var room: Node = autoload("Game").player.get_parent()
	room.add_child(coin)
	room.add_child(arrow)
	await tree.process_frame
	expect(!coin.has_node(NodePath(CaveLighting.LIGHT_NAME)), "a dropped coin has no light")
	expect(!arrow.has_node(NodePath(CaveLighting.LIGHT_NAME)), "a dropped arrow has no light")
	coin.queue_free()
	arrow.queue_free()

func test_inner_walls_block_light() -> void:
	await boot_floor()
	await tree.process_frame
	var checked := false
	for room: Room in (tree.current_scene as Overworld).rooms_by_id.values():
		var walls := room.get_node_or_null("InnerWalls") as TileMap
		if walls == null || walls.get_used_cells(0).is_empty():
			continue
		var holder := room.get_node_or_null(NodePath(CaveLighting.OCCLUDER_NAME))
		var occluders := [] if holder == null else holder.find_children("*", "LightOccluder2D", false, false)
		expect(!occluders.is_empty(), "%s's inner walls cast shadows" % room.name)
		checked = true
	expect(checked, "the floor has a room with inner walls to check")
	await enter_room(cave_room_id())
	expect(player_light().shadow_enabled, "the player's light is blocked by walls")
	autoload("Tuning").set_value("light_shadows", false)
	expect(!player_light().shadow_enabled, "turning shadows off lets light through walls")

func test_room_brightness_scales_the_cave_light() -> void:
	await boot_floor()
	var id := cave_room_id()
	await enter_room(id)
	var usual := ambient()
	var room: Room = autoload("Game").room_by_id(id)
	room.brightness = 0.5
	await enter_room(Constants.START_ROOM)
	await enter_room(id)
	expect(ambient().v < usual.v, "a darker room is darker than the usual cave")
	room.brightness = 1.5
	await enter_room(Constants.START_ROOM)
	await enter_room(id)
	expect_equal(ambient(), Color.WHITE, "a room bright enough is fully lit")

func test_room_design_keeps_brightness() -> void:
	var design := RoomDesign.new()
	var before := design.snapshot()
	design.brightness = 0.6
	design.record(before)
	expect(design.to_text().contains("brightness: 0.60"), "the export says the room's brightness")
	design.undo()
	expect_equal(design.brightness, 1.0, "undo puts the brightness back")

func test_player_light_is_at_their_feet() -> void:
	await boot_floor()
	await tree.process_frame
	var feet: Node2D = autoload("Game").player.get_node("CollisionShape2D")
	expect_equal(player_light().position, feet.position, "the player's light sits on their collision box, which walls keep out")
