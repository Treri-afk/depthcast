// Le bruit des nuages, partagé par le ciel et par leurs ombres au sol.
//
// Partagé et non recopié : si les deux divergeaient d'une constante, les ombres
// balaieraient le sol sans rapport avec ce qu'on voit en levant les yeux, et
// l'illusion tomberait aussitôt. C'est le genre de duplication qui ne casse
// jamais un test et ruine quand même l'effet.

// Hachage ENTIER, pas de trigonométrie.
//
// `fract(sin(dot(...)))` dégénère en rayures dès que les coordonnées
// grandissent : en simple précision le sinus n'a plus de mantisse à cette
// échelle et ses valeurs se corrèlent d'un point au suivant. Un ciel comme un
// sol de donjon sont faits de grandes coordonnées.
//
// Le biais évite de convertir un entier négatif en `uint` — le comportement
// diffère d'un pilote à l'autre, et une moitié du monde s'en trouverait rayée.
float hache_nuage(ivec2 q) {
	uvec2 u = uvec2(q + ivec2(65536));
	uint n = u.x * 1597334673u ^ u.y * 3812015801u;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 2147483647u) / float(2147483647u);
}


float bruit_nuage(vec2 p) {
	vec2 cellule = floor(p);
	vec2 f = p - cellule;
	// Lissage cubique : sans lui les cellules se voient en losanges.
	f = f * f * (3.0 - 2.0 * f);

	ivec2 q = ivec2(cellule);
	float a = hache_nuage(q);
	float b = hache_nuage(q + ivec2(1, 0));
	float c = hache_nuage(q + ivec2(0, 1));
	float d = hache_nuage(q + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


// Quatre octaves. Au-delà, le seuillage en aplats mange le détail ajouté : on
// paierait des tours de boucle pour une silhouette identique.
float masses_nuage(vec2 p) {
	float somme = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		somme += bruit_nuage(p) * amplitude;
		// 2.03 et pas 2.0 : à facteur exactement double, les octaves alignent
		// leurs cellules et laissent une grille visible dans les grandes masses.
		p *= 2.03;
		amplitude *= 0.5;
	}
	return somme;
}


// Le vent. Une seule direction pour tout le jeu : le ciel et le sol doivent
// dériver ensemble, sinon les ombres glissent sous des nuages immobiles.
vec2 vent_nuage(float temps, float derive) {
	return vec2(temps * derive, temps * derive * 0.6);
}
