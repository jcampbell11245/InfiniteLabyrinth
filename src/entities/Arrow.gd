extends KinematicBody2D

var speed = 200  #Speed in pixels/sec
var velocity #Arrow's velocity vector
var direction #Direction the arrow is moving

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(_delta):
	#Sets arrow direction
	if(direction == "right"):
		$SpritePivot/Sprite.set_flip_h(true)
	elif(direction == "up"):
		$SpritePivot.rotation_degrees = 90
	elif(direction == "down"):
		$SpritePivot.rotation_degrees = 270
	
	#Moves arrow
	velocity = Vector2.ZERO
	if(direction == "right"):
		velocity = Vector2(1, 0)
	elif(direction == "left"):
		velocity = Vector2(-1, 0)
	elif(direction == "down"):
		velocity = Vector2(0, 1)
	elif(direction == "up"):
		velocity = Vector2(0, -1)
	velocity = velocity.normalized() * speed
	velocity = move_and_slide(velocity)

#if the arrow hits anything it disappears
func _on_Area2D_body_shape_entered(_body_id, body, _body_shape, _area_shape):
	if (body.get_rid().get_id() != get_parent().get_child(0).get_rid().get_id()):
		queue_free()
