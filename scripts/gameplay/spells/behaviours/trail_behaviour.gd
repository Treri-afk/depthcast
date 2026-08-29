class_name TrailBehaviour
extends SpellBehaviour
## Le sol s'embrase sous les pas pendant un moment.
##
## Le comportement ne pose pas les flaques lui-même : il arme un état sur le
## joueur, et c'est le semeur qui les dépose au fil des déplacements. Un sort
## qui s'étale dans le temps ne peut pas se résoudre en un seul appel.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	ctx.joueur.arme_trainee(effet, couleur, slot_index)
