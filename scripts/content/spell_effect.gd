@tool
class_name SpellEffect
extends Resource
## Un effet de sort. C'est de la DONNÉE : on le crée et on le règle dans
## l'inspecteur Godot, sans écrire une ligne de code (R6).
##
## Le comportement est choisi dans une liste ; le code correspondant vit dans
## scripts/gameplay/spells/behaviours/. Ajouter un effet qui réutilise un
## comportement existant ne demande donc aucun script.

enum Comportement {
	PROJECTILE,   ## part droit devant, touche le premier corps
	MUR,          ## nappe persistante posée devant soi
	TRAINEE,      ## le sol s'embrase sous les pas pendant un moment
	NOVA,         ## explose autour de soi, une seule fois
	CONE,         ## souffle en éventail devant soi
	GEL,          ## nappe froide : peu de dégâts, gros ralentissement
	REPULSION,    ## repousse violemment ce qui est autour
	ATTRACTION,   ## aspire vers soi
	DASH,         ## charge en avant en traversant et blessant
	TELEPORT,     ## se transporte au point visé, avec aperçu préalable
	SOIN,         ## se soigne
	DRAIN,        ## projectile qui rend une part des dégâts en soin
	TOTEM,        ## balise au sol qui soigne tant qu'on reste dedans
	VOILE,        ## les monstres perdent notre trace
	LEURRE,       ## un mannequin attire les monstres à sa place
	PERMUTATION,  ## on échange sa place avec la créature visée
	ETAT,         ## pose un état temporaire : protection, provocation, hâte…
}

@export var nom: String = "Nouvel effet"
@export var comportement: Comportement = Comportement.PROJECTILE
@export_multiline var description: String = ""

@export_group("Puissance")
@export var degats: int = 0
@export var soin: int = 0
## Part des dégâts rendue en soin (DRAIN uniquement).
@export_range(0.0, 2.0, 0.05) var ratio_soin: float = 0.0

@export_group("Géométrie")
@export var portee: float = 0.0
@export var rayon: float = 0.0
@export var largeur: float = 0.0
@export var distance: float = 0.0
@export_range(0.0, 180.0, 1.0) var angle: float = 0.0

## Recul de la vue au lancer. Une boule de feu et un soin ne se lancent pas
## pareil, et c'est ce nombre qui le dit — pas une ligne de code par sort.
@export_range(0.0, 6.0, 0.05) var recul: float = 0.9

@export_group("Allure")
## La forme que prend la zone posée par ce sort.
##
## En ligne claire, deux surfaces de la même couleur sont indiscernables : ni
## dégradé, ni volume, ni lueur pour les séparer. La SILHOUETTE est donc le seul
## levier, et c'est ce réglage qui fait qu'un mur de flammes ne ressemble pas à
## une nappe de gel. Sans lui, tous les sorts de zone se ressemblaient.
@export var allure: ZoneVisual.Allure = ZoneVisual.Allure.NAPPE

## Ce qui se produit au point de contact. Même raison que l'allure : sans lui,
## toucher avec une boule de feu ou avec un éclat de givre donnait exactement la
## même image.
@export var impact: FxLibrary.Impact = FxLibrary.Impact.ECLAT

## LE GESTE PROPRE DE CE SORT.
##
## L'allure ci-dessus est un choix parmi cinq formes génériques ; celle-ci est
## la géométrie et l'animation faites POUR ce sort. Une onde de choc qui chasse
## des blocs vers l'extérieur ne se paramètre pas depuis une flaque qui tourne :
## il fallait une classe par geste.
##
## `NAPPE` est le repli. Un sort qui la garde est un sort qu'on n'a pas fini.
@export var signature: SpellSignature.Genre = SpellSignature.Genre.NAPPE

@export_group("État appliqué")
## Nom de l'état posé. Vide = ce sort n'en pose aucun.
##
## Le moteur ne connaît AUCUN de ces noms : il ne lit que les facteurs
## ci-dessous. « Protection », « Provocation », « Hâte » sont des mots que la
## donnée choisit, et un nouvel état ne demande donc pas une ligne de code (R6).
@export var statut_id: StringName = &""
@export_range(0.0, 60.0, 0.5) var statut_duree: float = 0.0
## Qui le reçoit.
@export_enum("Soi", "Alliés à portée", "Ennemis à portée") var statut_cible: int = 0
## Multiplie les dégâts REÇUS par le porteur. Sous 1, c'est une protection ;
## au-dessus, une vulnérabilité.
@export_range(0.0, 3.0, 0.05) var statut_degats_recus: float = 1.0
## Multiplie les dégâts INFLIGÉS par le porteur.
@export_range(0.0, 3.0, 0.05) var statut_degats_infliges: float = 1.0
@export_range(0.0, 3.0, 0.05) var statut_vitesse: float = 1.0
## Le monstre touché poursuit le lanceur tant que ça dure. C'est la provocation,
## et c'est ce qui rend le rôle de tank possible : sans elle, la cible d'un
## monstre se décide à la distance, donc c'est la géométrie qui joue.
@export var statut_provoque: bool = false

@export_group("Durée")
@export var cooldown: float = 1.0
@export var duree: float = 0.0
## Durée d'une flaque semée par une TRAINEE.
@export var duree_secondaire: float = 0.0
@export var intervalle: float = 0.5

@export_group("Contrôle")
@export var puissance: float = 0.0
## Facteur de vitesse appliqué aux monstres. 1.0 = aucun ralentissement.
@export_range(0.05, 1.0, 0.01) var ralentissement: float = 1.0

@export_group("Économie")
## Décoché, le coût de scellement vient de la formule de la table de tuning.
## Coché, la valeur ci-dessous s'impose.
##
## C'est la nullabilité exigée par R7, rendue explicite : un booléen plutôt
## qu'une sentinelle. Zéro reste un coût valide — un sceau délibérément gratuit
## doit rester exprimable — et un effet ajouté sans réglage tombe sur la
## formule au lieu de casser le système par oubli.
@export var cout_verrou_personnalise: bool = false
@export var cout_verrou: int = 0


func cout_de_scellement(defaut: int) -> int:
	return cout_verrou if cout_verrou_personnalise else defaut


## Ce que le HUD affiche sous le nom.
func libelle_famille() -> String:
	return NOMS_FAMILLE.get(comportement, "?")


const NOMS_FAMILLE: Dictionary = {
	Comportement.PROJECTILE: "projectile",
	Comportement.MUR: "mur persistant",
	Comportement.TRAINEE: "traînée au sol",
	Comportement.NOVA: "onde de choc",
	Comportement.CONE: "souffle conique",
	Comportement.GEL: "nappe ralentissante",
	Comportement.REPULSION: "répulsion",
	Comportement.ATTRACTION: "attraction",
	Comportement.DASH: "charge",
	Comportement.TELEPORT: "téléportation",
	Comportement.SOIN: "soin",
	Comportement.DRAIN: "vol de vie",
	Comportement.TOTEM: "totem de soin",
	Comportement.VOILE: "invisibilité",
	Comportement.LEURRE: "leurre",
	Comportement.PERMUTATION: "permutation",
	Comportement.ETAT: "état",
}


func libelle_puissance() -> String:
	if degats > 0:
		return "%d dégâts" % degats
	if soin > 0:
		return "%d soin" % soin
	return "utilitaire"
