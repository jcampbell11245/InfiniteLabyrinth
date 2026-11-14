extends Node2D

var activated = false

func _on_area_2d_area_exited(area):
	if((area.get_name() == "Hitbox" || area.get_name() == "ArrowHitbox")&& !activated):
		$Hit.play()
		activated = true
		$AnimatedSprite2D.animation = "right"
