class_name MetaTests
extends TestSuite
## Méta-progression, boss et variété des étages.


func nom() -> String:
	return "Méta, boss et structure des étages"


func execute() -> void:
	_check_meta()
	_check_boss()
	_check_etages()


func _check_meta() -> void:
	# La récompense doit croître avec la profondeur : descendre est ce qui paie.
	var peu: int = Meta.recompense(0, false)
	var loin: int = Meta.recompense(3, false)
	verifie("descendre plus bas rapporte plus", loin > peu, "%d vs %d" % [peu, loin])
	verifie("une victoire vaut plus qu'une mort au même étage",
		Meta.recompense(3, true) > loin)

	verifie("une première partie ouvre de quoi composer une équipe",
		Meta.ecoles_disponibles().size() >= PlayerState.SLOT_COUNT,
		"%d école(s)" % Meta.ecoles_disponibles().size())
	verifie("les Éclats ne sont pas la Résonance",
		not ("resonance" in Meta), "Meta ne doit connaître que la monnaie méta")

	# Un déblocage sans fonds doit échouer proprement, pas passer en négatif.
	var avant: int = Meta.eclats
	Meta.eclats = 0
	var verrouillee: StringName = &""
	for e: School in Content.ecoles:
		if not Meta.est_debloquee(e.id):
			verrouillee = e.id
			break
	if verrouillee != &"":
		verifie("un déblocage sans Éclats est refusé",
			not Meta.tente_deblocage(verrouillee))
		verifie("les Éclats ne passent jamais en négatif", Meta.eclats >= 0)
	Meta.eclats = avant


func _check_boss() -> void:
	var boss: BossStats = Content.monstre(&"gardien_du_seuil") as BossStats
	verifie("le boss existe et est bien un BossStats", boss != null)
	if boss == null:
		return
	verifie("il a plusieurs phases", boss.nombre_de_phases() >= 2,
		"%d phase(s)" % boss.nombre_de_phases())
	verifie("il ne se mélange pas aux monstres ordinaires",
		not Content.monstres_ordinaires().has(boss))

	# Les seuils doivent être décroissants, sinon les phases se déclenchent
	# dans le désordre ou toutes en même temps.
	var ordonnes: bool = true
	for i: int in boss.seuils_de_phase.size() - 1:
		if boss.seuils_de_phase[i] <= boss.seuils_de_phase[i + 1]:
			ordonnes = false
	verifie("ses seuils de phase sont décroissants", ordonnes,
		str(boss.seuils_de_phase))


func _check_etages() -> void:
	var tuning: Tuning = Content.tuning
	var rng := RandomNumberGenerator.new()

	# Deux étages tirés doivent pouvoir différer : un donjon dont chaque étage
	# a la même forme n'a pas de relief.
	var tailles: Dictionary = {}
	for graine: int in range(1, 25):
		rng.seed = graine
		tailles[FloorPlan.genere(rng, tuning).salles.size()] = true
	verifie("le nombre de salles varie d'un étage à l'autre", tailles.size() > 1,
		str(tailles.keys()))

	rng.seed = 7
	var plan := FloorPlan.genere(rng, tuning)
	var marchands: int = 0
	for salle: FloorPlan.Salle in plan.salles:
		if salle.marchand:
			marchands += 1
	verifie("un étage a exactement une salle de marchand", marchands == 1,
		"%d trouvée(s)" % marchands)

	var arene := FloorPlan.genere_arene(rng, tuning)
	verifie("l'arène de boss est une salle unique", arene.est_une_arene())
	verifie("l'arène n'a ni couloir ni marchand",
		arene.couloirs.is_empty() and not arene.salles[0].marchand)
