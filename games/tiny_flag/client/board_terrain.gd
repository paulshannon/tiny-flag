class_name BoardTerrain
extends RefCounted
## Paints a FlagMap into two TileMapLayers sharing FlagArt.tile_set(): the ground (Tiny
## Battle grass and ponds, Tiny Farm dirt paths) and the props over it (Tiny Farm wheat,
## trees, hedges and hay bales). Bases are plain grass; BoardOverlay tints them.

const T := FlagMap.Terrain


static func paint(map: FlagMap, ground: TileMapLayer, props: TileMapLayer) -> void:
	ground.clear()
	props.clear()
	for y: int in map.height:
		for x: int in map.width:
			var c := Vector2i(x, y)
			match map.terrain(c):
				T.WATER:
					_put(ground, c, FlagArt.BATTLE, _water(map, c))
				T.PATH:
					_put(ground, c, FlagArt.FARM, _path(map, c))
				_:
					var grass: int = FlagArt.GRASS[(x * 7 + y * 13 + x * y) % FlagArt.GRASS.size()]
					_put(ground, c, FlagArt.BATTLE, grass)
			var prop := _prop(map, c)
			if prop >= 0:
				_put(props, c, FlagArt.FARM, prop)


static func _put(layer: TileMapLayer, c: Vector2i, source: int, index: int) -> void:
	var cols := FlagArt.FARM_COLUMNS if source == FlagArt.FARM else FlagArt.BATTLE_COLUMNS
	layer.set_cell(c, source, FlagArt.coords(index, cols))


static func _prop(map: FlagMap, c: Vector2i) -> int:
	match map.terrain(c):
		T.CROPS:
			return FlagArt.CROPS
		T.TREE:
			return FlagArt.TREE
		T.HEDGE:
			return FlagArt.HEDGE
		T.BUILDING:
			var left := Vector2i(c.x - 1, c.y)
			var after_wall := map.in_bounds(left) and map.terrain(left) == T.BUILDING
			return FlagArt.BUILDING_RIGHT if after_wall else FlagArt.BUILDING_LEFT
	return -1


static func _is(map: FlagMap, c: Vector2i, t: FlagMap.Terrain) -> bool:
	return map.in_bounds(c) and map.terrain(c) == t


## A dirt strip joined to its path neighbours; a crossing uses the across piece.
static func _path(map: FlagMap, c: Vector2i) -> int:
	var l := _is(map, c + Vector2i.LEFT, T.PATH)
	var r := _is(map, c + Vector2i.RIGHT, T.PATH)
	var u := _is(map, c + Vector2i.UP, T.PATH)
	var d := _is(map, c + Vector2i.DOWN, T.PATH)
	if l and r or (l or r) and (u or d):
		return FlagArt.PATH_ACROSS
	if r:
		return FlagArt.PATH_LEFT_END
	if l:
		return FlagArt.PATH_RIGHT_END
	if u and d:
		return FlagArt.PATH_DOWN
	if d:
		return FlagArt.PATH_TOP_END
	if u:
		return FlagArt.PATH_BOTTOM_END
	return FlagArt.PATH_ALONE


## Pond corners where two water sides meet, open water otherwise.
static func _water(map: FlagMap, c: Vector2i) -> int:
	var l := _is(map, c + Vector2i.LEFT, T.WATER)
	var r := _is(map, c + Vector2i.RIGHT, T.WATER)
	var u := _is(map, c + Vector2i.UP, T.WATER)
	var d := _is(map, c + Vector2i.DOWN, T.WATER)
	if r and d and not l and not u:
		return FlagArt.WATER_TOP_LEFT
	if l and d and not r and not u:
		return FlagArt.WATER_TOP_RIGHT
	if r and u and not l and not d:
		return FlagArt.WATER_BOTTOM_LEFT
	if l and u and not r and not d:
		return FlagArt.WATER_BOTTOM_RIGHT
	return FlagArt.WATER
