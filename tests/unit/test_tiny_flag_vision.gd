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


func _viewers(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		out.append(t)
	return out


func test_radius_is_euclidean_five() -> void:
	var m := _map()
	var v := _viewers([Vector2i(10, 5)])
	assert_true(FlagVision.can_see(m, v, Vector2i(13, 9), false), "(3,4) is exactly 5")
	assert_true(FlagVision.can_see(m, v, Vector2i(15, 5), false), "(5,0)")
	assert_false(FlagVision.can_see(m, v, Vector2i(14, 9), false), "(4,4) is 5.66")
	assert_false(FlagVision.can_see(m, v, Vector2i(15, 6), false), "(5,1) is just outside, 26")
	assert_true(FlagVision.can_see(m, v, Vector2i(14, 8), false), "(4,3) is inside")
	assert_false(FlagVision.can_see(m, v, Vector2i(16, 5), false), "(6,0)")


func test_viewer_sees_own_tile() -> void:
	var m := _map({Vector2i(10, 5): "w"})
	assert_true(FlagVision.can_see(m, _viewers([Vector2i(10, 5)]), Vector2i(10, 5), false))
	assert_false(FlagVision.can_see(m, _viewers([]), Vector2i(10, 5), false), "no viewers, no sight")


func test_hedge_blocks_but_is_itself_visible() -> void:
	var m := _map({Vector2i(12, 5): "h"})
	var v := _viewers([Vector2i(10, 5)])
	assert_true(FlagVision.can_see(m, v, Vector2i(12, 5), false), "the hedge tile itself")
	assert_false(FlagVision.can_see(m, v, Vector2i(13, 5), false), "behind the hedge")
	assert_true(FlagVision.can_see(m, v, Vector2i(11, 5), false), "in front of it")
	assert_true(FlagVision.can_see(m, v, Vector2i(13, 7), false), "around it")


func test_tree_blocks_line_behind_it() -> void:
	var m := _map({Vector2i(12, 5): "t"})
	var v := _viewers([Vector2i(10, 5)])
	assert_false(FlagVision.line_clear(m, Vector2i(10, 5), Vector2i(14, 5)))
	assert_true(FlagVision.line_clear(m, Vector2i(10, 5), Vector2i(12, 5)), "the tree itself")
	assert_true(FlagVision.can_see(m, v, Vector2i(12, 5), false))
	assert_false(FlagVision.can_see(m, v, Vector2i(14, 5), false))
	assert_false(FlagVision.line_clear(m, Vector2i(14, 5), Vector2i(10, 5)), "symmetric")
	var b := _map({Vector2i(12, 5): "B"})
	assert_false(FlagVision.line_clear(b, Vector2i(10, 5), Vector2i(14, 5)), "building too")
	var water := _map({Vector2i(12, 5): "~"})
	assert_true(FlagVision.line_clear(water, Vector2i(10, 5), Vector2i(14, 5)), "water is see-through")


func test_corner_peek_needs_both_corners_blocked() -> void:
	var a := Vector2i(10, 5)
	var b := Vector2i(11, 6)
	# Diagonal neighbours: the line runs exactly through the shared corner.
	assert_true(FlagVision.line_clear(_map({Vector2i(11, 5): "h"}), a, b), "one corner blocked")
	assert_true(FlagVision.line_clear(_map({Vector2i(10, 6): "h"}), a, b), "other corner blocked")
	assert_false(FlagVision.line_clear(_map({Vector2i(11, 5): "h", Vector2i(10, 6): "h"}), a, b), "both")
	# Longer diagonal: corners at both (11,6) steps; the tile on the line blocks outright.
	var far := Vector2i(12, 7)
	assert_false(FlagVision.line_clear(_map({Vector2i(11, 6): "h"}), a, far), "tile on the line")
	assert_true(FlagVision.line_clear(_map({Vector2i(11, 5): "h"}), a, far), "single corner tile")
	assert_false(FlagVision.line_clear(_map({Vector2i(11, 5): "h", Vector2i(10, 6): "h"}), a, far))
	# Other diagonal directions behave the same.
	var up := _map({Vector2i(9, 5): "h", Vector2i(10, 4): "h"})
	assert_false(FlagVision.line_clear(up, a, Vector2i(9, 4)), "up-left, both")
	assert_true(FlagVision.line_clear(_map({Vector2i(9, 5): "h"}), a, Vector2i(9, 4)), "up-left, one")


func test_off_corner_line_is_blocked_by_either_tile() -> void:
	# (10,5)->(12,6) runs through (11,5) then (11,6), crossing no corner.
	var a := Vector2i(10, 5)
	var b := Vector2i(12, 6)
	assert_true(FlagVision.line_clear(_map(), a, b))
	assert_false(FlagVision.line_clear(_map({Vector2i(11, 5): "h"}), a, b), "first crossed tile")
	assert_false(FlagVision.line_clear(_map({Vector2i(11, 6): "h"}), a, b), "second crossed tile")
	assert_true(FlagVision.line_clear(_map({Vector2i(12, 5): "h", Vector2i(10, 6): "h"}), a, b), "untouched tiles")


func test_out_of_bounds_blocks() -> void:
	var m := _map()
	assert_false(FlagVision.line_clear(m, Vector2i(1, 5), Vector2i(-3, 5)), "target off the board")


func test_crops_hide_unless_adjacent() -> void:
	var c := Vector2i(10, 5)
	var m := _map({c: "w"})
	assert_false(FlagVision.can_see(m, _viewers([Vector2i(12, 5)]), c, false), "distance 2")
	assert_false(FlagVision.can_see(m, _viewers([Vector2i(8, 5)]), c, false), "distance 2 other side")
	assert_true(FlagVision.can_see(m, _viewers([Vector2i(11, 6)]), c, false), "diagonal neighbour")
	assert_true(FlagVision.can_see(m, _viewers([Vector2i(10, 4)]), c, false), "orthogonal neighbour")
	assert_true(FlagVision.can_see(m, _viewers([c]), c, false), "same tile")
	assert_true(FlagVision.can_see(m, _viewers([Vector2i(12, 5), Vector2i(9, 4)]), c, false), "any viewer")
	# Same distance on plain grass is visible, so the hiding is the crops.
	assert_true(FlagVision.can_see(_map(), _viewers([Vector2i(12, 5)]), c, false))


func test_crops_adjacent_sight_ignores_blockers_and_needs_no_radius_check() -> void:
	# A neighbour sees into crops even when it's the only thing in range.
	var m := _map({Vector2i(10, 5): "w", Vector2i(11, 5): "w"})
	assert_true(FlagVision.can_see(m, _viewers([Vector2i(11, 5)]), Vector2i(10, 5), false))


func test_carrier_always_visible() -> void:
	var m := _map({Vector2i(5, 5): "h"})
	var v := _viewers([Vector2i(2, 5)])
	var far := Vector2i(22, 5)
	assert_false(FlagVision.can_see(m, v, far, false), "20 tiles away, not carrying")
	assert_true(FlagVision.can_see(m, v, far, true), "carrying")
	var crops := _map({far: "w", Vector2i(5, 5): "h"})
	assert_true(FlagVision.can_see(crops, v, far, true), "a carrier on crops still shows")
	assert_false(FlagVision.can_see(crops, v, far, false))


func test_visible_enemy_ids_uses_any_teammate() -> void:
	var m := _map({Vector2i(14, 8): "w"})
	var s := FlagState.new_match(m)
	# Red 0 and 1 far apart; blue pieces scattered.
	s.piece(0).tile = Vector2i(5, 5)
	s.piece(1).tile = Vector2i(15, 5)
	for i: int in range(2, 5):
		s.piece(i).tile = Vector2i(0, 10)
	s.piece(5).tile = Vector2i(9, 5)    # 4 from red 0
	s.piece(6).tile = Vector2i(19, 5)   # 4 from red 1
	s.piece(7).tile = Vector2i(11, 10)  # too far from everyone
	s.piece(8).tile = Vector2i(14, 8)   # on crops, distance 3 from red 1
	s.piece(9).tile = Vector2i(23, 10)
	var red_sees := FlagVision.visible_enemy_ids(m, s, R)
	assert_eq(red_sees, [5, 6] as Array[int])
	# A carrier shows from anywhere.
	s.carrier[R] = 9
	assert_eq(FlagVision.visible_enemy_ids(m, s, R), [5, 6, 9] as Array[int])
	# Blue's view: red's own pieces are never listed, only red's, and 5-9 are theirs.
	var blue_sees := FlagVision.visible_enemy_ids(m, s, B)
	assert_true(blue_sees.has(0) and blue_sees.has(1), "blue sees red 0 and 1")
	for id: int in blue_sees:
		assert_true(id < FlagState.SQUAD, "only enemies listed")


func test_tagged_viewers_still_see_and_tagged_enemies_stay_visible() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	for p: FlagState.Piece in s.pieces:
		p.tile = Vector2i(0, 10) if p.team == R else Vector2i(23, 10)
	s.piece(0).tile = Vector2i(10, 5)
	s.piece(0).tagged = true
	s.piece(5).tile = Vector2i(12, 5)
	assert_eq(FlagVision.visible_enemy_ids(m, s, R), [5] as Array[int], "tagged red sees")
	s.piece(5).tagged = true
	assert_eq(FlagVision.visible_enemy_ids(m, s, R), [5] as Array[int], "tagged blue still on tile")
