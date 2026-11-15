extends Timer

# Time limit for the floor: 90 seconds plus 30 per time upgrade, 6 minutes at max level.

const BASE_TIME := 90
const TIME_PER_LEVEL := 30

func _ready() -> void:
	wait_time = BASE_TIME + SaveData.time_level * TIME_PER_LEVEL
