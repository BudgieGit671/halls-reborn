extends Node2D

@export var stairs: StaticBody2D                      # the ramp the player climbs
@export_range(0.0, 1.0) var dim_amount := 0.55        # how dark the abandoned path gets
@export var dim_time := 0.25                          # fade duration in seconds
@export var door_up: Node2D      # the door at the top of the stairs
@export var door_down: Node2D    # the door at the end of the lower path

@onready var zone = $DecisionZone
@onready var commit_point = $CommitPoint
@onready var up_path = $UpPath
@onready var down_path = $DownPath
const SIGHT_LAYER := 128   # physics layer 8: only Whisk's raycast looks at this one
var player: Node2D = null     # the player while they're inside the decision zone
var choice := "up"            # "up" = stairs are solid, "down" = stairs are ignored
var locked := false           # true once the player has committed
var active := false           # true once the fork has been "seen": dims are shown
var stairs_layer := 1         # the stairs' original collision layer
var dim_tween: Tween

func _ready():
	# rooms inherit "always run" from the world; the fork must stop when the game pauses
	process_mode = Node.PROCESS_MODE_PAUSABLE

	stairs_layer = stairs.collision_layer
	for path in [up_path, down_path]:
		path.color = Color.BLACK
		path.modulate.a = 0.0

	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)
	var room = gameManager.current_room_index   # already correct when the room loads

	var real = gameManager.get_real_path(room)
	var wrong_door = door_down if real == "up" else door_up
	if gameManager.room_has_fake_door(room):
		wrong_door.is_fake = true      # looks real, kills you
		wrong_door.show_fake_label()
	else:
		wrong_door.lock()              # visibly unusable
	# the room is rebuilt on every visit, so restore what the player chose last time
	if gameManager.fork_choice.has(room):
		choice = gameManager.fork_choice[room]
		active = true
		apply_stairs()
		update_dims()

# Is the player past the commit line? (to the right of it)
func past_commit() -> bool:
	return player.global_position.x >= commit_point.global_position.x

func _on_zone_entered(body):
	if not body.is_in_group("player"):
		return
	player = body
	active = true
	# entering from the right means coming BACK: keep the stairs exactly as they are,
	# otherwise changing them could drop a player who is standing on them
	locked = past_commit()
	update_dims()

func _on_zone_exited(body):
	if body != player:
		return
	if past_commit():
		lock()         # walked on past the fork: the choice is final
	else:
		# walked back out of the left side: forget everything, the fork is fresh again
		locked = false
		active = false
		choice = "up"
		apply_stairs()
		update_dims()
	player = null

func _process(_delta):
	if player == null or locked:
		return

	# crossing the commit line locks the current choice
	if past_commit():
		lock()
		return

	# where is the cursor, in WORLD coordinates (it follows the camera)
	var mouse = get_global_mouse_position()
	var new_choice = choice          # the cursor in neither polygon keeps the old choice
	if cursor_in(up_path, mouse):
		new_choice = "up"
	elif cursor_in(down_path, mouse):
		new_choice = "down"

	if new_choice != choice:
		choice = new_choice
		apply_stairs()
		update_dims()

func cursor_in(path: Polygon2D, world_point: Vector2) -> bool:
	# the polygon's points are in its own local space, so convert the mouse first
	return Geometry2D.is_point_in_polygon(path.to_local(world_point), path.polygon)

# Makes the stairs solid or not by switching their collision layer
func apply_stairs():
	stairs.collision_layer = stairs_layer if choice == "up" else SIGHT_LAYER

# Fades the dark overlay in over the path that is being left behind
func update_dims():
	var up_target = dim_amount if (active and choice == "down") else 0.0
	var down_target = dim_amount if (active and choice == "up") else 0.0
	if dim_tween:
		dim_tween.kill()
	dim_tween = create_tween().set_parallel(true)
	dim_tween.tween_property(up_path, "modulate:a", up_target, dim_time)
	dim_tween.tween_property(down_path, "modulate:a", down_target, dim_time)

func lock():
	locked = true
	gameManager.fork_choice[gameManager.current_room_index] = choice
