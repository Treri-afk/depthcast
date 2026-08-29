class_name PrototypeCatalogue
extends RefCounted
## Catalogue de contenu du PROTOTYPE. Volontairement en dur, volontairement jetable.
##
## En C2, tout ceci devient des Resources `.tres` éditables dans l'inspecteur.
##
## LA règle de conception, celle qui fait ou défait le jeu (GDD §4) : les effets
## d'une même école doivent être MÉCANIQUEMENT différents, pas des variantes de
## puissance. Si le reroll remplace un projectile par un autre projectile, le
## joueur ne sent rien et le jeu perd son sujet.
##
## Chaque effet ci-dessous a donc son propre comportement. Aucun n'est un
## doublon paramétré d'un autre.

enum Behaviour {
	PROJECTILE,   ## part droit devant, touche le premier monstre
	MUR,          ## nappe persistante posée devant soi, brûle qui la traverse
	TRAINEE,      ## le sol s'embrase sous nos pas pendant un moment
	NOVA,         ## explose autour de soi, une seule fois
	CONE,         ## souffle en éventail devant soi
	GEL,          ## nappe froide au sol : peu de dégâts, gros ralentissement
	REPULSION,    ## repousse violemment tout ce qui est autour
	ATTRACTION,   ## aspire les monstres vers soi
	DASH,         ## charge en avant en traversant et blessant
	TELEPORT,     ## se transporte au point visé, avec aperçu préalable
	SOIN,         ## se soigne
	DRAIN,        ## projectile qui rend une partie des dégâts en soin
	TOTEM,        ## balise posée au sol qui soigne tant qu'on reste dedans
	VOILE,        ## les monstres perdent notre trace
	LEURRE,       ## un mannequin attire les monstres à sa place
}

## Nom lisible par famille, pour le HUD.
const FAMILLES: Dictionary = {
	Behaviour.PROJECTILE: "projectile",
	Behaviour.MUR: "mur persistant",
	Behaviour.TRAINEE: "traînée au sol",
	Behaviour.NOVA: "onde de choc",
	Behaviour.CONE: "souffle conique",
	Behaviour.GEL: "nappe ralentissante",
	Behaviour.REPULSION: "répulsion",
	Behaviour.ATTRACTION: "attraction",
	Behaviour.DASH: "charge",
	Behaviour.TELEPORT: "téléportation",
	Behaviour.SOIN: "soin",
	Behaviour.DRAIN: "vol de vie",
	Behaviour.TOTEM: "totem de soin",
	Behaviour.VOILE: "invisibilité",
	Behaviour.LEURRE: "leurre",
}

const SCHOOLS: Array = [
	{
		"id": &"braise",
		"nom": "Braise",
		"couleur": Color(0.98, 0.42, 0.14),
		"effets": [
			{"nom": "Boule de Feu", "comportement": Behaviour.PROJECTILE,
				"degats": 14, "portee": 24.0, "cooldown": 0.55},
			{"nom": "Mur de Flammes", "comportement": Behaviour.MUR,
				"degats": 7, "largeur": 9.0, "duree": 5.0, "intervalle": 0.4,
				"distance": 4.5, "cooldown": 5.0},
			{"nom": "Traînée Ardente", "comportement": Behaviour.TRAINEE,
				"degats": 5, "duree": 6.0, "duree_flaque": 3.0, "rayon": 1.6,
				"intervalle": 0.35, "cooldown": 7.0},
		],
	},
	{
		"id": &"givre",
		"nom": "Givre",
		"couleur": Color(0.42, 0.82, 1.0),
		"effets": [
			{"nom": "Gel", "comportement": Behaviour.GEL,
				"degats": 3, "rayon": 5.5, "duree": 6.0, "intervalle": 0.5,
				"ralentissement": 0.28, "cooldown": 6.0},
			{"nom": "Bise Glaciale", "comportement": Behaviour.CONE,
				"degats": 20, "portee": 11.0, "angle": 50.0, "cooldown": 1.6},
			{"nom": "Rempart", "comportement": Behaviour.SOIN,
				"soin": 26, "cooldown": 4.0},
		],
	},
	{
		"id": &"force",
		"nom": "Force",
		"couleur": Color(0.92, 0.78, 0.22),
		"effets": [
			{"nom": "Poussée", "comportement": Behaviour.REPULSION,
				"degats": 6, "rayon": 7.0, "puissance": 26.0, "cooldown": 2.2},
			{"nom": "Attraction", "comportement": Behaviour.ATTRACTION,
				"degats": 4, "rayon": 12.0, "puissance": 20.0, "cooldown": 2.6},
			{"nom": "Ruée", "comportement": Behaviour.DASH,
				"degats": 18, "distance": 9.0, "rayon": 2.2, "cooldown": 2.0},
		],
	},
	{
		"id": &"vie",
		"nom": "Vie",
		"couleur": Color(0.42, 0.92, 0.48),
		"effets": [
			{"nom": "Soin", "comportement": Behaviour.SOIN,
				"soin": 34, "cooldown": 5.0},
			{"nom": "Siphon", "comportement": Behaviour.DRAIN,
				"degats": 11, "portee": 20.0, "ratio_soin": 0.8, "cooldown": 0.9},
			{"nom": "Invocation", "comportement": Behaviour.TOTEM,
				"soin": 6, "rayon": 3.2, "duree": 8.0, "intervalle": 0.8,
				"cooldown": 9.0},
		],
	},
	{
		"id": &"ombre",
		"nom": "Ombre",
		"couleur": Color(0.66, 0.44, 0.95),
		"effets": [
			{"nom": "Pas d'Ombre", "comportement": Behaviour.TELEPORT,
				"portee": 16.0, "cooldown": 2.4},
			{"nom": "Voile", "comportement": Behaviour.VOILE,
				"duree": 4.0, "cooldown": 8.0},
			{"nom": "Leurre", "comportement": Behaviour.LEURRE,
				"duree": 6.0, "distance": 5.0, "cooldown": 7.0},
			{"nom": "Éclat Nocturne", "comportement": Behaviour.PROJECTILE,
				"degats": 28, "portee": 15.0, "cooldown": 1.6},
		],
	},
]


static func school_by_id(school_id: StringName) -> Dictionary:
	for s: Dictionary in SCHOOLS:
		if s["id"] == school_id:
			return s
	return {}


## Définition passée à GameState.set_player_schools().
static func school_defs(indices: Array) -> Array:
	var out: Array = []
	for i: int in indices:
		var s: Dictionary = SCHOOLS[i]
		out.append({"id": s["id"], "pool_size": (s["effets"] as Array).size()})
	return out


static func effect(school_id: StringName, effect_index: int) -> Dictionary:
	var s: Dictionary = school_by_id(school_id)
	if s.is_empty():
		return {}
	var effets: Array = s["effets"]
	if effect_index < 0 or effect_index >= effets.size():
		return {}
	return effets[effect_index]


static func famille(comportement: int) -> String:
	return String(FAMILLES.get(comportement, "?"))
