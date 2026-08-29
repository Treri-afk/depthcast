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

var _t: float = 0.0
var _host: bool = false


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("host")
	if _host:
		print("[sonde] hébergement : ", Net.heberge(27015, "Alice"))
	else:
		print("[sonde] connexion : ", Net.rejoint("127.0.0.1", 27015, "Bob"))
	Net.roster_change.connect(func() -> void:
		var noms: Array = []
		for id: int in Net.joueurs():
			noms.append("%d=%s" % [id, Net.nom_du_joueur(id)])
		print("[sonde] %s salon=%s local=%d host=%s" % [
			"HOST" if _host else "CLIENT", str(noms),
			GameState.local_player_id, Net.est_host()]))
	Net.partie_lancee.connect(func(g: int) -> void:
		print("[sonde] %s départ avec graine %d" % ["HOST" if _host else "CLIENT", g]))


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
