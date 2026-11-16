extends CharacterBody2D

# Glides the camera to the centre of the player's room, snapping once within SNAP_DISTANCE,
# and eases the zoom to the room's camera_zoom on the way.

const SPEED := 700
const SNAP_DISTANCE := 10
const ZOOM_SPEED := 2.0 # Zoom change per second
# Where the camera aims, relative to a room's centre: right of and above it, measured from
# where the original game aimed in the first grid column.
const AIM_OFFSET := Vector2(14, -11)

func _physics_process(delta: float) -> void:
	var room := Game.room_by_id(Game.player.current_room)
	var target := room.position + room.centre + AIM_OFFSET
	var camera: Camera2D = Game.camera
	camera.zoom = camera.zoom.move_toward(Vector2.ONE * room.camera_zoom, ZOOM_SPEED * delta)
	if position.distance_to(target) > SNAP_DISTANCE:
		velocity = position.direction_to(target) * SPEED
		move_and_slide()
	elif position.distance_to(target) != 0:
		position = target
