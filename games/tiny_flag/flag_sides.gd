class_name FlagSides
extends RefCounted
## Who plays which Tiny Flag side, who waits for one, and who watches (spec §1 "Who
## plays"). Bookkeeping only: FlagMatch decides when changes apply.
##
## A side is held by a person (peer id > 0) or a bot (0). A person waiting for a bot's
## side is "pending" until the next turn start; everyone else watches.

## peer[team]: the person playing that side, 0 for a bot.
var peer: Array[int] = [0, 0]
## pending[team]: the person taking that side at the next turn start, 0 for none.
var pending: Array[int] = [0, 0]
## In join order; the first takes the next side that opens.
var spectators: Array[int] = []


func has(p: int) -> bool:
	return peer.has(p) or pending.has(p) or spectators.has(p)


func is_empty() -> bool:
	return peer.max() == 0 and pending.max() == 0 and spectators.is_empty()


## The side `p` plays now; FlagWire.SPECTATOR when none (watching, pending or unknown).
func team_of(p: int) -> int:
	if p > 0:
		for team: int in [FlagMap.RED, FlagMap.BLUE]:
			if peer[team] == p:
				return team
	return FlagWire.SPECTATOR


## A newcomer: queued for a bot side if one is free, else a spectator.
func add(p: int) -> void:
	var team := _open_side()
	if team >= 0:
		pending[team] = p
	else:
		spectators.append(p)


## Forgets `p`. Returns the side they played (now bot-held), or SPECTATOR.
func remove(p: int) -> int:
	spectators.erase(p)
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		if pending[team] == p:
			pending[team] = 0
			_promote()
	var side := team_of(p)
	if side >= 0:
		peer[side] = 0
		_promote()
	return side


## Turn start: pending people take their sides.
func apply_pending() -> void:
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		if pending[team] != 0 and peer[team] == 0:
			peer[team] = pending[team]
			pending[team] = 0


## A bot side nobody is queued for; RED first. -1 if none.
func _open_side() -> int:
	for team: int in [FlagMap.RED, FlagMap.BLUE]:
		if peer[team] == 0 and pending[team] == 0:
			return team
	return -1


## The longest-waiting spectator queues for a side that opened.
func _promote() -> void:
	var team := _open_side()
	if team >= 0 and not spectators.is_empty():
		pending[team] = spectators.pop_front()
