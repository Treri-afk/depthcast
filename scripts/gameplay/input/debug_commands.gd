class_name DebugCommands
extends RefCounted
## Raccourcis de développement. Actifs uniquement en build de debug : un joueur
## ne doit jamais pouvoir sauter un étage ou s'offrir des Éclats.
##
## Ils existent pour une raison précise — tester la boucle complète, notamment
## l'achat d'écoles au hub, sans devoir nettoyer chaque étage à la main.

const SAUTER_ETAGE := KEY_F9
const DONNER_RESONANCE := KEY_F10
const DONNER_ECLATS := KEY_F11
const TUER_LE_JOUEUR := KEY_F12

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
				GameState.run.players[0].hp = 0
				message.emit("[debug] mort forcée")
			return true
	return false


func aide() -> String:
	if not actif():
		return ""
	return ("[color=#7fd0ff]F9 sauter l'étage · F10 +Résonance · "
		+ "F11 +Éclats · F12 mourir[/color]")
