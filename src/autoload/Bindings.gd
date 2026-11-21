extends Node

# Runtime keyboard and controller bindings for the actions the game itself reads.
# project.godot supplies the defaults; this autoload re-applies them (or the player's saved
# choices) to InputMap on every launch. Each action has one replaceable key and button plus
# fixed alternates - arrow keys, left-stick axes and the extra attack keys - that stay
# available so rebinding never removes a way to play. F1 and F2 stay reserved for the room
# creator and debug menu. Joypad events use device -1 so any controller works, including one
# that gets a new id after reconnecting. SaveData owns the persistent copy.

const UNBOUND := -1
# J is Sword's replaceable key and Select's fixed alternate by design. Only those two actions
# may bind it: any other action taking J would fire Select as well.
const SHARED_FIXED_KEYS := {KEY_J: ["melee_attack", "select"]}
# These keys are read directly by the room creator and debug menu, outside InputMap.
const RESERVED_KEYS := [KEY_F1, KEY_F2]
const BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_GUIDE: "GUIDE",
	JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "UP",
	JOY_BUTTON_DPAD_DOWN: "DOWN",
	JOY_BUTTON_DPAD_LEFT: "LEFT",
	JOY_BUTTON_DPAD_RIGHT: "RIGHT",
}

# "keys" and "axes" survive rebinding; "key" and "button" are the parts players change.
const ACTIONS := [
	{"action": "left", "label": "MOVE LEFT", "key": KEY_A, "button": JOY_BUTTON_DPAD_LEFT,
		"keys": [KEY_LEFT], "axes": [[0, -1.0]]},
	{"action": "right", "label": "MOVE RIGHT", "key": KEY_D, "button": JOY_BUTTON_DPAD_RIGHT,
		"keys": [KEY_RIGHT], "axes": [[0, 1.0]]},
	{"action": "up", "label": "MOVE UP", "key": KEY_W, "button": JOY_BUTTON_DPAD_UP,
		"keys": [KEY_UP], "axes": [[1, -1.0]]},
	{"action": "down", "label": "MOVE DOWN", "key": KEY_S, "button": JOY_BUTTON_DPAD_DOWN,
		"keys": [KEY_DOWN], "axes": [[1, 1.0]]},
	{"action": "melee_attack", "label": "SWORD", "key": KEY_J, "button": JOY_BUTTON_X,
		"keys": [KEY_Z], "axes": []},
	{"action": "ranged_attack", "label": "BOW", "key": KEY_K, "button": JOY_BUTTON_Y,
		"keys": [KEY_X], "axes": []},
	{"action": "roll", "label": "ROLL", "key": KEY_SPACE, "button": JOY_BUTTON_RIGHT_SHOULDER,
		"keys": [], "axes": [[5, 1.0]]},
	{"action": "pause", "label": "PAUSE", "key": KEY_ESCAPE, "button": JOY_BUTTON_START,
		"keys": [], "axes": []},
	{"action": "select", "label": "SELECT", "key": KEY_ENTER, "button": JOY_BUTTON_A,
		"keys": [KEY_J], "axes": []},
]

var bindings := {} # action -> {"key": int, "button": int}; mirrored into SaveData.bindings

func _ready() -> void:
	load_from_save()
	apply()

# Reads the saved copy so a missing [controls] section (older saves) keeps every default.
# Bad values are dropped rather than trusted: a hand-edited save must not break input.
func load_from_save() -> void:
	var saved: Variant = SaveData.bindings
	for entry: Dictionary in ACTIONS:
		var action := String(entry["action"])
		var saved_pair: Dictionary = {}
		if saved is Dictionary && saved.has(action) && saved[action] is Dictionary:
			saved_pair = saved[action] as Dictionary
		var key := int(saved_pair.get("key", entry["key"]))
		var button := int(saved_pair.get("button", entry["button"]))
		if !_valid_key(key):
			key = int(entry["key"])
		if !_valid_button(button):
			button = int(entry["button"])
		bindings[action] = {"key": key, "button": button}
	_write_to_save()

func apply() -> void:
	for entry: Dictionary in ACTIONS:
		var action := String(entry["action"])
		if !InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var used_keys := {}
		for key: int in entry.get("keys", []):
			if used_keys.has(key):
				continue
			used_keys[key] = true
			InputMap.action_add_event(action, _key_event(key))
		for axis_data: Array in entry.get("axes", []):
			InputMap.action_add_event(action, _axis_event(int(axis_data[0]), float(axis_data[1])))
		var pair: Dictionary = bindings[action]
		var key_value := int(pair["key"])
		if key_value != UNBOUND && !used_keys.has(key_value):
			InputMap.action_add_event(action, _key_event(key_value))
		var button_value := int(pair["button"])
		# Actions have no fixed pad buttons, so only the replaceable one needs adding.
		if button_value != UNBOUND:
			InputMap.action_add_event(action, _button_event(button_value))

func set_key(action: String, keycode: int) -> void:
	if !bindings.has(action) || !_valid_key(keycode):
		return
	bindings[action]["key"] = keycode
	_write_to_save()
	apply()

func set_button(action: String, button_index: int) -> void:
	if !bindings.has(action) || !_valid_button(button_index):
		return
	bindings[action]["button"] = button_index
	_write_to_save()
	apply()

func reset_defaults() -> void:
	SaveData.bindings = {}
	load_from_save()
	apply()

func key_for(action: String) -> int:
	if !bindings.has(action):
		return UNBOUND
	return int((bindings[action] as Dictionary)["key"])

func button_for(action: String) -> int:
	if !bindings.has(action):
		return UNBOUND
	return int((bindings[action] as Dictionary)["button"])

func action_label(action: String) -> String:
	for entry: Dictionary in ACTIONS:
		if entry["action"] == action:
			return String(entry["label"])
	return action.to_upper()

# Returns the action that already uses this key, or an empty string when it is free for
# `action`. Fixed alternates count too: binding Move Left to the Right arrow would fire both
# actions. J stays free only for Sword and Select, which already share it by design.
func key_owner(keycode: int, action := "") -> String:
	var candidates: Array[String] = []
	for entry: Dictionary in ACTIONS:
		var candidate := String(entry["action"])
		if key_for(candidate) == keycode:
			candidates.append(candidate)
		for fixed_key: int in entry.get("keys", []):
			if fixed_key == keycode:
				candidates.append(candidate)
	var shared_owners: Array = SHARED_FIXED_KEYS.get(keycode, [])
	for candidate: String in candidates:
		if candidate == action:
			continue
		if shared_owners.has(candidate) && shared_owners.has(action):
			continue
		return candidate
	return ""

# True when the action that owns this key only has it as a fixed alternate. Those rows don't
# show the key, so the panel should say it is reserved rather than used by a visible binding.
func is_fixed_alternate(keycode: int, owner: String) -> bool:
	for entry: Dictionary in ACTIONS:
		if String(entry["action"]) != owner:
			continue
		for fixed_key: int in entry.get("keys", []):
			if fixed_key == keycode:
				return true
	return false

func is_reserved_key(keycode: int) -> bool:
	return RESERVED_KEYS.has(keycode)

func button_owner(button_index: int) -> String:
	for action: String in bindings:
		if button_for(action) == button_index:
			return action
	return ""

func key_name(keycode: int) -> String:
	if keycode == UNBOUND:
		return "--"
	return OS.get_keycode_string(keycode)

func button_name(button_index: int) -> String:
	if button_index == UNBOUND:
		return "--"
	if BUTTON_NAMES.has(button_index):
		return String(BUTTON_NAMES[button_index])
	return "BTN %d" % button_index

func _valid_key(keycode: int) -> bool:
	return keycode > 0 && !is_reserved_key(keycode) && keycode != KEY_CTRL \
		&& keycode != KEY_SHIFT && keycode != KEY_ALT && keycode != KEY_META

func _valid_button(button_index: int) -> bool:
	return button_index == UNBOUND || (button_index >= 0 && button_index <= 31)

func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event

func _button_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	return event

func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event

func _write_to_save() -> void:
	var data := {}
	for action: String in bindings:
		var pair: Dictionary = bindings[action]
		data[action] = {"key": int(pair["key"]), "button": int(pair["button"])}
	SaveData.bindings = data
