extends Node
## Télémétrie de run — autoload `Telemetrie`.
##
## Elle ÉCOUTE le bus et ne lui répond jamais. C'est une contrainte, pas une
## pudeur : le jour où un système de jeu lirait un compteur d'ici, la mesure
## deviendrait de l'état de jeu, et l'état de jeu vit dans GameState (R1). Rien
## dans `scripts/gameplay` ni `scripts/core` n'a le droit d'appeler ce fichier.
##
## Les questions auxquelles elle répond : à quel étage on meurt, lequel traîne,
## quel sort n'est jamais lancé, combien de Résonance dort dans le pot à la fin.
## Ce sont des questions d'équilibrage, et on ne les tranche pas de mémoire une
## heure après la partie.
##
## Tout reste local, dans `user://`. Rien n'est envoyé nulle part : c'est un
## outil de développement, pas de la collecte.

const DOSSIER := "user://telemetrie"

## Le journal chronologique est borné. Une run longue émet des dizaines de
## milliers d'évènements de dégâts ; les garder tous ferait grossir la mémoire
## sans rien apprendre de plus que les totaux, qui, eux, ne sont pas bornés.
const MAX_EVENEMENTS: int = 4000

## Sous ce seuil, la run n'a pas été jouée : c'est un test automatisé ou un
## aller-retour au menu. Écrire un fichier pour ça noierait les vraies mesures.
const DUREE_MINIMALE_MS: int = 5000

## Enregistrer coûte quelques dictionnaires par seconde. On ne le fait qu'en
## build de développement — le joueur final n'a rien à mesurer.
var enregistre: bool = OS.is_debug_build()

## Écrire le fichier de fin de run automatiquement. La console peut le couper
## pour enchaîner des essais sans laisser de traces.
var ecriture_auto: bool = true

var _graine: int = 0
var _debut_run_ms: int = 0
var _debut_etage_ms: int = 0
var _etage_en_cours: Dictionary = {}
var _etages: Array[Dictionary] = []
var _evenements: Array[Dictionary] = []
## Nombre de lancers par effet, tous étages confondus. C'est la mesure qui dit
## si une école sert ou si elle décore le HUD.
var _lancers: Dictionary[StringName, int] = {}
var _debordement: int = 0


func _ready() -> void:
	EventBus.run_started.connect(_sur_depart)
	EventBus.floor_entered.connect(_sur_etage)
	EventBus.run_ended.connect(_sur_fin)

	EventBus.player_damaged.connect(func(id: int, degats: int, _o: Vector3) -> void:
		_ajoute(&"degats_subis", degats)
		_note(&"degats_subis", {"joueur": id, "montant": degats}))
	EventBus.monster_damaged.connect(func(_m: int, _hp: int, degats: int) -> void:
		_ajoute(&"degats_infliges", degats))
	EventBus.monster_died.connect(func(id: int, tueur: int, recompense: int) -> void:
		_ajoute(&"monstres_tues", 1)
		_ajoute(&"resonance_gagnee", recompense)
		_note(&"monstre_mort", {"monstre": id, "tueur": tueur}))

	EventBus.player_downed.connect(func(id: int) -> void:
		_ajoute(&"chutes", 1)
		_note(&"chute", {"joueur": id}))
	EventBus.player_revived.connect(func(id: int, par: int) -> void:
		_ajoute(&"releves", 1)
		_note(&"releve", {"joueur": id, "par": par}))

	EventBus.slot_rerolled.connect(func(id: int, slot: int, _e: int) -> void:
		_ajoute(&"rerolls", 1)
		_note(&"reroll", {"joueur": id, "slot": slot}))
	EventBus.slot_kept.connect(func(_id: int, _slot: int) -> void:
		_ajoute(&"slots_scelles_tenus", 1))
	EventBus.slot_locked.connect(func(id: int, slot: int, cout: int, _f: int) -> void:
		_ajoute(&"verrous_achetes", 1)
		_ajoute(&"resonance_depensee", cout)
		_note(&"verrou", {"joueur": id, "slot": slot, "cout": cout}))

	# On compte les lancers À LA RÉSOLUTION et pas à la soumission : une
	# intention refusée par le resolver n'a pas eu lieu, et la compter
	# gonflerait l'usage apparent d'un sort qui, justement, ne passe pas.
	EventBus.intent_resolved.connect(func(intent: EffectIntent) -> void:
		if intent.source_slot < 0:
			return
		_ajoute(&"sorts_lances", 1)
		if enregistre:
			_lancers[intent.effect_id] = _lancers.get(intent.effect_id, 0) + 1)

	EventBus.explosion_triggered.connect(func(_o: Vector3, _p: float) -> void:
		_ajoute(&"explosions", 1))


# ── Lecture ───────────────────────────────────────────────────────────────

func en_cours() -> bool:
	return _debut_run_ms > 0


## Résumé lisible, pour la console. Volontairement du texte : la personne qui
## tape `tel` en pleine partie veut lire, pas parcourir un dictionnaire.
func lignes() -> PackedStringArray:
	var out := PackedStringArray()
	if not enregistre:
		out.append("télémétrie coupée (`tel actif` pour la reprendre)")
		return out
	if not en_cours():
		out.append("aucune run enregistrée depuis le lancement")
		return out

	out.append("run %d — %s, %d étage(s) traversé(s)" % [
		_graine, _duree(_debut_run_ms), _etages.size()])
	var tous: Array[Dictionary] = _etages.duplicate()
	if not _etage_en_cours.is_empty():
		tous.append(_ferme_l_etage())
	for etage: Dictionary in tous:
		out.append("  étage %d · %s · %d tué(s) · %d subi(s) · %d reroll(s)" % [
			int(etage.get("etage", 0)) + 1,
			_millis(int(etage.get("duree_ms", 0))),
			int(etage.get("monstres_tues", 0)),
			int(etage.get("degats_subis", 0)),
			int(etage.get("rerolls", 0))])

	var tries: Array[StringName] = []
	tries.assign(_lancers.keys())
	tries.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _lancers[a] > _lancers[b])
	if not tries.is_empty():
		var morceaux := PackedStringArray()
		for id: StringName in tries.slice(0, 5):
			morceaux.append("%s ×%d" % [id, _lancers[id]])
		out.append("  sorts : " + ", ".join(morceaux))
	if _debordement > 0:
		out.append("  (%d évènement(s) plus anciens oubliés)" % _debordement)
	return out


## La mesure complète, telle qu'elle part dans le fichier.
func rapport() -> Dictionary:
	var etages: Array[Dictionary] = _etages.duplicate()
	if not _etage_en_cours.is_empty():
		etages.append(_ferme_l_etage())
	return {
		"graine": _graine,
		"version_godot": Engine.get_version_info().get("string", ""),
		"date": Time.get_datetime_string_from_system(),
		"duree_ms": _millis_ecoulees(),
		"joueurs": Net.nombre_de_joueurs(),
		"etages": etages,
		"lancers_par_effet": _lancers,
		"evenements": _evenements,
		"evenements_oublies": _debordement,
	}


## Écrit le rapport et retourne le chemin, ou "" si rien n'a été écrit.
func ecrit() -> String:
	if not enregistre or not en_cours():
		return ""
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var chemin: String = "%s/run_%d_%s.json" % [DOSSIER, _graine,
		Time.get_datetime_string_from_system().replace(":", "-")]
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_warning("Télémétrie : impossible d'écrire %s" % chemin)
		return ""
	f.store_string(JSON.stringify(rapport(), "\t"))
	f.close()
	return ProjectSettings.globalize_path(chemin)


func remet_a_zero() -> void:
	_debut_run_ms = 0
	_debut_etage_ms = 0
	_etage_en_cours = {}
	_etages.clear()
	_evenements.clear()
	_lancers.clear()
	_debordement = 0


## Marqueur posé à la main depuis la console, pour retrouver un moment précis
## dans le journal après coup — « c'est ICI que ça a bégayé ».
func marque(texte: String) -> void:
	_note(&"marque", {"texte": texte})


# ── Écriture ──────────────────────────────────────────────────────────────

func _sur_depart(graine: int) -> void:
	if not enregistre:
		return
	remet_a_zero()
	_graine = graine
	_debut_run_ms = Time.get_ticks_msec()


func _sur_etage(index: int) -> void:
	if not enregistre or not en_cours():
		return
	if not _etage_en_cours.is_empty():
		_etages.append(_ferme_l_etage())
	_debut_etage_ms = Time.get_ticks_msec()
	_etage_en_cours = {"etage": index}
	_note(&"etage", {"index": index})


func _sur_fin(etage: int, victoire: bool) -> void:
	if not enregistre or not en_cours():
		return
	_note(&"fin", {"etage": etage, "victoire": victoire})
	if not _etage_en_cours.is_empty():
		_etages.append(_ferme_l_etage())
		_etage_en_cours = {}
	if ecriture_auto and _millis_ecoulees() >= DUREE_MINIMALE_MS:
		var chemin: String = ecrit()
		if chemin != "":
			print("[Télémétrie] %s" % chemin)


func _ferme_l_etage() -> Dictionary:
	var copie: Dictionary = _etage_en_cours.duplicate()
	copie["duree_ms"] = Time.get_ticks_msec() - _debut_etage_ms
	return copie


## Les compteurs vivent DANS l'étage courant, pas dans un total global : savoir
## qu'on a encaissé 900 dégâts sur la run n'apprend rien, savoir qu'on en a
## encaissé 700 au troisième étage désigne le coupable.
func _ajoute(cle: StringName, valeur: int) -> void:
	if not enregistre or _etage_en_cours.is_empty():
		return
	_etage_en_cours[cle] = int(_etage_en_cours.get(cle, 0)) + valeur


func _note(genre: StringName, donnees: Dictionary) -> void:
	if not enregistre or not en_cours():
		return
	if _evenements.size() >= MAX_EVENEMENTS:
		_evenements.pop_front()
		_debordement += 1
	var ligne: Dictionary = donnees.duplicate()
	ligne["t"] = _millis_ecoulees()
	ligne["genre"] = String(genre)
	_evenements.append(ligne)


func _millis_ecoulees() -> int:
	return 0 if _debut_run_ms == 0 else Time.get_ticks_msec() - _debut_run_ms


func _duree(depuis_ms: int) -> String:
	return _millis(Time.get_ticks_msec() - depuis_ms)


func _millis(ms: int) -> String:
	var total: int = int(ms / 1000.0)
	return "%d min %02d s" % [total / 60, total % 60] if total >= 60 else "%d s" % total
