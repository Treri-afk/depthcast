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

## LE GRIMOIRE.
##
## On ne part plus avec quatre écoles mais avec UNE, et deux sorts de celle-ci.
## Les pages achetées au marchand s'ajoutent ensuite, chacune liée à l'école
## dont elle vient. Le nombre de sorts n'est donc plus une constante : c'est
## une propriété de la partie en cours, et rien ne doit le supposer.
##
## Ce qui reste constant, ce sont les deux bornes.
const SLOTS_DEPART: int = 2
## Plafond du grimoire : deux sorts de départ, plus une page achetée.
##
## Trois et pas quatre. C'est un choix de design et non une limite technique :
## avec quatre pages, une seule mauvaise sortie de reroll se compense
## mécaniquement, et le sujet du jeu disparaît. À trois, chaque page compte, et
## la page achetée est une vraie décision.
##
## Il borne aussi le HUD et les tableaux de recharge, qui se dimensionnent
## dessus. Le relever un jour ne demande que de changer ce nombre.
const SLOTS_MAX: int = 3

## Écoles emmenées en run. Une seule, désormais : la spécialisation de départ.
## Les autres écoles entrent par les pages, pas par la préparation.
const ECOLES_DEPART: int = 1

var player_id: int = 0
var display_name: String = ""

## Le grimoire : entre SLOTS_DEPART et SLOTS_MAX pages, une fois la run
## démarrée. Sa taille CHANGE en cours de run — toujours la lire, jamais la
## supposer.
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

## Les états temporaires portés. Dans l'état, donc sérialisés, donc répliqués
## gratuitement par la photo du host (R1).
var statuts := StatusHolder.new()



func _init(p_player_id: int = 0, p_display_name: String = "") -> void:
	player_id = p_player_id
	display_name = p_display_name


func is_alive() -> bool:
	return hp > 0


## Reste-t-il de la place pour une page de plus ?
func peut_ajouter_une_page() -> bool:
	return slots.size() < SLOTS_MAX


## Ajoute une page au grimoire. Retourne le slot créé, ou null si le grimoire
## est plein — jamais une exception : un marchand qui vend à un grimoire plein
## est un cas de jeu, pas une erreur de programmation.
func ajoute_une_page(school_id: StringName, pool_size: int,
		effect_index: int) -> SpellSlot:
	if not peut_ajouter_une_page():
		return null
	var slot := SpellSlot.new(school_id, effect_index)
	slot.pool_size = clampi(pool_size, School.POOL_MIN, School.POOL_MAX)
	slots.append(slot)
	return slot


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
		"statuts": statuts.to_array(),
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
	p.statuts.depuis_array(d.get("statuts", []))
	return p
