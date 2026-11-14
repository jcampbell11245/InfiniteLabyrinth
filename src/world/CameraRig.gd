extends CharacterBody2D

# Glides the camera to the centre of the player's room, snapping once within SNAP_DISTANCE.

const SPEED = 700
const SNAP_DISTANCE = 10
const GRID_ROOM_CENTRE = Vector2(411, 133) # Room 0's centre; others step by legacy_room_offset
const SPECIAL_ROOM_CENTRES = {
	Constants.START_ROOM: Vector2(150, 710),
	Constants.END_ROOM: Vector2(1998, 710),
	Constants.BOSS_ROOM: Vector2(-130, 710),
}

func _physics_process(_delta):
	var target = _room_centre(Game.player.current_room)
	if (position.distance_to(target) > SNAP_DISTANCE):
		velocity = position.direction_to(target) * SPEED
		move_and_slide()
	elif(position.distance_to(target) != 0):
		position = target

# BUG(see BUGS.md): these don't line up with Room.position (grid rooms drift 3px per
# column, and the special rooms are a few pixels off each other).
func _room_centre(room_id):
	if(SPECIAL_ROOM_CENTRES.has(room_id)):
		return SPECIAL_ROOM_CENTRES[room_id]
	return Constants.legacy_room_offset(room_id) + GRID_ROOM_CENTRE
