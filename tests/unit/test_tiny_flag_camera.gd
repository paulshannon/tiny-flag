extends TestCase
## BoardCamera: fitting, zoom and pan limits, and telling drags and pinches from clicks
## and taps. The farm board (64x36 tiles = 1024x576 px) in a 1280x720 view between the
## HUD bars fits at zoom 1.

const VIEW := Vector2(1280, 720)
const Orders := preload("res://tests/unit/test_tiny_flag_orders.gd")


func _camera() -> BoardCamera:
	var board := BoardView.new()
	board.set_map(FlagMap.load_map(FlagMap.FARM_PATH))
	var camera := BoardCamera.new(board)
	camera.fit(VIEW, TurnHud.TOP, TurnHud.BOTTOM)
	return camera


func _free(camera: BoardCamera) -> void:
	camera.board.free()
	camera.free()


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _motion(pos: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.relative = relative
	return e


func test_fit_shows_the_whole_board_centred_at_a_whole_zoom() -> void:
	var c := _camera()
	assert_eq(c.zoom, 1.0)
	assert_eq(c.min_zoom, 1.0)
	assert_false(c.is_zoomed_in())
	assert_eq(c.board.position, Vector2(128, 72))  # (1280-1024)/2, 64 + (592-576)/2
	_free(c)


func test_wheel_zooms_in_whole_steps_keeping_the_tile_under_the_cursor() -> void:
	var c := _camera()
	var at := c.board.tile_center(Vector2i(40, 10))
	assert_true(c.handle_event(Orders.mouse(MOUSE_BUTTON_WHEEL_UP, at, true)))
	assert_eq(c.zoom, 2.0)
	assert_eq(c.board.tile_at(at), Vector2i(40, 10))
	c.handle_event(Orders.mouse(MOUSE_BUTTON_WHEEL_UP, at, true))
	assert_eq(c.zoom, 3.0)
	assert_eq(c.board.tile_at(at), Vector2i(40, 10))
	for i: int in 10:
		c.handle_event(Orders.mouse(MOUSE_BUTTON_WHEEL_UP, at, true))
	assert_eq(c.zoom, BoardCamera.MAX_ZOOM)
	for i: int in 10:
		c.handle_event(Orders.mouse(MOUSE_BUTTON_WHEEL_DOWN, at, true))
	assert_eq(c.zoom, 1.0)
	assert_eq(c.board.position, Vector2(128, 72), "fully out is the fitted view again")
	_free(c)


func test_pan_stops_at_the_board_edges() -> void:
	var c := _camera()
	c.zoom_at(Vector2(640, 360), 4.0)
	c.pan_by(Vector2(100000, 100000))  # drag far right and down: shows the top-left corner
	assert_eq(c.board.position, Vector2(0, TurnHud.TOP))
	c.pan_by(Vector2(-100000, -100000))
	var px := Vector2(64, 36) * FlagArt.TILE * 4.0
	assert_eq(c.board.position + px, Vector2(VIEW.x, VIEW.y - TurnHud.BOTTOM))
	# At the fitted zoom the board can't move at all.
	c.zoom_at(Vector2(640, 360), 1.0)
	c.pan_by(Vector2(300, 300))
	assert_eq(c.board.position, Vector2(128, 72))
	_free(c)


func test_a_left_drag_pans_and_is_not_a_click() -> void:
	var c := _camera()
	c.zoom_at(Vector2(640, 360), 2.0)
	var clicks: Array = []
	c.clicked.connect(func(p: Vector2, b: MouseButton) -> void: clicks.append([p, b]))
	var before := c.board.position
	assert_true(c.handle_event(Orders.mouse(MOUSE_BUTTON_LEFT, Vector2(600, 300), true)))
	c.handle_event(_motion(Vector2(640, 330), Vector2(40, 30)))
	assert_eq(c.board.position, before + Vector2(40, 30))
	assert_false(c.handle_event(Orders.mouse(MOUSE_BUTTON_LEFT, Vector2(640, 330), false)))
	assert_eq(clicks.size(), 0)
	# A wobble within the threshold is still a click, and doesn't move the board.
	c.handle_event(Orders.mouse(MOUSE_BUTTON_LEFT, Vector2(600, 300), true))
	c.handle_event(_motion(Vector2(603, 302), Vector2(3, 2)))
	assert_true(c.handle_event(Orders.mouse(MOUSE_BUTTON_LEFT, Vector2(603, 302), false)))
	assert_eq(clicks, [[Vector2(603, 302), MOUSE_BUTTON_LEFT]])
	assert_eq(c.board.position, before + Vector2(40, 30))
	_free(c)


func test_a_right_drag_is_neither_a_click_nor_a_pan() -> void:
	var c := _camera()
	c.zoom_at(Vector2(640, 360), 2.0)
	var clicks: Array = []
	c.clicked.connect(func(p: Vector2, b: MouseButton) -> void: clicks.append(b))
	var before := c.board.position
	c.handle_event(Orders.mouse(MOUSE_BUTTON_RIGHT, Vector2(600, 300), true))
	c.handle_event(_motion(Vector2(650, 300), Vector2(50, 0)))
	c.handle_event(Orders.mouse(MOUSE_BUTTON_RIGHT, Vector2(650, 300), false))
	assert_eq(clicks.size(), 0)
	assert_eq(c.board.position, before)
	_free(c)


func test_one_finger_drag_pans_and_is_not_a_tap() -> void:
	var c := _camera()
	c.zoom_at(Vector2(640, 360), 2.0)
	var taps: Array = []
	c.tapped.connect(func(p: Vector2) -> void: taps.append(p))
	var before := c.board.position
	c.handle_event(Orders.touch(5, Vector2(600, 300), true))
	c.handle_event(_drag(5, Vector2(620, 300)))
	c.handle_event(_drag(5, Vector2(650, 320)))
	assert_eq(c.board.position, before + Vector2(50, 20))
	assert_false(c.handle_event(Orders.touch(5, Vector2(650, 320), false)))
	assert_eq(taps.size(), 0)
	_free(c)


func test_pinch_zooms_and_is_not_a_tap() -> void:
	var c := _camera()
	var taps: Array = []
	c.tapped.connect(func(p: Vector2) -> void: taps.append(p))
	var mid := Vector2(640, 360)
	var under := c.to_board(mid)
	c.handle_event(Orders.touch(0, mid - Vector2(50, 0), true))
	c.handle_event(Orders.touch(1, mid + Vector2(50, 0), true))
	c.handle_event(_drag(0, mid - Vector2(100, 0)))
	c.handle_event(_drag(1, mid + Vector2(100, 0)))  # fingers twice as far apart
	assert_near(c.zoom, 2.0, 0.01)
	# The board point between the fingers stays put (within the whole-pixel rounding).
	assert_true(c.to_board(mid).distance_to(under) <= 0.5, "%s vs %s" % [c.to_board(mid), under])
	c.handle_event(Orders.touch(0, mid - Vector2(100, 0), false))
	assert_false(c.handle_event(Orders.touch(1, mid + Vector2(100, 0), false)))
	assert_eq(taps.size(), 0)
	_free(c)


func test_gestures_do_not_start_on_blocked_points() -> void:
	var c := _camera()
	c.blocked = func(p: Vector2) -> bool: return p.x > 1000
	var taps: Array = []
	c.tapped.connect(func(p: Vector2) -> void: taps.append(p))
	assert_false(c.handle_event(Orders.touch(0, Vector2(1100, 300), true)))
	c.handle_event(Orders.touch(0, Vector2(1100, 300), false))
	assert_false(c.handle_event(Orders.mouse(MOUSE_BUTTON_WHEEL_UP, Vector2(1100, 300), true)))
	assert_eq(c.zoom, 1.0)
	assert_eq(taps.size(), 0)
	_free(c)
