class_name TinyFlagGame
extends GameBase
## Tiny Flag on the network (spec §3 "Fit with the starter", "Messages"). The server runs
## one FlagMatch and drives it from _physics_process; this node only turns RPCs into
## FlagMatch calls and FlagMatch's sends into RPCs. People join through GameBase's
## spawner as FlagPerson markers (no InputRelay, PlayerNet or ServerBots: the game is
## turn-based, and FlagMatch plays empty sides itself).
##
## Clients get three messages (reliable, server -> one peer) and answer with three:
##   turn_started(payload)  -> submit_orders(turn, orders), lock_in(turn)
##   turn_resolved(payload) -> playback_done(turn)    (after the playback is drawn)
##   match_over(payload)

## Client: a planning phase began. `view` is FlagWire.view_for for our side (or a
## spectator's view, team FlagWire.SPECTATOR).
signal turn_started_received(seconds_left: float, view: Dictionary)
## Client: a turn's playback (FlagWire.turn_for: {"turn", "ticks", "events"}).
signal turn_resolved_received(turn: Dictionary)
## Client: {"result": FlagState.Result, "score": [red, blue]}.
signal match_over_received(result: Dictionary)

## Loaded on every peer: the server plays on it, clients check and draw with it.
var map: FlagMap
## Client: answer each turn_resolved with playback_done at once (bots, which draw
## nothing). A person's FlagClient turns this off and sends playback_done when its
## BoardView has played the turn.
var auto_playback_done: bool = true
## Client: smoke counters (turns, leaks, own_moved).
var tally := FlagClientTally.new()
## Client: match_over messages received.
var matches_over: int = 0

## Server only.
var _match: FlagMatch
## Client bots (config.bot) only.
var _bot: FlagBot


func _ready() -> void:
	map = FlagMap.load_map(FlagMap.FARM_PATH)
	super()


func start_server() -> void:
	super()
	_match = FlagMatch.new(map, _send, randi())


func _physics_process(delta: float) -> void:
	if _match != null:
		_match.tick(delta)


func touch_stick() -> bool:
	return false


## People get the board, orders and HUD; bots stay headless and auto-ack playback.
func _build_client_world() -> void:
	if config.bot:
		return
	add_child(FlagClient.new(self))


func make_menu() -> GameMenu:
	return FlagMenu.new(control_names())


## Orders are mouse and touch only; the one remappable action is the menu.
func control_names() -> Dictionary:
	return {InputSetup.MENU: "Back to select"}


func _create_player(data: Dictionary) -> Node:
	return FlagPerson.new(int(data["id"]))


# --- server -------------------------------------------------------------------

func spawn_player(id: int, index: int, choice: Dictionary, extra: Dictionary = {}) -> void:
	super(id, index, choice, extra)
	_match.add_person(id)


## Left, or back to select: the side passes to a bot (FlagMatch.remove_person).
func _player_leaving(id: int, _player: Node) -> void:
	if _match != null:
		_match.remove_person(id)


## FlagMatch's outlet. It only sends to current members, and a peer that left was
## removed from it first; the peer check only guards a send racing a disconnect.
func _send(peer: int, kind: String, payload: Dictionary) -> void:
	if not multiplayer.get_peers().has(peer):
		return
	match kind:
		"turn_started":
			turn_started.rpc_id(peer, payload)
		"turn_resolved":
			turn_resolved.rpc_id(peer, payload)
		"match_over":
			match_over.rpc_id(peer, payload)
		_:
			push_error("TinyFlagGame: unknown message %s" % kind)


# Client -> server. Arguments are Variants on purpose: a typed parameter makes the
# engine log an error for a hostile call with the wrong type before this code runs.
# FlagMatch drops a wrong turn, and FlagPath validates the orders themselves.

@rpc("any_peer", "call_remote", "reliable", 0)
func submit_orders(turn: Variant, orders: Variant) -> void:
	if _match == null or typeof(turn) != TYPE_INT:
		return
	_match.submit(multiplayer.get_remote_sender_id(), int(turn), orders)


@rpc("any_peer", "call_remote", "reliable", 0)
func lock_in(turn: Variant) -> void:
	if _match == null or typeof(turn) != TYPE_INT:
		return
	_match.lock_in(multiplayer.get_remote_sender_id(), int(turn))


@rpc("any_peer", "call_remote", "reliable", 0)
func playback_done(turn: Variant) -> void:
	if _match == null or typeof(turn) != TYPE_INT:
		return
	_match.playback_done(multiplayer.get_remote_sender_id(), int(turn))


# --- client -------------------------------------------------------------------

func send_orders(turn: int, orders: Array) -> void:
	submit_orders.rpc_id(1, turn, orders)


func send_lock_in(turn: int) -> void:
	lock_in.rpc_id(1, turn)


func send_playback_done(turn: int) -> void:
	playback_done.rpc_id(1, turn)


## Back to select: what arrives next may be a spectator's, so the tally forgets our side.
func leave_to_select() -> void:
	super()
	tally.forget_side()


@rpc("authority", "call_remote", "reliable", 0)
func turn_started(payload: Dictionary) -> void:
	if config.is_server:
		return
	var view: Dictionary = payload.get("view", {})
	tally.on_view(map, view)
	turn_started_received.emit(float(payload.get("seconds_left", 0.0)), view)
	if config.bot and tally.team >= 0:
		if _bot == null:
			_bot = FlagBot.new(multiplayer.get_unique_id())
		var turn: int = view["turn"]
		send_orders(turn, _bot.orders(map, view))
		send_lock_in(turn)


@rpc("authority", "call_remote", "reliable", 0)
func turn_resolved(payload: Dictionary) -> void:
	if config.is_server:
		return
	tally.on_turn(map, payload)
	turn_resolved_received.emit(payload)
	if auto_playback_done or config.bot:
		send_playback_done(int(payload.get("turn", -1)))


@rpc("authority", "call_remote", "reliable", 0)
func match_over(payload: Dictionary) -> void:
	if config.is_server:
		return
	matches_over += 1
	match_over_received.emit(payload)


# --- smoke test ---------------------------------------------------------------

## Replaces GameBase's moving-player latch (FlagPerson has no rendered_distance).
func _process(_delta: float) -> void:
	if config.is_server or config.run_seconds <= 0.0 or not Net.is_online():
		return
	var people: Array[Node] = active_players()
	_max_simultaneous = maxi(_max_simultaneous, people.size())
	for p: Node in people:
		_peers_seen[p.name] = true


func smoke_report() -> Dictionary:
	if config.is_server:
		var ok: bool = _match.turns_resolved >= 3 and _match.moved == [true, true] \
				and _match.invalid_orders == 0
		return {"ok": ok, "turns": _match.turns_resolved, "moved": _match.moved,
				"invalid_orders": _match.invalid_orders, "peers_seen": _peers_seen.size()}
	var ok_client: bool = Net.is_online() and tally.turns >= 3 and tally.own_moved \
			and tally.leaks == 0 and own_spawns > reselects
	return {"ok": ok_client, "peer": multiplayer.get_unique_id() if Net.is_online() else 0,
			"turns": tally.turns, "leaks": tally.leaks, "own_moved": tally.own_moved,
			"matches_over": matches_over, "reselects": reselects, "own_spawns": own_spawns,
			"max_simultaneous": _max_simultaneous}
