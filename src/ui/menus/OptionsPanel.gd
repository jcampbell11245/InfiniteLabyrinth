extends Control
class_name OptionsPanel

# Shared audio settings panel for the title and pause menus. Sliders write through
# SaveData, so a change made during a run is kept for the next one too. The parent menu
# decides when to show the panel and handles Back through the signal.

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
func refresh() -> void:
	music_slider.value = SaveData.music_volume * VOLUME_PERCENT
	sfx_slider.value = SaveData.sfx_volume * VOLUME_PERCENT

func focus_first() -> void:
	music_slider.grab_focus()

func _on_music_volume_changed(value: float) -> void:
	SaveData.set_music_volume(value / VOLUME_PERCENT)
	SaveData.save()

func _on_sfx_volume_changed(value: float) -> void:
	SaveData.set_sfx_volume(value / VOLUME_PERCENT)
	SaveData.save()
