extends TestCase
## OrderModel: planning clicks -> paths -> wire orders (spec §2 "Planning").

const R := FlagMap.RED
const B := FlagMap.BLUE


## 12x3: bases at the sides, grass between, a hedge at (5, 0).
func _map() -> FlagMap:
	return FlagMap.parse("RRR..h...UUU\nRRR......UUU\nRRR......UUU")


## Red piece 0 at (2, 1), red piece 1 at (2, 2), blue piece 5 at (9, 1).
func _model() -> OrderModel:
	var m := OrderModel.new(_map())
	m.set_view({"turn": 3, "team": R, "score": [0, 0], "turn_limit": 40,
			"pieces": [[0, R, 2, 1, 0, 0], [1, R, 2, 2, 0, 0], [5, B, 9, 1, 0, 0]],
			"flags": [[1, 1], [10, 1]], "result": -1})
	return m


func test_click_own_piece_then_tile_sets_path() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	assert_eq(m.selected, 0)
	m.click_tile(Vector2i(5, 1))
	assert_eq(m.path_of(0), [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i])
	assert_eq(m.cost_of(0), 6)
	assert_true(m.in_budget(0))
	assert_eq(m.turn, 3)


func test_second_click_extends_from_path_end() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(4, 0))
	var first := m.path_of(0)
	assert_eq(first[first.size() - 1], Vector2i(4, 0))
	m.click_tile(Vector2i(4, 2))
	var path := m.path_of(0)
	# Extended from (4, 0), not re-planned from the piece: the detour stays.
	assert_eq(path.slice(0, first.size()), first)
	assert_eq(path.slice(first.size()), [Vector2i(4, 1), Vector2i(4, 2)] as Array[Vector2i])
	# Clicking the end again changes nothing.
	m.click_tile(Vector2i(4, 2))
	assert_eq(m.path_of(0), path)


func test_over_budget_path_not_in_wire_orders() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(8, 1))  # 6 grass tiles: 12 > 8
	assert_eq(m.cost_of(0), 12)
	assert_false(m.in_budget(0))
	m.click_tile(Vector2i(2, 2))
	assert_eq(m.selected, 1)
	m.click_tile(Vector2i(4, 2))
	assert_true(m.in_budget(1))
	var wire := m.wire_orders()
	assert_eq(wire.size(), 1)
	assert_eq(wire[0][0], 1)
	assert_eq(wire[0][1], PackedInt32Array([3, 2, 4, 2]))
	m.clear(1)
	assert_eq(m.path_of(1).size(), 0)
	assert_eq(m.wire_orders().size(), 0)


func test_clicking_enemy_or_wall_does_nothing() -> void:
	var m := _model()
	m.click_tile(Vector2i(9, 1))  # the enemy: not selectable
	assert_eq(m.selected, -1)
	assert_eq(m.path_of(5).size(), 0)
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(5, 0))  # hedge
	assert_eq(m.path_of(0).size(), 0)
	m.click_tile(Vector2i(40, 1))  # off the map
	assert_eq(m.path_of(0).size(), 0)
	assert_eq(m.wire_orders().size(), 0)


func test_new_view_clears_paths_and_spectators_cannot_select() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(4, 1))
	m.set_view({"turn": 4, "team": -1, "pieces": [[0, R, 2, 1, 0, 0]]})
	assert_eq(m.path_of(0).size(), 0)
	m.click_tile(Vector2i(2, 1))
	assert_eq(m.selected, -1)


func test_carrier_budget_is_smaller() -> void:
	var m := OrderModel.new(_map())
	m.set_view({"turn": 1, "team": R, "pieces": [[0, R, 2, 1, 1, 0]]})
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(6, 1))  # 4 grass: 8 > 6
	assert_false(m.in_budget(0))
	assert_eq(m.budget_of(0), FlagState.CARRIER_POINTS)


func test_touch_needs_a_second_tap_on_the_same_tile() -> void:
	var board := BoardView.new()
	board.set_map(_map())
	var m := _model()
	var input := OrderInput.new(m, board)
	input.enabled = true
	var sent: Array = []
	input.orders_changed.connect(func(t: int, o: Array) -> void: sent.append([t, o]))
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = board.tile_center(Vector2i(2, 1))
	assert_true(input.handle_event(tap))
	assert_eq(m.selected, 0)
	tap.position = board.tile_center(Vector2i(4, 1))
	input.handle_event(tap)
	assert_eq(m.path_of(0).size(), 0)  # previewed only
	assert_eq(sent.size(), 0)
	input.handle_event(tap)
	assert_eq(m.path_of(0).size(), 2)
	assert_eq(sent, [[3, [[0, PackedInt32Array([3, 1, 4, 1])]]]])
	# The emulated mouse click from the same tap is ignored.
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = board.tile_center(Vector2i(6, 1))
	assert_false(input.handle_event(mouse))
	# A right click clears the selected piece's path and sends the change.
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.device = 0
	assert_true(input.handle_event(mouse))
	assert_eq(m.path_of(0).size(), 0)
	assert_eq(sent.size(), 2)
	input.free()
	board.free()
