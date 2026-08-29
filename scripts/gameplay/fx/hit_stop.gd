class_name HitStop
extends RefCounted
## L'arrêt sur image d'un impact.
##
## Quelques dizaines de millisecondes où le monde se fige, juste après un coup
## décisif. C'est la technique de ressenti la plus rentable qui existe : trois
## lignes, et chaque mise à mort devient une frappe au lieu d'une disparition.
##
## Elle passe par l'échelle de temps globale, donc elle touche AUSSI la physique
## et les minuteurs de jeu. D'où deux garde-fous non négociables : elle est très
## courte, et elle ne s'empile jamais. Deux morts simultanées ne doivent pas
## figer le jeu deux fois plus longtemps.

## Vrai pendant un arrêt. Statique parce que le temps est global : deux
## appelants qui croiraient chacun avoir le leur se marcheraient dessus.
static var _en_cours: bool = false


static func actif() -> bool:
	return _en_cours


## Fige le monde pour `duree` secondes RÉELLES.
##
## Le minuteur ignore l'échelle de temps — sinon il serait ralenti par ce qu'il
## est censé interrompre, et l'arrêt durerait vingt fois trop longtemps.
## Retourne false si l'arrêt n'a pas eu lieu — déjà un en cours, ou durée nulle.
static func frappe(duree: float, echelle: float = 0.05) -> bool:
	if _en_cours or duree <= 0.0:
		return false
	var boucle := Engine.get_main_loop() as SceneTree
	if boucle == null:
		return false

	_en_cours = true
	Engine.time_scale = clampf(echelle, 0.01, 1.0)
	boucle.create_timer(duree, true, false, true).timeout.connect(
		func() -> void:
			Engine.time_scale = 1.0
			_en_cours = false)
	return true
