extends TestCase
## FlagWire filtering checked over many random matches on the real farm map
## (split from test_tiny_flag_wire.gd to keep files short).

const R := FlagMap.RED
const B := FlagMap.BLUE


func _ids(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append(r[0])
	return out


func _random_orders(map: FlagMap, state: FlagState, rng: RandomNumberGenerator) -> Dictionary:
	var orders: Dictionary = {}
	for team: int in [R, B]:
		var raw: Array = []
		for p: FlagState.Piece in state.pieces:
			if p.team != team or p.tagged:
				continue
			var target := Vector2i(rng.randi_range(0, map.width - 1), rng.randi_range(0, map.height - 1))
			if rng.randf() < 0.5:
				target = map.flag_home(1 - team) + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			var path := FlagPath.find_path(map, p.tile, target)
			path = FlagPath.trim_to_budget(map, p.tile, path, state.move_points(p.id))
			if not path.is_empty():
				raw.append([p.id, FlagPath.encode(path)])
		orders.merge(FlagPath.validate_orders(map, state, team, raw))
	return orders


func test_no_leaks_in_random_matches() -> void:
	var m := FlagMap.load_map(FlagMap.FARM_PATH)
	var checked := 0
	var enemy_rows_seen := 0
	for seed_i: int in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var s := FlagState.new_match(m)
		for turn_i: int in 10:
			var o := FlagResolver.resolve(m, s, _random_orders(m, s, rng))
			for team: int in [R, B]:
				var t := FlagWire.turn_for(m, o, team)
				assert_eq(t["turn"], s.turn)
				for rows: Array in t["ticks"]:
					assert_eq(FlagWire.leaked_enemies(m, team, rows), [] as Array[int], "seed %d turn %d team %d" % [seed_i, turn_i, team])
					checked += 1
					for r: Array in rows:
						if r[1] != team:
							enemy_rows_seen += 1
			s = o.state
			for team: int in [R, B]:
				var v := FlagWire.view_for(m, s, team)
				assert_eq(FlagWire.leaked_enemies(m, team, v["pieces"]), [] as Array[int], "view seed %d turn %d team %d" % [seed_i, turn_i, team])
				# The view is exactly own pieces plus FlagVision's visible enemies.
				var want: Array = []
				for p: FlagState.Piece in s.pieces:
					if p.team == team:
						want.append(p.id)
				want.append_array(FlagVision.visible_enemy_ids(m, s, team))
				want.sort()
				var got := _ids(v["pieces"])
				got.sort()
				assert_eq(got, want, "view matches FlagVision")
	assert_eq(checked, 50 * 10 * 2 * FlagState.TICKS)
	assert_true(enemy_rows_seen > 0, "the matches actually showed some enemies")


## Spectator rows are the public view: a piece is there exactly when both teams can see
## it (own pieces count as seen by their team). Real tags are always kept.
func test_spectator_rows_are_public_in_random_matches() -> void:
	var m := FlagMap.load_map(FlagMap.FARM_PATH)
	var tags := 0
	var hidden_rows := 0
	for seed_i: int in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + seed_i
		var s := FlagState.new_match(m)
		for turn_i: int in 10:
			var o := FlagResolver.resolve(m, s, _random_orders(m, s, rng))
			var t := FlagWire.turn_for(m, o, FlagWire.SPECTATOR)
			var ticks: Array = t["ticks"]
			for k: int in ticks.size():
				var snap: FlagState = o.ticks[k]
				var want := _public_ids(m, snap)
				var got := _ids(ticks[k])
				got.sort()
				assert_eq(got, want, "seed %d turn %d tick %d" % [seed_i, turn_i, k + 1])
				hidden_rows += snap.pieces.size() - got.size()
			var all_tags := 0
			for e: Dictionary in o.events:
				if e["kind"] == "tag":
					all_tags += 1
			var kept_tags := 0
			for e: Dictionary in t["events"]:
				if e["kind"] == "tag":
					kept_tags += 1
			assert_eq(kept_tags, all_tags, "every real tag is public (seed %d turn %d)" % [seed_i, turn_i])
			tags += all_tags
			s = o.state
			var view := FlagWire.view_for(m, s, FlagWire.SPECTATOR)
			var vgot := _ids(view["pieces"])
			vgot.sort()
			assert_eq(vgot, _public_ids(m, s), "view seed %d turn %d" % [seed_i, turn_i])
	assert_true(tags > 0, "the matches had tags")
	assert_true(hidden_rows > 0, "spectators were shown less than everything")


func _public_ids(m: FlagMap, s: FlagState) -> Array:
	var seen_by_red := FlagVision.visible_enemy_ids(m, s, R)
	var seen_by_blue := FlagVision.visible_enemy_ids(m, s, B)
	var out: Array = []
	for p: FlagState.Piece in s.pieces:
		var red_sees := p.team == R or seen_by_red.has(p.id)
		var blue_sees := p.team == B or seen_by_blue.has(p.id)
		if red_sees and blue_sees:
			out.append(p.id)
	out.sort()
	return out
