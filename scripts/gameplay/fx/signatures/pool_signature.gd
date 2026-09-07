class_name PoolSignature
extends SpellSignature
## LE REPLI — la flaque d'autrefois.
##
## Elle reste pour les effets qui n'ont pas encore reçu leur geste propre : un
## sort sans signature doit s'afficher, pas disparaître. Mais tout sort qui
## garde celle-ci est un sort qu'on n'a pas fini.

var _bord: Array[MeshInstance3D] = []


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.5)
	var disque := fut(rayon, EPAISSEUR, 12, 0.3)
	disque.position.y = EPAISSEUR * 0.5
	add_child(disque)
	_bord = anneau(rayon, 0.22, 14, 0.5)
	for p: MeshInstance3D in _bord:
		p.position.y = 0.1


func anime(_part: float, delta: float) -> void:
	rotation.y += delta * 0.5
