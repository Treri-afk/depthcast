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

	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	# Seed fixe : deux générations donnent le même bruit, donc un son de jeu
	# reproductible d'un lancement à l'autre.
	rng.seed = int(def.id.hash())

	for i: int in echantillons:
		var avancee: float = float(i) / float(echantillons)
		var frequence: float = lerpf(def.frequence_debut, def.frequence_fin, avancee)
		phase += frequence / float(TAUX)

		var onde: float = _onde(def.forme, phase, rng)
		var valeur: float = onde * _enveloppe(avancee, def.attaque) * def.volume
		donnees.encode_s16(i * 2, int(clampf(valeur, -1.0, 1.0) * 32767.0))

	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = TAUX
	flux.stereo = false
	flux.data = donnees
	return flux


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
