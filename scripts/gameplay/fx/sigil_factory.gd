class_name SigilFactory
extends RefCounted
## Dessine le diagramme d'invocation d'un sort — et toujours le même.
##
## ── POURQUOI UNE TEXTURE ET NON DES MAILLAGES ────────────────────────────
##
## Le premier diagramme était fait de petites boîtes : deux anneaux et une
## étoile, une centaine de nœuds. Il ne pouvait pas être plus riche sans coûter
## une centaine de nœuds de plus par lancer, et il ne pouvait pas avoir de traits
## fins — une boîte de deux millimètres disparaît ou scintille.
##
## Un cercle magique est du DESSIN AU TRAIT. On le dessine donc, dans une image,
## une fois, et on l'affiche sur un quad. Traits fins, arcs, glyphes, anneaux
## concentriques : tout devient possible et rien ne coûte plus cher.
##
## ── POURQUOI IL EST FIXE ─────────────────────────────────────────────────
##
## Le tracé est tiré d'une graine dérivée du NOM du sort. Boule de Feu a donc
## toujours exactement le même diagramme, sur toutes les machines et d'une partie
## à l'autre. C'est ce qui permet de l'apprendre : au bout de quelques heures on
## reconnaît un sort à son cercle avant même de voir son effet.
##
## Les paramètres du sort pilotent la structure — le nombre de côtés vient de la
## famille de comportement, le nombre de satellites de la portée, les anneaux du
## temps de recharge. Un sort lourd a donc un cercle plus chargé qu'un sort
## rapide, sans qu'on ait rien à régler à la main.

const TAILLE: int = 512
## Marge laissée au bord : sans elle les satellites se font trancher.
const MARGE: float = 26.0

## Un diagramme par sort et par couche, gardé pour toute la session. Sans ce
## cache, chaque lancer redessinerait un demi-million de pixels.
static var _cache: Dictionary = {}


## Les deux couches d'un sort : l'anneau extérieur et le cœur.
##
## Deux et non une, parce qu'elles tournent en sens contraire. Un seul disque
## qui tourne se lit comme une roue ; deux qui se contrarient se lisent comme un
## mécanisme — et c'est toute la différence entre « ça bouge » et « ça calcule ».
static func couches(effet: SpellEffect) -> Array[ImageTexture]:
	var cle: String = effet.nom
	if _cache.has(cle):
		return _cache[cle]

	var graine: int = _graine(effet.nom)
	var out: Array[ImageTexture] = [
		_dessine_l_exterieur(effet, graine),
		_dessine_le_coeur(effet, graine),
	]
	_cache[cle] = out
	return out


## djb2, comme `RngService._derive_seed`, et pour la même raison : `String.hash()`
## n'est pas garanti stable entre versions du moteur, et un diagramme qui
## changerait à la mise à jour cesserait d'être reconnaissable.
static func _graine(nom: String) -> int:
	var h: int = 5381
	for i: int in nom.length():
		h = ((h << 5) + h + nom.unicode_at(i)) & 0x7FFFFFFF
	return h


# ── Les deux couches ──────────────────────────────────────────────────────

## L'extérieur : les anneaux du pourtour, les graduations, les satellites.
##
## Le vocabulaire est celui des cercles d'invocation classiques : deux anneaux
## serrés en bordure, un anneau gradué, et de petits cercles posés RÉGULIÈREMENT
## sur le pourtour. Régulièrement et non au hasard — un satellite mal placé se
## lit comme une erreur de tracé, pas comme une intention.
static func _dessine_l_exterieur(effet: SpellEffect, graine: int) -> ImageTexture:
	var img := _image_vide()
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var c: float = float(TAILLE) * 0.5
	var r: float = c - MARGE

	# La bordure : deux traits serrés. C'est ce qui donne son épaisseur au bord
	# sans avoir à dessiner un anneau épais, qui paraîtrait lourd.
	_cercle(img, c, c, r, 2.0)
	_cercle(img, c, c, r - 6.0, 1.0)

	# L'anneau gradué. Son pas vient de la recharge : un sort lent porte un
	# cadran plus fin, donc a l'air plus savant — et deux sorts de vitesses
	# différentes ne se confondent pas.
	var interieur: float = r - 34.0
	_cercle(img, c, c, interieur, 1.0)
	var graduations: int = clampi(int(effet.cooldown * 16.0) + 32, 32, 108)
	for i: int in graduations:
		var a: float = TAU * float(i) / float(graduations)
		var longue: bool = i % 8 == 0
		_rayon(img, c, c, interieur, r - (7.0 if longue else 20.0), a,
			2.0 if longue else 1.0)

	# Les satellites, sur les sommets du polygone du cœur : les deux couches
	# partagent ainsi leur ossature, et le diagramme se lit comme UN dessin et
	# non comme deux superposés.
	var cotes: int = _cotes_de(effet)
	var rs: float = 22.0 + float(_portee_de(effet)) * 0.25
	rs = clampf(rs, 18.0, 34.0)
	for i: int in cotes:
		var a: float = -PI * 0.5 + TAU * float(i) / float(cotes)
		var sx: float = c + cos(a) * interieur
		var sy: float = c + sin(a) * interieur
		_cercle(img, sx, sy, rs, 1.5)
		_cercle(img, sx, sy, rs * 0.5, 1.0)
		# Un point plein au centre d'un satellite sur deux : l'alternance donne
		# un rythme au pourtour, là où des satellites tous identiques font une
		# frise sans direction.
		if i % 2 == 0:
			_disque(img, sx, sy, rs * 0.18)

	return _finalise(img)


## Le cœur : les polygones inscrits, l'étoile, les anneaux internes.
static func _dessine_le_coeur(effet: SpellEffect, graine: int) -> ImageTexture:
	var img := _image_vide()
	var rng := RandomNumberGenerator.new()
	rng.seed = graine ^ 0x5BF03635
	var c: float = float(TAILLE) * 0.5
	var r: float = c - MARGE - 52.0

	_cercle(img, c, c, r, 1.5)

	# LE POLYGONE VIENT DE LA FAMILLE DU SORT.
	#
	# Trois côtés pour un projectile, quatre pour une zone, cinq pour un soin…
	# La forme n'est donc pas décorative : deux sorts de la même famille
	# partagent leur ossature, et l'oeil apprend la grammaire avant les sorts.
	var cotes: int = _cotes_de(effet)
	var tourne: float = -PI * 0.5
	_polygone(img, c, c, r, cotes, tourne, 2.0)
	_etoile(img, c, c, r, cotes, tourne, 1.5)

	# Un second polygone, tourné d'un demi-pas et plus petit : c'est lui qui
	# donne la profondeur du tracé sur les modèles classiques.
	_polygone(img, c, c, r * 0.72, cotes, tourne + PI / float(cotes), 1.0)

	# Un petit cercle à chaque sommet — présent sur presque tous les cercles
	# d'invocation, et c'est ce qui les empêche de ressembler à un logo.
	for i: int in cotes:
		var a: float = tourne + TAU * float(i) / float(cotes)
		_cercle(img, c + cos(a) * r, c + sin(a) * r, 9.0, 1.0)

	# Les anneaux du noyau, avec un anneau POINTILLÉ entre les deux : le
	# pointillé est ce qui distingue un cercle d'invocation d'une cible.
	_cercle(img, c, c, r * 0.46, 1.5)
	_pointille(img, c, c, r * 0.38, clampi(cotes * 6, 24, 60), 1.0)
	_cercle(img, c, c, r * 0.22, 1.5)
	_cercle(img, c, c, r * 0.09, 2.0)

	# Trois marques au noyau, tirées de la graine : deux sorts de même famille
	# et même recharge se distinguent par elles, et par elles seules.
	for i: int in 3:
		var a: float = rng.randf() * TAU
		_rayon(img, c, c, r * 0.22, r * 0.38, a, 2.0)

	return _finalise(img)


## Nombre de côtés du polygone central, par famille de comportement.
##
## Table explicite et non un modulo sur l'enum : l'ordre des comportements
## changerait la forme de la moitié des sorts au prochain ajout, et un joueur
## qui a appris à les reconnaître serait trahi par une mise à jour.
static func _cotes_de(effet: SpellEffect) -> int:
	var C := SpellEffect.Comportement
	match effet.comportement:
		C.PROJECTILE, C.DRAIN:
			return 3
		C.MUR, C.TRAINEE, C.GEL:
			return 4
		C.SOIN, C.TOTEM:
			return 5
		C.NOVA, C.REPULSION, C.ATTRACTION:
			return 6
		C.CONE, C.DASH:
			return 7
		C.TELEPORT, C.PERMUTATION, C.VOILE, C.LEURRE:
			return 8
	return 5


static func _portee_de(effet: SpellEffect) -> float:
	return maxf(maxf(effet.portee, effet.distance), maxf(effet.rayon, effet.largeur))


# ── Le crayon ─────────────────────────────────────────────────────────────
#
# Tout est dessiné en BLANC sur du transparent. La couleur vient du matériau,
# donc la même image sert à toutes les écoles — c'est ce qui permet de garder
# un seul diagramme par sort au lieu d'un par sort et par teinte.

static func _image_vide() -> Image:
	var img := Image.create_empty(TAILLE, TAILLE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	return img


## Les mipmaps sont générées APRÈS le tracé — avant, elles seraient calculées
## sur une image vide. Sans elles, un trait d'un pixel fourmille dès que le
## cercle tourne ; avec, il s'estompe proprement.
static func _finalise(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _point(img: Image, x: float, y: float, epaisseur: float) -> void:
	var demi: int = maxi(int(epaisseur * 0.5), 0)
	for dy: int in range(-demi, demi + 1):
		for dx: int in range(-demi, demi + 1):
			var px: int = int(x) + dx
			var py: int = int(y) + dy
			if px >= 0 and py >= 0 and px < TAILLE and py < TAILLE:
				img.set_pixel(px, py, Color(1, 1, 1, 1))


static func _cercle(img: Image, cx: float, cy: float, rayon: float,
		epaisseur: float) -> void:
	if rayon <= 0.5:
		return
	# Un pas par pixel de circonférence : moins, le cercle se pointille ; plus,
	# on repasse cent fois sur les mêmes pixels.
	var pas: int = maxi(int(TAU * rayon), 12)
	for i: int in pas:
		var a: float = TAU * float(i) / float(pas)
		_point(img, cx + cos(a) * rayon, cy + sin(a) * rayon, epaisseur)


static func _segment(img: Image, x1: float, y1: float, x2: float, y2: float,
		epaisseur: float) -> void:
	var longueur: float = maxf(absf(x2 - x1), absf(y2 - y1))
	var pas: int = maxi(int(longueur), 1)
	for i: int in pas + 1:
		var t: float = float(i) / float(pas)
		_point(img, lerpf(x1, x2, t), lerpf(y1, y2, t), epaisseur)


## Un trait radial, du rayon `de` au rayon `a`, à l'angle donné.
static func _rayon(img: Image, cx: float, cy: float, de: float, a_: float,
		angle: float, epaisseur: float) -> void:
	_segment(img, cx + cos(angle) * de, cy + sin(angle) * de,
		cx + cos(angle) * a_, cy + sin(angle) * a_, epaisseur)


static func _disque(img: Image, cx: float, cy: float, rayon: float) -> void:
	var r: int = maxi(int(rayon), 1)
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if float(dx * dx + dy * dy) <= rayon * rayon:
				_point(img, cx + float(dx), cy + float(dy), 1.0)


## Un anneau en tirets. C'est lui qui dit « cercle d'invocation » plutôt que
## « cible » : une mire est faite de traits pleins, un sceau de traits comptés.
static func _pointille(img: Image, cx: float, cy: float, rayon: float,
		tirets: int, epaisseur: float) -> void:
	if rayon <= 1.0 or tirets <= 0:
		return
	var pas: float = TAU / float(tirets)
	for i: int in tirets:
		var debut: float = pas * float(i)
		var fin: float = debut + pas * 0.55
		var etapes: int = maxi(int(rayon * pas * 0.6), 2)
		for j: int in etapes + 1:
			var a: float = lerpf(debut, fin, float(j) / float(etapes))
			_point(img, cx + cos(a) * rayon, cy + sin(a) * rayon, epaisseur)


static func _polygone(img: Image, cx: float, cy: float, rayon: float,
		cotes: int, tourne: float, epaisseur: float) -> void:
	if cotes < 3:
		return
	for i: int in cotes:
		var a1: float = tourne + TAU * float(i) / float(cotes)
		var a2: float = tourne + TAU * float(i + 1) / float(cotes)
		_segment(img, cx + cos(a1) * rayon, cy + sin(a1) * rayon,
			cx + cos(a2) * rayon, cy + sin(a2) * rayon, epaisseur)


## Les cordes qui sautent un sommet. C'est ce tracé-là, et pas le polygone, qui
## fait lire « pentagramme » plutôt que « pentagone ».
static func _etoile(img: Image, cx: float, cy: float, rayon: float, cotes: int,
		tourne: float, epaisseur: float) -> void:
	if cotes < 5:
		return
	var saut: int = 2 if cotes % 2 == 1 else 3
	if cotes % saut == 0:
		saut = 2
	for i: int in cotes:
		var a1: float = tourne + TAU * float(i) / float(cotes)
		var a2: float = tourne + TAU * float((i + saut) % cotes) / float(cotes)
		_segment(img, cx + cos(a1) * rayon, cy + sin(a1) * rayon,
			cx + cos(a2) * rayon, cy + sin(a2) * rayon, epaisseur)
