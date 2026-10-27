class_name FlagMenu
extends GameMenu
## Tiny Flag's start menu: title, how to play, Play and Controls (the starter's
## ControlsEditor with the game's action names). Shown again after a lost connection
## with "Rejoin" / "Try again".

const HOW_TO: String = "Two teams of five soldiers. Each turn, plan a path for each soldier, " \
		+ "then watch everyone move at once. Bring the enemy flag home three times to win. " \
		+ "Soldiers tagged on enemy ground go home."

var _names: Dictionary
var _main: VBoxContainer
var _status: Label
var _play: Button
var _controls: ControlsEditor


func _init(action_names: Dictionary) -> void:
	super()
	_names = action_names


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.08, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var pages := VBoxContainer.new()
	margin.add_child(pages)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 20)
	pages.add_child(_main)
	var title := Label.new()
	title.text = "Tiny Flag"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	_main.add_child(title)
	var how := Label.new()
	how.text = HOW_TO
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(560, 0)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.add_theme_font_size_override("font_size", 18)
	_main.add_child(how)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	_main.add_child(_status)
	_play = _button("Play", request_play)
	_button("Controls", _show_controls)

	_controls = ControlsEditor.new(_names, "Mouse: click a soldier, then a tile; right-click clears. "
			+ "Touch: tap a soldier, then tap a tile twice.")
	_controls.visible = false
	_controls.closed.connect(_show_main)
	pages.add_child(_controls)


func _apply(status: String, play_text: String) -> void:
	_status.text = status
	_status.visible = not status.is_empty()
	_play.text = play_text
	_show_main()


func _show_main() -> void:
	_controls.visible = false
	_main.visible = true
	_play.grab_focus.call_deferred()


func _show_controls() -> void:
	_main.visible = false
	_controls.visible = true
	_controls.refresh()
	_controls.focus_first()


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 64)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(on_press)
	var row := CenterContainer.new()
	row.add_child(b)
	_main.add_child(row)
	return b
