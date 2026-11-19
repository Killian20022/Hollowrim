// Effet passif d'élément des lames : couches sombres ou pâles (fumée des ténèbres, vapeur froide) en mélange alpha.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/lame_element.gdshaderinc"
