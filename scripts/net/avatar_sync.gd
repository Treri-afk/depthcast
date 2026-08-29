class_name AvatarSync
extends Node
## Réplique la position et le regard d'un avatar.
##
## Écrit à la main plutôt que confié à un synchroniseur générique, et c'est
## délibéré : on envoie exactement trois nombres, à une cadence qu'on choisit,
## et on peut lire ce qui part sur le réseau dans le fichier qui l'envoie. Une
## ressource de configuration générée aurait caché les deux.
##
## L'autorité d'un avatar est le pair qui le contrôle. Chacun n'annonce que sa
## propre position : personne ne peut déplacer le personnage d'un autre, et ce
## n'est pas une politesse — c'est ce qui empêche un client bricolé de
## téléporter tout le monde.
##
## Le corps distant cesse de calculer sa physique quand le réseau est branché.
## Sa vraie trajectoire est calculée chez son propriétaire ; la recalculer ici
## produirait deux vérités qui divergent, et c'est exactement ce que
## l'architecture host-autoritaire cherche à éviter.

## Envois par seconde. Vingt suffisent largement : l'interpolation comble, et
## doubler la cadence doublerait le trafic pour un gain invisible.
const TAUX: float = 20.0
## Vitesse de rattrapage de la position reçue. Assez vif pour ne pas traîner,
## assez souple pour absorber un paquet en retard sans à-coup.
const SOUPLESSE: float = 14.0

var avatar: PlayerAvatar = null

var _restant: float = 0.0
var _position_visee: Vector3 = Vector3.ZERO
var _lacet_vise: float = 0.0
var _tangage_vise: float = 0.0
var _recu: bool = false


static func cree(pour: PlayerAvatar, peer: int) -> AvatarSync:
	var sync := AvatarSync.new()
	sync.name = "Sync"
	sync.avatar = pour
	# Le chemin du nœud doit être identique sur toutes les machines pour qu'un
	# appel distant arrive à destination. Les avatars sont nommés d'après leur
	# identifiant de joueur, donc il l'est.
	sync.set_multiplayer_authority(peer)
	return sync


func _ready() -> void:
	if avatar == null:
		return
	_position_visee = avatar.global_position
	# Un corps distant n'est plus simulé : sa trajectoire vient du réseau.
	if Net.en_ligne() and not is_multiplayer_authority():
		avatar.set_physics_process(false)


func _physics_process(delta: float) -> void:
	if avatar == null or not is_instance_valid(avatar) or not Net.en_ligne():
		return
	if is_multiplayer_authority():
		_annonce(delta)
	else:
		_rattrape(delta)


func _annonce(delta: float) -> void:
	_restant -= delta
	if _restant > 0.0:
		return
	_restant = 1.0 / TAUX
	_recois.rpc(avatar.global_position, avatar.rotation.y, avatar.tete.rotation.x)


## Rattrapage continu plutôt que téléportation à chaque paquet : à vingt envois
## par seconde, poser brutalement la position ferait avancer les coéquipiers par
## saccades de cinquante millisecondes.
func _rattrape(delta: float) -> void:
	if not _recu:
		return
	var part: float = clampf(delta * SOUPLESSE, 0.0, 1.0)
	avatar.global_position = avatar.global_position.lerp(_position_visee, part)
	avatar.rotation.y = lerp_angle(avatar.rotation.y, _lacet_vise, part)
	avatar.tete.rotation.x = lerp_angle(avatar.tete.rotation.x, _tangage_vise, part)


## Non fiable et non ordonné : une position perdue est remplacée par la suivante
## quarante millisecondes plus tard. La retransmettre coûterait plus cher que ce
## qu'elle vaut, et arriverait périmée.
@rpc("authority", "call_remote", "unreliable")
func _recois(position: Vector3, lacet: float, tangage: float) -> void:
	_position_visee = position
	_lacet_vise = lacet
	_tangage_vise = tangage
	if not _recu:
		# Le tout premier paquet pose la position sans interpoler : sinon un
		# coéquipier qui rejoint traverse la salle en glissant depuis l'origine.
		_recu = true
		avatar.global_position = position
