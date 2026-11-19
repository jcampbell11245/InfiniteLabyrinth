extends Control
class_name OptionsPanel

# Shared audio settings panel for the title and pause menus. Sliders change the buses
# through SaveData as they move, but the disk write happens once when the parent closes
# the panel or the window is closed with it open. The parent decides when to show it and
# handles Back through the signal.

signal back_pressed

const VOLUME_PERCENT := 100.0

@onready var music_slider: HSlider = $Panel/MusicSlider
@onready var sfx_slider: HSlider = $Panel/SfxSlider
@onready var back_button: Button = $Panel/Back

func _ready() -> void:
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	back_button.pressed.connect(back_pressed.emit)

# Reads the saved values each time so the panel matches settings changed elsewhere.
# Setting .value emits value_changed, which only updates the buses, not the save file.
func refresh() -> void:
	music_slider.value = SaveData.music_volume * VOLUME_PERCENT
	sfx_slider.value = SaveData.sfx_volume * VOLUME_PERCENT

func focus_first() -> void:
	music_slider.grab_focus()

# Called by the menus when the panel closes, so all changes land in one disk write.
func save_changes() -> void:
	SaveData.save()

func _notification(what: int) -> void:
	# Closing the window never reaches the parent's Back path, so save here while open.
	if what == NOTIFICATION_WM_CLOSE_REQUEST && visible:
		save_changes()

func _on_music_volume_changed(value: float) -> void:
	SaveData.set_music_volume(value / VOLUME_PERCENT)

func _on_sfx_volume_changed(value: float) -> void:
	SaveData.set_sfx_volume(value / VOLUME_PERCENT)
