class_name ProjectileBehaviour
extends SpellBehaviour
## Part droit devant et s'arrête au premier corps touché.
##
## Sert aussi de base au vol de vie : seule la conclusion diffère, pas la
## trajectoire — d'où l'héritage plutôt qu'un drapeau dans les données.

const VITESSE: float = 34.0
const RAYON: float = 0.35


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var bille := Area3D.new()
	bille.position = ctx.joueur.position_yeux() + direction * 0.8

	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RAYON
	forme.shape = sphere
	bille.add_child(forme)
	bille.add_child(ctx.fx.sphere_lumineuse(RAYON, couleur))
	bille.add_child(ctx.fx.lampe(couleur))
	ctx.monde.add_child(bille)

	var consomme: Array[bool] = [false]
	bille.body_entered.connect(func(corps: Node3D) -> void:
		if consomme[0]:
			return

		# Le décor encaisse aussi : un projectile qui traverse une caisse sans
		# la marquer donne l'impression que rien n'est solide.
		var objet := corps as PropDestructible
		if objet != null:
			consomme[0] = true
			objet.encaisse(effet.degats, bille.global_position)
			bille.queue_free()
			return

		var avatar := corps as MonsterAvatar
		if avatar == null:
			return
		consomme[0] = true
		ctx.degats(slot_index, effet.degats, [avatar.monster_id])
		_a_touche(ctx, slot_index, effet)
		bille.queue_free()
	)

	var arrivee: Vector3 = bille.position + direction * effet.portee
	var tween := ctx.monde.create_tween()
	tween.tween_property(bille, "position", arrivee, effet.portee / VITESSE)
	tween.tween_callback(bille.queue_free)


## Point d'extension : ne fait rien pour un projectile ordinaire.
func _a_touche(_ctx: SpellContext, _slot_index: int, _effet: SpellEffect) -> void:
	pass
