class_name TurnHud
extends CanvasLayer
## Tiny Flag's on-screen HUD: score and turn (top centre), side and planning countdown
## (top right), the hint line, Clear and Lock in (bottom), event toasts and the result.
## The starter's Hud keeps the top-left corner (status line, touch Menu button).

signal lock_in_pressed()
signal clear_pressed()

## Room the board leaves for the bars (BoardView.fit).
const TOP: float = 64.0
const BOTTOM: float = 64.0
const TOAST_SECONDS: float = 3.0
const FONT: int = 22

var team: int = FlagWire.SPECTATOR

var _score: Label
var _turn: Label
var _side: Label
var _clock: Label
var _hint: Label
var _lock: Button
var _clear: Button
var _toasts: VBoxContainer
var _result: Label
var _seconds_left: float = 0.0
var _planning: bool = false


func _ready() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = TOP
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 40)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_score = _label(top, FONT + 4)
	_turn = _label(top, FONT)
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -360
	right.offset_right = -24
	right.offset_bottom = TOP
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 24)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_side = _label(right, FONT)
	_clock = _label(right, FONT + 4)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM + 6
	bottom.offset_bottom = -6
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.add_theme_constant_override("separation", 16)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_hint = _label(bottom, 18)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear = _button(bottom, "✕ Clear path")
	_clear.pressed.connect(func() -> void: clear_pressed.emit())
	_lock = _button(bottom, "Lock in")
	_lock.pressed.connect(_on_lock)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.offset_top = -BOTTOM - 160
	_toasts.offset_bottom = -BOTTOM - 8
	_toasts.offset_left = -300
	_toasts.offset_right = 300
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_result = Label.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 56)
	_result.add_theme_constant_override("outline_size", 12)
	_result.add_theme_color_override("font_outline_color", Color.BLACK)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	add_child(_result)
	_set_buttons(false)
	_hint.text = "Waiting for the next turn..."


func _process(delta: float) -> void:
	if not _planning:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_clock.text = "%d s" % ceili(_seconds_left)


func on_turn_started(seconds_left: float, view: Dictionary) -> void:
	team = int(view.get("team", FlagWire.SPECTATOR))
	_seconds_left = seconds_left
	_planning = team >= 0
	_result.visible = false
	_show_score(view.get("score"))
	_turn.text = "Turn %d / %d" % [int(view.get("turn", 0)) + 1, int(view.get("turn_limit", FlagState.TURN_LIMIT))]
	if team >= 0:
		_side.text = "You: " + FlagArt.TEAM_NAME[team]
		_side.add_theme_color_override("font_color", FlagArt.TEAM_COLOR[team].lightened(0.3))
		_hint.text = "Tap a soldier, then a tile twice" if DisplayServer.is_touchscreen_available() \
				else "Click a soldier, then a tile. Right-click clears."
		_lock.text = "Lock in"
	else:
		_side.text = "Watching"
		_side.remove_theme_color_override("font_color")
		_clock.text = ""
		_hint.text = "Spectating"
	_set_buttons(team >= 0)


func on_turn_resolved(turn: Dictionary) -> void:
	_planning = false
	_clock.text = ""
	_set_buttons(false)
	_hint.text = "Turn %d" % (int(turn.get("turn", 0)) + 1)


func on_match_over(result: Dictionary) -> void:
	_show_score(result.get("score"))
	var r := int(result.get("result", FlagState.Result.DRAW))
	var text := "Draw"
	if r == FlagState.Result.RED_WINS or r == FlagState.Result.BLUE_WINS:
		text = "You win!" if r == team else ("You lose" if team >= 0 else FlagArt.TEAM_NAME[r] + " wins")
	_result.text = text
	_result.visible = true


## A witnessed event from the playback.
func on_event(e: Dictionary) -> void:
	var piece := int(e.get("piece", 0))
	var side: String = FlagArt.TEAM_NAME[clampi(piece / FlagState.SQUAD, 0, 1)]
	match e.get("kind"):
		"tag":
			toast("%s soldier tagged!" % side)
		"pickup":
			toast("%s took %s's flag!" % [side, FlagArt.TEAM_NAME[clampi(int(e.get("flag", 0)), 0, 1)]])
		"capture":
			toast("%s captured the flag!" % side)


func toast(text: String) -> void:
	var l := _label(_toasts, FONT)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(l.queue_free)


## True if `pos` (viewport coordinates) is over one of the HUD's buttons.
func covers(pos: Vector2) -> bool:
	for b: Button in [_lock, _clear]:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false


func _on_lock() -> void:
	_lock.text = "Locked in"
	lock_in_pressed.emit()


func _set_buttons(on: bool) -> void:
	_lock.visible = on
	_clear.visible = on


func _show_score(score: Variant) -> void:
	if typeof(score) != TYPE_ARRAY or (score as Array).size() != 2:
		return
	_score.text = "Red %d  :  %d Blue" % [int(score[0]), int(score[1])]


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 0)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
