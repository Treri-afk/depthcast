@tool
class_name Palette
extends Resource
## La palette fermée du jeu.
##
## Règle de la ligne claire : toutes les couleurs du jeu sortent d'ici. Une
## couleur écrite en dur dans un script est une entorse, et trois entorses
## suffisent à faire disparaître une identité graphique.
##
## Le décor est sourd, la magie est vive. Les teintes d'école ne servent qu'aux
## sorts et aux accents de créatures — jamais aux murs, jamais au mobilier.

@export_group("Encre et ombre")
## Le trait. Une seule valeur pour tout le jeu.
@export var encre: Color = Color(0.09, 0.08, 0.14)
## Le liseré clair entre l'objet et son trait. C'est la signature « autocollant ».
@export var lisere_blanc: Color = Color(0.96, 0.96, 0.98)
## L'ombre. IDENTIQUE sur toute surface, jamais un albédo assombri : c'est la
## règle qui unifie l'image, et celle qu'on remarque sans savoir la nommer.
@export var ombre: Color = Color(0.20, 0.19, 0.34)
## Part d'albédo laissée passer dans l'ombre. À zéro la règle est pure, mais
## deux objets voisins deviennent indiscernables dans le noir d'un donjon.
@export_range(0.0, 0.5, 0.01) var melange_ombre: float = 0.18

@export_group("Post-traitement")
## Côté d'un bloc en pixels d'écran. 2 accroche discrètement, 4 est un parti pris.
@export_range(1.0, 8.0, 0.5) var pixel_taille: float = 2.0
## Épaisseur du contour, en blocs de trame. Le trait suit donc la grille.
@export_range(0.0, 6.0, 0.25) var contour_epaisseur: float = 2.0
## Écart de luminance à partir duquel on trace. Bas = trait partout, y compris
## dans le bruit ; haut = seules les vraies ruptures sont soulignées.
@export_range(0.01, 0.6, 0.005) var contour_seuil: float = 0.085

@export_group("Filtre de couleur")
## Aucun, Négatif, Monochrome, Duotone, Teinté. Un seul réglage pour changer
## complètement l'ambiance sans toucher à une seule couleur du jeu.
@export_enum("Aucun", "Négatif", "Monochrome", "Duotone", "Teinté")
var filtre: int = 0
## Couleur des hautes lumières en duotone, ou teinte multipliée en mode Teinté.
@export var filtre_teinte: Color = Color(0.45, 0.62, 1.0)
## Couleur des ombres en duotone.
@export var filtre_ombre: Color = Color(0.06, 0.05, 0.12)
@export_range(0.0, 1.0, 0.05) var filtre_force: float = 1.0

@export_group("Décor")
@export var fond: Color = Color(0.11, 0.11, 0.17)
@export var sol: Color = Color(0.62, 0.61, 0.66)
@export var sol_couloir: Color = Color(0.52, 0.51, 0.57)
@export var mur: Color = Color(0.40, 0.40, 0.47)
@export var mur_couloir: Color = Color(0.34, 0.34, 0.41)
@export var pilier: Color = Color(0.46, 0.45, 0.52)
@export var estrade: Color = Color(0.56, 0.55, 0.61)
@export var rampe: Color = Color(0.50, 0.49, 0.56)

@export_group("Mobilier")
@export var caisse: Color = Color(0.72, 0.55, 0.34)
@export var tonneau: Color = Color(0.60, 0.44, 0.27)
@export var table: Color = Color(0.51, 0.38, 0.27)

@export_group("Interactifs")
@export var socle: Color = Color(0.47, 0.46, 0.55)
@export var marchand: Color = Color(0.96, 0.83, 0.42)
@export var chapeau_marchand: Color = Color(0.42, 0.33, 0.62)
@export var portail: Color = Color(0.45, 0.72, 1.0)

@export_group("Créatures")
@export var creature_commune: Color = Color(0.84, 0.36, 0.40)
@export var creature_lourde: Color = Color(0.66, 0.25, 0.24)
@export var creature_ailee: Color = Color(0.58, 0.47, 0.88)
@export var boss: Color = Color(0.88, 0.29, 0.45)
