extends Control

var selected = 0

var upgrade_cost = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, "MAX"]

func _ready():
	update_selected()
	
	$Meter1.animation = str(SaveData.health_level + 1)
	$Meter2.animation = str(SaveData.damage_level + 1)
	$Meter3.animation = str(SaveData.time_level + 1)
	$Meter4.animation = str(SaveData.looting_level + 1)

func _process(delta):
	if(visible):
		if(Input.is_action_just_released("up") && selected != 0):
			selected -= 1
			update_selected()
		if(Input.is_action_just_released("down") && selected != 4):
			selected += 1
			update_selected()
		if(Input.is_action_just_released("select")):
			if(selected == 0):
				buy_health()
			if(selected == 1):
				buy_damage()
			if(selected == 2):
				buy_time()
			if(selected == 3):
				buy_looting()
			if(selected == 4):
				continue_button()

func show_menu():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	$Coins.text = str(upgrade_cost[SaveData.health_level])
	$Coins2.text = str(upgrade_cost[SaveData.damage_level])
	$Coins3.text = str(upgrade_cost[SaveData.time_level])
	$Coins4.text = str(upgrade_cost[SaveData.looting_level])
	
	selected = 0
	update_selected()

func buy_health():
	var coins = Game.coins
	if(SaveData.health_level != 9 && coins.coins >= upgrade_cost[SaveData.health_level]):
		coins.coins -= upgrade_cost[SaveData.health_level]
		coins.update_text()
		SaveData.health_level += 1
		$Meter1.animation = str(SaveData.health_level + 1)

		$Coins.text = str(upgrade_cost[SaveData.health_level])

		SaveData.save()

func buy_damage():
	var coins = Game.coins
	if(SaveData.damage_level != 9 && coins.coins >= upgrade_cost[SaveData.damage_level]):
		coins.coins -= upgrade_cost[SaveData.damage_level]
		coins.update_text()
		SaveData.damage_level += 1
		$Meter2.animation = str(SaveData.damage_level + 1)
		
		$Coins2.text = str(upgrade_cost[SaveData.damage_level])
		
		SaveData.save()

func buy_time():
	var coins = Game.coins
	if(SaveData.time_level != 9 && coins.coins >= upgrade_cost[SaveData.time_level]):
		coins.coins -= upgrade_cost[SaveData.time_level]
		coins.update_text()
		SaveData.time_level += 1
		$Meter3.animation = str(SaveData.time_level + 1)
		
		$Coins3.text = str(upgrade_cost[SaveData.time_level])
	
	SaveData.save()

func buy_looting():
	var coins = Game.coins
	if(SaveData.looting_level != 9 && coins.coins >= upgrade_cost[SaveData.looting_level]):
		coins.coins -= upgrade_cost[SaveData.looting_level]
		coins.update_text()
		SaveData.looting_level += 1
		$Meter4.animation = str(SaveData.looting_level + 1)
		
		$Coins4.text = str(upgrade_cost[SaveData.looting_level])
	
	SaveData.save()

func update_selected():
	if(selected == 0):
		$Plus1Control/Plus1.animation = "selected"
	else:
		$Plus1Control/Plus1.animation = "default"
	
	if(selected == 1):
		$Plus2Control/Plus2.animation = "selected"
	else:
		$Plus2Control/Plus2.animation = "default"
	
	if(selected == 2):
		$Plus3Control/Plus3.animation = "selected"
	else:
		$Plus3Control/Plus3.animation = "default"
	
	if(selected == 3):
		$Plus4Control/Plus4.animation = "selected"
	else:
		$Plus4Control/Plus4.animation = "default"
	
	if(selected == 4):
		$ContinueOutline.show()
	else:
		$ContinueOutline.hide()

func continue_button():
	show_menu()
	SaveData.floor_number = Game.overworld.floor_number
	SaveData.save()
	Game.overworld.reset_world()

func _on_continue_pressed():
	continue_button()

func _on_button_pressed():
	buy_health()

func _on_button_2_pressed():
	buy_damage()

func _on_button_3_pressed():
	buy_time()

func _on_button_4_pressed():
	buy_looting()

func _on_plus_1_control_mouse_entered():
	selected = 0
	update_selected()

func _on_plus_2_control_mouse_entered():
	selected = 1
	update_selected()

func _on_plus_3_control_mouse_entered():
	selected = 2
	update_selected()

func _on_plus_4_control_mouse_entered():
	selected = 3
	update_selected()

func _on_continue_mouse_entered():
	selected = 4
	update_selected()
