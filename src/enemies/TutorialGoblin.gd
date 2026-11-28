class_name TutorialGoblin
extends MeleeEnemy

# The goblin in the tutorial's parry lesson (Tutorial runs the lesson round it). It's an
# ordinary goblin made so the lesson can only go one way, and nothing the player does can
# hurt them or skip a step:
#
# - GUARDING (from the start): it stands still, turns to face the player and blocks every
#   hit, from any side, sword or arrow, taking nothing and never swinging back. The first
#   block sends `guarded`, so the merchant can explain parrying.
# - ATTACKING (start_attacking): it fights like a goblin, but only single swings, and hits
#   still do it no harm. Once its parry star shows it stays frozen in the windup with the
#   parry window held open until the player parries it, so its swing never lands. A star
#   stays on its blade all that time (the usual one pops in and away). The first star
#   sends `twinkled` with where the star is.
# - DAZED (parried): dazed for good, the daze never running down, and now it takes damage,
#   so the player can finish it off.

signal guarded # Blocked a hit in GUARDING
signal twinkled(at: Vector2) # Its parry star showed (global position), the first time
signal dazed # Parried

enum Stage { GUARDING, ATTACKING, DAZED }

const LESSON_STUN := 1.0 # Seconds the daze starts at; it never runs down from there
# Seconds it waits before its first swing, so the player (who has just swung at it) has
# their sword back by the time its star shows.
const FIRST_SWING_DELAY := 0.8

var stage := Stage.GUARDING
var _has_twinkled := false
var _held_star: HeldStar # On its blade while the parry window is held open

# The parry star at full size, still, for as long as the window is held.
class HeldStar extends Node2D:
	const TwinkleArt := preload("res://src/effects/Twinkle.gd")

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 5

	func _draw() -> void:
		var size := Vector2.ONE * TwinkleArt.SIZE
		draw_texture_rect_region(StatusBars.ICON_SHEET, Rect2(-size / 2, size),
			StatusBars.cell_region(TwinkleArt.SHEET_CELL))

func _ready() -> void:
	super()
	double_attack = false # One parry is the lesson; a follow-up would muddle it

# The merchant has explained parrying: come and fight.
func start_attacking() -> void:
	if stage != Stage.GUARDING:
		return
	stage = Stage.ATTACKING
	noticed = true
	attack_cooldown.start(FIRST_SWING_DELAY)

func _physics_process(delta: float) -> void:
	if stage != Stage.GUARDING:
		super(delta)
		return
	# Rooted, watching the player. The facing is kept while a block plays.
	_moving = false
	if !player.in_transition && is_player_in_room() && !_is_reacting():
		if _is_player_mostly_horizontal():
			_face_player_horizontally()
		else:
			_face_player_vertically()
		_point_pivots()
	_apply_knockback(delta)

func _on_player_sword(from_direction: String) -> void:
	if stage == Stage.DAZED:
		super(from_direction)
	elif stage == Stage.GUARDING || _can_guard(from_direction):
		_lesson_block.call_deferred(from_direction)
	else:
		super(from_direction) # Mid-swing: the parry timing decides it

# Anything that isn't a parry is shrugged off until it's dazed: sword hits that get past
# its guard, arrows, blasts.
func take_damage(from_direction: String, amount: float) -> void:
	if stage == Stage.DAZED:
		super(from_direction, amount)
	else:
		_lesson_block(from_direction)

func _chip(hit_dir: Vector2) -> void:
	if stage == Stage.DAZED:
		super(hit_dir)

# Blocks like a goblin's guard, but without chip damage. Attacking, it swings back as usual.
func _lesson_block(from_direction: String) -> void:
	if stage == Stage.DAZED:
		return
	if stage == Stage.ATTACKING && _animation_is("slash"):
		return # Mid-swing, the parry timing has already dealt with it
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	var hit_dir := Direction.to_vector(from_direction)
	Juice.burst(room, global_position - hit_dir * 6, GUARD_SPARK, 6, 70.0, -hit_dir, 1.5, 0.25)
	Juice.hitstop(HITSTOP_BLOCK)
	Juice.shake(Juice.SHAKE_LIGHT)
	Juice.clank(true)
	Juice.flash(animator, 0.1, GUARD_FLASH)
	_play_reaction("block")
	if stage == Stage.GUARDING:
		guarded.emit()
	else:
		_block_counter_pending = true

# Its star shows: hold the parry window open until the player parries.
func _twinkle() -> void:
	super()
	if stage != Stage.ATTACKING:
		return
	_parry_timer.paused = true
	_drop_held_star()
	_held_star = HeldStar.new()
	_held_star.position = _twinkle_position()
	add_child(_held_star)
	if !_has_twinkled:
		_has_twinkled = true
		twinkled.emit(to_global(_twinkle_position()))

func _process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_held_star):
		_held_star.position = _twinkle_position() # It turns to face a player who steps round

func _drop_held_star() -> void:
	if is_instance_valid(_held_star):
		_held_star.queue_free()
	_held_star = null

func _parried_follow_up() -> bool:
	return false

func stagger(from_direction: String, stun_time := -1.0) -> void:
	_parry_timer.paused = false # Stopped by the stagger; the next window runs normally
	_drop_held_star()
	super(from_direction, LESSON_STUN if stun_time <= 0 else stun_time)
	_stun_timer.paused = true # Dazed until it's dead
	if stage != Stage.DAZED:
		stage = Stage.DAZED
		dazed.emit()

# Never leaves the room to reset: the room's doors stay locked until it's beaten.
func reset_to_spawn() -> void:
	if stage == Stage.GUARDING:
		super()
