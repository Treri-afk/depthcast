class_name VeilBehaviour
extends SpellBehaviour
## Les monstres perdent notre trace pendant un moment.
##
## Un outil de désengagement : il ne fait aucun dégât, il rend une situation
## perdue survivable.


func lance(ctx: SpellContext, _slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	# Le seul sort du jeu qui montre une forme humaine avant de la détruire.
	# C'est ce qui le rend lisible d'un coup d'oeil : les autres partent d'un
	# point, celui-ci part d'un corps.
	_disloque(ctx, effet, couleur, ctx.joueur.global_position)
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


func _disloque(ctx: SpellContext, effet: SpellEffect, couleur: Color,
		ou: Vector3) -> void:
	if effet.signature == SpellSignature.Genre.NAPPE:
		return
	var geste := SpellSignature.cree(effet.signature, couleur, Vector3.ONE, 0.7)
	geste.position = ou
	ctx.monde.add_child(geste)
