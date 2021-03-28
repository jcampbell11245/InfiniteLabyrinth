extends Node2D

var activated = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_Area2D_area_exited(area):
	if((area.get_name() == "Hitbox" || area.get_name() == "ArrowHitbox")&& !activated):
		$Hit.play()
		activated = true
		$AnimatedSprite.animation = "right"
