extends KinematicBody2D

var speed = 200  #Speed in pixels/sec

var velocity = Vector2.ZERO

func _physics_process(delta):
	get_input()
	animate()
	velocity = move_and_slide(velocity)

func get_input():
	#Movement
	velocity = Vector2.ZERO
	if Input.is_action_pressed('right'):
		velocity.x += 1
	if Input.is_action_pressed('left'):
		velocity.x -= 1
	if Input.is_action_pressed('down'):
		velocity.y += 1
	if Input.is_action_pressed('up'):
		velocity.y -= 1
	velocity = velocity.normalized() * speed
	
	#Attacking
	

#Animates the player
func animate():
	var animator = $AnimatedSprite;
	
	#Reset to idle
	if Input.is_action_just_released('right'):
		animator.animation = "idle_right"
	elif Input.is_action_just_released('left'):
		animator.animation = "idle_left"
	elif Input.is_action_just_released('down'):
		animator.animation = "idle_down"
	elif Input.is_action_just_released('up'):
		animator.animation = "idle_up"
	
	#Movement
	if Input.is_action_pressed('right'):
		animator.animation = "walk_right"
	elif Input.is_action_pressed('left'):
		animator.animation = "walk_left"
	elif Input.is_action_pressed('down'):
		animator.animation = "walk_down"
	elif Input.is_action_pressed('up'):
		animator.animation = "walk_up"
