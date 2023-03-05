<!-- Auto-generated from JSON by GDScript docs maker. Do not edit this document directly. -->

# Player2D.gd

**Extends:** [KinematicBody2D](../KinematicBody2D)

## Description

## Constants Descriptions

### Arrow

```gdscript
const Arrow: PackedScene = preload("res://src/entities/Arrow.tscn")
```

Arrow tscn file

## Property Descriptions

### animator

```gdscript
var animator
```

Player's animated sprite

### hurtbox

```gdscript
var hurtbox
```

Player's hurtbox

### hitbox

```gdscript
var hitbox
```

Player's hitbox

### shoot\_cooldown

```gdscript
var shoot_cooldown
```

Cooldown to when the player can shoot again

### invincibility\_cooldown

```gdscript
var invincibility_cooldown
```

Cooldown to when the player can get hit again

### level\_countdown

```gdscript
var level_countdown
```

Countdown for how long the player has to clear the level

### respawn\_cooldown

```gdscript
var respawn_cooldown
```

The cooldown until the player respawns from falling in a pitfall

### hearts

```gdscript
var hearts
```

Player's hearts

### level\_countdown\_text

```gdscript
var level_countdown_text
```

The visual level countdown

### respawn\_x

```gdscript
var respawn_x
```

### respawn\_y

```gdscript
var respawn_y
```

### health

```gdscript
var health
```

Player's health

### speed

```gdscript
var speed
```

Speed in pixels/sec

### current\_room

```gdscript
var current_room
```

### direction

```gdscript
var direction
```

Direction the player is facing

### velocity

```gdscript
var velocity
```

Player's velocity vector

### knockback

```gdscript
var knockback
```

Player's knockback vector

### last\_tile

```gdscript
var last_tile
```

### last\_velocity

```gdscript
var last_velocity
```

### transitioning

```gdscript
var transitioning
```

### transitioned

```gdscript
var transitioned
```

## Method Descriptions

### get\_input

```gdscript
func get_input()
```

### animate

```gdscript
func animate()
```

Animates the player

### collision

```gdscript
func collision()
```

Updates the collision boxes

### take\_damage

```gdscript
func take_damage(damage, direction, mute)
```

Method called when the player takes damage

### timer

```gdscript
func timer()
```

Method called every frame to update the visual timer

### die

```gdscript
func die()
```

Method called when the player dies

### set\_last\_tile

```gdscript
func set_last_tile()
```

### transition

```gdscript
func transition()
```

