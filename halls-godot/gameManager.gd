extends Node

signal door_opened(direction)   # a door was used (door.gd emits, main.gd listens)
signal entity_started           # Whisk's event begins (gameManager emits, main.gd listens)
signal light_broken(room_index, lamp_id)

var current_room_index: int = 0
var max_room_reached: int = 0
var invincible: bool = false

# ---------- ENTITY STATE ----------
var entity_active: bool = false
var entity_room_index: int = -3   # Whisk updates this itself as it travels

const ENTITY_SPAWN_DELAY: int = 3   # Whisk starts this many rooms behind the player

# ---------- EVENTS ----------
# events[5] == "Whisk" means "Whisk starts when you first reach room 5"
var events: Array[String] = []
var lights_flickering: bool = false
var lights_off: bool = false
var broken_lights := {}
var flicker_time_left: float = 0.0
const FLICKER_TIME := Vector2(2.0, 3.0)
const PAINTING_FOLDER := "res://raw_assets/textures/paintings/"   # change to wherever your 61 images are
var paintings: Array[Texture2D] = []
var run_seed: int = 0    # changes every run, so paintings differ between runs

# --------- MUSIC -------------
var music_player := AudioStreamPlayer.new()
var _music_tween: Tween

func _ready():
	add_child(music_player)
	generate_events()
	load_paintings()
	run_seed = randi()

func generate_events():
	events.clear()
	events.resize(100)
	place_events(3, 10)    # one Whisk somewhere in rooms 3-10
	place_events(11, 17)   # one Whisk somewhere in rooms 11-17
	events[3] = "Whisk"  # <- uncomment to test, then delete

func _process(delta):
	if flicker_time_left > 0.0:
		flicker_time_left -= delta
		if flicker_time_left <= 0.0:
			lights_flickering = false   # the lights controllers notice this and restore the power

func start_flicker():
	lights_flickering = true
	flicker_time_left = randf_range(FLICKER_TIME.x, FLICKER_TIME.y)

func is_light_broken(room: int, lamp_id: int) -> bool:
	return broken_lights.has(room) and broken_lights[room].has(lamp_id)

func break_light(room: int, lamp_id: int):
	if not broken_lights.has(room):
		broken_lights[room] = {}
	broken_lights[room][lamp_id] = true
	light_broken.emit(room, lamp_id)

# Puts one Whisk in the range, then sprinkles "Dark" rooms around it
func place_events(from_room: int, to_room: int):
	events[randi_range(from_room, to_room)] = "Whisk"
	for i in range(from_room, to_room):
		# Dark rooms only go on empty slots whose neighbours are also empty
		if events[i] == "" and events[i - 1] == "" and events[i + 1] == "":
			if randi() % 5 == 1:   # 1 in 5 chance
				events[i] = "Dark"

# Safe lookup: returns "" outside the list instead of crashing
func get_event(index: int) -> String:
	if index < 0 or index >= events.size():
		return ""
	return events[index]

# Called by the main scene every time a room finishes loading
func on_room_changed(new_index: int):
	current_room_index = new_index
	var new_record = current_room_index > max_room_reached
	if new_record:
		max_room_reached = current_room_index
	
	# start a Whisk event only the FIRST time you reach its room
	if new_record and not entity_active \
			and current_room_index >= ENTITY_SPAWN_DELAY \
			and get_event(current_room_index) == "Whisk":
		entity_active = true
		start_flicker()
		entity_room_index = current_room_index - ENTITY_SPAWN_DELAY
		entity_started.emit()

# Whisk calls this when its rush is over
func end_entity_event():
	entity_active = false
	lights_flickering = false

# Brings everything back to the start after dying
func reset_run():
	current_room_index = 0
	max_room_reached = 0
	entity_active = false
	lights_flickering = false
	flicker_time_left = 0.0
	entity_room_index = -ENTITY_SPAWN_DELAY
	broken_lights.clear()
	run_seed = randi()
	generate_events()

func is_entity_in_player_room() -> bool:
	return entity_active and entity_room_index == current_room_index

func get_entity_distance() -> int:
	return abs(current_room_index - entity_room_index)

func load_paintings():
	var names: Array[String] = []
	for file in DirAccess.get_files_at(PAINTING_FOLDER):
		# exported games list files as "x.png.import", so strip that suffix
		var clean = file.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension() in ["png", "jpg", "jpeg", "webp"] and not names.has(clean):
			names.append(clean)
	names.sort()   # folder order isn't guaranteed; sorting keeps results consistent
	for n in names:
		paintings.append(load(PAINTING_FOLDER + n))
	print("Loaded ", paintings.size(), " paintings")

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if music_player.playing and music_player.stream == stream:
		return
	if _music_tween:
		_music_tween.kill()
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()

func fade_out_music(duration: float = 3.0) -> void:
	if not music_player.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -80.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _music_tween.finished
	music_player.stop()
	music_player.volume_db = 0.0
