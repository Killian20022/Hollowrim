// Disques de magie (onde de choc, cercle de la tempête, givre au sol, vortex obscur, bouclier runique) : quad plat,
// UV pixellisés en `texels` cases (pixel art), anneau + remplissage + runes ou spirale, opacité en 3 paliers.
// Additif (ou alpha : magie_sol_mix), sans texture.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/magie_sol.gdshaderinc"
