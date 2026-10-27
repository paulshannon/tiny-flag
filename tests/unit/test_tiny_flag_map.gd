extends TestCase

const MINI := "RRR..UUU\nRRR==UUU\nRRRwhUUU\n"   # 8x3, both bases 3x3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func test_parse_mini_map() -> void:
	var m := FlagMap.parse(MINI)
	assert_eq(m.width, 8); assert_eq(m.height, 3)
	assert_eq(m.cost(Vector2i(3, 1)), 1)            # path
	assert_eq(m.cost(Vector2i(3, 2)), 4)            # crops
	assert_eq(m.cost(Vector2i(4, 2)), -1)           # hedge
	assert_eq(m.cost(Vector2i(-1, 0)), -1)
	assert_true(m.blocks_sight(Vector2i(4, 2))); assert_false(m.blocks_sight(Vector2i(3, 2)))
	assert_true(m.hides(Vector2i(3, 2)))
	assert_eq(m.side_of(Vector2i(3, 0)), FlagMap.RED); assert_eq(m.side_of(Vector2i(4, 0)), FlagMap.BLUE)
	assert_eq(m.flag_home(FlagMap.RED), Vector2i(1, 1)); assert_eq(m.flag_home(FlagMap.BLUE), Vector2i(6, 1))
	assert_eq(m.home_tiles(FlagMap.RED), [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(2,1)])


func test_rejects_bad_maps() -> void:
	for bad: String in ["RRR..UUU\nRRR=UUU\nRRR..UUU", "RRR..UUUx\n", "RRRx.UUU\nRRR..UUU\nRRR..UUU",
			"RR...UUU\nRRR..UUU\nRRR..UUU", "UUU..RRR\nUUU..RRR\nUUU..RRR"]:
		expect_error("FlagMap:")
		assert_eq(FlagMap.parse(bad), null, bad)


func test_farm_is_64_by_36_and_symmetric() -> void:
	var m := FlagMap.load_map(FlagMap.FARM_PATH)
	assert_eq(m.width, 64); assert_eq(m.height, 36)
	for y: int in m.height:
		for x: int in m.width:
			var here: FlagMap.Terrain = m.terrain(Vector2i(x, y))
			var there: FlagMap.Terrain = m.terrain(Vector2i(m.width - 1 - x, y))
			assert_eq(here, there, "terrain at %d,%d" % [x, y])
			var base_here := m.in_base(Vector2i(x, y), FlagMap.RED)
			var base_there := m.in_base(Vector2i(m.width - 1 - x, y), FlagMap.BLUE)
			assert_eq(base_here, base_there, "base at %d,%d" % [x, y])


func test_farm_bases_reach_each_other_by_two_routes() -> void:
	var m := FlagMap.load_map(FlagMap.FARM_PATH)
	var start := m.flag_home(FlagMap.RED)
	var goal := m.flag_home(FlagMap.BLUE)
	var route := _route(m, start, goal, Vector2i(-1, -1))
	assert_true(route.size() > 0, "red flag reaches blue flag")
	for c: Vector2i in route:
		if m.in_base(c, FlagMap.RED) or m.in_base(c, FlagMap.BLUE):
			continue
		assert_true(_route(m, start, goal, c).size() > 0, "route survives blocking %s" % str(c))


func test_farm_middle_third_has_crops_and_trees() -> void:
	var m := FlagMap.load_map(FlagMap.FARM_PATH)
	var crops := 0
	var trees := 0
	for y: int in m.height:
		for x: int in range(m.width / 3, m.width - m.width / 3):
			match m.terrain(Vector2i(x, y)):
				FlagMap.Terrain.CROPS: crops += 1
				FlagMap.Terrain.TREE: trees += 1
	assert_true(crops >= 48, "crops %d" % crops)
	assert_true(trees >= 8, "trees %d" % trees)


## BFS over passable tiles, ignoring `blocked`. Returns the tiles from start to goal, or [].
func _route(m: FlagMap, start: Vector2i, goal: Vector2i, blocked: Vector2i) -> Array[Vector2i]:
	var came: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			break
		for d: Vector2i in DIRS:
			var nxt := cur + d
			if nxt == blocked or came.has(nxt) or m.cost(nxt) < 0:
				continue
			came[nxt] = cur
			queue.append(nxt)
	var out: Array[Vector2i] = []
	if not came.has(goal):
		return out
	var at := goal
	while at != start:
		out.push_front(at)
		at = came[at]
	out.push_front(start)
	return out
