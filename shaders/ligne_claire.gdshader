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
// Part maximale de la teinte éclairée que l'ombre a le droit d'atteindre.
// Voir `ombre_de()` : c'est ce qui empêche l'ombre d'être plus claire que
// la surface qu'elle assombrit.
uniform float plafond_ombre : hint_range(0.2, 1.0) = 0.82;
// Où bascule la frontière lumière/ombre. Bas = surfaces majoritairement claires.
uniform float seuil : hint_range(0.0, 1.0) = 0.32;
// Adoucit le bord sur un ou deux pixels, juste assez pour éviter l'escalier.
uniform float nettete : hint_range(0.001, 0.2) = 0.02;

uniform float emission_force : hint_range(0.0, 4.0) = 0.0;

// BRUME PAR BANDES.
//
// La brume de distance est le plus gros indice de rendu « réaliste » : un
// dégradé continu contredit frontalement la règle des aplats. Quantifiée en
// trois paliers, elle donne la profondeur — indispensable pour lire un couloir
// — tout en restant dans le langage du dessin.
//
// Les objets lointains fondent vers la couleur de fond. Le contour, tracé sur
// le contraste, s'efface donc de lui-même avec la distance : ce qui est loin
// est moins dessiné, exactement comme sur une planche.
uniform vec4 brume_couleur : source_color = vec4(0.11, 0.11, 0.17, 1.0);
uniform float brume_debut : hint_range(0.0, 60.0) = 14.0;
uniform float brume_fin : hint_range(1.0, 120.0) = 46.0;
uniform int brume_paliers : hint_range(1, 6) = 3;
uniform float brume_force : hint_range(0.0, 1.0) = 0.75;


// L'ombre d'une teinte donnée. UNE seule définition, appelée par fragment() et
// par light() : les deux doivent poser exactement la même valeur, sinon la
// soustraction faite dans light() laisse un liseré au bord de chaque lampe.
//
// Deux formulations, et on garde la plus sombre des deux.
//
// L'ABSOLUE est la règle de la ligne claire : une couleur d'ombre fixe,
// identique sur toute surface, à peine teintée par l'albédo.
//
// La RELATIVE est un garde-fou. La règle absolue suppose que les surfaces sont
// plus claires que l'ombre — vrai pour un sol à 0.66, faux pour un mur à 0.34.
// Sur ces décors sombres l'ombre devenait plus CLAIRE que la face éclairée :
// murs, piliers et mobilier se retrouvaient tous plaqués à la même valeur
// violette, sans contraste et sans teinte propre. C'était le délavé.
// La relative applique alors la couleur d'ombre en multiplicateur : la surface
// garde sa teinte, l'unité chromatique est préservée, et l'ombre reste plus
// sombre que la lumière — ce qui est la seule chose qu'une ombre doit faire.
vec3 ombre_de(vec3 teinte) {
	vec3 absolue = mix(couleur_ombre.rgb, couleur_ombre.rgb * teinte * 2.0,
		melange_ombre);
	vec3 relative = teinte * couleur_ombre.rgb * 2.0 * plafond_ombre;
	return min(absolue, relative);
}


void fragment() {
	vec3 teinte = albedo.rgb;

	if (brume_force > 0.0) {
		// VERTEX est en espace vue dans fragment() : sa longueur est la
		// distance à la caméra.
		float distance = length(VERTEX);
		float t = clamp((distance - brume_debut) / max(brume_fin - brume_debut, 0.001),
			0.0, 1.0);
		float paliers = float(brume_paliers);
		t = floor(t * paliers) / paliers;
		teinte = mix(teinte, brume_couleur.rgb, t * brume_force);
	}

	ALBEDO = teinte;

	// L'ombre est posée ici, en socle constant, et non dans light().
	//
	// Deux raisons. D'abord elle ne dépend d'aucune lumière : une surface non
	// éclairée garde exactement la teinte d'ombre au lieu de tomber au noir.
	// Ensuite light() est appelé UNE FOIS PAR LAMPE — poser l'ombre là-bas
	// l'empilerait autant de fois qu'il y a de lampes dans la salle.
	EMISSION = teinte * emission_force + ombre_de(teinte);
}


void light() {
	// L'ORIENTATION seule décide de la bascule. L'atténuation module ENSUITE
	// la quantité de lumière ajoutée, en fondu.
	//
	// L'inverse — atténuation incluse dans le seuil — donnait une frontière
	// parfaitement nette et circulaire autour de chaque lampe ponctuelle, que
	// la grille pixel transformait en escalier et que le contour soulignait.
	// C'était l'origine des marches sur les sols.
	//
	// Ne s'ajoute ici QUE l'écart entre la lumière et l'ombre. Le socle d'ombre
	// est déjà posé dans fragment() : le rajouter par lampe l'empilerait, et
	// une salle à cinq lampes aurait des ombres cinq fois trop claires.
	float incidence = dot(NORMAL, LIGHT);
	float eclaire = smoothstep(seuil - nettete, seuil + nettete, incidence);

	vec3 teinte_lumiere = ALBEDO * LIGHT_COLOR;

	DIFFUSE_LIGHT += max(teinte_lumiere - ombre_de(ALBEDO), vec3(0.0))
		* eclaire * ATTENUATION;
}
