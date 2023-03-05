<!-- Auto-generated from JSON by GDScript docs maker. Do not edit this document directly. -->

# Boss.gd

**Extends:** [KinematicBody2D](../KinematicBody2D)

## Description

## Constants Descriptions

### Fireball

```gdscript
const Fireball: PackedScene = preload("res://src/entities/Laser.tscn")
```

## Property Descriptions

### speed

```gdscript
export var speed: float = 0
```

### attack\_speed

```gdscript
export var attack_speed: float = 0
```

### knockback\_speed

```gdscript
export var knockback_speed: float = 0
```

### damage

```gdscript
export var damage: float = 0
```

### health

```gdscript
export var health: float = 0
```

### slash\_length

```gdscript
export var slash_length: int = 0
```

### attack\_cooldown\_length

```gdscript
export var attack_cooldown_length: float = 0
```

### direction

```gdscript
var direction
```

### knockback

```gdscript
var knockback
```

### critical\_chance

```gdscript
var critical_chance
```

### mode

```gdscript
var mode
```

### player

```gdscript
var player
```

### animator

```gdscript
var animator
```

### attack\_cooldown

```gdscript
var attack_cooldown
```

### hitbox

```gdscript
var hitbox
```

### hurtbox

```gdscript
var hurtbox
```

### invincibility\_cooldown

```gdscript
var invincibility_cooldown
```

### coins

```gdscript
var coins
```

### overworld

```gdscript
var overworld
```

## Method Descriptions

### animate

```gdscript
func animate()
```

Animates the enemy

### attack

```gdscript
func attack()
```

Called when the enemy attacks

### shoot\_fireball

```gdscript
func shoot_fireball()
```

Spawns a fireball at the enemy

### take\_damage

```gdscript
func take_damage(direction)
```

Called when the enemy takes damage

### die

```gdscript
func die()
```

Called when the enemy dies