class_name FeedbackTests
extends TestSuite
## Son, moment du reroll et retour de dégâts.


func nom() -> String:
	return "Retour au joueur — son, reroll, dégâts"


func execute() -> void:
	_check_banque_de_sons()
	_check_synthese()
	_check_origine_des_degats()


## Chaque évènement auquel le chef d'orchestre s'abonne doit trouver son son.
## Un identifiant absent est un silence qu'on ne remarque qu'en jouant.
func _check_banque_de_sons() -> void:
	var attendus: Array[StringName] = [
		&"impact", &"mort", &"blessure", &"mutation", &"sceau_tient",
		&"achat", &"refus", &"descente", &"victoire", &"defaite", &"sort",
	]
	var connus: Array[StringName] = []
	for def: SoundDef in Audio.definitions():
		connus.append(def.id)

	var manquants: Array = []
	for id: StringName in attendus:
		if not connus.has(id):
			manquants.append(String(id))
	verifie("tous les sons attendus existent", manquants.is_empty(), str(manquants))

	# La mutation monte, le sceau descend : le sens du glissement porte le sens
	# de l'évènement, et l'inverser rendrait une bonne nouvelle sinistre.
	for def: SoundDef in Audio.definitions():
		if def.id == &"mutation":
			verifie("le son de mutation monte — c'est un évènement, pas une punition",
				def.frequence_fin > def.frequence_debut)
		elif def.id == &"sceau_tient":
			verifie("celui du sceau descend et se pose",
				def.frequence_fin < def.frequence_debut)
		elif def.id == &"defaite":
			verifie("celui de la défaite descend", def.frequence_fin < def.frequence_debut)


func _check_synthese() -> void:
	var def := SoundDef.new()
	def.id = &"test"
	def.duree = 0.2
	var flux := SoundSynth.genere(def)

	verifie("la synthèse produit un flux jouable", flux != null and flux.data.size() > 0)
	verifie("à la bonne fréquence d'échantillonnage",
		flux.mix_rate == SoundSynth.TAUX)
	# Deux octets par échantillon en 16 bits : une taille impaire signalerait
	# un encodage cassé.
	verifie("avec un nombre pair d'octets", flux.data.size() % 2 == 0)

	# Même identifiant, même bruit : un son de jeu doit être reproductible.
	def.forme = SoundDef.Forme.BRUIT
	verifie("le bruit est reproductible d'une génération à l'autre",
		SoundSynth.genere(def).data == SoundSynth.genere(def).data)


## Sans origine, l'indicateur ne peut rien dire — et en vue subjective, un coup
## sans provenance est un coup illisible.
func _check_origine_des_degats() -> void:
	var intent := EffectIntent.new()
	verifie("une intention porte une origine", "origine" in intent)
	intent.origine = Vector3(3, 0, 4)
	verifie("elle survit à la sérialisation",
		intent.to_dict().has("origine"))

	var recu: Array = []
	var lien := func(_j: int, degats: int, origine: Vector3) -> void:
		recu.append([degats, origine])
	EventBus.player_damaged.connect(lien)

	GameState.start_run(999, 1)
	var coup := EffectIntent.new()
	coup.kind = EffectIntent.Kind.DAMAGE
	coup.amount = 5
	coup.origine = Vector3(7, 0, 0)
	coup.target_ids = PackedInt64Array([0])
	EffectResolver.submit(coup)
	EffectResolver.resolve_tick()

	EventBus.player_damaged.disconnect(lien)
	verifie("blesser le joueur annonce d'où vient le coup",
		recu.size() == 1 and (recu[0][1] as Vector3) == Vector3(7, 0, 0), str(recu))
