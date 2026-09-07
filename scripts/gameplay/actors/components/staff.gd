class_name Staff
extends Node3D
## Le bâton : ce que le joueur a toujours, quoi qu'il arrive.
##
## ── POURQUOI IL EXISTE ───────────────────────────────────────────────────
##
## Les sorts se rerollent à chaque étage. Rien n'empêche donc de se retrouver
## avec deux soins et une protection, c'est-à-dire sans aucun moyen de faire un
## dégât — et un étage qu'on ne peut pas finir n'est pas une contrainte
## intéressante, c'est une partie perdue par tirage.
##
## Le bâton est le plancher. Il est faible à dessein : il permet de survivre et
## de nettoyer, jamais de gagner. Le jour où l'on préfère le bâton à ses sorts,
## c'est que les sorts sont trop faibles — pas que le bâton est trop fort.
##
## ── DEUX GESTES, DEUX PORTÉES ────────────────────────────────────────────
##
## La frappe est immédiate et fait mal ; le trait porte loin et fait peu. Un
## seul des deux aurait fait du bâton une réponse universelle à une distance
## donnée, et un trou à toutes les autres.

## Le geste en cours. Sert à ne pas enchaîner deux frappes dans la même image.
enum Geste { REPOS, FRAPPE, TRAIT, INVOCATION }

const LONGUEUR: float = 1.15
const PORTEE_FRAPPE: float = 2.9
const DEMI_ANGLE_FRAPPE: float = 0.7
const VITESSE_TRAIT: float = 42.0

## Position de repos, dans le repère des mains.
const AU_REPOS := Vector3(0.0, 0.0, 0.0)

signal a_frappe(direction: Vector3)
signal a_tire(direction: Vector3)

var _tuning: Tuning
var _geste: Geste = Geste.REPOS
var _reste: float = 0.0
var _recharge_frappe: float = 0.0
var _recharge_trait: float = 0.0
var _tete: Node3D = null


static func cree(couleur: Color) -> Staff:
	var baton := Staff.new()
	baton.name = "Baton"
	baton._monte(couleur)
	return baton


func _ready() -> void:
	_tuning = Content.tuning


func _process(delta: float) -> void:
	_recharge_frappe = maxf(0.0, _recharge_frappe - delta)
	_recharge_trait = maxf(0.0, _recharge_trait - delta)
	if _reste > 0.0:
		_reste = maxf(0.0, _reste - delta)
		_joue_le_geste()
	elif _geste != Geste.REPOS:
		_geste = Geste.REPOS
		position = AU_REPOS
		rotation = Vector3.ZERO


# ── Ce que l'extérieur demande ────────────────────────────────────────────

func peut_frapper() -> bool:
	return _recharge_frappe <= 0.0 and _geste == Geste.REPOS


func peut_tirer() -> bool:
	return _recharge_trait <= 0.0 and _geste == Geste.REPOS


func frappe(direction: Vector3) -> void:
	if not peut_frapper():
		return
	_geste = Geste.FRAPPE
	_reste = _tuning.baton_frappe_geste
	_recharge_frappe = _tuning.baton_frappe_recharge
	a_frappe.emit(direction)


## Lève le bâton. Le diagramme, lui, est posé par l'avatar : accroché ici, il
## héritait de l'inclinaison du fût ET du geste d'invocation, donc il basculait
## et passait derrière la tête. Un cercle d'invocation doit rester face au
## regard quoi que fasse la main qui le porte.
##
## Ne consomme aucune recharge et n'annule aucun geste en cours : lancer un sort
## n'est pas un coup de bâton, et le joueur ne doit pas perdre sa frappe parce
## qu'il a lancé un sort dans la même seconde.
func invoque(duree: float) -> void:
	if _geste == Geste.REPOS:
		_geste = Geste.INVOCATION
		_reste = duree


func tire(direction: Vector3) -> void:
	if not peut_tirer():
		return
	_geste = Geste.TRAIT
	_reste = _tuning.baton_trait_geste
	_recharge_trait = _tuning.baton_trait_recharge
	a_tire.emit(direction)


# ── Le modèle ─────────────────────────────────────────────────────────────

## Un fût, une virole, une tête à facettes. Trois pièces et pas une de plus :
## en vue subjective le bâton occupe un coin de l'écran en permanence, et un
## objet chargé y devient du bruit qu'on regarde toute la partie.
func _monte(couleur: Color) -> void:
	var palette: Palette = Content.palette

	var futaie := _piece(BoxMesh.new(), palette.mur.lightened(0.1))
	(futaie.mesh as BoxMesh).size = Vector3(0.07, LONGUEUR, 0.07)
	# Incliné et décalé : tenu droit devant, il coupe l'écran en deux.
	futaie.position = Vector3(0.0, -LONGUEUR * 0.35, 0.0)
	futaie.rotation = Vector3(deg_to_rad(-18.0), 0.0, deg_to_rad(9.0))
	add_child(futaie)
	_tete = futaie

	var virole := _piece(BoxMesh.new(), palette.pilier)
	(virole.mesh as BoxMesh).size = Vector3(0.11, 0.06, 0.11)
	virole.position = Vector3(0.0, LONGUEUR * 0.42, 0.0)
	futaie.add_child(virole)

	# La tête porte la couleur de l'école : c'est le seul endroit du bâton qui
	# change, et il suffit à dire avec quoi on joue sans lire le HUD.
	var pointe := _piece(_octaedre(0.13), couleur)
	pointe.position = Vector3(0.0, LONGUEUR * 0.56, 0.0)
	futaie.add_child(pointe)


func _octaedre(rayon: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.4
	# Très peu de segments : des facettes franches, que le contour d'écran
	# souligne. Une sphère lisse ne lui offre aucune arête à tracer.
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh


func _piece(mesh: Mesh, couleur: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = MaterialLibrary.aplat(couleur,
		MaterialLibrary.Role.OBJET)
	# Il ne projette pas d'ombre : collé à la caméra, il en jetterait une
	# énorme en travers de la salle.
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


## L'armé et la détente. Deux courbes différentes : la frappe part vers l'avant
## et revient, le trait recule puis se détend — on doit reconnaître le geste
## avant d'en voir l'effet.
func _joue_le_geste() -> void:
	if _tete == null:
		return
	var duree: float = _tuning.baton_frappe_geste
	if _geste == Geste.TRAIT:
		duree = _tuning.baton_trait_geste
	elif _geste == Geste.INVOCATION:
		duree = maxf(_reste, 0.01)
	var part: float = 1.0 - clampf(_reste / maxf(duree, 0.01), 0.0, 1.0)

	if _geste == Geste.FRAPPE:
		var arc: float = sin(part * PI)
		position = AU_REPOS + Vector3(-0.25 * arc, -0.12 * arc, -0.55 * arc)
		rotation = Vector3(deg_to_rad(-70.0) * arc, 0.0, deg_to_rad(25.0) * arc)
	elif _geste == Geste.TRAIT:
		# Recul sec, détente lente : l'inverse de la frappe.
		var recul: float = pow(1.0 - part, 2.0)
		position = AU_REPOS + Vector3(0.08 * recul, 0.04 * recul, 0.3 * recul)
		rotation = Vector3(deg_to_rad(14.0) * recul, 0.0, 0.0)
	else:
		# L'invocation : on LÈVE, on tient, on redescend. Petit et lent — c'est
		# une ponctuation, pas une attaque, et un grand geste à chaque sort
		# deviendrait fatigant au bout de trois étages.
		var leve: float = sin(part * PI)
		position = AU_REPOS + Vector3(-0.06 * leve, 0.16 * leve, 0.1 * leve)
		rotation = Vector3(deg_to_rad(-22.0) * leve, deg_to_rad(-8.0) * leve, 0.0)
