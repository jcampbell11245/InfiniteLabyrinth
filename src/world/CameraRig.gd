extends CharacterBody2D

func _physics_process(delta):
	var player = Game.player
	var x
	var y
	if(player.current_room == Constants.START_ROOM):
		x = 150
		y = 710
	elif(player.current_room == Constants.END_ROOM):
		x = 1998
		y = 710
	elif(player.current_room == Constants.BOSS_ROOM):
		x = -130
		y = 710
	else:
		x = (player.current_room % Constants.COLUMNS) * Constants.LEGACY_ROOM_WIDTH + 411
		y = (player.current_room / Constants.COLUMNS) * Constants.ROOM_SIZE.y + 133
	
	if (position.distance_to(Vector2(x, y)) > 10):
		velocity = position.direction_to(Vector2(x, y)) * 700
		move_and_slide()
	elif(position.distance_to(Vector2(x, y)) != 0):
		position = Vector2(x, y)
