class_name DustMotes
extends GPUParticles3D
## La poussière du donjon.
##
## Des particules GPU, et pas un shader plein écran : chaque grain ne couvre que
## quelques pixels, alors qu'un volume plein écran paie le taux de remplissage
## sur CHAQUE pixel de l'image. À nombre égal de grains visibles, les particules
## coûtent un ordre de grandeur de moins.
##
## Et pas de physique du tout. Ni collision, ni attracteur, ni réaction au
## souffle : tout est calculé sur la carte graphique, le processeur n'y touche
## jamais. Le seul travail par frame est une affectation de position — la boîte
## d'émission suit la caméra pour qu'il y ait toujours de la poussière autour de
## soi, sans jamais en simuler ailleurs.
##
## `amount` est dans la palette : si ça coûte trop cher sur une machine, ça se
## baisse sans toucher au code.

const COTE: float = 20.0
const HAUTEUR: float = 9.0

var cible: Node3D = null


static func cree(suit: Node3D) -> DustMotes:
	var poussiere := DustMotes.new()
	poussiere.name = "Poussiere"
	poussiere.cible = suit
	var p: Palette = Content.palette

	poussiere.amount = p.poussiere_grains
	poussiere.lifetime = 9.0
	# Répartis dès la première frame : sans ça la salle est vide pendant neuf
	# secondes, le temps que le premier cycle se remplisse.
	poussiere.preprocess = 9.0
	# En espace MONDE : les grains dérivent où ils sont nés. Collés au repère de
	# la caméra, ils suivraient le joueur et ressembleraient à de la saleté sur
	# l'objectif plutôt qu'à de la poussière en suspension.
	poussiere.local_coords = false
	poussiere.visibility_aabb = AABB(Vector3(-COTE, -HAUTEUR, -COTE),
		Vector3(COTE * 2.0, HAUTEUR * 2.0, COTE * 2.0))
	poussiere.process_material = _mouvement()
	poussiere.draw_pass_1 = _grain(p)
	return poussiere


func _process(_delta: float) -> void:
	# Tout le travail par frame tient ici. La boîte d'émission suit la caméra ;
	# les grains, eux, restent où ils sont.
	if cible != null and is_instance_valid(cible):
		global_position = cible.global_position


static func _mouvement() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(COTE * 0.5, HAUTEUR * 0.5, COTE * 0.5)
	# Une chute très lente, presque nulle : de la poussière en suspension ne
	# tombe pas, elle flotte. Une gravité franche en ferait de la neige.
	mat.gravity = Vector3(0, -0.09, 0)
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.16
	mat.direction = Vector3(0.3, -0.2, 0.1)
	mat.spread = 180.0
	mat.damping_min = 0.0
	mat.damping_max = 0.05
	mat.scale_min = 0.5
	mat.scale_max = 1.6
	# La dérive latérale vient de la turbulence, pas d'un calcul par grain côté
	# processeur : elle est évaluée dans le nuanceur de particules.
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.14
	mat.turbulence_noise_scale = 2.2
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.25
	return mat


static func _grain(p: Palette) -> QuadMesh:
	var grain := QuadMesh.new()
	grain.size = Vector2(0.035, 0.035)

	var mat := StandardMaterial3D.new()
	# Non éclairée et orientée vers la caméra : un grain de poussière n'a ni
	# face ni ombre, et l'éclairer le ferait disparaître dans les salles sombres
	# — c'est-à-dire partout.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = p.poussiere
	# Pas d'écriture de profondeur : des milliers de quads transparents qui se
	# trient entre eux coûteraient bien plus que de les dessiner.
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	grain.material = mat
	return grain
