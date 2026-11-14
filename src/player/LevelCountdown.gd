extends Timer

# Time limit for the floor: 500 seconds plus 100 per time upgrade.

func _ready() -> void:
	wait_time = SaveData.time_level * 100 + 500
