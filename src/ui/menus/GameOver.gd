extends AnimatedSprite2D

func game_over():
	$GameOverSFX.play()
	visible = true
	$Timer.start(6.5)
	SaveData.floor_number = 1
	SaveData.save()

func _on_timer_timeout():
	visible = false
	get_tree().paused = false
	Game.upgrade_menu.show_menu()
