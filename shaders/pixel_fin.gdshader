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
// ── DEUX APPROCHES ÉCARTÉES, ET POURQUOI ────────────────────────────────
//
// La PROFONDEUR a été essayée pour souligner les arêtes géométriques. Même
// comparée à la moyenne des voisins opposés — ce qui annule la pente et ne
// laisse en principe que les cassures — elle produisait de grands escaliers sur
// les sols. La précision du tampon ne suffit pas sur une grande surface vue en
// rasant : la quantification devient plus grande que la cassure qu'on cherche.
//
// Les NORMALES ont été essayées ensuite pour distinguer courbure et arête. Le
// tampon revient quantifié lui aussi, et le comparer pixel à pixel amplifiait
// cette quantification au lieu de mesurer une orientation.
//
// Reste la luminance seule. Elle ne voit pas une jonction entre deux surfaces
// éclairées à l'identique — c'est sa limite, et on la compense en écartant les
// valeurs de la palette plutôt qu'en ajoutant un tampon de plus.
//
// ── POURQUOI UN SOBEL NU NE SUFFIT PAS ───────────────────────────────────
//
// Un gradient est une dérivée PREMIÈRE : il ne distingue pas une cassure d'une
// pente. Tant que l'image n'était faite que d'aplats, la seule chose qui avait
// une pente était un bord, et la confusion ne se voyait pas. Dès qu'un dégradé
// apparaît — la pénombre d'une ombre portée, le fondu d'une lampe — le Sobel
// s'allume sur TOUTE sa largeur et pose une large bavure sombre au lieu d'un
// trait. C'étaient les traînées au pied des caisses et sur les sols.
//
// D'où la mesure à deux rayons. Doubler le rayon double la mesure sur une
// pente, et la laisse inchangée sur une cassure. Le rapport des deux dit donc
// laquelle des deux on regarde, indépendamment du contraste local.
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


// Hachage ENTIER, pas de trigonométrie.
//
// Le `fract(sin(dot(p, ...)) * 43758.5453)` habituel se nourrit ici de
// coordonnées en pixels : jusqu'à 2000, donc un argument de sinus qui monte à
// 10^5. En simple précision, le sinus n'a plus assez de mantisse à cette
// échelle et ses valeurs se corrèlent d'un pixel au suivant — le « bruit »
// dégénère en rayures verticales régulières sur toute l'image. C'étaient les
// traits qu'on voyait partout, et ils ne venaient pas du contour.
//
// Un hachage sur entiers n'a pas d'échelle : il est aussi bon au pixel 2000
// qu'au pixel 3.
float bruit_fixe(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint n = q.x * 1597334673u ^ q.y * 3812015801u;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 2147483647u) / float(2147483647u);
}


float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}


// Gradient de Sobel de la luminance, mesuré à un rayon donné. Huit voisins :
// un contour continu même sur les diagonales, là où quatre laissent des
// escaliers.
//
// Échantillonné en PIXELS RÉELS, sans passer par la grille : mesuré sur les
// blocs, un contour oblique devient un escalier et on détecterait la trame
// plutôt que la forme.
float sobel(vec2 uv, vec2 pas) {
	float hg = luminance(texture(ecran, uv + vec2(-pas.x, -pas.y)).rgb);
	float h  = luminance(texture(ecran, uv + vec2( 0.0,   -pas.y)).rgb);
	float hd = luminance(texture(ecran, uv + vec2( pas.x, -pas.y)).rgb);
	float g  = luminance(texture(ecran, uv + vec2(-pas.x,  0.0)).rgb);
	float d  = luminance(texture(ecran, uv + vec2( pas.x,  0.0)).rgb);
	float bg = luminance(texture(ecran, uv + vec2(-pas.x,  pas.y)).rgb);
	float b  = luminance(texture(ecran, uv + vec2( 0.0,    pas.y)).rgb);
	float bd = luminance(texture(ecran, uv + vec2( pas.x,  pas.y)).rgb);

	float gx = (hd + 2.0 * d + bd) - (hg + 2.0 * g + bg);
	float gy = (bg + 2.0 * b + bd) - (hg + 2.0 * h + hd);
	return sqrt(gx * gx + gy * gy);
}


// Échantillonne au CENTRE du bloc, jamais à son coin : sinon l'image glisse
// d'un demi-bloc et le contour se décale d'autant.
vec2 accroche(vec2 uv, vec2 grille) {
	return (floor(uv * grille) + 0.5) / grille;
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
		vec2 pas = (1.0 / taille_ecran) * max(contour_epaisseur, 0.5);

		float proche = sobel(SCREEN_UV, pas);
		float large = sobel(SCREEN_UV, pas * 2.0);

		// Rapport des deux mesures : 1 sur une cassure, 2 sur une pente
		// régulière. On ne garde donc que ce qui est une vraie rupture, et
		// pénombres, fondus de lampes et dégradés ne tracent plus rien.
		//
		// Le rapport est sans dimension : le test vaut aussi bien sur un
		// contraste franc que sur une nuance ténue, ce qu'un seuil absolu sur
		// l'écart de luminance ne sait pas faire.
		float pente = large / max(proche, 0.0001);
		float cassure = clamp(2.0 - pente, 0.0, 1.0);
		float force = proche * cassure;

		float trace = smoothstep(contour_seuil, contour_seuil * 2.2, force);
		couleur = mix(couleur, contour_couleur.rgb, trace * contour_couleur.a);
	}

	if (grain_force > 0.0) {
		// Ancré sur les pixels d'écran, donc immobile quand la caméra bouge.
		float g = bruit_fixe(floor(SCREEN_UV * taille_ecran)) - 0.5;
		// MULTIPLICATIF, et non additif. Un écart absolu de 0.02 ne se voit pas
		// sur un sol clair mais double la valeur d'un plafond presque noir : le
		// grain ne salissait que les zones sombres, là précisément où il doit
		// se faire oublier. Proportionnel, il garde le même poids partout.
		couleur *= 1.0 + g * grain_force * 2.0;
	}

	ALBEDO = applique_filtre(couleur);
}
