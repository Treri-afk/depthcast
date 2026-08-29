shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

// Shader SPATIAL et non canvas_item : Godot refuse hint_depth_texture dans un
// shader d'interface, et sans la profondeur on ne peut pas souligner les arêtes
// géométriques. Le quad est donc dessiné dans la passe 3D, en dernier, et
// couvre l'écran en écrivant POSITION directement.
//
// Le HUD, lui, vit sur un CanvasLayer dessiné après la 3D : il reste net.

// Post-traitement de la ligne claire : trame pixel, contour, filtre de couleur.
//
// ── POURQUOI LE CONTOUR EST ICI ET PLUS SUR LES OBJETS ───────────────────
// La coque inversée dilate chaque face selon sa propre normale. Sur des
// boîtes — dont les arêtes sont dures — les faces voisines se séparent et le
// trait se déchire : c'est le pointillé qu'on voyait sur la jonction
// mur/plafond. En espace écran le trait est continu par construction, il
// s'épaissit librement, et il souligne AUSSI les arêtes internes, ce qui est
// précisément ce que fait un dessin.
//
// La détection se fait sur la luminance : avec des aplats et une ombre de
// couleur fixe, les frontières de luminance tombent exactement sur les
// contours de formes ET sur la limite lumière/ombre.

uniform sampler2D ecran : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D profondeur : hint_depth_texture, filter_nearest, repeat_disable;

group_uniforms Trame;
// Côté d'un bloc en pixels d'écran. 2 accroche discrètement, 4 est un parti pris.
uniform float taille_bloc : hint_range(1.0, 8.0) = 2.0;

group_uniforms Contour;
uniform vec4 contour_couleur : source_color = vec4(0.09, 0.08, 0.14, 1.0);
// Épaisseur en blocs. Le trait suit donc la trame au lieu de la contredire.
uniform float contour_epaisseur : hint_range(0.0, 6.0) = 2.0;
// Écart de luminance à partir duquel on trace. Bas = trait partout, y compris
// dans le bruit ; haut = seules les vraies ruptures sont soulignées.
uniform float contour_seuil : hint_range(0.01, 0.6) = 0.085;
// Rupture de profondeur RELATIVE à partir de laquelle on trace. La profondeur
// brute n'est pas linéaire : comparer un écart absolu tracerait tout au premier
// plan et rien au fond. Un rapport reste juste à toute distance.
uniform float contour_seuil_profondeur : hint_range(0.0005, 0.05) = 0.004;

group_uniforms Grain;
// GRAIN DE PAPIER.
//
// Un bruit fixe, très faible, posé sur toute l'image. Il ne bouge JAMAIS : un
// grain animé fait du bruit vidéo, un grain fixe fait du papier. C'est ce qui
// donne l'impression d'une image imprimée plutôt que calculée.
uniform float grain_force : hint_range(0.0, 0.2) = 0.045;

group_uniforms Filtre;
// 0 aucun · 1 négatif · 2 monochrome · 3 duotone · 4 teinté
uniform int filtre : hint_range(0, 4) = 0;
uniform vec4 filtre_teinte : source_color = vec4(0.45, 0.62, 1.0, 1.0);
uniform vec4 filtre_ombre : source_color = vec4(0.06, 0.05, 0.12, 1.0);
uniform float filtre_force : hint_range(0.0, 1.0) = 1.0;


void vertex() {
	// Le quad mesure 2 unités : VERTEX.xy couvre donc exactement [-1, 1], soit
	// tout l'écran en coordonnées normalisées.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float bruit_fixe(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}


float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}


// Échantillonne au CENTRE du bloc, jamais à son coin : sinon l'image glisse
// d'un demi-bloc et le contour se décale d'autant.
vec2 accroche(vec2 uv, vec2 grille) {
	return (floor(uv * grille) + 0.5) / grille;
}


// Arête géométrique : une VRAIE rupture, pas une surface vue en rasant.
//
// La première version comparait la profondeur du pixel à celle de ses voisins.
// Sur un sol vu de biais, cet écart est énorme alors qu'il n'y a aucune arête :
// d'où les traits qui apparaissaient au milieu de nulle part.
//
// On compare donc chaque pixel à la MOYENNE de ses deux voisins opposés. Sur
// une surface plane, même très inclinée, la profondeur varie linéairement et
// cette moyenne retombe pile sur la valeur du centre : l'écart est nul. Il ne
// devient grand qu'à une vraie discontinuité — un coin, une silhouette.
float rupture_profondeur(vec2 uv_centre, vec2 pas, vec2 grille) {
	float d0 = texture(profondeur, uv_centre).r;
	if (d0 <= 0.0) {
		return 0.0;
	}

	float gauche = texture(profondeur, accroche(uv_centre - vec2(pas.x, 0.0), grille)).r;
	float droite = texture(profondeur, accroche(uv_centre + vec2(pas.x, 0.0), grille)).r;
	float haut = texture(profondeur, accroche(uv_centre - vec2(0.0, pas.y), grille)).r;
	float bas = texture(profondeur, accroche(uv_centre + vec2(0.0, pas.y), grille)).r;

	// Dérivée seconde : la pente s'annule, seule la cassure subsiste.
	float ecart_x = abs((gauche + droite) * 0.5 - d0);
	float ecart_y = abs((haut + bas) * 0.5 - d0);

	return max(ecart_x, ecart_y) / max(d0, 0.00001);
}


vec3 applique_filtre(vec3 couleur) {
	vec3 sortie = couleur;
	float l = luminance(couleur);

	if (filtre == 1) {
		sortie = vec3(1.0) - couleur;
	} else if (filtre == 2) {
		sortie = vec3(l);
	} else if (filtre == 3) {
		// Duotone : une couleur d'ombre, une couleur de lumière, rien entre.
		sortie = mix(filtre_ombre.rgb, filtre_teinte.rgb, l);
	} else if (filtre == 4) {
		sortie = couleur * filtre_teinte.rgb;
	}

	return mix(couleur, sortie, filtre_force);
}


void fragment() {
	vec2 taille_ecran = VIEWPORT_SIZE;
	vec2 grille = taille_ecran / max(taille_bloc, 1.0);
	vec2 uv = accroche(SCREEN_UV, grille);

	vec3 couleur = texture(ecran, uv).rgb;

	if (contour_epaisseur > 0.0) {
		vec2 pas = (1.0 / taille_ecran) * taille_bloc * contour_epaisseur;

		// Sobel sur la luminance. Huit voisins : un contour continu même sur
		// des diagonales, là où quatre voisins laissent des escaliers.
		float hg = luminance(texture(ecran, accroche(SCREEN_UV + vec2(-pas.x, -pas.y), grille)).rgb);
		float h  = luminance(texture(ecran, accroche(SCREEN_UV + vec2( 0.0,   -pas.y), grille)).rgb);
		float hd = luminance(texture(ecran, accroche(SCREEN_UV + vec2( pas.x, -pas.y), grille)).rgb);
		float g  = luminance(texture(ecran, accroche(SCREEN_UV + vec2(-pas.x,  0.0),   grille)).rgb);
		float d  = luminance(texture(ecran, accroche(SCREEN_UV + vec2( pas.x,  0.0),   grille)).rgb);
		float bg = luminance(texture(ecran, accroche(SCREEN_UV + vec2(-pas.x,  pas.y), grille)).rgb);
		float b  = luminance(texture(ecran, accroche(SCREEN_UV + vec2( 0.0,    pas.y), grille)).rgb);
		float bd = luminance(texture(ecran, accroche(SCREEN_UV + vec2( pas.x,  pas.y), grille)).rgb);

		float gx = (hd + 2.0 * d + bd) - (hg + 2.0 * g + bg);
		float gy = (bg + 2.0 * b + bd) - (hg + 2.0 * h + hd);
		float force = sqrt(gx * gx + gy * gy);

		float trace_lumiere = smoothstep(contour_seuil, contour_seuil * 2.2, force);

		float rupture = rupture_profondeur(uv, pas, grille);
		float trace_forme = smoothstep(contour_seuil_profondeur,
			contour_seuil_profondeur * 2.5, rupture);

		// Le plus fort des deux : la luminance attrape la limite lumière/ombre
		// et les changements de matière, la profondeur attrape la géométrie.
		float trace = max(trace_lumiere, trace_forme);
		couleur = mix(couleur, contour_couleur.rgb, trace * contour_couleur.a);
	}

	if (grain_force > 0.0) {
		// Ancré sur les pixels d'écran, donc immobile quand la caméra bouge.
		float g = bruit_fixe(floor(SCREEN_UV * taille_ecran)) - 0.5;
		couleur += vec3(g * grain_force);
	}

	ALBEDO = applique_filtre(couleur);
}
