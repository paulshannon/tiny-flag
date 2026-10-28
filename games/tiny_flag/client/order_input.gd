class_name OrderInput
extends Node
## Mouse and touch order entry (spec §2 "Planning"): turns clicks and taps on the board
## into OrderModel calls, redraws the paths and reports every change to the orders.
##   Mouse: left click = OrderModel.click_tile, right click = clear the selected path.
##   Touch: tap a piece to select it; tap a tile to preview the path, tap it again to
##   confirm. (Godot also emulates a mouse click from each tap; those are ignored.)

## The in-budget orders changed; TinyFlagGame.send_orders(turn, orders) sends them.
signal orders_changed(turn: int, orders: Array)

var model: OrderModel
var board: BoardView
## Off while there's nothing to plan (spectating, playback, between turns).
var enabled: bool = false
## Returns true for screen points over HUD controls, which taps must not reach.
var blocked: Callable

var _pending: Vector2i = Vector2i(-1, -1)
var _last_sent: Array = []
## Fingers down on the board, by touch index. Browsers number touches freely
## (iOS Safari uses large ids, Chrome counts up), so "first finger" means "no
## other finger down", never index 0. Kept in _input, which sees every event, so a
## release a Control consumes still counts; cleared when focus is lost.
var _fingers: Dictionary[int, bool] = {}


func _init(order_model: OrderModel, board_view: BoardView) -> void:
	model = order_model
	board = board_view


func _input(event: InputEvent) -> void:
	_track_finger(event)


## Releases eaten by an app switch or a system gesture never arrive: start clean.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		_fingers.clear()


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## True if the event was used. Repeats _input's finger bookkeeping (it's idempotent),
## so it also works on its own.
func handle_event(event: InputEvent) -> bool:
	_track_finger(event)
	var st := event as InputEventScreenTouch
	var lone_finger: bool = false
	if st != null:
		if not st.pressed:
			return false
		lone_finger = _fingers.size() == 1 and _fingers.has(st.index)
	if not enabled:
		return false
	var mb := event as InputEventMouseButton
	if mb != null:
		if not mb.pressed or mb.device == InputEvent.DEVICE_ID_EMULATION or _is_blocked(mb.position):
			return false
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var c := board.tile_at(mb.position)
			if not model.map.in_bounds(c):
				return false  # off the board: leave it to other controls
			click(c)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			clear_selected()
			return true
		return false
	# One finger only: a second finger can't confirm a path. Off-board taps (the
	# starter's touch Menu button) are left for other controls.
	if st != null and lone_finger and not _is_blocked(st.position):
		var t := board.tile_at(st.position)
		if not model.map.in_bounds(t):
			return false
		tap(t)
		return true
	return false


func click(c: Vector2i) -> void:
	_pending = Vector2i(-1, -1)
	model.click_tile(c)
	_changed()


func tap(c: Vector2i) -> void:
	if model.piece_at(c) >= 0 or c == _pending:
		click(c)
		return
	var step := model.preview(c)
	_pending = c if not step.is_empty() else Vector2i(-1, -1)
	board.show_paths(model, step)


func clear_selected() -> void:
	_pending = Vector2i(-1, -1)
	model.clear(model.selected)
	_changed()


## A new turn's model: nothing has been sent for it yet. Paths carried over from the
## last turn are sent straight away, so they count even if nobody touches them.
func reset() -> void:
	_pending = Vector2i(-1, -1)
	_last_sent = []
	_fingers.clear()  # a release some other control took can't block the next turn
	_changed()


## Fingers down, tracked even while disabled so none is left stuck down.
func _track_finger(event: InputEvent) -> void:
	var st := event as InputEventScreenTouch
	if st == null:
		return
	if st.pressed:
		_fingers[st.index] = true
	else:
		_fingers.erase(st.index)


func _changed() -> void:
	board.show_paths(model)
	var orders := model.wire_orders()
	if orders != _last_sent:
		_last_sent = orders
		orders_changed.emit(model.turn, orders)


func _is_blocked(pos: Vector2) -> bool:
	return blocked.is_valid() and bool(blocked.call(pos))
