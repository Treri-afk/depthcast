shader_type sky;

#include "res://shaders/bruit.gdshaderinc"
// Ciel de ligne claire : des nuages en aplats, pas en dégradés.
//
// Le bruit sert à dessiner une FORME, jamais une matière. On le seuille en
// deux valeurs — une face éclairée, une face à l'ombre — exactement comme le
// reste du décor. Un nuage en dégradé introduirait une troisième valeur et
// ferait mentir tout le travail fait sur `ligne_claire.gdshader`.
//
// Le contour de `pixel_fin.gdshader` passe ensuite dessus et souligne le bord
// des masses : c'est voulu, c'est comme ça qu'un nuage se dessine.

uniform vec3 couleur_ciel : source_color = vec3(0.11, 0.11, 0.17);
uniform vec3 couleur_nuage : source_color = vec3(0.30, 0.30, 0.42);
uniform vec3 couleur_nuage_ombre : source_color = vec3(0.19, 0.19, 0.28);

// Part du ciel couverte. 0 = dégagé, 1 = bouché.
uniform float couverture : hint_range(0.0, 1.0) = 0.52;
// Taille des masses. Petit = grands nuages.
uniform float echelle : hint_range(0.2, 6.0) = 1.6;
uniform float derive : hint_range(0.0, 0.05) = 0.006;
// Dureté du bord. Volontairement minuscule : c'est ce qui garde l'aplat.
uniform float bord : hint_range(0.001, 0.2) = 0.014;
// Écart entre la masse et son noyau éclairé — l'épaisseur de la face à l'ombre.
uniform float epaisseur_ombre : hint_range(0.02, 0.4) = 0.13;


void sky() {
	float haut = EYEDIR.y;
	vec3 couleur = couleur_ciel;

	if (haut > 0.001) {
		// Projection sur une COUPOLE, et non sur un plan.
		//
		// Le plan (`EYEDIR.xz / haut`) est le réflexe, et il est faux ici : le
		// diviseur tend vers zéro quand le regard s'approche de l'horizontale,
		// les coordonnées de bruit partent à l'infini, et l'horizon se couvre
		// de traînées horizontales. Le terme constant borne le dénominateur :
		// on garde l'écrasement vers l'horizon, sans jamais l'étirement.
		vec2 p = EYEDIR.xz * echelle / (0.30 + haut * 1.2);
		p += vent_nuage(TIME, derive);

		float n = masses_nuage(p);
		float seuil = 1.0 - couverture;

		// Deux seuils, deux valeurs. Rien entre les deux.
		float masse = smoothstep(seuil, seuil + bord, n);
		float noyau = smoothstep(seuil + epaisseur_ombre,
			seuil + epaisseur_ombre + bord, n);

		vec3 nuage = mix(couleur_nuage_ombre, couleur_nuage, noyau);
		couleur = mix(couleur_ciel, nuage, masse);

		// Effacement près de l'horizon. La coupole a supprimé les traînées,
		// mais la bande rasante reste celle que la brume reprend : y laisser
		// des nuages ferait deux brouillards concurrents.
		couleur = mix(couleur_ciel, couleur, smoothstep(0.0, 0.26, haut));
	}

	COLOR = couleur;
}
