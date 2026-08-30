class_name FloorDirector
extends RefCounted
## Orchestre la vie d'un étage : le générer, le peupler, en changer.
##
## Il connaît l'ordre des opérations, et cet ordre est un choix de design :
## on scelle chez le marchand, PUIS on descend, et le reroll se produit à la
## descente. L'inverse rendrait les sceaux inutiles.

signal etage_pret(index: int)
signal boss_invoque(avatar: BossAvatar)

var plan: FloorPlan

var _geometrie: Node3D
var _tuning: Tuning
var _builder: FloorBuilder
var _furnisher: RoomFurnisher
var _marchand: MerchantRoom
var _spawner: MonsterSpawner
var _joueurs: Array[PlayerAvatar]


func _init(geometrie: Node3D, tuning: Tuning, builder: FloorBuilder,
		furnisher: RoomFurnisher, marchand: MerchantRoom, spawner: MonsterSpawner,
		joueurs: Array[PlayerAvatar]) -> void:
	_geometrie = geometrie
	_tuning = tuning
	_builder = builder
	_furnisher = furnisher
	_marchand = marchand
	_spawner = spawner
	_joueurs = joueurs


## Construit l'étage courant de zéro. Retourne les objets destructibles créés,
## que le contexte de sorts doit connaître.
func genere() -> Array[PropDestructible]:
	var etage: int = GameState.run.floor_index
	# Le flux est celui de CET étage, pas un flux global qui avance : deux
	# machines qui ne l'auraient pas fait avancer le même nombre de fois
	# généreraient deux donjons différents sans que rien ne le signale.
	var rng: RandomNumberGenerator = RngService.floor_stream(
		RngService.STREAM_DUNGEON, etage)

	for enfant: Node in _geometrie.get_children():
		enfant.queue_free()
	_furnisher.objets.clear()
	var boss: bool = etage >= _tuning.etage_du_boss

	# L'arène du boss n'a ni couloir, ni marchand : on y descend pour combattre,
	# pas pour préparer. Les décisions se sont prises à l'étage d'avant.
	plan = FloorPlan.genere_arene(rng, _tuning) if boss \
		else FloorPlan.genere(rng, _tuning)
	_builder.batit(plan)
	for salle: FloorPlan.Salle in plan.salles:
		_furnisher.meuble(salle, rng)
	if boss:
		_marchand.vide()
	else:
		_marchand.installe(plan.salle_du_marchand())

	if boss:
		var avatar: BossAvatar = _spawner.invoque_le_boss(plan, _joueurs, etage)
		if avatar != null:
			boss_invoque.emit(avatar)
	else:
		_spawner.peuple(plan, _joueurs, etage, rng)
	_pose_les_joueurs(plan.salle_de_depart().centre)

	etage_pret.emit(GameState.run.floor_index)
	return _furnisher.objets


## Tout le monde arrive dans la salle de départ, en cercle. Empilés au même
## point, les corps se repoussent et partent en gerbe au premier tick physique.
func _pose_les_joueurs(centre: Vector3) -> void:
	var total: int = maxi(_joueurs.size(), 1)
	for i: int in _joueurs.size():
		var angle: float = TAU * float(i) / float(total)
		var ecart: float = 0.0 if total == 1 else 1.6
		_joueurs[i].global_position = centre + Vector3(
			cos(angle) * ecart, 1.2, sin(angle) * ecart)


## Le portail ne s'ouvre qu'une fois l'étage nettoyé : sinon on traverse le
## donjon sans jamais combattre, et il n'y a plus de boucle.
func peut_descendre() -> bool:
	return GameState.is_in_run() and GameState.run.alive_monsters().is_empty()


## La descente est jouée à l'IDENTIQUE sur chaque machine, sur l'ordre du host.
##
## Un client rejoue donc `advance_floor()` localement, ce qui est normalement
## interdit (R8). L'exception est assumée et sûre : l'opération est entièrement
## déterministe — même étage, mêmes flux par joueur, même nombre d'appels — donc
## les deux machines aboutissent au même état, et la photo du host le confirme
## un dixième de seconde plus tard.
##
## L'alternative aurait été de répliquer le reroll effet par effet. Elle coûte
## beaucoup plus cher pour un résultat identique, et elle prive chaque machine
## des évènements `slot_rerolled` dont dépend toute la séquence de mutation.
func descend() -> Array[PropDestructible]:
	GameState.complete_floor()
	GameState.advance_floor()
	return genere()


func est_etage_de_boss() -> bool:
	return GameState.run.floor_index >= _tuning.etage_du_boss
