extends TestCase

const MINI := "RRR..UUU\nRRR==UUU\nRRRwhUUU\n"
const R := FlagMap.RED
const B := FlagMap.BLUE


func _grass_map() -> FlagMap:
	# 12 wide, 3 tall: bases at the sides, grass between; row 1 grass path of 1-cost tiles on row 2
	var rows := ["RRR......UUU", "RRR......UUU", "RRR......UUU"]
	return FlagMap.parse("\n".join(rows))


func test_new_match_puts_five_per_side_on_home_tiles() -> void:
	var m := FlagMap.parse(MINI)
	var s := FlagState.new_match(m)
	assert_eq(s.pieces.size(), 10)
	var homes := m.home_tiles(R)
	for i: int in 5:
		assert_eq(s.piece(i).tile, homes[i]); assert_eq(s.piece(i).team, R)
		assert_eq(s.piece(5 + i).team, B); assert_eq(s.piece(5 + i).id, 5 + i)
	assert_eq(s.carrier, [-1, -1] as Array[int])


func test_find_path_prefers_dirt_path() -> void:
	var m := FlagMap.parse("RRR......UUU\nRRR======UUU\nRRR......UUU")
	var from := Vector2i(2, 0)
	var path := FlagPath.find_path(m, from, Vector2i(8, 0))
	# Straight grass is 6 x 2 = 12; down to base (2) + 6 dirt (6) + up to grass (2) = 10.
	assert_eq(FlagPath.cost_of(m, from, path), 10)
	assert_true(path.has(Vector2i(4, 1)), "uses the dirt row")
	assert_eq(path[path.size() - 1], Vector2i(8, 0))
	assert_eq(FlagPath.find_path(m, from, from).size(), 0)


func test_find_path_unreachable_is_empty() -> void:
	var m := FlagMap.parse(MINI)
	assert_eq(FlagPath.find_path(m, Vector2i(3, 0), Vector2i(4, 2)).size(), 0)  # hedge
	assert_eq(FlagPath.find_path(m, Vector2i(3, 0), Vector2i(20, 20)).size(), 0)
	var walled := FlagMap.parse("RRR~.UUU\nRRR~.UUU\nRRR~.UUU")
	assert_eq(FlagPath.find_path(walled, Vector2i(2, 0), Vector2i(4, 0)).size(), 0)


func test_trim_to_budget_stops_before_overspend() -> void:
	var m := _grass_map()
	var path: Array[Vector2i] = []
	for x: int in range(3, 9):
		path.append(Vector2i(x, 1))
	assert_eq(FlagPath.cost_of(m, Vector2i(2, 1), path), 12)
	var t := FlagPath.trim_to_budget(m, Vector2i(2, 1), path, 8)
	assert_eq(t.size(), 4)
	assert_eq(FlagPath.cost_of(m, Vector2i(2, 1), t), 8)


func test_encode_decode_round_trip_and_malformed() -> void:
	var path: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1)]
	assert_eq(FlagPath.decode(FlagPath.encode(path)), path)
	assert_eq(FlagPath.decode([3, 1, 4, 1]), path)
	assert_eq(FlagPath.decode([3, 1, 4]).size(), 0)
	assert_eq(FlagPath.decode([3, "x"]).size(), 0)
	assert_eq(FlagPath.decode({}).size(), 0)
	assert_eq(FlagPath.decode(null).size(), 0)


func test_carrier_has_six_points() -> void:
	var s := FlagState.new_match(FlagMap.parse(MINI))
	assert_eq(s.move_points(0), 8)
	s.carrier[B] = 0
	assert_eq(s.move_points(0), 6)
	assert_true(s.is_carrying(0)); assert_false(s.is_carrying(1))


func test_flag_tile_and_reset() -> void:
	var m := FlagMap.parse(MINI)
	var s := FlagState.new_match(m)
	assert_eq(s.flag_tile(m, B), m.flag_home(B))
	s.carrier[B] = 0
	s.piece(0).tile = Vector2i(4, 0)
	s.piece(1).tagged = true
	assert_eq(s.flag_tile(m, B), Vector2i(4, 0))
	var c := s.copy()
	s.reset_positions(m)
	assert_eq(s.carrier, [-1, -1] as Array[int]); assert_false(s.piece(1).tagged)
	assert_eq(s.piece(0).tile, m.home_tiles(R)[0])
	assert_eq(c.carrier[B], 0); assert_true(c.piece(1).tagged)  # copy is deep


func test_result_rules() -> void:
	var s := FlagState.new_match(FlagMap.parse(MINI))
	assert_eq(s.result(), FlagState.Result.ONGOING)
	s.score = [3, 1]
	assert_eq(s.result(), FlagState.Result.RED_WINS)
	s.score = [0, 3]
	assert_eq(s.result(), FlagState.Result.BLUE_WINS)
	s.score = [2, 1]
	assert_eq(s.result(), FlagState.Result.ONGOING)
	s.turn = FlagState.TURN_LIMIT
	assert_eq(s.result(), FlagState.Result.RED_WINS)
	s.score = [1, 2]
	assert_eq(s.result(), FlagState.Result.BLUE_WINS)
	s.score = [2, 2]
	assert_eq(s.result(), FlagState.Result.DRAW)


func _flat(xs: Array) -> PackedInt32Array:
	return PackedInt32Array(xs)


func test_validate_accepts_good_order() -> void:
	var m := FlagMap.parse(MINI)
	var s := FlagState.new_match(m)
	# Red piece 2 at (2,0): step to (3,0) grass 2, (3,1) path 1.
	var out := FlagPath.validate_orders(m, s, R, [[2, _flat([3, 0, 3, 1])]])
	assert_eq(out.size(), 1)
	var p: Array[Vector2i] = out[2]
	assert_eq(p, [Vector2i(3, 0), Vector2i(3, 1)] as Array[Vector2i])


func test_validate_drops_bad_orders_individually() -> void:
	var m := _grass_map()
	var s := FlagState.new_match(m)
	var p0 := s.piece(0).tile  # (0,0)
	var p1 := s.piece(1).tile  # (1,0)
	var good: Array = [1, _flat([p1.x + 1, p1.y])]
	var long_path := PackedInt32Array()
	for i: int in 17:
		long_path.append(2 + (i % 8)); long_path.append(1)
	var batch: Array = [
		good,
		[5, _flat([9, 0])],                       # enemy piece
		[1, _flat([p1.x + 1, p1.y])],             # same piece twice
		[2, _flat([5, 1])],                       # gap (piece 2 at (2,0))
		[3, _flat([0, 1, 0, 2, 0, 3])],           # piece 3 at (0,1): (0,3) out of map
		[4, _flat([4, 1, 5, 1, 6, 1, 7, 1, 8, 1])],  # 5 grass steps = 10 > 8
		[0, long_path],                           # more than 16 steps
		[0, PackedInt32Array([p0.x, 1, 5])],      # odd length
		[0, _flat([99999, 99999])],               # coords out of range
		["0", _flat([1, 1])],                     # non-int id
		{"a": 1},                                 # Dictionary in place of the order
		[0],                                      # wrong size
		[0, {}],                                  # junk path
	]
	var out := FlagPath.validate_orders(m, s, R, batch)
	assert_eq(out.keys(), [1])
	# impassable step
	var w := FlagMap.parse(MINI)
	var ws := FlagState.new_match(w)
	ws.piece(2).tile = Vector2i(3, 2)  # crops tile
	assert_eq(FlagPath.validate_orders(w, ws, R, [[2, _flat([4, 2])]]).size(), 0)  # hedge


func test_validate_rejects_non_array_payload() -> void:
	var m := FlagMap.parse(MINI)
	var s := FlagState.new_match(m)
	for junk: Variant in [null, {}, "x", 5, _flat([1, 2])]:
		assert_eq(FlagPath.validate_orders(m, s, R, junk).size(), 0)
	var big: Array = []
	for i: int in 1000:
		big.append([i % 10, _flat([3, 0])])
	assert_true(FlagPath.validate_orders(m, s, R, big).size() <= 5)
	var nested: Array = [[[[]]], [[], []], [null, null], [2, null]]
	assert_eq(FlagPath.validate_orders(m, s, R, nested).size(), 0)


func test_validate_ignores_tagged_pieces() -> void:
	var m := FlagMap.parse(MINI)
	var s := FlagState.new_match(m)
	s.piece(2).tagged = true
	assert_eq(FlagPath.validate_orders(m, s, R, [[2, _flat([3, 0])]]).size(), 0)
	assert_eq(FlagPath.validate_orders(m, s, R, [[1, _flat([2, 0])]]).size(), 1)  # untagged neighbour still fine
