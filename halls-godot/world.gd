extends Node2D

@onready var player = $Player
@onready var camera = $Player/Camera2D
@onready var fade_rect = $FadeOverlay/FadeRect
@onready var jumpscare_idle = $Player/Camera2D/JumpscareOverlay/WhiskIdle
@onready var jumpscare_sound = $Player/Camera2D/JumpscareOverlay/JumpscareSound
@onready var jumpscare_background = $Player/Camera2D/JumpscareOverlay/JumpscareBackground

# ---------- ROOM GENERATION ----------
@export var start_room: PackedScene                 # room 000, always the same
@export var room_scenes: Array[PackedScene] = []    # pool of random rooms

# Remembers which room scene belongs to which room number, e.g. { 1: room_a, 2: room_c }
var room_layout := {}
var path_cache := {}     # remembers each room scene's Whisk path points

var current_instance = null
var is_transitioning = false
var entity_instance = null      # null until Whisk's event starts

const ENTITY_SCENE = preload("res://whisk.tscn")
# Distance between room origins. Make it a bit bigger than your widest room.
const ROOM_SPACING := 3000.0

const DEATH_SCREEN = preload("res://scenes/death_screen.tscn")
@export var main_menu_path := "res://main_menu.tscn"   # change this to your menu scene's path

func get_room_offset(index: int) -> Vector2:
	return Vector2(index * ROOM_SPACING, 0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Player/Camera2D/JumpscareOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	$Player/Camera2D/JumpscareOverlay/WhiskScare.process_mode = Node.PROCESS_MODE_ALWAYS
	$Player/Camera2D/JumpscareOverlay/WhiskIdle.process_mode = Node.PROCESS_MODE_ALWAYS
	$Player/Camera2D/JumpscareOverlay/JumpscareSound.process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect.modulate.a = 0.0
	jumpscare_idle.visible = false
	gameManager.door_opened.connect(on_door_opened)
	gameManager.entity_started.connect(spawn_entity)

	if start_room == null or room_scenes.is_empty():
		push_error("Fill in start_room and room_scenes in the Inspector!")
		return

	load_room(0, "SpawnLeft")

# ---------- ROOM GENERATION ALGORITHM ----------

# Picks randomly the FIRST time an index is reached, then always returns the same room
func get_room_scene(index: int) -> PackedScene:
	if index == 0:
		return start_room
	if not room_layout.has(index):
		room_layout[index] = pick_new_room(index)
	return room_layout[index]

# Random room, but never the same one twice in a row
func pick_new_room(index: int) -> PackedScene:
	var previous = room_layout.get(index - 1)   # null if there isn't one
	var choice = room_scenes.pick_random()
	if room_scenes.size() > 1:
		while choice == previous:
			choice = room_scenes.pick_random()
	return choice

# Swaps the current room for a new one
func load_room(index: int, spawn_name: String):
	if is_transitioning:
		return
	is_transitioning = true
	await fade_out()

	if is_instance_valid(entity_instance):
		entity_instance.set_loaded_room(-1)

	if current_instance:
		current_instance.queue_free()
	current_instance = get_room_scene(index).instantiate()
	current_instance.position = get_room_offset(index)   # NEW: place the room in the world
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

	# may start Whisk's event (which creates Whisk through the signal)
	gameManager.on_room_changed(gameManager.current_room_index)

	# tell Whisk which room is on screen; it shows itself if it's in that room
	if is_instance_valid(entity_instance):
		entity_instance.set_loaded_room(gameManager.current_room_index)

	await fade_in()
	is_transitioning = false

# Called by gameManager.door_opened (emitted from door.gd)
func on_door_opened(direction: String):
	if is_transitioning:
		return
	player.sfx_door_open.play()
	var new_index = gameManager.current_room_index
	if direction == "right":
		new_index += 1
	else:
		new_index -= 1
	if new_index < 0:
		return   # no room before room 0

	# update the index BEFORE loading, so the new doors' labels are correct
	gameManager.current_room_index = new_index

	# came through a right door -> appear on the left side of the new room
	var spawn_name = "SpawnLeft" if direction == "right" else "SpawnRight"
	load_room(new_index, spawn_name)

# ---------- ENTITY ----------

func spawn_entity():
	if is_instance_valid(entity_instance):
		return
	entity_instance = ENTITY_SCENE.instantiate()
	add_child(entity_instance)
	entity_instance.path_provider = get_entity_path
	entity_instance.caught_player.connect(trigger_jumpscare)
	entity_instance.begin()

# Returns the path points of ANY room, even one that isn't loaded
func get_entity_path(index: int) -> PackedVector2Array:
	var scene = get_room_scene(index)
	# the cache holds the room's own (local) points; they never change
	if not path_cache.has(scene):
		var points := PackedVector2Array()
		var temp = scene.instantiate()   # temporary copy, never added to the game
		var path = temp.get_node_or_null("EntityPath")
		if path:
			for p in path.curve.get_baked_points():
				points.append(path.transform * p)
		temp.free()
		path_cache[scene] = points

	# move the points to where this room sits in the world
	var offset = get_room_offset(index)
	var result := PackedVector2Array()
	for p in path_cache[scene]:
		result.append(p + offset)
	return result

# ---------- JUMPSCARE ----------

func trigger_jumpscare(killer: String = "Whisk"):
	# block doors while the death screen is up
	is_transitioning = true

	get_tree().paused = true
	await play_jumpscare()
	get_tree().paused = false
	jumpscare_idle.visible = false

	# the death screen fades in OVER the game, so there's no fade_out() here anymore
	var screen = DEATH_SCREEN.instantiate()
	add_child(screen)
	screen.show_death(killer, gameManager.max_room_reached)   # read BEFORE reset_run()
	var choice = await screen.choice_made                      # waits for a button press

	# cover the screen with black so the reset isn't visible, then remove the death screen
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	screen.queue_free()

	# clean up the old run
	if is_instance_valid(entity_instance):
		entity_instance.queue_free()
		entity_instance = null
	gameManager.reset_run()
	room_layout.clear()

	match choice:
		"play_again":
			player.set_physics_process(true)
			is_transitioning = false
			load_room(0, "SpawnLeft")
		"main_menu":
			get_tree().change_scene_to_file(main_menu_path)
		"quit":
			get_tree().quit()

func play_jumpscare():
	jumpscare_background.visible = true
	jumpscare_idle.scale = Vector2(0.5, 0.5)
	jumpscare_background.visible = true
	await get_tree().create_timer(1).timeout
	$Player/Camera2D/JumpscareOverlay/WhiskIdle.visible = true
	await get_tree().create_timer(2).timeout
	jumpscare_idle.scale = Vector2(1.0, 1.0)
	await get_tree().create_timer(2).timeout
	$Player/Camera2D/JumpscareOverlay/WhiskIdle.visible = false
	$Player/Camera2D/JumpscareOverlay/WhiskScare.visible = true

	jumpscare_sound.play()

	var scare_tween = create_tween()
	scare_tween.set_parallel(true)
	scare_tween.tween_property($Player/Camera2D/JumpscareOverlay/WhiskScare, "scale", Vector2(100.0, 100.0), 0.4)
	scare_tween.tween_property($Player/Camera2D/JumpscareOverlay/WhiskScare, "modulate", Color(16.917, 14.04, 14.04, 1.0), 0.6)
	await scare_tween.finished

	await jumpscare_sound.finished

# ---------- FADES ----------

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
