extends "res://tools/tests/test_case.gd"

# Cave lighting (CaveLighting): a floor is darkened, the player carries a light, and the
# Tuning values reach the lights live.

func lighting() -> CaveLighting:
	for child in tree.current_scene.get_children():
		if child is CaveLighting:
			return child
	return null

func darkness() -> CanvasModulate:
	return lighting().get_node("Darkness")

func player_light() -> PointLight2D:
	return autoload("Game").player.get_node(NodePath(CaveLighting.LIGHT_NAME))

func test_floor_is_dark_and_player_is_lit() -> void:
	await boot_floor()
	expect(lighting() != null, "the floor has cave lighting")
	expect(darkness().color.v < 0.8, "the cave is darkened")
	expect(player_light() != null, "the player carries a light")
	expect(player_light().enabled, "the player's light is on")

func test_tuning_applies_live() -> void:
	await boot_floor()
	var tuning := autoload("Tuning")
	var before := player_light().texture_scale
	tuning.set_value("light_player_radius", tuning.light_player_radius * 2.0)
	expect_near(player_light().texture_scale, before * 2.0, 0.001, "doubling the radius doubles the light")
	tuning.set_value("lighting_enabled", false)
	expect_equal(darkness().color, Color.WHITE, "lighting off shows the cave at full brightness")
	expect(!player_light().enabled, "lighting off turns the player's light off")
