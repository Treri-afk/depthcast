class_name HudStyle
extends RefCounted
## Le vocabulaire visuel de l'interface, aligné sur la ligne claire.
##
## Le HUD est la moitié de ce qu'on voit : s'il reste en gris arrondi par
## défaut, il flotte au-dessus de l'image au lieu de lui appartenir. Mêmes
## règles qu'ailleurs — aplats, bordure d'encre, coins francs, palette fermée.
##
## Coins francs : un arrondi est un dégradé de forme. La même raison qui
## interdit les demi-teintes interdit les angles mous.

const RAYON_COINS: int = 0
const EPAISSEUR_BORDURE: int = 3
const MARGE: int = 12


static func _p() -> Palette:
	return Content.palette


## Fond de panneau : aplat sombre, cerné d'encre.
static func panneau(accent: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(_p().fond.r, _p().fond.g, _p().fond.b, 0.88)
	style.set_corner_radius_all(RAYON_COINS)
	style.set_content_margin_all(MARGE)
	style.set_border_width_all(EPAISSEUR_BORDURE)
	style.border_color = _p().encre
	# Un liseré d'accent en pied de carte : la seule couleur vive de l'UI, et
	# elle dit à quelle école appartient la carte.
	if accent.a > 0.0:
		style.border_width_bottom = EPAISSEUR_BORDURE * 2
		style.border_color = accent
	return style


## Fond d'un bouton, dans les trois états qui comptent.
static func bouton(survol: bool = false, presse: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base: Color = _p().mur
	if presse:
		base = _p().ombre
	elif survol:
		base = _p().sol
	style.bg_color = base
	style.set_corner_radius_all(RAYON_COINS)
	style.set_content_margin_all(8)
	style.set_border_width_all(EPAISSEUR_BORDURE)
	style.border_color = _p().encre
	return style


## Applique le vocabulaire à un bouton existant.
static func habille_bouton(b: Button) -> void:
	b.add_theme_stylebox_override("normal", bouton())
	b.add_theme_stylebox_override("hover", bouton(true))
	b.add_theme_stylebox_override("pressed", bouton(false, true))
	b.add_theme_stylebox_override("disabled", bouton())
	b.add_theme_color_override("font_color", _p().lisere_blanc)
	b.add_theme_color_override("font_hover_color", _p().encre)
	b.add_theme_color_override("font_disabled_color",
		Color(_p().lisere_blanc.r, _p().lisere_blanc.g, _p().lisere_blanc.b, 0.35))
