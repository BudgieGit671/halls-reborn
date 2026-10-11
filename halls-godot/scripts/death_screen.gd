extends CanvasLayer

# Tells main.gd which button was pressed: "play_again", "main_menu" or "quit"
signal choice_made(choice)

const CHARS_PER_SECOND := 28.0   # typing speed
const FADE_IN_TIME := 3.0        # how slowly the screen goes black
const MUSIC_FADE_TIME := 4.0
const TEXT_COLOR := Color("77b0bdff")

# What the Guiding Light says for each entity.
# To add a new entity later, just add another entry with its name.
const HINTS := {
	"Whisk": [
		"You died to who you call Whisk...",
		"Whisk is fast. It sweeps through the rooms and never stops for anything.",
		"When you hear it coming, find a place to hide until it has passed.",
		"Stay calm, listen, and try again...",
	],
}

const DEFAULT_HINTS := [
	"You died to something you could not understand...",
	"Stay calm, listen, and try again...",
]

@onready var background = $Background
@onready var hint_label = $HintLabel
@onready var click_prompt = $ClickPrompt
@onready var stats_center = $StatsCenter
@onready var room_label = $StatsCenter/StatsBox/RoomReached
@onready var killer_label = $StatsCenter/StatsBox/KilledBy
@onready var music = $DeathMusic

var skip_pressed := false      # set to true by a mouse click
var accepting_clicks := false  # clicks only count during the text sequence

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working even if the game is paused
	setup_layout()
	setup_buttons()

	# everything starts invisible
	background.modulate.a = 0.0
	hint_label.text = ""
	click_prompt.visible = false
	stats_center.visible = false

# ---------- SETUP ----------

# Does the layout in code so you don't have to fiddle with anchors in the editor
func setup_layout():
	# black background over the whole screen; it also blocks clicks from reaching the game
	background.color = Color(0.044, 0.103, 0.13, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# the guiding light text: centered, wraps long lines, 200px margin on each side
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_label.offset_left = 200
	hint_label.offset_right = -200
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 32)
	hint_label.add_theme_color_override("font_color", TEXT_COLOR)

	# small "click to skip" text at the bottom
	click_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	click_prompt.offset_top = -80
	click_prompt.offset_bottom = -30
	click_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_prompt.text = "click to skip"
	click_prompt.modulate.a = 0.5
	click_prompt.add_theme_color_override("font_color", TEXT_COLOR)

	# stats and buttons: a column in the middle of the screen
	stats_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = $StatsCenter/StatsBox
	box.add_theme_constant_override("separation", 14)

	var title = $StatsCenter/StatsBox/Title
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 56)
	for label in [title, room_label, killer_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TEXT_COLOR)
	room_label.add_theme_font_size_override("font_size", 28)
	killer_label.add_theme_font_size_override("font_size", 28)

func setup_buttons():
	var play_again = $StatsCenter/StatsBox/PlayAgain
	var main_menu = $StatsCenter/StatsBox/MainMenu
	var quit = $StatsCenter/StatsBox/Quit

	play_again.text = "Play again"
	main_menu.text = "Main menu"
	quit.text = "Quit"
	for button in [play_again, main_menu, quit]:
		button.custom_minimum_size = Vector2(260, 50)

	# when a button is pressed, announce which one
	play_again.pressed.connect(func(): choice_made.emit("play_again"))
	main_menu.pressed.connect(func(): choice_made.emit("main_menu"))
	quit.pressed.connect(func(): choice_made.emit("quit"))

# ---------- CLICK DETECTION ----------

func _input(event):
	if not accepting_clicks:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip_pressed = true
		get_viewport().set_input_as_handled()

# ---------- THE SEQUENCE ----------

# main.gd calls this once. It runs the whole death screen from start to finish.
func show_death(killer: String, room_reached: int):
	room_label.text = "Room reached: %03d" % room_reached
	killer_label.text = "Died to: " + killer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # make sure the cursor is visible for the buttons
	accepting_clicks = true

	# music fades in from near-silent (this keeps going even if you skip)
	music.volume_db = -40.0
	music.play()
	var music_tween = create_tween()
	music_tween.tween_property(music, "volume_db", 0.0, MUSIC_FADE_TIME)

	# step 1: screen slowly fades to black
	await fade_in_background()

	# step 2: the guiding light speaks, one line at a time
	click_prompt.visible = true
	for line in HINTS.get(killer, DEFAULT_HINTS):
		await show_line(line)
	click_prompt.visible = false
	hint_label.text = ""
	accepting_clicks = false

	# step 3: stats and buttons fade in
	stats_center.modulate.a = 0.0
	stats_center.visible = true
	var tween = create_tween()
	tween.tween_property(stats_center, "modulate:a", 1.0, 1.0)

# Fades to black over FADE_IN_TIME seconds. A click finishes it instantly.
func fade_in_background():
	var t = 0.0
	while t < FADE_IN_TIME and not skip_pressed:
		await get_tree().process_frame
		t += get_process_delta_time()
		background.modulate.a = t / FADE_IN_TIME
	background.modulate.a = 1.0
	skip_pressed = false

# Types out one line, waits so it can be read, then fades it away.
# A click during typing finishes the typing; a click while reading goes to the next line.
func show_line(text: String):
	hint_label.text = text
	hint_label.visible_ratio = 0.0   # 0.0 = no letters shown, 1.0 = all letters shown
	hint_label.modulate.a = 1.0

	# typing
	var type_time = text.length() / CHARS_PER_SECOND
	var t = 0.0
	while t < type_time and not skip_pressed:
		await get_tree().process_frame
		t += get_process_delta_time()
		hint_label.visible_ratio = t / type_time
	hint_label.visible_ratio = 1.0
	skip_pressed = false

	# reading time: longer lines stay longer
	var read_time = 2.0 + text.length() * 0.04
	t = 0.0
	while t < read_time and not skip_pressed:
		await get_tree().process_frame
		t += get_process_delta_time()
	skip_pressed = false

	# quick fade out before the next line
	var tween = create_tween()
	tween.tween_property(hint_label, "modulate:a", 0.0, 0.3)
	await tween.finished
