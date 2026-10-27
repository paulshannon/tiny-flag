extends TestCase
## FlagMatch and spectators (split from test_tiny_flag_match.gd to keep files short).

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


func test_third_person_spectates_one_turn_late() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.add_person(30)
	assert_eq(fm.team_of(30), SPEC)
	assert_eq(_all_to(30).size(), 0, "a mid-match spectator gets nothing while turn 1 is planned")
	var prev: FlagState = null
	for n: int in range(1, 6):
		# Everything the spectator has while turn n is planned is from before turn n.
		for s: Array in _all_to(30):
			if s[1] == "turn_started":
				assert_true(s[2]["view"]["turn"] <= n - 1, "view of turn %d during %d" % [s[2]["view"]["turn"], n])
				assert_eq(s[2]["view"]["team"], SPEC)
			elif s[1] == "turn_resolved":
				assert_true(s[2]["turn"] <= n - 2, "playback of turn %d during %d" % [s[2]["turn"], n])
		var count := _all_to(30).size()
		var before := fm.state.copy()
		fm.lock_in(10, n)
		fm.lock_in(20, n)
		var got: Array = _all_to(30).slice(count)
		assert_eq(got.size(), 1)
		assert_eq(got[0][1], "turn_resolved")
		assert_eq(got[0][2]["turn"], n - 1, "the previous turn")
		if prev != null:
			# Nobody sent orders, so the previous turn resolves the same way again here;
			# the spectator gets its public playback (FlagWire.SPECTATOR), nothing more.
			var o := FlagResolver.resolve(_map(), prev, {})
			assert_eq(got[0][2], FlagWire.turn_for(_map(), o, SPEC))
		prev = before
		fm.playback_done(10, n)
		fm.playback_done(20, n)
		got = _all_to(30).slice(count + 1)
		assert_eq(got.size(), 1)
		assert_eq(got[0][1], "turn_started")
		assert_eq(got[0][2]["view"]["turn"], n, "the board before the turn just resolved")
		assert_eq(got[0][2]["view"], FlagWire.view_for(_map(), before, SPEC))


func test_spectator_takes_a_freed_side_next_turn() -> void:
	var fm := _match(_map())
	_two_people(fm)
	fm.add_person(30)
	fm.remove_person(20)
	assert_eq(fm.side_peer(B), 0)
	fm.lock_in(10, 1)
	fm.playback_done(10, 1)
	assert_eq(fm.side_peer(B), 30)
	assert_eq(fm.team_of(30), B)
	var last: Array = _all_to(30)
	assert_eq(last[last.size() - 1][2]["view"]["team"], B)
