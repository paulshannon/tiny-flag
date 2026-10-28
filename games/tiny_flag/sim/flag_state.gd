class_name FlagState
extends RefCounted
## Mutable Tiny Flag match state: pieces, who carries which flag, score, turn.
## Pure rules, no nodes.

const SQUAD: int = 5
const MOVE_POINTS: int = 8
const CARRIER_POINTS: int = 6
const SIGHT_RADIUS: int = 5
const TICKS: int = 8
const MAX_PATH: int = 16
const CAPTURES_TO_WIN: int = 3
## The farm is 64 tiles wide: one capture takes ~17 turns at best (road out, carrier back).
const TURN_LIMIT: int = 80

enum Result { ONGOING = -1, RED_WINS = 0, BLUE_WINS = 1, DRAW = 2 }


class Piece:
	var id: int = 0
	var team: int = 0
	var tile: Vector2i = Vector2i.ZERO
	var tagged: bool = false


## Ids 0-4 Red, 5-9 Blue.
var pieces: Array[Piece] = []
## carrier[t] = id of the piece holding team t's flag, or -1 if it is home.
var carrier: Array[int] = [-1, -1]
var score: Array[int] = [0, 0]
var turn: int = 0


static func new_match(map: FlagMap) -> FlagState:
	var s := FlagState.new()
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		for i: int in SQUAD:
			var p := Piece.new()
			p.id = team * SQUAD + i
			p.team = team
			s.pieces.append(p)
	s.reset_positions(map)
	return s


func copy() -> FlagState:
	var s := FlagState.new()
	for p: Piece in pieces:
		var q := Piece.new()
		q.id = p.id
		q.team = p.team
		q.tile = p.tile
		q.tagged = p.tagged
		s.pieces.append(q)
	s.carrier = carrier.duplicate()
	s.score = score.duplicate()
	s.turn = turn
	return s


func piece(id: int) -> Piece:
	return pieces[id]


func is_carrying(id: int) -> bool:
	return carrier[FlagMap.RED] == id or carrier[FlagMap.BLUE] == id


## Where team `team`'s flag is: on its carrier, else at home.
func flag_tile(map: FlagMap, team: int) -> Vector2i:
	if carrier[team] >= 0:
		return pieces[carrier[team]].tile
	return map.flag_home(team)


## Everyone home and untagged, flags home.
func reset_positions(map: FlagMap) -> void:
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		var homes := map.home_tiles(team)
		for i: int in SQUAD:
			var p := pieces[team * SQUAD + i]
			p.tile = homes[i]
			p.tagged = false
	carrier = [-1, -1]


func move_points(id: int) -> int:
	return CARRIER_POINTS if is_carrying(id) else MOVE_POINTS


func result() -> Result:
	var red := score[FlagMap.RED]
	var blue := score[FlagMap.BLUE]
	if red >= CAPTURES_TO_WIN and red > blue:
		return Result.RED_WINS
	if blue >= CAPTURES_TO_WIN and blue > red:
		return Result.BLUE_WINS
	if red >= CAPTURES_TO_WIN or blue >= CAPTURES_TO_WIN or turn >= TURN_LIMIT:
		if red > blue:
			return Result.RED_WINS
		if blue > red:
			return Result.BLUE_WINS
		return Result.DRAW
	return Result.ONGOING
