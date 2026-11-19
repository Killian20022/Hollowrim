// Effet passif d'élément des lames : couches lumineuses (braises, givre, étincelles) en additif. Voir lame_element.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#define LAME_ADD
#include "res://shaders/lame_element.gdshaderinc"
