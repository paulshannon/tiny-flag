class_name OrderModel
extends RefCounted
## The orders a person is planning (spec §2 "Planning"): which own piece is selected and
## the path each piece will walk. Pure, no nodes: OrderInput feeds it clicks and taps,
## BoardView draws it, and wire_orders() is what TinyFlagGame.send_orders sends.
##
## Click an own piece to select it; click a tile to plan the cheapest path there, and
## click again to extend from the path's end (to route around things). A path may be
## longer than one turn: the part within the piece's points (this_turn) is sent, and the
## rest carries over to the next turn's plan, where it can still be changed. It carries
## over only if the piece ended the turn where that part ended (not tagged, not reset by
## a capture, not stopped by picking up a flag).

var map: FlagMap
## The turn being planned (view["turn"]); send_orders and send_lock_in use it.
var turn: int = -1
## Our side, or FlagWire.SPECTATOR.
var team: int = FlagWire.SPECTATOR
## Selected own piece id, -1 for none.
var selected: int = -1

## Own untagged pieces: id -> tile.
var _tiles: Dictionary = {}
## Own pieces carrying a flag: id -> true.
var _carrying: Dictionary = {}
## id -> Array[Vector2i]
var _paths: Dictionary = {}


func _init(board_map: FlagMap) -> void:
	map = board_map


## A turn_started view: our pieces this turn. Selection starts empty; paths start with
## what is left of last turn's multi-turn paths (see the class comment).
func set_view(view: Dictionary) -> void:
	var t: Variant = view.get("turn")
	var new_turn := int(t) if typeof(t) == TYPE_INT else -1
	var tm: Variant = view.get("team")
	var new_team := int(tm) if typeof(tm) == TYPE_INT else FlagWire.SPECTATOR
	# id -> [tile this turn's part ends on, the rest of the path]
	var carry: Dictionary = {}
	if new_turn == turn + 1 and new_team == team:
		for id: int in _paths:
			var now := this_turn(id)
			var rest := path_of(id).slice(now.size())
			if not now.is_empty() and not rest.is_empty():
				carry[id] = [now[now.size() - 1], rest]
	turn = new_turn
	team = new_team
	selected = -1
	_tiles = {}
	_carrying = {}
	_paths = {}
	if team < 0:
		return
	for row: Array in FlagClientTally._rows(view.get("pieces")):
		if row[1] == team and row[5] == 0:
			_tiles[row[0]] = Vector2i(row[2], row[3])
			if row[4] == 1:
				_carrying[row[0]] = true
	for id: int in carry:
		if _tiles.get(id, Vector2i(-1, -1)) == carry[id][0]:
			var rest: Array[Vector2i] = []
			rest.assign(carry[id][1])
			_paths[id] = rest


## Own untagged piece ids, ascending.
func piece_ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in _tiles:
		out.append(id)
	out.sort()
	return out


func tile_of(id: int) -> Vector2i:
	return _tiles.get(id, Vector2i(-1, -1))


func select(id: int) -> void:
	if _tiles.has(id):
		selected = id


## An own piece's tile selects it; any other passable tile plans the selected piece's
## path there, extending from the current path's end.
func click_tile(c: Vector2i) -> void:
	var own := piece_at(c)
	if own >= 0:
		selected = own
		return
	var step := preview(c)
	if step.is_empty():
		return
	var path := path_of(selected)
	path.append_array(step)
	_paths[selected] = path


## What click_tile(c) would add to the selected piece's path (empty if nothing).
func preview(c: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not _tiles.has(selected) or map.cost(c) < 0 or piece_at(c) >= 0:
		return none
	return FlagPath.find_path(map, end_of(selected), c)


## The own piece standing on `c` (lowest id), or -1.
func piece_at(c: Vector2i) -> int:
	for id: int in piece_ids():
		if _tiles[id] == c:
			return id
	return -1


func clear(id: int) -> void:
	_paths.erase(id)


func path_of(id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _paths.has(id):
		out.assign(_paths[id])
	return out


## Where the piece's path ends (its own tile if it has none).
func end_of(id: int) -> Vector2i:
	var path := path_of(id)
	return tile_of(id) if path.is_empty() else path[path.size() - 1]


## Cost of the whole path, all turns.
func cost_of(id: int) -> int:
	if not _tiles.has(id):
		return 0
	return FlagPath.cost_of(map, _tiles[id], path_of(id))


func budget_of(id: int) -> int:
	return FlagState.CARRIER_POINTS if _carrying.has(id) else FlagState.MOVE_POINTS


## The start of the path that fits in this turn's points: what is sent.
func this_turn(id: int) -> Array[Vector2i]:
	return FlagPath.trim_to_budget(map, tile_of(id), path_of(id), budget_of(id))


## True if the whole path fits in this turn.
func in_budget(id: int) -> bool:
	var path := path_of(id)
	return not path.is_empty() and this_turn(id).size() == path.size()


## Turns the whole path takes at this turn's points (0 with no path).
func turns_of(id: int) -> int:
	var rest := path_of(id)
	var at := tile_of(id)
	var turns := 0
	while not rest.is_empty():
		var now := FlagPath.trim_to_budget(map, at, rest, budget_of(id))
		if now.is_empty():
			break
		turns += 1
		at = now[now.size() - 1]
		rest = rest.slice(now.size())
	return turns


## [[piece_id, PackedInt32Array path], ...]: this turn's part of every path, by id.
func wire_orders() -> Array:
	var out: Array = []
	for id: int in piece_ids():
		var now := this_turn(id)
		if not now.is_empty():
			out.append([id, FlagPath.encode(now)])
	return out
