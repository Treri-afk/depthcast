class_name FeedbackTests
extends TestSuite
## Son, moment du reroll et retour de dégâts.


func nom() -> String:
	return "Retour au joueur — son, reroll, dégâts"


func execute() -> void:
	_check_banque_de_sons()
	_check_synthese()
	_check_origine_des_degats()
	_check_ressenti()


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


## Le ressenti : ce qui ne change aucune règle mais décide si le jeu est bon.
func _check_ressenti() -> void:
	print("Ressenti — son situé, arrêt sur image, pardon du saut")

	# Un son du monde doit porter quelque part. Un son d'interface ne doit PAS
	# être situé : le spatialiser le ferait varier selon l'orientation du
	# joueur au moment où il clique, ce qui est le contraire d'un retour d'UI.
	var pour_l_oreille: Array[StringName] = [&"achat", &"refus", &"mutation",
		&"sceau_tient", &"victoire", &"defaite", &"blessure"]
	var du_monde: Array[StringName] = [&"impact", &"mort", &"detonation",
		&"souffle", &"balise"]

	for def: SoundDef in Audio.definitions():
		if pour_l_oreille.has(def.id):
			verifie("%s ne se situe pas dans l'espace" % def.id, not def.spatialise)
		elif du_monde.has(def.id):
			verifie("%s se situe dans l'espace" % def.id, def.spatialise)
			verifie("  et il porte quelque part", def.portee > 0.0 and def.unite > 0.0)

	# Une détonation doit s'entendre de plus loin qu'un impact, sinon la
	# distance ne dit plus rien de la gravité de ce qui se passe.
	var detonation: SoundDef = _son(&"detonation")
	var impact: SoundDef = _son(&"impact")
	verifie("une détonation porte plus loin qu'un impact",
		detonation.portee > impact.portee,
		"%.0f contre %.0f" % [detonation.portee, impact.portee])

	var t: Tuning = Content.tuning
	verifie("l'arrêt sur image est court", t.hitstop_mort > 0.0 and t.hitstop_mort < 0.2,
		"%.3f s" % t.hitstop_mort)
	verifie("il ne fige pas complètement", t.hitstop_echelle > 0.0)
	verifie("une égratignure ne fige rien", t.hitstop_seuil_degats > 0)
	# Deux morts simultanées ne doivent pas figer le jeu deux fois plus longtemps.
	verifie("et il ne s'empile pas",
		HitStop.frappe(0.05, 0.5) and not HitStop.frappe(0.05, 0.5))

	verifie("le saut pardonne le retard", t.saut_coyote > 0.0 and t.saut_coyote < 0.4)
	verifie("et l'avance", t.saut_tampon > 0.0 and t.saut_tampon < 0.4)

	# Le chiffre de dégâts : la seule chose du jeu qui dise si l'on progresse.
	var chiffre := DamageNumber.cree(42, Vector3.ZERO, false)
	var fatal := DamageNumber.cree(42, Vector3.ZERO, true)
	var label := chiffre.get_child(0) as Label3D
	var label_fatal := fatal.get_child(0) as Label3D
	verifie("le chiffre affiche le montant du coup", label.text == "42")
	verifie("le coup fatal se repère sans le lire",
		label_fatal.font_size > label.font_size
			and label_fatal.modulate != label.modulate)
	chiffre.free()
	fatal.free()

	# Le recul vient de la donnée, pas d'une ligne par sort.
	var recule: bool = false
	for ecole: School in Content.ecoles:
		for effet: SpellEffect in ecole.effets:
			if effet.recul > 0.0:
				recule = true
	verifie("les sorts déclarent leur recul dans la donnée", recule)


func _son(id: StringName) -> SoundDef:
	for def: SoundDef in Audio.definitions():
		if def.id == id:
			return def
	return null
