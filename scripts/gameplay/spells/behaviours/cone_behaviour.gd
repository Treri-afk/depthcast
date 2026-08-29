class_name ConeBehaviour
extends SpellBehaviour
## Souffle en éventail devant soi.
##
## Très différent d'une nova : il faut être orienté. Il récompense le placement
## là où la nova récompense la panique.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var plat: Vector3 = ctx.direction_au_sol(direction)
	var origine: Vector3 = ctx.joueur.global_position
	var demi_angle: float = deg_to_rad(effet.angle * 0.5)

	ctx.degats(slot_index, effet.degats,
		ctx.monstres_dans_cone(origine, plat, effet.portee, demi_angle))
	ctx.frappe_objets_devant(origine, plat, effet.portee, demi_angle, effet.degats)
	ctx.fx.cone(origine, plat, effet.portee, couleur)
	ctx.fx.eclair(origine + plat * (effet.portee * 0.4) + Vector3(0, 1.0, 0),
		couleur, 0.25, 5.0, effet.portee)
