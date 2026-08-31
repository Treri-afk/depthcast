class_name SteamApi
extends RefCounted
## Le pont vers Steamworks — et le seul endroit du projet qui parle à l'API.
##
## Tout passe par `Engine.get_singleton("Steam")` et par des appels dynamiques,
## jamais par l'identifiant global `Steam`. Ce n'est pas de la coquetterie :
## GodotSteam est une GDExtension ([D9]), elle n'est PAS versionnée dans le
## dépôt, et un script qui écrirait `Steam.getSteamID()` en dur refuserait de se
## parser sur une machine où l'extension n'est pas installée. Le projet entier
## cesserait de s'ouvrir — éditeur compris, CI comprise — pour une intégration
## dont personne n'a besoin ce jour-là.
##
## Ici, l'absence de Steam est un `false` et une phrase à afficher, jamais une
## erreur de parsing. C'est la condition pour que [R9] tienne : quatre instances
## locales en ENet, sans client Steam lancé.
##
## Les noms de méthodes de GodotSteam ont bougé d'une version à l'autre. On
## interroge donc `has_method()` avant d'appeler, et on appelle sans argument
## quand la signature a changé de forme selon les versions — les valeurs par
## défaut de GodotSteam font le reste.

## L'App ID public de Valve (*Spacewar*). Lobbies, invitations et P2P
## fonctionnent avec, sans payer Steam Direct et sans dépôt validé ([D8]).
## Le vrai App ID prendra sa place au moment de publier, et lui seul.
const APP_ID_DEV: int = 480

## Vrai une fois l'API démarrée avec succès. Statique parce que Steam ne
## s'initialise qu'une fois par processus : une seconde tentative n'est pas une
## erreur, c'est un non-évènement.
static var _demarre: bool = false

## Pourquoi Steam n'est pas disponible, en français, pour l'afficher sous un
## bouton grisé plutôt que dans une console que personne ne lit.
static var _raison: String = "Steam n'a pas été démarré."


## L'extension est-elle installée ? Répond sans rien initialiser.
static func extension_presente() -> bool:
	return Engine.has_singleton("Steam")


## Le singleton GodotSteam, ou `null`. Réservé aux couches transport et lobby :
## aucun autre script du projet n'a le droit de l'appeler ([R9]).
static func api() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


## Démarre l'API. Idempotent. Retourne faux et renseigne `raison()` en cas
## d'échec — extension absente, client fermé, ou compte déconnecté.
static func demarre(app_id: int = APP_ID_DEV) -> bool:
	if _demarre:
		return true
	var steam: Object = api()
	if steam == null:
		_raison = "GodotSteam n'est pas installé — voir docs/STEAM.md."
		return false

	# Steam veut connaître l'App ID AVANT l'initialisation. Par l'environnement
	# plutôt que par `steam_appid.txt` : ce fichier est ignoré par Git (il porte
	# des identifiants de publication) et quelqu'un qui vient de cloner ne l'a
	# pas. Une variable d'environnement, elle, voyage avec le code.
	OS.set_environment("SteamAppID", str(app_id))
	OS.set_environment("SteamGameId", str(app_id))

	var retour: Variant = null
	if steam.has_method("steamInitEx"):
		retour = steam.callv("steamInitEx", [])
	elif steam.has_method("steamInit"):
		retour = steam.callv("steamInit", [])
	else:
		_raison = "GodotSteam est présent mais n'expose aucune initialisation connue."
		return false

	# Selon la version, l'initialisation rend un dictionnaire {status, verbal},
	# un booléen, ou rien du tout. Les trois formes disent la même chose.
	if retour is Dictionary:
		var etat: Dictionary = retour
		var code: int = int(etat.get("status", 1))
		_demarre = code == 0
		_raison = String(etat.get("verbal", "Steam a répondu %d." % code))
	elif retour is bool:
		_demarre = bool(retour)
		_raison = "Steam a refusé l'initialisation."
	else:
		_demarre = client_lance()
		_raison = "Le client Steam ne répond pas."

	if _demarre:
		_raison = ""
	return _demarre


## Le client Steam tourne-t-il ?
static func client_lance() -> bool:
	var steam: Object = api()
	if steam == null or not steam.has_method("isSteamRunning"):
		return false
	return bool(steam.call("isSteamRunning"))


## Prêt à héberger ou rejoindre : API démarrée, compte connecté.
static func disponible() -> bool:
	if not _demarre:
		return false
	var steam: Object = api()
	if steam == null:
		return false
	if steam.has_method("loggedOn"):
		return bool(steam.call("loggedOn"))
	return true


static func raison() -> String:
	return _raison


## Le pseudo Steam du joueur, à défaut son nom Windows. Le salon affiche des
## noms, pas des identifiants : c'est ce qui fait qu'on reconnaît un ami.
static func mon_nom() -> String:
	var steam: Object = api()
	if disponible() and steam != null and steam.has_method("getPersonaName"):
		var nom: String = String(steam.call("getPersonaName"))
		if not nom.is_empty():
			return nom
	return OS.get_environment("USERNAME") if not OS.get_environment("USERNAME").is_empty() \
		else "Joueur"


## Mon SteamID64. Zéro si Steam n'est pas disponible.
static func mon_id() -> int:
	var steam: Object = api()
	if disponible() and steam != null and steam.has_method("getSteamID"):
		return int(steam.call("getSteamID"))
	return 0


## Fait avancer les rappels de Steamworks (invitations, lobbies, connexions).
##
## Steam empile ses évènements et ne les livre que lorsqu'on les réclame : sans
## cet appel, une invitation acceptée n'arrive jamais. L'appeler alors que la
## GDExtension les pompe déjà elle-même est sans effet — la file est simplement
## vide.
static func pompe_les_evenements() -> void:
	var steam: Object = api()
	if steam != null and _demarre and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")


## La classe de pair réseau fournie par l'extension est-elle disponible ?
##
## Elle est distincte de l'API elle-même : selon la distribution de GodotSteam
## installée, on peut avoir l'une sans l'autre. Un bouton « héberger » qui
## ouvrirait une session sans tuyau derrière serait pire qu'un bouton grisé.
static func peer_disponible() -> bool:
	return ClassDB.class_exists("SteamMultiplayerPeer") \
		and ClassDB.can_instantiate("SteamMultiplayerPeer")
