extends HBoxContainer

# Shows the player's health as a row of hearts, one per point of max health. Each child is
# a heart sprite with "full", "half" and "empty" animations.

const SHAKE_TIME := 0.3
const SHAKE_PIXELS := 2.0
const POP_SCALE := 1.6

var max_hearts := 0
var _last_health := -1.0

func _ready() -> void:
	Game.health_changed.connect(_show)
	add_to_group("hearts")
	set_max_hearts(SaveData.health_level + Tuning.base_health)

# Shows one heart per point of max health, up to the hearts the scene holds.
func set_max_hearts(count: int) -> void:
	max_hearts = clampi(count, 1, get_child_count())
	for n in range(get_child_count()):
		get_child(n).visible = n < max_hearts
	if _last_health >= 0:
		_show(_last_health)

func _show(health: float) -> void:
	if _last_health >= 0 && health != _last_health:
		_react(health < _last_health, health)
	_last_health = health
	for n in range(max_hearts):
		var heart: AnimatedSprite2D = get_child(n)
		if health >= n + 1:
			heart.play("full")
		elif health == n + 0.5:
			heart.play("half")
		else:
			heart.play("empty")

# Losing health jolts the row and pops the heart that changed; gaining it just pops.
func _react(lost: bool, health: float) -> void:
	var changed := clampi(int(ceil(maxf(health, _last_health))) - 1, 0, max_hearts - 1)
	var heart: AnimatedSprite2D = get_child(changed)
	var pop := heart.create_tween()
	heart.scale = Vector2.ONE * POP_SCALE
	pop.tween_property(heart, "scale", Vector2.ONE, 0.25) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if !lost:
		return
	for n in range(max_hearts):
		var h: AnimatedSprite2D = get_child(n)
		var jolt := h.create_tween()
		for i in 4:
			var o := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * SHAKE_PIXELS
			jolt.tween_property(h, "offset", o, SHAKE_TIME / 5)
		jolt.tween_property(h, "offset", Vector2.ZERO, SHAKE_TIME / 5)
