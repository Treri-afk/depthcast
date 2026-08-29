extends SceneTree
## Outil ponctuel : convertit les catalogues codés en dur en Resources .tres.
##
##   godot --headless --path . --script tools/generer_contenu.gd
##
## Une fois le contenu généré, il se règle dans l'inspecteur et ce script n'a
## plus lieu d'être relancé — le rejouer ÉCRASERAIT les réglages faits à la main.

const C := SpellEffect.Comportement

const SORTS: Array = [
	# nom, comportement, params
	["braise", "boule_de_feu", "Boule de Feu", C.PROJECTILE,
		{"degats": 14, "portee": 24.0, "cooldown": 0.55}],
	["braise", "mur_de_flammes", "Mur de Flammes", C.MUR,
		{"degats": 7, "largeur": 9.0, "duree": 5.0, "intervalle": 0.4,
		 "distance": 4.5, "cooldown": 5.0}],
	["braise", "trainee_ardente", "Traînée Ardente", C.TRAINEE,
		{"degats": 5, "duree": 6.0, "duree_secondaire": 3.0, "rayon": 1.6,
		 "intervalle": 0.35, "cooldown": 7.0}],

	["givre", "gel", "Gel", C.GEL,
		{"degats": 3, "rayon": 5.5, "duree": 6.0, "intervalle": 0.5,
		 "ralentissement": 0.28, "cooldown": 6.0}],
	["givre", "bise_glaciale", "Bise Glaciale", C.CONE,
		{"degats": 20, "portee": 11.0, "angle": 50.0, "cooldown": 1.6}],
	["givre", "rempart", "Rempart", C.SOIN,
		{"soin": 26, "cooldown": 4.0}],

	["force", "poussee", "Poussée", C.REPULSION,
		{"degats": 6, "rayon": 7.0, "puissance": 26.0, "cooldown": 2.2}],
	["force", "attraction", "Attraction", C.ATTRACTION,
		{"degats": 4, "rayon": 12.0, "puissance": 20.0, "cooldown": 2.6}],
	["force", "ruee", "Ruée", C.DASH,
		{"degats": 18, "distance": 9.0, "rayon": 2.2, "cooldown": 2.0}],

	["vie", "soin", "Soin", C.SOIN,
		{"soin": 34, "cooldown": 5.0}],
	["vie", "siphon", "Siphon", C.DRAIN,
		{"degats": 11, "portee": 20.0, "ratio_soin": 0.8, "cooldown": 0.9}],
	["vie", "invocation", "Invocation", C.TOTEM,
		{"soin": 6, "rayon": 3.2, "duree": 8.0, "intervalle": 0.8, "cooldown": 9.0}],

	["ombre", "pas_d_ombre", "Pas d'Ombre", C.TELEPORT,
		{"portee": 16.0, "cooldown": 2.4}],
	["ombre", "voile", "Voile", C.VOILE,
		{"duree": 4.0, "cooldown": 8.0}],
	["ombre", "leurre", "Leurre", C.LEURRE,
		{"duree": 6.0, "distance": 5.0, "cooldown": 7.0}],
	["ombre", "eclat_nocturne", "Éclat Nocturne", C.PROJECTILE,
		{"degats": 28, "portee": 15.0, "cooldown": 1.6}],
]

const ECOLES: Array = [
	["braise", "Braise", Color(0.98, 0.42, 0.14), "Dégâts et auto-soin instable"],
	["givre", "Givre", Color(0.42, 0.82, 1.0), "Contrôle et défense"],
	["force", "Force", Color(0.92, 0.78, 0.22), "Positionnement et mobilité"],
	["vie", "Vie", Color(0.42, 0.92, 0.48), "Soutien et récupération"],
	["ombre", "Ombre", Color(0.66, 0.44, 0.95), "Évasion et diversion"],
]

const MONSTRES: Array = [
	["rodeur", "Rôdeur", Color(0.78, 0.32, 0.36), Vector3(1.1, 1.5, 1.1),
		{"pv": 30, "degats": 7, "resonance": 12, "portee_frappe": 2.0,
		 "vitesse": 4.2, "distance_garde": 5.5, "delai_assaut": 2.4,
		 "duree_assaut": 0.45, "duree_repli": 0.7}],
	["brute", "Brute", Color(0.62, 0.24, 0.22), Vector3(1.9, 2.4, 1.9),
		{"pv": 78, "degats": 17, "resonance": 26, "portee_frappe": 2.6,
		 "vitesse": 2.1, "distance_garde": 0.0, "delai_assaut": 1.6,
		 "duree_assaut": 0.0, "duree_repli": 0.0}],
	["rodeuse_ailee", "Rôdeuse ailée", Color(0.55, 0.45, 0.85), Vector3(1.0, 0.8, 1.0),
		{"pv": 22, "degats": 9, "resonance": 18, "portee_frappe": 16.0,
		 "vitesse": 3.6, "distance_garde": 11.0, "delai_assaut": 2.0,
		 "duree_assaut": 0.0, "duree_repli": 0.0,
		 "vole": true, "hauteur_vol": 3.4, "tire": true}],
]


func _init() -> void:
	var par_ecole: Dictionary = {}

	for entree: Array in SORTS:
		var effet := SpellEffect.new()
		effet.nom = entree[2]
		effet.comportement = entree[3]
		for cle: String in (entree[4] as Dictionary):
			effet.set(cle, entree[4][cle])
		var chemin: String = "res://resources/spells/%s.tres" % entree[1]
		_sauve(effet, chemin)
		if not par_ecole.has(entree[0]):
			par_ecole[entree[0]] = []
		par_ecole[entree[0]].append(load(chemin))

	for entree: Array in ECOLES:
		var ecole := School.new()
		ecole.id = StringName(entree[0])
		ecole.nom = entree[1]
		ecole.couleur = entree[2]
		ecole.identite = entree[3]
		var liste: Array[SpellEffect] = []
		for e: SpellEffect in par_ecole.get(entree[0], []):
			liste.append(e)
		ecole.effets = liste
		_sauve(ecole, "res://resources/schools/%s.tres" % entree[0])
		print("  école %s : pool de %d" % [entree[1], liste.size()])

	for entree: Array in MONSTRES:
		var stats := MonsterStats.new()
		stats.id = StringName(entree[0])
		stats.nom = entree[1]
		stats.couleur = entree[2]
		stats.taille = entree[3]
		for cle: String in (entree[4] as Dictionary):
			stats.set(cle, entree[4][cle])
		_sauve(stats, "res://resources/monsters/%s.tres" % entree[0])

	_sauve(Tuning.new(), "res://resources/tuning.tres")
	print("Contenu généré.")
	quit()


func _sauve(res: Resource, chemin: String) -> void:
	var code: int = ResourceSaver.save(res, chemin)
	if code != OK:
		printerr("échec sur %s (code %d)" % [chemin, code])
