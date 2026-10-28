extends TestCase
## Tagged pieces stay where they were caught for the rest of the turn, then are home
## and free at the start of the next one (spec §2 "Resolution").

const R := FlagMap.RED
const B := FlagMap.BLUE
const GRASS := "RRR......UUU\nRRR......UUU\nRRR......UUU"


func _setup() -> Array:
	var m := FlagMap.parse(GRASS)
	return [m, FlagState.new_match(m)]


func _p(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		out.append(t)
	return out


func test_tagged_stops_then_is_home_and_movable_next_turn() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(4, 1)
	s.piece(5).tile = Vector2i(6, 1)
	var path := _p([Vector2i(5, 1), Vector2i(4, 1), Vector2i(3, 1)])
	var o := FlagResolver.resolve(m, s, {5: path})
	for k: int in range(3, FlagState.TICKS):  # tagged at tick 4
		var snap: FlagState = o.ticks[k]
		assert_eq(snap.piece(5).tile, Vector2i(4, 1), "tick %d: stays where it was caught" % (k + 1))
		assert_true(snap.piece(5).tagged, "tick %d: still tagged" % (k + 1))
	assert_eq(o.state.piece(5).tile, m.home_tiles(B)[0], "home for the next turn")
	assert_false(o.state.piece(5).tagged)
	var orders := FlagPath.validate_orders(m, o.state, B, [[5, FlagPath.encode(_p([Vector2i(10, 0)]))]])
	assert_true(orders.has(5), "can be ordered in the next planning phase")


func test_tagged_carrier_flag_is_home_and_piece_respawned() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(7, 1)
	s.carrier[B] = 0
	s.piece(5).tile = Vector2i(6, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(6, 1), Vector2i(5, 1)])})
	assert_eq(o.state.carrier, [-1, -1] as Array[int])
	assert_eq(o.state.piece(0).tile, m.home_tiles(R)[0])
	assert_true(o.ticks[FlagState.TICKS - 1].piece(0).tagged)
	assert_eq(o.ticks[FlagState.TICKS - 1].piece(0).tile, Vector2i(6, 1))


func test_respawn_onto_enemy_tags_visitor_at_tick_1() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	var home := m.home_tiles(R)[0]
	# Turn N: Red 0 is caught at (6,1) by Blue 6 (tick 2, on Blue ground); Blue 5 ends the
	# turn on Red 0's home tile.
	s.piece(0).tile = Vector2i(7, 1)
	s.piece(5).tile = home
	s.piece(6).tile = Vector2i(6, 1)
	var o := FlagResolver.resolve(m, s, {0: _p([Vector2i(6, 1)])})
	assert_true(o.ticks[1].piece(0).tagged, "Red 0 caught at tick 2")
	assert_eq(o.state.piece(0).tile, home, "Red 0 respawned on its home tile")
	assert_false(o.state.piece(0).tagged)
	assert_eq(o.state.piece(5).tile, home, "Blue 5 still camping there")
	var next := FlagResolver.resolve(m, o.state, {})
	assert_eq(next.events, [{"tick": 1, "kind": "tag", "piece": 5, "by": 0}] as Array[Dictionary])
	assert_eq(next.state.piece(5).tile, m.home_tiles(B)[0], "visitor sent home")


func test_stale_tagged_input_is_respawned_at_start() -> void:
	var setup := _setup()
	var m: FlagMap = setup[0]
	var s: FlagState = setup[1]
	s.piece(0).tile = Vector2i(7, 1)
	s.piece(0).tagged = true
	var o := FlagResolver.resolve(m, s, {})
	assert_eq(o.state.piece(0).tile, m.home_tiles(R)[0])
	assert_false(o.state.piece(0).tagged)
