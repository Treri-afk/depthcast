class_name SpellSigil
extends Node3D
## Le cercle d'invocation qui s'ouvre devant le bâton.
##
## ── CE QU'IL RÉPARE ──────────────────────────────────────────────────────
##
## Un sort partait de nulle part. On appuyait, un effet apparaissait à dix
## mètres, et rien entre les deux ne disait que c'était NOUS. Le cercle comble ce
## vide : il naît au bout du bâton, tourne le temps de l'invocation, et le sort
## en sort. La chaîne devient lisible — geste, cercle, effet.
##
## ── DEUX COUCHES, DEUX SENS ──────────────────────────────────────────────
##
## Le tracé est dessiné par `SigilFactory` en deux images : le pourtour et le
## cœur. Elles tournent en sens contraire. Un seul disque qui tourne se lit comme
## une roue ; deux qui se contrarient se lisent comme un mécanisme — et c'est
## toute la différence entre « ça bouge » et « ça calcule ».
##
## ── POURQUOI IL EST FIXE PAR SORT ────────────────────────────────────────
##
## Le tracé est tiré du nom du sort. Boule de Feu a donc toujours exactement le
## même cercle, partout et pour tout le monde. C'est ce qui permet de
## l'apprendre : au bout de quelques heures on reconnaît un sort à son cercle
## avant même d'en voir l'effet.

## Côté du quad, en mètres. Le cercle est accroché au bâton, donc à un peu plus
## d'un mètre de l'oeil : à cette distance chaque centimètre compte double, et un
## premier essai deux fois plus grand cachait ce qu'on visait.
const COTE: float = 0.86

var couleur: Color = Color.WHITE
var duree: float = 0.42

var _exterieur: MeshInstance3D = null
var _coeur: MeshInstance3D = null
var _materiaux: Array[StandardMaterial3D] = []
var _age: float = 0.0


static func cree(effet: SpellEffect, p_couleur: Color,
		p_duree: float) -> SpellSigil:
	var sceau := SpellSigil.new()
	sceau.name = "Diagramme"
	sceau.couleur = p_couleur
	sceau.duree = maxf(p_duree, 0.12)

	var couches: Array[ImageTexture] = SigilFactory.couches(effet)
	sceau._exterieur = sceau._quad(couches[0], COTE)
	# Le cœur légèrement en avant : deux quads coplanaires se disputent le même
	# pixel et clignotent selon l'angle de vue.
	sceau._coeur = sceau._quad(couches[1], COTE * 0.98)
	sceau._coeur.position.z = 0.004
	sceau.add_child(sceau._exterieur)
	sceau.add_child(sceau._coeur)
	return sceau


func _process(delta: float) -> void:
	_age += delta
	var part: float = clampf(_age / duree, 0.0, 1.0)

	# OUVERTURE SÈCHE, SORTIE EN FONDU.
	#
	# Le cercle doit être là AVANT le sort, pas en même temps : c'est lui qui
	# annonce. Il atteint donc sa taille pleine dans le premier tiers, et ne
	# s'efface qu'une fois le sort parti.
	var ouvre: float = smoothstep(0.0, 0.33, part)
	scale = Vector3.ONE * ouvre

	if _exterieur != null:
		_exterieur.rotation.z -= delta * 2.1
	if _coeur != null:
		_coeur.rotation.z += delta * 3.3

	# La sortie se fait en RELEVANT LE SEUIL de découpe : le tracé se dissout
	# par les traits les plus fins d'abord, au lieu de pâlir d'un bloc. Un fondu
	# est impossible ici — voir la note sur la découpe dans `_quad()` — et la
	# dissolution est de toute façon plus juste pour un sceau qui se referme.
	var reste: float = 1.0 - smoothstep(0.62, 1.0, part)
	for mat: StandardMaterial3D in _materiaux:
		mat.alpha_scissor_threshold = lerpf(1.05, 0.35, reste)

	if part >= 1.0:
		queue_free()


## Un quad non éclairé portant une couche du tracé.
##
## Non éclairé et sans ombre : le cercle est de la LUMIÈRE, pas une surface.
## L'éclairer lui donnerait un dégradé, c'est-à-dire la troisième valeur qu'on
## s'interdit partout ailleurs — et, collé à la caméra, il jetterait une ombre
## énorme en travers de la salle.
func _quad(texture: Texture2D, cote: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(cote, cote)
	var piece := MeshInstance3D.new()
	piece.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	# Éclairci, et émissif franchement.
	#
	# Le tracé se lit surtout sur le ciel, qui est la surface la plus sombre du
	# jeu : à la teinte nue d'une école sourde comme l'Ombre, il disparaissait
	# dedans. Un sceau d'invocation est une lumière, pas un objet peint.
	mat.albedo_color = couleur.lightened(0.35)
	mat.emission_enabled = true
	mat.emission = couleur.lightened(0.2)
	mat.emission_energy_multiplier = 1.8
	# DÉCOUPE ALPHA, ET NON FONDU ALPHA.
	#
	# Le post-traitement est un quad plein écran de priorité 100 : il repeint
	# l'image avec la capture faite AVANT la passe transparente. Tout ce qui est
	# transparent est donc dessiné, puis recouvert — le diagramme existait bel et
	# bien dans la scène, à la bonne place, et restait invisible.
	#
	# En découpe, le tracé passe dans la passe OPAQUE : il est capturé, donc
	# affiché, et il reçoit au passage la trame et le contour comme le reste du
	# jeu. C'est aussi plus juste en ligne claire — un trait est là ou il n'y est
	# pas, il n'est jamais à moitié là.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Le tracé est fin : sans mipmaps il fourmille dès que le cercle tourne.
	# Elles sont générées par la fabrique, APRÈS le tracé — en réclamer le
	# filtrage sur une image qui n'en a pas donne, selon le pilote, une texture
	# noire ou rien du tout.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	piece.material_override = mat
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_materiaux.append(mat)
	return piece
