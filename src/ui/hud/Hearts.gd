extends HBoxContainer

# Shows the player's health as a row of hearts, one per point of max health. Each child is
# a heart sprite with "full", "half" and "empty" animations.

var max_hearts := 0

func _ready() -> void:
	Game.health_changed.connect(_show)
	max_hearts = SaveData.health_level + Constants.BASE_HEALTH
	for heart in range(max_hearts):
		get_child(heart).visible = true

func _show(health: float) -> void:
	for n in range(max_hearts):
		var heart: AnimatedSprite2D = get_child(n)
		if health >= n + 1:
			heart.play("full")
		elif health == n + 0.5:
			heart.play("half")
		else:
			heart.play("empty")
