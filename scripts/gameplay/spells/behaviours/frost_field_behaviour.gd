class_name FrostFieldBehaviour
extends SpellBehaviour
## Nappe froide au sol : peu de dégâts, gros ralentissement.
##
## Sa valeur n'est pas dans les dégâts mais dans le temps qu'elle achète.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var pos: Vector3 = ctx.joueur.global_position
	var zone := ZoneEffet.cree(ZoneEffet.Forme.SPHERE,
		Vector3(effet.rayon, 0, 0), Vector3(pos.x, 0.5, pos.z))
	zone.duree = effet.duree
	zone.intervalle = effet.intervalle
	zone.degats = effet.degats
	zone.ralentissement = effet.ralentissement
	zone.source_player_id = ctx.joueur.player_id
	zone.source_slot = slot_index
	zone.couleur = couleur
	ctx.monde.add_child(zone)
