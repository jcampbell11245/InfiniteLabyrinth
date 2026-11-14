extends Timer

func _ready():
	wait_time = SaveData.time_level * 100 + 500
