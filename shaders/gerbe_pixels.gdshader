// Gerbe de pixels opaques (os, sang, échardes, poussière) : mélange alpha, paliers. Voir gerbe_pixels.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/gerbe_pixels.gdshaderinc"
