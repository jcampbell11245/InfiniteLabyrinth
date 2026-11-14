class_name Constants

# Dungeon layout: a grid of COLUMNS x ROWS generated rooms, plus the special rooms below.
const COLUMNS = 6
const ROWS = 5
const ROOM_SIZE = Vector2(264, 288) # Distance between neighbouring rooms, in pixels
# BUG(see BUGS.md): Player and CameraRig step rooms by 261px instead of ROOM_SIZE.x.
const LEGACY_ROOM_WIDTH = 261

# A grid room's offset from room 0, stepping columns by LEGACY_ROOM_WIDTH. Only meaningful
# for grid rooms (ids 0..COLUMNS*ROWS-1).
static func legacy_room_offset(room_id):
	return Vector2((room_id % COLUMNS) * LEGACY_ROOM_WIDTH, (room_id / COLUMNS) * ROOM_SIZE.y)

# Ids of the rooms that sit outside the grid (grid rooms are 0..COLUMNS*ROWS-1).
const START_ROOM = 60
const END_ROOM = 61
const BOSS_ROOM = 62

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
