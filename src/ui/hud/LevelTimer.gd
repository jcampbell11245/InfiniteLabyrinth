extends RichTextLabel

# Shows the seconds left on the player's level countdown.

func _process(_delta):
	if(Game.player != null):
		set_text(str(floor(Game.player.level_countdown.get_time_left())))
