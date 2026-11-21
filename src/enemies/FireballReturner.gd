class_name FireballReturner
extends RefCounted

# Bats back fireballs the player has hit at an enemy, just before they land: wizards and
# dragons both use one. Each return gets one try. It fumbles Tuning.wizard_deflect_miss_chance
# of them, and lets the fireball hit it once the rally is too fast for the player's sword
# cooldown to answer (see _player_could_return), so a rally always ends. Batted back, a
# fireball homes on the player again (Projectile.deflect), stronger and faster each time.

const PLAYER_SWORD_REACH := 20.0 # Pixels from the player out to where their sword meets a fireball

var _enemy: Enemy
var _reach: float # Pixels ahead of the enemy where it bats a fireball back
var _width: float # Pixels either side of a fireball's path that still count
var _flash: Color # The enemy flashes this colour as it bats one back
var _judged: Dictionary = {} # Fireball -> its deflections when last swung at

func _init(enemy: Enemy, reach: float, width: float, flash: Color) -> void:
	_enemy = enemy
	_reach = reach
	_width = width
	_flash = flash

# Forgets every fireball it has swung at (the room starting over).
func reset() -> void:
	_judged.clear()

# Swings at any player-deflected fireball about to hit, once per return. True if it batted
# one back (the enemy now faces the way it sent it).
func try_return() -> bool:
	var batted := false
	for node in _enemy.room.get_children():
		var shot := node as Projectile
		if shot == null || !shot.deflectable || shot.hostile_to_player || shot._hit:
			continue
		if _judged.get(shot, -1) == shot.deflections || !_is_incoming(shot):
			continue
		_judged[shot] = shot.deflections
		if randf() < Tuning.wizard_deflect_miss_chance:
			continue # Fumbled; it flies on and hits
		if !_player_could_return(shot):
			continue # No point; it takes the hit rather than send back an unanswerable one
		_enemy.direction = _back_the_way_it_came(shot)
		shot.deflect(_enemy.direction)
		Juice.flash(_enemy.animator, 0.1, _flash)
		Juice.deflect_sound()
		batted = true
	# Forget fireballs that have gone.
	for shot in _judged.keys():
		if !is_instance_valid(shot):
			_judged.erase(shot)
	return batted

# Batted back now, `shot` would reach the player's sword no sooner than they can swing
# again plus Tuning.wizard_volley_reaction_time.
func _player_could_return(shot: Projectile) -> bool:
	var return_speed := minf(shot.speed * Tuning.deflect_speed_multiplier, Tuning.deflect_max_speed)
	if return_speed <= 0:
		return true
	var player := _enemy.player
	var distance := maxf(_enemy.global_position.distance_to(player.global_position) - PLAYER_SWORD_REACH, 0.0)
	var travel := distance / return_speed
	return travel >= player.seconds_until_can_swing() + Tuning.wizard_volley_reaction_time

# Heading straight at the enemy and about to arrive. Measured along its real path, since a
# homing fireball comes in on a diagonal.
func _is_incoming(shot: Projectile) -> bool:
	var heading := shot.velocity.normalized() if shot.velocity != Vector2.ZERO \
		else Direction.to_vector(shot.direction)
	var to_enemy := _enemy.global_position - shot.global_position
	var ahead := to_enemy.dot(heading)
	return ahead > 0 && ahead < _reach && absf(to_enemy.cross(heading)) < _width

# The direction opposite the one `shot` flies in.
static func _back_the_way_it_came(shot: Projectile) -> String:
	var back := -Direction.to_vector(shot.direction)
	for dir: String in [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]:
		if Direction.to_vector(dir).is_equal_approx(back):
			return dir
	return shot.direction
