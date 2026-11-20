extends Button
var item
@onready var number_label = $NumberLabel

func setup(new_item: Dictionary, number: int) -> void:
	item = new_item
	icon = item["icon"]
	number_label.text = str(number)

func _pressed() -> void:
	match item["id"]:
		"flashlight":
			gameManager.flashlight_pressed.emit()
