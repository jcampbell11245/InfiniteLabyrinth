extends "res://tools/tests/test_case.gd"

# Leaving a room creator play-test (F1) while the player is dying: the level timer's fatal
# countdown is still running and must stop cleanly, not wait on a tree it has left.

func test_leaving_a_play_test_while_dying() -> void:
	Overworld.test_design = RoomDesign.new()
	await boot_floor()
	var player: Player = autoload("Game").player
	expect(!player.level_countdown.is_stopped(), "the level timer is running")
	player.lose_time(100000.0) # A killing hit: the timer starts its fatal countdown
	var timer: Node = _find_draining(tree.root)
	for i in 120: # Until it's ticking down to 0:00
		timer = _find_draining(tree.root)
		if timer != null:
			break
		await tree.process_frame
	expect(timer != null, "the fatal countdown is ticking down")
	tree.current_scene.leave_test() # What F1 does
	Overworld.test_design = null
	for i in 30:
		await tree.process_frame
	expect(true, "no error logged while the countdown was cut off")

# The level timer, while its fatal countdown is ticking down; null otherwise.
func _find_draining(node: Node) -> Node:
	if "_fatal" in node && "_draining" in node && node._fatal && node._draining:
		return node
	for child in node.get_children():
		var found := _find_draining(child)
		if found != null:
			return found
	return null
