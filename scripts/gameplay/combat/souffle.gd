class_name Souffle
extends RefCounted
## Un souffle d'explosion : ce qu'il déplace, et avec quelle force.
##
## C'est un objet et non trois fonctions parce que trois systèmes ont besoin du
## MÊME souffle : les sorts de zone, le mobilier, et le terrain d'essai. Une
## deuxième copie de la courbe d'atténuation quelque part, et deux explosions
## du jeu ne se ressembleraient déjà plus.
##
## Il ne retire AUCUN point de vie. Un souffle déplace des corps ; les dégâts
## restent le domaine du resolver (R4) et l'appelant les soumet séparément.

var centre: Vector3 = Vector3.ZERO
var rayon: float = 5.0
var puissance: float = 12.0
## Attire au lieu de repousser. Même code, sens inversé — et deux jeux
## différents : l'un dégage la place, l'autre rassemble pour frapper ensuite.
var aspire: bool = false
## Le lanceur ne subit pas son propre souffle.
##
## C'est un choix par sort, pas une règle générale. Une Répulsion fait de vous
## le point d'ancrage : vous poussez le monde, le monde ne vous pousse pas. Une
## Nova, elle, vous soulève — et c'est très bien, parce que ça transforme un
## sort défensif en outil de déplacement dès qu'on y pense.
var epargne_le_lanceur: bool = false


func _init(p_centre: Vector3 = Vector3.ZERO, p_rayon: float = 5.0,
		p_puissance: float = 12.0, p_aspire: bool = false) -> void:
	centre = p_centre
	rayon = p_rayon
	puissance = p_puissance
	aspire = p_aspire


## Part de la puissance reçue à une position donnée, entre 0 et 1.
##
## Elle ne tombe pas tout à fait à zéro au bord : une explosion qui s'annule
## exactement sur un cercle donne une frontière que le joueur finit par
## apprendre par cœur, et le souffle devient une question de géométrie plutôt
## que de danger.
func attenuation(pos: Vector3) -> float:
	var distance: float = centre.distance_to(pos)
	if distance > rayon or rayon <= 0.0:
		return 0.0
	return 1.0 - clampf(distance / rayon, 0.0, 0.85)


## Direction dans laquelle un corps est projeté.
##
## Au centre exact la direction est indéfinie : le souffle SOULÈVE alors au lieu
## de pousser. Sans ce cas particulier, une explosion sous ses propres pieds
## serait purement décorative.
func sens_vers(pos: Vector3) -> Vector3:
	var vers: Vector3 = pos - centre
	vers.y = 0.0
	if vers.length_squared() < 0.04:
		return Vector3.UP
	return vers.normalized() * (-1.0 if aspire else 1.0)


## Projette le mobilier. `degats_decor` peut rester à zéro : un souffle
## bouscule le décor, il n'est pas censé le pulvériser.
func sur_objets(objets: Array, degats_decor: int = 0) -> void:
	for corps: PropDestructible in objets:
		if not is_instance_valid(corps):
			continue
		var part: float = attenuation(corps.global_position)
		if part <= 0.0:
			continue
		# Divisé par la masse : une table lourde bouge moins qu'un tonneau.
		corps.apply_central_impulse((sens_vers(corps.global_position)
			+ Vector3.UP * 0.25) * puissance * part * corps.mass * 0.5)
		if degats_decor > 0:
			corps.encaisse(int(degats_decor * part), centre)


## Repousse les monstres. Retourne les identifiants touchés, que l'appelant
## passe ensuite au resolver s'il veut aussi leur infliger des dégâts.
func sur_monstres(monstres: Dictionary) -> Array:
	var touches: Array = []
	for id: int in monstres:
		var avatar: MonsterAvatar = monstres[id]
		if not is_instance_valid(avatar):
			continue
		var part: float = attenuation(avatar.global_position)
		if part <= 0.0:
			continue
		avatar.repousse(sens_vers(avatar.global_position) * puissance * part)
		touches.append(id)
	return touches


## Projette le joueur. C'est ici que le souffle cesse d'être un effet visuel :
## perdre le contrôle une demi-seconde est la seule chose qui fasse ressentir
## une explosion de l'intérieur.
func sur_joueur(joueur: PlayerAvatar, tuning: Tuning) -> void:
	if epargne_le_lanceur or joueur == null or not is_instance_valid(joueur):
		return
	var part: float = attenuation(joueur.global_position)
	if part <= 0.0:
		return

	# Une part d'élévation, sinon la projection rase le sol : on est poussé
	# sans jamais décoller, et le frottement l'absorbe en deux mètres.
	var sens: Vector3 = (sens_vers(joueur.global_position)
		+ Vector3.UP * tuning.souffle_elevation).normalized()
	var vitesse: float = puissance * part * tuning.souffle_effet_sur_joueur

	# En dessous du seuil, on ne projette pas du tout. Un souffle lointain qui
	# vous décolle d'un demi-mètre ne se lit pas comme une explosion, il se lit
	# comme un bug de collision.
	if vitesse < tuning.souffle_seuil_projection:
		return
	joueur.projete(sens * vitesse, centre)
