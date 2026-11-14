extends AnimationPlayer

@onready var color = get_parent().get_child(0)

func _on_fade_animation_finished(anim_name):
	if(anim_name == "FadeOut"):
		color.set_color(Color(0, 0, 0, 255))
	else:
		color.set_color(Color(0, 0, 0, 0))
