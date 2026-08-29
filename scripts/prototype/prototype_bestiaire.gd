class_name PrototypeBestiaire
extends RefCounted
## Les archétypes de monstres du PROTOTYPE. JETABLE — devient des Resources
## `MonsterStats` en C3.
##
## La règle est la même que pour les sorts : chaque type doit poser un problème
## DIFFÉRENT, pas être une variante de points de vie. Trois monstres qui foncent
## tout droit en ligne droite, c'est un seul monstre décliné trois fois.
##
##   Rôdeur  — tourne autour de toi et ne s'engage que par à-coups. Il faut
##             anticiper son assaut, pas juste reculer.
##   Brute   — avance sans dévier, encaisse, frappe fort. Elle impose de bouger
##             ou de la contrôler ; le kiting seul ne suffit pas.
##   Rôdeuse ailée — vole, garde ses distances et tire. Elle punit ceux qui
##             restent à découvert, et ignore les obstacles au sol.

enum Archetype { RODEUR, BRUTE, VOLANT }

const TYPES: Dictionary = {
	Archetype.RODEUR: {
		"nom": "Rôdeur",
		"pv": 30,
		"resonance": 12,
		"vitesse": 4.2,
		"degats": 7,
		"distance_garde": 5.5,      ## distance à laquelle il tourne autour
		"delai_assaut": 2.4,
		"duree_assaut": 0.45,
		"duree_repli": 0.7,
		"portee_frappe": 2.0,
		"taille": Vector3(1.1, 1.5, 1.1),
		"couleur": Color(0.78, 0.32, 0.36),
		"vole": false,
	},
	Archetype.BRUTE: {
		"nom": "Brute",
		"pv": 78,
		"resonance": 26,
		"vitesse": 2.1,
		"degats": 17,
		"distance_garde": 0.0,      ## elle ne garde aucune distance
		"delai_assaut": 1.6,
		"duree_assaut": 0.0,
		"duree_repli": 0.0,
		"portee_frappe": 2.6,
		"taille": Vector3(1.9, 2.4, 1.9),
		"couleur": Color(0.62, 0.24, 0.22),
		"vole": false,
	},
	Archetype.VOLANT: {
		"nom": "Rôdeuse ailée",
		"pv": 22,
		"resonance": 18,
		"vitesse": 3.6,
		"degats": 9,
		"distance_garde": 11.0,
		"delai_assaut": 2.0,
		"duree_assaut": 0.0,
		"duree_repli": 0.0,
		"portee_frappe": 16.0,      ## portée de tir, pas de contact
		"taille": Vector3(1.0, 0.8, 1.0),
		"couleur": Color(0.55, 0.45, 0.85),
		"vole": true,
		"hauteur_vol": 3.4,
		"tire": true,
		"vitesse_projectile": 13.0,
	},
}


static func stats(archetype: Archetype) -> Dictionary:
	return TYPES[archetype]


## Composition d'un étage. Elle se durcit en descendant : d'abord des rôdeurs
## seuls, puis du volant qui force à lever les yeux, puis de la brute.
static func composition(etage: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append(Archetype.RODEUR)
	out.append(Archetype.RODEUR)
	if etage >= 1:
		out.append(Archetype.VOLANT)
	if etage >= 2:
		out.append(Archetype.BRUTE)
	if etage >= 3:
		out.append(Archetype.VOLANT if rng.randf() < 0.5 else Archetype.RODEUR)
	return out
