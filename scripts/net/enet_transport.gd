class_name EnetTransport
extends NetTransport
## Réseau local, par ENet — le transport de développement et de LAN.
##
## C'est celui avec lequel le co-op se construit et se règle : deux instances du
## jeu sur la même machine se parlent en localhost, sans compte, sans client
## tiers, sans connexion Internet. Steam viendra remplacer ce tuyau pour la
## distribution, quand il s'agira de traverser les box des joueurs et d'inviter
## des amis — pas avant.


func nom() -> String:
	return "réseau local (ENet)"


func heberge(port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	var code: int = pair.create_server(port, JOUEURS_MAX)
	if code != OK:
		derniere_erreur = "Impossible d'ouvrir le port %d (code %d). Une autre partie tourne peut-être déjà." % [port, code]
		return null
	derniere_erreur = ""
	return pair


func rejoint(adresse: String, port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	var code: int = pair.create_client(adresse, port)
	if code != OK:
		derniere_erreur = "Adresse %s:%d injoignable (code %d)." % [adresse, port, code]
		return null
	derniere_erreur = ""
	return pair


func adresse_affichable() -> String:
	# L'adresse locale, celle que les autres joueurs du réseau doivent saisir.
	# Sur la même machine, 127.0.0.1 suffit toujours.
	for ip: String in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip
	return "127.0.0.1"
