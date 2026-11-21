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
	bindings.reset_defaults()
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

func test_joypad_events_match_any_controller_device() -> void:
	var bindings := autoload("Bindings")
	var snapshot := _snapshot()
	bindings.apply()
	var found_button := false
	for event: InputEvent in InputMap.action_get_events("melee_attack"):
		if event is InputEventJoypadButton \
				&& (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			found_button = true
			expect(event.device == -1, "the sword button accepts any controller")
	var found_axis := false
	for event: InputEvent in InputMap.action_get_events("left"):
		if event is InputEventJoypadMotion \
				&& (event as InputEventJoypadMotion).axis == 0 \
				&& (event as InputEventJoypadMotion).axis_value == -1.0:
			found_axis = true
			expect(event.device == -1, "the left-stick axis accepts any controller")
	expect(found_button, "the sword button is still in InputMap")
	expect(found_axis, "the left-stick axis is still in InputMap")
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
	expect(!status.visible && (status as Label).text.is_empty(),
		"the standing 'press a key' caption is gone")
	expect((status as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"the blurb is centred above the footer buttons")
	expect(rows.position.y + rows.size.y <= status.position.y + 0.01,
		"the last bind row does not overlap the status caption")
	expect(status.position.y + status.size.y <= reset.position.y + 0.01 \
		&& status.position.y + status.size.y <= back.position.y + 0.01,
		"the status caption does not overlap the buttons")
	expect(reset.position.y + reset.size.y <= dialog.size.y + 0.01 \
		&& back.position.y + back.size.y <= dialog.size.y + 0.01,
		"the buttons fit inside the dialog")
	var key_header := controls.get_node("Panel/KeyHeader") as Control
	var pad_header := controls.get_node("Panel/PadHeader") as Control
	var first_row := rows.get_child(0) as Control
	var second_row := rows.get_child(1) as Control
	var key_column := first_row.get_node("Key") as Control
	var pad_column := first_row.get_node("Pad") as Control
	expect(second_row.position.y - (first_row.position.y + first_row.size.y) >= 4.0,
		"the bind rows are spaced out")
	expect(pad_column.position.x - (key_column.position.x + key_column.size.x) >= 8.0,
		"the keyboard and controller buttons have a horizontal gap")
	expect(absf(rows.get_global_rect().get_center().y - dialog_rect.get_center().y) < 10.0,
		"the bind list is centred vertically in the dialog")
	expect(absf(key_header.get_global_rect().get_center().x
		- key_column.get_global_rect().get_center().x) < 0.5,
		"KEYBOARD is centred over the keyboard column")
	expect(absf(pad_header.get_global_rect().get_center().x
		- pad_column.get_global_rect().get_center().x) < 0.5,
		"CONTROLLER is centred over the controller column")
	for path: String in ["Panel/Reset", "Panel/Back"]:
		var footer := controls.get_node(path) as Button
		var footer_font := footer.get_theme_font(&"font")
		var footer_width := footer_font.get_string_size(footer.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			footer.get_theme_font_size(&"font_size")).x
		expect(footer_width <= footer.size.x, "%s label is not clipped" % footer.name)
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
	autoload("Bindings").reset_defaults()
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	panel.controls_panel.start_capture("roll", "key")
	expect(panel.controls_panel.status_label.text == ControlsPanel.CANCEL_HINT \
		&& panel.controls_panel.status_label.visible,
		"starting a capture shows the Esc and hold-B hint")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_R
	key_event.pressed = true
	panel.controls_panel._input(key_event)
	expect(bindings.key_for("roll") == KEY_R, "capturing a key rebinds the action")
	expect(!panel.controls_panel.is_listening(), "the capture ends after one press")
	expect(panel.controls_panel.status_label.text.find("KEY SET TO") >= 0 \
		&& panel.controls_panel.status_label.visible,
		"capturing a key shows the confirmation blurb")
	panel.controls_panel.start_capture("roll", "button")
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad_event.pressed = true
	panel.controls_panel._input(pad_event)
	expect(bindings.button_for("roll") == JOY_BUTTON_LEFT_SHOULDER,
		"capturing a pad button rebinds the action")
	expect(panel.controls_panel.status_label.text.find("PAD SET TO") >= 0 \
		&& panel.controls_panel.status_label.visible,
		"capturing a pad button shows the confirmation blurb")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_tapping_b_binds_it_but_holding_b_cancels() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	bindings.reset_defaults()
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	var controls := panel.controls_panel
	var b_event := _cancel_button_event()
	var release := _cancel_button_event()
	release.pressed = false

	controls.start_capture("roll", "button")
	controls._input(b_event)
	expect(controls.is_listening(), "pressing B starts a hold instead of binding at once")
	controls._input(release)
	expect(bindings.button_for("roll") == JOY_BUTTON_B, "a quick tap of B binds it")
	expect(!controls.is_listening(), "the tap ends the capture")
	expect(controls.status_label.text.find("PAD SET TO B") >= 0,
		"the tap shows the pad confirmation")

	controls.start_capture("select", "button")
	controls._input(b_event)
	controls._input(release)
	expect(bindings.button_for("select") == JOY_BUTTON_A,
		"B already used by Roll is rejected for Select")
	expect(controls.is_listening(), "the conflicting tap keeps listening")

	controls.start_capture("roll", "button")
	controls._input(b_event)
	var other_pad := InputEventJoypadButton.new()
	other_pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	other_pad.pressed = true
	controls._input(other_pad)
	expect(bindings.button_for("roll") == JOY_BUTTON_B,
		"other pad input is ignored while B is held")
	_finish_pad_hold(controls)
	controls._input(release)
	expect(bindings.button_for("roll") == JOY_BUTTON_B,
		"holding B cancels without changing the binding")
	expect(!controls.is_listening(), "the hold ends the capture")
	expect(controls.status_label.text == "CAPTURE CANCELLED",
		"the hold shows the cancellation blurb")

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
	bindings.reset_defaults()
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
	expect(panel.controls_panel.status_label.text == "CAPTURE CANCELLED" \
		&& panel.controls_panel.status_label.visible,
		"cancelling a capture shows the cancellation blurb")
	expect(panel.controls_panel.visible, "cancelling keeps the controls page open")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_fixed_alternate_keys_are_reserved() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	bindings.reset_defaults()
	expect(bindings.key_owner(KEY_RIGHT) == "right", "the right arrow belongs to Move Right")
	expect(bindings.key_owner(KEY_X) == "ranged_attack", "X belongs to Bow's fixed alternate")
	expect(bindings.key_owner(KEY_J) == "melee_attack", "the shared J is reported by Sword")
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	panel.controls_panel.start_capture("left", "key")
	_send_key(panel, KEY_RIGHT)
	expect(bindings.key_for("left") == KEY_A, "a fixed alternate cannot be stolen")
	panel.controls_panel.start_capture("melee_attack", "key")
	_send_key(panel, KEY_X)
	expect(bindings.key_for("melee_attack") == KEY_J, "Bow's alternate cannot be stolen")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_shared_j_is_only_free_for_sword_and_select() -> void:
	var bindings := autoload("Bindings")
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	var snapshot := _snapshot()
	save_data.write_to_disk = false
	bindings.reset_defaults()
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	panel.controls_panel.start_capture("melee_attack", "key")
	_send_key(panel, KEY_L)
	expect(bindings.key_for("melee_attack") == KEY_L, "Sword moves off J")
	expect(bindings.key_owner(KEY_J, "ranged_attack") == "select",
		"J still belongs to Select when Sword moves away")
	bindings.set_key("ranged_attack", KEY_J)
	expect(bindings.key_owner(KEY_J, "melee_attack") == "ranged_attack",
		"an old save with Bow already on J still conflicts")
	bindings.set_key("ranged_attack", KEY_K)
	panel.controls_panel.start_capture("ranged_attack", "key")
	_send_key(panel, KEY_J)
	expect(bindings.key_for("ranged_attack") == KEY_K, "Bow cannot take the shared J")
	expect(panel.controls_panel.is_listening(), "the rejected capture keeps listening")
	panel.controls_panel.cancel_capture()
	panel.controls_panel.start_capture("melee_attack", "key")
	_send_key(panel, KEY_J)
	expect(bindings.key_for("melee_attack") == KEY_J, "Sword can take J back")
	panel.controls_panel.start_capture("select", "key")
	_send_key(panel, KEY_J)
	expect(bindings.key_for("select") == KEY_J, "Select can use its fixed alternate")
	panel.hide()
	save_data.write_to_disk = old_write
	panel.free()
	_restore(snapshot)

func test_controls_labels_use_supported_font_glyphs() -> void:
	var font := load("res://assets/fonts/8-BIT WONDER.TTF") as FontFile
	var panel := _add_options_panel()
	panel.show()
	panel.controls_button.pressed.emit()
	var controls := panel.controls_panel
	var labels: Array[String] = [
		(controls.get_node("Panel/Heading") as Label).text,
		(controls.get_node("Panel/KeyHeader") as Label).text,
		(controls.get_node("Panel/PadHeader") as Label).text,
		controls.status_label.text,
		(controls.get_node("Panel/Reset") as Button).text,
		(controls.get_node("Panel/Back") as Button).text,
	]
	for child: Node in controls.get_node("Panel/Rows").get_children():
		var row := child as Control
		for button_name: String in ["Key", "Pad"]:
			labels.append((row.get_node(button_name) as Button).text)
	controls.start_capture("roll", "key")
	expect(controls.status_label.text == ControlsPanel.CANCEL_HINT && controls.status_label.visible,
		"starting a capture shows the cancel hint")
	labels.append((controls.get_node("Panel/Rows/Row_roll/Key") as Button).text)
	labels.append(controls.status_label.text)
	controls.start_capture("roll", "button")
	labels.append((controls.get_node("Panel/Rows/Row_roll/Pad") as Button).text)
	labels.append(controls.status_label.text)
	controls.cancel_capture()
	labels.append(controls.status_label.text)
	var hint_width := font.get_string_size(ControlsPanel.CANCEL_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		controls.status_label.get_theme_font_size(&"font_size")).x
	expect(hint_width <= controls.status_label.size.x, "the cancel hint fits the blurb strip")
	for text: String in labels:
		for i in text.length():
			var codepoint := text.unicode_at(i)
			expect(font.has_char(codepoint),
				"the Controls font can draw %d in '%s'" % [codepoint, text])
	panel.hide()
	panel.free()

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

func test_controller_b_cancels_capture_then_controls_then_options() -> void:
	var save_data := autoload("SaveData")
	var bindings := autoload("Bindings")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var screen := _add_title_screen()
	var panel := screen.get_node("Canvas/OptionsPanel") as OptionsPanel
	(screen.get_node("Canvas/Options") as BaseButton).pressed.emit()
	panel.controls_button.pressed.emit()
	var controls := panel.controls_panel
	controls.start_capture("roll", "key")
	var b_event := _cancel_button_event()
	var release := _cancel_button_event()
	release.pressed = false

	controls._input(b_event)
	controls._input(release)
	expect(panel.is_listening(), "a tap of B does not cancel the capture")
	expect(controls.status_label.text == ControlsPanel.CANCEL_HINT,
		"a tap of B leaves the cancel hint up")

	controls._input(b_event)
	var old_key: int = bindings.key_for("roll")
	var other_key := InputEventKey.new()
	other_key.keycode = KEY_R
	other_key.pressed = true
	controls._input(other_key)
	expect(bindings.key_for("roll") == old_key, "a key press while B is held is ignored")
	_finish_pad_hold(controls)
	controls._input(release)
	expect(!panel.is_listening(), "holding B cancels the capture")
	expect(controls.status_label.text == "CAPTURE CANCELLED", "the hold shows the cancellation blurb")
	screen._unhandled_input(b_event)
	expect(panel.visible && !panel.controls_panel.visible, "the next B returns to audio options")
	screen._unhandled_input(b_event)
	expect(!panel.visible, "the next B closes the options panel")
	save_data.write_to_disk = old_write
	tree.root.remove_child(screen)
	screen.free()

func test_controller_b_cancels_capture_in_pause_menu() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var menu := _add_pause_menu()
	if menu == null:
		save_data.write_to_disk = old_write
		return
	menu.show_options()
	var panel := menu.options_panel
	panel.controls_button.pressed.emit()
	var controls := panel.controls_panel
	controls.start_capture("roll", "key")
	var b_event := _cancel_button_event()
	var release := _cancel_button_event()
	release.pressed = false

	controls._input(b_event)
	controls._input(release)
	expect(panel.is_listening(), "a tap of B does not cancel the pause capture")

	controls._input(b_event)
	_finish_pad_hold(controls)
	controls._input(release)
	expect(panel.visible && panel.controls_panel.visible && !panel.is_listening(),
		"holding B cancels the capture without leaving the pause controls page")
	expect(controls.status_label.text == "CAPTURE CANCELLED",
		"the pause capture shows the cancellation blurb")
	menu._input(b_event)
	expect(panel.visible && !panel.controls_panel.visible, "the next B returns to audio options")
	menu._input(b_event)
	expect(!panel.visible, "the next B closes the pause options panel")
	save_data.write_to_disk = old_write
	var layer := menu.get_parent()
	tree.root.remove_child(layer)
	layer.free()

func _add_pause_menu() -> PauseMenu:
	var packed := load("res://src/ui/menus/PauseMenu.tscn") as PackedScene
	if packed == null:
		return null
	var layer := packed.instantiate() as CanvasLayer
	tree.root.add_child(layer)
	return layer.get_node("Pause") as PauseMenu

func _cancel_button_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	return event

func _finish_pad_hold(controls: ControlsPanel) -> void:
	controls._pad_cancel_started_msec = Time.get_ticks_msec() \
		- int(ControlsPanel.PAD_CANCEL_HOLD_SECONDS * 1000.0) - 1
	controls._process(0.0)

func _send_key(panel: OptionsPanel, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	panel.controls_panel._input(event)

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
