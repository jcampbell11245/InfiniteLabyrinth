extends Node

# Every gameplay number the debug menu (F2) can change while the game runs. Game code
# reads these instead of its own constants, so a change applies at once (or, for values
# only read when something spawns, to the next one spawned). The defaults below are the
# shipped values; DebugMenu resets fields to them and exports the changed ones.

signal changed(key: String)

# --- Player ---
var player_speed := 125.0 # Pixels/sec walking
var roll_speed_multiplier := 2.0 # Times player_speed while rolling
var roll_duration := 0.2 # Seconds; with the multiplier this sets the roll distance (just through an enemy)
var roll_cooldown := 0.5 # Seconds after a roll ends before the next
var hurt_invincibility := 0.7 # Seconds after being hit before the next hit counts
var player_knockback := 150.0 # Pixels/sec the player is pushed when hit
var shoot_cooldown := 0.5 # Seconds between arrows
var sword_cooldown := 0.3 # Seconds after a swing ends before the next can start
var shoot_recoil := 45.0 # Knockback speed pushed back from each shot
var blocked_daze_time := 0.6 # Seconds the player can't act after a swing is blocked
var pitfall_damage := 0.5 # Damage from falling down a pitfall, like a hit
# There's no health: damage comes off the level timer, this many seconds per point of
# damage (after multipliers), and the run ends when it runs out.
var seconds_per_damage := 10.0

# --- Combat ---
var sword_damage := 1.0
var arrow_damage := 1.0
var arrow_charge_time := 0.6 # Seconds the shoot button must be held for a charged arrow
var arrow_charge_multiplier := 2.0 # Damage of a charged arrow, times arrow_damage
var parry_window := 0.25 # Seconds from the twinkle to the strike; a sword hit in it parries
var parried_stun_time := 1.0 # Seconds a parried enemy stands helpless
var instant_finisher := true # While a parried enemy is stunned, swings skip the sword cooldown
var parried_knockback := 0.5 # Times the enemy's knockback_speed for being parried
var hit_knockback := 0.0 # Times the enemy's knockback_speed for an ordinary hit; 0 so a rush can't stunlock
var stagger_damage_multiplier := 2.0 # Next hit taken while vulnerable
var stagger_vulnerable_time := 3.0 # Seconds the vulnerability lasts
var crit_roll_max := 30 # A hit crits when randi_range(0, crit_roll_max) < damage upgrade level
var deflect_damage_multiplier := 1.5
var deflect_speed_multiplier := 1.15
var deflect_max_speed := 450.0 # Pixels/sec
var knight_block_stun := 1.0 # Seconds a knight stands after blocking an arrow
var chip_damage := 0.1 # Health a blocked hit still takes off the enemy that blocked it
# Spin attack: hold the sword button after a swing, let go once charged (see Player).
var spin_charge_time := 0.5 # Seconds of holding before a release spins
var spin_duration := 0.3 # Seconds the spin takes, all the way round
var spin_radius := 30.0 # Pixels from the player's centre that the spin reaches
var spin_damage := 1.0
var spin_staggers := true # A spin hit stuns the enemy like a parry (so a crowd can't all counter)
var spin_charge_move := 0.5 # Times walk speed while holding a charge

# --- Enemies (multipliers on each enemy's own scene values) ---
var enemy_health_multiplier := 1.0
var enemy_damage_multiplier := 1.0
var enemy_speed_multiplier := 1.0
var enemy_knockback_multiplier := 1.0
var enemy_attack_cooldown_multiplier := 1.0
var enemy_windup_multiplier := 1.0 # Random windup hold before the twinkle
var unparryable_chance := 0.3 # Knight swings that glint red and can't be parried
var unparryable_window := 0.5 # Seconds from the red twinkle to the strike, to roll behind in
var heavy_end_lag := 1.0 # Seconds a knight stays frozen at the end of an unparryable attack
var knight_counter_hold := 0.45 # Seconds of windup hold on a knight's counter, so its glint comes after the sword cooldown
var double_attack_chance := 0.35 # Goblin swings that follow up with a second when parried
var double_attack_hold := 0.65 # Seconds from parrying the first swing to the second's glint; outlasts the sword cooldown
var wizard_burst_cooldown := 2.5 # Seconds after each fireball
var wizard_melee_range := 32.0 # Pixels: a player this close gets the staff instead of fireballs
var wizard_melee_cooldown := 1.2 # Seconds between staff swipes
var wizard_melee_damage := 0.5 # Before the enemy damage multiplier
var wizard_deflect_miss_chance := 0.3 # Chance a returned fireball gets past a wizard or dragon (FireballReturner)
var wizard_volley_reaction_time := 0.1 # Seconds the player needs on top of the sword cooldown to return a fireball; less and the wizard or dragon takes the hit
# Support casters (Caster.gd): the warlock and the curses it casts (Curses.gd), and the
# necromancer, which raises the room's dead (Room.raise_fallen).
var warlock_curse_cooldown_min := 3.0 # Seconds between curses, rolled each time
var warlock_curse_cooldown_max := 5.0
var caster_keep_away := 80.0 # Pixels: warlocks and necromancers back away from a player closer than this
var necromancer_raise_cooldown_min := 4.0 # Seconds between raising the dead, rolled each time
var necromancer_raise_cooldown_max := 7.0
var curse_duration := 4.0 # Seconds each curse lasts
var curse_daze_time := 1.2 # Seconds the daze curse leaves the player unable to act
var curse_defense_multiplier := 2.0 # Damage taken while defense is lowered
var curse_attack_multiplier := 0.5 # Damage dealt while attack is lowered
var curse_speed_multiplier := 0.55 # Walk and roll speed while slowed
# Goblin family: trolls (Troll.gd) and orcs (Orc.tscn), placed with the room creator.
var troll_steal := 5.0 # Coins per floor number a troll takes with each hit that lands
var troll_coin_loss_chance := 0.1 # Chance each stolen coin isn't dropped back when the troll dies
# Dragons (Wyrm.gd): wyrms and the bigger wyverns circle the player, now and then stopping
# to breathe a fireball or charge. In the F2 menu their combat timings sit under Enemies,
# and how they move (distances, speeds, chances) under a Dragons tab of their own.
var wyrm_orbit_radius := 100.0 # Pixels from the player they circle at
var wyrm_orbit_flip_min := 1.0 # Seconds before it may turn round and circle the other way, rolled each time
var wyrm_orbit_flip_max := 2.5
var wyrm_orbit_flip_chance := 0.5 # Chance it does turn round each time it may
var wyrm_orbit_lead := 0.5 # Radians ahead round the circle it aims for while circling
var wyrm_back_off_lead := 0.3 # Share of wyrm_orbit_lead while backing off: mostly straight away, sliding round a little
var wyrm_orbit_stuck_time := 0.4 # Seconds pressed against something before it circles the other way
var wyrm_separation := 30.0 # Pixels: closer than this to another enemy, it steers away from it
var wyrm_cornered_share := 0.8 # Backing off, a target the floor's edge keeps closer than this share of its circle means it's cornered
var wyrm_escape_turn := 1.4 # Radians round the player a cornered dragon heads to slip out along the wall
var wyrm_keep_away := 0.85 # Share of the circle radius: a player closer than this sends it backing off
var wyrm_hit_back_off := 0.8 # Seconds it backs off without attacking after a hit lands (or a stun wears off)
var wyrm_first_attack_delay := 1.5 # Seconds it flies off, without attacking, after first noticing the player
var wyrm_first_back_off_radius := 1.4 # Times the circle radius it backs off to meanwhile
var wyrm_attack_cooldown_min := 1.6 # Seconds of circling between its attacks, rolled each time
var wyrm_attack_cooldown_max := 2.6
var wyrm_pack_attack_gap := 1.2 # Seconds every other dragon in the room waits after one finishes an attack
var wyrm_charge_chance := 0.5 # Share of attacks that are charges; the rest are fireballs
var wyrm_charge_hold_min := 0.2 # Seconds it hangs still in its lunge pose before a charge sets off, rolled each time
var wyrm_charge_hold_max := 0.5
var wyrm_charge_speed := 420.0 # Pixels/sec while charging
var wyrm_charge_overshoot := 28.0 # Pixels past the player a charge carries on
var wyrm_charge_max_distance := 240.0 # Pixels: longest a charge goes, overshoot included
var wyrm_clash_reach := 22.0 # Pixels short of the player where a charge bites
var wyrm_charge_recovery := 0.2 # Seconds it hovers after a charge before circling again
var wyrm_fireball_speed := 175.0 # Wyrm and wyvern fireballs, before any hit back
var wyrm_fireball_charge_time := 0.5 # Seconds it holds still glowing before breathing a fireball
var wyrm_breath_parry_window := 0.15 # Seconds from the glint at its mouth to the fireball; a sword hit on it in that time parries
var wyvern_heavy_charge_chance := 0.4 # Share of a wyvern's charges that glint red and can't be parried
var wyvern_heavy_end_lag := 1.0 # Seconds a wyvern hangs in the air, open, after an unparryable charge
var boss_laser_cooldown := 1.0

# --- Melee AI (goblins and knights; see MeleeEnemy and AttackCoordinator) ---
var engage_margin := 4.0 # Pixels inside the shorter of the two attack reaches to stop at
var pack_max_attackers := 1 # Enemies in a group allowed to step in and swing at once
var pack_swings_min := 1 # Swings per turn before stepping back out (groups only)
var pack_swings_max := 2
var pack_turn_gap_min := 0.1 # Seconds between one attacker leaving and the next stepping in
var pack_turn_gap_max := 0.35
var pack_turn_timeout := 3.0 # Seconds an attacker gets to reach the player before giving up its turn
var pack_ring_radius := 70.0 # Pixels from the player that waiting enemies circle at
var pack_circle_speed := 0.6 # Times the enemy's speed while circling
var alert_radius := 100.0 # Pixels: noticing the player alerts the rest of the room this close
var threat_reach := 28.0 # Pixels past its swing distance at which a player closing in sets off its windup
var counter_attack := true # A hit outside a parry makes it swing back at once, cooldown or not
var roam_speed := 0.5 # Times the enemy's speed while roaming, before it notices the player
var roam_pause_min := 0.5 # Seconds it stands at each end of its path, or between wanders in its area
var roam_pause_max := 1.5
# Group rushes (AttackCoordinator): now and then a few circling enemies rush in together
# from different sides and swing at once, a moment for the spin attack.
var group_rush_interval_min := 6.0 # Seconds of fighting between rushes, rolled each time
var group_rush_interval_max := 10.0
var group_rush_min := 2 # Fewest enemies in a rush (and in the fight, for one to happen)
var group_rush_max := 3
var group_rush_crowd_size := 3 # Enemies circling at once that count as a crowd...
var group_rush_crowd_speedup := 2.0 # ...and how many times faster the countdown to the next rush runs then
var group_rush_speed := 1.4 # Times their speed as they rush in
var group_rush_gather_time := 1.5 # Seconds to get into place; anyone not there by then drops out
var group_rush_hold := 0.9 # Seconds of windup hold before the glint; covers charging a spin
# A spin that catches a group rush stuns each rusher it hits for parried_stun_time plus
# this much per enemy in the rush, so there's time to finish them all off.
var group_rush_stun_per_enemy := 0.6

# --- Projectiles ---
var arrow_speed := 200.0
var fireball_speed := 150.0
var fireball_turn_rate := 2.5 # Radians/sec a wizard's fireball can turn towards the player
var laser_speed := 300.0
var projectile_lifetime := 5.0 # Seconds before a shot vanishes

# --- Time limit ---
var base_time := 90 # Seconds on the level timer before the time upgrade
var time_per_level := 30 # Seconds added per time upgrade level

# --- Loot & economy ---
var start_arrows := 10 # Arrows at the start of each floor
var start_keys := 0 # Keys given at the start of each floor, on top of any carried over
var keys_to_finish := 2 # Keys that open the end room; any spare carry over to the next floor
var start_floor := 1 # Floor a new run starts on
var arrow_drop_chance := 0.1
var arrow_drop_max := 2
var coin_multiplier := 1.0 # On top of the floor and looting multiplier
var upgrade_cost_multiplier := 1.0
var pickup_collect_distance := 6.0 # Pixels; raise it for a coin magnet
var pickup_home_accel := 900.0 # Pixels/sec² pickups fly towards the player

# --- Special floor tiles (SpecialTiles) ---
var spike_damage := 0.5 # Damage on stepping onto raised spikes, and again each spike_interval stood on them
var spike_interval := 1.0 # Seconds between spike hits while standing on them
var spike_warning_time := 0.5 # Seconds flat spikes show their tips after being stepped on, before stabbing up
var spike_up_time := 1.0 # Seconds spikes stay up after the last one standing on them leaves
var shock_damage := 1.0 # Damage from live wires or a live pressure plate
var shock_daze := 0.3 # Seconds the player can't act after a shock
var wire_idle_time := 2.5 # Seconds exposed wires rest between shocks
var wire_spark_time := 1.0 # Seconds they spark (the warning) before going live
var wire_live_time := 0.8 # Seconds they stay live
var plate_delay := 0.35 # Seconds from a pressure plate clicking down to it going live
var plate_live_time := 0.8 # Seconds a plate stays live
var plate_rearm_time := 1.5 # Seconds after going off before a plate can be set off again
var crack_time := 1.0 # Seconds cracked floor takes to give way once stood on
var crack_respawn_time := 5.0 # Seconds the hole stays open before the floor mends
var slick_grip := 300.0 # Pixels/sec² of speed the player gains or loses on slick floor (lower slides more)
# The same for enemies. Lower than the player's: they walk slower, so at the same grip
# they'd barely slide.
var enemy_slick_grip := 70.0
var paste_reach := 12.0 # Pixels past thermal paste's edge something caught in it can walk
var paste_pull := 60.0 # Pixels/sec it's pulled back to the middle while standing still
var paste_rolls_to_escape := 3 # Rolls the player needs to get out of paste
var paste_enemy_strain_time := 2.0 # Seconds an enemy runs on the spot at paste's edge before it's pulled back
var paste_enemy_pull := 25.0 # Pixels/sec an enemy is hauled back to the paste's middle (slower than the player)
var paste_enemy_escape_edges := 3 # The time an enemy reaches paste's edge that it tears free on
# Path cost for enemies of crossing a trap, against 1 for plain floor (RoomNav): they walk
# round one unless the way round is more than this many cells longer.
var trap_avoid_weight := 3.0
var slow_tile_multiplier := 0.6 # Walk, roll and attack speed on a slow tile
var fast_tile_multiplier := 1.4 # Walk, roll and attack speed on a speed tile
var teleport_glow_range := 20.0 # Pixels from a teleporter's edge at which its destination lights up

# --- Lighting (CaveLighting) ---
var lighting_enabled := true # Off shows the cave at full brightness, as before lighting
var cave_brightness := 0.75 # 0..1: how much of its colour the unlit cave keeps
var light_player_radius := 220.0 # Pixels from the player to where their light fades out
var light_player_energy := 0.5 # Strength of the player's light (added to cave_brightness where it falls)
var light_projectile_radius := 40.0 # Pixels; glow round fireballs and lasers
var light_pickup_radius := 18.0 # Pixels; glow round dropped arrows (coins don't glow)
var light_small_energy := 0.8 # Strength of the projectile and arrow pickup glows

# --- Game feel ---
var game_speed := 1.0 # Engine.time_scale outside hit-stop
var hitstop_enabled := true
var hitstop_time_scale := 0.05
var shake_multiplier := 1.0
var kill_combo_window := 1.0 # Seconds between kills for the death sound to keep pitching up

# --- Cheats ---
var god_mode := false # Hits and falls take no time
var infinite_arrows := false
var one_hit_kills := false
var freeze_enemies := false
var freeze_timer := false # The level timer stops counting down

# Display order and metadata for the debug menu: [category, key, label, min, max, step,
# where the value used to live (for the export)]. Booleans ignore min, max and step.
const FIELDS := [
	["Player", "player_speed", "Walk speed", 0, 600, 1, "Player.gd speed"],
	["Player", "roll_speed_multiplier", "Roll speed multiplier", 0, 6, 0.05, "Player.gd (literal 2)"],
	["Player", "roll_duration", "Roll duration (s)", 0.02, 2, 0.01, "Player.gd rolling.start(0.25)"],
	["Player", "roll_cooldown", "Roll cooldown (s)", 0, 5, 0.05, "Player.gd roll_cooldown.start(1)"],
	["Player", "hurt_invincibility", "Invincibility after hit (s)", 0, 5, 0.05, "Player.gd invincibility_cooldown.start(1)"],
	["Player", "player_knockback", "Knockback when hit", 0, 600, 5, "Player.gd KNOCKBACK_SPEED"],
	["Player", "sword_cooldown", "Sword cooldown (s)", 0, 3, 0.05, "Player.gd can_swing()"],
	["Player", "shoot_cooldown", "Shoot cooldown (s)", 0.05, 3, 0.05, "Player.gd shoot_cooldown.start(0.5)"],
	["Player", "shoot_recoil", "Shoot recoil", 0, 300, 5, "Player.gd SHOOT_RECOIL"],
	["Player", "blocked_daze_time", "Daze when blocked (s)", 0, 3, 0.05, "Player.gd BLOCKED_DAZE_TIME"],
	["Player", "pitfall_damage", "Pitfall damage", 0, 5, 0.5, "Player.gd take_damage(0.5, ...)"],
	["Player", "seconds_per_damage", "Seconds lost per damage", 0, 60, 0.5, "new (Player.lose_time; replaced health)"],

	["Combat", "sword_damage", "Sword damage", 0, 20, 0.5, "Enemy.gd SWORD_DAMAGE"],
	["Combat", "arrow_damage", "Arrow damage", 0, 20, 0.25, "Player.gd ARROW_DAMAGE"],
	["Combat", "arrow_charge_time", "Arrow charge time (s)", 0.05, 5, 0.05, "new (Player._update_charge)"],
	["Combat", "arrow_charge_multiplier", "Charged arrow damage multiplier", 1, 10, 0.1, "new (Player._fire_arrow)"],
	["Combat", "parry_window", "Parry window (s)", 0, 2, 0.01, "Enemy.gd PARRY_WINDOW"],
	["Combat", "parried_stun_time", "Parried stun (s)", 0, 5, 0.05, "Enemy.gd PARRIED_STUN_TIME"],
	["Combat", "instant_finisher", "Instant swings on stunned enemy", 0, 0, 0, "new (Player.in_finisher)"],
	["Combat", "parried_knockback", "Parried knockback multiplier", 0, 5, 0.05, "Enemy.gd PARRIED_KNOCKBACK"],
	["Combat", "hit_knockback", "Hit knockback multiplier", 0, 5, 0.05, "Enemy.take_damage (was 1x knockback_speed)"],
	["Combat", "stagger_damage_multiplier", "Stagger damage multiplier", 1, 10, 0.1, "Constants.gd STAGGER_DAMAGE_MULTIPLIER"],
	["Combat", "stagger_vulnerable_time", "Stagger vulnerable time (s)", 0, 10, 0.1, "Constants.gd STAGGER_VULNERABLE_TIME"],
	["Combat", "crit_roll_max", "Crit roll max (lower = more crits)", 0, 100, 1, "Enemy.gd CRIT_ROLL_MAX"],
	["Combat", "deflect_damage_multiplier", "Deflect damage multiplier", 0, 5, 0.05, "Constants.gd DEFLECT_DAMAGE_MULTIPLIER"],
	["Combat", "deflect_speed_multiplier", "Deflect speed multiplier", 0, 3, 0.05, "Constants.gd DEFLECT_SPEED_MULTIPLIER"],
	["Combat", "deflect_max_speed", "Deflect max speed", 50, 1000, 10, "Constants.gd DEFLECT_MAX_SPEED"],
	["Combat", "knight_block_stun", "Knight block stun (s)", 0, 5, 0.05, "MeleeEnemy.gd BLOCK_STUN_TIME"],
	["Combat", "chip_damage", "Chip damage on a block", 0, 5, 0.05, "new (Enemy._chip)"],
	["Combat", "spin_charge_time", "Spin charge time (s)", 0.05, 3, 0.05, "new (Player spin)"],
	["Combat", "spin_duration", "Spin duration (s)", 0.05, 2, 0.05, "new (Player spin)"],
	["Combat", "spin_radius", "Spin radius (px)", 5, 100, 1, "new (Player spin)"],
	["Combat", "spin_damage", "Spin damage", 0, 20, 0.5, "new (Player spin)"],
	["Combat", "spin_staggers", "Spin hits stun enemies", 0, 0, 0, "new (Enemy.spin_hit)"],
	["Combat", "spin_charge_move", "Walk speed while charging spin", 0, 1, 0.05, "new (Player spin)"],

	["Enemies", "enemy_health_multiplier", "Health multiplier", 0.1, 10, 0.1, "new (enemy .tscn health)"],
	["Enemies", "enemy_damage_multiplier", "Damage multiplier", 0, 10, 0.1, "new (enemy .tscn damage)"],
	["Enemies", "enemy_speed_multiplier", "Speed multiplier", 0, 5, 0.05, "new (enemy .tscn speed)"],
	["Enemies", "enemy_knockback_multiplier", "Knockback taken multiplier", 0, 5, 0.05, "new (enemy .tscn knockback_speed)"],
	["Enemies", "enemy_attack_cooldown_multiplier", "Attack cooldown multiplier", 0.1, 5, 0.05, "new (enemy .tscn attack_cooldown_length)"],
	["Enemies", "enemy_windup_multiplier", "Windup hold multiplier", 0, 5, 0.05, "new (enemy .tscn windup_hold_min/max)"],
	["Enemies", "unparryable_chance", "Knight unparryable attack chance", 0, 1, 0.05, "new (MeleeEnemy unparryable_attack)"],
	["Enemies", "unparryable_window", "Knight unparryable: red star to strike (s)", 0.05, 2, 0.05, "new (Enemy._twinkle)"],
	["Enemies", "heavy_end_lag", "Knight unparryable end lag (s)", 0, 5, 0.05, "new (MeleeEnemy._start_end_lag)"],
	["Enemies", "knight_counter_hold", "Knight counter windup hold (s)", 0, 2, 0.05, "new (MeleeEnemy._counter)"],
	["Enemies", "double_attack_chance", "Goblin double attack chance", 0, 1, 0.05, "new (MeleeEnemy double_attack)"],
	["Enemies", "double_attack_hold", "Double attack follow-up hold (s)", 0, 2, 0.05, "new (MeleeEnemy._parried_follow_up)"],
	["Enemies", "wizard_burst_cooldown", "Wizard fireball cooldown (s)", 0.1, 10, 0.1, "RangedEnemy.gd BURST_COOLDOWN"],
	["Enemies", "wizard_melee_range", "Wizard melee range (px)", 0, 150, 1, "new (RangedEnemy._in_melee_range)"],
	["Enemies", "wizard_melee_cooldown", "Wizard melee cooldown (s)", 0.1, 5, 0.05, "new (RangedEnemy._start_melee)"],
	["Enemies", "wizard_melee_damage", "Wizard melee damage", 0, 5, 0.25, "new (RangedEnemy.melee_damage)"],
	["Enemies", "warlock_curse_cooldown_min", "Warlock curse cooldown min (s)", 0.1, 20, 0.1, "new (Warlock)"],
	["Enemies", "warlock_curse_cooldown_max", "Warlock curse cooldown max (s)", 0.1, 20, 0.1, "new (Warlock)"],
	["Enemies", "caster_keep_away", "Warlock/necromancer keep-away (px)", 0, 300, 1, "new (Caster)"],
	["Enemies", "necromancer_raise_cooldown_min", "Necromancer raise cooldown min (s)", 0.1, 30, 0.1, "new (Necromancer)"],
	["Enemies", "necromancer_raise_cooldown_max", "Necromancer raise cooldown max (s)", 0.1, 30, 0.1, "new (Necromancer)"],
	["Enemies", "curse_duration", "Curse duration (s)", 0.1, 20, 0.1, "new (Curses)"],
	["Enemies", "curse_daze_time", "Daze curse duration (s)", 0, 5, 0.05, "new (Curses)"],
	["Enemies", "curse_defense_multiplier", "Lowered defense: damage taken x", 1, 5, 0.25, "new (Curses)"],
	["Enemies", "curse_attack_multiplier", "Lowered attack: damage dealt x", 0, 1, 0.05, "new (Curses)"],
	["Enemies", "curse_speed_multiplier", "Slowed: speed x", 0.1, 1, 0.05, "new (Curses)"],
	["Enemies", "wizard_deflect_miss_chance", "Wizard/dragon deflect miss chance", 0, 1, 0.05, "RangedEnemy.gd DEFLECT_MISS_CHANCE"],
	["Enemies", "wizard_volley_reaction_time", "Wizard/dragon volley reaction time (s)", 0, 2, 0.05, "new (RangedEnemy._player_could_return)"],
	["Enemies", "troll_steal", "Troll coins stolen per hit (x floor)", 0, 50, 1, "new (Troll.landed_hit)"],
	["Enemies", "troll_coin_loss_chance", "Troll stolen coin lost chance", 0, 1, 0.05, "new (Troll.die)"],
	["Enemies", "wyrm_hit_back_off", "Wyrm back-off after being hit (s)", 0, 5, 0.05, "new (Wyrm._back_off)"],
	["Enemies", "wyrm_first_attack_delay", "Wyrm delay before its first attack (s)", 0, 6, 0.1, "new (Wyrm._open_fight)"],
	["Enemies", "wyrm_attack_cooldown_min", "Wyrm attack cooldown min (s)", 0.1, 10, 0.1, "new (Wyrm._roll_cooldown)"],
	["Enemies", "wyrm_attack_cooldown_max", "Wyrm attack cooldown max (s)", 0.1, 10, 0.1, "new (Wyrm._roll_cooldown)"],
	["Enemies", "wyrm_pack_attack_gap", "Wyrm gap after another dragon attacks (s)", 0, 10, 0.1, "new (Wyrm._hold_off_other_dragons)"],
	["Enemies", "wyrm_charge_hold_min", "Wyrm hold before a charge min (s)", 0, 6, 0.1, "new (Wyrm._start_charge)"],
	["Enemies", "wyrm_charge_hold_max", "Wyrm hold before a charge max (s)", 0, 6, 0.1, "new (Wyrm._start_charge)"],
	["Enemies", "wyrm_charge_recovery", "Wyrm recovery after a charge (s)", 0, 3, 0.05, "new (Wyrm._end_attack)"],
	["Enemies", "wyrm_fireball_charge_time", "Wyrm fireball charge-up (s)", 0, 6, 0.1, "new (Wyrm._hold_breath)"],
	["Enemies", "wyrm_breath_parry_window", "Wyrm fireball glint parry window (s)", 0.02, 1, 0.01, "new (Wyrm._pulse_breath)"],
	["Enemies", "wyvern_heavy_end_lag", "Wyvern unparryable charge end lag (s)", 0, 5, 0.05, "new (Wyrm._end_attack)"],
	["Enemies", "boss_laser_cooldown", "Boss laser cooldown (s)", 0.1, 10, 0.1, "Boss.gd LASER_COOLDOWN"],

	["Dragons", "wyrm_orbit_radius", "Circle radius (px)", 20, 200, 1, "new (Wyrm._circle)"],
	["Dragons", "wyrm_orbit_flip_min", "Circle direction change min (s)", 0.1, 10, 0.1, "new (Wyrm._circle)"],
	["Dragons", "wyrm_orbit_flip_max", "Circle direction change max (s)", 0.1, 10, 0.1, "new (Wyrm._circle)"],
	["Dragons", "wyrm_orbit_flip_chance", "Circle direction change chance", 0, 1, 0.05, "Wyrm._circle (was a fixed 0.5)"],
	["Dragons", "wyrm_orbit_lead", "Circling lead (rad)", 0, 2, 0.05, "Wyrm.gd ORBIT_LEAD"],
	["Dragons", "wyrm_back_off_lead", "Back-off lead (x circling lead)", 0, 1, 0.05, "Wyrm.gd BACK_OFF_LEAD"],
	["Dragons", "wyrm_keep_away", "Back-off distance (x circle radius)", 0, 1.5, 0.05, "new (Wyrm._circle)"],
	["Dragons", "wyrm_first_back_off_radius", "First back-off radius (x circle radius)", 0.5, 3, 0.05, "new (Wyrm._circle)"],
	["Dragons", "wyrm_orbit_stuck_time", "Stuck time before turning round (s)", 0, 3, 0.05, "Wyrm.gd ORBIT_STUCK_TIME"],
	["Dragons", "wyrm_separation", "Separation from other enemies (px)", 0, 100, 1, "Wyrm.gd SEPARATION"],
	["Dragons", "wyrm_cornered_share", "Cornered below (x circle radius)", 0, 1, 0.05, "Wyrm.gd CORNERED_SHARE"],
	["Dragons", "wyrm_escape_turn", "Corner escape turn (rad)", 0, 3.1, 0.05, "Wyrm.gd ESCAPE_TURN"],
	["Dragons", "wyrm_charge_chance", "Charge (vs fireball) chance", 0, 1, 0.05, "new (Wyrm._start_attack)"],
	["Dragons", "wyvern_heavy_charge_chance", "Wyvern unparryable charge chance", 0, 1, 0.05, "new (Wyrm._start_attack)"],
	["Dragons", "wyrm_charge_speed", "Charge speed (px/s)", 50, 800, 10, "new (Wyrm._charge)"],
	["Dragons", "wyrm_charge_overshoot", "Charge overshoot (px)", 0, 150, 1, "new (Wyrm._begin_dash)"],
	["Dragons", "wyrm_charge_max_distance", "Charge max distance (px)", 20, 500, 5, "new (Wyrm._begin_dash)"],
	["Dragons", "wyrm_clash_reach", "Charge bite distance (px)", 0, 80, 1, "new (Wyrm._ahead_of_strike)"],
	["Dragons", "wyrm_fireball_speed", "Fireball speed (px/s)", 10, 600, 10, "new (Wyrm.breathe_fire)"],

	["AI", "engage_margin", "Engage margin (px)", 0, 30, 1, "new (MeleeEnemy engage distance)"],
	["AI", "pack_max_attackers", "Max attackers at once", 1, 6, 1, "new (AttackCoordinator)"],
	["AI", "pack_swings_min", "Swings per turn (min)", 1, 6, 1, "new (MeleeEnemy)"],
	["AI", "pack_swings_max", "Swings per turn (max)", 1, 6, 1, "new (MeleeEnemy)"],
	["AI", "pack_turn_gap_min", "Gap between turns min (s)", 0, 5, 0.05, "new (AttackCoordinator)"],
	["AI", "pack_turn_gap_max", "Gap between turns max (s)", 0, 5, 0.05, "new (AttackCoordinator)"],
	["AI", "pack_turn_timeout", "Turn timeout (s)", 0.5, 10, 0.1, "new (AttackCoordinator)"],
	["AI", "pack_ring_radius", "Circle radius (px)", 20, 150, 1, "new (MeleeEnemy)"],
	["AI", "pack_circle_speed", "Circle speed multiplier", 0, 2, 0.05, "new (MeleeEnemy)"],
	["AI", "alert_radius", "Alert others radius (px)", 0, 300, 1, "new (MeleeEnemy._alert_pack)"],
	["AI", "threat_reach", "Windup on approach reach (px)", 0, 80, 1, "new (MeleeEnemy._player_in_threat_range)"],
	["AI", "counter_attack", "Counter-attack when hit", 0, 0, 0, "new (MeleeEnemy._after_hit)"],
	["AI", "roam_speed", "Roam speed multiplier", 0, 2, 0.05, "new (MeleeEnemy._roam)"],
	["AI", "roam_pause_min", "Roam pause min (s)", 0, 10, 0.1, "new (MeleeEnemy._roam)"],
	["AI", "roam_pause_max", "Roam pause max (s)", 0, 10, 0.1, "new (MeleeEnemy._roam)"],
	["AI", "group_rush_interval_min", "Group rush every min (s)", 0.5, 60, 0.5, "new (AttackCoordinator)"],
	["AI", "group_rush_interval_max", "Group rush every max (s)", 0.5, 60, 0.5, "new (AttackCoordinator)"],
	["AI", "group_rush_min", "Group rush size min", 2, 6, 1, "new (AttackCoordinator)"],
	["AI", "group_rush_max", "Group rush size max", 2, 6, 1, "new (AttackCoordinator)"],
	["AI", "group_rush_crowd_size", "Group rush: crowd size", 2, 8, 1, "new (AttackCoordinator._circling_count)"],
	["AI", "group_rush_crowd_speedup", "Group rush: crowd speedup", 1, 5, 0.1, "new (AttackCoordinator._update_rush_countdown)"],
	["AI", "group_rush_speed", "Group rush speed multiplier", 0.5, 3, 0.05, "new (MeleeEnemy._group_rush)"],
	["AI", "group_rush_gather_time", "Group rush gather time (s)", 0.2, 5, 0.1, "new (AttackCoordinator)"],
	["AI", "group_rush_hold", "Group rush windup hold (s)", 0, 3, 0.05, "new (MeleeEnemy.rush_strike)"],
	["AI", "group_rush_stun_per_enemy", "Spun rush: extra stun per rusher (s)", 0, 3, 0.05, "new (MeleeEnemy._spin_stun_time)"],

	["Projectiles", "arrow_speed", "Arrow speed", 10, 1000, 10, "Arrow.tscn speed"],
	["Projectiles", "fireball_speed", "Fireball speed", 10, 1000, 10, "Fireball.tscn speed"],
	["Projectiles", "fireball_turn_rate", "Fireball homing turn rate (rad/s)", 0, 20, 0.1, "new (Projectile._steer)"],
	["Projectiles", "laser_speed", "Laser speed", 10, 1000, 10, "Laser.tscn speed"],
	["Projectiles", "projectile_lifetime", "Lifetime (s)", 0.5, 30, 0.5, "Projectile.gd LIFETIME"],

	["Timer", "base_time", "Base time limit (s)", 5, 1800, 5, "LevelCountdown.gd BASE_TIME"],
	["Timer", "time_per_level", "Seconds per time upgrade", 0, 300, 5, "LevelCountdown.gd TIME_PER_LEVEL"],

	["Loot", "start_arrows", "Arrows per floor", 0, 99, 1, "Constants.gd START_ARROWS"],
	["Loot", "start_keys", "Keys per floor", 0, 3, 1, "Game.gd DEBUG_START_KEYS"],
	["Loot", "keys_to_finish", "Keys to open the end room", 0, 3, 1, "Room.gd (was 3)"],
	["Loot", "start_floor", "Run start floor", 1, 10, 1, "Game.gd START_FLOOR"],
	["Loot", "arrow_drop_chance", "Arrow drop chance", 0, 1, 0.05, "Constants.gd ARROW_DROP_CHANCE"],
	["Loot", "arrow_drop_max", "Arrow drop max", 1, 10, 1, "Constants.gd ARROW_DROP_MAX"],
	["Loot", "coin_multiplier", "Coin multiplier", 0, 20, 0.1, "new (Enemy._coin_multiplier)"],
	["Loot", "upgrade_cost_multiplier", "Upgrade cost multiplier", 0, 5, 0.05, "new (UpgradeMenu.gd COSTS)"],
	["Loot", "pickup_collect_distance", "Pickup collect distance", 1, 400, 1, "Pickup.gd COLLECT_DISTANCE"],
	["Loot", "pickup_home_accel", "Pickup homing accel", 50, 5000, 50, "Pickup.gd HOME_ACCEL"],

	["Tiles", "spike_damage", "Spike damage", 0, 5, 0.25, "new (SpecialTiles)"],
	["Tiles", "spike_interval", "Spike hit interval (s)", 0.1, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "spike_warning_time", "Spikes warning (s)", 0, 3, 0.05, "new (SpecialTiles)"],
	["Tiles", "spike_up_time", "Spikes stay up (s)", 0, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "shock_damage", "Shock damage", 0, 5, 0.25, "new (SpecialTiles)"],
	["Tiles", "shock_daze", "Shock daze (s)", 0, 3, 0.05, "new (SpecialTiles)"],
	["Tiles", "wire_idle_time", "Wires rest (s)", 0.1, 20, 0.1, "new (SpecialTiles)"],
	["Tiles", "wire_spark_time", "Wires spark warning (s)", 0, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "wire_live_time", "Wires live (s)", 0.05, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "plate_delay", "Plate click to live (s)", 0, 3, 0.05, "new (SpecialTiles)"],
	["Tiles", "plate_live_time", "Plate live (s)", 0.05, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "plate_rearm_time", "Plate re-arm (s)", 0, 10, 0.1, "new (SpecialTiles)"],
	["Tiles", "crack_time", "Cracked floor gives way after (s)", 0, 5, 0.05, "new (SpecialTiles)"],
	["Tiles", "crack_respawn_time", "Hole mends after (s)", 0.5, 30, 0.5, "new (SpecialTiles)"],
	["Tiles", "slick_grip", "Slick floor grip, player (px/s²)", 20, 3000, 10, "new (Player._apply_ground)"],
	["Tiles", "enemy_slick_grip", "Slick floor grip, enemies (px/s²)", 5, 3000, 5, "new (Enemy.ground_motion)"],
	["Tiles", "paste_reach", "Paste reach past its edge (px)", 0, 48, 1, "new (SpecialTiles)"],
	["Tiles", "paste_pull", "Paste pull back (px/s)", 0, 300, 5, "new (SpecialTiles)"],
	["Tiles", "paste_rolls_to_escape", "Rolls to escape paste", 1, 10, 1, "new (SpecialTiles._hold_in_paste)"],
	["Tiles", "paste_enemy_strain_time", "Enemy strains at paste edge (s)", 0, 10, 0.25, "new (SpecialTiles._hold_in_paste)"],
	["Tiles", "paste_enemy_pull", "Enemy paste pull back (px/s)", 1, 300, 1, "new (SpecialTiles._hold_in_paste)"],
	["Tiles", "paste_enemy_escape_edges", "Enemy escapes paste on edge reach no.", 1, 10, 1, "new (SpecialTiles._hold_in_paste)"],
	["Tiles", "trap_avoid_weight", "Enemy trap avoidance (path cost)", 1, 20, 0.5, "new (RoomNav.set_avoided)"],
	["Tiles", "slow_tile_multiplier", "Slow tile speed x", 0.1, 1, 0.05, "new (SpecialTiles.speed_factor)"],
	["Tiles", "fast_tile_multiplier", "Speed tile speed x", 1, 3, 0.05, "new (SpecialTiles.speed_factor)"],
	["Tiles", "teleport_glow_range", "Teleporter destination glow range (px)", 0, 200, 4, "new (SpecialTiles._update_glow)"],

	["Lighting", "lighting_enabled", "Lighting on", 0, 0, 0, "new (CaveLighting)"],
	["Lighting", "cave_brightness", "Cave brightness", 0, 1, 0.05, "new (CaveLighting.ambient_color)"],
	["Lighting", "light_player_radius", "Player light radius (px)", 0, 400, 5, "new (CaveLighting)"],
	["Lighting", "light_player_energy", "Player light strength", 0, 3, 0.05, "new (CaveLighting)"],
	["Lighting", "light_projectile_radius", "Fireball glow radius (px)", 0, 200, 2, "new (CaveLighting)"],
	["Lighting", "light_pickup_radius", "Dropped arrow glow radius (px)", 0, 100, 1, "new (CaveLighting)"],
	["Lighting", "light_small_energy", "Fireball / arrow glow strength", 0, 3, 0.05, "new (CaveLighting)"],

	["Feel", "game_speed", "Game speed", 0.1, 3, 0.05, "new (Engine.time_scale)"],
	["Feel", "hitstop_enabled", "Hit-stop", 0, 0, 0, "new (Juice.hitstop)"],
	["Feel", "hitstop_time_scale", "Hit-stop time scale", 0, 1, 0.01, "Juice.gd HITSTOP_TIME_SCALE"],
	["Feel", "shake_multiplier", "Screen shake multiplier", 0, 5, 0.1, "new (Juice.shake)"],
	["Feel", "kill_combo_window", "Kill combo window (s)", 0, 5, 0.05, "Room.gd _on_enemy_died (was per room visit)"],

	["Cheats", "god_mode", "God mode", 0, 0, 0, "new"],
	["Cheats", "infinite_arrows", "Infinite arrows", 0, 0, 0, "new"],
	["Cheats", "one_hit_kills", "One-hit kills", 0, 0, 0, "new"],
	["Cheats", "freeze_enemies", "Freeze enemies", 0, 0, 0, "new"],
	["Cheats", "freeze_timer", "Freeze level timer", 0, 0, 0, "new"],
]

var _defaults := {} # key -> shipped value, read before anything can change it

func _ready() -> void:
	for field: Array in FIELDS:
		_defaults[field[1]] = get(field[1])

func default_of(key: String) -> Variant:
	return _defaults[key]

func is_default(key: String) -> bool:
	return get(key) == _defaults[key]

func set_value(key: String, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	changed.emit(key)

func reset(key: String) -> void:
	set_value(key, _defaults[key])

func reset_all() -> void:
	for field: Array in FIELDS:
		reset(field[1])

# The level timer's full length for the current time upgrade.
func time_limit() -> float:
	return base_time + SaveData.time_level * time_per_level
