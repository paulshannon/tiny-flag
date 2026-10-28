class_name BoardOverlay
extends Node2D
## What BoardView draws over the terrain and under the pieces: tinted bases, the halfway
## line, and while planning the selected piece and every planned path: this turn's part
## in green with its cost, the rest (later turns) paler with how many turns it all takes,
## plus a touch tap's pending path.

const PATH_OK := Color(0.35, 0.95, 0.35, 0.9)
const PATH_LATER := Color(0.85, 0.95, 1.0, 0.55)
const PENDING := Color(1, 1, 1, 0.7)
const SELECT := Color(1, 0.95, 0.4, 0.95)
const FONT_SIZE: int = 8

var map: FlagMap
var model: OrderModel
var pending: Array[Vector2i] = []


func _draw() -> void:
	if map == null:
		return
	var t := float(FlagArt.TILE)
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		var tiles := map.base_tiles(team)
		var rect := Rect2(Vector2(tiles[0]) * t, Vector2(3, 3) * t)
		var col: Color = FlagArt.TEAM_COLOR[team]
		draw_rect(rect, Color(col, 0.22))
		draw_rect(rect, Color(col, 0.8), false, 1.0)
	var mid := float(map.width / 2) * t
	draw_dashed_line(Vector2(mid, t), Vector2(mid, (map.height - 1) * t), Color(1, 1, 1, 0.35), 1.0, 4.0)
	if model == null:
		return
	for id: int in model.piece_ids():
		_draw_path(id)
	if model.selected >= 0:
		var c := center(model.tile_of(model.selected))
		draw_arc(c, t * 0.55, 0, TAU, 20, SELECT, 1.5)
		if not pending.is_empty():
			var pts := PackedVector2Array([center(model.end_of(model.selected))])
			for s: Vector2i in pending:
				pts.append(center(s))
			draw_polyline(pts, PENDING, 1.5)
			draw_circle(pts[pts.size() - 1], 3.0, PENDING)


func _draw_path(id: int) -> void:
	var path := model.path_of(id)
	if path.is_empty():
		return
	var now := model.this_turn(id)
	var width := 2.0 if id == model.selected else 1.5
	var pts := PackedVector2Array([center(model.tile_of(id))])
	for s: Vector2i in path:
		pts.append(center(s))
	var split := now.size()  # pts[split] is where this turn's part ends
	if split < path.size():
		draw_polyline(pts.slice(split), PATH_LATER, width)
		var end := pts[pts.size() - 1]
		draw_circle(end, 2.5, PATH_LATER)
		_label(end, "%d turns" % model.turns_of(id), PATH_LATER)
	if split > 0:
		draw_polyline(pts.slice(0, split + 1), PATH_OK, width)
		draw_circle(pts[split], 2.5, PATH_OK)
		var spent := FlagPath.cost_of(map, model.tile_of(id), now)
		_label(pts[split], "%d/%d" % [spent, model.budget_of(id)], PATH_OK)


func _label(at_tile: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var at := at_tile + Vector2(-8, -5)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col.lightened(0.3))


static func center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * FlagArt.TILE
