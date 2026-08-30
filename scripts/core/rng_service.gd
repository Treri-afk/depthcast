extends Node
## Service d'aléatoire seedé — autoload `RngService`.
##
## Implémente la règle R3. Aucun appel direct à `randi()`, `randf()` ou à un
## `RandomNumberGenerator` non seedé n'est autorisé ailleurs dans le projet.
##
## Chaque usage a son propre flux nommé, dérivé de la seed de run. Deux
## conséquences directes :
##   - deux clients avec la même seed génèrent le même donjon (co-op, D2)
##   - rejouer une seed rejoue exactement la même run (outillage, R3)
##
## Le flux de reroll d'un joueur dérive de `seed de run + player_id` : il n'est
## JAMAIS influencé par ce que font les autres joueurs (D4, builds indépendants).

## Noms de flux standards. Utiliser ces constantes plutôt que des chaînes libres :
## une faute de frappe créerait silencieusement un flux parallèle.
const STREAM_DUNGEON := "dungeon"
const STREAM_REROLL := "reroll"
const STREAM_LOOT := "loot"
const STREAM_BEHAVIOUR := "behaviour"

var _run_seed: int = 0
var _streams: Dictionary[String, RandomNumberGenerator] = {}


## Démarre une nouvelle run. Réinitialise tous les flux.
## Passer 0 tire une seed au hasard — c'est le SEUL endroit du projet où
## l'aléatoire non déterministe est permis.
func seed_run(run_seed: int = 0) -> int:
	if run_seed == 0:
		var boot := RandomNumberGenerator.new()
		boot.randomize()
		run_seed = boot.randi() & 0x7FFFFFFF
	_run_seed = run_seed
	_streams.clear()
	return _run_seed


func get_run_seed() -> int:
	return _run_seed


## Flux global, partagé par tous les joueurs (génération de donjon, loot).
func stream(stream_name: String) -> RandomNumberGenerator:
	return _get_or_create(stream_name)


## Flux d'un étage donné.
##
## Dérivé de l'INDEX de l'étage, donc indépendant du nombre de fois qu'on l'a
## généré. Un flux global qui avance à chaque génération suppose que toutes les
## machines l'ont fait autant de fois, dans le même ordre — une hypothèse que le
## co-op casse à la première régénération, et qui produirait deux donjons
## différents sans que rien ne le signale.
func floor_stream(stream_name: String, floor_index: int) -> RandomNumberGenerator:
	return _get_or_create("%s@%d" % [stream_name, floor_index])


## Flux propre à un joueur. Deux joueurs qui rerollent au même étage tirent
## indépendamment, et l'ordre dans lequel ils le font n'a aucune influence.
func player_stream(stream_name: String, player_id: int) -> RandomNumberGenerator:
	return _get_or_create("%s#%d" % [stream_name, player_id])


## État des flux, pour le log de fin d'étage et la sérialisation de run.
func debug_state() -> Dictionary:
	var out: Dictionary = {"run_seed": _run_seed, "streams": {}}
	for key: String in _streams:
		out["streams"][key] = _streams[key].state
	return out


func _get_or_create(key: String) -> RandomNumberGenerator:
	if _streams.has(key):
		return _streams[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = _derive_seed(key)
	_streams[key] = rng
	return rng


## Dérive une seed de flux à partir de la seed de run et du nom du flux.
##
## On n'utilise PAS `String.hash()` : sa valeur n'est pas garantie stable entre
## versions du moteur, ce qui casserait la reproductibilité d'une run enregistrée
## et pourrait faire diverger deux clients sur des builds différents.
## djb2 est trivial, stable partout, et suffisant ici — ce n'est pas de la crypto.
func _derive_seed(key: String) -> int:
	var h: int = 5381
	for i: int in key.length():
		h = ((h << 5) + h + key.unicode_at(i)) & 0x7FFFFFFF
	return (_run_seed ^ (h * 0x9E3779B1)) & 0x7FFFFFFFFFFF
