class_name StatusHolder
extends RefCounted
## Le sac d'états d'un porteur, et les règles de cumul.
##
## Partagé par les joueurs et les monstres : un état ne se comporte pas
## différemment selon qui le porte, et deux implémentations auraient fini par
## diverger sur le seul point qui compte — comment ils se cumulent.
##
## ── LE CUMUL EST MULTIPLICATIF ──────────────────────────────────────────
##
## Deux protections à 0,6 donnent 0,36, pas 0,2. L'addition permet d'atteindre
## zéro dégât reçu en empilant assez de sorts ; la multiplication s'en approche
## sans jamais y arriver. C'est la seule règle qui reste juste quel que soit le
## contenu qu'on ajoutera plus tard, et elle est décidée ici une fois pour
## toutes plutôt qu'à chaque nouvelle école.

var etats: Array[Status] = []


## Pose un état. Le même identifiant REMPLACE au lieu de s'ajouter : relancer un
## sort de protection en rafraîchit la durée, il ne rend pas invincible.
func pose(etat: Status) -> void:
	for i: int in etats.size():
		if etats[i].id == etat.id:
			etats[i] = etat
			return
	etats.append(etat)


func avance(delta: float) -> void:
	if etats.is_empty():
		return
	var restants: Array[Status] = []
	for etat: Status in etats:
		etat.restant -= delta
		if etat.actif():
			restants.append(etat)
	etats = restants


func porte(id: StringName) -> bool:
	for etat: Status in etats:
		if etat.id == id:
			return true
	return false


func degats_recus() -> float:
	return _produit(func(e: Status) -> float: return e.degats_recus)


func degats_infliges() -> float:
	return _produit(func(e: Status) -> float: return e.degats_infliges)


func vitesse() -> float:
	return _produit(func(e: Status) -> float: return e.vitesse)


## Qui a provoqué le porteur, ou -1. Le dernier posé l'emporte : une provocation
## fraîche doit reprendre l'attention à la précédente, sinon deux tanks se
## disputeraient un monstre au profit du premier arrivé.
func provocateur() -> int:
	var qui: int = -1
	for etat: Status in etats:
		if etat.provoque and etat.source_player_id >= 0:
			qui = etat.source_player_id
	return qui


func _produit(lecture: Callable) -> float:
	var total: float = 1.0
	for etat: Status in etats:
		total *= float(lecture.call(etat))
	return total


func to_array() -> Array:
	var out: Array = []
	for etat: Status in etats:
		out.append(etat.to_dict())
	return out


func depuis_array(brut: Array) -> void:
	etats.clear()
	for d: Variant in brut:
		etats.append(Status.from_dict(d as Dictionary))
