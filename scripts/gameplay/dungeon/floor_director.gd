class_name FloorDirector
extends RefCounted
## Orchestre la vie d'un étage : le générer, le peupler, en changer.
##
## Il connaît l'ordre des opérations, et cet ordre est un choix de design :
## on scelle chez le marchand, PUIS on descend, et le reroll se produit à la
## descente. L'inverse rendrait les sceaux inutiles.

signal etage_pret(index: int)

var plan: FloorPlan

var _geometrie: Node3D
var _tuning: Tuning
var _builder: FloorBuilder
var _furnisher: RoomFurnisher
var _marchand: MerchantRoom
var _spawner: MonsterSpawner
var _joueur: PlayerAvatar


func _init(geometrie: Node3D, tuning: Tuning, builder: FloorBuilder,
		furnisher: RoomFurnisher, marchand: MerchantRoom, spawner: MonsterSpawner,
		joueur: PlayerAvatar) -> void:
	_geometrie = geometrie
	_tuning = tuning
	_builder = builder
	_furnisher = furnisher
	_marchand = marchand
	_spawner = spawner
	_joueur = joueur


## Construit l'étage courant de zéro. Retourne les objets destructibles créés,
## que le contexte de sorts doit connaître.
func genere() -> Array[PropDestructible]:
	var rng: RandomNumberGenerator = RngService.stream(RngService.STREAM_DUNGEON)

	for enfant: Node in _geometrie.get_children():
		enfant.queue_free()
	_furnisher.objets.clear()

	plan = FloorPlan.genere(rng, _tuning)
	_builder.batit(plan)
	for salle: FloorPlan.Salle in plan.salles:
		_furnisher.meuble(salle, rng)
	_marchand.installe(plan.salle_du_marchand())

	_spawner.peuple(plan, _joueur, GameState.run.floor_index, rng)
	_joueur.global_position = plan.salle_de_depart().centre + Vector3(0, 1.2, 0)

	etage_pret.emit(GameState.run.floor_index)
	return _furnisher.objets


## Le portail ne s'ouvre qu'une fois l'étage nettoyé : sinon on traverse le
## donjon sans jamais combattre, et il n'y a plus de boucle.
func peut_descendre() -> bool:
	return GameState.is_in_run() and GameState.run.alive_monsters().is_empty()


func descend() -> Array[PropDestructible]:
	GameState.complete_floor()
	GameState.advance_floor()
	return genere()


func redemarre(ecoles: Array) -> Array[PropDestructible]:
	GameState.start_run(0, 1)
	GameState.set_player_schools(0, ecoles)
	return genere()
