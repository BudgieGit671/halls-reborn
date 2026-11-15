extends HBoxContainer

const SLOT = preload("res://scenes/gui/hud/slot.tscn")

func refresh(items: Array) -> void:
	for child in get_children():
		child.queue_free()
	for item in items.slice(0, 9):   # never more than 9
		var slot = SLOT.instantiate()
		add_child(slot)
		slot.setup(item)
