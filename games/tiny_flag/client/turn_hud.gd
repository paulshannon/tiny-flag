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
const FONT: int = 20
const CLEAR_TEXT: String = "Clear path"  # the cross is the theme's icon (FlagUi.CLEAR_BUTTON)

var team: int = FlagWire.SPECTATOR

var _score: Label
var _turn: Label
var _middle_bar: PanelContainer
var _side_tag: PanelContainer
var _side: Label
var _clock_bar: PanelContainer
var _clock: Label
var _hint: Label
var _lock: Button
var _clear: Button
var _toasts: VBoxContainer
var _result_box: CenterContainer
var _result_panel: PanelContainer
var _result: Label
var _seconds_left: float = 0.0
var _planning: bool = false


func _ready() -> void:
	# One root carries the Kenney UI Pack theme for everything below it. The project's
	# default filter is Nearest (pixel-art board); the pack's art and font are smooth.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = FlagUi.make_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 8
	top.offset_bottom = TOP - 6
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_middle_bar = _bar(top, FlagUi.BAR)
	var middle := _row(_middle_bar, 32)
	_score = _label(middle, FONT + 4)
	_turn = _label(middle, FONT)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -360
	right.offset_right = -16
	right.offset_top = 8
	right.offset_bottom = TOP - 6
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	_side_tag = _bar(right, FlagUi.NEUTRAL_TAG)
	_side = _label(_side_tag, FONT)
	_clock_bar = _bar(right, FlagUi.BAR)
	_clock_bar.custom_minimum_size = Vector2(84, 0)
	_clock = _label(_clock_bar, FONT + 4)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM + 6
	bottom.offset_bottom = -6
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.add_theme_constant_override("separation", 12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_hint = _label(_bar(bottom, FlagUi.BAR), FlagUi.SMALL_FONT_SIZE)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	_clear = _button(bottom, CLEAR_TEXT, FlagUi.CLEAR_BUTTON)
	_clear.pressed.connect(func() -> void: clear_pressed.emit())
	_lock = _button(bottom, "Lock in", FlagUi.LOCK_BUTTON)
	_lock.pressed.connect(_on_lock)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.offset_top = -BOTTOM - 180
	_toasts.offset_bottom = -BOTTOM - 12
	_toasts.offset_left = -300
	_toasts.offset_right = 300
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN  # a long stack grows up, not onto the bar
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	_result_box = CenterContainer.new()
	_result_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_box.visible = false
	root.add_child(_result_box)
	_result_panel = _bar(_result_box, FlagUi.NEUTRAL_BANNER)
	_result = _label(_result_panel, 56)
	_result.theme_type_variation = FlagUi.LIGHT_LABEL
	_result.add_theme_constant_override("outline_size", 10)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_buttons(false)
	_hint.text = "Waiting for the next turn..."
	_clock_bar.visible = false
	_side_tag.visible = false
	_middle_bar.visible = false  # until the first turn fills it


func _process(delta: float) -> void:
	if not _planning:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_clock.text = "%d s" % ceili(_seconds_left)


func on_turn_started(seconds_left: float, view: Dictionary) -> void:
	team = int(view.get("team", FlagWire.SPECTATOR))
	_seconds_left = seconds_left
	_planning = team >= 0
	_result_box.visible = false
	_show_score(view.get("score"))
	_turn.text = "Turn %d / %d" % [int(view.get("turn", 0)) + 1, int(view.get("turn_limit", FlagState.TURN_LIMIT))]
	_side_tag.visible = true
	_middle_bar.visible = true
	if team >= 0:
		_side.text = "You: " + FlagArt.TEAM_NAME[team]
		_side_tag.theme_type_variation = FlagUi.TEAM_TAG[team]
		_side.theme_type_variation = FlagUi.LIGHT_LABEL
		_hint.text = "Tap a soldier, then a tile twice" if DisplayServer.is_touchscreen_available() \
				else "Click a soldier, then a tile. Right-click clears."
		_lock.text = "Lock in"
		_clock_bar.visible = true
	else:
		_side.text = "Watching"
		_side_tag.theme_type_variation = FlagUi.NEUTRAL_TAG
		_side.theme_type_variation = &""
		_clock.text = ""
		_clock_bar.visible = false
		_hint.text = "Spectating"
	_set_buttons(team >= 0)


func on_turn_resolved(turn: Dictionary) -> void:
	_planning = false
	_clock.text = ""
	_clock_bar.visible = false
	_set_buttons(false)
	_hint.text = "Turn %d" % (int(turn.get("turn", 0)) + 1)


func on_match_over(result: Dictionary) -> void:
	_show_score(result.get("score"))
	var r := int(result.get("result", FlagState.Result.DRAW))
	var text := "Draw"
	_result_panel.theme_type_variation = FlagUi.NEUTRAL_BANNER
	if r == FlagState.Result.RED_WINS or r == FlagState.Result.BLUE_WINS:
		text = "You win!" if r == team else ("You lose" if team >= 0 else FlagArt.TEAM_NAME[r] + " wins")
		_result_panel.theme_type_variation = FlagUi.TEAM_BANNER[r]  # the winner's colour
	_result.text = text
	_result_box.visible = true


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
	var p := _bar(_toasts, FlagUi.TOAST)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(p, FONT - 2)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(p.queue_free)


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


## A themed panel (FlagUi variation) that lets clicks through to the board.
func _bar(parent: Control, variation: StringName) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _row(parent: Control, separation: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, variation: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(170, 0)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
