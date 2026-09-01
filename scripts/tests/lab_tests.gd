class_name LabTests
extends TestSuite
## Souffle, mobilier et terrain d'essai.
##
## Le souffle est du calcul pur : atténuation et direction se vérifient sans
## moteur, et ce sont exactement les deux choses qu'on casserait sans s'en
## apercevoir en retouchant le ressenti d'une explosion.


func nom() -> String:
	return "Souffle, mobilier et terrain d'essai"


func execute() -> void:
	_check_souffle()
	_check_mobilier()
	_check_tonneaux()
	_check_vigilance()
	_check_portage()
	_check_postes()
	_check_reglages()


func _check_souffle() -> void:
	print("Souffle — atténuation et direction")

	var onde := Souffle.new(Vector3.ZERO, 10.0, 20.0)

	verifie("au centre, la puissance est entière",
		is_equal_approx(onde.attenuation(Vector3.ZERO), 1.0))
	verifie("elle décroît avec la distance",
		onde.attenuation(Vector3(3, 0, 0)) > onde.attenuation(Vector3(7, 0, 0)))
	verifie("elle est nulle au-delà du rayon",
		is_zero_approx(onde.attenuation(Vector3(11, 0, 0))))
	# Un souffle qui s'annule exactement sur son cercle donne une frontière que
	# le joueur apprend par cœur : au bord il reste de quoi être bousculé.
	verifie("elle ne s'annule pas juste avant le bord",
		onde.attenuation(Vector3(9.9, 0, 0)) > 0.1)

	verifie("il pousse vers l'extérieur",
		onde.sens_vers(Vector3(4, 0, 0)).is_equal_approx(Vector3.RIGHT))
	# Sans ce cas particulier, une nova sous ses propres pieds serait décorative.
	verifie("au centre exact, il soulève au lieu de pousser",
		onde.sens_vers(Vector3(0, 0, 0)).is_equal_approx(Vector3.UP))
	verifie("la projection reste horizontale ailleurs",
		is_zero_approx(onde.sens_vers(Vector3(4, 3, 0)).y))

	var aspiration := Souffle.new(Vector3.ZERO, 10.0, 20.0, true)
	verifie("l'aspiration est le même souffle en sens inverse",
		aspiration.sens_vers(Vector3(4, 0, 0)).is_equal_approx(Vector3.LEFT))

	# Épargner le lanceur ne doit épargner QUE lui : le décor part quand même.
	var epargnant := Souffle.new(Vector3.ZERO, 10.0, 20.0)
	epargnant.epargne_le_lanceur = true
	verifie("épargner le lanceur ne change pas l'atténuation",
		is_equal_approx(epargnant.attenuation(Vector3(5, 0, 0)),
			onde.attenuation(Vector3(5, 0, 0))))
	epargnant.sur_joueur(null, Content.tuning)
	verifie("un souffle sans joueur ne plante pas", true)


func _check_mobilier() -> void:
	print("Mobilier — une caisse est une caisse partout")

	var masses: Array[float] = []
	for genre: int in [PropFactory.Genre.CAISSE, PropFactory.Genre.TONNEAU,
			PropFactory.Genre.TABLE]:
		var corps := PropFactory.cree(genre, Vector3.ZERO)
		verifie("%s : ses points de vie suivent sa masse" % PropFactory.nom(genre),
			corps.pv == int(corps.mass * 2.2), "pv=%d masse=%.1f" % [corps.pv, corps.mass])
		verifie("%s : il repose sur le sol, pas dedans" % PropFactory.nom(genre),
			corps.position.y > 0.0)
		verifie("%s : sa couleur vient de la palette" % PropFactory.nom(genre),
			corps.couleur == PropFactory.couleur(genre))
		masses.append(corps.mass)
		corps.free()

	verifie("une table est plus lourde qu'un tonneau, lui-même plus qu'une caisse",
		masses[0] < masses[1] and masses[1] < masses[2], str(masses))


func _check_tonneaux() -> void:
	print("Tonneaux explosifs")

	var t: Tuning = Content.tuning
	var baril := PropFactory.cree(PropFactory.Genre.TONNEAU_EXPLOSIF, Vector3.ZERO)
	var ordinaire := PropFactory.cree(PropFactory.Genre.TONNEAU, Vector3.ZERO)

	verifie("un tonneau explosif est bien un ExplosiveProp", baril is ExplosiveProp)
	# Il doit partir au premier projectile : un baril qu'il faut viser trois
	# fois n'est plus une opportunité, c'est une corvée.
	verifie("il est plus fragile qu'un tonneau ordinaire", baril.pv < ordinaire.pv,
		"%d contre %d" % [baril.pv, ordinaire.pv])
	verifie("il se repère : sa couleur sort de la gamme du décor",
		baril.couleur == Content.palette.tonneau_explosif)

	# LA règle qui décide si une rangée part en chaîne ou s'arrête au premier.
	verifie("un tonneau en fait sauter un autre — les dégâts de décor le tuent",
		t.tonneau_degats_decor > baril.pv,
		"%d contre %d pv" % [t.tonneau_degats_decor, baril.pv])
	# Courte mais jamais nulle : sans mèche, une rangée part en une frame et on
	# ne voit qu'un flash.
	verifie("la mèche existe", t.tonneau_meche > 0.0)
	verifie("et elle reste courte", t.tonneau_meche <= 1.0)
	verifie("le rayon dépasse largement la taille du tonneau", t.tonneau_rayon > 2.0)

	# Activer dans la main : c'est le seul endroit où un objet décide de son
	# propre usage, et il doit ANNONCER cet usage avant qu'on appuie.
	verifie("un tonneau propose d'allumer sa mèche",
		baril.libelle_activation() != "")
	var dit: String = (baril as ExplosiveProp).active_par(null)
	verifie("et l'allumer dit ce qui se passe", dit != "", dit)
	# Rallumer une mèche déjà allumée ne la raccourcit pas et ne la double pas.
	verifie("rallumer ne fait plus rien", (baril as ExplosiveProp).active_par(null) == "")
	verifie("et l'objet cesse de le proposer", baril.libelle_activation() == "")

	var simple := PropFactory.cree(PropFactory.Genre.CAISSE, Vector3.ZERO)
	# Une caisse n'a rien à activer, et elle ne doit rien proposer : une invite
	# qui ne fait rien est pire que pas d'invite du tout.
	verifie("une caisse ne propose rien", simple.libelle_activation() == ""
		and simple.active_par(null) == "")
	simple.free()

	# Le câblage Tuning → tonneau. C'est ce qui casse en silence le jour où l'on
	# règle une valeur dans l'inspecteur sans qu'elle arrive jusqu'au baril.
	var explosif := baril as ExplosiveProp
	verifie("son rayon vient du Tuning", is_equal_approx(explosif.rayon, t.tonneau_rayon))
	verifie("sa puissance aussi",
		is_equal_approx(explosif.puissance, t.tonneau_puissance))
	verifie("ses dégâts aussi", explosif.degats == t.tonneau_degats)
	verifie("sa mèche aussi", is_equal_approx(explosif.meche, t.tonneau_meche))

	baril.free()
	ordinaire.free()


func _check_vigilance() -> void:
	print("Vigilance — remarquer une mèche et s'en écarter")

	var t: Tuning = Content.tuning
	var rodeur: MonsterStats = Content.monstre(&"rodeur")
	var brute: MonsterStats = Content.monstre(&"brute")

	# LA condition qui rend toute la mécanique possible. Si la mèche est plus
	# courte que le temps de réaction, le tonneau saute avant que personne ait
	# eu le temps de le remarquer, et la vigilance ne sert strictement à rien.
	verifie("la mèche dure plus longtemps que le temps de réaction",
		t.tonneau_meche > rodeur.temps_de_reaction,
		"%.2f s contre %.2f s" % [t.tonneau_meche, rodeur.temps_de_reaction])

	# Fuir doit améliorer ses chances, pas la sauver : sinon les tonneaux ne
	# tuent plus rien et deviennent décoratifs.
	var course: float = rodeur.vitesse * t.vigilance_vitesse_de_fuite \
		* (t.tonneau_meche - rodeur.temps_de_reaction)
	verifie("mais pas assez pour sortir du rayon", course < t.tonneau_rayon,
		"%.1f m parcourus pour un rayon de %.1f" % [course, t.tonneau_rayon])

	var peureux := ThreatSense.new(rodeur, t.vigilance_duree_de_fuite)
	var pos := Vector3(2, 0, 0)
	peureux.signale(Vector3.ZERO, 6.0, pos)
	verifie("un rôdeur remarque une mèche proche",
		peureux.etat == ThreatSense.Etat.REMARQUE)

	var brave := ThreatSense.new(brute, t.vigilance_duree_de_fuite)
	brave.signale(Vector3.ZERO, 6.0, pos)
	verifie("une brute ne recule devant rien", brave.etat == ThreatSense.Etat.CALME)

	var sourd := ThreatSense.new(rodeur, t.vigilance_duree_de_fuite)
	sourd.signale(Vector3.ZERO, 6.0, Vector3(30, 0, 0))
	verifie("une mèche hors de portée ne regarde personne",
		sourd.etat == ThreatSense.Etat.CALME)

	var compris: Array[bool] = [false]
	peureux.remarque.connect(func() -> void: compris[0] = true)

	# À mi-parcours : l'attention est visible, mais rien n'a encore bougé. C'est
	# précisément la fenêtre laissée au joueur.
	peureux.avance(rodeur.temps_de_reaction * 0.5, pos)
	verifie("l'attention se voit avant d'être pleine",
		peureux.progression() > 0.2 and peureux.progression() < 0.9,
		"%.2f" % peureux.progression())
	verifie("et la créature n'a pas encore réagi",
		not compris[0] and peureux.etat == ThreatSense.Etat.REMARQUE)

	peureux.avance(rodeur.temps_de_reaction, pos)
	verifie("elle finit par comprendre", compris[0])
	var direction: Vector3 = peureux.avance(0.05, pos)
	verifie("puis s'écarte de la menace, pas d'autre chose",
		direction.is_equal_approx(Vector3.RIGHT), str(direction))

	peureux.avance(t.vigilance_duree_de_fuite + 0.1, pos)
	verifie("et se calme une fois le danger passé",
		peureux.etat == ThreatSense.Etat.CALME)


func _check_portage() -> void:
	print("Portage, balise et permutation")

	var t: Tuning = Content.tuning

	# Ce qui se porte doit tenir dans les bras : une table qu'on transporte
	# ferait mentir la silhouette du joueur sur ce qu'il a en main.
	var portables: Dictionary = {
		PropFactory.Genre.CAISSE: true,
		PropFactory.Genre.TONNEAU: true,
		PropFactory.Genre.TONNEAU_EXPLOSIF: true,
		PropFactory.Genre.BALISE_LEURRE: true,
		PropFactory.Genre.TABLE: false,
	}
	for genre: int in portables:
		var corps := PropFactory.cree(genre, Vector3.ZERO)
		verifie("%s : portable = %s" % [PropFactory.nom(genre), portables[genre]],
			corps.portable == portables[genre])
		corps.free()

	# Porter DOIT coûter. Sans coût, porter est gratuit et il n'y a aucune
	# décision entre traverser vite et traverser armé.
	verifie("porter ralentit", t.portage_ralentissement < 1.0)
	verifie("et lancer envoie quelque part", t.portage_force_de_lancer > 0.0)

	# Le même bouton, deux gestes : une pression brève POSE, un maintien LANCE.
	# Si les deux extrémités se ressemblent, personne ne découvrira la charge.
	var bref: float = PlayerAvatar.part_de_charge(0.0, t)
	var plein: float = PlayerAvatar.part_de_charge(t.portage_charge_duree, t)
	verifie("une pression brève pose l'objet devant soi", bref < 0.5,
		"%.2f de la force" % bref)
	verifie("un maintien complet l'envoie à pleine force",
		is_equal_approx(plein, 1.0))
	verifie("et l'écart entre les deux se sent", plein > bref * 2.0,
		"%.2f contre %.2f" % [plein, bref])
	# Au-delà du temps de charge on ne gagne plus rien : une charge sans plafond
	# récompense la patience plutôt que la décision.
	verifie("charger plus longtemps n'ajoute rien",
		is_equal_approx(PlayerAvatar.part_de_charge(t.portage_charge_duree * 4.0, t),
			plein))

	var balise := PropFactory.cree(PropFactory.Genre.BALISE_LEURRE, Vector3.ZERO)
	verifie("la balise de leurre est bien une LureBeacon", balise is LureBeacon)
	var caisse := PropFactory.cree(PropFactory.Genre.CAISSE, Vector3.ZERO)
	# Légère, donc elle part loin : une balise qu'on ne peut poser qu'à ses
	# pieds ne détourne rien de dangereux.
	verifie("elle est plus légère qu'une caisse, donc elle vole plus loin",
		balise.mass < caisse.mass, "%.1f contre %.1f" % [balise.mass, caisse.mass])
	verifie("son rayon d'appel vient du Tuning",
		is_equal_approx((balise as LureBeacon).rayon, t.leurre_rayon))
	balise.free()
	caisse.free()

	# La diversion et son retour sont tenus par le monstre : le sort de leurre
	# et la balise en objet obtiennent le même comportement sans partager une
	# seule ligne.
	var faux_leurre := Node3D.new()
	var bestiole := MonsterAvatar.new()
	bestiole.stats = Content.monstre(&"rodeur")
	bestiole.distrait_par(faux_leurre, 3.0)
	verifie("une balise détourne l'attention", bestiole.cible == faux_leurre)
	bestiole.distrait_par(null, 3.0)
	verifie("mais pas vers rien du tout", bestiole.cible == faux_leurre)
	bestiole.free()
	faux_leurre.free()

	# Permutation : une Resource, une ligne de registre, et le pool d'Ombre
	# reste dans les bornes du GDD.
	var ombre: School = Content.ecole(&"ombre")
	var noms: Array = []
	for effet: SpellEffect in ombre.effets:
		noms.append(effet.nom)
	verifie("Permutation est entrée dans le pool d'Ombre", noms.has("Permutation"),
		str(noms))
	verifie("et le pool reste dans les bornes du GDD",
		ombre.taille_pool() >= School.POOL_MIN and ombre.taille_pool() <= School.POOL_MAX,
		"%d effets" % ombre.taille_pool())

	verifie("les souffles poussent les alliés", t.souffle_pousse_les_allies)


func _check_postes() -> void:
	print("Terrain d'essai — les postes")

	var postes: Array[LabStation] = [DummyStation.new(), BlastStation.new(),
		PropsStation.new(), RerollStation.new(), RangeStation.new()]
	for poste: LabStation in postes:
		verifie("un poste s'annonce : %s" % poste.titre(),
			poste.titre() != "" and poste.titre() != "Poste")
		poste.free()

	# Le cran d'arrêt en tête : la fosse doit pouvoir se taire.
	verifie("la fosse aux explosions a un cran d'arrêt",
		float(BlastStation.CRANS[0]["puissance"]) == 0.0)
	verifie("ses crans montent en puissance",
		float(BlastStation.CRANS[1]["puissance"])
			< float(BlastStation.CRANS[3]["puissance"]))
	verifie("l'étal mélange les masses — sinon un souffle ne compare rien",
		_genres_de_l_etal().size() >= 3, str(_genres_de_l_etal()))
	verifie("et il porte de quoi essayer une chaîne d'explosions",
		_genres_de_l_etal().has(PropFactory.Genre.TONNEAU_EXPLOSIF))


func _check_reglages() -> void:
	print("Réglages de projection")

	var t: Tuning = Content.tuning
	verifie("le seuil de projection est non nul — sinon tout souffle décolle",
		t.souffle_seuil_projection > 0.0)
	verifie("la vitesse est plafonnée", t.projection_vitesse_max > 0.0)
	verifie("un garde-fou borne la projection — on ne reste jamais coincé",
		t.projection_duree_max > 0.0 and t.projection_duree_max <= 20.0)
	# Bien plus faible que le freinage normal : un corps projeté garde sa
	# trajectoire, il ne freine pas en l'air.
	verifie("on ne freine pas en vol",
		t.projection_amortissement < t.freinage_joueur)

	# Le vol dure ce qu'il dure — jusqu'à l'atterrissage. C'est le RELEVÉ, une
	# fois à terre, qui se paie en secondes proportionnelles à la violence.
	var doux: float = PlayerAvatar.duree_de_releve(6.0, t)
	var brutal: float = PlayerAvatar.duree_de_releve(40.0, t)
	verifie("un gros souffle laisse à terre plus longtemps qu'un petit",
		brutal > doux, "%.2f s contre %.2f s" % [brutal, doux])
	verifie("même le plus faible laisse une trace", doux >= t.projection_releve_min)
	verifie("et le plus violent reste borné",
		PlayerAvatar.duree_de_releve(9999.0, t) == t.projection_releve_max)
	verifie("perdre la main fait partie du contrat",
		t.projection_bloque_les_sorts)

	# La verticale est bornée, l'horizontale ne l'est pas : on part loin, pas
	# haut. Au-dessus des murs, on quitte le décor.
	var sommet: float = Souffle.vitesse_pour_culminer_a(
		t.projection_hauteur_max, t.gravite)
	verifie("la projection ne dépasse pas la hauteur des murs",
		t.projection_hauteur_max < t.hauteur_mur,
		"%.1f m contre %.1f m" % [t.projection_hauteur_max, t.hauteur_mur])
	verifie("et elle décolle quand même franchement", sommet > t.impulsion_saut,
		"%.1f m/s contre un saut à %.1f" % [sommet, t.impulsion_saut])
	# Un rôdeur qui part à quinze mètres n'est plus une réaction, c'est un gag.
	verifie("un monstre décolle bien moins haut que le joueur",
		t.souffle_hauteur_max_monstres < t.projection_hauteur_max,
		"%.1f m contre %.1f m" % [t.souffle_hauteur_max_monstres,
			t.projection_hauteur_max])

func _genres_de_l_etal() -> Array:
	var vus: Array = []
	for modele: Dictionary in PropsStation.ETAL:
		if not vus.has(modele["genre"]):
			vus.append(modele["genre"])
	return vus
