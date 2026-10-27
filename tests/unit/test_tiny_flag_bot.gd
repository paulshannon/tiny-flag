extends TestCase

const R := FlagMap.RED
const B := FlagMap.BLUE


func _map() -> FlagMap:
	return FlagMap.load_map(FlagMap.FARM_PATH)


## Both bots play a full match; returns {"state", "turns", "tags", "pickups", "captures"}.
func _play(seed_a: int, seed_b: int) -> Dictionary:
	var m := _map()
	var s := FlagState.new_match(m)
	var bots: Array[FlagBot] = [FlagBot.new(seed_a), FlagBot.new(seed_b)]
	var counts := {"tag": 0, "pickup": 0, "capture": 0}
	var log: Array = []
	while s.result() == FlagState.Result.ONGOING:
		var merged: Dictionary = {}
		for team: int in [R, B]:
			var raw := bots[team].orders(m, FlagWire.view_for(m, s, team))
			merged.merge(FlagPath.validate_orders(m, s, team, raw))
		var out := FlagResolver.resolve(m, s, merged)
		for e: Dictionary in out.events:
			counts[e["kind"]] += 1
		log.append([out.state.score.duplicate(), out.events.size()])
		s = out.state
	return {"state": s, "turns": s.turn, "tags": counts["tag"], "pickups": counts["pickup"],
		"captures": counts["capture"], "log": log}


func test_orders_are_valid() -> void:
	var m := _map()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var total := 0
	for n: int in 20:
		var s := FlagState.new_match(m)
		s.turn = rng.randi_range(0, 30)
		for p: FlagState.Piece in s.pieces:
			var t := Vector2i(rng.randi_range(0, m.width - 1), rng.randi_range(0, m.height - 1))
			if m.cost(t) >= 0:
				p.tile = t
			p.tagged = rng.randf() < 0.15
		if rng.randf() < 0.7:
			s.carrier[R] = rng.randi_range(5, 9)
		if rng.randf() < 0.7:
			s.carrier[B] = rng.randi_range(0, 4)
		for team: int in [R, B]:
			var bot := FlagBot.new(n)
			var raw := bot.orders(m, FlagWire.view_for(m, s, team))
			var kept := FlagPath.validate_orders(m, s, team, raw)
			assert_eq(kept.size(), raw.size(), "every order kept (state %d team %d)" % [n, team])
			total += raw.size()
	assert_true(total > 0, "bots gave some orders")


func test_carrier_goes_home() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	s.piece(5).tile = Vector2i(6, 8)  # Blue piece with Red's flag, near Red's half
	s.carrier[R] = 5
	var bot := FlagBot.new(1)
	var raw := bot.orders(m, FlagWire.view_for(m, s, B))
	var found := false
	for o: Array in raw:
		if o[0] == 5:
			found = true
			var path := FlagPath.decode(o[1])
			var home := m.flag_home(B)
			var before := absi(6 - home.x) + absi(8 - home.y)
			var end := path[path.size() - 1]
			assert_true(absi(end.x - home.x) + absi(end.y - home.y) < before, "ends closer to home")
			var trimmed := FlagPath.trim_to_budget(m, Vector2i(6, 8), path, FlagState.CARRIER_POINTS)
			assert_eq(trimmed.size(), path.size(), "within carrier budget")
	assert_true(found, "carrier ordered")


func test_attacker_flees_nearby_enemy() -> void:
	var m := _map()
	var s := FlagState.new_match(m)
	s.piece(0).tile = Vector2i(22, 8)  # Red attacker on Blue's half
	s.piece(5).tile = Vector2i(24, 8)  # Blue piece 2 tiles east
	var raw := FlagBot.new(3).orders(m, FlagWire.view_for(m, s, R))
	var seen := false
	for o: Array in raw:
		if o[0] == 0:
			seen = true
			var first := FlagPath.decode(o[1])[0]
			assert_true(absi(first.x - 24) + absi(first.y - 8) > 2, "steps away")
	assert_true(seen, "attacker ordered")


func test_bot_vs_bot_finishes() -> void:
	var r := _play(1, 2)
	var s: FlagState = r["state"]
	assert_true(s.turn <= FlagState.TURN_LIMIT, "ends by turn 40")
	assert_true(s.result() != FlagState.Result.ONGOING, "has result")
	assert_true(r["tags"] >= 1, "at least one tag")
	assert_true(r["pickups"] >= 1, "at least one pickup")


func test_same_seed_same_match() -> void:
	var a := _play(1, 2)
	var b := _play(1, 2)
	assert_eq(str(a["log"]), str(b["log"]), "identical matches")
	assert_eq(a["turns"], b["turns"])

