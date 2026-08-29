class_name DecoyBehaviour
extends SpellBehaviour
## Pose un mannequin qui vole l'attention.
##
## Les monstres le poursuivent et ne le frappent pas : c'est du répit acheté,
## pas un allié. Il redirige la menace au lieu de la supprimer.


func lance(ctx: SpellContext, _slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var plat: Vector3 = ctx.direction_au_sol(direction)
	var leurre := Node3D.new()
	leurre.add_to_group("leurre")
	leurre.position = ctx.joueur.global_position + plat * effet.distance
	leurre.add_child(ctx.fx.sphere_lumineuse(0.7, couleur))
	ctx.monde.add_child(leurre)

	# La diversion et son retour sont tenus par le monstre lui-même : le sort
	# n'a pas à mémoriser qui poursuivait qui, et la balise en objet obtient le
	# même comportement sans une ligne en commun avec ce fichier.
	for id: int in ctx.monstres:
		var avatar: MonsterAvatar = ctx.monstres[id]
		if is_instance_valid(avatar):
			avatar.distrait_par(leurre, effet.duree)

	ctx.monde.get_tree().create_timer(effet.duree).timeout.connect(
		func() -> void:
			if is_instance_valid(leurre):
				leurre.queue_free()
	)
