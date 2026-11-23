extends HBoxContainer
const SLOT = preload("res://scenes/gui/hud/slot.tscn")

func refresh(items: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for i in min(items.size(), 9): 
		var slot = SLOT.instantiate()
		add_child(slot)
		slot.setup(items[i], i + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index = event.keycode - KEY_1   # KEY_1 -> 0, KEY_2 -> 1, ...
		if index >= 0 and index < get_child_count():
			get_child(index).activate()
