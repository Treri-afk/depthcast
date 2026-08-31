extends Node
## Sonde réseau : héberge ou rejoint, puis raconte ce qu'elle voit.
##
## Elle existe pour vérifier la session SANS ouvrir deux fenêtres. Le réseau est
## le seul système du projet qu'un banc de vérification ordinaire ne peut pas
## atteindre — il lui faut deux processus — et un système qu'on ne peut pas
## essayer vite est un système qu'on n'essaie pas.
##
##     Godot --headless --path . res://tools/sonde.tscn -- host   (terminal 1)
##     Godot --headless --path . res://tools/sonde.tscn            (terminal 2)
##
## Elle doit afficher, des deux côtés, le même salon et la même graine.
##
## Ajouter `steam` passe par le transport Steam au lieu du réseau local. Le
## client donne alors le SteamID64 de l'hôte, que celui-ci affiche au démarrage.
## Ça demande deux comptes et deux machines — Steam en refuse deux sur le même
## compte (D8) — mais c'est le seul moyen d'essayer le tuyau de production sans
## passer par l'interface, et sans export :
##
##     Godot --headless --path . res://tools/sonde.tscn -- host steam
##     Godot --headless --path . res://tools/sonde.tscn -- steam 76561198000000000

var _t: float = 0.0
var _host: bool = false


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_host = arguments.has("host")

	# Les écoutes d'abord, l'ouverture ensuite : par Steam, la session peut
	# s'ouvrir avant la fin de cette fonction, et un salon qu'on n'écoutait pas
	# encore ne se raconte jamais.
	Net.roster_change.connect(func() -> void:
		var noms: Array = []
		for id: int in Net.joueurs():
			noms.append("%d=%s" % [id, Net.nom_du_joueur(id)])
		print("[sonde] %s salon=%s local=%d host=%s" % [
			"HOST" if _host else "CLIENT", str(noms),
			GameState.local_player_id, Net.est_host()]))
	Net.partie_lancee.connect(func(g: int) -> void:
		print("[sonde] %s départ avec graine %d" % ["HOST" if _host else "CLIENT", g]))

	if arguments.has("steam"):
		_demarre_par_steam(arguments)
	elif _host:
		print("[sonde] hébergement : ", Net.heberge(27015, "Alice"))
	else:
		print("[sonde] connexion : ", Net.rejoint("127.0.0.1", 27015, "Bob"))


## Le chemin Steam. Il échoue bruyamment plutôt que de retomber sur ENet : une
## sonde qui répond « SUCCÈS » en ayant testé l'autre transport est pire
## qu'une sonde qui ne répond rien.
func _demarre_par_steam(arguments: PackedStringArray) -> void:
	var pourquoi: String = SteamNet.indisponible_pourquoi()
	if not pourquoi.is_empty():
		print("[sonde] ÉCHEC — %s" % pourquoi)
		get_tree().quit(1)
		return

	SteamNet.echec.connect(func(message: String) -> void:
		print("[sonde] ÉCHEC — %s" % message)
		get_tree().quit(1))

	if _host:
		print("[sonde] hébergement Steam — les clients rejoignent l'hôte %d"
			% SteamApi.mon_id())
		SteamNet.heberge()
		return

	# Le dernier argument numérique est l'identifiant : celui d'un hôte, ou
	# celui d'un lobby. Un lobby demande un aller-retour de plus, et c'est très
	# exactement ce qu'on veut vérifier quand on le passe.
	var identifiant: String = ""
	for argument: String in arguments:
		if argument.is_valid_int():
			identifiant = argument
	if identifiant.is_empty():
		print("[sonde] ÉCHEC — donne le SteamID64 de l'hôte en argument.")
		get_tree().quit(1)
		return
	print("[sonde] connexion Steam à %s" % identifiant)
	SteamNet.rejoint_lhote(identifiant)


var _battement: float = 0.0
## Le meilleur état observé. L'hôte se termine avant le client, et son départ
## ferait conclure à un échec alors que la session a parfaitement fonctionné.
var _meilleur: int = 1


func _process(delta: float) -> void:
	_t += delta

	# Un battement par seconde : sans lui, une sonde qui attend en silence
	# ressemble exactement à une sonde qui a planté.
	_battement -= delta
	if _battement <= 0.0:
		_battement = 1.0
		_meilleur = maxi(_meilleur, Net.nombre_de_joueurs())
		print("[sonde] %.0fs — %s, %d joueur(s)" % [
			_t, Net.description(), Net.nombre_de_joueurs()])

	if _host and _t > 4.0 and _t < 4.2:
		_t = 4.3
		if Net.nombre_de_joueurs() < 2:
			print("[sonde] ÉCHEC — personne n'a rejoint. Lance le second terminal.")
		else:
			print("[sonde] le host lance la partie")
			Net.lance_la_partie()

	if _t > 7.0:
		var seul: bool = _meilleur < 2
		print("[sonde] VERDICT : %s" % ("ÉCHEC — resté seul, personne n'a rejoint"
			if seul else "SUCCÈS — session à %d joueurs, graine %d" % [
				_meilleur, Net.graine]))
		get_tree().quit(1 if seul else 0)
