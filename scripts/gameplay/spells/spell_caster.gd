class_name SpellCaster
extends RefCounted
## Résout un lancer : slot → école → effet actif → comportement.
##
## C'est le remplacement du `match` à quinze branches. Il ne connaît aucun sort
## en particulier : il lit la donnée, demande la classe correspondante au
## registre, et délègue. Ajouter un sort ne le fait pas grossir d'une ligne.

var _contexte: SpellContext
var _registre: SpellRegistry


func _init(contexte: SpellContext) -> void:
	_contexte = contexte
	_registre = SpellRegistry.new()


func registre() -> SpellRegistry:
	return _registre


## Effet actuellement chargé dans un slot, ou null.
func effet_actif(player_id: int, slot_index: int) -> SpellEffect:
	if not GameState.is_in_run():
		return null
	var joueur: PlayerState = GameState.run.get_player(player_id)
	if joueur == null or slot_index < 0 or slot_index >= joueur.slots.size():
		return null
	var slot: SpellSlot = joueur.slots[slot_index]
	var ecole: School = Content.ecole(slot.school_id)
	return null if ecole == null else ecole.effet(slot.effect_index)


func ecole_du_slot(player_id: int, slot_index: int) -> School:
	if not GameState.is_in_run():
		return null
	var joueur: PlayerState = GameState.run.get_player(player_id)
	if joueur == null or slot_index < 0 or slot_index >= joueur.slots.size():
		return null
	return Content.ecole(joueur.slots[slot_index].school_id)


## Lance le sort d'un slot. Retourne false si rien n'a été lancé.
func lance(slot_index: int, direction: Vector3) -> bool:
	var joueur: PlayerAvatar = _contexte.joueur
	var effet: SpellEffect = effet_actif(joueur.player_id, slot_index)
	if effet == null:
		return false

	var comportement: SpellBehaviour = _registre.comportement(effet.comportement)
	if comportement == null:
		push_error("Aucun comportement enregistré pour %s." % effet.nom)
		return false

	var ecole: School = ecole_du_slot(joueur.player_id, slot_index)
	var couleur: Color = ecole.couleur if ecole != null else Color.WHITE

	joueur.demarre_cooldown(slot_index, effet.cooldown)
	Audio.joue(&"sort")
	comportement.lance(_contexte, slot_index, effet, couleur, direction)
	return true
