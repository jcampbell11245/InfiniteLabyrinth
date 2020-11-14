extends KinematicBody2D

var speed = 80
onready var player = get_parent().get_node("Player2D")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(delta):
	if(abs(player.global_position.x - global_position.x) > 50 || abs(player.global_position.y - global_position.y) > 50):
		var dir = (player.global_position - global_position).normalized()
		move_and_collide(dir * speed * delta)
