extends Node
## La session réseau — autoload `Net`.
##
## Elle sait qui est connecté, quel identifiant de jeu porte chaque pair, et qui
## fait autorité. Elle ne réplique RIEN elle-même : c'est un annuaire et un
## cycle de vie, pas un moteur de synchronisation.
##
## Elle survit aux changements de scène, parce qu'une partie survit au passage
## du salon au donjon. C'est aussi pour ça qu'elle porte la graine : les deux
## machines doivent générer le même donjon, et la graine est la seule chose qui
## le garantisse (D1).
##
## Hors ligne, tout ici répond en solo sans qu'un seul appelant ait à demander
## s'il y a un réseau : `nombre_de_joueurs()` vaut 1, `est_host()` vaut vrai.
## C'est la condition pour que le mode solo ne devienne pas un cas particulier
## du multijoueur — ce serait le meilleur moyen de le casser sans s'en rendre
## compte.

## Où en est la connexion.
##
## `est_host()` répond vrai hors ligne, à dessein : le gameplay ne doit jamais
## demander s'il y a un réseau avant d'agir. Mais le SALON, lui, doit faire la
## différence entre « je suis seul » et « je suis l'hôte d'une vraie partie ».
##
## Sans cet état, une connexion ratée laissait le salon se comporter comme un
## host solo : on appuyait sur Descendre et chacun jouait sa partie sans que
## rien ne le signale. C'est exactement le genre de panne qui se lit comme
## « le multijoueur ne marche pas ».
enum Etat { HORS_LIGNE, CONNEXION, CONNECTE }

const PORT_PAR_DEFAUT: int = 27015
## Repris du transport, qui est celui qui ouvre les connexions : deux plafonds
## différents laisseraient entrer un joueur que le jeu ne saurait pas placer.
const JOUEURS_MAX: int = NetTransport.JOUEURS_MAX

## Le salon a changé : quelqu'un est arrivé, parti, ou s'est nommé.
signal roster_change()
## Le host lance la descente. Tout le monde bascule sur la même graine.
signal partie_lancee(graine: int)
signal connexion_perdue()
signal echec(message: String)

var etat: Etat = Etat.HORS_LIGNE
var transport: NetTransport = null
## Graine de la run en cours. Choisie par le host, diffusée à tous.
var graine: int = 0

## peer Godot → player_id du jeu. Le host est toujours le joueur 0.
var _joueurs: Dictionary = {}
var _noms: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_sur_arrivee)
	multiplayer.peer_disconnected.connect(_sur_depart)
	multiplayer.connected_to_server.connect(_sur_connexion_reussie)
	multiplayer.connection_failed.connect(_sur_connexion_ratee)
	multiplayer.server_disconnected.connect(_sur_host_perdu)


# ── Interrogation ─────────────────────────────────────────────────────────

func en_ligne() -> bool:
	return multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer is not OfflineMultiplayerPeer


## Hors ligne, on est son propre host : le code de gameplay n'a jamais à se
## demander s'il y a un réseau avant de décider s'il a le droit d'agir.
func est_host() -> bool:
	return not en_ligne() or multiplayer.is_server()


func nombre_de_joueurs() -> int:
	return maxi(_joueurs.size(), 1) if en_ligne() else 1


## Les identifiants de jeu présents, triés. En solo : [0].
func joueurs() -> Array[int]:
	var out: Array[int] = []
	if not en_ligne():
		out.append(0)
		return out
	for peer: int in _joueurs:
		out.append(int(_joueurs[peer]))
	out.sort()
	return out


func nom_du_joueur(player_id: int) -> String:
	var peer: int = peer_de(player_id)
	if _noms.has(peer):
		return String(_noms[peer])
	return "Joueur %d" % (player_id + 1)


## Le pair Godot qui contrôle ce joueur. -1 si inconnu.
func peer_de(player_id: int) -> int:
	for peer: int in _joueurs:
		if int(_joueurs[peer]) == player_id:
			return peer
	return -1


func player_id_de(peer: int) -> int:
	return int(_joueurs.get(peer, -1))


# ── Cycle de vie ──────────────────────────────────────────────────────────

func heberge(port: int = PORT_PAR_DEFAUT, mon_nom: String = "Host") -> bool:
	quitte()
	transport = EnetTransport.new()
	var pair: MultiplayerPeer = transport.heberge(port)
	if pair == null:
		echec.emit(transport.derniere_erreur)
		return false

	multiplayer.multiplayer_peer = pair
	etat = Etat.CONNECTE
	# Le host est le joueur 0, toujours. Ça n'a rien d'arbitraire : c'est lui
	# qui fait autorité, et l'autorité doit avoir un identifiant stable.
	_joueurs = {1: 0}
	_noms = {1: mon_nom}
	GameState.local_player_id = 0
	roster_change.emit()
	return true


func rejoint(adresse: String, port: int = PORT_PAR_DEFAUT,
		mon_nom: String = "Invité") -> bool:
	quitte()
	transport = EnetTransport.new()
	var pair: MultiplayerPeer = transport.rejoint(adresse, port)
	if pair == null:
		echec.emit(transport.derniere_erreur)
		return false

	multiplayer.multiplayer_peer = pair
	# CONNEXION et pas CONNECTE : créer un client réussit TOUJOURS, même face à
	# une adresse où personne n'écoute. La vérité arrive plus tard, par
	# `connected_to_server` ou par `connection_failed`.
	etat = Etat.CONNEXION
	_noms[0] = mon_nom
	return true


func quitte() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_joueurs.clear()
	_noms.clear()
	transport = null
	etat = Etat.HORS_LIGNE
	# La graine meurt avec la session. Sans ça, une partie solo lancée après
	# avoir quitté un salon rejouait le donjon de la partie d'avant, à
	# l'identique, jusqu'au redémarrage du jeu.
	graine = 0
	GameState.local_player_id = 0


## Le host lance la descente. La graine part avec l'ordre : sans elle, chacun
## générerait son propre donjon et personne ne jouerait dans le même.
## Vrai pour l'hôte d'une VRAIE partie en ligne, ou pour un solo assumé. Un
## client, ou un salon dont la connexion a échoué, ne lance rien.
func peut_lancer() -> bool:
	match etat:
		Etat.HORS_LIGNE:
			return true
		Etat.CONNECTE:
			return multiplayer.is_server()
	return false


## Description lisible de l'état, pour l'AFFICHER plutôt que le deviner.
func description() -> String:
	match etat:
		Etat.CONNEXION:
			return "connexion en cours…"
		Etat.CONNECTE:
			return "connecté — %s" % ("hôte" if multiplayer.is_server() else "invité")
	return "hors ligne"


func lance_la_partie() -> void:
	if not peut_lancer():
		return
	var tirage: int = randi()
	if en_ligne():
		_recois_le_depart.rpc(tirage)
	else:
		_recois_le_depart(tirage)


# ── Signaux du réseau ─────────────────────────────────────────────────────

func _sur_arrivee(peer: int) -> void:
	if not multiplayer.is_server():
		return
	if _joueurs.size() >= JOUEURS_MAX:
		multiplayer.multiplayer_peer.disconnect_peer(peer)
		return
	_joueurs[peer] = _prochain_identifiant_libre()
	_diffuse_le_salon()


func _sur_depart(peer: int) -> void:
	if not multiplayer.is_server():
		return
	_joueurs.erase(peer)
	_noms.erase(peer)
	_diffuse_le_salon()


func _sur_connexion_reussie() -> void:
	etat = Etat.CONNECTE
	_declare_mon_nom.rpc_id(1, String(_noms.get(0, "Invité")))
	roster_change.emit()


func _sur_connexion_ratee() -> void:
	echec.emit("Le host n'a pas répondu.")
	quitte()


func _sur_host_perdu() -> void:
	connexion_perdue.emit()
	quitte()


## Le plus petit identifiant libre, jamais la taille de la liste : après un
## départ, réutiliser un trou évite qu'un quatrième joueur porte l'identifiant 5
## et sorte des tableaux indexés par joueur.
func _prochain_identifiant_libre() -> int:
	var pris: Array = _joueurs.values()
	for candidat: int in JOUEURS_MAX:
		if not pris.has(candidat):
			return candidat
	return JOUEURS_MAX - 1


func _diffuse_le_salon() -> void:
	_recois_le_salon.rpc(_joueurs, _noms)


# ── Appels distants ───────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _declare_mon_nom(nom: String) -> void:
	if not multiplayer.is_server():
		return
	_noms[multiplayer.get_remote_sender_id()] = nom
	_diffuse_le_salon()


## Le host est la seule source de vérité sur qui joue et sous quel identifiant.
## Un client qui déciderait du sien pourrait entrer en collision avec un autre.
@rpc("authority", "call_local", "reliable")
func _recois_le_salon(joueurs: Dictionary, noms: Dictionary) -> void:
	_joueurs = joueurs.duplicate()
	_noms = noms.duplicate()
	var moi: int = player_id_de(multiplayer.get_unique_id())
	if moi >= 0:
		GameState.local_player_id = moi
	roster_change.emit()


@rpc("authority", "call_local", "reliable")
func _recois_le_depart(tirage: int) -> void:
	graine = tirage
	partie_lancee.emit(tirage)
