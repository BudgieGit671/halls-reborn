extends Node2D   # if your Lights node is a plain Node, change this to "extends Node"

@export_range(0.0, 1.0) var unpowered_light := 0.0
@export_range(0.0, 1.0) var unpowered_sprite := 0.3
@export var powered_time := Vector2(0.05, 0.2)
@export var unpowered_time := Vector2(0.1, 0.2)
@export var max_desync := 0.12

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

func _ready():
	for light in find_children("*", "PointLight2D", true, false):
		var sprite = light.get_parent()
		var lamp = {"light": light, "base_energy": light.energy, "level": 1.0, "delay": -1.0}
		if sprite != self:
			lamp["sprite"] = sprite
			lamp["base_modulate"] = sprite.modulate

		# one speaker per lamp, attached to the light so it sits at the lamp's position
		var speaker = AudioStreamPlayer2D.new()
		speaker.volume_db = sound_volume_db
		speaker.max_distance = sound_range
		light.add_child(speaker)
		lamp["speaker"] = speaker

		lamps.append(lamp)

func _process(delta):
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
	lamp["level"] = amount
	lamp["light"].energy = lamp["base_energy"] * lerp(unpowered_light, 1.0, amount)
	if lamp.has("sprite"):
		var s = lerp(unpowered_sprite, 1.0, amount)
		var base: Color = lamp["base_modulate"]
		lamp["sprite"].modulate = Color(base.r * s, base.g * s, base.b * s, base.a)
