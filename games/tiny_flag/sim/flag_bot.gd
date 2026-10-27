class_name FlagBot
extends RefCounted
## Plays one Tiny Flag side from a FlagWire view alone (no FlagState), so it gives the
## same orders on the server and on a client. Seeded: same seed and views, same orders.
##
## Piece ids team*5 + 0..1 attack, +2..4 defend; a carrier always heads home.

const ATTACKERS: int = 2
## A visible enemy this close (Manhattan) makes an attacker back off.
const FLEE_RANGE: int = 3
## Defenders idle within this distance of their flag.
const HOLD_RADIUS: int = 4
const LANE_SPREAD: int = 2
const LANE_DEPTH: int = 3

var _rng := RandomNumberGenerator.new()
## Piece id -> the tile that defender holds, chosen on first use.
var _hold: Dictionary = {}
## Piece id -> row offset of that attacker's approach lane.
var _lane: Dictionary = {}


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## Wire orders for view["team"]: Array of [piece_id, PackedInt32Array]. No entry for a
## piece that stays put.
func orders(map: FlagMap, view: Dictionary) -> Array:
	var team: int = view["team"]
	var rows: Array = view["pieces"]
	var flags: Array = view["flags"]
	var enemy_flag := Vector2i(flags[1 - team][0], flags[1 - team][1])
	var enemies: Array[Vector2i] = []
	for r: Array in rows:
		if r[1] != team and r[5] == 0:  # defensive: tagged pieces respawn at turn end, so a turn-start view has none
			enemies.append(Vector2i(r[2], r[3]))
	var out: Array = []
	for r: Array in rows:
		if r[1] != team or r[5] == 1:
			continue
		var id: int = r[0]
		var at := Vector2i(r[2], r[3])
		var carrying: bool = r[4] == 1
		var budget := FlagState.CARRIER_POINTS if carrying else FlagState.MOVE_POINTS
		var path: Array[Vector2i] = []
		if carrying:
			path = FlagPath.find_path(map, at, map.flag_home(team))
		elif id % FlagState.SQUAD < ATTACKERS:
			path = _attack(map, team, id, at, enemy_flag, enemies, budget)
		else:
			path = _defend(map, team, id, at, enemies)
		path = FlagPath.trim_to_budget(map, at, path, budget)
		if not path.is_empty():
			out.append([id, FlagPath.encode(path)])
	return out


func _attack(map: FlagMap, team: int, id: int, at: Vector2i, flag: Vector2i, enemies: Array[Vector2i], budget: int) -> Array[Vector2i]:
	# Two attackers closing head-on tag each other; back off from any enemy this close.
	var near := _nearest(at, enemies)
	if near.x >= 0 and _dist(at, near) <= FLEE_RANGE:
		var step := _step_away(map, at, near, budget)
		if not step.is_empty():
			return step
	var path := FlagPath.find_path(map, at, _via_lane(map, team, id, at, flag))
	return path if not path.is_empty() else FlagPath.find_path(map, at, flag)


## Attackers approach on their own seeded lane (a row off the road) until past the midline,
## so two attackers do not meet head-on in the corridor.
func _via_lane(map: FlagMap, team: int, id: int, at: Vector2i, flag: Vector2i) -> Vector2i:
	if not _lane.has(id):
		_lane[id] = _rng.randi_range(-LANE_SPREAD, LANE_SPREAD)
	var dir := 1 if team == FlagMap.RED else -1
	var gate := Vector2i(map.width / 2 + dir * LANE_DEPTH - (1 if dir < 0 else 0), flag.y + int(_lane[id]))
	if (gate.x - at.x) * dir <= 0 or map.cost(gate) < 0:
		return flag
	return gate


func _defend(map: FlagMap, team: int, id: int, at: Vector2i, enemies: Array[Vector2i]) -> Array[Vector2i]:
	var own_half: Array[Vector2i] = []
	for e: Vector2i in enemies:
		if map.side_of(e) == team:
			own_half.append(e)
	var near := _nearest(at, own_half)
	if near.x >= 0:
		return FlagPath.find_path(map, at, near)
	if not _hold.has(id):
		_hold[id] = _pick_hold(map, team)
	return FlagPath.find_path(map, at, _hold[id])


## A seeded passable tile within HOLD_RADIUS of the team's flag home.
func _pick_hold(map: FlagMap, team: int) -> Vector2i:
	var home := map.flag_home(team)
	var tiles: Array[Vector2i] = []
	for dy: int in range(-HOLD_RADIUS, HOLD_RADIUS + 1):
		for dx: int in range(-HOLD_RADIUS, HOLD_RADIUS + 1):
			var t := home + Vector2i(dx, dy)
			if absi(dx) + absi(dy) <= HOLD_RADIUS and map.cost(t) >= 0:
				tiles.append(t)
	return tiles[_rng.randi_range(0, tiles.size() - 1)]


## One step to the neighbour that is farther from `threat` than `at` is (seeded tie-break);
## empty if none is.
func _step_away(map: FlagMap, at: Vector2i, threat: Vector2i, budget: int) -> Array[Vector2i]:
	var best := _dist(at, threat)
	var picks: Array[Vector2i] = []
	for d: Vector2i in FlagPath.DIRS:
		var n := at + d
		var c := map.cost(n)
		if c < 0 or c > budget:
			continue
		var dn := _dist(n, threat)
		if dn > best:
			best = dn
			picks.clear()
		if dn == best and dn > _dist(at, threat):
			picks.append(n)
	var out: Array[Vector2i] = []
	if not picks.is_empty():
		out.append(picks[_rng.randi_range(0, picks.size() - 1)])
	return out


## Closest of `tiles` to `at` (first wins ties); (-1, -1) if there are none.
func _nearest(at: Vector2i, tiles: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for t: Vector2i in tiles:
		var d := _dist(at, t)
		if d < best_d:
			best_d = d
			best = t
	return best


func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
