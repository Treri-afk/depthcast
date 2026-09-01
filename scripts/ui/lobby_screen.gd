extends Control
## Le salon : qui est là, et qui appuie sur le bouton.
##
## Il n'affiche rien qu'il détienne. La liste des joueurs vit dans la session,
## et cet écran se contente de la redessiner à chaque changement — c'est la même
## règle que pour l'état de jeu (R1), et pour la même raison : deux copies d'une
## vérité finissent toujours par diverger.
##
## Seul le host peut lancer. La graine part avec l'ordre de départ : sans elle,
## chacun générerait son propre donjon et personne ne jouerait dans le même.

var _liste: Label
var _descendre: Button
var _statut: Label
var _connexion: Label
var _inviter: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ScreenUtils.fond(self)
	var col := ScreenUtils.colonne(self, 14)

	col.add_child(ScreenUtils.titre("SALON"))
	var quoi: String = Net.transport.nom() if Net.transport != null else "hors ligne"
	var ou: String = Net.transport.adresse_affichable() if Net.transport != null else ""
	col.add_child(ScreenUtils.sous_titre(
		"%s   ·   les autres joueurs saisissent %s" % [quoi, ou]))

	_connexion = ScreenUtils.sous_titre("")
	_connexion.add_theme_font_size_override("font_size", 17)
	col.add_child(_connexion)
	col.add_child(_espace(16))

	_liste = ScreenUtils.sous_titre("", Color(1, 1, 1, 0.9))
	_liste.add_theme_font_size_override("font_size", 18)
	col.add_child(_liste)
	col.add_child(_espace(20))

	# L'invitation n'existe que par Steam, et seulement une fois le lobby créé :
	# c'est son identifiant qui part à l'ami, pas le nôtre. Le bouton apparaît
	# donc quand le lobby arrive, pas quand l'écran s'ouvre.
	_inviter = ScreenUtils.bouton("Inviter des amis")
	_inviter.pressed.connect(func() -> void: SteamNet.invite_des_amis())
	col.add_child(_inviter)
	SteamNet.lobby_change.connect(func(_id: int) -> void: _rafraichit())

	_descendre = ScreenUtils.bouton("Rejoindre le hub")
	_descendre.pressed.connect(func() -> void: Net.lance_la_partie())
	col.add_child(_descendre)

	var quitter := ScreenUtils.bouton("Quitter le salon")
	quitter.pressed.connect(func() -> void:
		Net.quitte()
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU))
	col.add_child(quitter)

	_statut = ScreenUtils.sous_titre("", Color(1, 0.6, 0.5, 0.9))
	col.add_child(_statut)

	Net.roster_change.connect(_rafraichit)
	Net.partie_lancee.connect(_descend)
	Net.connexion_perdue.connect(func() -> void:
		_statut.text = "L'hôte a quitté la partie."
		_rafraichit())
	Net.echec.connect(func(message: String) -> void:
		_statut.text = message
		_rafraichit())
	_rafraichit()


## Redessiné tant que la connexion n'a pas abouti. Un échec arrive par signal,
## mais une tentative qui traîne ne dit rien du tout — et un salon figé sur
## « connexion en cours » n'apprend pas grand-chose non plus.
func _process(_delta: float) -> void:
	if Net.etat == Net.Etat.CONNEXION:
		_rafraichit()


func _rafraichit() -> void:
	var lignes: PackedStringArray = []
	for id: int in Net.joueurs():
		var marque: String = "  (host)" if id == 0 else ""
		var moi: String = "  ← toi" if GameState.est_local(id) else ""
		lignes.append("%d.  %s%s%s" % [id + 1, Net.nom_du_joueur(id), marque, moi])
	_liste.text = "\n".join(lignes)

	# Rien à inviter sans lobby Steam : en réseau local, on communique une
	# adresse, et le bouton n'aurait aucune action à proposer.
	_inviter.visible = SteamNet.lobby > 0
	if _inviter.visible:
		_inviter.text = "Inviter des amis  ·  lobby %d" % SteamNet.lobby

	_connexion.text = Net.description()
	_connexion.add_theme_color_override("font_color",
		Color(0.55, 0.92, 0.6) if Net.etat == Net.Etat.CONNECTE
		else Color(1, 0.72, 0.4))

	# Seul l'hôte d'une VRAIE partie lance. Un salon dont la connexion a échoué
	# se croyait host solo et laissait descendre : chacun jouait alors sa partie
	# de son côté sans que rien ne le signale.
	_descendre.disabled = not Net.peut_lancer()
	if Net.etat == Net.Etat.CONNEXION:
		_descendre.text = "Connexion…"
	elif Net.etat == Net.Etat.HORS_LIGNE:
		_descendre.text = "Hors ligne — reviens au menu"
		_descendre.disabled = true
	elif not multiplayer.is_server():
		_descendre.text = "En attente de l'hôte…"
	else:
		_descendre.text = "Rejoindre le hub"



## Le salon mène au HUB, pas au donjon. C'est là qu'on se retrouve, qu'on voit
## ce que prennent les autres et qu'on se répartit les écoles — la préparation
## est un moment de jeu, pas un écran de configuration.
func _descend(_graine: int) -> void:
	get_tree().change_scene_to_file(ScreenUtils.CHEMIN_HUB)


func _espace(hauteur: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
