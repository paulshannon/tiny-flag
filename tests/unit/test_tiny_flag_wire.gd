extends TestCase

const R := FlagMap.RED
const B := FlagMap.BLUE
const W := 24
const H := 11


## 24x11 grass board with a base in each top corner; `put` maps tile -> map character.
func _map(put: Dictionary = {}) -> FlagMap:
	var rows: Array[String] = []
	for y: int in H:
		var row := ""
		for x: int in W:
			var c := "."
			if y < 3 and x < 3:
				c = "R"
			elif y < 3 and x >= W - 3:
				c = "U"
			if put.has(Vector2i(x, y)):
				c = put[Vector2i(x, y)]
			row += c
		rows.append(row)
	return FlagMap.parse("\n".join(rows))


func _p(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		out.append(t)
	return out


func _ids(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append(r[0])
	return out


func _has_id(rows: Array, id: int) -> bool:
	return _ids(rows).has(id)


func test_view_hides_enemy_in_crops() -> void:
	var m := _map({Vector2i(12, 5): "w"})
	var s := FlagState.new_match(m)
	s.piece(0).tile = Vector2i(10, 5)
	s.piece(5).tile = Vector2i(12, 5)  # in crops, two tiles away
	s.piece(6).tile = Vector2i(13, 5)  # on grass, three tiles away
	var v := FlagWire.view_for(m, s, R)
	var rows: Array = v["pieces"]
	assert_false(_has_id(rows, 5), "enemy in crops hidden")
	assert_true(_has_id(rows, 6), "enemy on grass seen")
	for id: int in range(0, 5):
		assert_true(_has_id(rows, id), "own piece %d present" % id)
	assert_eq(rows.size(), 6)
	# Next to the crops it shows.
	s.piece(0).tile = Vector2i(11, 5)
	assert_true(_has_id(FlagWire.view_for(m, s, R)["pieces"], 5), "adjacent crops piece seen")


func test_view_shape_and_row_format() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	s.turn = 7
	s.score = [1, 2]
	s.piece(0).tile = Vector2i(10, 5)
	s.piece(0).tagged = true
	s.carrier[B] = 0
	s.piece(5).tile = Vector2i(11, 5)
	s.carrier[R] = 5
	var v := FlagWire.view_for(m, s, R)
	assert_eq(v["turn"], 7)
	assert_eq(v["team"], R)
	assert_eq(v["score"], [1, 2])
	assert_eq(v["turn_limit"], FlagState.TURN_LIMIT)
	assert_eq(v["result"], int(s.result()))
	var rows: Array = v["pieces"]
	assert_eq(rows[0], [0, R, 10, 5, 1, 1])
	assert_eq(rows[5], [5, B, 11, 5, 1, 0])
	assert_eq(v["flags"], [[11, 5], [10, 5]], "Red flag on piece 5, Blue flag on piece 0")


func test_flags_home_in_view() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	var f: Array = FlagWire.view_for(m, s, B)["flags"]
	assert_eq(f, [[m.flag_home(R).x, m.flag_home(R).y], [m.flag_home(B).x, m.flag_home(B).y]])


func test_carrier_far_away_is_in_view() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	s.piece(5).tile = Vector2i(20, 9)
	s.carrier[R] = 5
	assert_true(_has_id(FlagWire.view_for(m, s, R)["pieces"], 5), "carrier always visible")
	s.carrier[R] = -1
	assert_false(_has_id(FlagWire.view_for(m, s, R)["pieces"], 5), "same piece, no flag: hidden")


func test_spectator_view_is_the_public_view() -> void:
	var m := _map({Vector2i(12, 5): "w"})
	var s := FlagState.new_match(m)
	s.piece(0).tile = Vector2i(10, 5)   # Red, two tiles from Blue 5: Blue sees it
	s.piece(5).tile = Vector2i(12, 5)   # Blue in crops two tiles away: Red can't see it
	s.piece(6).tile = Vector2i(9, 5)    # Blue on grass next to Red 0: both sides see it
	s.piece(1).tile = Vector2i(20, 9)   # Red carrying Blue's flag far from everyone
	s.carrier[B] = 1
	var v := FlagWire.view_for(m, s, FlagWire.SPECTATOR)
	assert_eq(v["team"], FlagWire.SPECTATOR)
	var rows: Array = v["pieces"]
	assert_false(_has_id(rows, 5), "enemy hidden in crops stays hidden from spectators")
	assert_true(_has_id(rows, 0), "Red piece Blue can see")
	assert_true(_has_id(rows, 6), "Blue piece Red can see")
	assert_true(_has_id(rows, 1), "a carrier is always public")
	assert_false(_has_id(rows, 2), "Red piece at home, out of Blue's sight")
	assert_false(_has_id(rows, 7), "Blue piece at home, out of Red's sight")
	assert_eq(_ids(rows), [0, 1, 6])


func test_turn_for_drops_enemy_once_it_enters_corn() -> void:
	var m := _map({Vector2i(13, 5): "w"})
	var s := FlagState.new_match(m)
	s.turn = 3
	s.piece(0).tile = Vector2i(10, 5)
	s.piece(5).tile = Vector2i(12, 5)
	# Crops cost 4 half-points, so piece 5 enters (13,5) at tick 4.
	var o := FlagResolver.resolve(m, s, {5: _p([Vector2i(13, 5)])})
	var t := FlagWire.turn_for(m, o, R)
	assert_eq(t["turn"], 3, "the turn that was resolved")
	var ticks: Array = t["ticks"]
	assert_eq(ticks.size(), FlagState.TICKS)
	assert_true(_has_id(ticks[0], 5), "tick 1 visible")
	assert_true(_has_id(ticks[1], 5), "tick 2 visible on grass")
	assert_true(_has_id(ticks[2], 5), "tick 3 still on grass")
	for k: int in range(3, 8):
		assert_false(_has_id(ticks[k], 5), "tick %d hidden in crops" % (k + 1))
	for k: int in 8:
		assert_true(_has_id(ticks[k], 0), "own piece every tick")
	# Blue sees its own piece throughout, and Red's piece 0 while in range.
	var tb := FlagWire.turn_for(m, o, B)
	assert_true(_has_id(tb["ticks"][7], 5))
	assert_true(_has_id(tb["ticks"][0], 0), "piece 5 at (12,5) sees (10,5)")
	assert_false(_has_id(tb["ticks"][0], 1), "but not Red's piece at home")


func test_events_witnessed_only() -> void:
	var m := _map({Vector2i(14, 5): "w"})
	var s := FlagState.new_match(m)
	s.turn = 4
	s.piece(0).tile = Vector2i(10, 5)
	# Hand-built outcome (a Blue-vs-Blue "tag" can't happen in play, so the tile clause
	# is exercised directly): Blue piece 5 sits in crops far from Red, piece 6 elsewhere.
	s.piece(5).tile = Vector2i(14, 5)
	s.piece(6).tile = Vector2i(20, 9)
	var o := FlagResolver.Outcome.new()
	for k: int in FlagState.TICKS:
		o.ticks.append(s.copy())
	o.state = s.copy()
	o.state.turn = 5
	o.events = [
		{"tick": 1, "kind": "tag", "piece": 5, "by": 6},   # hidden tile for Red
		{"tick": 2, "kind": "tag", "piece": 0, "by": 6},   # Red's own piece
		{"tick": 3, "kind": "tag", "piece": 6, "by": 0},   # Red is the tagger
		{"tick": 4, "kind": "pickup", "piece": 6, "flag": R},
		{"tick": 5, "kind": "capture", "piece": 6, "team": B},
	]
	var red := FlagWire.turn_for(m, o, R)
	assert_eq(red["turn"], 4)
	var kinds: Array = []
	for e: Dictionary in red["events"]:
		kinds.append("%s%d" % [e["kind"], e["tick"]])
	assert_eq(kinds, ["tag2", "tag3", "pickup4", "capture5"], "unseen enemy-only tag dropped")
	# Blue sees tile (14,5) with its own pieces, so it keeps every event.
	assert_eq((FlagWire.turn_for(m, o, B)["events"] as Array).size(), 5)
	# Spectators keep a tag only when both pieces are in their rows: Red sees neither 5
	# (crops) nor 6 (far away), so only the pickup and the capture remain.
	var spec_kinds: Array = []
	for e: Dictionary in FlagWire.turn_for(m, o, FlagWire.SPECTATOR)["events"]:
		spec_kinds.append("%s%d" % [e["kind"], e["tick"]])
	assert_eq(spec_kinds, ["pickup4", "capture5"])
	# Events are copies: editing the filtered output leaves the outcome alone.
	(red["events"] as Array)[0]["tick"] = 99
	assert_eq(o.events[1]["tick"], 2)


func test_tag_between_teams_is_kept_for_both() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	s.piece(0).tile = Vector2i(4, 5)
	s.piece(5).tile = Vector2i(6, 5)
	var o := FlagResolver.resolve(m, s, {5: _p([Vector2i(5, 5), Vector2i(4, 5)])})
	for team: int in [R, B, FlagWire.SPECTATOR]:
		var evs: Array = FlagWire.turn_for(m, o, team)["events"]
		assert_eq(evs.size(), 1, "team %d sees the tag" % team)
		assert_eq(evs[0]["kind"], "tag")


func test_leak_check_catches_a_leak() -> void:
	var m := _map({Vector2i(12, 5): "w"})
	var rows: Array = [
		[0, R, 10, 5, 0, 0],
		[1, R, 1, 1, 0, 0],
		[5, B, 12, 5, 0, 0],   # in crops two tiles away: not visible
		[6, B, 13, 5, 0, 0],   # grass, visible
		[7, B, 22, 9, 1, 0],   # carrier, visible anywhere
		[8, B, 22, 9, 0, 0],   # same tile, not carrying: leak
	]
	assert_eq(FlagWire.leaked_enemies(m, R, rows), [5, 8] as Array[int])
	assert_eq(FlagWire.leaked_enemies(m, B, rows), [1] as Array[int], "Blue sees Red 0 from 2 tiles, not Red 1")
