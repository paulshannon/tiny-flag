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


func test_long_path_sends_this_turns_part() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(8, 1))  # 6 grass tiles: 12 > 8
	assert_eq(m.cost_of(0), 12)
	assert_false(m.in_budget(0))
	assert_eq(m.turns_of(0), 2)
	assert_eq(m.this_turn(0), [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)] as Array[Vector2i])
	m.click_tile(Vector2i(2, 2))
	assert_eq(m.selected, 1)
	m.click_tile(Vector2i(4, 2))
	assert_true(m.in_budget(1))
	assert_eq(m.turns_of(1), 1)
	assert_eq(m.wire_orders(), [[0, PackedInt32Array([3, 1, 4, 1, 5, 1, 6, 1])], [1, PackedInt32Array([3, 2, 4, 2])]])
	m.clear(1)
	assert_eq(m.path_of(1).size(), 0)
	assert_eq(m.wire_orders().size(), 1)


## The next turn's view, with Red's pieces on the given tiles.
func _next_view(m: OrderModel, p0: Vector2i, turn_step: int = 1) -> void:
	m.set_view({"turn": m.turn + turn_step, "team": R, "pieces": [[0, R, p0.x, p0.y, 0, 0],
			[1, R, 2, 2, 0, 0], [5, B, 9, 1, 0, 0]], "flags": [[1, 1], [10, 1]], "result": -1})


func test_rest_of_a_long_path_carries_over_to_the_next_turn() -> void:
	var m := _model()
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(8, 1))
	m.click_tile(Vector2i(2, 2))
	m.click_tile(Vector2i(4, 2))  # fits: nothing left over
	_next_view(m, Vector2i(6, 1))
	assert_eq(m.turn, 4)
	assert_eq(m.path_of(0), [Vector2i(7, 1), Vector2i(8, 1)] as Array[Vector2i])
	assert_true(m.in_budget(0))
	assert_eq(m.path_of(1).size(), 0)
	assert_eq(m.wire_orders(), [[0, PackedInt32Array([7, 1, 8, 1])]])
	# The carried path is a plan like any other: it can be extended or cleared.
	m.select(0)
	m.click_tile(Vector2i(8, 2))
	assert_eq(m.end_of(0), Vector2i(8, 2))


func test_rest_is_dropped_when_the_piece_did_not_get_there() -> void:
	for case: Array in [[Vector2i(0, 0), 1], [Vector2i(6, 1), 2]]:  # tagged home; a skipped turn
		var m := _model()
		m.click_tile(Vector2i(2, 1))
		m.click_tile(Vector2i(8, 1))
		_next_view(m, case[0], case[1])
		assert_eq(m.path_of(0).size(), 0, str(case))
		assert_eq(m.wire_orders().size(), 0, str(case))


func test_carried_orders_are_sent_at_turn_start() -> void:
	var board := BoardView.new()
	board.set_map(_map())
	var m := _model()
	var input := OrderInput.new(m, board)
	var sent: Array = []
	input.orders_changed.connect(func(t: int, o: Array) -> void: sent.append([t, o]))
	m.click_tile(Vector2i(2, 1))
	m.click_tile(Vector2i(8, 1))
	_next_view(m, Vector2i(6, 1))
	input.reset()
	assert_eq(sent, [[4, [[0, PackedInt32Array([7, 1, 8, 1])]]]])
	input.free()
	board.free()


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


## Board, camera and input on the 12x3 map, the camera fitted (zoom 2) to a 400x200 view.
func _rig() -> Dictionary:
	var board := BoardView.new()
	board.set_map(_map())
	var camera := BoardCamera.new(board)
	camera.fit(Vector2(400, 200), 0, 0)
	var m := _model()
	var input := OrderInput.new(m, board, camera)
	input.enabled = true
	return {"board": board, "camera": camera, "model": m, "input": input}


func _free(rig: Dictionary) -> void:
	for k: String in ["input", "camera", "board"]:
		(rig[k] as Node).free()


static func touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


static func mouse(button: MouseButton, pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = pos
	e.pressed = pressed
	return e


## A one-finger tap (down and up) on a tile: true if it ended in a tap.
static func tap_tile(camera: BoardCamera, board: BoardView, c: Vector2i, index: int = 0) -> bool:
	camera.handle_event(touch(index, board.tile_center(c), true))
	return camera.handle_event(touch(index, board.tile_center(c), false))


static func click_tile(camera: BoardCamera, board: BoardView, c: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT) -> bool:
	camera.handle_event(mouse(button, board.tile_center(c), true))
	return camera.handle_event(mouse(button, board.tile_center(c), false))


func test_touch_needs_a_second_tap_on_the_same_tile() -> void:
	var r := _rig()
	var board: BoardView = r["board"]
	var camera: BoardCamera = r["camera"]
	var m: OrderModel = r["model"]
	var input: OrderInput = r["input"]
	var sent: Array = []
	input.orders_changed.connect(func(t: int, o: Array) -> void: sent.append([t, o]))
	assert_true(tap_tile(camera, board, Vector2i(2, 1)))
	assert_eq(m.selected, 0)
	tap_tile(camera, board, Vector2i(4, 1))
	assert_eq(m.path_of(0).size(), 0)  # previewed only
	assert_eq(sent.size(), 0)
	tap_tile(camera, board, Vector2i(4, 1))
	assert_eq(m.path_of(0).size(), 2)
	assert_eq(sent, [[3, [[0, PackedInt32Array([3, 1, 4, 1])]]]])
	# The emulated mouse click from the same tap is ignored.
	var emulated := mouse(MOUSE_BUTTON_LEFT, board.tile_center(Vector2i(6, 1)), true)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	assert_false(camera.handle_event(emulated))
	emulated.pressed = false
	assert_false(camera.handle_event(emulated))
	assert_eq(m.path_of(0).size(), 2)
	# A right click clears the selected piece's path and sends the change.
	assert_true(click_tile(camera, board, Vector2i(6, 1), MOUSE_BUTTON_RIGHT))
	assert_eq(m.path_of(0).size(), 0)
	assert_eq(sent.size(), 2)
	_free(r)


func test_off_board_taps_and_clicks_and_second_fingers_pass_through() -> void:
	var r := _rig()
	var board: BoardView = r["board"]
	var camera: BoardCamera = r["camera"]
	var m: OrderModel = r["model"]
	# Off the map (e.g. the touch Menu button): not taken.
	assert_false(camera.handle_event(touch(0, board.tile_center(Vector2i(-2, 1)), true)))
	camera.handle_event(touch(0, board.tile_center(Vector2i(-2, 1)), false))
	# A second finger while the first is still down: no tap from either.
	camera.handle_event(touch(0, board.tile_center(Vector2i(2, 1)), true))
	camera.handle_event(touch(1, board.tile_center(Vector2i(2, 1)), true))
	assert_false(camera.handle_event(touch(1, board.tile_center(Vector2i(2, 1)), false)))
	assert_false(camera.handle_event(touch(0, board.tile_center(Vector2i(2, 1)), false)))
	assert_eq(m.selected, -1)
	assert_true(tap_tile(camera, board, Vector2i(2, 1), 1))  # now the only finger
	assert_eq(m.selected, 0)
	assert_false(camera.handle_event(mouse(MOUSE_BUTTON_LEFT, board.tile_center(Vector2i(5, 9)), true)))  # below the map
	assert_true(click_tile(camera, board, Vector2i(4, 1)))
	assert_eq(m.path_of(0).size(), 2)
	_free(r)


## Browsers number touches freely (iOS Safari: large ids; Chrome: counting up), so a
## lone finger must work whatever its index. Found in the Task 11 browser check.
func test_a_lone_finger_works_with_any_index() -> void:
	var r := _rig()
	var board: BoardView = r["board"]
	var camera: BoardCamera = r["camera"]
	var m: OrderModel = r["model"]
	var input: OrderInput = r["input"]
	for step: Array in [[17, Vector2i(2, 1)], [18, Vector2i(4, 1)], [1234567, Vector2i(4, 1)]]:
		assert_true(tap_tile(camera, board, step[1], step[0]), "finger %d" % step[0])
	assert_eq(m.selected, 0)
	assert_eq(m.path_of(0).size(), 2)
	# Taps while planning is off do nothing, and don't block the next turn.
	input.enabled = false
	tap_tile(camera, board, Vector2i(2, 2), 3)
	assert_eq(m.selected, 0)
	input.reset()
	input.enabled = true
	assert_true(tap_tile(camera, board, Vector2i(2, 2), 4))
	assert_eq(m.selected, 1)
	_free(r)


## A release that a Control consumes never reaches _unhandled_input; _input still sees it,
## so the finger isn't left stuck down and the next tap works.
func test_a_release_consumed_elsewhere_does_not_block_the_next_tap() -> void:
	var r := _rig()
	var board: BoardView = r["board"]
	var camera: BoardCamera = r["camera"]
	var m: OrderModel = r["model"]
	camera.handle_event(touch(7, board.tile_center(Vector2i(2, 1)), true))
	camera._input(touch(7, board.tile_center(Vector2i(2, 1)), false))  # only the _input stage
	assert_eq(m.selected, 0)
	assert_true(tap_tile(camera, board, Vector2i(4, 1), 8), "the next lone finger is accepted")
	_free(r)


## Losing focus (app switch, system gesture) can swallow releases: forget every finger.
func test_focus_out_clears_fingers() -> void:
	var r := _rig()
	var board: BoardView = r["board"]
	var camera: BoardCamera = r["camera"]
	for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
		camera.handle_event(touch(1, board.tile_center(Vector2i(2, 1)), true))
		camera.notification(what)  # finger 1's release is lost
		assert_true(tap_tile(camera, board, Vector2i(2, 1), 2), "lone finger after notification %d" % what)
	_free(r)
