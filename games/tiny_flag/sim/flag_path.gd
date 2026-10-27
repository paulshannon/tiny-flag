class_name FlagPath
extends RefCounted
## Pathfinding and order validation for Tiny Flag. Pure rules, no nodes.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Most order entries looked at in one payload; the rest is ignored.
const MAX_ORDERS_SEEN: int = 16
## Wire coordinates beyond this are junk whatever the map (also keeps ints small).
const MAX_COORD: int = 4096


## Cheapest tiles to enter from `from` to `to` (excluding `from`). Ties: up, right, down, left.
static func find_path(map: FlagMap, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or map.cost(to) < 0 or not map.in_bounds(from):
		return out
	var best: Dictionary = {from: 0}
	var came: Dictionary = {}
	var open: Array = [[_h(from, to), 0, from]]  # [f, seq, tile]
	var seq := 0
	while not open.is_empty():
		var bi := 0
		for i: int in range(1, open.size()):
			var a: Array = open[i]
			var b: Array = open[bi]
			if a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]):
				bi = i
		var cur_entry: Array = open[bi]
		open.remove_at(bi)
		var cur: Vector2i = cur_entry[2]
		var g: int = best[cur]
		if cur_entry[0] != g + _h(cur, to):
			continue  # stale entry
		if cur == to:
			break
		for d: Vector2i in DIRS:
			var n := cur + d
			var c := map.cost(n)
			if c < 0:
				continue
			var ng := g + c
			if not best.has(n) or ng < int(best[n]):
				best[n] = ng
				came[n] = cur
				seq += 1
				open.append([ng + _h(n, to), seq, n])
	if not came.has(to):
		return out
	var t := to
	while t != from:
		out.append(t)
		t = came[t]
	out.reverse()
	return out


static func _h(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Total cost of entering `path` from `from`; -1 if a step isn't 4-adjacent or is impassable.
static func cost_of(map: FlagMap, from: Vector2i, path: Array[Vector2i]) -> int:
	var total := 0
	var cur := from
	for step: Vector2i in path:
		var d := step - cur
		if absi(d.x) + absi(d.y) != 1:
			return -1
		var c := map.cost(step)
		if c < 0:
			return -1
		total += c
		cur = step
	return total


## The longest prefix of `path` whose cost fits in `budget`; stops at the first bad step.
static func trim_to_budget(map: FlagMap, from: Vector2i, path: Array[Vector2i], budget: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var spent := 0
	var cur := from
	for step: Vector2i in path:
		var d := step - cur
		var c := map.cost(step)
		if absi(d.x) + absi(d.y) != 1 or c < 0 or spent + c > budget:
			break
		spent += c
		out.append(step)
		cur = step
	return out


static func encode(path: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t: Vector2i in path:
		out.append(t.x)
		out.append(t.y)
	return out


## Flat x,y pairs (PackedInt32Array or Array of ints) -> tiles. Empty on anything malformed.
static func decode(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var typ := typeof(raw)
	if typ != TYPE_PACKED_INT32_ARRAY and typ != TYPE_ARRAY:
		return out
	var n: int = raw.size()
	if n % 2 != 0 or n > 2 * FlagState.MAX_PATH:
		return out
	var tiles: Array[Vector2i] = []
	for i: int in range(0, n, 2):
		var x: Variant = raw[i]
		var y: Variant = raw[i + 1]
		if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT:
			return out
		var xi: int = x
		var yi: int = y
		if xi < 0 or yi < 0 or xi > MAX_COORD or yi > MAX_COORD:
			return out
		tiles.append(Vector2i(xi, yi))
	return tiles


## Wire orders -> {piece_id: Array[Vector2i]}. Each bad order is dropped alone.
static func validate_orders(map: FlagMap, state: FlagState, team: int, raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_ARRAY:
		return out
	var entries: Array = raw
	for i: int in mini(entries.size(), MAX_ORDERS_SEEN):
		var entry: Variant = entries[i]
		if typeof(entry) != TYPE_ARRAY:
			continue
		var order: Array = entry
		if order.size() != 2 or typeof(order[0]) != TYPE_INT:
			continue
		var id: int = order[0]
		if id < 0 or id >= state.pieces.size() or out.has(id):
			continue
		var p := state.piece(id)
		if p.team != team or p.tagged:
			continue
		var path := decode(order[1])
		if path.is_empty():
			continue
		var cost := cost_of(map, p.tile, path)
		if cost < 0 or cost > state.move_points(id):
			continue
		out[id] = path
	return out
