extends Node2D
@export var thunder_sounds: Array[AudioStream] = []
@export var menu_music: AudioStream
@onready var flash: ColorRect = $Flash
@onready var thunder: AudioStreamPlayer = $ThunderSounds
var _last_index := -1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gameManager.play_music(menu_music)
	flash.modulate.a = 0.0
	_thunder_loop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _thunder_loop() -> void:
	while true:
		await get_tree().create_timer(randf_range(10.0, 20.0)).timeout
		_strike()

func _strike() -> void:
	# Flicker: quick uneven pulses, then a slow fade out
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.7, 0.04)
	tween.tween_property(flash, "modulate:a", 0.1, 0.06)
	tween.tween_property(flash, "modulate:a", 1.0, 0.03)
	tween.tween_property(flash, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)

	_pick_random_sound()
	thunder.pitch_scale = randf_range(0.9, 1.1)
	thunder.volume_db = randf_range(-6.0, 0.0)
	
	await get_tree().create_timer(randf_range(0.2, 0.8)).timeout
	thunder.play()

func _pick_random_sound() -> void:
	if thunder_sounds.is_empty():
		return
	var index := randi() % thunder_sounds.size()
	# Avoid playing the same sound twice in a row
	if thunder_sounds.size() > 1:
		while index == _last_index:
			index = randi() % thunder_sounds.size()
	_last_index = index
	thunder.stream = thunder_sounds[index]

func _on_play_pressed() -> void:
	$ButtonPress.play()
	$"Button Manager/Play".disabled = true  # prevent double clicks
	gameManager.fade_out_music(5.0)
	get_tree().change_scene_to_file("res://game.tscn")

func _on_credits_pressed() -> void:
	$ButtonPress.play()
	get_tree().change_scene_to_file("res://credits.tscn")

func _on_quit_pressed() -> void:
	$ButtonPress.play()
	get_tree().quit()

func _on_invincible_toggled(toggled_on: bool) -> void:
	gameManager.invincible = toggled_on
