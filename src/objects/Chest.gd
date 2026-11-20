extends Node2D

# Key chest: opens the first time the player's sword hits it and releases a key that
# floats toward the player. Collecting the key adds it and extends the level timer.

const KeyPickup := preload("res://src/effects/KeyPickup.gd")

@export var direction := "down" # Which way the chest faces, an animation suffix

var open := false

func _ready() -> void:
	$AnimatedSprite2D.animation = "closed_" + direction

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_name() == "Hitbox" && !open:
		Juice.play($Open, 0.04)
		open = true
		$AnimatedSprite2D.animation = "open_" + direction
		_release_key()
		_burst_open()

# Spawns the key pickup so it can float around before being collected.
func _release_key() -> void:
	var pickup: Node2D = KeyPickup.new()
	get_parent().add_child(pickup)
	pickup.global_position = global_position

# Squash and stretch, a spray of gold and a small thump.
func _burst_open() -> void:
	var sprite: Node2D = $AnimatedSprite2D
	var base := sprite.scale
	sprite.scale = base * Vector2(1.35, 0.7)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", base * Vector2(0.85, 1.2), 0.08)
	tween.tween_property(sprite, "scale", base, 0.25) 		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Juice.burst(get_parent(), global_position, Color(1, 0.85, 0.3), 16, 90.0, Vector2.UP, 2.0, 0.5)
	Juice.hitstop(0.06)
	Juice.shake(Juice.SHAKE_LIGHT)
