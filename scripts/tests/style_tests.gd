class_name StyleTests
extends TestSuite
## Les règles de la ligne claire, vérifiées comme le reste.
##
## Une identité graphique tient par la discipline. Autant en faire des tests :
## une entorse devient un échec visible, pas une dérive qu'on remarque six mois
## plus tard sur une capture d'écran.


func nom() -> String:
	return "Style — règles de la ligne claire"


func execute() -> void:
	_check_ombre_commune()
	_check_traits()
	_check_palette()
	_check_trame()
	_check_interface()


## Règle 2 : l'ombre est la même pour toute surface, jamais un albédo assombri.
func _check_ombre_commune() -> void:
	var p: Palette = Content.palette
	var pierre := MaterialLibrary.aplat(p.mur, MaterialLibrary.Role.DECOR)
	var caisse := MaterialLibrary.aplat(p.caisse, MaterialLibrary.Role.OBJET)
	var bestiole := MaterialLibrary.aplat(p.creature_commune, MaterialLibrary.Role.CREATURE)

	var ombres: Array = []
	for mat: ShaderMaterial in [pierre, caisse, bestiole]:
		ombres.append(mat.get_shader_parameter("couleur_ombre"))

	verifie("un mur, une caisse et une créature partagent la même ombre",
		ombres[0] == ombres[1] and ombres[1] == ombres[2], str(ombres))
	verifie("cette ombre est celle de la palette", ombres[0] == p.ombre)
	verifie("l'ombre n'est pas l'albédo assombri",
		ombres[0] != p.mur.darkened(0.5))

	# Et une ombre assombrit — toujours. La règle de l'ombre absolue suppose
	# des surfaces plus claires qu'elle ; appliquée telle quelle à un décor
	# sombre, elle rendait l'ombre plus CLAIRE que la face éclairée et tout le
	# décor s'écrasait sur une seule valeur violette. Le plafond corrige ça,
	# et c'est ce test qui interdit de le retirer.
	for teinte: Color in [p.mur_couloir, p.mur, p.pilier, p.sol, p.lisere_blanc]:
		var ombre: Color = _ombre_de(teinte)
		verifie("l'ombre de %s reste plus sombre qu'elle" % teinte.to_html(false),
			ombre.v < teinte.v, "ombre %s" % ombre.to_html(false))


## Transcription fidèle de `ombre_de()` du shader ligne_claire. Les deux
## formulations doivent rester alignées : ce qui est vérifié ici est ce qui est
## dessiné là-bas.
func _ombre_de(teinte: Color) -> Color:
	var p: Palette = Content.palette
	var out := Color.BLACK
	for i: int in 3:
		var c: float = p.ombre[i]
		var t: float = teinte[i]
		var absolue: float = lerpf(c, c * t * 2.0, p.melange_ombre)
		var relative: float = t * c * 2.0 * p.plafond_ombre
		out[i] = minf(absolue, relative)
	return out


## Règle 4 : le trait est tracé une fois, en espace écran.
##
## Plus aucune coque sur les objets : sur des boîtes, chaque face se dilatait
## selon sa propre normale et le contour se déchirait aux arêtes. La hiérarchie
## du regard passe désormais par le contraste de matière.
func _check_traits() -> void:
	var p: Palette = Content.palette

	for role: int in [MaterialLibrary.Role.DECOR, MaterialLibrary.Role.OBJET,
			MaterialLibrary.Role.INTERACTIF, MaterialLibrary.Role.CREATURE]:
		verifie("aucune coque de contour sur les matériaux (rôle %d)" % role,
			MaterialLibrary.aplat(p.mur, role).next_pass == null)

	# Ce qui compte se détache par un albédo plus clair, sans ligne en plus.
	var clartes: Array[float] = []
	for role: int in [MaterialLibrary.Role.DECOR, MaterialLibrary.Role.OBJET,
			MaterialLibrary.Role.INTERACTIF, MaterialLibrary.Role.CREATURE]:
		var mat := MaterialLibrary.aplat(p.mur, role)
		clartes.append((mat.get_shader_parameter("albedo") as Color).v)

	var croissant: bool = true
	for i: int in clartes.size() - 1:
		if clartes[i + 1] <= clartes[i]:
			croissant = false
	verifie("décor, objet, interactif, créature : contraste croissant",
		croissant, str(clartes))


## Règle 5 : la palette est fermée et le décor reste sourd.
func _check_palette() -> void:
	var p: Palette = Content.palette
	verifie("la palette est chargée", p != null)

	# Le décor doit rester peu saturé : la magie est la seule chose vive.
	var decor: Array[Color] = [p.sol, p.mur, p.pilier, p.estrade, p.mur_couloir]
	var trop_vif: Array = []
	for c: Color in decor:
		if c.s > 0.25:
			trop_vif.append(c.to_html(false))
	verifie("le décor reste sourd — la magie est la seule chose vive",
		trop_vif.is_empty(), str(trop_vif))

	# Les écoles, elles, doivent être franchement distinctes les unes des autres.
	var ecarts_faibles: Array = []
	for i: int in Content.ecoles.size():
		for j: int in range(i + 1, Content.ecoles.size()):
			var a: Color = Content.ecoles[i].couleur
			var b: Color = Content.ecoles[j].couleur
			if absf(a.h - b.h) < 0.06:
				ecarts_faibles.append("%s/%s" % [Content.ecoles[i].nom, Content.ecoles[j].nom])
	verifie("deux écoles ne partagent pas la même teinte",
		ecarts_faibles.is_empty(), str(ecarts_faibles))


## La trame pixel doit rester fine, et surtout ne jamais recouvrir le HUD.
func _check_trame() -> void:
	var p: Palette = Content.palette
	verifie("la trame reste fine — au-delà de 4, la vue subjective devient illisible",
		p.pixel_taille <= 4.0, "%.1f" % p.pixel_taille)
	verifie("le contour est tracé", p.contour_epaisseur > 0.0)
	verifie("son seuil laisse passer les vraies ruptures sans souligner le bruit",
		p.contour_seuil > 0.02 and p.contour_seuil < 0.3,
		"%.3f" % p.contour_seuil)

	# Le contour ne voit que la luminance : si deux surfaces adjacentes ont la
	# même valeur, leur jonction n'existe pas à l'écran. L'écart de valeur est
	# donc une contrainte technique, pas un goût.
	verifie("le sol et les murs ont des valeurs franchement distinctes",
		absf(p.sol.v - p.mur.v) > 0.2, "écart %.2f" % absf(p.sol.v - p.mur.v))
	verifie("idem dans les couloirs",
		absf(p.sol_couloir.v - p.mur_couloir.v) > 0.2,
		"écart %.2f" % absf(p.sol_couloir.v - p.mur_couloir.v))
	verifie("le filtre de couleur est un mode connu",
		p.filtre >= 0 and p.filtre <= 4, "mode %d" % p.filtre)

	# Le grain doit rester du papier, pas du bruit vidéo.
	verifie("le grain reste discret", p.grain_force <= 0.1,
		"%.3f" % p.grain_force)

	# La brume par paliers ne vaut que si elle en a plusieurs : à un seul
	# palier c'est un mur de couleur, à trop ce redevient un dégradé.
	verifie("la brume a plusieurs paliers sans redevenir un dégradé",
		p.brume_paliers >= 2 and p.brume_paliers <= 6,
		"%d palier(s)" % p.brume_paliers)
	verifie("elle commence avant de finir", p.brume_debut < p.brume_fin,
		"%.0f → %.0f" % [p.brume_debut, p.brume_fin])
	verifie("elle fond vers la couleur de fond, pas vers une autre",
		p.brume_couleur == p.fond)

	var post := PostProcess.cree(p)
	verifie("le post-traitement est un quad de la passe 3D", post is MeshInstance3D)
	verifie("il porte un matériau de shader",
		post.material_override is ShaderMaterial)
	# Sans volume englobant démesuré, il disparaît dès que la caméra tourne.
	verifie("il échappe à l'élimination par le frustum",
		post.custom_aabb.size.x > 1000.0)
	verifie("il ne projette pas d'ombre",
		post.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	post.free()


## L'interface obéit aux mêmes règles que le monde. Sans ça elle flotte
## au-dessus de l'image au lieu de lui appartenir.
func _check_interface() -> void:
	var p: Palette = Content.palette
	var panneau := HudStyle.panneau()

	verifie("les panneaux ont des coins francs — un arrondi est un dégradé de forme",
		panneau.corner_radius_top_left == 0)
	verifie("ils sont cernés d'encre",
		panneau.border_color == p.encre and panneau.border_width_top > 0)
	verifie("leur fond vient de la palette",
		Color(panneau.bg_color.r, panneau.bg_color.g, panneau.bg_color.b) == p.fond)

	# L'accent d'école est la seule couleur vive tolérée dans l'interface.
	var accent := HudStyle.panneau(Color(1, 0, 0))
	verifie("un accent épaissit le pied de carte",
		accent.border_width_bottom > accent.border_width_top)

	var b := Button.new()
	HudStyle.habille_bouton(b)
	verifie("les boutons portent les trois états qui comptent",
		b.has_theme_stylebox_override("normal")
			and b.has_theme_stylebox_override("hover")
			and b.has_theme_stylebox_override("pressed"))
	b.free()
