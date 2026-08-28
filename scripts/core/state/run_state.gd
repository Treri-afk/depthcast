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

## Monstres vivants ou morts de l'étage courant. Vidés à chaque changement
## d'étage — un monstre ne survit pas à la salle où il a été tué.
var monsters: Array[MonsterState] = []

## Compteur d'identifiants. Sérialisé lui aussi : sans ça, recharger une partie
## réattribuerait des ids déjà utilisés et deux monstres se confondraient.
var next_monster_id: int = 1

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


func get_monster(monster_id: int) -> MonsterState:
	for m: MonsterState in monsters:
		if m.monster_id == monster_id:
			return m
	return null


func alive_monsters() -> Array[MonsterState]:
	var out: Array[MonsterState] = []
	for m: MonsterState in monsters:
		if m.is_alive():
			out.append(m)
	return out


func alive_players() -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p: PlayerState in players:
		if p.is_alive():
			out.append(p)
	return out


## Remet à zéro les compteurs à portée étage, pour tout le monde.
func begin_floor() -> void:
	team_locks_this_floor = 0
	monsters.clear()
	for p: PlayerState in players:
		p.begin_floor()


func to_dict() -> Dictionary:
	var player_dicts: Array = []
	for p: PlayerState in players:
		player_dicts.append(p.to_dict())
	var monster_dicts: Array = []
	for m: MonsterState in monsters:
		monster_dicts.append(m.to_dict())
	return {
		"monsters": monster_dicts,
		"next_monster_id": next_monster_id,
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
	r.next_monster_id = int(d.get("next_monster_id", 1))
	var player_dicts: Array = d.get("players", [])
	for pd: Variant in player_dicts:
		r.players.append(PlayerState.from_dict(pd as Dictionary))
	var monster_dicts: Array = d.get("monsters", [])
	for md: Variant in monster_dicts:
		r.monsters.append(MonsterState.from_dict(md as Dictionary))
	return r
