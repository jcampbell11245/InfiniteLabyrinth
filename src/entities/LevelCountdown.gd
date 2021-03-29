extends Timer


# Called when the node enters the scene tree for the first time.
func _ready():
	var timer_save = File.new()
	if not timer_save.file_exists("user://time.save"):
		print("Aborting, no savefile")
		return
	timer_save.open("user://time.save", File.READ)
	wait_time = int(timer_save.get_line()) * 100 + 500
	timer_save.close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
