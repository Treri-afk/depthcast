class_name MonsterBrain
extends RefCounted
## La décision d'un monstre, séparée de son corps.
##
## Le corps se contente d'appliquer une vitesse ; c'est ici qu'on choisit quoi
## faire. Cette séparation permet d'écrire une nouvelle IA sans toucher au
## code de collision, et de raisonner sur le comportement en le lisant d'un
## seul tenant.
##
## La machine à états est le point important : un monstre qui fonce tout droit
## ne crée aucune décision chez le joueur. Ici il approche, tourne autour,
## choisit son moment, frappe, se replie.

enum Etat { APPROCHE, GARDE, ASSAUT, REPLI }

signal veut_frapper()
signal veut_tirer(direction: Vector3)
signal engage_l_attaque()

var stats: MonsterStats
var etat: Etat = Etat.APPROCHE
## Sens de rotation autour de la cible. Alterné d'un monstre à l'autre, sinon
## tous tournent du même côté et forment une ronde parfaitement lisible.
var sens_orbite: float = 1.0

var _minuteur: float = 0.0
var _recharge: float = 0.0


func _init(p_stats: MonsterStats, sens: float) -> void:
	stats = p_stats
	sens_orbite = sens
	_recharge = stats.delai_assaut * 0.5


## Retourne la vitesse horizontale voulue pour cette frame.
func decide(delta: float, position: Vector3, cible: Node3D,
		facteur_vitesse: float) -> Vector3:
	_recharge = maxf(0.0, _recharge - delta)
	_minuteur = maxf(0.0, _minuteur - delta)

	var vers: Vector3 = cible.global_position - position
	vers.y = 0.0
	var distance: float = vers.length()
	if distance < 0.01:
		return Vector3.ZERO
	var direction: Vector3 = vers / distance

	var vitesse: float = stats.vitesse * facteur_vitesse
	var sur_un_leurre: bool = cible.is_in_group("leurre")

	match etat:
		Etat.APPROCHE:
			# Une brute n'a pas de distance de garde : elle arrive au contact.
			if distance <= maxf(stats.distance_garde, stats.portee_frappe):
				etat = Etat.GARDE
			return direction * vitesse

		Etat.GARDE:
			if distance > stats.distance_garde * 1.45:
				etat = Etat.APPROCHE
				return direction * vitesse
			if _recharge <= 0.0 and not sur_un_leurre:
				_engage(distance, direction)
				return Vector3.ZERO
			return _orbite(direction, distance, vitesse)

		Etat.ASSAUT:
			if distance <= stats.portee_frappe:
				veut_frapper.emit()
				etat = Etat.REPLI
				_minuteur = stats.duree_repli
				_recharge = stats.delai_assaut
				return Vector3.ZERO
			if _minuteur <= 0.0:
				etat = Etat.GARDE
				_recharge = stats.delai_assaut * 0.6
			# L'assaut est plus rapide que la marche : c'est ce qui le rend
			# menaçant, et ce qui donne au joueur quelque chose à esquiver.
			return direction * vitesse * 2.1

		Etat.REPLI:
			if _minuteur <= 0.0:
				etat = Etat.GARDE
			return -direction * vitesse * 0.9

	return Vector3.ZERO


## Rotation autour de la cible, avec une correction radiale pour ne pas dériver
## au fil des tours.
func _orbite(direction: Vector3, distance: float, vitesse: float) -> Vector3:
	var tangente: Vector3 = direction.cross(Vector3.UP) * sens_orbite
	var correction: float = clampf(
		(distance - stats.distance_garde) / maxf(stats.distance_garde, 1.0), -1.0, 1.0)
	return (tangente + direction * correction).normalized() * vitesse * 0.85


func _engage(distance: float, direction: Vector3) -> void:
	if stats.tire:
		if distance <= stats.portee_frappe:
			veut_tirer.emit(direction)
			_recharge = stats.delai_assaut
			engage_l_attaque.emit()
		return

	if stats.duree_assaut <= 0.0:
		# Sans phase de charge (la brute), on frappe dès qu'on est à portée.
		if distance <= stats.portee_frappe:
			veut_frapper.emit()
			_recharge = stats.delai_assaut
		return

	etat = Etat.ASSAUT
	_minuteur = stats.duree_assaut
	engage_l_attaque.emit()


## Être bousculé interrompt un assaut : on ne charge pas en étant projeté.
func interrompt_l_assaut() -> void:
	if etat == Etat.ASSAUT:
		etat = Etat.GARDE
