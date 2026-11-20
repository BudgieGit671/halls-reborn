extends PointLight2D

@onready var player = get_parent()
var is_on := false

func _ready():
	enabled = false
	gameManager.flashlight_pressed.connect(_on_flashlight_pressed)

# R key: swap in a battery
func _unhandled_input(event):
	if event.is_action_pressed("reload_flashlight"):
		use_battery()

func can_use() -> bool:
	return gameManager.has_flashlight and not player.is_hiding

func _on_flashlight_pressed():
	if is_on:
		turn_off()
	elif can_use() and gameManager.flashlight_charge > 0.0:
		turn_on()

func _process(delta):
	if not is_on:
		return    # nothing to do while off, so no per-frame work or signal spam

	# hid in a closet, or the flashlight was removed: switch off
	if not can_use():
		turn_off()
		return

	# aim at the mouse (the cone texture must point RIGHT; a round texture ignores this)
	look_at(get_global_mouse_position())

	# drain the charge
	gameManager.flashlight_charge = max(gameManager.flashlight_charge - delta, 0.0)
	if gameManager.flashlight_charge <= 0.0:
		turn_off()

func turn_on():
	is_on = true
	enabled = true
	gameManager.flashlight_toggled.emit(true)
	print("Flashlight ON")

func turn_off():
	if not is_on:
		return    # already off, so don't announce it again
	is_on = false
	enabled = false
	gameManager.flashlight_toggled.emit(false)
	print("Flashlight OFF")

func use_battery():
	if gameManager.battery_count > 0 and gameManager.flashlight_charge < gameManager.FLASHLIGHT_MAX:
		gameManager.battery_count -= 1
		gameManager.flashlight_charge = gameManager.FLASHLIGHT_MAX
