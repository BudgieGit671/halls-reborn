extends Node2D

# Every painting is shrunk to fit inside this box (keeps its proportions)
@export var max_size := Vector2(110, 110)
# Chance that a spot is left empty (0.0 = every spot filled, 0.2 = about 1 in 5 is bare)
@export_range(0.0, 1.0) var empty_chance := 0.15

func _ready():
	if gameManager.paintings.is_empty():
		return

	# Random generator that gives the same results for the same room in the same run
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([gameManager.run_seed, gameManager.current_room_index])

	# a list of painting NUMBERS (0 to 60); picked ones get removed so none repeats
	var available = range(gameManager.paintings.size())

	for marker in get_children():
		if not marker is Marker2D:
			continue
		if available.is_empty() or rng.randf() < empty_chance:
			continue

		# pick a random position in the list, take that painting, remove it from the list
		var slot = rng.randi_range(0, available.size() - 1)
		var texture = gameManager.paintings[available[slot]]
		available.remove_at(slot)

		var painting = Sprite2D.new()
		painting.texture = texture
		# scale to fit the box without stretching
		var fit = min(max_size.x / texture.get_width(), max_size.y / texture.get_height())
		painting.scale = Vector2(fit, fit)
		marker.add_child(painting)   # child of the marker, so it sits exactly on it
