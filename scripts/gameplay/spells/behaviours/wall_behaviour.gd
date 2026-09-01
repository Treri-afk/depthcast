class_name WallBehaviour
extends SpellBehaviour
## Pose une nappe persistante devant soi, perpendiculaire à la visée.
##
## Un vrai mur : il reste, il brûle ce qui le traverse, et il coupe une salle
## en deux. C'est un outil de contrôle d'espace, pas une attaque.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var plat: Vector3 = ctx.direction_au_sol(direction)
	var centre: Vector3 = ctx.joueur.global_position + plat * effet.distance
	centre.y = 1.4

	var zone := ZoneEffet.cree(ZoneEffet.Forme.BOITE,
		Vector3(effet.largeur, 2.8, 0.9), centre, atan2(plat.x, plat.z))
	zone.duree = effet.duree
	zone.intervalle = effet.intervalle
	zone.degats = effet.degats
	zone.source_player_id = ctx.joueur.player_id
	zone.source_slot = slot_index
	zone.couleur = couleur
	zone.allure = effet.allure
	ctx.monde.add_child(zone)
