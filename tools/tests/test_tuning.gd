extends "res://tools/tests/test_case.gd"

# Tuning's debug-menu table (FIELDS) has to match its variables: every row names a real
# value, once, with a sane range, and resetting restores the shipped value.

func test_fields_name_real_values() -> void:
	var tuning := autoload("Tuning")
	var seen := {}
	for field: Array in tuning.FIELDS:
		var key: String = field[1]
		expect(key in tuning, "FIELDS row %s is a Tuning variable" % key)
		expect(!seen.has(key), "FIELDS row %s appears once" % key)
		seen[key] = true
		if key in tuning && typeof(tuning.get(key)) != TYPE_BOOL:
			expect(float(field[3]) <= float(field[4]), "%s: min <= max" % key)

func test_reset_restores_the_default() -> void:
	var tuning := autoload("Tuning")
	var shipped: float = tuning.default_of("player_speed")
	tuning.set_value("player_speed", shipped + 50.0)
	expect(!tuning.is_default("player_speed"), "changed value is marked as changed")
	tuning.reset("player_speed")
	expect_equal(tuning.player_speed, shipped, "player_speed after reset")
