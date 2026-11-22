extends Timer

# Time limit for the floor: 90 seconds plus 30 per time upgrade, 6 minutes at max level.

# Both numbers live in Tuning (base_time, time_per_level) so the debug menu can change them.
#
# It only runs in the cave: the clock holds still while the player is in the start room
# (shopping, getting ready) or the end room (the floor is as good as done).

const STILL_ROOMS: Array[int] = [Constants.START_ROOM, Constants.END_ROOM]

func _process(_delta: float) -> void:
	paused = Tuning.freeze_timer || (get_parent() as Player).current_room in STILL_ROOMS

func _ready() -> void:
	wait_time = Tuning.time_limit()
	if OS.is_debug_build() && SaveData.debug_time_limit > 0:
		wait_time = SaveData.debug_time_limit
