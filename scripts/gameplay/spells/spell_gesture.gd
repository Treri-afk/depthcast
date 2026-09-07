class_name SpellGesture
extends RefCounted
## Pose la signature d'un sort dans le monde.
##
## Un seul endroit, appelé par tous les comportements. Avant, chacun décidait
## s'il en posait une et avec quelles dimensions : cinq comportements avaient
## été oubliés, et leurs sorts s'affichaient encore avec l'anneau générique.
## Rassembler la décision ici rend l'oubli impossible.

## Taille de repli quand la Resource ne déclare aucune géométrie.
##
## Beaucoup d'effets laissent `rayon` et `largeur` à zéro : ils n'en avaient pas
## besoin tant que le visuel était un anneau. Une signature, elle, a besoin
## d'une emprise — sans repli, la moitié des sorts se dessineraient gros comme
## un poing.
const RAYON_MINIMAL: float = 2.4


## Pose le geste du sort à un endroit du monde, et retourne la signature — ou
## `null` si l'effet n'en déclare pas.
##
## `duree` à zéro laisse la signature vivre jusqu'à ce que l'appelant la libère.
static func pose(ctx: SpellContext, effet: SpellEffect, couleur: Color,
		ou: Vector3, duree: float = 0.6,
		orientation: float = 0.0) -> SpellSignature:
	if effet.signature == SpellSignature.Genre.NAPPE:
		return null
	var geste := SpellSignature.cree(effet.signature, couleur,
		dimensions_de(effet), duree)
	geste.position = ou
	geste.rotation.y = orientation
	ctx.monde.add_child(geste)
	return geste


## L'emprise d'un effet, lue dans ses données et complétée quand elles se
## taisent. `x` est le rayon, `y` la hauteur ou l'angle, `z` la portée.
static func dimensions_de(effet: SpellEffect) -> Vector3:
	var rayon: float = effet.rayon
	if rayon <= 0.0:
		rayon = maxf(effet.largeur * 0.5, RAYON_MINIMAL)
	var hauteur: float = effet.angle if effet.angle > 0.0 else 2.4
	var portee: float = maxf(effet.portee, effet.distance)
	return Vector3(rayon, hauteur, portee)
