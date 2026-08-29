class_name MonsterSync
extends Node
## Réplique le corps d'un monstre, du host vers les clients.
##
## Même principe que pour les avatars, avec une autorité qui ne change jamais :
## le host. Les monstres sont le cas d'école de l'état autoritaire — deux
## machines qui simulent chacune leur intelligence artificielle divergent en
## quelques secondes, et les joueurs se mettent à tirer sur des créatures qui ne
## sont pas là.
##
## Les clients ne font PAS tourner de cerveau. Ce n'est pas une optimisation :
## c'est ce qui garantit qu'il n'existe qu'une seule vérité sur la position d'un
## monstre, et donc qu'un coup porté chez l'un porte aussi chez l'autre.

const TAUX: float = 15.0
const SOUPLESSE: float = 16.0

var corps: MonsterAvatar = null

var _restant: float = 0.0
var _position_visee: Vector3 = Vector3.ZERO
var _lacet_vise: float = 0.0
var _recu: bool = false


static func cree(pour: MonsterAvatar) -> MonsterSync:
	var sync := MonsterSync.new()
	sync.name = "Sync"
	sync.corps = pour
	# Toujours le host : il n'y a rien à négocier sur qui simule les monstres.
	sync.set_multiplayer_authority(1)
	return sync


func _physics_process(delta: float) -> void:
	if corps == null or not is_instance_valid(corps) or not Net.en_ligne():
		return
	if is_multiplayer_authority():
		_restant -= delta
		if _restant <= 0.0:
			_restant = 1.0 / TAUX
			_recois.rpc(corps.global_position, corps.rotation.y)
	elif _recu:
		var part: float = clampf(delta * SOUPLESSE, 0.0, 1.0)
		corps.global_position = corps.global_position.lerp(_position_visee, part)
		corps.rotation.y = lerp_angle(corps.rotation.y, _lacet_vise, part)


@rpc("authority", "call_remote", "unreliable")
func _recois(position: Vector3, lacet: float) -> void:
	_position_visee = position
	_lacet_vise = lacet
	if not _recu:
		_recu = true
		corps.global_position = position
