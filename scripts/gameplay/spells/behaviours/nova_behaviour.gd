class_name NovaBehaviour
extends SpellBehaviour
## Explose autour du lanceur, une seule fois. Touche tout dans un rayon, sans
## avoir besoin de viser — ce qui en fait la réponse aux encerclements.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var centre: Vector3 = ctx.joueur.global_position
	ctx.degats(slot_index, effet.degats, ctx.monstres_dans_rayon(centre, effet.rayon))
	ctx.souffle_sur_objets(centre, effet.rayon, 14.0, true, effet.degats)
	ctx.fx.anneau(centre, effet.rayon, couleur)
