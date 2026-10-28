class_name FlagClient
extends Node
## A person's Tiny Flag client: wires TinyFlagGame's messages to the board, the order
## model and input, and the HUD, and sends orders, lock-in and playback_done back.
## Built by TinyFlagGame._build_client_world for people only; bots stay headless.

var game: TinyFlagGame
var board: BoardView
var model: OrderModel
var input: OrderInput
var camera: BoardCamera
var hud: TurnHud
## A match_over that arrived while the board was still playing the final turn.
var _held_result: Dictionary = {}


func _init(flag_game: TinyFlagGame) -> void:
	game = flag_game
	name = "FlagClient"


func _ready() -> void:
	board = BoardView.new()
	board.name = "Board"
	board.set_map(game.map)
	add_child(board)
	camera = BoardCamera.new(board)
	add_child(camera)
	model = OrderModel.new(game.map)
	input = OrderInput.new(model, board, camera)
	input.name = "OrderInput"
	add_child(input)
	hud = TurnHud.new()
	hud.name = "TurnHud"
	add_child(hud)
	# HUD buttons, and the menu while back at select (no player of ours spawned).
	camera.blocked = func(pos: Vector2) -> bool: return hud.covers(pos) or game.local_player() == null

	game.auto_playback_done = false
	game.turn_started_received.connect(_on_turn_started)
	game.turn_resolved_received.connect(_on_turn_resolved)
	game.match_over_received.connect(_on_match_over)
	board.playback_finished.connect(_on_playback_finished)
	board.event_shown.connect(hud.on_event)
	input.orders_changed.connect(game.send_orders)
	hud.lock_in_pressed.connect(func() -> void: game.send_lock_in(model.turn))
	hud.clear_pressed.connect(input.clear_selected)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	camera.fit(get_viewport().get_visible_rect().size, TurnHud.TOP, TurnHud.BOTTOM)


func _on_turn_started(seconds_left: float, view: Dictionary) -> void:
	board.show_view(view)
	model.set_view(view)
	input.reset()
	_held_result = {}
	input.enabled = model.team >= 0
	board.show_paths(model)
	hud.on_turn_started(seconds_left, view)


func _on_turn_resolved(turn: Dictionary) -> void:
	input.enabled = false
	board.show_paths(null)
	hud.on_turn_resolved(turn)
	board.play_turn(turn)


## match_over comes right after the final turn_resolved: the banner waits until the
## board has played that turn, so it doesn't cover the winning move.
func _on_match_over(result: Dictionary) -> void:
	if board.is_playing():
		_held_result = result
	else:
		hud.on_match_over(result)


## Only a side's playback paces the match; spectators don't answer.
func _on_playback_finished(turn: int) -> void:
	if not _held_result.is_empty():
		hud.on_match_over(_held_result)
		_held_result = {}
	if model.team >= 0:
		game.send_playback_done(turn)
