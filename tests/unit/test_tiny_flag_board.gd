extends TestCase
## BoardView off the tree: builds the farm board and converts tiles <-> screen.


func test_board_builds_and_tile_at_roundtrips() -> void:
	var board := BoardView.new()
	board.set_map(FlagMap.load_map(FlagMap.FARM_PATH))
	var c := Vector2i(5, 7)
	assert_eq(board.tile_at(board.tile_center(c)), c)
	board.scale = Vector2(2, 2)
	board.position = Vector2(128, 72)
	assert_eq(board.tile_at(board.tile_center(c)), c)
	assert_eq(board.tile_at(Vector2(128 + 5 * 32 + 1, 72 + 7 * 32 + 1)), c)
	board.free()


func test_enemy_dropping_out_of_view_leaves_a_marker_until_seen_again() -> void:
	var board := BoardView.new()
	board.set_map(FlagMap.load_map(FlagMap.FARM_PATH))
	var own := [0, FlagMap.RED, 10, 8, 0, 0]
	board.show_view({"turn": 1, "team": FlagMap.RED, "pieces": [own, [5, FlagMap.BLUE, 12, 8, 0, 0]]})
	assert_eq(board.marker_tiles(), {})
	board.show_view({"turn": 2, "team": FlagMap.RED, "pieces": [own]})
	assert_eq(board.marker_tiles(), {5: Vector2i(12, 8)})
	board.show_view({"turn": 3, "team": FlagMap.RED, "pieces": [own, [5, FlagMap.BLUE, 13, 8, 0, 0]]})
	assert_eq(board.marker_tiles(), {})
	board.free()


func test_capture_in_playback_clears_markers_and_playback_finishes() -> void:
	var board := BoardView.new()
	board.set_map(FlagMap.load_map(FlagMap.FARM_PATH))
	var own := [0, FlagMap.RED, 10, 8, 0, 0]
	board.show_view({"turn": 1, "team": FlagMap.RED, "pieces": [own, [5, FlagMap.BLUE, 12, 8, 0, 0]]})
	board.show_view({"turn": 2, "team": FlagMap.RED, "pieces": [own]})
	var done: Array[int] = []
	board.playback_finished.connect(func(t: int) -> void: done.append(t))
	board.play_turn({"turn": 2, "ticks": [[own], [own]], "events": [{"tick": 2, "kind": "capture", "piece": 0, "team": 0}]})
	assert_eq(board.marker_tiles().size(), 1)
	for i: int in 10:
		board._process(BoardView.TICK_SECONDS)
	assert_eq(board.marker_tiles(), {})
	assert_eq(done, [2] as Array[int])
	assert_false(board.is_playing())
	board.free()


func test_new_match_clears_markers() -> void:
	var board := BoardView.new()
	board.set_map(FlagMap.load_map(FlagMap.FARM_PATH))
	var own := [0, FlagMap.RED, 10, 8, 0, 0]
	board.show_view({"turn": 7, "team": FlagMap.RED, "pieces": [own, [5, FlagMap.BLUE, 12, 8, 0, 0]]})
	board.show_view({"turn": 8, "team": FlagMap.RED, "pieces": [own]})
	assert_eq(board.marker_tiles().size(), 1)
	board.show_view({"turn": 0, "team": FlagMap.RED, "pieces": [own]})
	assert_eq(board.marker_tiles(), {})
	board.free()
