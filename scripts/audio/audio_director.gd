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
## Nombre de lectures simultanées, par famille. Au-delà, la plus ancienne est
## réutilisée : dix impacts en même temps doivent saturer, pas empiler
## cinquante voix.
const VOIX: int = 10
## Voix POSITIONNÉES, pour tout ce qui appartient au monde. Elles vivent sous
## cet autoload et non dans la scène : le directeur survit aux changements de
## scène, et un son en cours ne se coupe pas parce qu'on a changé d'étage.
const VOIX_3D: int = 12

var actif: bool = true

var _definitions: Dictionary[StringName, SoundDef] = {}
var _flux: Dictionary[StringName, AudioStream] = {}
var _lecteurs: Array[AudioStreamPlayer] = []
var _lecteurs_3d: Array[AudioStreamPlayer3D] = []
var _prochain: int = 0
var _prochain_3d: int = 0
## Lecteur dédié à la nappe d'ambiance. À part des voix : elle ne s'arrête
## jamais et ne doit donc jamais se faire voler son tour par un impact.
var _nappe: AudioStreamPlayer = null


func _ready() -> void:
	_charge()
	for i: int in VOIX:
		var lecteur := AudioStreamPlayer.new()
		add_child(lecteur)
		_lecteurs.append(lecteur)
	for i: int in VOIX_3D:
		var lecteur := AudioStreamPlayer3D.new()
		add_child(lecteur)
		_lecteurs_3d.append(lecteur)
	_nappe = AudioStreamPlayer.new()
	_nappe.bus = &"Master"
	add_child(_nappe)
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


## Joue un son À UN ENDROIT du monde.
##
## C'est la différence entre entendre une mèche et savoir qu'elle grésille
## derrière soi. Dans un jeu en vue subjective où l'on encaisse hors champ,
## c'est la moitié de l'information disponible.
##
## Un son déclaré non spatialisé retombe sur la lecture ordinaire : l'appelant
## n'a pas à savoir de quel genre est le son qu'il annonce.
func joue_a(id: StringName, origine: Vector3, gain_supplementaire: float = 0.0) -> void:
	if not actif or not _flux.has(id):
		return
	var def: SoundDef = _definitions[id]
	if not def.spatialise:
		joue(id, gain_supplementaire)
		return

	var lecteur: AudioStreamPlayer3D = _lecteurs_3d[_prochain_3d]
	_prochain_3d = (_prochain_3d + 1) % _lecteurs_3d.size()

	lecteur.global_position = origine
	lecteur.stream = _flux[id]
	lecteur.volume_db = def.gain_db + gain_supplementaire
	lecteur.max_distance = def.portee
	lecteur.unit_size = def.unite
	lecteur.pitch_scale = 1.0 + randf_range(-def.variation_hauteur, def.variation_hauteur)
	lecteur.play()


## Installe la nappe de fond. Une seule à la fois : deux nappes superposées ne
## font pas une ambiance plus riche, elles font de la boue.
func ambiance(id: StringName, hauteur: float = 1.0) -> void:
	if _nappe == null or not _flux.has(id):
		return
	var def: SoundDef = _definitions[id]
	if _nappe.stream != _flux[id]:
		_nappe.stream = _flux[id]
		_nappe.volume_db = def.gain_db
		_nappe.play()
	_nappe.pitch_scale = maxf(hauteur, 0.05)


func coupe_l_ambiance() -> void:
	if _nappe != null:
		_nappe.stop()


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
	# Le bruit qu'une créature fait est annoncé par la créature, avec sa
	# position : le resolver, lui, ne sait pas où se tiennent les corps.
	EventBus.sound_emitted.connect(joue_a)
	EventBus.slot_rerolled.connect(func(_j: int, _s: int, _e: int) -> void: joue(&"mutation"))
	EventBus.slot_kept.connect(func(_j: int, _s: int) -> void: joue(&"sceau_tient"))
	EventBus.slot_locked.connect(func(_j: int, _s: int, _c: int, _u: int) -> void:
		joue(&"achat"))
	EventBus.resonance_spend_rejected.connect(func(_j: int, _r: String) -> void:
		joue(&"refus"))
	# Sa propre douleur ne se situe pas dans l'espace : elle est déclarée non
	# spatialisée, et la direction du coup est déjà dite par l'interface.
	EventBus.player_damaged.connect(func(_j: int, _d: int, _o: Vector3) -> void:
		joue(&"blessure"))
	EventBus.player_blasted.connect(func(_j: int, _f: float, origine: Vector3) -> void:
		joue_a(&"souffle", origine))
	# Le volume de la réception suit la vitesse de chute : une chute de dix
	# mètres ne doit pas sonner comme un pas manqué.
	EventBus.player_slammed.connect(func(_j: int, vitesse: float) -> void:
		joue(&"chute", clampf(vitesse - 12.0, -14.0, 4.0)))
	EventBus.explosion_triggered.connect(func(origine: Vector3, _p: float) -> void:
		joue_a(&"detonation", origine))
	EventBus.lure_activated.connect(func(origine: Vector3, _r: float, _d: float) -> void:
		joue_a(&"balise", origine))
	# La nappe s'assombrit à mesure qu'on descend. C'est le seul endroit du jeu
	# où la profondeur s'entend, et ça ne coûte qu'un facteur de hauteur.
	EventBus.floor_entered.connect(func(etage: int) -> void:
		joue(&"descente")
		ambiance(&"ambiance", pow(0.93, float(etage))))
	EventBus.run_started.connect(func(_s: int) -> void:
		ambiance(&"ambiance", 1.0))
	EventBus.run_ended.connect(func(_e: int, _v: bool) -> void: coupe_l_ambiance())
	EventBus.run_ended.connect(func(_e: int, victoire: bool) -> void:
		joue(&"victoire" if victoire else &"defaite"))
