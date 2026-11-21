extends Control
class_name OptionsPanel

# Shared audio and control settings panel for the title and pause menus. Sliders change the
# buses through SaveData as they move, and the controls sub-panel changes Bindings, but the
# disk write happens once when the parent closes the panel or the window is closed with it
# open. The parent decides when to show it and handles Back through the signal.

signal back_pressed

const VOLUME_PERCENT := 100.0

@onready var music_slider: HSlider = $Panel/MusicSlider
@onready var sfx_slider: HSlider = $Panel/SfxSlider
@onready var controls_button: Button = $Panel/Controls
@onready var back_button: Button = $Panel/Back
@onready var controls_panel: ControlsPanel = $ControlsPanel

func _ready() -> void:
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	controls_button.pressed.connect(_show_controls)
	back_button.pressed.connect(back_pressed.emit)
	controls_panel.back_pressed.connect(_hide_controls)

# Reads the saved values each time so the panel matches settings changed elsewhere.
# Setting .value emits value_changed, which only updates the buses, not the save file.
func refresh() -> void:
	music_slider.value = SaveData.music_volume * VOLUME_PERCENT
	sfx_slider.value = SaveData.sfx_volume * VOLUME_PERCENT
	controls_panel.refresh()

func focus_first() -> void:
	if controls_panel.visible:
		controls_panel.focus_first()
	else:
		music_slider.grab_focus()

func is_listening() -> bool:
	return controls_panel.is_listening()

# Escape cancels a capture before it can close a menu. While Pause's key is being rebound,
# a tap of Escape binds it instead; holding it still cancels inside the controls panel.
func cancel_capture_if_listening(event: InputEvent) -> bool:
	if !controls_panel.should_cancel_with_escape(event):
		return false
	controls_panel.cancel_capture()
	return true

# Called by the hosts for Escape/B once no capture is active. Returns true when it closed the
# controls sub-panel, so the host leaves the rest of the options screen (and pause) alone.
func handle_cancel() -> bool:
	if controls_panel.visible:
		_hide_controls()
		return true
	return false

# Called by the menus when the panel closes, so all changes land in one disk write.
func save_changes() -> void:
	SaveData.save()

func _notification(what: int) -> void:
	# Closing the window never reaches the parent's Back path, so save here while open.
	if what == NOTIFICATION_WM_CLOSE_REQUEST && visible:
		save_changes()

func _show_controls() -> void:
	$Panel.hide()
	controls_panel.show()
	controls_panel.refresh()
	controls_panel.focus_first()

func _hide_controls() -> void:
	# Leaving the page must abandon a capture, whether by Back, Escape or Android go-back.
	controls_panel.stop_capture()
	controls_panel.hide()
	$Panel.show()
	controls_button.grab_focus()

func _on_music_volume_changed(value: float) -> void:
	SaveData.set_music_volume(value / VOLUME_PERCENT)

func _on_sfx_volume_changed(value: float) -> void:
	SaveData.set_sfx_volume(value / VOLUME_PERCENT)
