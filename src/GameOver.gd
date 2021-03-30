extends AnimatedSprite


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func game_over():
	$GameOverSFX.play()
	visible = true
	$Timer.start(6.5)
	
	var floor_save = File.new()
	floor_save.open("user://floor.save", File.WRITE)
	floor_save.store_line("1")
	floor_save.close()
	
	


func _on_Timer_timeout():
	visible = false
	get_tree().paused = false
	get_parent().get_node("UpgradeMenu/Control").show_menu()
