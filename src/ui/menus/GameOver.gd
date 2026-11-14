extends AnimatedSprite2D

# Shown when the player dies: plays the jingle, resets the floor count, then opens the
# upgrade menu. Runs while the tree is paused.

const SHOW_TIME = 6.5

func _ready():
	Game.player_died.connect(_on_player_died)

func _on_player_died():
	$GameOverSFX.play()
	visible = true
	SaveData.floor_number = 1
	SaveData.save()
	
	await get_tree().create_timer(SHOW_TIME).timeout
	visible = false
	get_tree().paused = false
	Game.upgrade_menu.show_menu()
