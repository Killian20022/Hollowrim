// Particules de magie lumineuses (feu, givre, étincelles, lueurs) : mélange additif. Voir magie_part.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#define MAGIE_ADD
#include "res://shaders/magie_part.gdshaderinc"
