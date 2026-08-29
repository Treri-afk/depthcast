@tool
class_name Tuning
extends Resource
## Toutes les valeurs d'équilibrage du jeu, en un seul endroit (R7).
##
## Aucune de ces valeurs ne doit être écrite en dur ailleurs. C'est ce qui rend
## le calibrage possible sans rouvrir un script — donc ce qui rend le calibrage
## possible tout court, parce qu'un réglage qui coûte une recompilation n'est
## jamais fait.

@export_group("Scellement des sorts")
## Coût par défaut d'un sceau sur un sort précis, quand l'effet ne définit
## pas le sien.
@export var cout_verrou_sort: int = 18
## Base du coût d'un sceau d'école. Multipliée par la taille du pool : plus une
## école a d'effets, plus la sceller retire d'incertitude, plus c'est cher.
@export var cout_verrou_ecole_base: int = 12
## Renchérissement de chaque sceau supplémentaire au sein d'un même étage.
## Sans lui, dès qu'on a de la Résonance on fige tout et le jeu perd son sujet.
@export var multiplicateurs_cumulatifs: Array[float] = [1.0, 1.5, 2.0, 3.0]

@export_group("Économie")
@export var cout_fiole_soin: int = 25
@export var valeur_fiole_soin: int = 45
@export var cout_eclat_vigueur: int = 40
@export var valeur_eclat_vigueur: int = 15

@export_group("Donjon")
@export var salles_par_etage: int = 3
@export var taille_salle_min: float = 22.0
@export var taille_salle_max: float = 30.0
@export var longueur_couloir: float = 7.0
@export var largeur_couloir: float = 4.0
@export var hauteur_mur: float = 5.5
@export var hauteur_pilier: float = 4.0

@export_group("Difficulté")
## Points de vie ajoutés aux monstres à chaque étage descendu.
@export var pv_monstre_par_etage: int = 6

@export_group("Joueur")
@export var pv_joueur: int = 100
@export var vitesse_joueur: float = 7.0
@export var acceleration_joueur: float = 55.0
@export var freinage_joueur: float = 42.0
@export var impulsion_saut: float = 8.4
@export var gravite: float = 26.0
@export_range(0.0005, 0.01, 0.0001) var sensibilite_souris: float = 0.0022


## Coût du prochain sceau, renchérissement compris.
func cout_scelle(deja_acquis: int) -> int:
	if multiplicateurs_cumulatifs.is_empty():
		return cout_verrou_sort
	var i: int = mini(deja_acquis, multiplicateurs_cumulatifs.size() - 1)
	return int(round(cout_verrou_sort * multiplicateurs_cumulatifs[i]))
