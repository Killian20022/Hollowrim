// Gerbe de pixels lumineux (étincelles) : additif, traînée filante. Voir gerbe_pixels.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/gerbe_pixels.gdshaderinc"
