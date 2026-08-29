@tool
class_name SoundDef
extends Resource
## La définition d'un son, en une poignée de nombres.
##
## Aucun fichier audio : la forme d'onde est synthétisée au démarrage. C'est ce
## qui permet d'avoir un jeu sonore aujourd'hui, sans attendre un sound designer,
## et de régler chaque effet dans l'inspecteur comme on règle un sort.
##
## Le jour où de vrais sons arrivent, il suffira de poser un AudioStream dans
## `remplacement` : le reste du jeu ne verra pas la différence.

enum Forme {
	SINUS,   ## doux, rond — soins, interface
	CARRE,   ## dur, rétro — impacts, refus
	SCIE,    ## agressif — dégâts, charges
	BRUIT,   ## souffle — explosions, morts, vent
}

@export var id: StringName = &""
@export var forme: Forme = Forme.SINUS

@export_group("Hauteur")
## La fréquence glisse du début vers la fin sur toute la durée. C'est ce
## glissement qui fait la différence entre un bip et un son de jeu : montant
## pour une réussite, descendant pour un échec ou une mort.
@export_range(40.0, 4000.0, 1.0) var frequence_debut: float = 440.0
@export_range(40.0, 4000.0, 1.0) var frequence_fin: float = 440.0

@export_group("Enveloppe")
@export_range(0.02, 3.0, 0.01) var duree: float = 0.18
## Part de la durée consacrée à la montée. Court = percussif, long = soufflé.
@export_range(0.0, 1.0, 0.01) var attaque: float = 0.02
@export_range(0.0, 1.0, 0.01) var volume: float = 0.6

@export_group("Variation")
## Écart de hauteur tiré à chaque lecture. Sans lui, dix impacts d'affilée
## sonnent comme une machine à écrire.
@export_range(0.0, 0.5, 0.01) var variation_hauteur: float = 0.08
## Décalage de volume en décibels, appliqué à la lecture.
@export_range(-40.0, 12.0, 0.5) var gain_db: float = 0.0

@export_group("Espace")
## Le son appartient au monde et se joue à un endroit.
##
## Faux pour ce qui appartient à l'interface — un achat, un refus, une mutation
## de sort. Ces sons-là n'ont pas de position : les spatialiser les ferait
## varier selon l'orientation du joueur au moment où il clique, ce qui est
## exactement le contraire de ce qu'on veut d'un retour d'interface.
@export var spatialise: bool = true
## Au-delà, on ne l'entend plus. Une détonation porte plus loin qu'un pas.
@export_range(1.0, 300.0, 1.0) var portee: float = 45.0
## Distance à laquelle le volume vaut celui d'origine. Petite = le son décroît
## vite et localise bien ; grande = il remplit la salle.
@export_range(0.5, 30.0, 0.5) var unite: float = 6.0

@export_group("Remplacement")
## Si renseigné, ce flux est joué au lieu de la synthèse. Point d'entrée pour
## de vrais sons, sans toucher au code.
@export var remplacement: AudioStream = null
