// Particules de magie sombres ou opaques (fumée, volutes des ténèbres, vapeur) : mélange alpha. Voir magie_part.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_part.gdshaderinc"
