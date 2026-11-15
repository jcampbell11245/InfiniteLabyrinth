extends Node2D

# Floor switch: flips the first time a sword swing passes over it. Arrows fly over it.

signal hit

var activated := false

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.get_name() == "Hitbox" && !activated:
		$Hit.play()
		activated = true
		$AnimatedSprite2D.animation = "right"
		hit.emit()
