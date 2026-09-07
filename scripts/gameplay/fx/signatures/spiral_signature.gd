class_name SpiralSignature
extends SpellSignature
## ATTRACTION — l'inverse exact de l'onde de choc, et ça doit se voir.
##
## Les éclats partent du bord et CONVERGENT en tournant vers le centre, où ils
## s'écrasent les uns sur les autres. Là où la répulsion couche ses blocs vers
## l'extérieur, celle-ci les redresse en approchant : deux gestes opposés, donc
## deux sorts qu'on ne confondra pas même à travers un mur de fumée.

const ECLATS: int = 18
const TOURS: float = 1.35


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	for i: int in ECLATS:
		var eclat := bloc(Vector3(0.22, 0.22, rayon * 0.28), 0.55)
		add_child(eclat)
		eclat.set_meta(&"angle", TAU * float(i) / float(ECLATS))
		# Décalés en hauteur : tous au ras du sol, ils feraient une roue plate.
		eclat.set_meta(&"haut", 0.4 + fmod(float(i) * 0.47, 1.0) * 1.8)

	# Le puits au centre : ce qui aspire doit avoir un fond, sinon les éclats
	# ont l'air de se diriger vers rien.
	var puits := fut(rayon * 0.16, 0.3, 6, 0.5)
	puits.position = Vector3(0, 0.15, 0)
	puits.name = "Puits"
	add_child(puits)


func anime(part: float, _delta: float) -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	# Lent d'abord, avalé à la fin : une aspiration accélère en approchant du
	# centre, exactement l'inverse de la courbe de l'onde de choc.
	var approche: float = pow(part, 2.2)

	for enfant: Node in get_children():
		var piece := enfant as MeshInstance3D
		if piece == null or piece.name == "Puits":
			continue
		var angle: float = float(piece.get_meta(&"angle")) + approche * TAU * TOURS
		var d: float = rayon * (1.0 - approche)
		piece.position = Vector3(cos(angle) * d,
			float(piece.get_meta(&"haut")) * (1.0 - approche * 0.75), sin(angle) * d)
		# Ils se REDRESSENT en arrivant : couchés au bord, dressés au centre.
		piece.rotation = Vector3(approche * PI * 0.5, -angle, 0)
		piece.scale = Vector3(1.0, 1.0, 1.0 - approche * 0.6)

	var puits: Node = get_node_or_null(^"Puits")
	if puits is MeshInstance3D:
		var pulse: float = 1.0 + sin(part * TAU * 3.0) * 0.25 + approche * 1.4
		(puits as MeshInstance3D).scale = Vector3(pulse, 1.0 + approche * 2.0, pulse)
