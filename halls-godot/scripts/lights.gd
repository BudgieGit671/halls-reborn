extends Node2D   # if your Lights node is a plain Node, change this to "extends Node"

@export_range(0.0, 1.0) var unpowered_light := 0.0
@export_range(0.0, 1.0) var unpowered_sprite := 0.3
@export var powered_time := Vector2(0.05, 0.2)
@export var unpowered_time := Vector2(0.1, 0.2)
@export var max_desync := 0.12
@export var break_sounds: Array[AudioStream] = []   # spark / pop / glass sounds
@export_range(0.0, 1.0) var broken_sprite := 0.15   # how dark a broken lamp looks
@export var broken_texture: Array[Texture2D] = []               # optional: swap the lamp to a smashed version

var room_index := 0
# --- sounds (drag audio files into these in the Inspector) ---
@export var sounds_off: Array[AudioStream] = []   # played when a lamp cuts out
@export var sounds_on: Array[AudioStream] = []    # played when a lamp comes back
@export var sound_volume_db := -5.0
@export var sound_range := 1500.0                 # pixels; beyond this it's silent

var lamps: Array = []
var powered := true
var timer := 0.0
var was_flickering := false
var restore_tween: Tween
var dark_room := false

func _ready():
	room_index = gameManager.current_room_index   # already correct when the room loads
	gameManager.light_broken.connect(_on_light_broken)

	var id = 0
	for light in find_children("*", "PointLight2D", true, false):
		var sprite = light.get_parent()
		var lamp = {"light": light, "base_energy": light.energy, "level": 1.0, "delay": -1.0,
				"broken": false}
		if sprite != self:
			lamp["sprite"] = sprite
			lamp["base_modulate"] = sprite.modulate

		var speaker = AudioStreamPlayer2D.new()
		speaker.volume_db = sound_volume_db
		speaker.max_distance = sound_range
		light.add_child(speaker)
		lamp["speaker"] = speaker

		lamps.append(lamp)

		# already broken by Whisk earlier? start dead, silently
		if gameManager.is_light_broken(room_index, id):
			break_lamp(lamp, false)
		id += 1
	dark_room = gameManager.get_event(room_index) == "Dark"
	if dark_room:
		for lamp in lamps:
			set_lamp(lamp, 0.0)   # unpowered look, no light

func _process(delta):
	if dark_room:
		return   # lamps stay dead, no flickering
	if gameManager.lights_flickering:
		if not was_flickering:
			was_flickering = true
			timer = 0.0
			if restore_tween:
				restore_tween.kill()
		timer -= delta
		if timer <= 0.0:
			powered = not powered
			for lamp in lamps:
				lamp["target"] = 1.0 if powered else 0.0
				lamp["delay"] = randf_range(0.0, max_desync)
			var range_to_use = powered_time if powered else unpowered_time
			timer = randf_range(range_to_use.x, range_to_use.y)

		for lamp in lamps:
			if lamp["delay"] >= 0.0:
				lamp["delay"] -= delta
				if lamp["delay"] < 0.0:
					set_lamp(lamp, lamp["target"])
					if not lamp["broken"]:
						play_flicker_sound(lamp, lamp["target"] > 0.5)   # NEW
	elif was_flickering:
		was_flickering = false
		powered = true
		for lamp in lamps:
			lamp["delay"] = -1.0
			lamp["start"] = lamp["level"]
		restore_tween = create_tween()
		restore_tween.tween_method(restore_step, 0.0, 1.0, 0.4)

func restore_step(progress: float):
	for lamp in lamps:
		set_lamp(lamp, lerp(lamp["start"], 1.0, progress))

# Plays a random sound from the matching list, from this lamp's position
func play_flicker_sound(lamp: Dictionary, turning_on: bool):
	var pool = sounds_on
	if pool.is_empty():
		return
	var speaker: AudioStreamPlayer2D = lamp["speaker"]
	speaker.stream = pool.pick_random()
	speaker.pitch_scale = randf_range(0.9, 1.1)   # slight variation so lamps don't sound identical
	speaker.play()

func set_lamp(lamp: Dictionary, amount: float):
	if lamp["broken"]:
		return
	lamp["level"] = amount
	lamp["light"].energy = lamp["base_energy"] * lerp(unpowered_light, 1.0, amount)
	if lamp.has("sprite"):
		var s = lerp(unpowered_sprite, 1.0, amount)
		var base: Color = lamp["base_modulate"]
		lamp["sprite"].modulate = Color(base.r * s, base.g * s, base.b * s, base.a)

func _on_light_broken(room: int, lamp_id: int):
	if room == room_index and lamp_id < lamps.size():
		break_lamp(lamps[lamp_id], true)

func break_lamp(lamp: Dictionary, with_sound: bool):
	if lamp["broken"]:
		return
	lamp["broken"] = true
	lamp["light"].energy = 0.0
	lamp["delay"] = -1.0

	if lamp.has("sprite"):
		var sprite = lamp["sprite"]
		var base: Color = lamp["base_modulate"]

		if sprite is AnimatedSprite2D and sprite.sprite_frames \
				and sprite.sprite_frames.has_animation("off"):
			# your own design: play the "broken" animation, keep the original color
			sprite.play("off")
			sprite.modulate = base
		elif sprite is Sprite2D and broken_texture:
			# plain Sprite2D with a shared broken texture
			sprite.texture = broken_texture
			sprite.modulate = base
		else:
			# no broken design found: just darken the lamp
			var s = broken_sprite
			sprite.modulate = Color(base.r * s, base.g * s, base.b * s, base.a)

	if with_sound and not break_sounds.is_empty():
		var speaker: AudioStreamPlayer2D = lamp["speaker"]
		speaker.stream = break_sounds.pick_random()
		speaker.pitch_scale = randf_range(0.8, 1.2)
		speaker.play()
