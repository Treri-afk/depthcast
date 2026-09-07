class_name SpellSignature
extends Node3D
## La signature visuelle d'un sort : sa géométrie et son geste, à lui seul.
##
## ── POURQUOI CETTE COUCHE EXISTE ─────────────────────────────────────────
##
## Avant, dix-sept sorts se partageaient cinq allures et quatre impacts. Sept
## d'entre eux posaient la même flaque ronde. On lançait un sort sans savoir
## lequel on venait de lancer — le pire défaut possible dans un jeu dont le
## sujet est de ne pas savoir de quoi son sort est capable.
##
## Régler des paramètres n'aurait pas suffi : une nappe reste une nappe qu'elle
## soit rouge ou bleue. Ce qu'il fallait, c'est une FORME et un MOUVEMENT par
## sort. Une onde de choc se propage vers l'extérieur, un mur monte par blocs
## décalés, des plaques de givre se posent en claquant. Ces trois gestes ne se
## paramètrent pas l'un depuis l'autre.
##
## ── CE QU'UNE SIGNATURE DOIT RESPECTER ───────────────────────────────────
##
## La ligne claire ne connaît ni dégradé, ni volume, ni lueur. Deux surfaces de
## la même couleur y sont indiscernables. Une signature ne peut donc pas
## compter sur l'ombrage pour se distinguer : tout passe par la SILHOUETTE et
## par le RYTHME. C'est une contrainte, et c'est une bonne — on reconnaît les
## sorts du coin de l'oeil, même superposés, même en filtre monochrome.
##
## ── DEUX DURÉES DE VIE ───────────────────────────────────────────────────
##
## Une signature attachée à une `ZoneEffet` vit aussi longtemps que la zone, qui
## la fait disparaître. Une signature autonome — une onde de choc, un impact —
## se donne une durée et se libère elle-même. Le champ `duree` distingue les
## deux : zéro veut dire « quelqu'un d'autre me tient ».

## Le catalogue. Une entrée par geste, pas par sort : deux sorts qui font
## vraiment le même geste ont le droit de partager, mais il faut alors pouvoir
## le dire à voix haute.
enum Genre {
	NAPPE,             ## repli : la flaque d'autrefois, pour ce qui n'a pas encore de geste
	ONDE_DE_CHOC,      ## un anneau de blocs chassé vers l'extérieur — répulsion
	SPIRALE,           ## des éclats qui convergent en tournant — attraction
	BRASIER_MURAL,     ## un vrai mur de blocs qui montent en désordre
	BRAISE_AU_SOL,     ## des plaques ardentes qui crépitent et s'affaissent
	PLAQUES_DE_GIVRE,  ## des hexagones qui se posent en claquant, puis se fendent
	ECLATS_DE_GIVRE,   ## des esquilles projetées en éventail
	REMPART,           ## des panneaux qui se dressent autour du lanceur
	PETALES,           ## des lames qui montent en tournant — soin
	TOTEM_VIVANT,      ## un fût qui pousse, ceint d'anneaux qui tournent
	DISSOLUTION,       ## des fragments qui s'écartent et s'effacent — ombre
	COMETE,            ## un noyau qui tourne, traîné de braises — projectile de feu
	ESQUILLE,          ## un éclat anguleux qui vrille — projectile d'ombre
	FILET,             ## un lien tendu, parcouru de perles — vol de vie
	ANNEAUX_LIES,      ## deux anneaux qui échangent leurs places — permutation
	SILLAGE,           ## une trace droite laissée derrière une charge
	MANNEQUIN,         ## une silhouette qui clignote et appelle — leurre
	PORTE_D_OMBRE,     ## un cadre qui s'ouvre puis claque — téléportation
}

## Épaisseur commune des pièces plates. Assez pour que le contour d'écran les
## souligne : une plaque d'un millimètre n'existe pas pour un détecteur de bord.
const EPAISSEUR: float = 0.14

var couleur: Color = Color.WHITE
## Ce que le sort occupe : rayon en x, hauteur en y, longueur en z. Chaque
## signature lit ce dont elle a besoin et ignore le reste.
var dimensions: Vector3 = Vector3.ONE
## Durée de vie propre. Zéro : c'est l'appelant qui tient la signature.
var duree: float = 0.0

var _age: float = 0.0
var _materiaux: Array[StandardMaterial3D] = []


static func cree(genre: Genre, p_couleur: Color, p_dimensions: Vector3,
		p_duree: float = 0.0) -> SpellSignature:
	var signature: SpellSignature = SignatureRegistry.instancie(genre)
	signature.name = "Signature"
	signature.couleur = p_couleur
	signature.dimensions = p_dimensions
	signature.duree = p_duree
	return signature


func _ready() -> void:
	monte()


func _process(delta: float) -> void:
	_age += delta
	# Une progression normalisée plutôt qu'un âge en secondes : une signature
	# doit faire le même geste qu'elle dure une seconde ou six, sinon régler la
	# durée d'un sort dans l'inspecteur casserait son animation.
	var part: float = 1.0 if duree <= 0.0 else clampf(_age / duree, 0.0, 1.0)
	anime(part, delta)

	if duree > 0.0:
		# Les deux derniers dixièmes servent à s'effacer : disparaître d'un coup
		# donne l'impression d'un bug, pas d'une fin.
		fondu(1.0 - smoothstep(0.8, 1.0, part))
		if part >= 1.0:
			queue_free()


# ── À redéfinir ───────────────────────────────────────────────────────────

## Construit la géométrie. Appelée une fois, à l'entrée dans l'arbre.
func monte() -> void:
	pass


## Le geste. `part` va de 0 à 1 sur la durée de vie ; il vaut 1 en permanence
## pour une signature tenue par quelqu'un d'autre.
func anime(_part: float, _delta: float) -> void:
	pass


# ── Fabrique commune ──────────────────────────────────────────────────────

## Opacité d'ensemble. La zone qui nous tient s'en sert pour nous estomper.
func fondu(part: float) -> void:
	for mat: StandardMaterial3D in _materiaux:
		var base: float = mat.get_meta(&"alpha_base", 0.34)
		var voulu: float = base * clampf(part, 0.0, 1.0)
		mat.albedo_color.a = voulu
		# Une pièce opaque doit repasser en transparence pour s'effacer, sinon
		# elle disparaît d'un coup au lieu de s'estomper.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if voulu >= 0.999 \
			else BaseMaterial3D.TRANSPARENCY_ALPHA


## Un bloc, l'unité de base de presque toutes les signatures.
##
## Des boîtes et non des sphères : une arête franche donne au contour d'écran de
## quoi tracer, là où une sphère lui offre un dégradé continu qu'il refuse de
## souligner. C'est la même raison qui fait que le décor du jeu est cubique.
func bloc(taille: Vector3, alpha: float = 0.5) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	return _habille(mesh, alpha)


func plaque(cote: float, alpha: float = 0.45) -> MeshInstance3D:
	return bloc(Vector3(cote, EPAISSEUR, cote), alpha)


func pointe(rayon: float, hauteur: float, alpha: float = 0.5) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = rayon
	mesh.height = hauteur
	# Peu de côtés : une pointe à trente-deux facettes redevient un cône lisse,
	# donc un dégradé. Six se lit comme un éclat taillé.
	mesh.radial_segments = 6
	return _habille(mesh, alpha)


func fut(rayon: float, hauteur: float, cotes: int = 6,
		alpha: float = 0.4) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = rayon
	mesh.bottom_radius = rayon
	mesh.height = hauteur
	mesh.radial_segments = cotes
	return _habille(mesh, alpha)


## Un anneau plat, fait de segments : un tore lisse n'a pas d'arête, donc pas
## de trait. Les segments lui en donnent, et permettent de l'ouvrir en morceaux.
func anneau(rayon: float, epaisseur: float, segments: int,
		alpha: float = 0.5) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var corde: float = TAU * rayon / float(segments) * 0.82
	for i: int in segments:
		var angle: float = TAU * float(i) / float(segments)
		var piece := bloc(Vector3(corde, EPAISSEUR, epaisseur), alpha)
		piece.position = Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon)
		piece.rotation.y = -angle
		add_child(piece)
		out.append(piece)
	return out


## Le matériau commun : non éclairé, translucide, émissif.
##
## Non éclairé parce qu'une zone est de la LUMIÈRE et non une surface :
## l'éclairer lui donnerait un dégradé, c'est-à-dire la troisième valeur qu'on
## s'interdit partout ailleurs.
func _habille(mesh: Mesh, alpha: float) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh

	# LES PIÈCES PORTANTES SONT OPAQUES.
	#
	# C'était le défaut de l'ancienne couche : tout était translucide, et sur le
	# sol clair du jeu un voile à 40 % ne se voyait tout simplement pas. Pire, le
	# contour d'écran ne souligne que des ruptures de luminance — une forme
	# à demi transparente n'en produit aucune, donc elle n'était même pas
	# dessinée. Les sorts se noyaient dans le décor.
	#
	# La ligne claire veut des aplats : une forme pleine, un bord franc, un
	# trait autour. On ne garde la transparence que pour les pièces
	# d'ambiance — sillages, anneaux au sol — qui doivent laisser voir le jeu
	# dessous.
	var portante: bool = alpha >= 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if portante:
		alpha = 1.0
	mat.albedo_color = Color(couleur.r, couleur.g, couleur.b, alpha)
	mat.emission_enabled = true
	mat.emission = couleur
	mat.emission_energy_multiplier = 0.35 if portante else 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if portante \
		else BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# L'alpha de départ est mémorisé sur le matériau : le fondu multiplie cette
	# valeur au lieu de l'écraser, donc une pièce discrète le reste.
	mat.set_meta(&"alpha_base", alpha)
	piece.material_override = mat
	_materiaux.append(mat)
	return piece


## Une teinte plus claire, pour les pièces qui doivent ressortir sur les autres.
## Deux valeurs, comme le décor : la vive et la sourde, jamais un dégradé entre.
func vive() -> Color:
	return couleur.lightened(0.45)
