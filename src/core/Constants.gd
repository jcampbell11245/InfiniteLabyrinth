class_name Constants

# Dungeon layout: a grid of COLUMNS x ROWS generated rooms, plus the special rooms below.
const COLUMNS := 6
const ROWS := 5
const ROOM_SIZE := Vector2(360, 384) # Distance between neighbouring rooms, in pixels (13x13-floor rooms)

# Ids of the rooms that sit outside the grid (grid rooms are 0..COLUMNS*ROWS-1).
const START_ROOM := 60
const END_ROOM := 61
const BOSS_ROOM := 62

# Health, arrows, parrying and deflecting numbers moved to the Tuning autoload so the
# debug menu (F2) can change them while the game runs.

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
