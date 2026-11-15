extends RichTextLabel

# Shows the time left on the player's level countdown, as m:ss.

func _process(_delta: float) -> void:
	if Game.player != null:
		var seconds := int(Game.player.level_countdown.get_time_left())
		@warning_ignore("integer_division")
		set_text("%d:%02d" % [seconds / 60, seconds % 60])
