extends Node
## Le son du jeu — autoload `Audio`.
##
## Il charge les SoundDef de resources/sounds/, les synthétise une fois au
## démarrage, et les joue à la demande. Ajouter un son au jeu revient à déposer
## un .tres et à appeler `Audio.joue(&"mon_son")`.
##
## Il s'abonne lui-même aux évènements du bus : le reste du code n'a donc rien
## à savoir du son, et couper l'audio ne demande de toucher aucun système.

const DOSSIER := "res://resources/sounds"
## Nombre de lectures simultanées. Au-delà, la plus ancienne est réutilisée :
## dix impacts en même temps doivent saturer, pas empiler cinquante voix.
const VOIX: int = 12

var actif: bool = true

var _definitions: Dictionary[StringName, SoundDef] = {}
var _flux: Dictionary[StringName, AudioStream] = {}
var _lecteurs: Array[AudioStreamPlayer] = []
var _prochain: int = 0


func _ready() -> void:
	_charge()
	for i: int in VOIX:
		var lecteur := AudioStreamPlayer.new()
		add_child(lecteur)
		_lecteurs.append(lecteur)
	_branche_les_evenements()
	print("[Audio] %d son(s) synthétisé(s)." % _flux.size())


func joue(id: StringName, gain_supplementaire: float = 0.0) -> void:
	if not actif or not _flux.has(id):
		return
	var def: SoundDef = _definitions[id]
	var lecteur: AudioStreamPlayer = _lecteurs[_prochain]
	_prochain = (_prochain + 1) % _lecteurs.size()

	lecteur.stream = _flux[id]
	lecteur.volume_db = def.gain_db + gain_supplementaire
	# Une variation de hauteur à chaque lecture : sans elle, dix impacts
	# d'affilée sonnent comme une machine à écrire.
	lecteur.pitch_scale = 1.0 + randf_range(-def.variation_hauteur, def.variation_hauteur)
	lecteur.play()


func definitions() -> Array:
	return _definitions.values()


func _charge() -> void:
	var dossier := DirAccess.open(DOSSIER)
	if dossier == null:
		push_warning("Dossier de sons introuvable : " + DOSSIER)
		return
	var fichiers: PackedStringArray = dossier.get_files()
	fichiers.sort()
	for fichier: String in fichiers:
		var nom: String = fichier.trim_suffix(".remap")
		if not nom.ends_with(".tres"):
			continue
		var def := load(DOSSIER.path_join(nom)) as SoundDef
		if def == null or def.id == &"":
			continue
		_definitions[def.id] = def
		_flux[def.id] = def.remplacement if def.remplacement != null \
			else SoundSynth.genere(def)


## Le son écoute le jeu, le jeu n'appelle pas le son. Un système de gameplay
## qui déclencherait lui-même ses bruitages deviendrait impossible à couper.
func _branche_les_evenements() -> void:
	EventBus.monster_damaged.connect(func(_id: int, _pv: int) -> void: joue(&"impact"))
	EventBus.monster_died.connect(func(_id: int, _t: int, _r: int) -> void: joue(&"mort"))
	EventBus.slot_rerolled.connect(func(_j: int, _s: int, _e: int) -> void: joue(&"mutation"))
	EventBus.slot_kept.connect(func(_j: int, _s: int) -> void: joue(&"sceau_tient"))
	EventBus.slot_locked.connect(func(_j: int, _s: int, _c: int, _u: int) -> void:
		joue(&"achat"))
	EventBus.resonance_spend_rejected.connect(func(_j: int, _r: String) -> void:
		joue(&"refus"))
	EventBus.player_damaged.connect(func(_j: int, _d: int, _o: Vector3) -> void:
		joue(&"blessure"))
	EventBus.floor_entered.connect(func(_i: int) -> void: joue(&"descente"))
	EventBus.run_ended.connect(func(_e: int, victoire: bool) -> void:
		joue(&"victoire" if victoire else &"defaite"))
