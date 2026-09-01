class_name DebugTests
extends TestSuite
## Les outils de développement se vérifient comme le reste.
##
## Ce n'est pas du zèle : un outil de débogage faux est pire que pas d'outil.
## Une graine qui n'est pas vraiment rejouée, un compteur qui oublie un étage,
## et on passe la journée à chercher un bug de jeu dans un bug d'outil.


func nom() -> String:
	return "Outils — console, rejeu par graine, télémétrie"


func execute() -> void:
	_check_rejeu()
	_check_historique()
	_check_telemetrie()
	_check_console()


# ── Rejeu ─────────────────────────────────────────────────────────────────

func _check_rejeu() -> void:
	print("Une graine forcée passe devant toutes les autres")
	var memoire: Array[int] = Rejeu.historique.duplicate()
	Rejeu.libere()

	verifie("sans contrainte, rien n'est forcé", not Rejeu.actif())
	verifie("et la graine proposée passe telle quelle",
		Rejeu.graine_a_utiliser(1234) == 1234)

	Rejeu.force(4242)
	verifie("une fois forcée, elle l'emporte sur le salon",
		Rejeu.graine_a_utiliser(1234) == 4242)
	verifie("y compris sur le tirage au sort du solo",
		Rejeu.graine_a_utiliser(0) == 4242)

	Rejeu.libere()
	verifie("la libérer rend la main au hasard",
		Rejeu.graine_a_utiliser(77) == 77)

	Rejeu.historique.assign(memoire)


func _check_historique() -> void:
	print("L'historique retient les runs sans les répéter")
	var memoire: Array[int] = Rejeu.historique.duplicate()
	Rejeu.historique.clear()

	EventBus.run_started.emit(11)
	EventBus.run_started.emit(22)
	verifie("la dernière jouée est en tête", Rejeu.precedente(0) == 22)
	verifie("et l'avant-dernière juste derrière", Rejeu.precedente(1) == 11)

	EventBus.run_started.emit(11)
	verifie("rejouer une graine la remonte au lieu de la dupliquer",
		Rejeu.historique.size() == 2 and Rejeu.precedente(0) == 11)
	verifie("un rang hors de portée ne plante pas",
		Rejeu.precedente(99) == 0 and Rejeu.precedente(-1) == 0)

	for i: int in Rejeu.MEMOIRE * 2:
		EventBus.run_started.emit(1000 + i)
	verifie("la mémoire est bornée", Rejeu.historique.size() == Rejeu.MEMOIRE)

	Rejeu.historique.assign(memoire)


# ── Télémétrie ────────────────────────────────────────────────────────────

func _check_telemetrie() -> void:
	print("La télémétrie compte par étage, pas en vrac")
	Telemetrie.enregistre = true
	Telemetrie.ecriture_auto = false
	Telemetrie.remet_a_zero()

	GameState.start_run(31415, 1)
	verifie("une run ouverte est une run enregistrée", Telemetrie.en_cours())

	EventBus.player_damaged.emit(0, 12, Vector3.ZERO)
	EventBus.monster_died.emit(1, 0, 5)
	EventBus.floor_entered.emit(1)
	EventBus.player_damaged.emit(0, 30, Vector3.ZERO)

	var rapport: Dictionary = Telemetrie.rapport()
	var etages: Array = rapport["etages"]
	verifie("la graine part avec le rapport", int(rapport["graine"]) == 31415)
	verifie("chaque étage traversé laisse une ligne", etages.size() == 2,
		"trouvé %d" % etages.size())
	verifie("les dégâts restent dans l'étage où ils sont tombés",
		int((etages[0] as Dictionary).get("degats_subis", 0)) == 12
		and int((etages[1] as Dictionary).get("degats_subis", 0)) == 30)
	verifie("les morts et la Résonance suivent le même chemin",
		int((etages[0] as Dictionary).get("monstres_tues", 0)) == 1
		and int((etages[0] as Dictionary).get("resonance_gagnee", 0)) == 5)

	Telemetrie.marque("ici")
	var marques: int = 0
	for e: Dictionary in Telemetrie.rapport()["evenements"]:
		if e.get("genre", "") == "marque":
			marques += 1
	verifie("une marque posée à la main se retrouve dans le journal", marques == 1)

	verifie("le résumé lisible parle de la run",
		"\n".join(Telemetrie.lignes()).contains("31415"))

	# Le fichier est le produit fini : un rapport qui ne se relit pas n'a servi
	# à rien, et c'est le genre de panne qu'on ne découvre qu'au moment où on
	# en a besoin. On l'écrit vraiment, on le relit, et on le retire.
	var chemin: String = Telemetrie.ecrit()
	verifie("le rapport s'écrit sur le disque", chemin != "")
	var relu: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(Telemetrie.DOSSIER.path_join(
			chemin.get_file())))
	verifie("et se relit tel qu'il a été écrit",
		relu is Dictionary and int((relu as Dictionary).get("graine", 0)) == 31415)
	DirAccess.remove_absolute(Telemetrie.DOSSIER.path_join(chemin.get_file()))

	Telemetrie.remet_a_zero()
	verifie("la remise à zéro efface tout", not Telemetrie.en_cours()
		and (Telemetrie.rapport()["etages"] as Array).is_empty())

	Telemetrie.enregistre = false
	GameState.start_run(1, 1)
	verifie("coupée, elle n'enregistre plus rien", not Telemetrie.en_cours())
	Telemetrie.enregistre = OS.is_debug_build()
	Telemetrie.ecriture_auto = true


# ── Console ───────────────────────────────────────────────────────────────

func _check_console() -> void:
	print("La console répond, et refuse ce qu'elle ne connaît pas")
	verifie("elle est disponible en build de développement",
		Console.disponible() == OS.is_debug_build())
	verifie("elle démarre fermée", not Console.ouverte())

	var aide: String = Console.execute("aide")
	verifie("l'aide liste les commandes", aide.contains("graine")
		and aide.contains("tel") and aide.contains("etat"))
	verifie("une commande inconnue est refusée, pas ignorée",
		Console.execute("bidule").contains("inconnue"))
	verifie("une ligne vide ne fait rien", Console.execute("   ") == "")

	var memoire: int = Rejeu.graine_forcee
	Console.execute("graine 909")
	verifie("`graine <n>` force bien la graine", Rejeu.graine_forcee == 909)
	Console.execute("graine libre")
	verifie("`graine libre` la relâche", not Rejeu.actif())
	verifie("un argument non entier est refusé",
		Console.execute("graine abc").contains("entier"))
	Rejeu.force(memoire)

	var vitesse: float = Engine.time_scale
	Console.execute("vitesse 0.5")
	verifie("`vitesse` agit sur l'échelle de temps",
		is_equal_approx(Engine.time_scale, 0.5))
	verifie("et reste dans des bornes tenables",
		Console.execute("vitesse 999").contains("8.00"))
	Engine.time_scale = vitesse

	# Hors run, aucune commande d'état ne doit planter : c'est exactement là
	# qu'on tape au hasard, depuis le menu, en cherchant quoi faire.
	GameState.run = null
	verifie("hors run, `etat` répond au lieu de planter",
		Console.execute("etat").contains("hors run"))
	verifie("hors run, `sorts` dit ce qui manque",
		Console.execute("sorts").contains("run"))
	verifie("hors run, `etage` refuse", Console.execute("etage").contains("run"))
	verifie("`net` répond toujours", not Console.execute("net").is_empty())
