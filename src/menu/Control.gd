extends Control

var health_level
var damage_level
var time_level
var looting_level

var upgrade_cost = [10, 50, 100, 300, 500, 750, 1000, 1500, 3000, 5000]

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

func show_menu():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	$Description.text = "Health:  Level " + String(health_level + 1)
	$Description2.text = "Damage:  Level " + String(damage_level + 1)
	$Description3.text = "Time:  Level " + String(time_level + 1)
	$Description4.text = "Looting:  Level " + String(looting_level + 1)
	
	$Coins.text = "Cost " + String(upgrade_cost[health_level])
	$Coins2.text = "Cost " + String(upgrade_cost[damage_level])
	$Coins3.text = "Cost " + String(upgrade_cost[time_level])
	$Coins4.text = "Cost " + String(upgrade_cost[looting_level])

func _on_Continue_pressed():
	show_menu()
	get_parent().get_parent().get_parent().get_parent().reset_world()

func _on_Button_pressed():
	print(coins.coins)
	
	if(health_level != 9 && coins.coins >= upgrade_cost[health_level]):
		coins.coins -= upgrade_cost[health_level]
		health_level += 1
		
		$Description.text = "Health:  Level " + String(health_level + 1)
		$Coins.text = "Cost " + String(upgrade_cost[health_level])
		
		var save = File.new()
		save.open("user://health.save", File.WRITE)
		save.store_line(String(health_level))
		save.close()

func _on_Button2_pressed():
	print(coins.coins)
	
	if(damage_level != 9 && coins.coins >= upgrade_cost[damage_level]):
		coins.coins -= upgrade_cost[damage_level]
		damage_level += 1
		
		$Description2.text = "Damage:  Level " + String(damage_level + 1)
		$Coins2.text = "Cost " + String(upgrade_cost[damage_level])
		
		var save = File.new()
		save.open("user://damage.save", File.WRITE)
		save.store_line(String(damage_level))
		save.close()

func _on_Button3_pressed():
	print(coins.coins)
	
	if(time_level != 9 && coins.coins >= upgrade_cost[time_level]):
		coins.coins -= upgrade_cost[time_level]
		time_level += 1
		
		$Description3.text = "Time:  Level " + String(time_level + 1)
		$Coins3.text = "Cost " + String(upgrade_cost[time_level])
		
		var save = File.new()
		save.open("user://time.save", File.WRITE)
		save.store_line(String(time_level))
		save.close()

func _on_Button4_pressed():
	print(coins.coins)
	
	if(looting_level != 9 && coins.coins >= upgrade_cost[looting_level]):
		coins.coins -= upgrade_cost[looting_level]
		looting_level += 1
		
		$Description4.text = "Looting:  Level " + String(looting_level + 1)
		$Coins4.text = "Cost " + String(upgrade_cost[looting_level])
		
		var save = File.new()
		save.open("user://looting.save", File.WRITE)
		save.store_line(String(looting_level))
		save.close()
