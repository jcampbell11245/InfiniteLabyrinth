extends AnimationPlayer

onready var color = get_parent().get_child(0)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Fade_animation_finished(anim_name):
	if(anim_name == "FadeOut"):
		color.set_frame_color(Color(0, 0, 0, 255))
	else:
		color.set_frame_color(Color(0, 0, 0, 0))
