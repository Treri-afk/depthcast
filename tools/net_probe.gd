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


func _process(delta: float) -> void:
	_t += delta
	if _host and _t > 2.0 and _t < 2.1:
		_t = 2.2
		print("[sonde] le host lance")
		Net.lance_la_partie()
	if _t > 4.0:
		get_tree().quit()
