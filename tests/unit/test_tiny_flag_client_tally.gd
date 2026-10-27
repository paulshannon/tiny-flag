extends TestCase

const R := FlagMap.RED
const B := FlagMap.BLUE
const W := 24
const H := 11


## 24x11 grass board with a base in each top corner.
func _map() -> FlagMap:
	var rows: Array[String] = []
	for y: int in H:
		var row := ""
		for x: int in W:
			var c := "."
			if y < 3 and x < 3:
				c = "R"
			elif y < 3 and x >= W - 3:
				c = "U"
			row += c
		rows.append(row)
	return FlagMap.parse("\n".join(rows))


func _view(team: int, pieces: Array) -> Dictionary:
	return {"turn": 1, "team": team, "pieces": pieces}


func test_counts_turns_for_spectators_without_checks() -> void:
	var t := FlagClientTally.new()
	# Spectator rows aren't one side's view, so no leak is counted for a spectator.
	t.on_turn(_map(), {"turn": 1, "ticks": [[[0, R, 0, 10, 0, 0], [5, B, 23, 10, 0, 0]]], "events": []})
	assert_eq(t.turns, 1)
	assert_eq(t.leaks, 0)
	assert_false(t.own_moved)


func test_counts_an_enemy_out_of_sight_in_a_view_as_a_leak() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 0, 10, 0, 0], [5, B, 23, 10, 0, 0]]))
	assert_eq(t.leaks, 1)
	assert_eq(t.team, R)


func test_visible_enemy_and_carrier_are_not_leaks() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 5, 5, 0, 0], [5, B, 7, 5, 0, 0], [6, B, 23, 10, 1, 0]]))
	assert_eq(t.leaks, 0)


func test_checks_every_tick_of_a_turn() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 5, 5, 0, 0]]))
	var ticks: Array = [
		[[0, R, 5, 5, 0, 0], [5, B, 7, 5, 0, 0]],
		[[0, R, 5, 5, 0, 0], [5, B, 20, 5, 0, 0]],   # out of sight: leaked
		[[0, R, 5, 5, 0, 0]],
	]
	t.on_turn(_map(), {"turn": 1, "ticks": ticks, "events": []})
	assert_eq(t.leaks, 1)
	assert_eq(t.turns, 1)


func test_own_moved_from_the_view() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 5, 5, 0, 0]]))
	t.on_turn(_map(), {"turn": 1, "ticks": [[[0, R, 5, 5, 0, 0]]], "events": []})
	assert_false(t.own_moved, "standing still is not moving")
	t.on_turn(_map(), {"turn": 2, "ticks": [[[0, R, 5, 5, 0, 0]], [[0, R, 6, 5, 0, 0]]], "events": []})
	assert_true(t.own_moved)


func test_enemy_moving_is_not_own_moved() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 5, 5, 0, 0], [5, B, 7, 5, 0, 0]]))
	t.on_turn(_map(), {"turn": 1, "ticks": [[[0, R, 5, 5, 0, 0], [5, B, 8, 5, 0, 0]]], "events": []})
	assert_false(t.own_moved)


func test_forget_side_stops_checks_until_the_next_view() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), _view(R, [[0, R, 5, 5, 0, 0]]))
	t.forget_side()
	assert_eq(t.team, FlagWire.SPECTATOR)
	# A spectator's playback isn't Red's view; with the old side kept this would leak.
	t.on_turn(_map(), {"turn": 1, "ticks": [[[0, R, 0, 10, 0, 0], [5, B, 23, 10, 0, 0]]], "events": []})
	assert_eq(t.leaks, 0)


func test_malformed_payload_is_ignored() -> void:
	var t := FlagClientTally.new()
	t.on_view(_map(), {"team": R, "pieces": "junk"})
	t.on_turn(_map(), {"turn": 1, "ticks": "junk"})
	t.on_turn(_map(), {"turn": 1, "ticks": [[["x"]], "junk"]})
	assert_eq(t.leaks, 0)
