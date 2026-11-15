extends Button

var item

func setup(new_item: Dictionary) -> void:
	item = new_item
	icon = item["icon"]

func _pressed() -> void:
	match item["id"]:
		"flashlight":
			print("Flash light")
