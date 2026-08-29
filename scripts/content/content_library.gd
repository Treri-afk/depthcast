extends Node
## Catalogue du contenu — autoload `Content`.
##
## Charge les Resources posées dans resources/ et les tient à disposition.
## Déposer un nouveau fichier .tres suffit à l'ajouter au jeu : ce script ne
## nomme aucun contenu en particulier, il lit un dossier (R6).

const DOSSIER_ECOLES := "res://resources/schools"
const DOSSIER_MONSTRES := "res://resources/monsters"
const CHEMIN_TUNING := "res://resources/tuning.tres"
const CHEMIN_PALETTE := "res://resources/palette.tres"

var ecoles: Array[School] = []
var monstres: Array[MonsterStats] = []
var tuning: Tuning
var palette: Palette


func _ready() -> void:
	ecoles.assign(_charge_dossier(DOSSIER_ECOLES))
	monstres.assign(_charge_dossier(DOSSIER_MONSTRES))
	tuning = load(CHEMIN_TUNING) if ResourceLoader.exists(CHEMIN_TUNING) else Tuning.new()
	palette = load(CHEMIN_PALETTE) if ResourceLoader.exists(CHEMIN_PALETTE) else Palette.new()

	# Un pool hors bornes est une erreur de contenu, pas un plantage : on le
	# signale et on continue, pour pouvoir tester malgré tout.
	for e: School in ecoles:
		if e.taille_pool() < School.POOL_MIN or e.taille_pool() > School.POOL_MAX:
			push_warning("École %s : pool de %d, hors des bornes %d-%d." % [
				e.nom, e.taille_pool(), School.POOL_MIN, School.POOL_MAX])

	print("[Content] %d école(s), %d monstre(s) chargés." % [ecoles.size(), monstres.size()])


func ecole(id: StringName) -> School:
	for e: School in ecoles:
		if e.id == id:
			return e
	return null


## Monstres ordinaires, boss exclus : la composition d'un étage ne doit pas
## tirer un boss au hasard.
func monstres_ordinaires() -> Array[MonsterStats]:
	var out: Array[MonsterStats] = []
	for m: MonsterStats in monstres:
		if not (m is BossStats):
			out.append(m)
	return out


func monstre(id: StringName) -> MonsterStats:
	for m: MonsterStats in monstres:
		if m.id == id:
			return m
	return null


## Définitions passées à GameState.set_player_schools().
func definitions_ecoles(indices: Array) -> Array:
	var out: Array = []
	for i: int in indices:
		if i < 0 or i >= ecoles.size():
			continue
		out.append({"id": ecoles[i].id, "pool_size": ecoles[i].taille_pool()})
	return out


func index_ecole(id: StringName) -> int:
	for i: int in ecoles.size():
		if ecoles[i].id == id:
			return i
	return -1


func _charge_dossier(chemin: String) -> Array:
	var out: Array = []
	var dossier := DirAccess.open(chemin)
	if dossier == null:
		push_warning("Dossier de contenu introuvable : " + chemin)
		return out
	var fichiers: PackedStringArray = dossier.get_files()
	fichiers.sort()
	for fichier: String in fichiers:
		# Godot renomme les .tres en .tres.remap dans un export.
		var nom: String = fichier.trim_suffix(".remap")
		if not nom.ends_with(".tres"):
			continue
		var res: Resource = load(chemin.path_join(nom))
		if res != null:
			out.append(res)
	return out
