class_name FrostShardsSignature
extends SpellSignature
## BISE GLACIALE — des esquilles projetées en éventail.
##
## Un cône de souffle est invisible par nature : ce qu'on doit voir, ce sont les
## ÉCLATS qu'il emporte. Ils partent serrés, s'écartent, vrillent, et se
## dispersent au bout de la portée. Le cône n'est jamais dessiné — seulement
## rempli.

const ESQUILLES: int = 26


func monte() -> void:
	var portee: float = maxf(dimensions.z, 3.0)
	var demi_angle: float = deg_to_rad(clampf(dimensions.y, 12.0, 80.0)) * 0.5

	for i: int in ESQUILLES:
		var e := pointe(0.17, 0.85, 0.62)
		# Couchée vers l'avant : une pointe verticale se lirait comme un pic
		# planté, pas comme un éclat en vol.
		e.rotation.x = PI * 0.5
		add_child(e)

		# Direction tirée dans le cône, en racine pour que la densité soit
		# uniforme sur la section et non concentrée au centre.
		var t: float = float(i) / float(ESQUILLES - 1)
		var lacet: float = (t * 2.0 - 1.0) * demi_angle
		var tangage: float = sin(float(i) * 2.7) * demi_angle * 0.55
		e.set_meta(&"cap", Vector3(sin(lacet), sin(tangage) * 0.5, cos(lacet)).normalized())
		e.set_meta(&"vitesse", portee * (0.72 + fmod(float(i) * 0.31, 1.0) * 0.5))
		e.set_meta(&"vrille", (fmod(float(i) * 0.53, 1.0) - 0.5) * 22.0)


func anime(part: float, _delta: float) -> void:
	# Le souffle est instantané : les éclats sont déjà lancés quand on les voit.
	var course: float = 1.0 - pow(1.0 - part, 1.7)
	for enfant: Node in get_children():
		var e := enfant as MeshInstance3D
		if e == null:
			continue
		var cap: Vector3 = e.get_meta(&"cap")
		e.position = cap * (float(e.get_meta(&"vitesse")) * course) \
			+ Vector3(0, 1.1 - course * course * 0.6, 0)
		e.rotation = Vector3(PI * 0.5 + cap.y,
			atan2(cap.x, cap.z), float(e.get_meta(&"vrille")) * course)
		e.scale = Vector3.ONE * (0.5 + course * 0.8)
