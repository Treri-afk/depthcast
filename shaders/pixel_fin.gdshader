shader_type canvas_item;
render_mode unshaded;

// Pixellisation fine, en post-traitement plein écran.
//
// L'idée n'est pas de faire du pixel art — les formes restent en 3D — mais de
// poser une grille très fine sur toute l'image. Le résultat est un rendu qui
// « accroche » légèrement, comme une sérigraphie ou un dessin imprimé, et qui
// unifie décor et créatures sous une même trame.
//
// Le HUD est dessiné APRÈS ce passage, sur un calque supérieur : le texte
// reste net. Pixelliser du texte le rendrait illisible sans rien gagner.

uniform sampler2D ecran : hint_screen_texture, filter_nearest, repeat_disable;

// Côté d'un bloc, en pixels d'écran. 2 est déjà perceptible, 4 devient un parti
// pris, au-delà ça écrase la lisibilité en vue subjective.
uniform float taille_bloc : hint_range(1.0, 8.0) = 2.0;

// Quantification des couleurs. Elle prolonge la règle des deux valeurs : moins
// de niveaux, plus de lecture en aplat. À 0 elle est désactivée.
uniform int niveaux_couleur : hint_range(0, 64) = 0;


void fragment() {
	vec2 taille_ecran = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 grille = taille_ecran / max(taille_bloc, 1.0);

	// On échantillonne au CENTRE du bloc, pas à son coin : sinon l'image
	// glisse d'un demi-bloc et les contours se décalent.
	vec2 uv_bloc = (floor(SCREEN_UV * grille) + 0.5) / grille;

	vec4 couleur = texture(ecran, uv_bloc);

	if (niveaux_couleur > 0) {
		float n = float(niveaux_couleur);
		couleur.rgb = floor(couleur.rgb * n + 0.5) / n;
	}

	COLOR = couleur;
}
