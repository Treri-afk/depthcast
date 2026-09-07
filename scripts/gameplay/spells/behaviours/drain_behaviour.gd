class_name DrainBehaviour
extends ProjectileBehaviour
## Un projectile qui rend une part de ses dégâts en soin.
##
## Toute la différence tient dans `_a_touche` : c'est exactement ce que
## l'héritage doit servir à exprimer.


func _a_touche(ctx: SpellContext, slot_index: int, effet: SpellEffect) -> void:
	ctx.soin(slot_index, int(effet.degats * effet.ratio_soin))


## Le lien apparaît AU MOMENT DE L'IMPACT, du point touché vers le lanceur.
##
## Pas au lancer : tant que le projectile vole, il n'y a rien à drainer. C'est
## le retour qui est le sujet du sort, et le montrer trop tôt promettrait un
## soin qui n'a pas encore eu lieu.
func _a_l_impact(ctx: SpellContext, effet: SpellEffect, couleur: Color,
		depuis: Vector3) -> void:
	var geste := SpellGesture.pose(ctx, effet, couleur, depuis, 0.45)
	if geste is TetherSignature:
		(geste as TetherSignature).vise(ctx.joueur.global_position + Vector3(0, 1.2, 0))
