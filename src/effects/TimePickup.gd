extends "res://src/effects/FloatingPickup.gd"

# An hourglass released from a chest. It floats around briefly, then drifts toward the
# player. When collected it extends the level timer.

# The shop's time upgrade icon doubles as the chest hourglass. It is a still 12x12 icon
# whose hourglass fills columns 2-9, so only that part is shown, scaled down to stand about
# as tall as a coin (7px) so the two pickups read as the same kind of loot.
const HOURGLASS_TEXTURE := preload("res://assets/sprites/hud/upgrade_time.png")
const HOURGLASS_REGION := Rect2(2, 0, 8, 12)
const COIN_HEIGHT := 7.0

var seconds := 0.0 # Time granted on collection, set by the spawner

func _ready() -> void:
	super()
	texture = HOURGLASS_TEXTURE
	region_enabled = true
	region_rect = HOURGLASS_REGION
	scale = Vector2.ONE * (COIN_HEIGHT / HOURGLASS_REGION.size.y)

func _credit() -> void:
	if seconds <= 0.0 || !is_instance_valid(Game.player):
		return
	var countdown: Timer = Game.player.level_countdown
	if countdown != null && !countdown.is_stopped():
		countdown.start(countdown.time_left + seconds)
		Game.time_gained.emit(seconds)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated hourglass sound yet.
	Juice.coin_sound()
