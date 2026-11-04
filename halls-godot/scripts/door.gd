extends Node2D
# which direction this door goes
@export var direction: String = "right"  # set to "left" or "right" in Inspector
@export var sprite: Node2D
@export var locked_texture: Texture2D
var is_fake := false
var is_locked := false
var player_nearby = false
var tween: Tween

func _ready():
	$Prompt.visible = false
	update_room_label()

# Makes the door unusable: no label, no prompt, locked look
func lock():
	is_locked = true
	player_nearby = false
	$Label.visible = false
	$Prompt.visible = false
	stop_pulse()
	if sprite is Sprite2D and locked_texture:
		sprite.texture = locked_texture

func update_room_label():
	# calculate what room number this door leads to
	var next_room: int
	if direction == "right":
		next_room = gameManager.current_room_index + 1
	elif direction == "left":
		next_room = gameManager.current_room_index
	# display it on the door label
	# add 1 so it shows human-readable numbers starting from 1, not 0
	$Label.text = "%03d" % next_room

func show_fake_label():
	# a wrong number: next room number plus or minus a few
	var wrong = gameManager.current_room_index + 1 + [-2, -1, 1, 2].pick_random()
	$Label.text = "%03d" % max(wrong, 0)

func _on_interact_zone_body_entered(body):
	if is_locked:
		return
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
	if is_locked:
		return
	if player_nearby and event.is_action_pressed("interact"):
		if is_fake:
			gameManager.fake_door_opened.emit()
		else:
			gameManager.door_opened.emit(direction)

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
