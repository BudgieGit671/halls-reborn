extends Node2D

@export var palette: Array[Texture2D] = []

func _ready():
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([gameManager.run_seed, gameManager.current_room_index, "bg"])
	$BG.texture = palette[rng.randi_range(0, palette.size() - 1)]
