extends Node2D

var player_inside = false
var hiding_cooldown = false
func _ready():
	$Prompt.visible = false
	
func _on_interact_zone_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		$Prompt.visible = true
		
func _on_interact_zone_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		$Prompt.visible = false

func _input(event):
	var player = get_tree().get_first_node_in_group("player")
	if event.is_action_pressed("interact") and not player.velocity.y:
		if player_inside and not is_player_hidden() and not hiding_cooldown:
			hiding_cooldown = true
			print("entering closet!")
			$ClosetIn.play()
			player.set_hidden(true)
			await get_tree().create_timer(0.5).timeout
			print("hiding cooldown over!")
			hiding_cooldown = false
		elif is_player_hidden() and not hiding_cooldown :
			hiding_cooldown = true
			print("exiting closet!")
			$ClosetOut.play()
			player.set_hidden(false)
			await get_tree().create_timer(0.5).timeout
			print("hiding cooldown over!")
			hiding_cooldown = false
		

func is_player_hidden() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return player.is_hiding
