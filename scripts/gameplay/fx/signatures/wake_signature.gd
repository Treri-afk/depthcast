class_name WakeSignature
extends SpellSignature
## RUÉE — un sillage laissé le long de la charge.
##
## La charge est le seul sort où le LANCEUR est le projectile. Son visuel ne
## peut donc pas être une forme posée quelque part : c'est une trace laissée
## derrière, qui dit d'où l'on vient et à quelle vitesse.
##
## Des lames couchées, perpendiculaires à la course, qui s'écartent latéralement
## en s'effaçant. Rien à voir avec l'onde de choc, qui part d'un point et fait
## le tour : celle-ci est droite et n'a qu'un sens.

const LAMES: int = 12


func monte() -> void:
	var distance: float = maxf(dimensions.z, 3.0)
	for i: int in LAMES:
		var t: float = float(i) / float(LAMES - 1)
		# Serrées au départ, espacées à l'arrivée : c'est ce qui fait lire une
		# accélération plutôt qu'un trait uniforme.
		var d: float = distance * t * t
		var lame := bloc(Vector3(1.5 - t * 0.7, 0.16, 0.2), 0.55 - t * 0.3)
		lame.position = Vector3(0, 0.5 + t * 0.9, -d)
		add_child(lame)
		lame.set_meta(&"t", t)
		lame.set_meta(&"repos", lame.position)
		# Alternées à gauche et à droite : symétriques, elles feraient une
		# échelle ; alternées, elles font un remous.
		lame.set_meta(&"cote", 1.0 if i % 2 == 0 else -1.0)


func anime(part: float, _delta: float) -> void:
	for enfant: Node in get_children():
		var lame := enfant as MeshInstance3D
		if lame == null:
			continue
		var t: float = float(lame.get_meta(&"t"))
		var repos: Vector3 = lame.get_meta(&"repos")
		var cote: float = float(lame.get_meta(&"cote"))
		# Les lames du fond s'effacent en premier : le sillage se résorbe
		# depuis l'origine, comme une trace qui se referme.
		var vie: float = clampf((part - t * 0.25) / 0.75, 0.0, 1.0)

		lame.position = repos + Vector3(cote * vie * 1.2, vie * 0.5, 0)
		lame.rotation.z = cote * vie * 0.9
		lame.scale = Vector3(1.0 - vie * 0.7, 1.0, 1.0)
