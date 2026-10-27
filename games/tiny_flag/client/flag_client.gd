class_name FlagClient
extends Node
## A person's Tiny Flag client: wires TinyFlagGame's messages to the board, the order
## model and input, and the HUD, and sends orders, lock-in and playback_done back.
## Built by TinyFlagGame._build_client_world for people only; bots stay headless.

var game: TinyFlagGame
var board: BoardView
var model: OrderModel
var input: OrderInput
var hud: TurnHud


func _init(flag_game: TinyFlagGame) -> void:
	game = flag_game
	name = "FlagClient"


func _ready() -> void:
	board = BoardView.new()
	board.name = "Board"
	board.set_map(game.map)
	add_child(board)
	model = OrderModel.new(game.map)
	input = OrderInput.new(model, board)
	input.name = "OrderInput"
	add_child(input)
	hud = TurnHud.new()
	hud.name = "TurnHud"
	add_child(hud)
	# HUD buttons, and the menu while back at select (no player of ours spawned).
	input.blocked = func(pos: Vector2) -> bool: return hud.covers(pos) or game.local_player() == null

	game.auto_playback_done = false
	game.turn_started_received.connect(_on_turn_started)
	game.turn_resolved_received.connect(_on_turn_resolved)
	game.match_over_received.connect(hud.on_match_over)
	board.playback_finished.connect(game.send_playback_done)
	board.event_shown.connect(hud.on_event)
	input.orders_changed.connect(game.send_orders)
	hud.lock_in_pressed.connect(func() -> void: game.send_lock_in(model.turn))
	hud.clear_pressed.connect(input.clear_selected)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	board.fit(get_viewport().get_visible_rect().size, TurnHud.TOP, TurnHud.BOTTOM)


func _on_turn_started(seconds_left: float, view: Dictionary) -> void:
	board.show_view(view)
	model.set_view(view)
	input.reset()
	input.enabled = model.team >= 0
	board.show_paths(model)
	hud.on_turn_started(seconds_left, view)


func _on_turn_resolved(turn: Dictionary) -> void:
	input.enabled = false
	board.show_paths(null)
	hud.on_turn_resolved(turn)
	board.play_turn(turn)
