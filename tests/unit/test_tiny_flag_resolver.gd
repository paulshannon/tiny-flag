extends TestCase

const R := FlagMap.RED
const B := FlagMap.BLUE
## 12x3: Red base x 0-2 (flag at 1,1), Blue base x 9-11 (flag at 10,1); halves split at x = 6.
## Red homes (0,0) (1,0) (2,0) (0,1) (2,1); Blue homes (9,0) (10,0) (11,0) (9,1) (11,1).
const GRASS := "RRR......UUU\nRRR......UUU\nRRR......UUU"
## Same, with a dirt path (cost 1) along row 1 between the bases.
const DIRT := "RRR......UUU\nRRR======UUU\nRRR......UUU"


func _setup(text: String = GRASS) -> Array:
	var m := FlagMap.parse(text)
	return [m, FlagState.new_match(m)]


func _p(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		out.append(t)
	return out


## Plain-data form of a state, for equality checks.
func _rows(s: FlagState) -> Array:
	var out: Array = [s.turn, s.score.duplicate(), s.carrier.duplicate()]
	for p: FlagState.Piece in s.pieces:
		out.append([p.id, p.team, p.tile.x, p.tile.y, int(s.is_carrying(p.id)), int(p.tagged)])
	return out


func _to_rows(o: FlagResolver.Outcome) -> Array:
	var ticks: Array = []
	for t: FlagState in o.ticks:
		ticks.append(_rows(t))
	return [_rows(o.state), ticks, o.events.duplicate(true)]


func _tag(tick: int, piece: int, by: int) -> Dictionary:
	return {"tick": tick, "kind": "tag", "piece": piece, "by": by}


func test_same_tile_on_red_half_tags_blue() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.piece(5).tile = Vector2i(6, 1)
	var o := FlagResolver.resolve(m, s, {5: _p([Vector2i(5, 1), Vector2i(4, 1)])})
	assert_true(o.state.piece(5).tagged, "visitor tagged")
	assert_false(o.state.piece(0).tagged, "defender untouched")
	assert_eq(o.state.piece(5).tile, Vector2i(4, 1))
	assert_eq(o.events, [_tag(4, 5, 0)] as Array[Dictionary])


func test_same_tile_on_blue_half_tags_red() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(5, 1)
	s.piece(5).tile = Vector2i(7, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(6, 1), Vector2i(7, 1)])})
	assert_true(o.state.piece(0).tagged)
	assert_false(o.state.piece(5).tagged)
	assert_eq(o.events, [_tag(4, 0, 5)] as Array[Dictionary])


func test_swap_on_one_half_tags_visitor() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(3, 1)
	s.piece(5).tile = Vector2i(4, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(4, 1)]), 5: _p([Vector2i(3, 1)])})
	assert_true(o.state.piece(5).tagged, "Blue ends on Red ground")
	assert_false(o.state.piece(0).tagged, "Red is on its own half")
	assert_eq(o.state.piece(0).tile, Vector2i(4, 1))
	assert_eq(o.state.piece(5).tile, Vector2i(3, 1))
	assert_eq(o.events, [_tag(2, 5, 0)] as Array[Dictionary])


func test_swap_across_line_tags_both() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(5, 1)
	s.piece(5).tile = Vector2i(6, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(6, 1)]), 5: _p([Vector2i(5, 1)])})
	assert_true(o.state.piece(0).tagged)
	assert_true(o.state.piece(5).tagged)
	assert_eq(o.events, [_tag(2, 0, 5), _tag(2, 5, 0)] as Array[Dictionary])


func test_tagger_keeps_moving() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(3, 1)
	s.piece(5).tile = Vector2i(4, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(4, 1), Vector2i(5, 1)])})
	assert_eq(o.events, [_tag(2, 5, 0)] as Array[Dictionary])
	assert_eq(o.ticks[1].piece(0).tile, Vector2i(4, 1))
	assert_eq(o.state.piece(0).tile, Vector2i(5, 1), "tagger finishes its path")
	assert_false(o.state.piece(0).tagged)


func test_tagged_stops_and_respawns_next_turn() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.piece(5).tile = Vector2i(6, 1)
	var path := _p([Vector2i(5, 1), Vector2i(4, 1), Vector2i(3, 1)])
	var o := FlagResolver.resolve(m, s, {5: path})
	assert_eq(o.state.piece(5).tile, Vector2i(4, 1), "stops where it was tagged")
	assert_eq(o.ticks[FlagState.TICKS - 1].piece(5).tile, Vector2i(4, 1))
	assert_true(o.state.piece(5).tagged)
	var next := FlagResolver.resolve(m, o.state, {})
	assert_eq(next.state.piece(5).tile, m.home_tiles(B)[0], "back on its own home tile")
	assert_false(next.state.piece(5).tagged)
	assert_eq(next.ticks[0].piece(5).tile, m.home_tiles(B)[0], "home before tick 1")
	assert_eq(next.events.size(), 0)


func test_pickup_on_entering_flag_tile() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(10, 2)
	s.piece(1).tile = Vector2i(0, 2)
	# Red 1 walks onto its own flag: nothing happens.
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(10, 1)]), 1: _p([Vector2i(1, 2), Vector2i(1, 1)])})
	assert_eq(o.events, [{"tick": 2, "kind": "pickup", "piece": 0, "flag": B}] as Array[Dictionary])
	assert_eq(o.state.carrier, [-1, 0] as Array[int])
	assert_eq(o.ticks[0].carrier, [-1, -1] as Array[int], "not before it gets there")
	assert_eq(o.state.flag_tile(m, B), Vector2i(10, 1))


func test_tag_beats_pickup_same_tick() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(10, 2)
	s.piece(5).tile = Vector2i(10, 1)  # Blue guarding its own flag
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(10, 1)])})
	assert_eq(o.events, [_tag(2, 0, 5)] as Array[Dictionary])
	assert_eq(o.state.carrier, [-1, -1] as Array[int])


func test_tagged_carrier_drops_flag_home() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(7, 1)
	s.carrier[B] = 0
	s.piece(5).tile = Vector2i(6, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(6, 1), Vector2i(5, 1)])})
	assert_eq(o.events, [_tag(2, 0, 5)] as Array[Dictionary])
	assert_eq(o.state.carrier, [-1, -1] as Array[int])
	assert_eq(o.ticks[0].carrier, [-1, 0] as Array[int], "still carrying before the tag")
	assert_eq(o.state.flag_tile(m, B), m.flag_home(B))
	assert_eq(o.state.piece(0).tile, Vector2i(6, 1))


func test_carrier_moves_only_six() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	for id: int in range(5, 10):
		s.piece(id).tile = Vector2i(11, 2)  # out of the way
	s.piece(0).tile = Vector2i(9, 2)
	# 2 + 2 (pickup at 4) + 2 = 6, then the 8th half-point would be spent carrying.
	var path := _p([Vector2i(10, 2), Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1)])
	var o := FlagResolver.resolve(m, s, {0: path})
	assert_eq(o.state.carrier[B], 0)
	assert_eq(o.ticks[5].piece(0).tile, Vector2i(9, 1))
	assert_eq(o.state.piece(0).tile, Vector2i(9, 1), "stops at 6 half-points")


func test_capture_scores_and_resets() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.carrier[B] = 0
	s.piece(1).tile = Vector2i(5, 2)
	s.piece(6).tile = Vector2i(5, 2)
	var blue_path := _p([Vector2i(8, 0), Vector2i(7, 0), Vector2i(6, 0), Vector2i(5, 0)])
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(3, 1), Vector2i(2, 1)]), 5: blue_path})
	# Red 1 and Blue 6 share a tile on Red's half: Blue 6 is tagged at tick 1.
	var capture := {"tick": 4, "kind": "capture", "piece": 0, "team": R}
	assert_eq(o.events, [_tag(1, 6, 1), capture] as Array[Dictionary])
	assert_eq(o.state.score, [1, 0] as Array[int])
	var reset := FlagState.new_match(m)
	reset.score = [1, 0]
	reset.turn = s.turn
	for k: int in range(3, FlagState.TICKS):
		assert_eq(_rows(o.ticks[k]), _rows(reset), "tick %d repeats the reset board" % (k + 1))
	assert_eq(o.ticks[2].piece(5).tile, Vector2i(8, 0), "moving before the capture")
	reset.turn = s.turn + 1
	assert_eq(_rows(o.state), _rows(reset))


func test_double_capture_same_tick_counts_both() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.carrier[B] = 0
	s.piece(5).tile = Vector2i(7, 1)
	s.carrier[R] = 5
	var o := FlagResolver.resolve(m, s, {
		0: _p([Vector2i(3, 1), Vector2i(2, 1)]), 5: _p([Vector2i(8, 1), Vector2i(9, 1)])})
	assert_eq(o.state.score, [1, 1] as Array[int])
	assert_eq(o.events, [
		{"tick": 4, "kind": "capture", "piece": 0, "team": R},
		{"tick": 4, "kind": "capture", "piece": 5, "team": B}] as Array[Dictionary])
	assert_eq(o.state.carrier, [-1, -1] as Array[int])


func test_tagged_piece_takes_no_further_part() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.piece(5).tile = Vector2i(5, 1)
	s.piece(1).tile = Vector2i(3, 0)
	# Blue 5 is tagged at tick 2; Red 1 walks onto it at tick 4: no second meeting.
	var o := FlagResolver.resolve(m, s, {
		5: _p([Vector2i(4, 1), Vector2i(3, 1)]), 1: _p([Vector2i(3, 1), Vector2i(4, 1)])})
	assert_eq(o.events, [_tag(2, 5, 0)] as Array[Dictionary])
	assert_eq(o.state.piece(1).tile, Vector2i(4, 1))
	assert_eq(o.state.piece(5).tile, Vector2i(4, 1))


func test_cheap_path_moves_faster() -> void:
	var setup := _setup(DIRT)
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(3, 1)
	s.piece(1).tile = Vector2i(3, 0)
	var o := FlagResolver.resolve(m, s, {
		0: _p([Vector2i(4, 1), Vector2i(5, 1)]), 1: _p([Vector2i(4, 0), Vector2i(5, 0)])})
	assert_eq(o.ticks[0].piece(0).tile, Vector2i(4, 1))
	assert_eq(o.ticks[1].piece(0).tile, Vector2i(5, 1), "path piece on tile 2 at tick 2")
	assert_eq(o.ticks[0].piece(1).tile, Vector2i(3, 0), "grass piece hasn't arrived at tick 1")
	assert_eq(o.ticks[1].piece(1).tile, Vector2i(4, 0))
	assert_eq(o.ticks[2].piece(1).tile, Vector2i(4, 0))
	assert_eq(o.ticks[3].piece(1).tile, Vector2i(5, 0), "grass piece on tile 2 at tick 4")


func test_respawn_onto_enemy_tags_visitor_at_tick_1() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(7, 1)
	s.piece(0).tagged = true
	s.piece(5).tile = m.home_tiles(R)[0]  # Blue camping on Red 0's home tile
	var o := FlagResolver.resolve(m, s, {})
	assert_eq(o.events, [_tag(1, 5, 0)] as Array[Dictionary])
	assert_eq(o.ticks[0].piece(0).tile, m.home_tiles(R)[0])
	assert_false(o.state.piece(0).tagged)
	assert_true(o.state.piece(5).tagged)


func test_resolve_is_deterministic() -> void:
	var setup := _setup(DIRT)
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(2).tile = Vector2i(8, 2)
	s.piece(7).tile = Vector2i(4, 2)
	s.piece(8).tagged = true
	var orders: Dictionary = {
		0: FlagPath.find_path(m, s.piece(0).tile, Vector2i(5, 1)),
		2: _p([Vector2i(9, 2), Vector2i(10, 2), Vector2i(10, 1)]),
		5: FlagPath.find_path(m, s.piece(5).tile, Vector2i(6, 1)),
		7: _p([Vector2i(3, 2), Vector2i(2, 2)]),
	}
	var before := _rows(s)
	var a := _to_rows(FlagResolver.resolve(m, s, orders))
	var b := _to_rows(FlagResolver.resolve(m, s, orders))
	assert_eq(a, b)
	assert_eq(_rows(s), before, "input state untouched")
	assert_true((a[2] as Array).size() > 0, "the scenario produces events")


func test_no_orders_still_advances_turn() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.turn = 3
	var o := FlagResolver.resolve(m, s, {})
	assert_eq(o.state.turn, 4)
	assert_eq(s.turn, 3)
	assert_eq(o.ticks.size(), FlagState.TICKS)
	assert_eq(o.events.size(), 0)
	for p: FlagState.Piece in o.state.pieces:
		assert_eq(p.tile, s.piece(p.id).tile)
