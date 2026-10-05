extends CharacterBody2D
@onready var sprite = $AnimatedSprite2D
const SPEED = 250
const JUMP_VELOCITY = -500.0

# Hiding
	
var is_hiding = false

func set_hidden(value: bool):
	if !velocity.y:
		is_hiding = value
		$AnimatedSprite2D.visible = !value
		$CollisionShape2D.disabled = value
		set_physics_process(!value)

# Movement

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle jump.
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		sprite.play("walk")
		sprite.flip_h = direction < 0
		velocity.x = direction * SPEED
	else:
		sprite.play("idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
