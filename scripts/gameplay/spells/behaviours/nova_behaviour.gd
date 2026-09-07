class_name NovaBehaviour
extends SpellBehaviour
## Explose autour du lanceur, une seule fois. Touche tout dans un rayon, sans
## avoir besoin de viser — ce qui en fait la réponse aux encerclements.
##
## Le lanceur EST au centre : le souffle le soulève au lieu de le pousser. Ce
## n'est pas un effet de bord, c'est le meilleur cadeau que ce sort puisse
## faire — un sort défensif qui devient un outil de déplacement dès qu'on y
## pense, sans qu'une seule ligne de règle ait eu à l'autoriser.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var centre: Vector3 = ctx.joueur.global_position
	ctx.degats(slot_index, effet.degats, ctx.monstres_dans_rayon(centre, effet.rayon))
	ctx.souffle(centre, effet.rayon, ctx.tuning.puissance_souffle_nova, true,
		effet.degats)
	if SpellGesture.pose(ctx, effet, couleur, centre, 0.6) == null:
		ctx.fx.anneau(centre, effet.rayon, couleur)
	ctx.fx.eclair(centre + Vector3(0, 1.0, 0), couleur, 0.25, 6.0, effet.rayon * 2.2)
