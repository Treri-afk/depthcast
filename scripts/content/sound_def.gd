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

@export_group("Remplacement")
## Si renseigné, ce flux est joué au lieu de la synthèse. Point d'entrée pour
## de vrais sons, sans toucher au code.
@export var remplacement: AudioStream = null
