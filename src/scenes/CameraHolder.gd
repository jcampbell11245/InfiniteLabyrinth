extends KinematicBody2D

onready var player = get_parent().get_child(get_parent().room_count)

var last_room_number = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	#if(player.current_room != last_room_number):
	last_room_number = player.current_room
	
	var x = (player.current_room % get_parent().columns) * 261 - 261
	var y = (player.current_room / get_parent().columns) * 261
	
	if (position.distance_to(Vector2(x, y)) > 5):
		var velocity = position.direction_to(Vector2(x, y)) * 500
		velocity = move_and_slide(velocity)
