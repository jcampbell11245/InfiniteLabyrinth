extends KinematicBody2D

onready var player = get_parent().get_node("Player2D")

var last_room_number = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var x
	var y
	if(player.current_room == 60):
		x = 150
		y = 710
	elif(player.current_room == 61):
		x = 1998
		y = 710
	elif(player.current_room == 62):
		x = -130
		y = 710
	else:
		x = (player.current_room % get_parent().columns) * 261 + 411
		y = (player.current_room / get_parent().columns) * 288 + 133
	
	if (position.distance_to(Vector2(x, y)) > 10):
		var velocity = position.direction_to(Vector2(x, y)) * 700
		velocity = move_and_slide(velocity)
	elif(position.distance_to(Vector2(x, y)) != 0):
		position = Vector2(x, y)
