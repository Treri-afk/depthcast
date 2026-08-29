class_name PrototypeCatalogue
extends RefCounted
## Catalogue de contenu du PROTOTYPE. Volontairement en dur, volontairement jetable.
##
## En C2, tout ceci devient des Resources `.tres` éditables dans l'inspecteur, et
## ce fichier disparaît. Il n'est là que pour donner de quoi ressentir le reroll
## avant que le système data-driven existe.
##
## Ce qui compte ici, c'est que les trois effets d'une même école soient
## MÉCANIQUEMENT DIFFÉRENTS. Si le reroll remplace un projectile par un autre
## projectile un peu plus fort, le joueur ne sent rien et le jeu n'a plus de sujet.
## D'où trois familles nettement distinctes : à distance, autour de soi, sur soi.

enum Behaviour {
	PROJECTILE,  ## part droit devant, touche le premier monstre
	NOVA,        ## explose autour du lanceur, touche tout dans un rayon
	SOIN,        ## se soigne, ne fait aucun dégât
}

## Les 5 écoles du GDD. Noter les tailles de pool différentes (2 à 5) :
## c'est ce qui vérifie qu'aucun code ne suppose un nombre fixe.
const SCHOOLS: Array = [
	{
		"id": &"braise",
		"nom": "Braise",
		"couleur": Color(0.95, 0.35, 0.15),
		"effets": [
			{"nom": "Boule de Feu", "comportement": Behaviour.PROJECTILE,
				"degats": 12, "portee": 22.0, "cooldown": 0.5},
			{"nom": "Mur de Flammes", "comportement": Behaviour.NOVA,
				"degats": 18, "rayon": 4.5, "cooldown": 1.8},
			{"nom": "Brûlure Vive", "comportement": Behaviour.PROJECTILE,
				"degats": 5, "portee": 30.0, "cooldown": 0.15},
		],
	},
	{
		"id": &"givre",
		"nom": "Givre",
		"couleur": Color(0.4, 0.8, 1.0),
		"effets": [
			{"nom": "Gel", "comportement": Behaviour.NOVA,
				"degats": 10, "rayon": 6.0, "cooldown": 1.4},
			{"nom": "Bise Glaciale", "comportement": Behaviour.PROJECTILE,
				"degats": 16, "portee": 18.0, "cooldown": 0.9},
			{"nom": "Rempart", "comportement": Behaviour.SOIN,
				"soin": 20, "cooldown": 3.0},
		],
	},
	{
		"id": &"force",
		"nom": "Force",
		"couleur": Color(0.85, 0.75, 0.25),
		# Pool de 2 : une école n'est pas obligée d'en avoir trois.
		"effets": [
			{"nom": "Poussée", "comportement": Behaviour.NOVA,
				"degats": 8, "rayon": 5.5, "cooldown": 0.8},
			{"nom": "Ruée", "comportement": Behaviour.PROJECTILE,
				"degats": 22, "portee": 12.0, "cooldown": 1.2},
		],
	},
	{
		"id": &"vie",
		"nom": "Vie",
		"couleur": Color(0.4, 0.9, 0.45),
		"effets": [
			{"nom": "Soin", "comportement": Behaviour.SOIN,
				"soin": 30, "cooldown": 4.0},
			{"nom": "Siphon", "comportement": Behaviour.PROJECTILE,
				"degats": 9, "portee": 20.0, "cooldown": 0.7},
			{"nom": "Invocation", "comportement": Behaviour.NOVA,
				"degats": 14, "rayon": 3.5, "cooldown": 2.0},
		],
	},
	{
		"id": &"ombre",
		"nom": "Ombre",
		"couleur": Color(0.6, 0.4, 0.85),
		# Pool de 4 : l'autre borne à vérifier.
		"effets": [
			{"nom": "Pas d'Ombre", "comportement": Behaviour.PROJECTILE,
				"degats": 14, "portee": 25.0, "cooldown": 0.6},
			{"nom": "Voile", "comportement": Behaviour.SOIN,
				"soin": 12, "cooldown": 2.2},
			{"nom": "Leurre", "comportement": Behaviour.NOVA,
				"degats": 11, "rayon": 7.0, "cooldown": 1.6},
			{"nom": "Éclat Nocturne", "comportement": Behaviour.PROJECTILE,
				"degats": 25, "portee": 14.0, "cooldown": 1.5},
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
