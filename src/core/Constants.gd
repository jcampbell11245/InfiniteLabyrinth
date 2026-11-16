class_name Constants

# Dungeon layout: a grid of COLUMNS x ROWS generated rooms, plus the special rooms below.
const COLUMNS := 6
const ROWS := 5
const ROOM_SIZE := Vector2(360, 384) # Distance between neighbouring rooms, in pixels (13x13-floor rooms)

# Ids of the rooms that sit outside the grid (grid rooms are 0..COLUMNS*ROWS-1).
const START_ROOM := 60
const END_ROOM := 61
const BOSS_ROOM := 62

const BASE_HEALTH := 5 # Hearts before the health upgrade

# Arrows are limited: each floor starts with START_ARROWS, and a killed enemy has
# ARROW_DROP_CHANCE of dropping 1..ARROW_DROP_MAX more, which fly to the player like coins.
const START_ARROWS := 10
const ARROW_DROP_CHANCE := 0.4
const ARROW_DROP_MAX := 2

# Parrying (see Enemy._on_player_sword): whoever is staggered, a parried enemy or a
# player whose swing was blocked, is left vulnerable: their next hit taken does
# STAGGER_DAMAGE_MULTIPLIER times the damage, if it lands within STAGGER_VULNERABLE_TIME.
const STAGGER_DAMAGE_MULTIPLIER := 2.5
const STAGGER_VULNERABLE_TIME := 3.0 # Seconds

# Deflecting: a fireball hit back by a sword (or batted back by a wizard) does this many
# times its damage and flies this many times faster, compounding with each return.
const DEFLECT_DAMAGE_MULTIPLIER := 1.5
const DEFLECT_SPEED_MULTIPLIER := 1.15
const DEFLECT_MAX_SPEED := 450.0 # Pixels/sec; faster risks skipping through hurtboxes

# Physics layers, matching Project Settings > Layer Names > 2D Physics.
enum Layer {
	GENERAL = 1,
	ENEMY = 2,
	PLAYER = 3,
	ARROW = 4,
	ENEMY_PROJECTILE = 5,
	PITFALL = 6,
	FEET = 7,
	DETECTION_ZONE = 8,
	TOP_TILES = 9,
	ROOM = 10,
	ROOM_DETECTOR = 11,
	ROOM_TRANSITION = 12,
}
