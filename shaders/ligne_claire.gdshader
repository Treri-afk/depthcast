shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled, diffuse_lambert;

// LIGNE CLAIRE — deux valeurs par surface, jamais trois.
//
// Pas de dégradé, pas de spéculaire, pas de lumière ambiante : une face est
// éclairée ou elle est dans l'ombre. C'est cette absence de demi-teinte qui
// fait basculer la lecture du photographique vers le dessiné.
//
// L'ombre a TOUJOURS la même couleur, quelle que soit celle de l'objet. Ce
// n'est jamais l'albédo assombri. Une pierre grise, une caisse brune et un chat
// blanc partagent exactement la même ombre — c'est la règle qui unifie l'image.
//
// `melange_ombre` laisse passer un soupçon d'albédo. À zéro la règle est pure,
// mais deux objets voisins deviennent indiscernables dans un donjon sombre.

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.85, 1.0);
uniform vec4 couleur_ombre : source_color = vec4(0.20, 0.19, 0.34, 1.0);
uniform float melange_ombre : hint_range(0.0, 0.5) = 0.18;
// Où bascule la frontière lumière/ombre. Bas = surfaces majoritairement claires.
uniform float seuil : hint_range(0.0, 1.0) = 0.32;
// Adoucit le bord sur un ou deux pixels, juste assez pour éviter l'escalier.
uniform float nettete : hint_range(0.001, 0.2) = 0.02;

uniform float emission_force : hint_range(0.0, 4.0) = 0.0;


void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * emission_force;
}


void light() {
	float incidence = dot(NORMAL, LIGHT) * ATTENUATION;

	// Une seule bascule. Pas de bandes intermédiaires : à deux valeurs, une
	// troisième nuance suffirait à casser la lecture d'aplat.
	float eclaire = smoothstep(seuil - nettete, seuil + nettete, incidence);

	vec3 teinte_ombre = mix(couleur_ombre.rgb, couleur_ombre.rgb * ALBEDO * 2.0,
		melange_ombre);
	vec3 teinte_lumiere = ALBEDO * LIGHT_COLOR;

	DIFFUSE_LIGHT += mix(teinte_ombre, teinte_lumiere, eclaire);
}
