extends CharacterBody2D

# Glides the camera to the centre of the player's room, snapping once within SNAP_DISTANCE.

const SPEED := 700
const SNAP_DISTANCE := 10
# Where the camera aims, relative to a room's position. Sits right of and above the room's
# centre, measured from where the original game aimed in the first grid column.
const AIM := Vector2(338, 301)

func _physics_process(_delta: float) -> void:
	var target := Game.room_by_id(Game.player.current_room).position + AIM
	if position.distance_to(target) > SNAP_DISTANCE:
		velocity = position.direction_to(target) * SPEED
		move_and_slide()
	elif position.distance_to(target) != 0:
		position = target
