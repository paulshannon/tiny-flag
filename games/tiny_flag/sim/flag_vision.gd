class_name FlagVision
extends RefCounted
## Tiny Flag fog of war: who can see which tile. Pure rules, no nodes.
## Later tasks filter every message through this, so hidden pieces never leave the server.


## True if no tile strictly between the centres of `a` and `b` blocks sight.
## Walks the supercover line in integer arithmetic. Where the line passes exactly
## through a tile corner it is blocked only if both tiles sharing that corner block.
static func line_clear(map: FlagMap, a: Vector2i, b: Vector2i) -> bool:
	var nx := absi(b.x - a.x)
	var ny := absi(b.y - a.y)
	var sx := signi(b.x - a.x)
	var sy := signi(b.y - a.y)
	var x := a.x
	var y := a.y
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		# The line next meets a vertical grid line at t = (2ix+1)/(2nx) and a horizontal
		# one at (2iy+1)/(2ny); cross-multiplied so everything stays integer.
		var along_x := (2 * ix + 1) * ny
		var along_y := (2 * iy + 1) * nx
		if ix >= nx:
			y += sy
			iy += 1
		elif iy >= ny:
			x += sx
			ix += 1
		elif along_x < along_y:
			x += sx
			ix += 1
		elif along_x > along_y:
			y += sy
			iy += 1
		else:
			if map.blocks_sight(Vector2i(x + sx, y)) and map.blocks_sight(Vector2i(x, y + sy)):
				return false
			x += sx
			y += sy
			ix += 1
			iy += 1
		if (x != b.x or y != b.y) and map.blocks_sight(Vector2i(x, y)):
			return false
	return true


## Can any of `viewers` see a piece on `tile`? `carrying` pieces show regardless
## of distance, cover and line of sight.
static func can_see(map: FlagMap, viewers: Array[Vector2i], tile: Vector2i, carrying: bool) -> bool:
	if carrying:
		return true
	var radius_sq := FlagState.SIGHT_RADIUS * FlagState.SIGHT_RADIUS
	var hidden := map.hides(tile)
	for v: Vector2i in viewers:
		var d := tile - v
		if hidden:
			# Crops: only the same tile or an 8-neighbour (radius and LOS hold trivially).
			if absi(d.x) <= 1 and absi(d.y) <= 1:
				return true
		elif d.x * d.x + d.y * d.y <= radius_sq and line_clear(map, v, tile):
			return true
	return false


## Ids of `team`'s enemies that `team` can see. Every piece of `team` is a viewer,
## tagged ones included (they stand on their tile until respawn).
static func visible_enemy_ids(map: FlagMap, state: FlagState, team: int) -> Array[int]:
	var viewers: Array[Vector2i] = []
	for p: FlagState.Piece in state.pieces:
		if p.team == team:
			viewers.append(p.tile)
	var out: Array[int] = []
	for p: FlagState.Piece in state.pieces:
		if p.team != team and can_see(map, viewers, p.tile, state.is_carrying(p.id)):
			out.append(p.id)
	return out
