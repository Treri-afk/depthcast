class_name BulwarkSignature
extends SpellSignature
## REMPART — des panneaux qui se dressent autour de celui qu'on protège.
##
## Ni dôme ni bulle : des plaques verticales, espacées, qui montent du sol en
## se rabattant vers l'intérieur. On voit à travers — c'est important, on doit
## continuer à jouer — mais la silhouette dit clairement « abrité ».

const PANNEAUX: int = 7


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	var hauteur: float = maxf(dimensions.y, 1.8)
	for i: int in PANNEAUX:
		var angle: float = TAU * float(i) / float(PANNEAUX)
		var p := bloc(Vector3(rayon * 0.72, hauteur, EPAISSEUR * 1.4), 0.45)
		p.position = Vector3(cos(angle) * rayon, hauteur * 0.5, sin(angle) * rayon)
		p.rotation.y = -angle + PI * 0.5
		add_child(p)
		p.set_meta(&"angle", angle)
		p.set_meta(&"retard", float(i) / float(PANNEAUX) * 0.22)
		p.set_meta(&"hauteur", hauteur)


func anime(part: float, _delta: float) -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	for enfant: Node in get_children():
		var p := enfant as MeshInstance3D
		if p == null:
			continue
		var retard: float = float(p.get_meta(&"retard"))
		var angle: float = float(p.get_meta(&"angle"))
		var hauteur: float = float(p.get_meta(&"hauteur"))
		# Chaque panneau se lève à son tour, en tournant autour du cercle :
		# tous ensemble, ce serait une cage qui tombe du ciel.
		var leve: float = clampf((part - retard) / 0.2, 0.0, 1.0)
		var doux: float = leve * leve * (3.0 - 2.0 * leve)

		p.scale.y = doux
		p.position = Vector3(cos(angle) * rayon, hauteur * 0.5 * doux,
			sin(angle) * rayon)
		# Rabattus vers l'intérieur en fin de course : c'est ce qui fait un abri
		# plutôt qu'une palissade.
		p.rotation = Vector3(0, -angle + PI * 0.5, 0)
		p.rotate_object_local(Vector3.RIGHT, -doux * 0.22)
