shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Dissolution : le maillage se désagrège selon un bruit, avec un bord
// incandescent qui avance.
//
// Sert aux morts de monstres. Un ennemi qui disparaît d'un coup laisse un doute
// — l'a-t-on tué, ou est-il sorti du champ ? Une dissolution répond sans texte.
//
// Le bruit est procédural : pas de texture à charger, donc rien à gérer côté
// assets tant que la direction artistique n'est pas posée.

uniform vec4 albedo : source_color = vec4(0.75, 0.3, 0.35, 1.0);
uniform float progression : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur_bord : source_color = vec4(1.0, 0.65, 0.25, 1.0);
uniform float largeur_bord : hint_range(0.0, 0.3) = 0.08;
uniform float echelle_bruit : hint_range(1.0, 40.0) = 12.0;


float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}


// Bruit de valeur trilinéaire : suffisant pour une désagrégation, et bien
// moins coûteux qu'un Perlin complet.
float bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i);
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}


void fragment() {
	float n = bruit(VERTEX * echelle_bruit);

	if (n < progression) {
		discard;
	}

	ALBEDO = albedo.rgb;
	// Le bord incandescent suit le front de dissolution.
	float proximite = smoothstep(progression + largeur_bord, progression, n);
	EMISSION = couleur_bord.rgb * proximite * 3.0;
}
