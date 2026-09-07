class_name PetalsSignature
extends SpellSignature
## SOIN — des lames qui montent en tournant.
##
## Le soin doit MONTER. C'est la seule chose du jeu qui va vers le haut sans
## être une explosion, et c'est ce qui le rend reconnaissable même hors du champ
## de vision : on aperçoit quelque chose s'élever, on sait que quelqu'un soigne.
##
## Des lames plates et non des sphères : une sphère lumineuse est déjà ce que
## font trois autres sorts.

const PETALES: int = 12


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.8)
	for i: int in PETALES:
		var p := bloc(Vector3(0.16, 0.72, 0.05), 0.6)
		add_child(p)
		p.set_meta(&"angle", TAU * float(i) / float(PETALES))
		p.set_meta(&"retard", fmod(float(i) * 0.37, 1.0) * 0.35)
		p.set_meta(&"rayon", rayon * (0.45 + fmod(float(i) * 0.29, 1.0) * 0.55))

	# L'anneau au sol : il dit l'emprise du soin, donc qui en profite. Sans lui
	# on ne sait pas s'il faut se rapprocher.
	for piece: MeshInstance3D in anneau(rayon, 0.18, 16, 0.3):
		piece.position.y = 0.07


func anime(part: float, _delta: float) -> void:
	for enfant: Node in get_children():
		var p := enfant as MeshInstance3D
		if p == null or not p.has_meta(&"angle"):
			continue
		var retard: float = float(p.get_meta(&"retard"))
		var monte: float = clampf((part - retard) / maxf(1.0 - retard, 0.01), 0.0, 1.0)
		var r: float = float(p.get_meta(&"rayon"))
		var angle: float = float(p.get_meta(&"angle")) + monte * 1.6

		p.position = Vector3(cos(angle) * r * (1.0 - monte * 0.35),
			0.2 + monte * 2.3, sin(angle) * r * (1.0 - monte * 0.35))
		p.rotation.y = -angle
		# Elles s'effilent en montant : une lame qui garde sa taille monte comme
		# un ascenseur, une lame qui s'amenuise s'évapore.
		p.scale = Vector3(1.0 - monte * 0.6, 1.0 - monte * 0.3, 1.0)
