@tool
class_name BossStats
extends MonsterStats
## Caractéristiques d'un boss. Hérite d'un monstre ordinaire et ajoute ce qui
## lui est propre : des phases, et un rythme d'attaque spéciale.
##
## Un boss reste un monstre — il apparaît par le même spawner, encaisse par le
## même resolver, meurt en versant de la Résonance comme les autres. Seule sa
## décision diffère.

@export_group("Phases")
## Seuils de points de vie, en fraction, où le boss change de phase.
## [0.66, 0.33] donne trois phases.
@export var seuils_de_phase: Array[float] = [0.66, 0.33]
## Titre affiché à l'apparition.
@export var titre: String = "Gardien"

@export_group("Attaque spéciale")
@export var delai_special: float = 6.0
@export var degats_special: int = 22
@export var rayon_special: float = 8.0
## Chaque phase franchie accélère l'attaque spéciale de ce facteur.
@export_range(0.4, 1.0, 0.05) var acceleration_par_phase: float = 0.75


func nombre_de_phases() -> int:
	return seuils_de_phase.size() + 1
