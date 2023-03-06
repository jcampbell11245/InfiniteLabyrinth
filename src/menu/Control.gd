extends Control

var health_level
var damage_level
var time_level
var looting_level

var selected = 0

var upgrade_cost = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, "MAX"]

onready var coins = get_parent().get_parent().get_node("HudLayer/Hud/Coins")

# Called when the node enters the scene tree for the first time.
func _ready():
	var hearts_save = File.new()
	if not hearts_save.file_exists("user://health.save"):
		print("Aborting, no savefile")
		return
	hearts_save.open("user://health.save", File.READ)
	health_level = int(hearts_save.get_line())
	hearts_save.close()
	
	var crit_file = File.new()
	if not crit_file.file_exists("user://damage.save"):
		print("Aborting, no savefile")
		return
	crit_file.open("user://damage.save", File.READ)
	damage_level = int(crit_file.get_line())
	crit_file.close()
	
	var time_save = File.new()
	if not time_save.file_exists("user://time.save"):
		print("Aborting, no savefile")
		return
	time_save.open("user://time.save", File.READ)
	time_level = int(time_save.get_line())
	time_save.close()
	
	var looting_file = File.new()
	if not looting_file.file_exists("user://looting.save"):
		print("Aborting, no savefile")
		return
	looting_file.open("user://looting.save", File.READ)
	looting_level = int(looting_file.get_line())
	looting_file.close()
	
	update_selected()
	
	$Meter1.animation = String(health_level + 1)
	$Meter2.animation = String(damage_level + 1)
	$Meter3.animation = String(time_level + 1)
	$Meter4.animation = String(looting_level + 1)

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
	
	#$Description.text = "Health:  Level " + String(health_level + 1)
	#$Description2.text = "Damage:  Level " + String(damage_level + 1)
	#$Description3.text = "Time:  Level " + String(time_level + 1)
	#$Description4.text = "Looting:  Level " + String(looting_level + 1)
	
	$Coins.text = String(upgrade_cost[health_level])
	$Coins2.text = String(upgrade_cost[damage_level])
	$Coins3.text = String(upgrade_cost[time_level])
	$Coins4.text = String(upgrade_cost[looting_level])
	
	selected = 0
	update_selected()

func buy_health():
	print(coins.coins)
	
	if(health_level != 9 && coins.coins >= upgrade_cost[health_level]):
		coins.coins -= upgrade_cost[health_level]
		coins.update_text()
		health_level += 1
		$Meter1.animation = String(health_level + 1)

		$Coins.text = String(upgrade_cost[health_level])

		var save = File.new()
		save.open("user://health.save", File.WRITE)
		save.store_line(String(health_level))
		save.close()

func buy_damage():
	print(coins.coins)
	
	if(damage_level != 9 && coins.coins >= upgrade_cost[damage_level]):
		coins.coins -= upgrade_cost[damage_level]
		coins.update_text()
		damage_level += 1
		$Meter2.animation = String(damage_level + 1)
		
		$Coins2.text = String(upgrade_cost[damage_level])
		
		var save = File.new()
		save.open("user://damage.save", File.WRITE)
		save.store_line(String(damage_level))
		save.close()

func buy_time():
	print(coins.coins)
	
	if(time_level != 9 && coins.coins >= upgrade_cost[time_level]):
		coins.coins -= upgrade_cost[time_level]
		coins.update_text()
		time_level += 1
		$Meter3.animation = String(time_level + 1)
		
		$Coins3.text = String(upgrade_cost[time_level])
	
	var save = File.new()
	save.open("user://time.save", File.WRITE)
	save.store_line(String(time_level))
	save.close()

func buy_looting():
	print(coins.coins)
	
	if(looting_level != 9 && coins.coins >= upgrade_cost[looting_level]):
		coins.coins -= upgrade_cost[looting_level]
		coins.update_text()
		looting_level += 1
		$Meter4.animation = String(looting_level + 1)
		
		$Coins4.text = String(upgrade_cost[looting_level])
	
	var save = File.new()
	save.open("user://looting.save", File.WRITE)
	save.store_line(String(looting_level))
	save.close()

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
	var floor_save = File.new()
	floor_save.open("user://floor.save", File.WRITE)
	floor_save.store_line(String(get_parent().get_parent().get_parent().get_parent().floor_number))
	floor_save.close()
	get_parent().get_parent().get_parent().get_parent().reset_world()

func _on_Continue_pressed():
	continue_button()

func _on_Plus1Area_mouse_entered():
	selected = 0
	update_selected()

func _on_Plus2Area_mouse_entered():
	selected = 1
	update_selected()

func _on_Button_pressed():
	buy_health()

func _on_Button2_pressed():
	buy_damage()

func _on_Button3_pressed():
	buy_time()

func _on_Button4_pressed():
	buy_looting()

func _on_Control_mouse_entered():
	selected = 0
	update_selected()

func _on_Plus2Control_mouse_entered():
	selected = 1
	update_selected()

func _on_Plus3Control_mouse_entered():
	selected = 2
	update_selected()

func _on_Plus4Control_mouse_entered():
	selected = 3
	update_selected()

func _on_Continue_mouse_entered():
	selected = 4
	update_selected()
