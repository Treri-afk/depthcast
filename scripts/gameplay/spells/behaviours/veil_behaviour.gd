class_name VeilBehaviour
extends SpellBehaviour
## Les monstres perdent notre trace pendant un moment.
##
## Un outil de désengagement : il ne fait aucun dégât, il rend une situation
## perdue survivable.


func lance(ctx: SpellContext, _slot_index: int, effet: SpellEffect,
		_couleur: Color, _direction: Vector3) -> void:
	ctx.joueur.voile(effet.duree)
	for id: int in ctx.monstres:
		var avatar: MonsterAvatar = ctx.monstres[id]
		if is_instance_valid(avatar):
			avatar.aveugle = true

	ctx.monde.get_tree().create_timer(effet.duree).timeout.connect(
		func() -> void:
			for id: int in ctx.monstres:
				var avatar: MonsterAvatar = ctx.monstres[id]
				if is_instance_valid(avatar):
					avatar.aveugle = false
	)
