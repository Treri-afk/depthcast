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
## `lanceur` à null signifie « le joueur local ». En co-op, chaque machine
## rejoue le sort de CHACUN : c'est ce qui fait que tout le monde voit la boule
## de feu, et pas seulement celui qui l'a lancée.
func lance(slot_index: int, direction: Vector3, lanceur: PlayerAvatar = null) -> bool:
	var joueur: PlayerAvatar = lanceur if lanceur != null else _contexte.joueur
	if joueur == null or not is_instance_valid(joueur):
		return false
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
	# Annoncé plutôt qu'appelé : le son écoute le jeu, le jeu ne pilote pas le
	# son. Ça vaut aussi pour le lancer, qui appelait Audio en direct.
	EventBus.sound_emitted.emit(&"sort", joueur.position_yeux())
	# Le recul est de la caméra : il n'appartient qu'à celui qui lance. Le
	# donner à l'avatar d'un coéquipier secouerait la vue de personne, mais
	# c'est le genre d'approximation qui finit par se voir.
	if joueur.local:
		joueur.recul(effet.recul)

	# LE DIAGRAMME D'ABORD, LE SORT ENSUITE.
	#
	# Un sort partait de nulle part : on appuyait, un effet apparaissait à dix
	# mètres, et rien entre les deux ne disait que c'était nous. Le bâton se
	# lève, le cercle s'ouvre, puis le sort en sort — la chaîne devient lisible.
	#
	# Joué pour TOUS les lanceurs, y compris distants : c'est ce qui rend le
	# sort d'un coéquipier attribuable.
	var delai: float = Content.tuning.sort_invocation_delai
	joueur.invoque_au_baton(effet, couleur, delai)

	if delai <= 0.0:
		_execute(comportement, joueur, slot_index, effet, couleur, direction)
		return true

	# Le sort part APRÈS le geste. La recharge, elle, a déjà démarré : le délai
	# est une mise en scène, il ne doit pas se payer deux fois.
	#
	# Le lanceur est revérifié à l'échéance — il a pu mourir, se déconnecter ou
	# quitter la scène pendant ces cent millisecondes.
	_contexte.monde.get_tree().create_timer(delai).timeout.connect(
		func() -> void:
			if is_instance_valid(joueur):
				_execute(comportement, joueur, slot_index, effet, couleur,
					direction))
	return true


## Bascule le contexte sur le lanceur, exécute, et le remet.
##
## Sans cette bascule, le sort d'un coéquipier partirait de nos propres mains.
func _execute(comportement: SpellBehaviour, joueur: PlayerAvatar,
		slot_index: int, effet: SpellEffect, couleur: Color,
		direction: Vector3) -> void:
	var precedent: PlayerAvatar = _contexte.joueur
	_contexte.joueur = joueur
	comportement.lance(_contexte, slot_index, effet, couleur, direction)
	_contexte.joueur = precedent
