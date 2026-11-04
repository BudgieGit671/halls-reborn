extends Node2D

var player_inside = false
var hiding_cooldown = false
var hidden_here = false      # NEW: true only in the closet the player actually entered
var tween: Tween

func _ready():
	$Prompt.visible = false

func _on_interact_zone_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		$Prompt.visible = true
		start_pulse()

func _on_interact_zone_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		$Prompt.visible = false
		stop_pulse()

func _input(event):
	if not event.is_action_pressed("interact"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or hiding_cooldown:
		return

	if hidden_here:
		# only the closet you're inside can let you out
		exit_closet(player)
	elif player_inside and not player.is_hiding and not player.velocity.y:
		enter_closet(player)

func enter_closet(player):
	hiding_cooldown = true
	hidden_here = true
	print("entering closet!")
	$ClosetIn.play()
	player.set_hidden(true)
	await get_tree().create_timer(0.5).timeout
	hiding_cooldown = false

func exit_closet(player):
	hiding_cooldown = true
	hidden_here = false
	print("exiting closet!")
	$ClosetOut.play()
	player.set_hidden(false)
	await get_tree().create_timer(0.5).timeout
	hiding_cooldown = false

func start_pulse():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_loops()
	tween.tween_property($Prompt, "modulate:a", 0.0, 0.6)
	tween.tween_property($Prompt, "modulate:a", 1.0, 0.6)

func stop_pulse():
	if tween:
		tween.kill()
	$Prompt.modulate.a = 1.0
