extends Node2D

signal attacked   # time ran out: main.gd plays the jumpscare
signal killed     # the player clicked it in time

const ATTACK_TIME := Vector2(5.0, 7.0)   # it attacks after a random time in this range (seconds)
const INTRO_TIME := 0.8                  # how long the slide-in from the top takes
@export var sound_range := 900.0     # pixels from screen center at which it goes silent
@export var pan_strength := 2.0      # how hard it pans left/right (1.0 = default, higher = more extreme)
@export var orbit_size := Vector2(300, 170)   # width and height of the oval it circles on
@export var orbit_speed := 1.5                # radians per second (6.28 = one full lap)
@export var hit_radius := 70.0                # how close the click must be, in pixels
@export var max_alpha := 1                  # how visible it gets (lower = harder to spot)
@export var center_offset := Vector2(0, -60)  # circle around the player's body, not their feet

var total_time := 4.0
var time_left := 4.0
var angle := -PI / 2      # -PI/2 = the top of the oval, so it enters from above
var direction := 1        # 1 = clockwise, -1 = counter-clockwise
var wobble := 0.0         # makes the oval breathe in and out so it's harder to predict
var intro := 0.0          # 0 -> 1 during the slide-in
var start_pos := Vector2.ZERO
var done := false
var appear_sound: AudioStreamPlayer2D
var death_sound: AudioStreamPlayer2D

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE

	total_time = randf_range(ATTACK_TIME.x, ATTACK_TIME.y)
	time_left = total_time
	direction = 1 if randf() < 0.5 else -1

	# NEW: start at a random point on the upper half of the oval, so it can appear left OR right
	angle = randf_range(-PI * 0.85, -PI * 0.15)
	start_pos = Vector2(get_center().x + cos(angle) * orbit_size.x, -150.0)
	position = start_pos
	modulate.a = 0.0

	setup_sound()

func setup_sound():
	appear_sound = $AppearSound
	death_sound = $DeathSound
	make_world_sound(appear_sound)
	make_world_sound(death_sound)
	update_sound_position()
	appear_sound.play()   # the death sound waits until Murk is clicked

# Moves a speaker out of the screen layer and into the world, where the "listener" (camera) is
func make_world_sound(speaker: AudioStreamPlayer2D):
	speaker.reparent(get_tree().current_scene)
	speaker.process_mode = Node.PROCESS_MODE_PAUSABLE   # silent during the jumpscare pause
	speaker.max_distance = sound_range
	speaker.attenuation = 0.6
	speaker.panning_strength = pan_strength
	# the speaker outlives Murk, so it deletes itself when its sound ends
	speaker.finished.connect(speaker.queue_free)

# Turns Murk's position on the SCREEN into a position in the WORLD, and puts both speakers there
func update_sound_position():
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * position
	if is_instance_valid(appear_sound):
		appear_sound.global_position = world_pos
	if is_instance_valid(death_sound):
		death_sound.global_position = world_pos


# The player's position ON THE SCREEN (not in the world)
func get_center() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return get_viewport_rect().size / 2.0
	# the canvas transform is how the camera turns world positions into screen positions
	return get_viewport().get_canvas_transform() * player.global_position + center_offset

func _process(delta):
	update_sound_position()
	if done:
		return
	time_left -= delta
	if time_left <= 0.0:
		attack()
		return
	# it speeds up by up to 40% as the deadline gets closer
	var urgency = 1.0 + (1.0 - time_left / total_time) * 0.4
	angle += direction * orbit_speed * urgency * delta
	# cos/sin turn an angle into a point on a circle; different x/y sizes make it an oval
	wobble += delta
	var radius = orbit_size * (1.0 + 0.2 * sin(wobble * 2.3))
	var orbit_pos = get_center() + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
	# slide in from the top: blend from the start position to the orbit, easing out
	intro = min(intro + delta / INTRO_TIME, 1.0)
	var t = 1.0 - pow(1.0 - intro, 3.0)
	position = start_pos.lerp(orbit_pos, t)
	modulate.a = intro * max_alpha   # fades in slowly

func _input(event):
	if done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# position of the mouse in this layer's coordinates (the same space Murk is in)
		if get_global_mouse_position().distance_to(global_position) <= hit_radius * scale.x:
			get_viewport().set_input_as_handled()
			die()

func die():
	done = true
	killed.emit()

	# cut the appear sound (stop() doesn't emit "finished", so free it manually)
	if is_instance_valid(appear_sound):
		appear_sound.queue_free()

	# the death sound is already in the world, so it keeps playing after Murk is gone.
	# It stays where Murk died, since update_sound_position() stops running.
	death_sound.pitch_scale = randf_range(0.95, 1.05)
	death_sound.play()

	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 0.3, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()   # no need to wait for the sound anymore

func attack():
	if is_instance_valid(appear_sound):
		appear_sound.queue_free()
	done = true
	# lunge at the player, then tell the game
	var tween = create_tween()
	tween.tween_property(self, "position", get_center(), 0.15)
	tween.parallel().tween_property(self, "scale", scale * 2.0, 0.15)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.15)
	await tween.finished
	attacked.emit()
