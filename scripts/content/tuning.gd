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
@export var taille_salle_min: float = 22.0
@export var taille_salle_max: float = 30.0
@export var longueur_couloir: float = 7.0
@export var largeur_couloir: float = 4.0
@export var hauteur_mur: float = 5.5
@export var hauteur_pilier: float = 4.0

@export_group("Méta-progression")
## Éclats gagnés par étage atteint. Doublés en cas de victoire.
@export var eclats_par_etage: int = 12
## Base du coût de déblocage d'une école. Renchérit à chaque école acquise.
@export var cout_deblocage_ecole: int = 60

@export_group("Structure de la run")
## Étage du boss. Avant lui, les étages sont des donjons ordinaires.
@export var etage_du_boss: int = 3
@export var salles_min: int = 3
@export var salles_max: int = 5

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

@export_group("Tonneaux explosifs")
## Le rayon d'un tonneau. Plus large que sa taille ne le laisse croire : on doit
## pouvoir se dire « j'aurais dû m'écarter », pas « je ne pouvais pas savoir ».
@export_range(1.0, 20.0, 0.5) var tonneau_rayon: float = 6.0
@export_range(1.0, 60.0, 1.0) var tonneau_puissance: float = 26.0
@export var tonneau_degats: int = 34
## Dégâts infligés au mobilier alentour. C'est ce nombre qui décide de la
## PORTÉE DE PROPAGATION : un tonneau voisin saute si ces dégâts, atténués par
## la distance, dépassent ses points de vie. À 80 contre 13 pv et un rayon de 6,
## la chaîne se propage jusqu'à environ cinq mètres — assez pour qu'une rangée
## parte, trop peu pour qu'une salle entière saute d'un seul tir.
@export var tonneau_degats_decor: int = 80
## Longueur de la mèche. Courte mais JAMAIS nulle : sans elle une rangée part en
## une seule frame et on ne voit qu'un flash. Avec elle la chaîne se lit, et on
## a le temps de courir.
@export_range(0.05, 2.0, 0.05) var tonneau_meche: float = 0.4

## La braise laissée au sol après l'explosion. Ce n'est pas une décoration :
## elle brûle, comme un sol ardent, et elle ne demande pas qui a allumé le feu.
## C'est ce qui empêche de faire sauter un tonneau à ses pieds sans y penser, et
## ce qui transforme un baril en outil d'interdiction de zone.
@export_range(0.0, 1.0, 0.05) var tonneau_braise_part_du_rayon: float = 0.45
@export_range(0.0, 15.0, 0.5) var tonneau_braise_duree: float = 4.0
@export_range(0.1, 3.0, 0.1) var tonneau_braise_intervalle: float = 0.6
@export var tonneau_braise_degats: int = 5

@export_group("Souffle et projection")
## Part de la puissance d'un souffle qui s'applique au joueur. À zéro, les
## explosions ne bousculent que le décor et les monstres.
@export_range(0.0, 4.0, 0.05) var souffle_effet_sur_joueur: float = 1.5
## Part d'élévation dans la projection. Sans elle, on est poussé au ras du sol
## et le frottement absorbe tout en deux mètres — or la projection ne dure que
## tant qu'on est en l'air, donc c'est aussi ce réglage qui décide de sa durée.
@export_range(0.0, 1.5, 0.05) var souffle_elevation: float = 0.9
## Élévation appliquée aux MONSTRES, volontairement plus basse que celle du
## joueur. Les voir décoller est la moitié du plaisir d'une explosion ; les voir
## rester en l'air trois secondes en ferait une immobilisation, donc une
## mécanique de contrôle — ce qu'une explosion ne doit pas devenir.
@export_range(0.0, 1.5, 0.05) var souffle_elevation_monstres: float = 0.35
## Hauteur maximale d'un monstre projeté. Bien plus basse que celle du joueur :
## un rôdeur qui part à quinze mètres n'est plus une réaction, c'est un gag, et
## il retombe hors du décor.
@export_range(0.0, 12.0, 0.5) var souffle_hauteur_max_monstres: float = 2.5
## Vitesse en dessous de laquelle on ne projette pas du tout. Un souffle
## lointain qui décolle le joueur d'un demi-mètre se lit comme un bug de
## collision, pas comme une explosion.
@export_range(0.0, 12.0, 0.5) var souffle_seuil_projection: float = 2.5
## Puissance du souffle d'une Nova. Le lanceur étant au centre, c'est aussi la
## hauteur à laquelle son propre sort le catapulte.
@export_range(0.0, 40.0, 0.5) var puissance_souffle_nova: float = 9.0

## Plafond de vitesse après projection. Deux explosions simultanées ne doivent
## pas envoyer le joueur hors de la salle.
@export_range(5.0, 80.0, 1.0) var projection_vitesse_max: float = 48.0
## Hauteur maximale atteinte par une projection, en mètres.
##
## Borne la seule composante verticale, jamais l'horizontale. Sans elle, un
## souffle violent envoie à vingt mètres — au-dessus de murs qui en font cinq
## et demi, donc hors du décor. La violence part vers l'horizon, pas vers le
## ciel : c'est aussi bien plus lisible, on voit où l'on atterrit.
@export_range(0.5, 20.0, 0.5) var projection_hauteur_max: float = 4.0
## Garde-fou du vol. Une chute qui n'en finit pas — trou dans le décor, corps
## coincé — ne doit jamais confisquer le contrôle indéfiniment.
@export_range(1.0, 20.0, 0.5) var projection_duree_max: float = 6.0

## Temps passé à terre APRÈS l'impact, par unité de vitesse reçue.
##
## C'est ici que la violence de l'explosion se paie en secondes. Le vol, lui,
## dure ce qu'il dure : on reste en ragdoll tant qu'on n'a pas retouché le sol,
## et pas une frame de plus ni de moins.
@export_range(0.0, 0.3, 0.005) var projection_releve_par_vitesse: float = 0.06
@export_range(0.05, 2.0, 0.05) var projection_releve_min: float = 0.25
@export_range(0.2, 8.0, 0.1) var projection_releve_max: float = 3.5
## Freinage horizontal pendant le vol. Très faible : un corps projeté conserve
## sa trajectoire, il ne freine pas en l'air.
@export_range(0.0, 40.0, 0.5) var projection_amortissement: float = 1.0
## Amplitude de la culbute de la vue. À zéro, la projection reste lisible mais
## perd ce qui la rend physique.
@export_range(0.0, 4.0, 0.05) var projection_culbute: float = 1.6
## Lancer un sort pendant qu'on est projeté. Désactivé, c'est ce qui donne son
## poids à une explosion : on ne se contente pas d'être déplacé, on perd la
## main. Activé, la projection redevient un simple effet de caméra.
@export var projection_bloque_les_sorts: bool = true


## Coût du prochain sceau, renchérissement compris.
func cout_scelle(deja_acquis: int) -> int:
	if multiplicateurs_cumulatifs.is_empty():
		return cout_verrou_sort
	var i: int = mini(deja_acquis, multiplicateurs_cumulatifs.size() - 1)
	return int(round(cout_verrou_sort * multiplicateurs_cumulatifs[i]))
