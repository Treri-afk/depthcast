class_name SoundSynth
extends RefCounted
## Synthétise un AudioStreamWAV à partir d'une SoundDef.
##
## Volontairement rudimentaire : une seule oscillation, une enveloppe
## attaque/chute, un glissement de hauteur. C'est assez pour donner du corps à
## un jeu et assez peu pour rester lisible — l'objectif n'est pas de faire un
## synthétiseur, c'est de ne plus être muet.

const TAUX: int = 22050


static func genere(def: SoundDef) -> AudioStreamWAV:
	var echantillons: int = maxi(1, int(def.duree * float(TAUX)))
	var donnees := PackedByteArray()
	donnees.resize(echantillons * 2)

	# Une boucle doit se raccorder à elle-même. On recale donc la fréquence sur
	# le nombre entier de cycles le plus proche qui tienne dans le tampon : sans
	# ça, le dernier échantillon ne prolonge pas le premier et le raccord claque
	# une fois par tour, très audible sur une nappe qui joue en continu.
	var debut: float = def.frequence_debut
	var fin: float = def.frequence_fin
	if def.boucle:
		debut = _cale_sur_la_boucle(debut, def.duree)
		fin = debut

	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	# Seed fixe : deux générations donnent le même bruit, donc un son de jeu
	# reproductible d'un lancement à l'autre.
	rng.seed = int(def.id.hash())

	for i: int in echantillons:
		var avancee: float = float(i) / float(echantillons)
		var frequence: float = lerpf(debut, fin, avancee)
		phase += frequence / float(TAUX)

		var onde: float = _onde(def.forme, phase, rng)
		var gain: float = 1.0 if def.boucle else _enveloppe(avancee, def.attaque)
		var valeur: float = onde * gain * def.volume
		donnees.encode_s16(i * 2, int(clampf(valeur, -1.0, 1.0) * 32767.0))

	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = TAUX
	flux.stereo = false
	flux.data = donnees
	if def.boucle:
		flux.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flux.loop_begin = 0
		flux.loop_end = echantillons
	return flux


## Fréquence la plus proche dont un nombre ENTIER de cycles tient dans la durée.
static func _cale_sur_la_boucle(frequence: float, duree: float) -> float:
	if duree <= 0.0:
		return frequence
	var cycles: float = maxf(1.0, round(frequence * duree))
	return cycles / duree


static func _onde(forme: SoundDef.Forme, phase: float,
		rng: RandomNumberGenerator) -> float:
	match forme:
		SoundDef.Forme.SINUS:
			return sin(phase * TAU)
		SoundDef.Forme.CARRE:
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		SoundDef.Forme.SCIE:
			return fmod(phase, 1.0) * 2.0 - 1.0
		SoundDef.Forme.BRUIT:
			return rng.randf_range(-1.0, 1.0)
	return 0.0


## Montée courte puis chute exponentielle. La chute plutôt que le plateau :
## un son qui s'arrête net claque, un son qui s'éteint respire.
static func _enveloppe(avancee: float, attaque: float) -> float:
	var seuil: float = maxf(attaque, 0.001)
	if avancee < seuil:
		return avancee / seuil
	var reste: float = (avancee - seuil) / maxf(1.0 - seuil, 0.001)
	return pow(1.0 - reste, 2.2)
