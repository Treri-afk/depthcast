class_name HealBehaviour
extends SpellBehaviour
## Soin instantané sur soi.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	ctx.soin(slot_index, effet.soin)
	ctx.fx.anneau(ctx.joueur.global_position, 2.2, couleur)
