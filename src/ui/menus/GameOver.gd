extends AnimatedSprite2D

# Shown when the player dies: plays the jingle, resets the floor count, then opens the
# upgrade menu. Runs while the tree is paused.

const SHOW_TIME := 6.5
# Shown on its own screen layer so walls and neighbouring rooms' covers can't draw over
# it. Whole-number scale so each art pixel lands on whole screen pixels; 12 would make
# the 160x90 frame fill the 1920x1080 screen.
const SHOW_SCALE := 9.0
const LAYER := 10 # Above the HUD's layer

func _ready() -> void:
	Game.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	_move_to_screen_layer()
	# Stopped, not left paused, or it plays for a moment when the tree unpauses below.
	Music.stop_all()
	$GameOverSFX.play()
	visible = true
	scale = Vector2.ONE * SHOW_SCALE
	SaveData.floor_number = Game.START_FLOOR
	SaveData.save()
	
	await get_tree().create_timer(SHOW_TIME).timeout
	visible = false
	get_tree().paused = false
	Game.upgrade_menu.show_menu()

# Reparents onto a CanvasLayer centred on the screen, the first time it's shown.
func _move_to_screen_layer() -> void:
	if get_parent() is CanvasLayer:
		return
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(layer)
	reparent(layer, false)
	position = get_viewport_rect().size / 2
