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


func _init(order_model: OrderModel, board_view: BoardView) -> void:
	model = order_model
	board = board_view


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## True if the event was used.
func handle_event(event: InputEvent) -> bool:
	if not enabled:
		return false
	var mb := event as InputEventMouseButton
	if mb != null:
		if not mb.pressed or mb.device == InputEvent.DEVICE_ID_EMULATION or _is_blocked(mb.position):
			return false
		if mb.button_index == MOUSE_BUTTON_LEFT:
			click(board.tile_at(mb.position))
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			clear_selected()
			return true
		return false
	var st := event as InputEventScreenTouch
	if st != null and st.pressed and not _is_blocked(st.position):
		tap(board.tile_at(st.position))
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


## A new turn's model: nothing has been sent for it yet.
func reset() -> void:
	_pending = Vector2i(-1, -1)
	_last_sent = []


func _changed() -> void:
	board.show_paths(model)
	var orders := model.wire_orders()
	if orders != _last_sent:
		_last_sent = orders
		orders_changed.emit(model.turn, orders)


func _is_blocked(pos: Vector2) -> bool:
	return blocked.is_valid() and bool(blocked.call(pos))
