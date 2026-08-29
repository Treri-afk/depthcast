extends Node
## Progression méta — autoload `Meta`.
##
## Les Éclats et les écoles débloquées survivent aux runs ; la Résonance,
## jamais (GDD §3). Ce sont deux systèmes séparés et cette classe ne connaît
## que le premier.
##
## Règle de conception centrale : débloquer une école élargit le pool de choix,
## donc l'incertitude. La méta ne rend jamais plus fort, elle rend moins
## prévisible.

const CHEMIN := "user://depthcast.save"
const VERSION := 1

signal eclats_changes(total: int)
signal ecole_debloquee(id: StringName)

var eclats: int = 0
var ecoles_debloquees: Array[StringName] = []


func _ready() -> void:
	charge()


## Écoles disponibles à la sélection, dans l'ordre du catalogue.
func ecoles_disponibles() -> Array[School]:
	var out: Array[School] = []
	for e: School in Content.ecoles:
		if ecoles_debloquees.has(e.id):
			out.append(e)
	return out


func est_debloquee(id: StringName) -> bool:
	return ecoles_debloquees.has(id)


func cout_deblocage() -> int:
	# Chaque école coûte plus cher que la précédente : le pool s'élargit de
	# plus en plus lentement, et chaque ajout reste une décision.
	var deja: int = ecoles_debloquees.size()
	return Content.tuning.cout_deblocage_ecole * maxi(1, deja - 2)


func tente_deblocage(id: StringName) -> bool:
	if est_debloquee(id):
		return false
	var cout: int = cout_deblocage()
	if eclats < cout:
		return false
	eclats -= cout
	ecoles_debloquees.append(id)
	eclats_changes.emit(eclats)
	ecole_debloquee.emit(id)
	sauve()
	return true


func gagne_eclats(montant: int) -> void:
	if montant <= 0:
		return
	eclats += montant
	eclats_changes.emit(eclats)
	sauve()


## Récompense de fin de run. Croît avec la profondeur : descendre est ce qui
## paie, pas la durée passée en jeu.
func recompense(etage_atteint: int, victoire: bool) -> int:
	var base: int = Content.tuning.eclats_par_etage * (etage_atteint + 1)
	return base * 2 if victoire else base


# ── Persistance ───────────────────────────────────────────────────────────

func sauve() -> void:
	var fichier := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if fichier == null:
		push_warning("Sauvegarde impossible : " + CHEMIN)
		return
	var ids: Array = []
	for id: StringName in ecoles_debloquees:
		ids.append(String(id))
	fichier.store_string(JSON.stringify({
		"version": VERSION,
		"eclats": eclats,
		"ecoles": ids,
	}))


func charge() -> void:
	if not FileAccess.file_exists(CHEMIN):
		_premiere_partie()
		return
	var fichier := FileAccess.open(CHEMIN, FileAccess.READ)
	var donnees: Variant = JSON.parse_string(fichier.get_as_text())
	if typeof(donnees) != TYPE_DICTIONARY:
		_premiere_partie()
		return

	eclats = int((donnees as Dictionary).get("eclats", 0))
	ecoles_debloquees.clear()
	for id: Variant in (donnees as Dictionary).get("ecoles", []):
		ecoles_debloquees.append(StringName(id))
	if ecoles_debloquees.is_empty():
		_premiere_partie()


## Une première partie ouvre assez d'écoles pour composer une équipe, et pas
## une de plus : le premier déblocage doit rester un évènement.
func _premiere_partie() -> void:
	ecoles_debloquees.clear()
	for e: School in Content.ecoles.slice(0, PlayerState.SLOT_COUNT):
		ecoles_debloquees.append(e.id)
	sauve()


## Remise à zéro, pour les tests et l'équilibrage.
func reinitialise() -> void:
	eclats = 0
	_premiere_partie()
	eclats_changes.emit(eclats)
