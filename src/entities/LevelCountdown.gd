extends Timer

# Called when the node enters the scene tree for the first time.
func _ready():
	if not FileAccess.file_exists("user://time.save"):
		print("Aborting, no savefile")
		return
	var timer_save = FileAccess.open("user://time.save", FileAccess.READ)
	wait_time = int(timer_save.get_line()) * 100 + 500
	timer_save.close()
