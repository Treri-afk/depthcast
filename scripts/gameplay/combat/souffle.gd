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


## Vitesse verticale nécessaire pour culminer à une hauteur donnée.
##
## Ici et pas dans l'un des deux corps qui s'en servent : le joueur et les
## monstres plafonnent leur envol par la même règle, et deux copies de la même
## racine carrée finiraient par se contredire.
static func vitesse_pour_culminer_a(hauteur: float, gravite: float) -> float:
	return sqrt(2.0 * maxf(gravite, 0.001) * maxf(hauteur, 0.0))


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
func sur_monstres(monstres: Dictionary, tuning: Tuning) -> Array:
	var touches: Array = []
	for id: int in monstres:
		var avatar: MonsterAvatar = monstres[id]
		if is_instance_valid(avatar) and pousse(avatar, tuning):
			touches.append(id)
	return touches


## Repousse un monstre. Retourne false s'il était hors de portée.
##
## L'élévation est plus basse que celle du joueur : les voir décoller est la
## moitié du plaisir d'une explosion, les voir rester en l'air trois secondes en
## ferait une immobilisation.
func pousse(avatar: MonsterAvatar, tuning: Tuning) -> bool:
	var part: float = attenuation(avatar.global_position)
	if part <= 0.0:
		return false
	var sens: Vector3 = (sens_vers(avatar.global_position)
		+ Vector3.UP * tuning.souffle_elevation_monstres).normalized()
	var vecteur: Vector3 = sens * puissance * part
	# La verticale est plafonnée, l'horizontale non — même règle que pour le
	# joueur. Sans ça, un monstre pris au centre exact reçoit toute la puissance
	# à la verticale et part à quinze mètres, très au-dessus des murs.
	vecteur.y = minf(vecteur.y, vitesse_pour_culminer_a(
		tuning.souffle_hauteur_max_monstres, tuning.gravite))
	avatar.repousse(vecteur)
	return true


## Applique le souffle à tout ce que la PHYSIQUE trouve dans le rayon.
##
## Variante des méthodes ci-dessus, qui reçoivent des listes tenues par le jeu.
## Ici on interroge le monde, et c'est plus juste pour une explosion qui part du
## décor : un tonneau n'a aucune raison de connaître le registre des monstres.
## C'est aussi ce qui fait chaîner les explosions sans une ligne de plus — un
## tonneau en trouve un autre exactement comme il trouve une caisse.
##
## Retourne ce qui a été touché : `monstres` et `joueurs` par identifiant, à
## passer au resolver par l'appelant s'il veut aussi blesser (R4).
func sur_les_corps_autour(depuis: Node3D, tuning: Tuning,
		degats_decor: int = 0) -> Dictionary:
	var touches: Dictionary = {"monstres": [], "joueurs": []}
	var espace: PhysicsDirectSpaceState3D = depuis.get_world_3d().direct_space_state
	if espace == null:
		return touches

	var boule := SphereShape3D.new()
	boule.radius = rayon
	var requete := PhysicsShapeQueryParameters3D.new()
	requete.shape = boule
	requete.transform = Transform3D(Basis(), centre)
	requete.collide_with_bodies = true
	requete.collide_with_areas = false
	# On ne se souffle pas soi-même : le tonneau qui explose est déjà mort.
	requete.exclude = [depuis.get_rid()]

	for resultat: Dictionary in espace.intersect_shape(requete, 48):
		var corps: Node = resultat.get("collider")
		if corps == null or not is_instance_valid(corps):
			continue

		var meuble := corps as PropDestructible
		if meuble != null:
			sur_objets([meuble], degats_decor)
			continue

		var monstre := corps as MonsterAvatar
		if monstre != null:
			if pousse(monstre, tuning):
				(touches["monstres"] as Array).append(monstre.monster_id)
			continue

		var joueur := corps as PlayerAvatar
		if joueur != null:
			sur_joueur(joueur, tuning)
			(touches["joueurs"] as Array).append(joueur.player_id)

	return touches


## Projette le joueur. C'est ici que le souffle cesse d'être un effet visuel :
## perdre le contrôle une demi-seconde est la seule chose qui fasse ressentir
## une explosion de l'intérieur.
func sur_joueur(joueur: PlayerAvatar, tuning: Tuning) -> void:
	if epargne_le_lanceur:
		return
	_projette(joueur, tuning)


## Projette TOUS les joueurs à portée, lanceur compris ou non.
##
## `epargne_le_lanceur` n'épargne que le lanceur, jamais ses alliés : c'est le
## sens même du drapeau. Une Répulsion fait de celui qui la lance un point
## d'ancrage — pas de toute l'équipe, qui n'a rien demandé.
func sur_les_joueurs(joueurs: Array, tuning: Tuning,
		lanceur: PlayerAvatar = null) -> void:
	for avatar in joueurs:
		if not is_instance_valid(avatar):
			continue
		var est_le_lanceur: bool = avatar == lanceur
		if est_le_lanceur and epargne_le_lanceur:
			continue
		if not est_le_lanceur and not tuning.souffle_pousse_les_allies:
			continue
		_projette(avatar, tuning)


func _projette(joueur: PlayerAvatar, tuning: Tuning) -> void:
	if joueur == null or not is_instance_valid(joueur):
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
		# Trop loin pour décoller, assez près pour la sentir passer. Sans cette
		# secousse il existe une distance à laquelle une explosion ne fait
		# absolument RIEN — et c'est là que le joueur cesse de la craindre.
		joueur.secoue(vitesse)
		return
	joueur.projete(sens * vitesse, centre)
