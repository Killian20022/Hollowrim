// Cœur plein lumineux, additif (prémultiplié sans opacité, comme magie_part_add ; voir magie_coeur.gdshaderinc).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
#define MAGIE_ADD
#include "res://shaders/magie_coeur.gdshaderinc"
