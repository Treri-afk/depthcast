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
@export var ombre: Color = Color(0.38, 0.37, 0.52)
## Part d'albédo laissée passer dans l'ombre. À zéro la règle est pure, mais
## deux objets voisins deviennent indiscernables dans le noir d'un donjon.
@export_range(0.0, 0.5, 0.01) var melange_ombre: float = 0.34
## Part maximale de la teinte éclairée que l'ombre peut atteindre. La règle de
## l'ombre absolue suppose des surfaces plus claires qu'elle ; sur un décor
## sombre elle produirait une ombre plus CLAIRE que la lumière, et tout le
## décor s'aplatirait sur une seule valeur. Ce plafond garantit qu'une ombre
## assombrit toujours.
@export_range(0.2, 1.0, 0.01) var plafond_ombre: float = 0.82

@export_group("Post-traitement")
## Côté d'un bloc en pixels d'écran. 2 accroche discrètement, 4 est un parti pris.
@export_range(1.0, 8.0, 0.5) var pixel_taille: float = 2.0
## Épaisseur du contour, en blocs de trame. Le trait suit donc la grille.
@export_range(0.0, 6.0, 0.25) var contour_epaisseur: float = 1.25
## Écart de luminance à partir duquel on trace. Bas = trait partout, y compris
## dans le bruit ; haut = seules les vraies ruptures sont soulignées.
@export_range(0.01, 0.6, 0.005) var contour_seuil: float = 0.10
## Rupture de profondeur qui déclenche un trait. C'est ce qui souligne les
## arêtes de géométrie, invisibles à la luminance quand deux surfaces voisines
## sont éclairées pareil.

## Bruit fixe posé sur l'image. Il ne bouge jamais : un grain animé fait du
## bruit vidéo, un grain fixe fait du papier.
@export_range(0.0, 0.2, 0.005) var grain_force: float = 0.045

@export_group("Lumière des sorts")
## Les sorts éclairent le décor. Une boule de feu qui traverse une salle sans
## la faire réagir n'a pas de poids ; c'est aussi ce qui rend un couloir sombre
## lisible au moment où on en a besoin.
@export_range(0.0, 8.0, 0.25) var lumiere_sort_energie: float = 3.0
@export_range(1.0, 30.0, 0.5) var lumiere_sort_portee: float = 9.0

@export_group("Brume")
## La brume de distance est le plus gros indice de rendu réaliste. Quantifiée
## en paliers, elle donne la profondeur sans trahir les aplats.
@export var brume_couleur: Color = Color(0.11, 0.11, 0.17)
@export_range(0.0, 60.0, 1.0) var brume_debut: float = 14.0
@export_range(1.0, 120.0, 1.0) var brume_fin: float = 46.0
@export_range(1, 6, 1) var brume_paliers: int = 3
@export_range(0.0, 1.0, 0.05) var brume_force: float = 0.75

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
## Les valeurs sont volontairement ÉCARTÉES les unes des autres. Le contour se
## détecte sur la luminance : deux surfaces adjacentes de valeur voisine ne
## produisent aucun trait, et leur jonction disparaît. L'écart de valeur n'est
## donc pas un choix esthétique ici, c'est ce qui rend la géométrie lisible.
@export var fond: Color = Color(0.11, 0.11, 0.17)
@export var sol: Color = Color(0.66, 0.65, 0.71)
@export var sol_couloir: Color = Color(0.56, 0.55, 0.62)
@export var mur: Color = Color(0.34, 0.34, 0.42)
@export var mur_couloir: Color = Color(0.27, 0.27, 0.34)
@export var pilier: Color = Color(0.48, 0.47, 0.55)
@export var estrade: Color = Color(0.56, 0.55, 0.61)
@export var rampe: Color = Color(0.50, 0.49, 0.56)

@export_group("Mobilier")
@export var caisse: Color = Color(0.72, 0.55, 0.34)
@export var tonneau: Color = Color(0.60, 0.44, 0.27)
## Le tonneau explosif. Volontairement HORS de la gamme sourde du décor : c'est
## la seule chose du mobilier qui doive se repérer d'un bout à l'autre d'une
## salle, avant d'avoir à y réfléchir.
@export var tonneau_explosif: Color = Color(0.92, 0.45, 0.20)
@export var table: Color = Color(0.51, 0.38, 0.27)

@export_group("Interactifs")
@export var socle: Color = Color(0.47, 0.46, 0.55)
@export var marchand: Color = Color(0.96, 0.83, 0.42)
@export var chapeau_marchand: Color = Color(0.42, 0.33, 0.62)
@export var portail: Color = Color(0.45, 0.72, 1.0)

@export_group("Émotes")
## Le signe de surprise au-dessus d'une créature qui vient de comprendre.
## Volontairement hors de toute autre gamme du jeu : une émote doit se lire
## avant d'être regardée.
@export var emote_surprise: Color = Color(0.98, 0.83, 0.25)

@export_group("Créatures")
@export var creature_commune: Color = Color(0.84, 0.36, 0.40)
@export var creature_lourde: Color = Color(0.66, 0.25, 0.24)
@export var creature_ailee: Color = Color(0.58, 0.47, 0.88)
@export var boss: Color = Color(0.88, 0.29, 0.45)
