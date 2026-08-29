class_name ThreatSense
extends RefCounted
## L'attention d'une créature à une menace posée dans le décor — pour l'instant,
## une mèche allumée.
##
## Séparé du cerveau à dessein. MonsterBrain décide COMMENT attaquer ; ceci
## décide QUAND arrêter de le faire. Les mélanger ferait une machine à états où
## chaque nouvel état devrait connaître tous les autres.
##
## Le délai de réaction n'est pas une limite technique, c'est le sujet. Une
## créature qui s'écarte à l'instant où la mèche s'allume n'est pas surprise,
## elle est omnisciente. C'est le temps entre « ça brille » et « je pars » qui
## se lit à l'écran — et c'est lui qui laisse au joueur sa fenêtre pour agir.

enum Etat { CALME, REMARQUE, FUITE }

signal remarque()

var stats: MonsterStats = null
var duree_de_fuite: float = 1.4

var etat: Etat = Etat.CALME

var _menace: Vector3 = Vector3.ZERO
var _attention: float = 0.0
var _fuite_restante: float = 0.0


func _init(p_stats: MonsterStats, p_duree_de_fuite: float) -> void:
	stats = p_stats
	duree_de_fuite = p_duree_de_fuite


## Une menace vient d'apparaître. Ignorée si l'espèce ne la craint pas, ou si
## elle est hors du rayon dangereux : un tonneau qui saute à vingt mètres ne
## regarde personne.
func signale(origine: Vector3, rayon: float, position: Vector3) -> void:
	if stats == null or not stats.peur_des_explosions:
		return
	var distance: float = position.distance_to(origine)
	# Une marge au-delà du rayon : on s'écarte de ce qui va faire mal, pas
	# seulement de ce qui va tout juste nous atteindre.
	if distance > rayon * 1.2:
		return
	# Deux mèches à la fois : la plus proche l'emporte, et elle ne relance pas
	# une attention déjà en cours.
	if etat != Etat.CALME and distance >= position.distance_to(_menace):
		return

	_menace = origine
	if etat == Etat.CALME:
		etat = Etat.REMARQUE
		_attention = 0.0


## Fait avancer l'attention. Retourne la direction de fuite, ou ZERO — auquel
## cas l'appelant garde la décision de son cerveau.
##
## Pendant qu'elle remarque, la créature CONTINUE ce qu'elle faisait. La figer
## le temps de comprendre donnerait une seconde d'immobilité gratuite au joueur
## et rendrait les tonneaux meilleurs qu'ils ne devraient l'être.
func avance(delta: float, position: Vector3) -> Vector3:
	match etat:
		Etat.REMARQUE:
			_attention += delta / maxf(stats.temps_de_reaction, 0.01)
			if _attention >= 1.0:
				_attention = 1.0
				etat = Etat.FUITE
				_fuite_restante = duree_de_fuite
				remarque.emit()
			return Vector3.ZERO

		Etat.FUITE:
			_fuite_restante -= delta
			if _fuite_restante <= 0.0:
				oublie()
				return Vector3.ZERO
			var loin: Vector3 = position - _menace
			loin.y = 0.0
			return loin.normalized() if loin.length_squared() > 0.01 else Vector3.FORWARD

	return Vector3.ZERO


## Y a-t-il quelque chose à montrer au-dessus de sa tête ?
func attentif() -> bool:
	return etat != Etat.CALME


func progression() -> float:
	return _attention


func oublie() -> void:
	etat = Etat.CALME
	_attention = 0.0
	_fuite_restante = 0.0
