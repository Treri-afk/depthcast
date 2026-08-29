class_name DamageIndicator
extends Control
## Retour de dégâts : un voile rouge, et une flèche qui dit d'où vient le coup.
##
## En vue subjective, encaisser 17 dégâts d'une brute hors champ sans aucune
## indication est simplement illisible. La flèche ne dit pas quoi faire — elle
## dit où regarder, et c'est au joueur de décider.

const DUREE_VOILE: float = 0.45
const DUREE_FLECHE: float = 1.1
const RAYON: float = 140.0

var joueur: PlayerAvatar = null

var _voile: ColorRect
## Chaque marque : {angle, restant}. L'angle est relatif au regard, donc il
## suit la caméra quand le joueur se retourne.
var _marques: Array[Dictionary] = []
var _intensite_voile: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_voile = ColorRect.new()
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.color = Color(0.75, 0.12, 0.18, 0.0)
	add_child(_voile)

	EventBus.player_damaged.connect(_sur_blessure)


func _sur_blessure(_player_id: int, degats: int, origine: Vector3) -> void:
	# Un coup plus fort assombrit plus. Sans ça, une égratignure et une charge
	# de brute se ressemblent, et le voile perd toute valeur d'information.
	_intensite_voile = minf(1.0, _intensite_voile + float(degats) / 45.0)

	if origine == Vector3.ZERO or joueur == null:
		return
	_marques.append({"origine": origine, "restant": DUREE_FLECHE})


func _process(delta: float) -> void:
	if _intensite_voile > 0.0:
		_intensite_voile = maxf(0.0, _intensite_voile - delta / DUREE_VOILE)
		_voile.color.a = _intensite_voile * 0.32

	var encore: Array[Dictionary] = []
	for marque: Dictionary in _marques:
		marque["restant"] = float(marque["restant"]) - delta
		if float(marque["restant"]) > 0.0:
			encore.append(marque)
	_marques = encore

	queue_redraw()


func _draw() -> void:
	if _marques.is_empty() or joueur == null:
		return
	var centre: Vector2 = size * 0.5

	for marque: Dictionary in _marques:
		var angle: float = _angle_relatif(marque["origine"])
		var reste: float = float(marque["restant"]) / DUREE_FLECHE
		var couleur := Color(0.9, 0.2, 0.25, reste)

		# Un arc plutôt qu'une flèche : il indique une direction sans prétendre
		# à une position exacte, ce qui est honnête — on sait d'où ça vient,
		# pas exactement où c'est.
		draw_arc(centre, RAYON, angle - 0.28, angle + 0.28, 24, couleur, 7.0, true)


## Angle de l'arc, en repère écran : 0 en haut, positif vers la droite.
##
## Il se recalcule à chaque image plutôt qu'au moment du coup : quand le joueur
## se retourne, la marque tourne avec lui et continue de désigner la vraie
## provenance.
func _angle_relatif(origine: Vector3) -> float:
	var vers: Vector3 = origine - joueur.global_position
	vers.y = 0.0
	if vers.length_squared() < 0.001:
		return 0.0
	vers = vers.normalized()

	var avant: Vector3 = -joueur.global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized()
	var droite: Vector3 = joueur.global_transform.basis.x
	droite.y = 0.0
	droite = droite.normalized()

	return atan2(vers.dot(droite), vers.dot(avant)) - PI * 0.5
