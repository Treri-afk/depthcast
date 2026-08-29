class_name DrainBehaviour
extends ProjectileBehaviour
## Un projectile qui rend une part de ses dégâts en soin.
##
## Toute la différence tient dans `_a_touche` : c'est exactement ce que
## l'héritage doit servir à exprimer.


func _a_touche(ctx: SpellContext, slot_index: int, effet: SpellEffect) -> void:
	ctx.soin(slot_index, int(effet.degats * effet.ratio_soin))
