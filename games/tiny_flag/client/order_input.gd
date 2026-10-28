class_name OrderInput
extends Node
## Mouse and touch order entry (spec §2 "Planning"): turns BoardCamera's clicks and taps
## on the board into OrderModel calls, redraws the paths and reports every change to the
## orders. (Drags and pinches pan and zoom; BoardCamera keeps them apart from clicks.)
##   Mouse: left click = OrderModel.click_tile, right click = clear the selected path.
##   Touch: tap a piece to select it; tap a tile to preview the path, tap it again to
##   confirm.

## The orders to send changed; TinyFlagGame.send_orders(turn, orders) sends them.
signal orders_changed(turn: int, orders: Array)

var model: OrderModel
var board: BoardView
## Off while there's nothing to plan (spectating, playback, between turns).
var enabled: bool = false

var _pending: Vector2i = Vector2i(-1, -1)
var _last_sent: Array = []


func _init(order_model: OrderModel, board_view: BoardView, camera: BoardCamera = null) -> void:
	model = order_model
	board = board_view
	if camera != null:
		camera.clicked.connect(on_click)
		camera.tapped.connect(on_tap)


## A mouse click on the board. True if it was used.
func on_click(pos: Vector2, button: MouseButton) -> bool:
	if not enabled:
		return false
	if button == MOUSE_BUTTON_RIGHT:
		clear_selected()
		return true
	var c := board.tile_at(pos)
	if button != MOUSE_BUTTON_LEFT or not model.map.in_bounds(c):
		return false
	click(c)
	return true


## A one-finger tap on the board. True if it was used.
func on_tap(pos: Vector2) -> bool:
	var c := board.tile_at(pos)
	if not enabled or not model.map.in_bounds(c):
		return false
	tap(c)
	return true


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
	_changed()


func _changed() -> void:
	board.show_paths(model)
	var orders := model.wire_orders()
	if orders != _last_sent:
		_last_sent = orders
		orders_changed.emit(model.turn, orders)
