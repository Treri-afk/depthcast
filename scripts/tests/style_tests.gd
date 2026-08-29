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


## Règle 4 : le trait existe là où il sert, et pas ailleurs.
func _check_traits() -> void:
	var p: Palette = Content.palette
	# Tout est cerné, mais la hiérarchie du trait doit tenir : c'est elle qui
	# hiérarchise le regard. Un mur aussi dessiné qu'un monstre noierait le
	# monstre dans le décor.
	var epaisseurs: Dictionary = {}
	for role: int in [MaterialLibrary.Role.DECOR, MaterialLibrary.Role.OBJET,
			MaterialLibrary.Role.INTERACTIF, MaterialLibrary.Role.CREATURE]:
		var mat := MaterialLibrary.aplat(p.mur, role)
		var trace := (mat.next_pass as ShaderMaterial).next_pass as ShaderMaterial
		epaisseurs[role] = float(trace.get_shader_parameter("epaisseur"))

	verifie("tout est cerné, décor compris", epaisseurs.size() == 4)
	verifie("un objet est plus dessiné qu'un mur",
		epaisseurs[MaterialLibrary.Role.OBJET] > epaisseurs[MaterialLibrary.Role.DECOR])
	verifie("un interactif est plus dessiné qu'un objet",
		epaisseurs[MaterialLibrary.Role.INTERACTIF] > epaisseurs[MaterialLibrary.Role.OBJET])
	verifie("une créature est la plus dessinée de toutes",
		epaisseurs[MaterialLibrary.Role.CREATURE] > epaisseurs[MaterialLibrary.Role.INTERACTIF])

	var bestiole := MaterialLibrary.aplat(p.creature_commune,
		MaterialLibrary.Role.CREATURE)
	var clair := bestiole.next_pass as ShaderMaterial
	verifie("une créature porte un liseré clair", clair != null)
	if clair == null:
		return
	var encre := clair.next_pass as ShaderMaterial
	verifie("puis un trait d'encre par-dessus", encre != null)
	if encre == null:
		return

	verifie("l'encre est plus épaisse que le liseré, sinon elle le masquerait",
		float(encre.get_shader_parameter("epaisseur"))
			> float(clair.get_shader_parameter("epaisseur")))
	verifie("le liseré prend la couleur claire de la palette",
		clair.get_shader_parameter("couleur") == p.lisere_blanc)
	verifie("l'encre prend celle de la palette",
		encre.get_shader_parameter("couleur") == p.encre)



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

	var post := PostProcess.cree(p)
	verifie("la trame est dessinée avant le HUD", post.layer < 0,
		"calque %d" % post.layer)
	var voile := post.get_child(0) as ColorRect
	verifie("elle couvre tout l'écran et ne capte pas la souris",
		voile != null and voile.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	post.free()
