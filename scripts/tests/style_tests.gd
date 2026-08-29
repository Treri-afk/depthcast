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
	var decor := MaterialLibrary.aplat(p.mur, MaterialLibrary.Role.DECOR)
	verifie("le décor n'est pas cerné — cent blocs soulignés font une bouillie",
		decor.next_pass == null)

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

	var objet := MaterialLibrary.aplat(p.caisse, MaterialLibrary.Role.OBJET)
	var encre_objet := (objet.next_pass as ShaderMaterial).next_pass as ShaderMaterial
	verifie("une créature est cernée plus fort qu'un objet",
		float(encre.get_shader_parameter("epaisseur"))
			> float(encre_objet.get_shader_parameter("epaisseur")))


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
