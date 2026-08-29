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
