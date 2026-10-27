class_name FlagWire
extends RefCounted
## Builds exactly what the server sends each Tiny Flag team (spec §2 "Vision" and
## "Playback"). This is where fog of war is enforced: an enemy a team can't see is
## never in its data. Pure rules, no nodes.
##
## Piece row: [id, team, x, y, carrying (0/1), tagged (0/1)], plain ints so it travels as is.

## Team value for spectators: they get everything.
const SPECTATOR: int = -1


## The board as `team` sees it between turns.
## {"turn", "team", "score": [r, b], "turn_limit", "pieces": rows, "flags": [[x, y], [x, y]], "result"}
static func view_for(map: FlagMap, state: FlagState, team: int) -> Dictionary:
	var flags: Array = []
	for t: int in [FlagMap.RED, FlagMap.BLUE]:
		var tile := state.flag_tile(map, t)
		flags.append([tile.x, tile.y])
	return {
		"turn": state.turn,
		"team": team,
		"score": [state.score[FlagMap.RED], state.score[FlagMap.BLUE]],
		"turn_limit": FlagState.TURN_LIMIT,
		"pieces": _rows_for(map, state, team),
		"flags": flags,
		"result": int(state.result()),
	}


## A resolved turn as `team` saw it: per tick the own pieces plus the enemies visible in
## that tick's snapshot, and the events the team witnessed.
## {"turn": the turn that was resolved, "ticks": [rows per tick], "events": [...]}
static func turn_for(map: FlagMap, outcome: FlagResolver.Outcome, team: int) -> Dictionary:
	var ticks: Array = []
	for snap: FlagState in outcome.ticks:
		ticks.append(_rows_for(map, snap, team))
	var events: Array = []
	for e: Dictionary in outcome.events:
		if _witnessed(map, outcome, team, e):
			events.append(e.duplicate(true))
	# Snapshots keep the turn number they were resolved from; only outcome.state advanced.
	return {"turn": outcome.state.turn - 1, "ticks": ticks, "events": events}


## The client's leak check, using only the rows it was sent: ids of enemy rows that the
## team's own rows could not see.
static func leaked_enemies(map: FlagMap, team: int, rows: Array) -> Array[int]:
	var viewers: Array[Vector2i] = []
	for r: Array in rows:
		if r[1] == team:
			viewers.append(Vector2i(r[2], r[3]))
	var out: Array[int] = []
	for r: Array in rows:
		if r[1] != team and not FlagVision.can_see(map, viewers, Vector2i(r[2], r[3]), r[4] == 1):
			out.append(r[0])
	return out


static func _rows_for(map: FlagMap, state: FlagState, team: int) -> Array:
	var shown: Array[int] = []
	if team != SPECTATOR:
		shown = FlagVision.visible_enemy_ids(map, state, team)
	var rows: Array = []
	for p: FlagState.Piece in state.pieces:
		if team == SPECTATOR or p.team == team or shown.has(p.id):
			rows.append([p.id, p.team, p.tile.x, p.tile.y, int(state.is_carrying(p.id)), int(p.tagged)])
	return rows


## Pickups and captures are always announced (flags are always visible). A tag is kept if
## one of the pieces is the team's or its tile was visible at that tick.
static func _witnessed(map: FlagMap, outcome: FlagResolver.Outcome, team: int, e: Dictionary) -> bool:
	if team == SPECTATOR or e["kind"] != "tag":
		return true
	var tick: int = e["tick"]
	var snap: FlagState = outcome.ticks[tick - 1]
	var victim := snap.piece(e["piece"])
	var tagger := snap.piece(e["by"])
	if victim.team == team or tagger.team == team:
		return true
	var viewers: Array[Vector2i] = []
	for p: FlagState.Piece in snap.pieces:
		if p.team == team:
			viewers.append(p.tile)
	return FlagVision.can_see(map, viewers, victim.tile, false)
