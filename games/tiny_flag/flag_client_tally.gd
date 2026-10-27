class_name FlagClientTally
extends RefCounted
## Client-side smoke checks for Tiny Flag (spec §4 smoke test), from only what the server
## sent: turns played back, enemies sent that the side's own pieces could not see
## (FlagWire.leaked_enemies, every tick and every view), and whether an own piece moved.
## No nodes, so it is unit-tested directly.

var turns: int = 0
var leaks: int = 0
var own_moved: bool = false
## The side the last turn_started view was for; FlagWire.SPECTATOR when watching.
var team: int = FlagWire.SPECTATOR

## Own untagged pieces last seen: id -> tile.
var _last: Dictionary = {}


## A turn_started view.
func on_view(map: FlagMap, view: Dictionary) -> void:
	var t: Variant = view.get("team")
	team = int(t) if typeof(t) == TYPE_INT else FlagWire.SPECTATOR
	_last = {}
	if team < 0:
		return
	var rows := _rows(view.get("pieces"))
	leaks += FlagWire.leaked_enemies(map, team, rows).size()
	_last = _own_tiles(rows)


## A turn_resolved playback.
func on_turn(map: FlagMap, turn: Dictionary) -> void:
	turns += 1
	if team < 0:
		return
	var ticks: Variant = turn.get("ticks")
	if typeof(ticks) != TYPE_ARRAY:
		return
	for tick: Variant in ticks:
		var rows := _rows(tick)
		leaks += FlagWire.leaked_enemies(map, team, rows).size()
		var now := _own_tiles(rows)
		for id: int in now:
			if _last.has(id) and _last[id] != now[id]:
				own_moved = true
		_last = now


## Back at select: the next messages may be a spectator's (the public view, checked by no side's sight), so stop
## checking as a side until a view says which side this is.
func forget_side() -> void:
	team = FlagWire.SPECTATOR
	_last = {}


func _own_tiles(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for r: Array in rows:
		if r[1] == team and r[5] == 0:
			out[r[0]] = Vector2i(r[2], r[3])
	return out


## Well-formed piece rows only ([id, team, x, y, carrying, tagged], all ints).
static func _rows(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	var list: Array = v
	for r: Variant in list:
		if typeof(r) != TYPE_ARRAY:
			continue
		var row: Array = r
		if row.size() != 6:
			continue
		var ok := true
		for x: Variant in row:
			if typeof(x) != TYPE_INT:
				ok = false
		if ok:
			out.append(row)
	return out
