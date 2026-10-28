class_name FlagMatch
extends RefCounted
## The server's Tiny Flag match: phases, planning timer, sides (person or bot) and
## spectators (spec §1 "Turns", "Winning", "Who plays"; §2 "Playback"; §3 "Messages").
## No networking and no scene tree: TinyFlagGame calls in with what peers did and the
## time that passed, and FlagMatch answers through `send`, so all of it is unit-tested.
##
## send.call(peer, kind, payload):
## - "turn_started"  {"seconds_left": float, "view": FlagWire.view_for(...)}
## - "turn_resolved" FlagWire.turn_for(...) ({"turn", "ticks", "events"})
## - "match_over"    {"result": int, "score": [red, blue]}
##
## Spectators get the public view (FlagWire.SPECTATOR: only pieces both teams can see) and
## run one turn behind on top of that: at the start of turn N they get the board at the
## start of turn N-1, and when turn N resolves they get turn N-1's playback.

enum Phase { WAITING, PLANNING, PLAYBACK, OVER }

const PLAN_SECONDS: float = 30.0
const PLAYBACK_CAP: float = 4.0
const RESULT_SECONDS: float = 10.0

var phase: Phase = Phase.WAITING
var state: FlagState

## Smoke counters.
var turns_resolved: int = 0
## moved[team]: some piece of that team walked to another tile in a resolve.
var moved: Array[bool] = [false, false]
## People's orders dropped by FlagPath.validate_orders (bots' are not counted).
var invalid_orders: int = 0

var _map: FlagMap
var _send: Callable
var _seed: int
var _sides := FlagSides.new()
var _bots: Array[FlagBot] = []
## Seconds left in the current phase (planning, playback cap or result screen).
var _left: float = 0.0
## Per team, this turn's validated orders: {piece_id: Array[Vector2i]}.
var _orders: Array[Dictionary] = [{}, {}]
var _locked: Array[bool] = [false, false]
var _done: Array[bool] = [false, false]
## For spectators: the board at the start of the last resolved turn, and its outcome.
var _prev_start: FlagState = null
var _prev_outcome: FlagResolver.Outcome = null


func _init(map: FlagMap, send: Callable, seed_value: int = 0) -> void:
	_map = map
	_send = send
	_seed = seed_value
	_new_match()


## 0 when a bot plays `team`.
func side_peer(team: int) -> int:
	return _sides.peer[team]


## The side `peer` plays now, else FlagWire.SPECTATOR (also while waiting to take one).
func team_of(peer: int) -> int:
	return _sides.team_of(peer)


func add_person(peer: int) -> void:
	if peer <= 0 or _sides.has(peer):
		return
	_sides.add(peer)
	if phase == Phase.WAITING:
		_start_turn()


## The side passes to a bot at once, and the bot gives anything the side still owed.
func remove_person(peer: int) -> void:
	var team := _sides.remove(peer)
	if _sides.is_empty():
		_new_match()
		return
	if team < 0:
		return
	if phase == Phase.PLANNING and not _locked[team]:
		_bot_orders(team)
		if _locked[FlagMap.RED] and _locked[FlagMap.BLUE]:
			_resolve()
	elif phase == Phase.PLAYBACK and not _done[team]:
		_done[team] = true
		if _done[FlagMap.RED] and _done[FlagMap.BLUE]:
			_start_turn()


## Replaces the side's orders for the turn; a locked side stays locked.
func submit(peer: int, turn: int, raw: Variant) -> void:
	var team := _planning_team(peer, turn)
	if team < 0:
		return
	var valid := FlagPath.validate_orders(_map, state, team, raw)
	var given := 1
	if typeof(raw) == TYPE_ARRAY:
		var entries: Array = raw
		given = entries.size()
	invalid_orders += maxi(given - valid.size(), 0)
	_orders[team] = valid


func lock_in(peer: int, turn: int) -> void:
	var team := _planning_team(peer, turn)
	if team < 0:
		return
	_locked[team] = true
	if _locked[FlagMap.RED] and _locked[FlagMap.BLUE]:
		_resolve()


## `turn` is the turn that was played back (turn_resolved's "turn").
func playback_done(peer: int, turn: int) -> void:
	var team := _sides.team_of(peer)
	if team < 0 or phase != Phase.PLAYBACK or turn != state.turn - 1:
		return
	_done[team] = true
	if _done[FlagMap.RED] and _done[FlagMap.BLUE]:
		_start_turn()


## The server calls this every physics frame.
func tick(delta: float) -> void:
	if phase == Phase.WAITING:
		return
	_left -= delta
	if _left > 0.0:
		return
	match phase:
		Phase.PLANNING:
			_resolve()
		Phase.PLAYBACK:
			_start_turn()
		Phase.OVER:
			_new_match()
			_start_turn()


## The side `peer` plays, if it is planning `turn`; else -1.
func _planning_team(peer: int, turn: int) -> int:
	if phase != Phase.PLANNING or turn != state.turn:
		return -1
	return _sides.team_of(peer)


## A fresh board and bots; WAITING until a turn starts.
func _new_match() -> void:
	state = FlagState.new_match(_map)
	_bots = [FlagBot.new(_seed + FlagMap.RED), FlagBot.new(_seed + FlagMap.BLUE)]
	_prev_start = null
	_prev_outcome = null
	phase = Phase.WAITING


func _start_turn() -> void:
	_sides.apply_pending()
	phase = Phase.PLANNING
	_left = PLAN_SECONDS
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		_orders[team] = {}
		_locked[team] = false
		_done[team] = false
		var peer: int = _sides.peer[team]
		if peer == 0:
			_bot_orders(team)
		else:
			_send.call(peer, "turn_started", {"seconds_left": _left, "view": FlagWire.view_for(_map, state, team)})
	if _prev_start != null:
		var view := FlagWire.view_for(_map, _prev_start, FlagWire.SPECTATOR)
		_to_spectators("turn_started", {"seconds_left": _left, "view": view})


## The bot playing `team` orders from its own view and locks in.
func _bot_orders(team: int) -> void:
	var raw := _bots[team].orders(_map, FlagWire.view_for(_map, state, team))
	_orders[team] = FlagPath.validate_orders(_map, state, team, raw)
	_locked[team] = true


func _resolve() -> void:
	var merged: Dictionary = {}
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		merged.merge(_orders[team])
	var start := state
	var outcome := FlagResolver.resolve(_map, start, merged)
	turns_resolved += 1
	_count_moves(start, outcome)
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		var peer: int = _sides.peer[team]
		if peer != 0:
			_send.call(peer, "turn_resolved", FlagWire.turn_for(_map, outcome, team))
	if _prev_outcome != null:
		_to_spectators("turn_resolved", FlagWire.turn_for(_map, _prev_outcome, FlagWire.SPECTATOR))
	_prev_start = start
	_prev_outcome = outcome
	state = outcome.state
	var result := state.result()
	if result != FlagState.Result.ONGOING:
		# Nothing is planned any more, so spectators catch up on the last turn.
		_to_spectators("turn_resolved", FlagWire.turn_for(_map, outcome, FlagWire.SPECTATOR))
		var over := {"result": int(result), "score": [state.score[FlagMap.RED], state.score[FlagMap.BLUE]]}
		for team: int in [FlagMap.RED, FlagMap.BLUE]:
			if _sides.peer[team] != 0:
				_send.call(_sides.peer[team], "match_over", over)
		_to_spectators("match_over", over)
		phase = Phase.OVER
		_left = RESULT_SECONDS
		return
	phase = Phase.PLAYBACK
	_left = PLAYBACK_CAP
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		_done[team] = _sides.peer[team] == 0
	if _done[FlagMap.RED] and _done[FlagMap.BLUE]:
		_start_turn()


## A team moved if one of its pieces, untagged at the start, stood elsewhere at any tick.
func _count_moves(start: FlagState, outcome: FlagResolver.Outcome) -> void:
	for p: FlagState.Piece in start.pieces:
		# p.tagged is defensive: tagged pieces respawn at turn end, so a turn's
		# start state has none.
		if p.tagged or moved[p.team]:
			continue
		for snap: FlagState in outcome.ticks:
			if snap.piece(p.id).tile != p.tile:
				moved[p.team] = true
				break


func _to_spectators(kind: String, payload: Dictionary) -> void:
	for peer: int in _sides.spectators:
		_send.call(peer, kind, payload)
