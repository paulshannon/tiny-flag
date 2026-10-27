class_name FlagResolver
extends RefCounted
## Resolves one Tiny Flag turn in lockstep: TICKS ticks of move, meet, pick up, capture
## (spec §2 "Resolution"). Pure rules, no nodes; deterministic for the same input.


class Outcome:
	## The board after the turn (turn number advanced).
	var state: FlagState
	## One snapshot after each tick; after a capture the rest repeat the reset board.
	var ticks: Array[FlagState] = []
	## {"tick","kind":"tag","piece","by"} / {"tick","kind":"pickup","piece","flag"} /
	## {"tick","kind":"capture","piece","team"}, in tick order, then piece id order.
	var events: Array[Dictionary] = []


## Working data for one resolve.
class _Run:
	var map: FlagMap
	var s: FlagState
	var events: Array[Dictionary] = []
	## piece id -> tiles still to enter.
	var paths: Dictionary = {}
	## Per piece: half-points spent on tiles entered so far this turn.
	var spent: Array[int] = []
	## Per piece: tile before this tick's move.
	var prev: Array[Vector2i] = []
	## Per piece: entered a tile this tick.
	var moved: Array[bool] = []
	## A capture happened: no more movement this turn.
	var done: bool = false


## Does not mutate `state`. `orders` is FlagPath.validate_orders output (both teams merged).
static func resolve(map: FlagMap, state: FlagState, orders: Dictionary) -> Outcome:
	var run := _Run.new()
	run.map = map
	run.s = state.copy()
	var respawned := _respawn(run)
	_take_orders(run, orders, respawned)
	var out := Outcome.new()
	for tick: int in range(1, FlagState.TICKS + 1):
		if not run.done:
			_move(run, tick)
			_meet(run, tick)
			_pickups(run, tick)
			_captures(run, tick)
		out.ticks.append(run.s.copy())
	_respawn(run)  # the next turn is planned with everyone home and free
	run.s.turn = state.turn + 1
	out.state = run.s
	out.events = run.events
	return out


## Tagged pieces reappear untagged on their own home tile. Returns their ids. Run at the
## end of a turn (the ticks keep showing where they were caught); at the start it is a
## no-op guard for hand-built states that still carry tagged pieces.
static func _respawn(run: _Run) -> Array[int]:
	var ids: Array[int] = []
	for p: FlagState.Piece in run.s.pieces:
		if p.tagged:
			p.tile = run.map.home_tiles(p.team)[p.id % FlagState.SQUAD]
			p.tagged = false
			ids.append(p.id)
	return ids


static func _take_orders(run: _Run, orders: Dictionary, respawned: Array[int]) -> void:
	var n := run.s.pieces.size()
	run.spent.resize(n)
	run.spent.fill(0)
	run.prev.resize(n)
	run.moved.resize(n)
	for key: Variant in orders:
		if typeof(key) != TYPE_INT or typeof(orders[key]) != TYPE_ARRAY:
			continue
		var id: int = key
		# A piece respawned at the start (hand-built input) had no valid orders; its old
		# path would not start at its home tile anyway.
		if id < 0 or id >= n or respawned.has(id):
			continue
		var path: Array[Vector2i] = []
		path.assign(orders[key])
		run.paths[id] = path


## Every piece whose running cost reaches its next tile this tick enters it, all at once.
static func _move(run: _Run, tick: int) -> void:
	for p: FlagState.Piece in run.s.pieces:
		run.prev[p.id] = p.tile
		run.moved[p.id] = false
		if p.tagged or not run.paths.has(p.id):
			continue
		var path: Array[Vector2i] = run.paths[p.id]
		if path.is_empty():
			continue
		var next := path[0]
		var c := run.map.cost(next)
		var d := next - p.tile
		var total := run.spent[p.id] + c
		if c < 0 or absi(d.x) + absi(d.y) != 1 or total > run.s.move_points(p.id):
			run.paths.erase(p.id)  # bad step, or a carrier out of points: stop here
			continue
		if total != tick:
			continue
		p.tile = next
		path.remove_at(0)
		run.spent[p.id] = total
		run.moved[p.id] = true


## Red–Blue pairs on one tile, or swapped this tick, meet; each on enemy ground is tagged.
static func _meet(run: _Run, tick: int) -> void:
	var by: Dictionary = {}  # tagged id -> the other piece of its first meeting
	for a: FlagState.Piece in run.s.pieces:
		if a.team != FlagMap.RED or a.tagged:
			continue
		for b: FlagState.Piece in run.s.pieces:
			if b.team != FlagMap.BLUE or b.tagged or not _met(run, a, b):
				continue
			for pair: Array in [[a, b], [b, a]]:
				var x: FlagState.Piece = pair[0]
				var y: FlagState.Piece = pair[1]
				if run.map.side_of(x.tile) != x.team and not by.has(x.id):
					by[x.id] = y.id
	var ids: Array = by.keys()
	ids.sort()
	for id: int in ids:
		_tag(run, run.s.piece(id))
		run.events.append({"tick": tick, "kind": "tag", "piece": id, "by": by[id]})


static func _met(run: _Run, a: FlagState.Piece, b: FlagState.Piece) -> bool:
	if a.tile == b.tile:
		return true
	return a.tile == run.prev[b.id] and b.tile == run.prev[a.id]


## Stops the piece for the rest of the turn; a carried flag goes home.
static func _tag(run: _Run, p: FlagState.Piece) -> void:
	p.tagged = true
	run.paths.erase(p.id)
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		if run.s.carrier[team] == p.id:
			run.s.carrier[team] = -1


## An untagged piece that entered the enemy flag's tile (flag at home) picks it up.
static func _pickups(run: _Run, tick: int) -> void:
	for p: FlagState.Piece in run.s.pieces:
		var enemy := 1 - p.team
		if p.tagged or not run.moved[p.id] or run.s.carrier[enemy] != -1:
			continue
		if p.tile == run.map.flag_home(enemy):
			run.s.carrier[enemy] = p.id
			run.events.append({"tick": tick, "kind": "pickup", "piece": p.id, "flag": enemy})


## A carrier inside its own base scores; any capture resets the board and ends movement.
static func _captures(run: _Run, tick: int) -> void:
	for p: FlagState.Piece in run.s.pieces:
		if p.tagged or run.s.carrier[1 - p.team] != p.id or not run.map.in_base(p.tile, p.team):
			continue
		run.s.score[p.team] += 1
		run.events.append({"tick": tick, "kind": "capture", "piece": p.id, "team": p.team})
		run.done = true
	if run.done:
		run.s.reset_positions(run.map)
		run.paths.clear()
