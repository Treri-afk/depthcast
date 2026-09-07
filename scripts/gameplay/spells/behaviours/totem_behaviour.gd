class_name TotemBehaviour
extends SpellBehaviour
## Balise posée au sol qui soigne tant qu'on reste dedans.
##
## Rien à voir avec un soin instantané : elle demande de tenir une position,
## donc elle se paie en mobilité.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var pos: Vector3 = ctx.joueur.global_position
	var zone := ZoneEffet.cree(ZoneEffet.Forme.SPHERE,
		Vector3(effet.rayon, 0, 0), Vector3(pos.x, 0.6, pos.z))
	zone.duree = effet.duree
	zone.intervalle = effet.intervalle
	zone.soin = effet.soin
	zone.source_player_id = ctx.joueur.player_id
	zone.source_slot = slot_index
	zone.couleur = couleur
	zone.allure = effet.allure
	zone.signature = effet.signature
	ctx.monde.add_child(zone)
