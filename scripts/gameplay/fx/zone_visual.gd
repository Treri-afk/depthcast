class_name ZoneVisual
extends Node3D
## L'apparence d'une zone persistante, et ce qui la rend reconnaissable.
##
## Avant, toutes les zones étaient la même sphère translucide : un mur de
## flammes, une nappe de gel et un totem de soin se ressemblaient trait pour
## trait. On lançait un sort sans savoir lequel on venait de lancer, ce qui est
## le pire défaut possible dans un jeu dont le sujet est de ne pas savoir de
## quoi son sort est capable.
##
## ── LA SILHOUETTE, PAS L'OMBRAGE ────────────────────────────────────────
##
## En ligne claire il n'y a ni dégradé, ni volume, ni lueur : deux surfaces de
## la même couleur sont indiscernables quelle que soit leur matière. Ce qui
## distingue un sort d'un autre ne peut donc être QUE sa forme et son mouvement.
##
## C'est une contrainte, et c'est une bonne : une nappe rampe, un mur monte, un
## dôme respire, des pics jaillissent. On les reconnaît du coin de l'œil, sans
## lire une couleur — donc aussi quand ils se superposent, et aussi en filtre
## monochrome.

enum Allure {
	NAPPE,    ## une flaque au sol, qui tourne lentement — traînée, gel
	MUR,      ## une rangée de langues verticales qui montent — mur de flammes
	DOME,     ## une coupole qui respire — soin, protection
	PICS,     ## des pointes qui jaillissent du sol — gel offensif
	COLONNE,  ## un fût qui tourne sur lui-même — invocation, balise
}

## Vitesse de base des animations. Chaque allure la module à sa façon.
const CADENCE: float = 1.6

var allure: Allure = Allure.NAPPE
var couleur: Color = Color.WHITE
var dimensions: Vector3 = Vector3.ONE

var _pieces: Array[MeshInstance3D] = []
var _materiaux: Array[StandardMaterial3D] = []
var _phase: float = 0.0


static func cree(p_allure: Allure, p_dimensions: Vector3, p_couleur: Color) -> ZoneVisual:
	var visuel := ZoneVisual.new()
	visuel.name = "Visuel"
	visuel.allure = p_allure
	visuel.dimensions = p_dimensions
	visuel.couleur = p_couleur
	visuel._monte()
	return visuel


## Opacité d'ensemble, pilotée par la zone qui s'estompe en fin de vie.
func fondu(part: float) -> void:
	for mat: StandardMaterial3D in _materiaux:
		mat.albedo_color.a = part


func _monte() -> void:
	match allure:
		Allure.MUR:
			_monte_le_mur()
		Allure.DOME:
			_monte_le_dome()
		Allure.PICS:
			_monte_les_pics()
		Allure.COLONNE:
			_monte_la_colonne()
		_:
			_monte_la_nappe()


func _process(delta: float) -> void:
	_phase += delta * CADENCE
	match allure:
		Allure.NAPPE:
			# Elle tourne, lentement, et respire à peine : une flaque n'a pas de
			# geste propre, elle occupe le sol.
			rotation.y += delta * 0.5
			var souffle: float = 1.0 + sin(_phase) * 0.04
			scale = Vector3(souffle, 1.0, souffle)
		Allure.MUR:
			# Chaque langue monte et redescend à son propre rythme. Décalées,
			# elles font une flamme ; en phase, elles feraient un ascenseur.
			for i: int in _pieces.size():
				var h: float = 0.55 + absf(sin(_phase * 1.7 + float(i) * 0.9)) * 0.75
				_pieces[i].scale.y = h
		Allure.DOME:
			var r: float = 1.0 + sin(_phase * 0.9) * 0.06
			scale = Vector3(r, r * 0.9, r)
		Allure.PICS:
			# Les pointes jaillissent en vagues successives : c'est ce qui les
			# distingue d'un simple hérisson posé là.
			for i: int in _pieces.size():
				var sortie: float = 0.45 + absf(sin(_phase * 2.1 + float(i) * 1.3)) * 0.9
				_pieces[i].scale.y = sortie
		Allure.COLONNE:
			rotation.y += delta * 1.4
			var pulse: float = 1.0 + sin(_phase * 1.3) * 0.08
			scale = Vector3(pulse, 1.0, pulse)


# ── Les cinq allures ──────────────────────────────────────────────────────

func _monte_la_nappe() -> void:
	var rayon: float = maxf(dimensions.x, 0.5)
	# Un disque plat, à peine décollé du sol, plus un anneau de bord : c'est le
	# bord qui la fait lire comme une flaque plutôt que comme une lueur.
	_ajoute(_cylindre(rayon, 0.12), Vector3(0, 0.06, 0))
	var bord := _cylindre(rayon * 1.02, 0.3)
	_ajoute(bord, Vector3(0, 0.15, 0), 0.35)


func _monte_le_mur() -> void:
	var largeur: float = maxf(dimensions.x, 1.0)
	var hauteur: float = maxf(dimensions.y, 1.5)
	var langues: int = clampi(int(largeur / 0.7), 3, 14)
	for i: int in langues:
		var x: float = -largeur * 0.5 + largeur * (float(i) + 0.5) / float(langues)
		var langue := _boite(Vector3(largeur / float(langues) * 0.8, hauteur, 0.5))
		# Le pivot au pied : la langue GRANDIT vers le haut au lieu de s'étirer
		# des deux côtés, ce qui est la différence entre une flamme et un
		# accordéon.
		(langue.mesh as BoxMesh).size.y = hauteur
		langue.position = Vector3(x, 0.0, 0.0)
		_pieces.append(langue)
		add_child(langue)
		_cale_au_pied(langue, hauteur)


func _monte_le_dome() -> void:
	var rayon: float = maxf(dimensions.x, 0.5)
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.0
	# Hémisphère : une sphère entière moitié enterrée se lit comme une bulle,
	# pas comme une protection posée sur le sol.
	mesh.is_hemisphere = true
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	_ajoute(piece, Vector3.ZERO, 0.28)
	_ajoute(_cylindre(rayon, 0.1), Vector3(0, 0.05, 0), 0.5)


func _monte_les_pics() -> void:
	var rayon: float = maxf(dimensions.x, 0.6)
	var combien: int = clampi(int(rayon * 2.2), 4, 16)
	for i: int in combien:
		var angle: float = TAU * float(i) / float(combien)
		var d: float = rayon * (0.25 + 0.7 * fmod(float(i) * 0.37, 1.0))
		var pic := _cone(0.28, 1.5)
		pic.position = Vector3(cos(angle) * d, 0.0, sin(angle) * d)
		_pieces.append(pic)
		add_child(pic)
		_cale_au_pied(pic, 1.5)


func _monte_la_colonne() -> void:
	var rayon: float = maxf(dimensions.x, 0.4)
	_ajoute(_cylindre(rayon * 0.55, maxf(dimensions.y, 2.4)),
		Vector3(0, maxf(dimensions.y, 2.4) * 0.5, 0), 0.3)
	_ajoute(_cylindre(rayon, 0.12), Vector3(0, 0.06, 0), 0.55)


# ── Fabrique ──────────────────────────────────────────────────────────────

## Décale le maillage vers le haut pour que la mise à l'échelle en Y fasse
## grandir la pièce depuis le sol, et non depuis son centre.
func _cale_au_pied(piece: MeshInstance3D, hauteur: float) -> void:
	var mesh: Mesh = piece.mesh
	if mesh is BoxMesh:
		# Godot centre une boîte sur son origine : on remonte le nœud d'une
		# demi-hauteur, et l'échelle part alors bien du pied.
		piece.position.y = hauteur * 0.5
	elif mesh is CylinderMesh:
		piece.position.y = hauteur * 0.5
	_habille(piece, 0.42)
	_materiaux.append(piece.material_override as StandardMaterial3D)


func _ajoute(piece: MeshInstance3D, ou: Vector3, alpha: float = 0.34) -> void:
	piece.position = ou
	_habille(piece, alpha)
	_materiaux.append(piece.material_override as StandardMaterial3D)
	add_child(piece)


## Non éclairée, comme tous les effets translucides du jeu : une zone est de la
## lumière, pas une surface. L'éclairer lui donnerait un dégradé, c'est-à-dire
## la troisième valeur qu'on s'interdit partout ailleurs.
func _habille(piece: MeshInstance3D, alpha: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(couleur.r, couleur.g, couleur.b, alpha)
	mat.emission_enabled = true
	mat.emission = couleur
	mat.emission_energy_multiplier = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material_override = mat


func _cylindre(rayon: float, hauteur: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = rayon
	mesh.bottom_radius = rayon
	mesh.height = hauteur
	# Peu de côtés : la facette est le langage du jeu, un cercle lisse jurerait
	# avec des murs faits de blocs.
	mesh.radial_segments = 10
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	return piece


func _boite(taille: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	return piece


func _cone(rayon: float, hauteur: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = rayon
	mesh.height = hauteur
	mesh.radial_segments = 6
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	return piece
