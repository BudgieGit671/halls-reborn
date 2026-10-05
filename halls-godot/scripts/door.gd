extends Node2D

# which direction this door goes
@export var direction: String = "right"  # set to "left" or "right" in Inspector

var player_nearby = false
var tween: Tween

func _ready():
	$Prompt.visible = false
	update_room_label()

func update_room_label():
	# calculate what room number this door leads to
	var next_room: int
	if direction == "right":
		next_room = gameManager.current_room_index + 1
	elif direction == "left":
		next_room = gameManager.current_room_index - 1
	# display it on the door label
	# add 1 so it shows human-readable numbers starting from 1, not 0
	if next_room < 10:
		$Label.text = str("00",next_room)
	else:
		$Label.text = str("0",next_room)

func _on_interact_zone_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		$Prompt.visible = true
		start_pulse()

func _on_interact_zone_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		$Prompt.visible = false
		stop_pulse()

func _input(event):
	if player_nearby and event.is_action_pressed("interact"):
		# tell the world to load the next room
		get_parent().get_parent().on_door_opened(direction)

func start_pulse():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_loops()
	tween.tween_property($Prompt, "modulate:a", 0.0, 0.6)
	tween.tween_property($Prompt, "modulate:a", 1.0, 0.6)

func stop_pulse():
	if tween:
		tween.kill()
	$Prompt.modulate.a = 1.0
