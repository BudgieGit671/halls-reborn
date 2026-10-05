extends Node2D

@onready var player = $Player
@onready var camera = $Player/Camera2D
@onready var fade_rect = $FadeOverlay/FadeRect
@onready var jumpscare_overlay = $JumpscareOverlay/TextureRect  # your jumpscare image
@onready var jumpscare_sound = $JumpscareOverlay/JumpscareSound

var current_instance = null
var is_transitioning = false
var entity_instance = null

const ENTITY_SCENE = preload("res://whisk.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$JumpscareOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	$JumpscareOverlay/TextureRect.process_mode = Node.PROCESS_MODE_ALWAYS
	$JumpscareOverlay/JumpscareSound.process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect.modulate.a = 0.0
	# spawn entity once, keep it forever
	entity_instance = ENTITY_SCENE.instantiate()
	add_child(entity_instance)
	load_room(gameManager.get_template_for_room(0), "SpawnLeft")

func load_room(template_path: String, spawn_name: String):
	if is_transitioning:
		return
	is_transitioning = true
	await fade_out()
	entity_instance.leave_player_room()
	if current_instance:
		current_instance.queue_free()
	var scene = load(template_path)
	current_instance = scene.instantiate()
	add_child(current_instance)
	var spawn = current_instance.get_node_or_null(spawn_name)
	if spawn:
		player.global_position = spawn.global_position
	var bounds = current_instance.get_node_or_null("CameraBounds")
	if bounds:
		var top_left = bounds.get_node("TopLeft").global_position
		var bottom_right = bounds.get_node("BotRight").global_position
		camera.limit_left   = int(top_left.x)
		camera.limit_top    = int(top_left.y)
		camera.limit_right  = int(bottom_right.x)
		camera.limit_bottom = int(bottom_right.y)
	# tell gameManager the room changed
	gameManager.on_room_changed(gameManager.current_room_index)
	# spawn entity if it has caught up to the player
	if gameManager.is_entity_in_player_room():
		on_entity_arrived()
	await fade_in()
	is_transitioning = false

func on_entity_arrived():
	# dont spawn if transitioning between rooms
	if is_transitioning:
		return
	var entity_path = current_instance.get_node_or_null("EntityPath")
	if entity_path:
		entity_instance.enter_player_room(entity_path)

func trigger_jumpscare():
	# freeze the game
	get_tree().paused = true

	# start the jumpscare sequence
	await play_jumpscare()

	# unpause so fade can run
	get_tree().paused = false

	await fade_out()

	# reset everything
	jumpscare_overlay.visible = false
	gameManager.current_room_index = 0
	gameManager.entity_room_index = -3
	gameManager.entity_active = false

	# restart from beginning
	player.set_physics_process(true)
	load_room(gameManager.get_template_for_room(0), "SpawnLeft")

func play_jumpscare():
	# step 1 — show entity small and centered
	jumpscare_overlay.visible = true
	jumpscare_overlay.scale = Vector2(0.5, 0.5)
	jumpscare_overlay.modulate.a = 0.0

	# fade entity in over 0.3 seconds
	var fade_tween = create_tween()
	fade_tween.tween_property(jumpscare_overlay, "modulate:a", 1.0, 0.3)
	await fade_tween.finished

	# step 2 — hold for 1-2 seconds, building tension
	await get_tree().create_timer(1.5).timeout

	# step 3 — quickly grow and play loud sound at the same time
	jumpscare_sound.play()

	var scare_tween = create_tween()
	scare_tween.set_parallel(true)  # run both at the same time
	scare_tween.tween_property(jumpscare_overlay, "scale", Vector2(3.0, 3.0), 0.4)
	scare_tween.tween_property(jumpscare_overlay, "modulate:a", 0.0, 0.4)
	await scare_tween.finished

	# step 4 — wait for sound to finish
	await get_tree().create_timer(0.5).timeout

func on_door_opened(direction: String):
	if direction == "right":
		gameManager.current_room_index += 1
		load_room(
			gameManager.get_template_for_room(gameManager.current_room_index),
            "SpawnLeft"
		)
	elif direction == "left":
		gameManager.current_room_index -= 1
		load_room(
			gameManager.get_template_for_room(gameManager.current_room_index),
            "SpawnRight"
		)

func fade_out() -> void:
	fade_rect.visible = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished

func fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	await tween.finished
	fade_rect.visible = false
