extends Node
## Les lobbies Steam et les invitations — autoload `SteamNet`.
##
## Le transport ouvre un tuyau entre deux SteamID ; encore faut-il connaître
## celui d'en face. C'est le rôle du lobby : il porte l'identité de l'hôte, il
## sait ouvrir l'overlay d'invitation, et il reçoit les « rejoindre la partie »
## venus de la liste d'amis. Deux métiers, deux fichiers — R9 autorise Steam
## dans la couche transport ET dans le lobby, nulle part ailleurs.
##
## Tout est asynchrone ici, et ce n'est pas un détail d'implémentation : créer
## un lobby demande un aller-retour aux serveurs de Valve. Rien ne peut donc
## répondre « oui, la session est ouverte » sur-le-champ. L'écran qui appelle
## attend le signal `session_prete` — c'est pour ça que ces méthodes ne rendent
## pas de booléen, contrairement à `Net.heberge()`.
##
## Si GodotSteam n'est pas installé, cet autoload se charge quand même et répond
## non à tout. C'est la condition pour que le projet s'ouvre sur une machine
## sans extension, et pour que le développement quotidien reste en ENet (D15).

## La session en ligne est ouverte : l'écran appelant peut basculer sur le salon.
signal session_prete()
## Une tentative a échoué, avec une phrase affichable telle quelle.
signal echec(message: String)
## Le lobby a changé d'identifiant (créé, rejoint, ou quitté). Le salon s'en
## sert pour afficher — ou masquer — le bouton d'invitation.
signal lobby_change(lobby_id: int)
## Un ami nous invite à le rejoindre. Émis pour l'écran qui écoute ; ceux qui
## n'écoutaient pas encore la retrouvent avec `consomme_invitation()`.
signal invitation_recue(lobby_id: int)

## Type de lobby Steam : visible des amis, invisible du reste du monde.
## Valeur de l'ABI Steamworks (`k_ELobbyTypeFriendsOnly`), stable depuis 2007.
const LOBBY_AMIS: int = 1
## Métadonnée qui distingue nos lobbies de ceux des milliers d'autres projets
## qui développent sur l'App ID 480 (D8).
const CLE_JEU: String = "jeu"
const VALEUR_JEU: String = "depthcast"
## Au-delà, on considère que Steam ne répondra pas. Sans ce garde, un lobby qui
## ne se crée jamais laisse l'écran sur « connexion… » indéfiniment.
const DELAI_MAX: float = 12.0

## Le lobby courant, ou 0. Renseigné par les rappels de Steam, jamais deviné.
var lobby: int = 0

## Invitation reçue avant que le menu n'existe — typiquement au lancement, quand
## Steam démarre le jeu avec `+connect_lobby`. Elle attend qu'on vienne la
## chercher plutôt que de forcer un changement de scène par-dessus un écran en
## cours de construction.
var _invitation: int = 0

## Ce qu'on attend de Steam en ce moment, et depuis combien de temps.
var _attente: String = ""
var _depuis: float = 0.0


func _ready() -> void:
	# Steam ne se démarre qu'une fois, au lancement du jeu, et son absence n'est
	# pas une panne : c'est le cas normal en développement.
	if SteamApi.extension_presente():
		SteamApi.demarre()
		_branche_les_rappels()
	_recupere_invitation_de_lancement()


func _process(delta: float) -> void:
	SteamApi.pompe_les_evenements()
	if _attente.is_empty():
		return
	_depuis += delta
	if _depuis > DELAI_MAX:
		_abandonne("Steam n'a pas répondu (%s)." % _attente)


# ── Interrogation ─────────────────────────────────────────────────────────

## Peut-on héberger ou rejoindre par Steam, ici et maintenant ?
func disponible() -> bool:
	return SteamApi.disponible() and SteamApi.peer_disponible()


## Pourquoi pas, en une phrase à afficher sous un bouton grisé. Vide si tout va
## bien. Un bouton inerte qui ne dit pas pourquoi se lit comme une panne.
func indisponible_pourquoi() -> String:
	if not SteamApi.extension_presente():
		return "GodotSteam n'est pas installé — voir docs/STEAM.md."
	if not SteamApi.peer_disponible():
		return "GodotSteam ne fournit pas SteamMultiplayerPeer."
	if not SteamApi.disponible():
		var raison: String = SteamApi.raison()
		return "Steam indisponible%s" % ("" if raison.is_empty() else " : " + raison)
	return ""


func occupe() -> bool:
	return not _attente.is_empty()


## L'invitation en attente. Elle n'est rendue qu'une fois : la consommer évite
## qu'un simple retour au menu rejoue la partie de la veille.
func consomme_invitation() -> int:
	var recue: int = _invitation
	_invitation = 0
	return recue


# ── Actions ───────────────────────────────────────────────────────────────

## Ouvre une partie et le lobby qui va avec. Le tuyau est prêt immédiatement ;
## le lobby, lui, arrive par rappel — et c'est seulement à ce moment-là que des
## amis peuvent être invités.
func heberge() -> void:
	if not _verifie_disponible():
		return
	if not Net.heberge(Net.PORT_PAR_DEFAUT, SteamApi.mon_nom(), SteamTransport.new()):
		return
	var steam: Object = SteamApi.api()
	if steam == null or not steam.has_method("createLobby"):
		Net.quitte()
		echec.emit("Cette version de GodotSteam ne sait pas créer de lobby.")
		return
	_attends("création du lobby")
	steam.call("createLobby", LOBBY_AMIS, NetTransport.JOUEURS_MAX)


## Rejoint par identifiant de lobby : le chemin des invitations. Il faut entrer
## dans le lobby pour apprendre qui l'héberge — d'où l'aller-retour.
func rejoint_le_lobby(identifiant: int) -> void:
	if not _verifie_disponible():
		return
	if identifiant <= 0:
		echec.emit("Identifiant de lobby invalide.")
		return
	var steam: Object = SteamApi.api()
	if steam == null or not steam.has_method("joinLobby"):
		echec.emit("Cette version de GodotSteam ne sait pas rejoindre de lobby.")
		return
	_attends("connexion au lobby")
	steam.call("joinLobby", identifiant)


## Rejoint directement le SteamID d'un hôte, sans passer par un lobby. C'est le
## recours quand l'overlay est coupé — et le seul chemin qu'on puisse essayer
## avec un identifiant collé à la main.
func rejoint_lhote(steam_id: String) -> void:
	if not _verifie_disponible():
		return
	if Net.rejoint(steam_id, Net.PORT_PAR_DEFAUT, SteamApi.mon_nom(),
			SteamTransport.new()):
		session_prete.emit()


## Ouvre l'overlay Steam sur la liste d'amis. Sans lobby, il n'y a rien à
## proposer : l'invitation porte l'identifiant du lobby, pas celui du joueur.
##
## L'overlay ne s'affiche PAS depuis l'éditeur, uniquement dans un export (D9).
func invite_des_amis() -> void:
	if lobby <= 0:
		return
	var steam: Object = SteamApi.api()
	if steam != null and steam.has_method("activateGameOverlayInviteDialog"):
		steam.call("activateGameOverlayInviteDialog", lobby)


## Quitte le lobby. La session réseau, elle, appartient à `Net` : on ne la ferme
## pas ici, sinon deux endroits décideraient de la fin d'une partie.
func quitte_le_lobby() -> void:
	var steam: Object = SteamApi.api()
	if lobby > 0 and steam != null and steam.has_method("leaveLobby"):
		steam.call("leaveLobby", lobby)
	_attente = ""
	lobby = 0
	lobby_change.emit(0)


# ── Rappels de Steam ──────────────────────────────────────────────────────

func _branche_les_rappels() -> void:
	var steam: Object = SteamApi.api()
	if steam == null:
		return
	# Chaque rappel est branché s'il existe : les signaux de GodotSteam ont bougé
	# entre versions, et une version qui en manque un doit dégrader, pas planter
	# au chargement de l'autoload.
	if steam.has_signal("lobby_created"):
		steam.connect("lobby_created", _sur_lobby_cree)
	if steam.has_signal("lobby_joined"):
		steam.connect("lobby_joined", _sur_lobby_rejoint)
	if steam.has_signal("join_requested"):
		steam.connect("join_requested", _sur_demande_de_rejoindre)


func _sur_lobby_cree(retour: int, identifiant: int) -> void:
	# Steam livre ce rappel DEUX fois — observé, pas supposé : une fois par la
	# file de callbacks, une fois par le résultat d'appel. Sans ce garde, la
	# session s'annonce prête deux fois et l'écran change de scène deux fois.
	if identifiant > 0 and identifiant == lobby:
		return
	if retour != 1 or identifiant <= 0:
		Net.quitte()
		_abandonne("Steam n'a pas créé le lobby (code %d)." % retour)
		return
	lobby = identifiant
	_attente = ""
	var steam: Object = SteamApi.api()
	if steam != null and steam.has_method("setLobbyData"):
		# La marque du jeu : l'App ID 480 est partagé par tout le monde, et sans
		# elle on ne distingue pas nos parties de celles des milliers d'autres
		# projets qui développent dessus (D8).
		steam.call("setLobbyData", lobby, CLE_JEU, VALEUR_JEU)
		steam.call("setLobbyData", lobby, "hote", str(SteamApi.mon_id()))
	lobby_change.emit(lobby)
	session_prete.emit()


func _sur_lobby_rejoint(identifiant: int, _permissions: int, _verrouille: bool,
		reponse: int) -> void:
	# Même rappel en double que pour la création, et ici il coûte plus cher :
	# `Net.rejoint()` commence par fermer la session en cours. Rejouer l'entrée
	# dans un lobby déjà rejoint couperait une connexion qui marchait.
	if identifiant > 0 and identifiant == lobby and Net.en_ligne():
		return
	# 1 = k_EChatRoomEnterResponseSuccess. Tout le reste est un refus : lobby
	# plein, partie fermée, joueur banni.
	if reponse != 1:
		_abandonne("Le lobby a refusé l'entrée (code %d)." % reponse)
		return

	var steam: Object = SteamApi.api()
	if steam == null or not steam.has_method("getLobbyOwner"):
		_abandonne("Impossible de savoir qui héberge ce lobby.")
		return
	var hote: int = int(steam.call("getLobbyOwner", identifiant))
	if hote <= 0:
		_abandonne("Ce lobby n'a plus d'hôte.")
		return

	lobby = identifiant
	_attente = ""
	lobby_change.emit(lobby)

	# On est déjà l'hôte : c'est le cas d'une invitation acceptée sur sa propre
	# partie. Rien à rejoindre, et surtout pas soi-même.
	if hote == SteamApi.mon_id():
		session_prete.emit()
		return

	if Net.rejoint(str(hote), Net.PORT_PAR_DEFAUT, SteamApi.mon_nom(),
			SteamTransport.new()):
		session_prete.emit()


## « Rejoindre la partie » depuis la liste d'amis ou l'overlay. On ne bascule pas
## de scène d'autorité : l'invitation attend que le menu vienne la chercher.
func _sur_demande_de_rejoindre(identifiant: int, _ami: int) -> void:
	_invitation = identifiant
	invitation_recue.emit(identifiant)


# ── Détails ───────────────────────────────────────────────────────────────

## Steam peut aussi lancer le jeu pour rejoindre une partie : l'identifiant du
## lobby arrive alors en ligne de commande, avant que le moindre écran existe.
func _recupere_invitation_de_lancement() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for i: int in arguments.size() - 1:
		if arguments[i] == "+connect_lobby":
			_invitation = arguments[i + 1].to_int()
			return


func _verifie_disponible() -> bool:
	if occupe():
		echec.emit("Une connexion Steam est déjà en cours.")
		return false
	var pourquoi: String = indisponible_pourquoi()
	if not pourquoi.is_empty():
		echec.emit(pourquoi)
		return false
	return true


func _attends(quoi: String) -> void:
	_attente = quoi
	_depuis = 0.0


func _abandonne(message: String) -> void:
	_attente = ""
	echec.emit(message)
