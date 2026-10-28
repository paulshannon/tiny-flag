class_name BoardOverlay
extends Node2D
## What BoardView draws over the terrain and under the pieces: tinted bases, the halfway
## line, and while planning the selected piece and every planned path with its cost
## (green within the piece's points, red over them), plus a touch tap's pending path.

const PATH_OK := Color(0.35, 0.95, 0.35, 0.9)
const PATH_OVER := Color(1.0, 0.3, 0.25, 0.9)
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
	var col := PATH_OK if model.in_budget(id) else PATH_OVER
	var pts := PackedVector2Array([center(model.tile_of(id))])
	for s: Vector2i in path:
		pts.append(center(s))
	draw_polyline(pts, col, 2.0 if id == model.selected else 1.5)
	var end := pts[pts.size() - 1]
	draw_circle(end, 2.5, col)
	var label := "%d/%d" % [model.cost_of(id), model.budget_of(id)]
	var font := ThemeDB.fallback_font
	var at := end + Vector2(-8, -5)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color(0, 0, 0, 0.8))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col.lightened(0.3))


static func center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * FlagArt.TILE
