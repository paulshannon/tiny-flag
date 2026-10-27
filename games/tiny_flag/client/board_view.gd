class_name BoardView
extends Node2D
## The farm board on a client: terrain, both bases, pieces (Tiny Battle soldiers), flags,
## planned paths, faded "last seen" markers, and the playback of a resolved turn
## (about TICK_SECONDS per tick). Draws only what the server sent: a view's rows, then each
## tick's rows. A spectator may get a turn with no view before it, so ticks' rows alone
## are enough to draw from.
##
## Last-seen markers are client-side only: when an enemy that was drawn drops out of the
## rows, a faded soldier stays on its last tile until it is seen again or a capture
## resets the board.

## Emitted when a turn's playback has been drawn (TinyFlagGame.send_playback_done).
signal playback_finished(turn: int)
## Emitted as playback reaches each witnessed event ({"tick", "kind", ...}).
signal event_shown(event: Dictionary)

const TICK_SECONDS: float = 0.3
## Pieces moving further than this in one tick (a reset) jump instead of sliding.
const SLIDE_MAX: float = 1.5 * FlagArt.TILE
const TAGGED := Color(0.55, 0.55, 0.55, 0.6)
const MARKER := Color(1, 1, 1, 0.35)
const CARRIED_OFFSET := Vector2(5, -6)

var map: FlagMap
## The side whose view we draw (FlagWire.SPECTATOR draws everyone, no markers).
var team: int = FlagWire.SPECTATOR

var _ground: TileMapLayer
var _props: TileMapLayer
var _overlay: BoardOverlay
var _marker_root: Node2D
var _piece_root: Node2D
## id -> Sprite2D, id -> team, id -> tile last drawn.
var _sprites: Dictionary = {}
var _team_of: Dictionary = {}
var _tile: Dictionary = {}
## id -> Sprite2D (faded enemy on its last seen tile).
var _markers: Dictionary = {}
var _flags: Array[Sprite2D] = []
## Per flag: id of the visible piece carrying it, or -1 (home).
var _carrier: Array[int] = [-1, -1]

## The turn of the last view shown.
var _view_turn: int = -1

# Playback.
var _turn: int = -1
var _ticks: Array = []
var _events: Array = []
var _tick: int = 0
var _t: float = 0.0
var _from: Dictionary = {}
var _to: Dictionary = {}


func set_map(board_map: FlagMap) -> void:
	map = board_map
	if _ground == null:
		_build()
	BoardTerrain.paint(map, _ground, _props)
	_overlay.map = map
	_overlay.queue_redraw()
	for t: int in [FlagMap.RED, FlagMap.BLUE]:
		_carrier[t] = -1
	_place_flags()


func _build() -> void:
	var ts := FlagArt.tile_set()
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = ts
	add_child(_ground)
	_props = TileMapLayer.new()
	_props.name = "Props"
	_props.tile_set = ts
	add_child(_props)
	_overlay = BoardOverlay.new()
	_overlay.name = "Overlay"
	add_child(_overlay)
	_marker_root = Node2D.new()
	_marker_root.name = "LastSeen"
	add_child(_marker_root)
	_piece_root = Node2D.new()
	_piece_root.name = "Pieces"
	add_child(_piece_root)
	for t: int in [FlagMap.RED, FlagMap.BLUE]:
		var s := Sprite2D.new()
		s.name = "Flag%d" % t
		s.texture = FlagArt.battle_tile(FlagArt.FLAG[t])
		s.z_index = 1
		add_child(s)
		_flags.append(s)


## Scales by the largest whole zoom that fits the board between `top` and `bottom`
## margins of a `size` viewport, centred.
func fit(size: Vector2, top: float, bottom: float) -> void:
	var w := float(map.width * FlagArt.TILE)
	var h := float(map.height * FlagArt.TILE)
	var zoom := maxf(1.0, floorf(minf(size.x / w, (size.y - top - bottom) / h)))
	scale = Vector2(zoom, zoom)
	position = Vector2(roundf((size.x - w * zoom) / 2.0),
			roundf(top + maxf(0.0, (size.y - top - bottom - h * zoom) / 2.0)))


func tile_at(screen_pos: Vector2) -> Vector2i:
	var local := _screen_xform().affine_inverse() * screen_pos
	return Vector2i(floori(local.x / FlagArt.TILE), floori(local.y / FlagArt.TILE))


func tile_center(c: Vector2i) -> Vector2:
	return _screen_xform() * BoardOverlay.center(c)


func _screen_xform() -> Transform2D:
	return get_global_transform_with_canvas() if is_inside_tree() else transform


## A turn_started view: draw it as is (ends any playback still running).
func show_view(view: Dictionary) -> void:
	_turn = -1
	var t: Variant = view.get("team")
	var new_team := int(t) if typeof(t) == TYPE_INT else FlagWire.SPECTATOR
	var n: Variant = view.get("turn")
	var turn := int(n) if typeof(n) == TYPE_INT else -1
	# Another side, or a new match: what we saw before is stale.
	if new_team != team or turn < _view_turn:
		clear_markers()
	team = new_team
	_view_turn = turn
	_apply_rows(FlagClientTally._rows(view.get("pieces")), false)
	_finish_slides()


## Planned paths (null hides them), and a touch tap's pending path.
func show_paths(model: OrderModel, pending: Array[Vector2i] = []) -> void:
	_overlay.model = model
	_overlay.pending = pending
	_overlay.queue_redraw()


## A turn_resolved playback; playback_finished(turn) follows after the last tick.
func play_turn(turn: Dictionary) -> void:
	_turn = int(turn.get("turn", -1))
	var ticks: Variant = turn.get("ticks")
	var events: Variant = turn.get("events")
	_ticks = ticks if typeof(ticks) == TYPE_ARRAY else []
	_events = events if typeof(events) == TYPE_ARRAY else []
	_tick = 0
	_t = 0.0
	if _ticks.is_empty():
		_end_playback()
		return
	_begin_tick()


func is_playing() -> bool:
	return _turn >= 0


func clear_markers() -> void:
	for id: int in _markers:
		var m: Sprite2D = _markers[id]
		m.queue_free()
	_markers = {}


func marker_tiles() -> Dictionary:
	var out: Dictionary = {}
	for id: int in _markers:
		out[id] = _tile[id]
	return out


func _process(delta: float) -> void:
	if _turn < 0:
		return
	_t += delta
	var k := clampf(_t / TICK_SECONDS, 0.0, 1.0)
	for id: int in _from:
		var s: Sprite2D = _sprites[id]
		s.position = (_from[id] as Vector2).lerp(_to[id], k)
	_place_flags()
	if _t < TICK_SECONDS:
		return
	_finish_slides()
	_tick += 1
	_t = 0.0
	if _tick >= _ticks.size():
		_end_playback()
	else:
		_begin_tick()


func _begin_tick() -> void:
	for e: Variant in _events:
		if typeof(e) == TYPE_DICTIONARY and int((e as Dictionary).get("tick", -1)) == _tick + 1:
			if (e as Dictionary).get("kind") == "capture":
				clear_markers()
			event_shown.emit(e)
	_apply_rows(FlagClientTally._rows(_ticks[_tick]), true)


func _end_playback() -> void:
	var turn := _turn
	_turn = -1
	_finish_slides()
	playback_finished.emit(turn)


func _finish_slides() -> void:
	for id: int in _to:
		var s: Sprite2D = _sprites[id]
		s.position = _to[id]
	_from = {}
	_to = {}
	_place_flags()


## Draws `rows` ([id, team, x, y, carrying, tagged]); pieces missing from them are hidden,
## and an enemy that was drawn leaves a last-seen marker.
func _apply_rows(rows: Array, slide: bool) -> void:
	_finish_slides()
	var seen: Dictionary = {}
	_carrier = [-1, -1]
	for r: Array in rows:
		var id: int = r[0]
		var piece_team: int = r[1]
		if piece_team != FlagMap.RED and piece_team != FlagMap.BLUE or id < 0:
			continue
		seen[id] = true
		var s := _sprite(id, piece_team)
		var c := Vector2i(r[2], r[3])
		var target := BoardOverlay.center(c)
		if slide and s.visible and s.position.distance_to(target) <= SLIDE_MAX:
			_from[id] = s.position
			_to[id] = target
		else:
			s.position = target
		s.visible = true
		s.modulate = TAGGED if r[5] == 1 else Color.WHITE
		s.z_index = -1 if r[5] == 1 else 0  # a tagger sharing the tile stays on top
		_tile[id] = c
		if r[4] == 1:
			_carrier[1 - piece_team] = id
		if _markers.has(id):
			(_markers[id] as Sprite2D).queue_free()
			_markers.erase(id)
	for id: int in _sprites:
		var s: Sprite2D = _sprites[id]
		if seen.has(id) or not s.visible:
			continue
		s.visible = false
		if team >= 0 and _team_of[id] != team:
			_add_marker(id)


func _add_marker(id: int) -> void:
	var m := Sprite2D.new()
	m.texture = FlagArt.battle_tile(FlagArt.SOLDIER[_team_of[id]])
	m.modulate = MARKER
	m.position = BoardOverlay.center(_tile[id])
	_marker_root.add_child(m)
	_markers[id] = m


func _sprite(id: int, piece_team: int) -> Sprite2D:
	if _sprites.has(id) and _team_of[id] == piece_team:
		return _sprites[id]
	if _sprites.has(id):
		(_sprites[id] as Sprite2D).queue_free()
	var s := Sprite2D.new()
	s.name = "Piece%d" % id
	s.texture = FlagArt.battle_tile(FlagArt.SOLDIER[piece_team])
	s.visible = false
	_piece_root.add_child(s)
	_sprites[id] = s
	_team_of[id] = piece_team
	return s


## Each flag on its carrier (always drawn: carriers always show), else at home.
func _place_flags() -> void:
	if map == null or _flags.is_empty():
		return
	for t: int in [FlagMap.RED, FlagMap.BLUE]:
		var id := _carrier[t]
		if id >= 0 and _sprites.has(id):
			_flags[t].position = (_sprites[id] as Sprite2D).position + CARRIED_OFFSET
			_flags[t].scale = Vector2(0.75, 0.75)
		else:
			_flags[t].position = BoardOverlay.center(map.flag_home(t))
			_flags[t].scale = Vector2.ONE
