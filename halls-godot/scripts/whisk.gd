extends Node2D

signal caught_player

@export var speed: float = 1000.0

# How far each sound can be heard, in pixels
@export var far_sound_range: float = 12000.0
@export var close_sound_range: float = 800.0

# Low-pass filter: sounds above this frequency are cut. Lower = more muffled.
@export var muffled_hz: float = 4000.0   # Whisk is in another room
const CLEAR_HZ := 20500.0                # Whisk is in the player's room
const MUFFLE_BUS := "WhiskMuffle"

# The main scene fills this in: a function that takes a room number and returns its path points
var path_provider: Callable

var path_points: PackedVector2Array = []
var current_point: int = 0
var is_jumpscaring: bool = false

var loaded_room: int = -1            # the room on screen (-1 = swapping)
var is_in_player_room: bool = false  # true when Whisk is in that room

var muffle_filter: AudioEffectLowPassFilter
var muffle_tween: Tween

@onready var raycast = $RayCast2D
@onready var idle_sound_far = $IdleSoundFar      # must be AudioStreamPlayer2D
@onready var idle_sound_close = $IdleSoundClose  # must be AudioStreamPlayer2D
@onready var sprite = $WhiskFace

func _ready():
	setup_sound()
	set_visual(false)

func setup_sound():
	# Create the muffle bus once; it stays alive in the audio server
	var bus = AudioServer.get_bus_index(MUFFLE_BUS)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, MUFFLE_BUS)
		AudioServer.set_bus_send(bus, "Master")
		AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
	muffle_filter = AudioServer.get_bus_effect(bus, 0)
	muffle_filter.cutoff_hz = muffled_hz   # Whisk always starts in another room

	idle_sound_far.bus = MUFFLE_BUS
	idle_sound_far.max_distance = far_sound_range
	idle_sound_close.bus = MUFFLE_BUS
	idle_sound_close.max_distance = close_sound_range

	# the far sound plays the whole time Whisk exists
	idle_sound_far.play()

# Smoothly muffles or clears the sound
func set_muffled(muffled: bool):
	if muffle_tween:
		muffle_tween.kill()
	muffle_tween = create_tween()
	var target = muffled_hz if muffled else CLEAR_HZ
	muffle_tween.tween_property(muffle_filter, "cutoff_hz", target, 0.3)

# Called once by the main scene right after Whisk is created
func begin():
	start_room_path()
	refresh_visibility()

# Loads the path of the room Whisk is currently in
func start_room_path():
	path_points = path_provider.call(gameManager.entity_room_index)
	current_point = 0
	if path_points.size() > 0:
		global_position = path_points[0]

# ---------- MOVEMENT ----------

func _physics_process(delta):
	if is_jumpscaring:
		return

	# finished this room's path (or the room has no path): move on
	if current_point >= path_points.size():
		finish_room()
		return

	# walk toward the next point (runs in EVERY room, loaded or not)
	var target = path_points[current_point]
	var direction = (target - global_position).normalized()
	global_position += direction * speed * delta
	if global_position.distance_to(target) < 100.0:
		current_point += 1

	# only look for the player if they can actually see this room
	if is_in_player_room and not gameManager.invincible:
		check_for_player()

func finish_room():
	# reached or passed the player's room -> the rush is over
	if gameManager.entity_room_index >= gameManager.current_room_index:
		finish_event()
		return
	# otherwise continue into the next room
	gameManager.entity_room_index += 1
	start_room_path()
	refresh_visibility()

func check_for_player():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	raycast.target_position = to_local(player.global_position)
	raycast.force_raycast_update()   # check right now instead of next frame
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit and hit.is_in_group("player"):
			if not hit.is_hiding:
				trigger_jumpscare(hit)

# ---------- VISIBILITY ----------

# The main scene calls this after a room loads (and with -1 when a swap starts)
func set_loaded_room(index: int):
	loaded_room = index
	refresh_visibility()

func refresh_visibility():
	var here = (loaded_room == gameManager.entity_room_index)
	if here == is_in_player_room:
		return   # nothing changed
	is_in_player_room = here
	set_visual(here)
	set_muffled(not here)

func set_visual(show_it: bool):
	sprite.visible = show_it
	if show_it:
		$WhiskEffect1.propagate_call("show")
		$WhiskEffect1.propagate_call("play", ["idle"])
		idle_sound_close.play()
	else:
		$WhiskEffect1.propagate_call("hide")
		$WhiskEffect1.propagate_call("stop")
		idle_sound_close.stop()

# ---------- ENDING ----------

func trigger_jumpscare(player):
	is_jumpscaring = true
	idle_sound_far.stop()
	idle_sound_close.stop()
	player.set_physics_process(false)
	$JumpscareSoundIdle.play()
	var tween = create_tween()
	tween.tween_property(self, "global_position", player.global_position, 0.15)
	await tween.finished
	caught_player.emit()

# Whisk finished its rush: tell the game and remove itself
func finish_event():
	gameManager.end_entity_event()
	queue_free()
