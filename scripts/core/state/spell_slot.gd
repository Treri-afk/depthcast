class_name SpellSlot
extends RefCounted
## Un des 4 slots de sort d'un joueur.
##
## Deux pièges du GDD sont encodés ici plutôt que laissés à la discipline :
##
## 1. UN VERROU DURE EXACTEMENT UN ÉTAGE. On ne stocke pas un booléen `locked`
##    — qu'il faudrait penser à remettre à false — mais l'étage jusqu'auquel le
##    verrou est valide. Oublier de le réinitialiser devient impossible.
##
## 2. L'ÉTAT `???` EST À PORTÉE ÉTAGE. Même principe : on mémorise l'étage où
##    l'effet a été découvert, pas un booléen. Un slot verrouillé redevient donc
##    `???` au nouvel étage tant qu'il n'a pas été relancé — c'est voulu, et
##    c'est facile à implémenter à l'envers si on part d'un booléen.

const NOT_SET: int = -1

## L'école à laquelle ce slot est rattaché pour toute la run. Ne change jamais.
var school_id: StringName = &""

## Index de l'effet actif dans le pool de l'école. C'est CE champ que le reroll
## fait muter. Le pool fait 2 à 5 entrées selon l'école : ne jamais supposer 3.
var effect_index: int = 0

## Étage jusqu'auquel (inclus) le verrou protège ce slot du reroll.
var locked_until_floor: int = NOT_SET

## Étage sur lequel l'effet actif a été lancé au moins une fois.
var discovered_on_floor: int = NOT_SET


func _init(p_school_id: StringName = &"", p_effect_index: int = 0) -> void:
	school_id = p_school_id
	effect_index = p_effect_index


## Le slot résiste-t-il au reroll pour l'étage donné ?
func is_locked_for(floor_index: int) -> bool:
	return locked_until_floor >= floor_index


## Le joueur sait-il ce que fait son sort à cet étage ?
## Faux au début de chaque étage, y compris pour un slot verrouillé.
func is_discovered_on(floor_index: int) -> bool:
	return discovered_on_floor == floor_index


## Appelé par l'Effect Resolver au premier cast de l'étage.
func mark_discovered(floor_index: int) -> void:
	discovered_on_floor = floor_index


## Applique un reroll. Retourne false si le slot était verrouillé — dans ce cas
## rien n'est modifié et l'appelant émet `slot_kept` plutôt que `slot_rerolled`.
func try_reroll(floor_index: int, new_effect_index: int) -> bool:
	if is_locked_for(floor_index):
		return false
	effect_index = new_effect_index
	return true


func to_dict() -> Dictionary:
	return {
		"school_id": String(school_id),
		"effect_index": effect_index,
		"locked_until_floor": locked_until_floor,
		"discovered_on_floor": discovered_on_floor,
	}


static func from_dict(d: Dictionary) -> SpellSlot:
	var s := SpellSlot.new(StringName(d.get("school_id", "")), int(d.get("effect_index", 0)))
	s.locked_until_floor = int(d.get("locked_until_floor", NOT_SET))
	s.discovered_on_floor = int(d.get("discovered_on_floor", NOT_SET))
	return s
