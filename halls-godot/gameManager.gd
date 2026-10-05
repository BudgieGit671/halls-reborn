extends Node

# list of all your room template files
# add all your templates here
const ROOM_TEMPLATES = [
	#"res://rooms/RoomTemplate_A.tscn",
	#"res://rooms/RoomTemplate_B.tscn",
	#"res://rooms/RoomTemplate_C.tscn",
]
var current_room_index: int = 0
var invincible: bool = false
# tracks which room the entity is in
var entity_room_index: int = -3  # starts 3 rooms behind player
var max_room_reached: int = 0
# whether the entity has spawned yet
var entity_active: bool = false

# how many rooms the player must visit before entity spawns
const ENTITY_SPAWN_DELAY: int = 3
const ENTITY_MOVE_INTERVAL: float = 2.0
# counts how many rooms the player has visited
var rooms_visited: int = 0
var entity_timer: float = 0.0
var events: Array[String]

func _ready():
	# shuffle the random seed so rooms are different every playthrough
	randomize()
	events.resize(100)
	events[randi_range(3,10)] = "Whisk"
	for i in range(3,10):
		if events [i] == "":
			if events [i-1] == "" and events [i+1] == "":
				if randi() % 5 == 1:
					events [i] = "Dark"
	events[randi_range(10,17)] = "Whisk"
	for i in range(10,17):
		if events [i] == "":
			if events [i-1] == "" and events [i+1] == "":
				if randi() % 5 == 1:
					events [i] = "Dark"

func _process(delta):
	# only tick if entity is active and not in player room yet
	if not entity_active:
		return
	if entity_room_index == current_room_index:
		return
	entity_timer += delta
	if entity_timer >= ENTITY_MOVE_INTERVAL:
		entity_timer = 0.0
		move_entity_closer()

func move_entity_closer():
	if entity_room_index < current_room_index:
		entity_room_index += 1
	elif entity_room_index > current_room_index:
		entity_room_index -= 1
	print("entity moved to room: ", entity_room_index)
	print("player is in room: ", current_room_index)
	# tell world to spawn entity if it reached player room
	if entity_room_index == current_room_index:
		get_tree().get_root().get_node("Game").on_entity_arrived()

func get_template_for_room(index: int) -> String:
	# fixed rooms - these are always the same
	if index == 0:
		return "res://rooms/room_entrance.tscn"
	if index == 1:
		return "res://rooms/room_waiting.tscn"
	# all other rooms pick a random template from the list
	#return ROOM_TEMPLATES[randi() % ROOM_TEMPLATES.size()]
	return "res://rooms/room_waiting.tscn"

func on_room_changed(new_index: int):
	if max_room_reached < current_room_index:
		max_room_reached = current_room_index
	if not entity_active and current_room_index >= ENTITY_SPAWN_DELAY and max_room_reached == current_room_index and events[current_room_index] == "Whisk":
		entity_active = true
		entity_room_index = new_index - 3
		entity_timer = 0.0
	if entity_active:
		# if entity was in player room, despawn it
		if entity_room_index == current_room_index and new_index != current_room_index:
			get_tree().get_root().get_node("Game").leave_player_room()
		current_room_index = new_index
		# if entity already reached new room, spawn it again
		if entity_room_index == new_index:
			get_tree().get_root().get_node("Game").on_entity_arrived()

func is_entity_in_player_room() -> bool:
	return entity_active and entity_room_index == current_room_index

func get_entity_distance() -> int:
	return abs(current_room_index - entity_room_index)
