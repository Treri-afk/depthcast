class_name BossBrain
extends MonsterBrain
## La décision d'un boss : le comportement d'un monstre, plus des phases et une
## attaque spéciale périodique.
##
## ── POINT D'EXTENSION ────────────────────────────────────────────────────
## C'est ici qu'on écrit un boss précis. Deux crochets sont prévus :
##
##   _sur_changement_de_phase(phase)  appelé au franchissement d'un seuil
##   declenche_special(phase)         appelé quand la jauge d'attaque est prête
##
## Une sous-classe qui les redéfinit obtient un boss singulier sans toucher ni
## au corps, ni au resolver, ni à la machine à états de base.

signal veut_special(phase: int)
signal phase_changee(phase: int, total: int)

var boss: BossStats
var phase: int = 0

var _recharge_special: float = 0.0


func _init(p_stats: BossStats, sens: float) -> void:
	super(p_stats, sens)
	boss = p_stats
	_recharge_special = p_stats.delai_special


func decide(delta: float, position: Vector3, cible: Node3D,
		facteur_vitesse: float) -> Vector3:
	_recharge_special -= delta
	if _recharge_special <= 0.0:
		_recharge_special = _delai_courant()
		declenche_special(phase)
	# Le comportement de base continue : un boss se déplace comme un monstre,
	# il a juste quelque chose en plus.
	return super(delta, position, cible, facteur_vitesse)


## Appelé par le corps à chaque changement de points de vie.
func evalue_les_phases(fraction_pv: float) -> void:
	var atteinte: int = 0
	for seuil: float in boss.seuils_de_phase:
		if fraction_pv <= seuil:
			atteinte += 1
	if atteinte == phase:
		return
	phase = atteinte
	_sur_changement_de_phase(phase)
	phase_changee.emit(phase, boss.nombre_de_phases())


## À redéfinir pour un boss précis : nouvelle attaque, changement de rythme,
## invocation d'appui. Par défaut, le boss accélère et devient plus mobile.
func _sur_changement_de_phase(_phase_atteinte: int) -> void:
	_recharge_special = _delai_courant() * 0.4


## À redéfinir pour remplacer l'attaque spéciale par autre chose.
func declenche_special(phase_courante: int) -> void:
	veut_special.emit(phase_courante)


func _delai_courant() -> float:
	return boss.delai_special * pow(boss.acceleration_par_phase, float(phase))
