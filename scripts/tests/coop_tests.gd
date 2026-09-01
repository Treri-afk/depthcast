class_name CoopTests
extends TestSuite
## Co-op — ce que l'état doit garantir avant qu'un seul octet ne circule.
##
## Le réseau n'est pas branché, et c'est justement pour ça que ces
## vérifications existent maintenant : elles portent sur des propriétés que le
## netcode SUPPOSERA, et qu'il est bien plus coûteux de découvrir fausses une
## fois les paquets en vol.


func nom() -> String:
	return "Co-op — état partagé et flux indépendants"


func execute() -> void:
	_check_joueur_local()
	_check_etat_partage()
	_check_flux_independants()
	_check_session_hors_ligne()
	_check_chute_et_releve()
	_check_reprise()
	_check_transport_steam()


## Le joueur local est une notion de CLIENT, pas de partie. Deux machines qui
## jouent la même run avec des `local_player_id` différents doivent produire
## exactement le même état sérialisé — sinon toute comparaison host/client
## devient inutilisable, et avec elle toute détection de divergence.
func _check_joueur_local() -> void:
	print("Le joueur local ne fait pas partie de la run")

	GameState.start_run(4242, 3)
	GameState.local_player_id = 0
	var vu_du_host: Dictionary = GameState.serialize()

	GameState.local_player_id = 2
	var vu_du_client: Dictionary = GameState.serialize()

	verifie("changer de joueur local ne change pas l'état sérialisé",
		vu_du_host == vu_du_client)
	verifie("mais il désigne bien quelqu'un d'autre",
		GameState.local_player().player_id == 2)
	verifie("et il sait qui il est", GameState.est_local(2)
		and not GameState.est_local(0))

	GameState.local_player_id = 0


func _check_etat_partage() -> void:
	print("Trois joueurs, un seul pot")

	GameState.start_run(7, 3)
	verifie("trois joueurs enregistrés", GameState.run.players.size() == 3)

	var ids: Array = []
	for p: PlayerState in GameState.run.players:
		ids.append(p.player_id)
	verifie("aux identifiants distincts", ids.size() == ids.duplicate().size()
		and not ids.has(null), str(ids))

	# D3 : la Résonance est COMMUNE. Ce qu'un joueur dépense, les autres ne
	# l'ont plus — c'est la première source de friction du co-op, et elle doit
	# être vraie dans l'état avant d'être vraie à l'écran.
	GameState.add_resonance(100)
	verifie("le pot est commun", GameState.run.resonance_pool == 100)
	verifie("le joueur 2 peut y puiser", GameState.try_spend_resonance(2, 40))
	verifie("et le joueur 0 n'a plus que le reste",
		GameState.run.resonance_pool == 60, "%d" % GameState.run.resonance_pool)
	verifie("personne ne dépense ce qui n'y est pas",
		not GameState.try_spend_resonance(1, 999))

	# Q1 reste ouverte : les deux compteurs sont maintenus, un seul servira.
	GameState.add_resonance(500)
	GameState.try_lock_slot(1, 0, 10)
	var joueur_1: PlayerState = GameState.run.get_player(1)
	verifie("le compteur de sceaux par joueur avance",
		joueur_1.locks_bought_this_floor == 1)
	verifie("celui de l'équipe aussi — Q1 n'est pas tranchée",
		GameState.run.team_locks_this_floor == 1)
	verifie("et celui d'un autre joueur reste à zéro",
		GameState.run.get_player(2).locks_bought_this_floor == 0)


## D4 : chacun son aléatoire. Deux joueurs qui descendent au même étage ne
## doivent pas tirer le même sort — sinon le co-op devient un solo à plusieurs,
## et la composition d'équipe ne veut plus rien dire.
func _check_flux_independants() -> void:
	print("Chacun son aléatoire")

	GameState.start_run(999, 2)
	var tirages_0: Array[int] = []
	var tirages_1: Array[int] = []
	for i: int in 8:
		tirages_0.append(RngService.player_stream(RngService.STREAM_REROLL, 0).randi_range(0, 99))
		tirages_1.append(RngService.player_stream(RngService.STREAM_REROLL, 1).randi_range(0, 99))

	verifie("deux joueurs ne tirent pas la même suite", tirages_0 != tirages_1,
		"%s vs %s" % [str(tirages_0), str(tirages_1)])

	# Et la même seed doit redonner la même suite : c'est ce qui rend une run
	# rejouable, et ce qui permettra de comparer host et client.
	GameState.start_run(999, 2)
	var rejoue: Array[int] = []
	for i: int in 8:
		rejoue.append(RngService.player_stream(RngService.STREAM_REROLL, 0).randi_range(0, 99))
	verifie("mais la même seed redonne la même suite", rejoue == tirages_0,
		"%s vs %s" % [str(rejoue), str(tirages_0)])


## Le solo ne doit JAMAIS être un cas particulier du multijoueur.
##
## Hors ligne, la session répond comme une partie à un joueur dont on est le
## host : le code de gameplay n'a donc jamais à demander « y a-t-il un réseau ? »
## avant de décider s'il a le droit d'agir. Le jour où cette propriété se
## casse, c'est le mode solo qui se casse — sans que rien ne le signale.
func _check_session_hors_ligne() -> void:
	print("Hors ligne, la session répond en solo")

	verifie("aucune partie en ligne au démarrage", not Net.en_ligne())
	verifie("on est son propre host", Net.est_host())
	verifie("un seul joueur", Net.nombre_de_joueurs() == 1)
	var ids: Array[int] = Net.joueurs()
	verifie("qui porte l'identifiant 0", ids.size() == 1 and ids[0] == 0, str(ids))
	verifie("la graine vaut zéro — la run en tirera une",
		Net.graine == 0)
	# La graine meurt avec la session : sinon une partie solo lancée après avoir
	# quitté un salon rejoue le donjon précédent, à l'identique, jusqu'au
	# redémarrage du jeu.
	Net.graine = 12345
	Net.quitte()
	verifie("et elle meurt avec la session", Net.graine == 0)
	# Le plafond vient du transport, qui ouvre les connexions : deux plafonds
	# différents laisseraient entrer un joueur que le jeu ne saurait pas placer.
	verifie("le plafond de joueurs est celui du transport",
		Net.JOUEURS_MAX == NetTransport.JOUEURS_MAX and Net.JOUEURS_MAX == 4)

	# Le transport est interchangeable (R9) : c'est ce qui permet de jouer en
	# local aujourd'hui et de passer par Steam à la sortie, sans toucher au jeu.
	var enet := EnetTransport.new()
	verifie("le transport local s'annonce", enet.nom() != "aucun")
	verifie("et il sait dire où le joindre", enet.adresse_affichable() != "")
	verifie("il dérive bien de l'abstraction", enet is NetTransport)


## Le transport Steam, vérifié SANS Steam.
##
## C'est tout l'enjeu de R9 : le jour où l'extension n'est pas installée — sur
## la CI, sur la machine d'un artiste, sur celle d'un développeur qui n'a pas
## lancé le client — le jeu doit s'ouvrir, tourner, et refuser proprement.
## Une intégration Steam qui empêche d'ouvrir le projet a cassé plus de choses
## qu'elle n'en apporte.
func _check_transport_steam() -> void:
	print("Steam se branche par-dessus, et son absence est un refus poli")

	var steam := SteamTransport.new()
	verifie("il dérive de l'abstraction, comme ENet", steam is NetTransport)
	verifie("et il s'annonce sous son nom", steam.nom() == "Steam")
	verifie("le plafond de joueurs reste celui du jeu",
		NetTransport.JOUEURS_MAX == 4)

	# Une IP n'est pas un SteamID. Sans ce refus, `to_int()` transformerait
	# « 192.168.1.4 » en 192 et on tenterait d'ouvrir une session vers un
	# identifiant qui n'a jamais existé — avec un échec illisible à la clé.
	verifie("une adresse IP n'est pas acceptée comme identifiant Steam",
		steam.rejoint("192.168.1.4", 27015) == null)
	verifie("et le refus s'explique", not steam.derniere_erreur.is_empty(),
		steam.derniere_erreur)

	# Le reste ne se vérifie que sur une machine sans Steam. Sur un poste où
	# l'extension est installée ET le client lancé, ces chemins-là s'essaient à
	# la main, dans un export — l'overlay ne répond pas depuis l'éditeur (D9).
	if SteamNet.disponible():
		verifie("Steam est disponible : le lobby sait le dire",
			SteamNet.indisponible_pourquoi().is_empty())
		return

	verifie("sans Steam, le lobby dit non", not SteamNet.disponible())
	verifie("et il dit pourquoi, en une phrase affichable",
		not SteamNet.indisponible_pourquoi().is_empty(),
		SteamNet.indisponible_pourquoi())

	var motifs: Array[String] = []
	var ecoute: Callable = func(message: String) -> void: motifs.append(message)
	SteamNet.echec.connect(ecoute)
	SteamNet.heberge()
	verifie("héberger sans Steam échoue", motifs.size() == 1, str(motifs))
	# Le point qui compte vraiment : un échec ne doit RIEN laisser derrière lui.
	# Une session ouverte sur un tuyau mort, c'est un salon qui se croit hôte et
	# laisse descendre — chacun jouant alors sa propre partie.
	verifie("et ne laisse aucune session ouverte derrière lui",
		not Net.en_ligne() and Net.etat == Net.Etat.HORS_LIGNE)

	SteamNet.rejoint_le_lobby(0)
	verifie("rejoindre un lobby sans Steam échoue aussi", motifs.size() == 2,
		str(motifs))
	verifie("toujours sans session ouverte", not Net.en_ligne())

	# Le solo, lui, n'a jamais entendu parler de tout ça.
	verifie("et le solo continue de répondre comme avant",
		Net.est_host() and Net.nombre_de_joueurs() == 1)
	SteamNet.echec.disconnect(ecoute)


## Tomber n'est pas mourir, et la relève n'a pas de verbe à elle.
func _check_chute_et_releve() -> void:
	print("À terre — et relevé par un soin")

	GameState.start_run(31, 2)
	var a: PlayerState = GameState.run.get_player(0)
	var b: PlayerState = GameState.run.get_player(1)

	_frappe_joueur(0, a.max_hp + 50)
	verifie("tomber met à terre, pas à zéro joueur", not a.is_alive() and a.hp == 0)
	# LA règle : la run continue tant que quelqu'un tient debout.
	verifie("la run continue tant qu'il reste quelqu'un debout",
		GameState.run.alive_players().size() == 1)

	# N'importe quel soin relève : il n'existe aucun sort de relève, et c'est
	# tout l'intérêt — pouvoir relever dépend de ce que le reroll a donné.
	_soigne_joueur(1, 0, 20)
	verifie("un soin venu d'un coéquipier relève", a.is_alive() and a.hp == 20)

	_frappe_joueur(0, 999)
	_frappe_joueur(1, 999)
	verifie("quand tout le monde est à terre, plus personne ne tient",
		GameState.run.alive_players().is_empty()
			and not a.is_alive() and not b.is_alive())

	# Un soin nul ne ressuscite personne : sinon le moindre effet de zone
	# relèverait toute l'équipe sans que ce soit voulu.
	_soigne_joueur(0, 1, 0)
	verifie("mais un soin nul ne relève pas", not b.is_alive())


func _frappe_joueur(cible: int, degats: float) -> void:
	var intent := EffectIntent.new()
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.source_player_id = -1
	intent.target_ids = PackedInt64Array([cible])
	EffectResolver.submit(intent)
	EffectResolver.resolve_tick()


func _soigne_joueur(soigneur: int, cible: int, montant: float) -> void:
	var intent := EffectIntent.new()
	intent.kind = EffectIntent.Kind.HEAL
	intent.amount = montant
	intent.source_player_id = soigneur
	intent.target_ids = PackedInt64Array([cible])
	EffectResolver.submit(intent)
	EffectResolver.resolve_tick()


## Rejoindre une partie en cours, et y revenir après une coupure.
##
## Personne n'y pense avant la sortie, et c'est précisément ce qui plombe une
## soirée : quelqu'un perd sa connexion et la partie est finie pour lui.
func _check_reprise() -> void:
	print("Reprise — rejoindre une partie déjà commencée")

	GameState.start_run(55, 1)
	verifie("la partie commence seule", GameState.run.players.size() == 1)

	# Un arrivant s'inscrit dans une run déjà ouverte.
	var arrivant: PlayerState = GameState.ajoute_joueur(1, "Tard")
	verifie("un arrivant entre dans la run", arrivant != null
		and GameState.run.players.size() == 2)
	# Il arrive DEBOUT : le punir de l'état d'une partie qu'il n'a pas jouée
	# n'apprendrait rien à personne.
	verifie("et il arrive debout", arrivant.is_alive())

	# Revenir n'est pas arriver : on ne se dédouble pas.
	var encore: PlayerState = GameState.ajoute_joueur(1, "Tard")
	verifie("revenir ne crée pas un second corps",
		GameState.run.players.size() == 2 and encore == arrivant)

	# Et quelqu'un qui s'était fait mettre à terre avant de tomber de la partie
	# revient debout, sinon il rejoint pour ne rien pouvoir faire.
	arrivant.hp = 0
	GameState.ajoute_joueur(1, "Tard")
	verifie("celui qui revient après une coupure se relève",
		GameState.run.get_player(1).is_alive())

	# Hors run, il n'y a rien à rejoindre.
	GameState.end_run(false)
	verifie("hors partie, personne ne rejoint", GameState.ajoute_joueur(2) == null)
