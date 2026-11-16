extends Timer

# Time limit for the floor: 90 seconds plus 30 per time upgrade, 6 minutes at max level.

# Both numbers live in Tuning (base_time, time_per_level) so the debug menu can change them.

func _process(_delta: float) -> void:
	paused = Tuning.freeze_timer

func _ready() -> void:
	wait_time = Tuning.time_limit()
	if OS.is_debug_build() && SaveData.debug_time_limit > 0:
		wait_time = SaveData.debug_time_limit
