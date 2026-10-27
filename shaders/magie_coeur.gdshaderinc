// Cœurs pleins des projectiles (sphères lumineuses, boule de feu, orbe) : couleur unie (déjà multipliée par l'éclat),
// occlusion de la couche fine (magie_occ.gdshaderinc). Variantes : magie_coeur_add (lumière) / magie_coeur (opaque).
#include "res://shaders/magie_occ.gdshaderinc"
uniform vec4 couleur = vec4(1.0);   // linéaire (GestionMagie._mat_coeur)

void fragment() {
	if (magie_cachee(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX)) {
		discard;
	}
#ifdef MAGIE_ADD
	ALBEDO = couleur.rgb * couleur.a;
	ALPHA = 0.0;
#else
	ALBEDO = couleur.rgb;
#endif
}
