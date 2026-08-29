shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, depth_draw_opaque;

// Contour par coque inversée : on dilate le maillage le long de ses normales
// et on ne rend que les faces arrière. Le résultat est un trait d'encre autour
// de la silhouette, sans post-traitement plein écran.
//
// C'est ce qui rapproche le rendu 3D des références d'illustration encrée.
// L'épaisseur est compensée par la distance : sans ça, un trait correct de près
// devient un pâté de loin.

uniform vec4 couleur : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float epaisseur : hint_range(0.0, 0.2) = 0.025;
uniform bool epaisseur_constante = true;


void vertex() {
	float echelle = epaisseur;
	if (epaisseur_constante) {
		// Distance à la caméra, en espace vue.
		float distance = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
		echelle = epaisseur * clamp(distance * 0.12, 0.35, 3.0);
	}
	VERTEX += normalize(NORMAL) * echelle;
}


void fragment() {
	ALBEDO = couleur.rgb;
}
