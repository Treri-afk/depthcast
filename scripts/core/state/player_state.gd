class_name PlayerState
extends RefCounted
## État d'un joueur. Vit dans RunState, jamais sur un node.
##
## Règle R2 : un joueur est identifié par son `player_id`, et les systèmes
## prennent cet id en paramètre. Il n'existe aucun singleton `Player.instance`
## dans ce projet, même en solo.
##
## Note d'économie (GDD §3) : les Éclats sont INDIVIDUELS et persistent entre
## les runs. La Résonance est COMMUNE et vit dans RunState. Les deux ne partagent
## aucun code et aucune conversion n'existe entre elles.

## Nombre d'écoles qu'un joueur emmène en run. Fixé par le design.
const SLOT_COUNT: int = 4

var player_id: int = 0
var display_name: String = ""

## Les 4 slots. Toujours SLOT_COUNT entrées une fois la run démarrée.
var slots: Array[SpellSlot] = []

var max_hp: int = 100
var hp: int = 100

## Monnaie méta, individuelle, persiste entre les runs.
var eclats: int = 0

## Verrous achetés par CE joueur sur l'étage courant. Sert au multiplicateur
## cumulatif. Q1 du journal de décisions n'est pas tranchée : ce compteur permet
## la variante « par joueur ». RunState en tient un second pour la variante
## « par équipe ». Les deux sont maintenus, un seul sera utilisé après playtest.
var locks_bought_this_floor: int = 0


func _init(p_player_id: int = 0, p_display_name: String = "") -> void:
	player_id = p_player_id
	display_name = p_display_name


func is_alive() -> bool:
	return hp > 0


## Remet à zéro ce qui est à portée étage. Appelé à chaque changement d'étage.
func begin_floor() -> void:
	locks_bought_this_floor = 0


func to_dict() -> Dictionary:
	var slot_dicts: Array = []
	for s: SpellSlot in slots:
		slot_dicts.append(s.to_dict())
	return {
		"player_id": player_id,
		"display_name": display_name,
		"slots": slot_dicts,
		"max_hp": max_hp,
		"hp": hp,
		"eclats": eclats,
		"locks_bought_this_floor": locks_bought_this_floor,
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new(int(d.get("player_id", 0)), String(d.get("display_name", "")))
	p.max_hp = int(d.get("max_hp", 100))
	p.hp = int(d.get("hp", 100))
	p.eclats = int(d.get("eclats", 0))
	p.locks_bought_this_floor = int(d.get("locks_bought_this_floor", 0))
	var slot_dicts: Array = d.get("slots", [])
	for sd: Variant in slot_dicts:
		p.slots.append(SpellSlot.from_dict(sd as Dictionary))
	return p
