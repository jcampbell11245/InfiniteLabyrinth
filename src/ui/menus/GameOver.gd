extends AnimatedSprite2D

func game_over():
	$GameOverSFX.play()
	visible = true
	$Timer.start(6.5)
	
	var floor_save = FileAccess.open("user://floor.save", FileAccess.WRITE)
	floor_save.store_line("1")
	floor_save.close()
	
	

func _on_timer_timeout():
	visible = false
	get_tree().paused = false
	get_parent().get_node("UpgradeMenu/Control").show_menu()
