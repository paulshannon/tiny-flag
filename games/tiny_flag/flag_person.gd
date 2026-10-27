class_name FlagPerson
extends Node
## One person in a Tiny Flag match (a side or a spectator), spawned by GameBase's
## spawner and named by peer id like every player. A marker only: Tiny Flag has no
## per-player movement to sync, so there is no InputRelay or PlayerNet here; the
## board and turns travel as TinyFlagGame RPCs.

## The peer this person is.
var peer: int = 0


func _init(peer_id: int = 0) -> void:
	peer = peer_id
