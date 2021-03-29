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
		x = 1848
		y = 719
	else:
		x = (player.current_room % get_parent().columns) * 261 + 411
		y = (player.current_room / get_parent().columns) * 288 + 133
	
	print(player.current_room % get_parent().columns)
	
	if (position.distance_to(Vector2(x, y)) > 5):
		var velocity = position.direction_to(Vector2(x, y)) * 500
		velocity = move_and_slide(velocity)
