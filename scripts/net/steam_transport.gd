class_name SteamTransport
extends NetTransport
## Le tuyau de production : les Steam Networking Sockets ([D2], [D8]).
##
## Steam relaie le trafic par ses propres serveurs quand la connexion directe
## échoue. C'est tout l'intérêt face à ENet : plus de port à ouvrir, plus de box
## à configurer, plus d'adresse IP à s'échanger — un ami clique sur une
## invitation et il est là.
##
## Ce que ce fichier ne fait PAS : les lobbies, les invitations, la découverte.
## Tout ça vit dans `SteamLobby` (autoload `SteamNet`), parce que ce sont deux
## métiers différents. Ici on ouvre un tuyau entre deux SteamID, un point.
##
## Le port est ignoré, à dessein : Steam n'en a pas. Ce qui remplace l'adresse,
## c'est le SteamID64 de l'hôte — c'est lui qu'on passe à `rejoint()`.

## Le canal virtuel Steam utilisé par la partie. Zéro : le jeu n'en ouvre qu'un,
## et deux canaux ne serviraient qu'à répliquer la file de messages de Godot.
const CANAL: int = 0


func nom() -> String:
	return "Steam"


func heberge(_port: int) -> MultiplayerPeer:
	var pair: MultiplayerPeer = _cree_le_pair()
	if pair == null:
		return null
	if not _appelle(pair, "create_host", [CANAL]):
		return null
	derniere_erreur = ""
	return pair


## `adresse` est le SteamID64 de l'hôte, pas une IP.
func rejoint(adresse: String, _port: int) -> MultiplayerPeer:
	var identifiant: int = _lit_un_identifiant(adresse)
	if identifiant <= 0:
		derniere_erreur = "« %s » n'est pas un identifiant Steam." % adresse
		return null
	var pair: MultiplayerPeer = _cree_le_pair()
	if pair == null:
		return null
	if not _appelle(pair, "create_client", [identifiant, CANAL]):
		return null
	derniere_erreur = ""
	return pair


## Ce que l'hôte communique aux autres : son SteamID64. Il reste utile même
## quand les invitations marchent — c'est le seul recours quand l'overlay est
## désactivé, et c'est ce qui rend une session déboguable au téléphone.
func adresse_affichable() -> String:
	var identifiant: int = SteamApi.mon_id()
	return str(identifiant) if identifiant > 0 else ""


# ── Détails ───────────────────────────────────────────────────────────────

func _cree_le_pair() -> MultiplayerPeer:
	if not SteamApi.disponible():
		derniere_erreur = "Steam n'est pas disponible : %s" % SteamApi.raison()
		return null
	if not SteamApi.peer_disponible():
		derniere_erreur = "GodotSteam ne fournit pas SteamMultiplayerPeer — voir docs/STEAM.md."
		return null
	var pair: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if pair is not MultiplayerPeer:
		derniere_erreur = "SteamMultiplayerPeer n'est pas un pair réseau valide."
		return null
	return pair


## Ouvre le tuyau, quelle que soit la façon dont la version installée rend son
## verdict : un code d'erreur, ou rien du tout suivi d'un état de connexion.
func _appelle(pair: MultiplayerPeer, methode: String, arguments: Array) -> bool:
	if not pair.has_method(methode):
		derniere_erreur = "SteamMultiplayerPeer n'expose pas %s()." % methode
		return false
	var retour: Variant = pair.callv(methode, arguments)
	if retour is int and int(retour) != OK:
		derniere_erreur = "Steam a refusé la connexion (code %d)." % int(retour)
		return false
	if pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		derniere_erreur = "Steam n'a pas ouvert la connexion."
		return false
	return true


## Un SteamID64 tient sur 17 chiffres : au-delà de ce que `to_int()` accepte
## sans broncher, mais dans les clous d'un entier 64 bits signé. On refuse tout
## ce qui n'est pas une suite de chiffres plutôt que de laisser `to_int()`
## transformer une adresse IP collée par erreur en un identifiant plausible.
func _lit_un_identifiant(texte: String) -> int:
	var propre: String = texte.strip_edges()
	if propre.is_empty() or not propre.is_valid_int():
		return 0
	return propre.to_int()
