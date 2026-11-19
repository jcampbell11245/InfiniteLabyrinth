extends "res://tools/tests/test_case.gd"

# The title screen's Options button uses the same sprites as Start and Quit, and its
# options panel can be closed and navigated with a controller as well as a keyboard.

func test_title_options_button_uses_sprites() -> void:
	var screen := _add_title_screen()
	var button := screen.get_node("Canvas/Options")
	expect(button is TextureButton, "the title Options button is a textured button")
	if button is TextureButton:
		expect((button as TextureButton).texture_normal != null, "the Options button has a normal sprite")
		expect((button as TextureButton).texture_focused != null, "the Options button has a focused sprite")
	_free_screen(screen)

func test_title_buttons_have_vertical_gaps() -> void:
	var screen := _add_title_screen()
	var start := screen.get_node("Canvas/Start") as Control
	var options := screen.get_node("Canvas/Options") as Control
	var quit := screen.get_node("Canvas/Quit") as Control
	expect(options.position.y - (start.position.y + start.size.y) >= 8.0,
		"START and OPTIONS have a gap between them")
	expect(quit.position.y - (options.position.y + options.size.y) >= 8.0,
		"OPTIONS and QUIT have a gap between them")
	_free_screen(screen)

func test_title_options_cancel_and_focus_recovery() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var screen := _add_title_screen()
	var panel := screen.get_node("Canvas/OptionsPanel")
	var options_button := screen.get_node("Canvas/Options") as BaseButton
	options_button.pressed.emit()
	expect(panel.visible, "pressing Options opens the panel")
	# A click on the background can leave nothing focused; the next navigation key must
	# land inside the open panel rather than on the hidden Start button.
	var focused := screen.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	screen._unhandled_input(down)
	expect(panel.get_node("Panel/MusicSlider") == screen.get_viewport().gui_get_focus_owner(),
		"focus returns to the open panel")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	screen._unhandled_input(back)
	expect(!panel.visible, "the controller's cancel button closes the title options")
	save_data.write_to_disk = old_write
	_free_screen(screen)

func _add_title_screen() -> Control:
	var packed := load("res://src/ui/menus/TitleScreen.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	tree.root.add_child(screen)
	return screen

func _free_screen(screen: Control) -> void:
	tree.root.remove_child(screen)
	screen.free()
