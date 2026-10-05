extends Node2D

var speed: float = 1000.0
var path_points: PackedVector2Array = []
var current_point: int = 0
var is_jumpscaring: bool = false
var is_in_player_room: bool = false
@onready var raycast = $RayCast2D
@onready var idle_sound_far = $IdleSoundFar
@onready var idle_sound_close = $IdleSoundClose
@onready var sprite = $WhiskFace
#@onready var effect = get_tree().get_nodes_in_group("effect")
func _ready():
	# start hidden and inactive
	sprite.visible = false
	global_position = Vector2(-2000, 128)
	idle_sound_far.play()
	update_sound_volume()

func set_path(path2d: Path2D):
	path_points = path2d.curve.get_baked_points()
	gameManager.entity_active = true
	if path_points.size() > 0:
		global_position = path_points[0]

func _physics_process(delta):
	if is_jumpscaring:
		return
	update_sound_volume()
	
	if not gameManager.entity_active or path_points.is_empty() or is_jumpscaring:
		return
	if not gameManager.invincible:
		# check if player is visible
		check_for_player()
	if current_point >= path_points.size():
		return
	var target = path_points[current_point]
	var direction = (target - global_position).normalized()
	global_position += direction * speed * delta
	if global_position.distance_to(target) < 100.0:
		current_point += 1

func check_for_player():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# point the raycast toward the player in local space
	raycast.target_position = to_local(player.global_position)
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit and hit.is_in_group("player"):
			if not hit.is_hiding:
				trigger_jumpscare(hit)

func update_sound_volume():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# get distance between entity and player
	var distance = global_position.distance_to(player.global_position)
	# convert distance to volume
	# closer = louder, further = quieter
	# adjust these values to taste
	var min_distance1 = 200.0   # closer than this = max volume
	var max_distance1 = 3000.0  # further than this = silent
	var min_distance2 = 200.0   # closer than this = max volume
	var max_distance2 = 1500.0  # further than this = silent
	# clamp distance between min and max
	var t1 = clamp(distance, min_distance1, max_distance1)
	var t2 = clamp(distance, min_distance2, max_distance2)
	# convert to a 0.0 - 1.0 range
	# 0.0 = close, 1.0 = far
	t1 = (t1 - min_distance1) / (max_distance1 - min_distance1)
	t2 = (t2 - min_distance2) / (max_distance2 - min_distance2)
	# convert to decibels
	# 0db = full volume, -80db = silent
	idle_sound_far.volume_db = lerp(10.0, -10.0, t1)
	idle_sound_close.volume_db = lerp(0.0, -80.0, t2)

func trigger_jumpscare(player):
	is_jumpscaring = true
	gameManager.entity_active = false
	player.set_physics_process(false)
	$JumpscareSound.play()
	var tween = create_tween()
	tween.tween_property(self, "global_position", player.global_position, 0.15)
	await tween.finished
	get_tree().get_root().get_node("Game").trigger_jumpscare()
	
func enter_player_room(path2d: Path2D):
	is_in_player_room = true
	sprite.visible = true
	$WhiskEffect1.propagate_call("show")
	$WhiskEffect1.propagate_call("play",["idle"])
	gameManager.entity_active = true
	path_points = path2d.curve.get_baked_points()
	current_point = 0
	idle_sound_close.play()
	idle_sound_far.play()
	# debug prints
	print("path has ", path_points.size(), " points")
	if path_points.size() > 0:
		print("first point: ", path_points[0])
		print("entity position: ", global_position)
		global_position = path_points[0]
		print("entity moved to: ", global_position)

func leave_player_room():
	is_in_player_room = false
	sprite.visible = false
	$WhiskEffect1.propagate_call("hide")
	$WhiskEffect1.propagate_call("stop")
	gameManager.entity_active = false
	path_points = []
	current_point = 0
	global_position = Vector2(-99999, -99999)
