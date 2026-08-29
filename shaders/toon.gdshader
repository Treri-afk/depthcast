shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Éclairage cel : la lumière est quantifiée en quelques bandes au lieu d'un
// dégradé continu. C'est ce qui donne la lecture « dessinée » plutôt que
// photographique, et c'est le choix qui porte le plus l'identité low-poly.
//
// Un liseré lumineux détache les silhouettes du fond — indispensable dans un
// donjon sombre où tout est gris : sans lui, un monstre devant un mur disparaît.

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.85, 1.0);
uniform int bandes : hint_range(2, 6) = 3;
// Plus c'est haut, plus la zone d'ombre est franche.
uniform float durete : hint_range(0.0, 1.0) = 0.55;
uniform vec4 teinte_ombre : source_color = vec4(0.16, 0.17, 0.26, 1.0);

uniform vec4 couleur_lisere : source_color = vec4(0.55, 0.7, 1.0, 1.0);
uniform float force_lisere : hint_range(0.0, 2.0) = 0.55;
uniform float finesse_lisere : hint_range(0.5, 8.0) = 3.2;

uniform float emission_force : hint_range(0.0, 4.0) = 0.0;


void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * emission_force;

	// Liseré : d'autant plus vif que la surface fuit la caméra.
	float bord = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION += couleur_lisere.rgb * pow(bord, finesse_lisere) * force_lisere;
}


void light() {
	float intensite = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);

	// Quantification. Le mélange avec la valeur continue permet d'adoucir
	// l'effet sans perdre les bandes : à 1.0 c'est franchement cartoon.
	float paliers = float(bandes);
	float quantifie = floor(intensite * paliers) / max(paliers - 1.0, 1.0);
	float finale = mix(intensite, clamp(quantifie, 0.0, 1.0), durete);

	vec3 eclairee = LIGHT_COLOR * ATTENUATION * finale;
	vec3 ombre = teinte_ombre.rgb * (1.0 - finale);
	DIFFUSE_LIGHT += (eclairee + ombre) * ALBEDO;
}
