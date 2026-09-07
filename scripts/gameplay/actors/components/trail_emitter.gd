class_name TrailEmitter
extends RefCounted
## Mémorise une traînée en cours et dit quand semer la prochaine flaque.
##
## Une flaque tous les 1,6 mètre plutôt qu'à intervalle fixe : rester immobile
## ne doit pas empiler dix flaques au même endroit.
##
## Il ne crée rien lui-même — il décide. C'est la racine du jeu qui instancie
## la zone, parce qu'un composant d'acteur n'a pas à peupler la scène.

const ESPACEMENT: float = 1.6

var effet: SpellEffect = null
var couleur: Color = Color.WHITE
var slot_index: int = -1

var _restant: float = 0.0
var _derniere: Vector3 = Vector3.ZERO


func arme(p_effet: SpellEffect, p_couleur: Color, p_slot: int) -> void:
	effet = p_effet
	couleur = p_couleur
	slot_index = p_slot
	_restant = p_effet.duree
	_derniere = Vector3.ZERO


func actif() -> bool:
	return _restant > 0.0 and effet != null


## Prochaine flaque à poser, ou un dictionnaire vide.
func consomme(delta: float, position: Vector3) -> Dictionary:
	if not actif():
		return {}
	_restant -= delta
	if position.distance_to(_derniere) <= ESPACEMENT:
		return {}
	_derniere = position
	return {
		"effet": effet,
		"allure": effet.allure,
		"signature": effet.signature,
		"couleur": couleur,
		"slot": slot_index,
		"position": position,
	}
