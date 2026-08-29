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
uniform sampler2D normales : hint_normal_roughness_texture, filter_nearest, repeat_disable;

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
// Écart d'orientation entre deux pixels voisins, en cosinus. C'est ce qui
// distingue une CASSURE d'une COURBURE : sur une sphère les normales tournent
// doucement, sur une arête elles sautent. 0.25 ≈ 40 degrés.
uniform float contour_seuil_normale : hint_range(0.02, 0.9) = 0.25;

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


// Arête géométrique.
//
// Deux mesures complémentaires, et chacune corrige un défaut de l'autre.
//
// La PROFONDEUR attrape les silhouettes — là où un objet se détache de ce qui
// est derrière. Comparée à la moyenne des voisins opposés, elle ignore les
// surfaces vues en rasant : sur un plan, même très incliné, la profondeur varie
// linéairement et la moyenne retombe sur le centre.
//
// Mais elle ne distingue pas une COURBURE d'une CASSURE : sur une sphère, la
// profondeur n'est pas linéaire non plus, et le test s'affolait — d'où les
// traits parasites sur les objets ronds.
//
// Les NORMALES tranchent. Sur une sphère elles tournent doucement d'un pixel à
// l'autre ; sur une arête elles sautent. Un seuil sur leur écart sépare donc
// exactement ce que la profondeur confondait.
float rupture_geometrique(vec2 uv_centre, vec2 pas, vec2 grille) {
	float d0 = texture(profondeur, uv_centre).r;
	if (d0 <= 0.0) {
		return 0.0;
	}

	float gauche = texture(profondeur, accroche(uv_centre - vec2(pas.x, 0.0), grille)).r;
	float droite = texture(profondeur, accroche(uv_centre + vec2(pas.x, 0.0), grille)).r;
	float haut = texture(profondeur, accroche(uv_centre - vec2(0.0, pas.y), grille)).r;
	float bas = texture(profondeur, accroche(uv_centre + vec2(0.0, pas.y), grille)).r;

	// Dérivée seconde : la pente s'annule, seule la cassure subsiste.
	float saut = max(abs((gauche + droite) * 0.5 - d0),
		abs((haut + bas) * 0.5 - d0)) / max(d0, 0.00001);
	float trace_profondeur = step(contour_seuil_profondeur, saut);

	// Écart d'orientation. Les normales sont stockées en [0,1], on les ramène
	// dans [-1,1] avant de comparer.
	vec3 n0 = texture(normales, uv_centre).xyz * 2.0 - 1.0;
	vec3 ng = texture(normales, accroche(uv_centre - vec2(pas.x, 0.0), grille)).xyz * 2.0 - 1.0;
	vec3 nd = texture(normales, accroche(uv_centre + vec2(pas.x, 0.0), grille)).xyz * 2.0 - 1.0;
	vec3 nh = texture(normales, accroche(uv_centre - vec2(0.0, pas.y), grille)).xyz * 2.0 - 1.0;
	vec3 nb = texture(normales, accroche(uv_centre + vec2(0.0, pas.y), grille)).xyz * 2.0 - 1.0;

	float ecart = 0.0;
	ecart = max(ecart, 1.0 - dot(n0, ng));
	ecart = max(ecart, 1.0 - dot(n0, nd));
	ecart = max(ecart, 1.0 - dot(n0, nh));
	ecart = max(ecart, 1.0 - dot(n0, nb));
	float trace_normale = step(contour_seuil_normale, ecart);

	// La silhouette se trace sur la profondeur seule ; les arêtes internes
	// demandent en plus une vraie cassure d'orientation. Une surface courbe ne
	// satisfait ni l'une ni l'autre.
	return max(trace_profondeur, trace_normale);
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

		float trace_forme = rupture_geometrique(uv, pas, grille);

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
