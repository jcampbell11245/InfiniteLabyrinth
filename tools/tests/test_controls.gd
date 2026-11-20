extends "res://tools/tests/test_case.gd"

# Control bindings are saved choices applied to InputMap at startup. The options panel's
# Controls page captures a key or pad button per action and keeps the defaults available
# for old saves and for the reset button.

func test_default_bindings_are_applied_to_input_map() -> void:
	var bindings := autoload("Bindings")
	var snapshot := _snapshot()
	bindings.reset_defaults()
	for entry: Dictionary in bindings.ACTIONS:
		var action := String(entry["action"])
		expect(InputMap.has_action(action), "%s is a live input action" % action)
		expect(_has_key(action, int(entry["key"])), "%s has its default key in InputMap" % action)
		if int(entry["button"]) != bindings.UNBOUND:
			expect(_has_button(action, int(entry["button"])),
				"%s has its default pad button in InputMap" % action)
	_restore(snapshot)

func test_changing_binding_updates_input_map_and_save_data() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var snapshot := _snapshot()
	bindings.set_key("roll", KEY_R)
	bindings.set_button("roll", JOY_BUTTON_B)
	expect(bindings.key_for("roll") == KEY_R, "the new key is remembered")
	expect(_has_key("roll", KEY_R), "InputMap accepts the new key")
	expect(!_has_key("roll", KEY_SPACE), "the old key is removed")
	expect(_has_button("roll", JOY_BUTTON_B), "InputMap accepts the new pad button")
	var saved: Dictionary = save_data.bindings["roll"]
	expect(int(saved["key"]) == KEY_R, "the key is written to the save data")
	expect(int(saved["button"]) == JOY_BUTTON_B, "the pad button is written to the save data")
	_restore(snapshot)

func test_saved_bindings_load_with_defaults_for_missing_or_bad_values() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var snapshot := _snapshot()
	save_data.bindings = {"roll": {"key": KEY_R, "button": JOY_BUTTON_A},
		"melee_attack": {"key": 0, "button": 99}}
	bindings.load_from_save()
	bindings.apply()
	expect(bindings.key_for("roll") == KEY_R, "a saved key is loaded")
	expect(bindings.button_for("roll") == JOY_BUTTON_A, "a saved pad button is loaded")
	expect(bindings.key_for("left") == KEY_A, "an action missing from an old save keeps its default")
	expect(bindings.key_for("melee_attack") == KEY_J, "an invalid saved key is ignored")
	expect(bindings.button_for("melee_attack") == JOY_BUTTON_X, "an invalid saved button is ignored")
	_restore(snapshot)

func test_reset_keeps_bindings_as_a_preference() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	bindings.set_key("roll", KEY_R)
	save_data.reset()
	expect(bindings.key_for("roll") == KEY_R, "resetting progress keeps the control bindings")
	save_data.write_to_disk = old_write
	_restore(snapshot)

func test_options_panel_has_a_controls_page() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	expect(panel.controls_panel.visible, "Controls opens the controls page")
	expect(!panel.get_node("Panel").visible, "the audio page is hidden behind it")
	expect(panel.controls_panel.get_node("Panel/Rows").get_child_count() == autoload("Bindings").ACTIONS.size(),
		"every bindable action has a row")
	panel.controls_panel.back_pressed.emit()
	expect(!panel.controls_panel.visible, "Back closes the controls page")
	expect(panel.get_node("Panel").visible, "the audio page returns")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()

func test_controls_page_rows_and_labels_fit_the_panel() -> void:
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var controls := panel.controls_panel
	var host_rect := panel.get_global_rect()
	var controls_rect := controls.get_global_rect()
	expect(controls_rect.position.is_equal_approx(host_rect.position) \
		&& controls_rect.size.is_equal_approx(host_rect.size),
		"the controls page fills the options panel instead of sitting offscreen")
	var dialog_rect := (controls.get_node("Panel") as Control).get_global_rect()
	expect(host_rect.encloses(dialog_rect), "the controls dialog stays inside the options panel")
	expect(dialog_rect.has_point(host_rect.position + host_rect.size / 2.0),
		"the controls dialog is centred in the options panel")
	var dialog := controls.get_node("Panel") as Control
	var rows: VBoxContainer = controls.get_node("Panel/Rows")
	var status := controls.get_node("Panel/Status") as Control
	var reset := controls.get_node("Panel/Reset") as Control
	var back := controls.get_node("Panel/Back") as Control
	expect(rows.get_child_count() == autoload("Bindings").ACTIONS.size(), "one row per action")
	expect(rows.position.y + rows.size.y <= status.position.y + 0.01,
		"the last bind row does not overlap the status caption")
	expect(status.position.y + status.size.y <= reset.position.y + 0.01 \
		&& status.position.y + status.size.y <= back.position.y + 0.01,
		"the status caption does not overlap the buttons")
	expect(reset.position.y + reset.size.y <= dialog.size.y + 0.01 \
		&& back.position.y + back.size.y <= dialog.size.y + 0.01,
		"the buttons fit inside the dialog")
	for child: Node in rows.get_children():
		var row := child as Control
		expect(row.position.y >= -0.01 && row.position.y + row.size.y <= rows.size.y + 0.01,
			"%s sits inside the rows container" % row.name)
		for button_name: String in ["Key", "Pad"]:
			var button := row.get_node(button_name) as Button
			var font := button.get_theme_font(&"font")
			var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				button.get_theme_font_size(&"font_size")).x
			expect(text_width <= button.size.x, "%s %s label is not clipped" % [row.name, button_name])
	panel.hide()
	panel.free()

func test_capturing_a_key_and_a_pad_button_changes_the_binding() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	panel.controls_panel.start_capture("roll", "key")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_R
	key_event.pressed = true
	panel.controls_panel._input(key_event)
	expect(bindings.key_for("roll") == KEY_R, "capturing a key rebinds the action")
	expect(!panel.controls_panel.is_listening(), "the capture ends after one press")
	panel.controls_panel.start_capture("roll", "button")
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = JOY_BUTTON_B
	pad_event.pressed = true
	panel.controls_panel._input(pad_event)
	expect(bindings.button_for("roll") == JOY_BUTTON_B, "capturing a pad button rebinds the action")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_conflicting_key_is_rejected_and_escape_cancels_capture() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	bindings.set_key("roll", KEY_R)
	panel.controls_panel.start_capture("left", "key")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_R
	key_event.pressed = true
	panel.controls_panel._input(key_event)
	expect(bindings.key_for("left") == KEY_A, "a key used by another action is rejected")
	expect(panel.controls_panel.is_listening(), "the rejected capture keeps listening")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel.controls_panel.cancel_capture()
	expect(!panel.controls_panel.is_listening(), "Escape cancels the capture")
	expect(panel.controls_panel.visible, "cancelling keeps the controls page open")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_escape_closes_capture_then_controls_then_options() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var screen := _add_title_screen()
	var panel := screen.get_node("Canvas/OptionsPanel") as OptionsPanel
	(screen.get_node("Canvas/Options") as BaseButton).pressed.emit()
	panel.controls_button.pressed.emit()
	panel.controls_panel.start_capture("roll", "key")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._unhandled_input(escape)
	expect(panel.visible && panel.controls_panel.visible, "the first Escape only cancels the capture")
	expect(!panel.is_listening(), "the capture is no longer active")
	screen._unhandled_input(escape)
	expect(panel.visible && !panel.controls_panel.visible, "the second Escape returns to audio options")
	screen._unhandled_input(escape)
	expect(!panel.visible, "the third Escape closes the options panel")
	save_data.write_to_disk = old_write
	tree.root.remove_child(screen)
	screen.free()

func _add_options_panel() -> OptionsPanel:
	var packed := load("res://src/ui/menus/OptionsPanel.tscn") as PackedScene
	var panel := packed.instantiate() as OptionsPanel
	tree.root.add_child(panel)
	return panel

func _add_title_screen() -> Control:
	var packed := load("res://src/ui/menus/TitleScreen.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	tree.root.add_child(screen)
	return screen

func _snapshot() -> Dictionary:
	return (autoload("SaveData").bindings as Dictionary).duplicate(true)

func _restore(snapshot: Dictionary) -> void:
	var save_data := autoload("SaveData")
	var bindings := autoload("Bindings")
	save_data.bindings = snapshot
	bindings.load_from_save()
	bindings.apply()

func _has_key(action: String, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey && (event as InputEventKey).keycode == keycode:
			return true
	return false

func _has_button(action: String, button_index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton && (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false
