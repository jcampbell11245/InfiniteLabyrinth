extends Camera2D

var camera_x = [324, 585]
var camera_y = [323]
#onready var player = get_parent().get_child(get_parent().room_count)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#var x = (player.current_room % get_parent().columns) * 261 + 324
	#var y = (player.current_room / get_parent().columns) * 261 + 322
	#
	#var velocity = position.direction_to(Vector2(x, y)) * 200
	#velocity = get_parent().move_and_slide(velocity)
