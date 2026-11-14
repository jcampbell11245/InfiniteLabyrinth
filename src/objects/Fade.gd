extends AnimationPlayer

# A room's fade to and from black. Pins the cover's colour once each fade ends.

@onready var color: ColorRect = get_parent().get_child(0)

func _on_fade_animation_finished(anim_name: StringName) -> void:
	if anim_name == "FadeOut":
		color.set_color(Color(0, 0, 0, 255))
	else:
		color.set_color(Color(0, 0, 0, 0))
