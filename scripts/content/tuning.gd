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
## Longueur de la mèche. Elle doit dépasser le temps de réaction des créatures
## (MonsterStats.temps_de_reaction), sinon le tonneau saute avant que personne
## ait eu le temps de le remarquer et toute la vigilance ne sert à rien.
## Jamais nulle non plus : sans mèche une rangée part en une frame et on ne voit
## qu'un flash.
@export_range(0.05, 3.0, 0.05) var tonneau_meche: float = 0.9

## La braise laissée au sol après l'explosion. Ce n'est pas une décoration :
## elle brûle, comme un sol ardent, et elle ne demande pas qui a allumé le feu.
## C'est ce qui empêche de faire sauter un tonneau à ses pieds sans y penser, et
## ce qui transforme un baril en outil d'interdiction de zone.
@export_range(0.0, 1.0, 0.05) var tonneau_braise_part_du_rayon: float = 0.45
@export_range(0.0, 15.0, 0.5) var tonneau_braise_duree: float = 4.0
@export_range(0.1, 3.0, 0.1) var tonneau_braise_intervalle: float = 0.6
@export var tonneau_braise_degats: int = 5

@export_group("Créature aveuglée")
## Vitesse de déambulation d'une créature qui a perdu sa trace, en multiple de
## sa vitesse. Nettement plus lente : elle cherche, elle ne patrouille pas.
@export_range(0.0, 1.0, 0.05) var errance_vitesse: float = 0.4
## Durée d'un cap avant d'en changer. Trop long et elle a l'air de savoir où
## elle va, trop court et elle tremble sur place.
@export_range(0.2, 5.0, 0.1) var errance_duree_du_cap: float = 1.3

@export_group("Vigilance")
## Combien de temps une créature s'écarte, une fois qu'elle a compris. Assez
## pour la voir détaler, trop peu pour qu'elle sorte du rayon — fuir doit
## améliorer ses chances, pas la sauver.
@export_range(0.1, 6.0, 0.1) var vigilance_duree_de_fuite: float = 1.4
## Vitesse de fuite, en multiple de la vitesse normale. La panique va plus vite
## que la marche.
@export_range(0.5, 3.0, 0.05) var vigilance_vitesse_de_fuite: float = 1.25

@export_group("Balise de leurre")
## Rayon d'appel. Large : une balise qui n'attire que ce qui est déjà sur soi
## n'a rien détourné du tout.
@export_range(2.0, 40.0, 0.5) var leurre_rayon: float = 16.0
## Combien de temps elle tient l'attention. C'est du répit acheté — assez pour
## souffler, traverser ou se replacer, jamais assez pour gagner le combat.
@export_range(1.0, 20.0, 0.5) var leurre_duree: float = 6.5
## Chance qu'une balise apparaisse dans une salle meublée.
@export_range(0.0, 1.0, 0.05) var leurre_chance_par_salle: float = 0.35
@export var leurre_cout: int = 30

@export_group("À terre")
## Vitesse en rampant, en multiple de la vitesse normale. On se traîne : assez
## pour se mettre à couvert ou se rapprocher d'un coéquipier, jamais assez pour
## fuir un combat.
@export_range(0.0, 1.0, 0.05) var a_terre_vitesse: float = 0.3
## Hauteur des yeux une fois à terre, en part de la hauteur normale.
@export_range(0.0, 1.0, 0.05) var a_terre_hauteur: float = 0.25

@export_group("Marche")
## Distance parcourue entre deux pas, en mètres. C'est ce nombre qui règle la
## cadence : la calquer sur une horloge donnerait des pas qui continuent quand
## on s'arrête.
@export_range(0.5, 6.0, 0.1) var marche_cadence: float = 1.9
## Amplitude du balancement vertical de la vue, en mètres.
@export_range(0.0, 0.2, 0.005) var marche_amplitude: float = 0.032
## Balancement latéral. Deux fois plus lent que le vertical — un pas à gauche,
## un pas à droite, c'est ce qui distingue une démarche d'un rebond.
@export_range(0.0, 0.2, 0.005) var marche_lateral: float = 0.02

@export_group("Portage")
## Distance à laquelle on attrape un objet, depuis les yeux.
@export_range(0.5, 6.0, 0.1) var portage_portee: float = 2.6
## Vitesse en portant, en multiple de la vitesse normale. Porter DOIT coûter :
## sans coût, c'est gratuit, et il n'y a aucune décision à prendre.
@export_range(0.2, 1.0, 0.05) var portage_ralentissement: float = 0.62
## Vitesse de lancer. Divisée par la masse : une caisse part loin, un tonneau
## tombe à ses pieds — c'est ce qui rend le choix de l'objet intéressant.
@export_range(1.0, 200.0, 0.5) var portage_force_de_lancer: float = 80.0
## Lancer un sort les mains pleines. Désactivé, porter un tonneau amorcé
## jusqu'à un groupe devient un vrai pari.
## Part d'élévation ajoutée au lancer. À plat, la gravité du jeu — volontairement
## forte — plaque l'objet au sol en trois dixièmes de seconde et il ne parcourt
## que quatre mètres. Un peu d'arc rend le lancer utile ; viser vers le haut
## reste le vrai levier, et c'est celui qui récompense le joueur.
@export_range(0.0, 1.0, 0.05) var portage_arc: float = 0.25
## Temps de charge d'un lancer, en secondes. Au-delà, on ne gagne plus rien :
## une charge sans plafond récompense la patience plutôt que la décision.
@export_range(0.1, 3.0, 0.05) var portage_charge_duree: float = 0.75
## Part de la force appliquée à charge nulle. Une pression brève doit POSER
## l'objet devant soi, pas le catapulter — c'est la différence entre lâcher et
## lancer, et elle doit se sentir dès la première fois.
@export_range(0.0, 1.0, 0.05) var portage_force_minimale: float = 0.22
@export var portage_bloque_les_sorts: bool = true

@export_group("Ressenti")
## Durée de l'arrêt sur image quand une créature meurt, en secondes réelles.
## Court : au-delà, ça cesse d'être une frappe et ça devient une saccade.
@export_range(0.0, 0.3, 0.005) var hitstop_mort: float = 0.06
## Arrêt plus bref quand c'est le joueur qui encaisse un gros coup.
@export_range(0.0, 0.3, 0.005) var hitstop_blessure: float = 0.035
## En dessous de ce montant, encaisser ne fige rien : sinon le jeu hoquette à
## chaque égratignure.
@export var hitstop_seuil_degats: int = 14
## Échelle du temps pendant l'arrêt. Zéro figerait aussi les tweens de retour.
@export_range(0.01, 1.0, 0.01) var hitstop_echelle: float = 0.05

## Fenêtre pendant laquelle on peut encore sauter après avoir quitté le sol.
## Personne ne sait la nommer, tout le monde la sent : sans elle, sauter en
## quittant une estrade échoue sans qu'on comprenne pourquoi.
@export_range(0.0, 0.4, 0.01) var saut_coyote: float = 0.12
## Fenêtre pendant laquelle un saut demandé trop tôt est retenu au lieu d'être
## perdu. Le symétrique du coyote : l'un pardonne le retard, l'autre l'avance.
@export_range(0.0, 0.4, 0.01) var saut_tampon: float = 0.14

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
## Les souffles projettent aussi les COÉQUIPIERS, pas seulement leur lanceur.
##
## Le dosage est toute la décision : des dégâts entre alliés font des disputes,
## une poussée seule fait de la comédie. Personne ne meurt de ta main, tout le
## monde te déteste trente secondes. Les dégâts de sort, eux, ne visent
## toujours que les monstres.
@export var souffle_pousse_les_allies: bool = true


## Coût du prochain sceau, renchérissement compris.
func cout_scelle(deja_acquis: int) -> int:
	if multiplicateurs_cumulatifs.is_empty():
		return cout_verrou_sort
	var i: int = mini(deja_acquis, multiplicateurs_cumulatifs.size() - 1)
	return int(round(cout_verrou_sort * multiplicateurs_cumulatifs[i]))
