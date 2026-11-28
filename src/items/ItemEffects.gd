class_name ItemEffects
extends Node

# What the items that last a while are doing right now (see Items). The player has one of
# these (Player.item_effects), so it goes with the player: a new floor or a new run starts
# with nothing on.
#
# Three items are timed boosts, each with its own Timer counting game time (so hit-stop,
# slow motion and the paused shop hold it too):
# - Lucky cat: enemies drop Tuning.lucky_cat_coin_multiplier times the coins and an arrow
#   drop Tuning.lucky_cat_arrow_drop_chance of the time (Enemy.die).
# - Ram stick: the parry window is Tuning.ram_stick_parry_multiplier times as long
#   (parry_window, read wherever a glint opens one).
# - Broken watch: the level timer stops, and hits and falls take no time (LevelCountdown,
#   Player.lose_time).
# Using one again while it's on adds its time to what's left.
#
# The preowned mace isn't timed: it charges the next sword swing (Player calls on_swing as a
# swing begins), and every enemy that swing hits is dazed (Enemy._mace_hit).
#
# The static helpers read the current player's, so game code can ask without a player at
# hand, and get the plain values when there's no floor running.

signal changed # An effect started or ended, or the mace was charged or swung

var mace_charged := false # The next swing is a mace swing
var mace_swing := -2 # Player.swing_started_frame of the mace swing; -2 as that starts at -1
var _timers := {} # Items.Kind -> Timer, made the first time each is used

# Turns on the timed effect of `kind` for `seconds`, or adds them to the time it has left.
func start(kind: Items.Kind, seconds: float) -> void:
	var timer := _timer(kind)
	timer.start(timer.time_left + seconds)
	changed.emit()

func is_active(kind: Items.Kind) -> bool:
	var timer: Timer = _timers.get(kind)
	return timer != null && !timer.is_stopped()

# Seconds the timed effect of `kind` has left, 0 when it's off.
func time_left(kind: Items.Kind) -> float:
	return (_timers[kind] as Timer).time_left if is_active(kind) else 0.0

# Ends the timed effect of `kind` now.
func stop(kind: Items.Kind) -> void:
	if is_active(kind):
		(_timers[kind] as Timer).stop()
		changed.emit()

# The swing begun on `swing_frame` uses up a charged mace.
func on_swing(swing_frame: int) -> void:
	if mace_charged:
		mace_charged = false
		mace_swing = swing_frame
		changed.emit()

func _timer(kind: Items.Kind) -> Timer:
	if !_timers.has(kind):
		var timer := Timer.new()
		timer.one_shot = true
		timer.timeout.connect(changed.emit)
		add_child(timer)
		_timers[kind] = timer
	return _timers[kind]

# --- For game code ---

static func current() -> ItemEffects:
	return Game.player.item_effects if is_instance_valid(Game.player) else null

static func active(kind: Items.Kind) -> bool:
	var effects := current()
	return effects != null && effects.is_active(kind)

# The parry window an enemy's glint opens: Tuning.parry_window (or `base`, for windows of
# their own like a dragon's breath), longer under a ram stick.
static func parry_window(base := -1.0) -> float:
	var window := base if base >= 0 else Tuning.parry_window
	return window * Tuning.ram_stick_parry_multiplier if active(Items.Kind.RAM_STICK) else window

# Times the coins an enemy drops.
static func coin_multiplier() -> float:
	return Tuning.lucky_cat_coin_multiplier if active(Items.Kind.LUCKY_CAT) else 1.0

static func arrow_drop_chance() -> float:
	if active(Items.Kind.LUCKY_CAT):
		return maxf(Tuning.arrow_drop_chance, Tuning.lucky_cat_arrow_drop_chance)
	return Tuning.arrow_drop_chance

# The level timer is held still and takes no time off for hits.
static func clock_stopped() -> bool:
	return active(Items.Kind.BROKEN_WATCH)
