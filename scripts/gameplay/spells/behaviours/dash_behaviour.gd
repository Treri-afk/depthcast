class_name DashBehaviour
extends SpellBehaviour
## Charge en avant, en traversant et en blessant.
##
## C'est une attaque, pas un sprint : elle inflige des dégâts sur son passage
## et bouscule ce qu'elle traverse. Le contrôle est confisqué le temps de la
## charge, ce qui la rend engageante — on ne peut pas l'annuler.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var plat: Vector3 = ctx.direction_au_sol(direction)
	var origine: Vector3 = ctx.joueur.global_position
	ctx.joueur.charge(plat, effet.distance)

	var touches: Array = []
	for id: int in ctx.monstres:
		var avatar: MonsterAvatar = ctx.monstres[id]
		if not is_instance_valid(avatar):
			continue
		var vers: Vector3 = avatar.global_position - origine
		vers.y = 0.0
		var le_long: float = vers.dot(plat)
		if le_long < 0.0 or le_long > effet.distance:
			continue
		if (vers - plat * le_long).length() <= effet.rayon:
			touches.append(id)
			avatar.repousse(plat * 12.0)

	ctx.degats(slot_index, effet.degats, touches)
	ctx.frappe_objets_devant(origine, plat, effet.distance, deg_to_rad(28.0), effet.degats)
	ctx.fx.anneau(origine, 2.0, couleur)
	ctx.fx.eclair(origine + Vector3(0, 1.0, 0), couleur, 0.2, 4.0, 8.0)
