class_name Direction

# The four facing directions. They are plain strings because they double as animation
# name suffixes ("walk_" + direction).

const RIGHT := "right"
const LEFT := "left"
const UP := "up"
const DOWN := "down"

# Unit vector for a direction, or Vector2.ZERO if it isn't one of the four.
static func to_vector(direction: String) -> Vector2:
	match direction:
		RIGHT: return Vector2.RIGHT
		LEFT: return Vector2.LEFT
		UP: return Vector2.UP
		DOWN: return Vector2.DOWN
	return Vector2.ZERO

# Rotation for a pivot whose child points right by default (hitboxes, detection zones).
static func to_rotation_degrees(direction: String) -> float:
	match direction:
		LEFT: return 180.0
		UP: return 270.0
		DOWN: return 90.0
	return 0.0
