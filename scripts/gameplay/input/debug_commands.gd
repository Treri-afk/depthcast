class_name DebugCommands
extends RefCounted
## Raccourcis de développement. Actifs uniquement en build de debug : un joueur
## ne doit jamais pouvoir sauter un étage ou s'offrir des Éclats.
##
## Ils existent pour une raison précise — tester la boucle complète, notamment
## l'achat d'écoles au hub, sans devoir nettoyer chaque étage à la main.

# Des lettres et non des touches de fonction : sur macOS, F1 à F12 sont
# captées par le système (Mission Control, luminosité) avant d'atteindre le jeu.
# Ces quatre-là ne servent à rien d'autre et sont loin des touches de
# déplacement, donc pas d'appui accidentel en plein combat.
const SAUTER_ETAGE := KEY_P
const DONNER_RESONANCE := KEY_O
const DONNER_ECLATS := KEY_I
const TUER_LE_JOUEUR := KEY_M
const SOIGNER_LE_JOUEUR := KEY_L

const RESONANCE_DONNEE: int = 150
const ECLATS_DONNES: int = 300

signal saut_d_etage_demande()
signal message(texte: String)


func actif() -> bool:
	return OS.is_debug_build()


## Retourne true si la touche a été consommée.
func traite(touche: InputEventKey) -> bool:
	if not actif() or touche == null or not touche.pressed or touche.echo:
		return false

	match touche.physical_keycode:
		SAUTER_ETAGE:
			saut_d_etage_demande.emit()
			return true
		DONNER_RESONANCE:
			GameState.add_resonance(RESONANCE_DONNEE)
			message.emit("[debug] +%d Résonance" % RESONANCE_DONNEE)
			return true
		DONNER_ECLATS:
			Meta.gagne_eclats(ECLATS_DONNES)
			message.emit("[debug] +%d Éclats — total %d" % [ECLATS_DONNES, Meta.eclats])
			return true
		TUER_LE_JOUEUR:
			if GameState.is_in_run():
				GameState.local_player().hp = 0
				message.emit("[debug] mort forcée")
			return true
		SOIGNER_LE_JOUEUR:
			if GameState.is_in_run():
				var p: PlayerState = GameState.local_player()
				p.hp = p.max_hp
				message.emit("[debug] points de vie rendus")
			return true
	return false


func aide() -> String:
	if not actif():
		return ""
	return ("[color=#7fd0ff][b]Debug[/b]  P sauter l'étage · O +Résonance\n"
		+ "I +Éclats · L se soigner · M mourir\n"
		+ "² ou ` ouvre la console — `aide` pour tout le reste[/color]")
