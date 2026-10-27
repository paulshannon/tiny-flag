extends TestCase

const R := FlagMap.RED
const B := FlagMap.BLUE
const SPEC := FlagWire.SPECTATOR

## Every message FlagMatch sent: [peer, kind, payload].
var sent: Array = []


func _record(peer: int, kind: String, payload: Dictionary) -> void:
	sent.append([peer, kind, payload])


func _map() -> FlagMap:
	return FlagMap.load_map(FlagMap.FARM_PATH)


func _match(m: FlagMap) -> FlagMatch:
	sent = []
	return FlagMatch.new(m, _record)


## Payloads of `kind` sent to `peer`, in order.
func _to(peer: int, kind: String) -> Array:
	var out: Array = []
	for s: Array in sent:
		if s[0] == peer and s[1] == kind:
			out.append(s[2])
	return out


func _all_to(peer: int) -> Array:
	var out: Array = []
	for s: Array in sent:
		if s[0] == peer:
			out.append(s)
	return out


## Peer 10 plays Red, peer 20 Blue, at the start of turn 1.
func _two_people(fm: FlagMatch) -> void:
	fm.add_person(10)
	fm.add_person(20)
	fm.lock_in(10, 0)
	fm.playback_done(10, 0)
	assert_eq(fm.side_peer(B), 20, "second person takes Blue at turn 1")
	assert_eq(fm.state.turn, 1)
	sent.clear()


## A one-tile order for piece `id`: its first passable neighbour within budget.
func _step(m: FlagMap, s: FlagState, id: int) -> Array:
	var at := s.piece(id).tile
	for d: Vector2i in FlagPath.DIRS:
		var n := at + d
		var c := m.cost(n)
		if c >= 0 and c <= s.move_points(id):
			var path: Array[Vector2i] = [n]
			return [id, FlagPath.encode(path)]
	return []


func test_first_person_plays_red_against_bot() -> void:
	var fm := _match(_map())
	assert_eq(fm.phase, FlagMatch.Phase.WAITING)
	fm.add_person(10)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.side_peer(R), 10)
	assert_eq(fm.side_peer(B), 0)
	var started := _to(10, "turn_started")
	assert_eq(started.size(), 1)
	var p: Dictionary = started[0]
	assert_eq(p["view"]["team"], R)
	assert_eq(p["view"]["turn"], 0)
	assert_near(p["seconds_left"], FlagMatch.PLAN_SECONDS)


func test_both_locked_resolves_and_sends_each_side_its_own() -> void:
	var m := _map()
	var fm := _match(m)
	_two_people(fm)
	var before := fm.state.copy()
	fm.lock_in(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING, "one lock is not enough")
	assert_eq(_to(10, "turn_resolved").size(), 0)
	fm.lock_in(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)
	var expect := FlagResolver.resolve(m, before, {})
	var red: Array = _to(10, "turn_resolved")
	var blue: Array = _to(20, "turn_resolved")
	assert_eq(red.size(), 1)
	assert_eq(blue.size(), 1)
	assert_eq(red[0], FlagWire.turn_for(m, expect, R))
	assert_eq(blue[0], FlagWire.turn_for(m, expect, B))
	assert_true(red[0] != blue[0], "each side gets its own filtered playback")
	assert_eq(fm.turns_resolved, 2)


func test_timer_resolves_without_lock() -> void:
	var fm := _match(_map())
	fm.add_person(10)
	fm.tick(29.0)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.turns_resolved, 0)
	fm.tick(1.0)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)
	assert_eq(fm.turns_resolved, 1)
	assert_eq(_to(10, "turn_resolved").size(), 1)


func test_next_turn_waits_for_playback_done_or_cap() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.lock_in(10, 1)
	fm.lock_in(20, 1)
	fm.playback_done(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK, "waits for both sides")
	fm.playback_done(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.state.turn, 2)
	# Nobody reports: the cap starts the next turn.
	fm.lock_in(10, 2)
	fm.lock_in(20, 2)
	fm.tick(3.5)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)
	fm.tick(0.5)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.state.turn, 3)
	var started: Array = _to(20, "turn_started")
	assert_near(started[started.size() - 1]["seconds_left"], FlagMatch.PLAN_SECONDS)


func test_disconnect_mid_planning_hands_side_to_bot() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.remove_person(20)
	assert_eq(fm.side_peer(B), 0)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	fm.lock_in(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK, "the bot locked for the leaver")
	# The other order: the remaining person already locked when the other leaves.
	var fm2 := _match(_map())
	_two_people(fm2)
	fm2.lock_in(20, 1)
	fm2.remove_person(10)
	assert_eq(fm2.side_peer(R), 0)
	assert_eq(fm2.phase, FlagMatch.Phase.PLAYBACK)
	assert_eq(fm2.turns_resolved, 2)


func test_disconnect_mid_playback_does_not_stall() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.lock_in(10, 1)
	fm.lock_in(20, 1)
	fm.playback_done(10, 1)
	fm.remove_person(20)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING, "the leaver's playback_done is implied")
	assert_eq(fm.state.turn, 2)
	assert_eq(fm.side_peer(B), 0)
	fm.lock_in(10, 2)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)


func test_newcomer_takes_bot_side_next_turn() -> void:
	var fm := _match(_map())
	fm.add_person(10)
	fm.add_person(20)
	assert_eq(fm.side_peer(B), 0, "the bot keeps Blue for the current turn")
	assert_eq(_all_to(20).size(), 0, "nothing until the takeover")
	fm.lock_in(10, 0)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK, "the bot's lock for turn 0 stands")
	assert_true(fm.moved[B], "the bot's turn 0 orders were played")
	assert_eq(_all_to(20).size(), 0)
	fm.playback_done(10, 0)
	assert_eq(fm.side_peer(B), 20)
	var first: Array = _all_to(20)
	assert_eq(first.size(), 1)
	assert_eq(first[0][1], "turn_started")
	assert_eq(first[0][2]["view"]["team"], B)
	assert_eq(first[0][2]["view"]["turn"], 1)
	# Blue is now a person's: the turn waits for them.
	fm.lock_in(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	fm.lock_in(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)


func test_resubmit_replaces_orders() -> void:
	var m := _map()
	var fm := _match(m)
	_two_people(fm)
	var start0 := fm.state.piece(0).tile
	var order0 := _step(m, fm.state, 0)
	var order1 := _step(m, fm.state, 1)
	fm.submit(10, 1, [order0])
	fm.lock_in(10, 1)
	fm.submit(10, 1, [order1])
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	fm.lock_in(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK, "a submit after lock_in keeps the side locked")
	assert_eq(fm.state.piece(0).tile, start0, "the earlier order was replaced")
	var p1: PackedInt32Array = order1[1]
	assert_eq(fm.state.piece(1).tile, Vector2i(p1[0], p1[1]))
	assert_eq(fm.invalid_orders, 0)


func test_wrong_turn_and_stranger_orders_ignored() -> void:
	var m := _map()
	var fm := _match(m)
	_two_people(fm)
	var start0 := fm.state.piece(0).tile
	var order0 := _step(m, fm.state, 0)
	fm.submit(99, 1, [order0])
	fm.submit(10, 0, [order0])
	fm.submit(10, 2, [order0])
	fm.lock_in(99, 1)
	fm.lock_in(10, 0)
	fm.playback_done(10, 1)
	fm.playback_done(20, 0)
	fm.lock_in(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING, "Red's stale lock_in did not count")
	assert_eq(fm.invalid_orders, 0)
	# Blue ordering a Red piece, plus junk: dropped and counted.
	fm.submit(20, 1, [order0, "junk"])
	assert_eq(fm.invalid_orders, 2)
	fm.submit(20, 1, {"a": 1})
	assert_eq(fm.invalid_orders, 3)
	fm.lock_in(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK)
	assert_eq(fm.state.piece(0).tile, start0)
	fm.submit(10, 2, [order0])
	fm.lock_in(10, 2)
	fm.playback_done(10, 5)
	fm.playback_done(20, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLAYBACK, "playback_done for the wrong turn ignored")
	fm.playback_done(10, 1)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.state.turn, 2)


func test_match_over_then_restart() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.add_person(30)
	fm.state.turn = FlagState.TURN_LIMIT - 1
	fm.state.score = [1, 0]
	fm.lock_in(10, FlagState.TURN_LIMIT - 1)
	fm.lock_in(20, FlagState.TURN_LIMIT - 1)
	assert_eq(fm.phase, FlagMatch.Phase.OVER)
	for peer: int in [10, 20, 30]:
		var over: Array = _to(peer, "match_over")
		assert_eq(over.size(), 1, "match_over to %d" % peer)
		assert_eq(over[0]["result"], int(FlagState.Result.RED_WINS))
		assert_eq(over[0]["score"], [1, 0])
	fm.playback_done(10, FlagState.TURN_LIMIT - 1)
	fm.playback_done(20, FlagState.TURN_LIMIT - 1)
	assert_eq(fm.phase, FlagMatch.Phase.OVER, "playback_done does not cut the result short")
	fm.tick(9.5)
	assert_eq(fm.phase, FlagMatch.Phase.OVER)
	sent.clear()
	fm.tick(0.5)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
	assert_eq(fm.state.turn, 0)
	assert_eq(fm.state.score, [0, 0])
	assert_eq(fm.side_peer(R), 10)
	assert_eq(fm.side_peer(B), 20)
	assert_eq(_to(10, "turn_started")[0]["view"]["team"], R)
	assert_eq(_to(20, "turn_started")[0]["view"]["team"], B)
	assert_eq(_to(20, "turn_started")[0]["view"]["turn"], 0)
	assert_eq(_all_to(30).size(), 0, "a spectator has no previous turn to see yet")


func test_everyone_leaving_waits_for_a_new_match() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.remove_person(10)
	fm.remove_person(20)
	assert_eq(fm.phase, FlagMatch.Phase.WAITING)
	fm.tick(100.0)
	assert_eq(fm.phase, FlagMatch.Phase.WAITING)
	fm.add_person(40)
	assert_eq(fm.side_peer(R), 40)
	assert_eq(fm.state.turn, 0)
	assert_eq(fm.phase, FlagMatch.Phase.PLANNING)
