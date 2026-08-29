class_name ExplosiveProp
extends PropDestructible
## Un tonneau qui rend ce qu'on lui donne.
##
## Il ne meurt pas : il s'amorce. La mèche est courte mais JAMAIS nulle, et
## c'est tout l'intérêt — sans elle une rangée de tonneaux part en une seule
## frame et on ne voit qu'un flash blanc. Avec elle la chaîne se lit, on a le
## temps de reculer, et une réaction en chaîne devient un évènement au lieu d'un
## chiffre de dégâts.
##
## Il ne connaît ni le registre des monstres ni le contexte de sorts : il
## interroge la physique. Une explosion est un évènement physique, et c'est ce
## qui la fait chaîner sans une ligne de plus — un tonneau en trouve un autre
## exactement comme il trouve une caisse.
##
## Comme tout le reste, il ne retire aucun point de vie lui-même : il soumet une
## intention au resolver (R4).

var rayon: float = 6.0
var puissance: float = 26.0
var degats: int = 34
var degats_decor: int = 40
var meche: float = 0.4

## Négatif tant que la mèche n'est pas allumée.
var _meche_restante: float = -1.0
var _lampe: OmniLight3D = null


static func regle(corps: ExplosiveProp, tuning: Tuning) -> void:
	corps.rayon = tuning.tonneau_rayon
	corps.puissance = tuning.tonneau_puissance
	corps.degats = tuning.tonneau_degats
	corps.degats_decor = tuning.tonneau_degats_decor
	corps.meche = tuning.tonneau_meche


## Détruire un tonneau ne le fait pas disparaître : ça allume la mèche.
func _casse() -> void:
	amorce()


func amorce() -> void:
	if _meche_restante >= 0.0:
		return
	_meche_restante = meche
	# Une lampe qui monte : la mèche s'entend mal dans un donjon, elle doit se
	# voir. C'est aussi ce qui éclaire la zone d'où il faut sortir.
	_lampe = OmniLight3D.new()
	_lampe.light_color = Content.palette.tonneau_explosif
	_lampe.omni_range = rayon
	_lampe.light_energy = 0.0
	_lampe.shadow_enabled = false
	add_child(_lampe)


func _process(delta: float) -> void:
	super(delta)
	if _meche_restante < 0.0:
		return

	_meche_restante -= delta
	var avancement: float = 1.0 - clampf(_meche_restante / maxf(meche, 0.01), 0.0, 1.0)
	if _lampe != null:
		_lampe.light_energy = avancement * 6.0
	if _materiau != null:
		_materiau.set_shader_parameter("albedo",
			couleur.lerp(Content.palette.lisere_blanc, avancement))

	if _meche_restante <= 0.0:
		_explose()


func _explose() -> void:
	var centre: Vector3 = global_position
	var parent: Node = get_parent()

	var onde := Souffle.new(centre, rayon, puissance)
	var touches: Dictionary = onde.sur_les_corps_autour(self, Content.tuning,
		degats_decor)
	_blesse(centre, touches)

	if parent != null:
		var fx := FxLibrary.new(parent as Node3D)
		fx.anneau(centre, rayon, Content.palette.tonneau_explosif)
		fx.eclair(centre + Vector3(0, 0.8, 0), Content.palette.tonneau_explosif,
			0.32, 9.0, rayon * 2.4)

	EventBus.explosion_triggered.emit(centre, puissance)
	_projette_des_debris()
	detruit.emit()
	queue_free()


## Le tonneau ne retire pas un point de vie lui-même : il décrit ce qu'il
## voudrait faire, et le resolver arbitre (R4). `source_player_id` vaut -1 —
## personne n'est crédité de ce qu'un tonneau tue.
func _blesse(centre: Vector3, touches: Dictionary) -> void:
	var monstres: Array = touches["monstres"]
	var joueurs: Array = touches["joueurs"]
	if monstres.is_empty() and joueurs.is_empty():
		return

	var intent := EffectIntent.new()
	intent.source_player_id = -1
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.origine = centre
	intent.target_monsters = PackedInt64Array(monstres)
	intent.target_ids = PackedInt64Array(joueurs)
	EffectResolver.submit(intent)
