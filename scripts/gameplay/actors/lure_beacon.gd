class_name LureBeacon
extends PropDestructible
## La balise de leurre : le sort du même nom, mais en objet.
##
## Pourquoi un objet et pas un second sort. Un sort dépend du tirage, donc on ne
## peut jamais compter dessus — c'est le sujet du jeu, et c'est très bien. Un
## objet, lui, se garde, se transporte et se pose au moment choisi. C'est un
## outil, pas une chance. Les deux ont leur place.
##
## Elle réutilise entièrement le verbe porter/lancer : aucune seconde mécanique
## d'inventaire n'a été inventée pour elle. Ramasser une balise et ramasser un
## tonneau sont le même geste, et c'est ce qui rend le verbe évident.
##
## Elle ne s'arme QU'UNE FOIS lâchée par un joueur. Sans cette condition, celle
## qui repose au sol dans une salle s'activerait toute seule au premier contact
## avec le plancher, c'est-à-dire à la génération de l'étage.

var rayon: float = 14.0
var duree: float = 6.0

var _armee: bool = false
var _active: bool = false
var _lampe: OmniLight3D = null


static func regle(balise: LureBeacon, tuning: Tuning) -> void:
	balise.rayon = tuning.leurre_rayon
	balise.duree = tuning.leurre_duree


func _ready() -> void:
	super()
	# Le contact est ce qui la déclenche : lancée, elle s'allume là où elle
	# retombe, et pas une seconde avant.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_sur_contact)


## Armée à la main plutôt qu'au lâcher. Ça change tout : on l'allume à couvert,
## on choisit son moment, et on la jette quand le paquet est bien placé — au
## lieu de découvrir où elle atterrit en la lançant.
func active_par(_joueur: Node3D) -> String:
	if _armee:
		return ""
	_armee = true
	_montre_qu_elle_est_armee()
	return "Balise armée. Elle appellera là où tu la poseras."


func libelle_activation() -> String:
	return "" if _armee else "[E] armer la balise"


## Une lueur faible tant qu'elle est armée sans être posée : on doit voir dans
## sa main qu'elle est vivante, sinon on oublie qu'on la porte.
func _montre_qu_elle_est_armee() -> void:
	if _lampe != null:
		return
	_lampe = OmniLight3D.new()
	_lampe.light_color = Content.palette.balise_leurre
	_lampe.omni_range = 3.0
	_lampe.light_energy = 1.2
	_lampe.shadow_enabled = false
	add_child(_lampe)


## Lâchée par un joueur : à partir de maintenant, le prochain contact compte.
func lache_par_le_joueur(_joueur: Node3D) -> void:
	_armee = true


func _sur_contact(_corps: Node) -> void:
	# Le contact qui compte est celui de l'hôte : sa physique fait foi, et deux
	# machines ne posent pas la balise exactement au même endroit.
	if _armee and not _active and Net.est_host():
		Repl.annonce_balise(self)
		declenche_sans_annonce()


func declenche_sans_annonce() -> void:
	_active = true
	# Même groupe que le leurre du sort : les cerveaux poursuivent un leurre
	# sans jamais le frapper, et cette règle ne doit exister qu'à un endroit.
	add_to_group(&"leurre")
	portable = false
	# Elle s'ancre : une balise qu'on peut repousser du pied ne détourne rien.
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true

	if _lampe == null:
		_lampe = OmniLight3D.new()
		_lampe.shadow_enabled = false
		add_child(_lampe)
	_lampe.light_color = Content.palette.balise_leurre
	_lampe.omni_range = rayon * 0.5
	_lampe.light_energy = 4.0

	# Le groupe plutôt que le registre des monstres : une balise posée au sol
	# n'a pas de raison de connaître l'état de la run, exactement comme un
	# tonneau n'en a pas besoin pour exploser.
	for noeud: Node in get_tree().get_nodes_in_group(&"monstre"):
		var avatar := noeud as MonsterAvatar
		if avatar != null and avatar.global_position.distance_to(global_position) <= rayon:
			avatar.distrait_par(self, duree)

	EventBus.lure_activated.emit(global_position, rayon, duree)
	get_tree().create_timer(duree).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_projette_des_debris()
			detruit.emit()
			queue_free())


func _process(delta: float) -> void:
	super(delta)
	if _lampe == null:
		return
	# Elle pulse tant qu'elle appelle. On doit voir de loin qu'elle tient
	# encore — c'est sur cette information qu'on décide de rester ou de fuir.
	_lampe.light_energy = 3.0 + sin(float(Time.get_ticks_msec()) * 0.008) * 1.6
