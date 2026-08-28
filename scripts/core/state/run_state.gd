class_name RunState
extends RefCounted
## Racine de l'état d'une run. Détenu par l'autoload GameState.
##
## Règle R1 : cet objet contient TOUT l'état de gameplay, et il est sérialisable
## en entier. Le test est explicite dans ARCHITECTURE.md — sérialiser, tuer le
## processus, relancer, reprendre à l'identique. Si une donnée de gameplay vit
## sur un node Godot, ce test échoue.
##
## C'est aussi ce qui rend la réplication réseau possible sans réécriture (D1).

var run_seed: int = 0
var floor_index: int = 0
var players: Array[PlayerState] = []

## Pot commun de Résonance (D3). Alimenté par les kills de TOUS les joueurs,
## dépensé par chacun pour ses propres verrous. Jamais persisté entre les runs.
var resonance_pool: int = 0

## Verrous achetés par l'ÉQUIPE sur l'étage courant. Voir la note dans
## PlayerState.locks_bought_this_floor — Q1 non tranchée, on maintient les deux.
var team_locks_this_floor: int = 0

var is_over: bool = false
var victory: bool = false


## Accès par index — `players[0]` fonctionne dès le solo (R2).
func get_player(player_id: int) -> PlayerState:
	for p: PlayerState in players:
		if p.player_id == player_id:
			return p
	return null


func alive_players() -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p: PlayerState in players:
		if p.is_alive():
			out.append(p)
	return out


## Remet à zéro les compteurs à portée étage, pour tout le monde.
func begin_floor() -> void:
	team_locks_this_floor = 0
	for p: PlayerState in players:
		p.begin_floor()


func to_dict() -> Dictionary:
	var player_dicts: Array = []
	for p: PlayerState in players:
		player_dicts.append(p.to_dict())
	return {
		"run_seed": run_seed,
		"floor_index": floor_index,
		"players": player_dicts,
		"resonance_pool": resonance_pool,
		"team_locks_this_floor": team_locks_this_floor,
		"is_over": is_over,
		"victory": victory,
	}


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.run_seed = int(d.get("run_seed", 0))
	r.floor_index = int(d.get("floor_index", 0))
	r.resonance_pool = int(d.get("resonance_pool", 0))
	r.team_locks_this_floor = int(d.get("team_locks_this_floor", 0))
	r.is_over = bool(d.get("is_over", false))
	r.victory = bool(d.get("victory", false))
	var player_dicts: Array = d.get("players", [])
	for pd: Variant in player_dicts:
		r.players.append(PlayerState.from_dict(pd as Dictionary))
	return r
