extends HBoxContainer
const SLOT = preload("res://scenes/gui/hud/slot.tscn")

func refresh(items: Array) -> void:
	for child in get_children():
		child.queue_free()
	for i in min(items.size(), 9): 
		var slot = SLOT.instantiate()
		add_child(slot)
		slot.setup(items[i], i + 1)
