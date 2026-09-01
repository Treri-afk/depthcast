extends Control
## Menu principal.
##
## Le bouton multijoueur est visible mais désactivé, et dit pourquoi. Masquer
## une fonctionnalité prévue donne l'impression qu'elle n'existe pas ; la
## montrer inerte donne une carte du chemin restant.
##
## Deux façons de jouer à plusieurs, et elles cohabitent sans se remplacer :
## le réseau local, avec lequel le co-op se développe et se règle (D15), et
## Steam, qui traverse les box et invite les amis. Retirer le premier le jour où
## le second marche serait une erreur — on ne peut pas lancer deux clients Steam
## sur le même compte, donc on ne pourrait plus essayer une partie à deux seul
## devant sa machine (D8).


var _adresse: LineEdit
var _lobby: LineEdit
var _statut: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Revenir au menu ferme la partie en cours : une session laissée ouverte
	# derrière soi bloquerait le port au prochain hébergement. Et le lobby Steam
	# avec elle : un lobby orphelin continue d'apparaître aux amis, qui
	# rejoindraient une partie que plus personne n'héberge.
	Net.quitte()
	SteamNet.quitte_le_lobby()
	Net.echec.connect(func(message: String) -> void: _statut.text = message)
	SteamNet.echec.connect(func(message: String) -> void: _statut.text = message)
	# Le lobby Steam se crée par aller-retour avec Valve : le salon n'ouvre qu'au
	# retour, jamais au clic.
	SteamNet.session_prete.connect(func() -> void: _ouvre(true))
	SteamNet.invitation_recue.connect(_sur_invitation)
	ScreenUtils.fond(self)
	var col := ScreenUtils.colonne(self, 16)

	col.add_child(ScreenUtils.titre("DEPTHCAST"))
	col.add_child(ScreenUtils.sous_titre(
		"La magie ne t'obéit jamais complètement."))
	col.add_child(_espace(28))

	var solo := ScreenUtils.bouton("Jouer en solo")
	solo.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_HUB))
	col.add_child(solo)

	# Le terrain d'essai est au menu et non derrière une touche de debug : c'est
	# là qu'on passe le plus de temps quand on règle le jeu, et une chose qu'on
	# ouvre vingt fois par jour ne doit pas demander de traverser le hub.
	var labo := ScreenUtils.bouton("Terrain d'essai")
	labo.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_LABO))
	col.add_child(labo)
	col.add_child(ScreenUtils.sous_titre(
		"Mannequins, explosions en boucle, mobilier qui se réarme, portique de\n"
		+ "mesure et pupitre de reroll. Aucun enjeu : on n'y meurt pas.",
		Color(0.55, 0.85, 1.0, 0.75)))
	col.add_child(_espace(12))

	col.add_child(_espace(8))
	_ajoute_le_bloc_steam(col)

	col.add_child(_espace(8))
	col.add_child(ScreenUtils.sous_titre("— ou par le réseau local —",
		Color(1, 1, 1, 0.4)))
	var heberger := ScreenUtils.bouton("Héberger une partie")
	heberger.pressed.connect(func() -> void: _ouvre(Net.heberge()))
	col.add_child(heberger)

	# L'adresse est pré-remplie sur la machine locale : le cas le plus fréquent
	# pendant le développement est deux fenêtres côte à côte, et il ne doit rien
	# demander de plus qu'un clic.
	_adresse = ScreenUtils.champ("127.0.0.1", "adresse du host")
	col.add_child(_adresse)

	var rejoindre := ScreenUtils.bouton("Rejoindre")
	rejoindre.pressed.connect(func() -> void: _ouvre(Net.rejoint(_adresse.text)))
	col.add_child(rejoindre)

	_statut = ScreenUtils.sous_titre("", Color(1, 0.6, 0.5, 0.9))
	col.add_child(_statut)
	_ajoute_l_avis_de_rejeu(col)
	col.add_child(_espace(14))

	var quitter := ScreenUtils.bouton("Quitter")
	quitter.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quitter)

	# Steam a pu lancer le jeu pour rejoindre un ami : l'invitation attendait
	# qu'un écran existe pour être suivie.
	var invitation: int = SteamNet.consomme_invitation()
	if invitation > 0:
		_sur_invitation(invitation)


## Le co-op par Steam : un bouton pour héberger, un champ pour rejoindre à la
## main. Les invitations, elles, n'ont besoin d'aucun des deux — elles arrivent
## par l'overlay et ouvrent le salon toutes seules.
##
## Quand Steam manque, les commandes restent VISIBLES et grisées, avec la raison
## juste en dessous : « le multijoueur ne marche pas » est un rapport de bug
## qu'on ne peut pas traiter, « GodotSteam n'est pas installé » en est un qu'on
## corrige en cinq minutes.
func _ajoute_le_bloc_steam(col: VBoxContainer) -> void:
	var pourquoi: String = SteamNet.indisponible_pourquoi()
	var pret: bool = pourquoi.is_empty()

	var heberger := ScreenUtils.bouton("Héberger sur Steam", pret)
	heberger.pressed.connect(func() -> void:
		_statut.text = "Création du lobby Steam…"
		SteamNet.heberge())
	col.add_child(heberger)

	# On accepte les deux identifiants qu'un joueur peut avoir sous la main :
	# celui d'un lobby (copié d'une invitation) et celui d'un hôte. Ils se
	# ressemblent — ce sont deux SteamID64 — mais ne se rejoignent pas pareil,
	# alors on demande lequel c'est plutôt que de le deviner.
	_lobby = ScreenUtils.champ("", "identifiant de lobby ou d'hôte Steam")
	_lobby.editable = pret
	col.add_child(_lobby)

	var rejoindre_lobby := ScreenUtils.bouton("Rejoindre le lobby", pret)
	rejoindre_lobby.pressed.connect(func() -> void:
		_statut.text = "Connexion au lobby…"
		SteamNet.rejoint_le_lobby(_identifiant_saisi()))
	col.add_child(rejoindre_lobby)

	var rejoindre_hote := ScreenUtils.bouton("Rejoindre l'hôte", pret)
	rejoindre_hote.pressed.connect(func() -> void:
		_statut.text = "Connexion à l'hôte…"
		SteamNet.rejoint_lhote(_lobby.text))
	col.add_child(rejoindre_hote)

	if not pret:
		col.add_child(ScreenUtils.sous_titre(pourquoi, Color(1, 0.72, 0.4, 0.85)))


## Une graine forcée doit se voir depuis le menu, et se relâcher d'un clic.
##
## C'est le piège de l'outil : on force une graine pour reproduire un bug, on
## l'oublie, et trois jours plus tard on croit que le donjon ne change plus.
## Un bandeau permanent coûte moins cher que cette demi-journée-là.
func _ajoute_l_avis_de_rejeu(col: VBoxContainer) -> void:
	if not Rejeu.actif():
		return
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 8)
	col.add_child(bloc)
	bloc.add_child(ScreenUtils.sous_titre(
		"Rejeu actif — toutes les runs partiront sur la graine %d"
			% Rejeu.graine_forcee, Color(1, 0.78, 0.35, 0.95)))
	var liberer := ScreenUtils.bouton("Libérer la graine")
	liberer.custom_minimum_size = Vector2(340, 34)
	liberer.pressed.connect(func() -> void:
		Rejeu.libere()
		bloc.queue_free())
	bloc.add_child(liberer)


func _identifiant_saisi() -> int:
	var texte: String = _lobby.text.strip_edges()
	return texte.to_int() if texte.is_valid_int() else 0


## Une invitation acceptée est un ordre : on la suit sans rien demander de plus.
## L'ami est déjà en train d'attendre de l'autre côté.
func _sur_invitation(lobby_id: int) -> void:
	_statut.text = "Invitation reçue — connexion…"
	SteamNet.rejoint_le_lobby(lobby_id)


## Le salon ne s'ouvre que si la connexion a démarré. Sinon on reste ici, avec
## la raison affichée sous les boutons.
func _ouvre(ouverte: bool) -> void:
	if ouverte and is_inside_tree():
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_SALON)


func _espace(hauteur: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
