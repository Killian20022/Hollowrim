class_name ProfondeurMagie
extends CompositorEffect
## Copie de la profondeur du MONDE (rendu 640x360 de la caméra du joueur) dans une texture R32F partagée
## (Texture2DRD `texture`), après la passe opaque. La couche fine de la magie (CoucheMagie : SubViewport à la résolution
## de l'écran, sans décor) la lit dans shaders/magie_occ.gdshaderinc pour cacher ce qui passe derrière les murs, les
## ennemis et les mains. La copie de l'image N sert à l'image N+1 (le SubViewport est dessiné AVANT la fenêtre) : le
## shader reprojette avec `vue` (repère de la caméra au moment de la copie), le décor fixe reste donc exact.
## Renderers RenderingDevice seulement (Mobile, Forward+) ; en Compatibility, CoucheMagie reste en mode rétro.

const GLSL := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D prof;
layout(r32f, set = 0, binding = 1) uniform restrict writeonly image2D sortie;
layout(push_constant, std430) uniform Params { vec2 taille; vec2 vide; } p;
void main() {
	ivec2 c = ivec2(gl_GlobalInvocationID.xy);
	if (c.x >= int(p.taille.x) || c.y >= int(p.taille.y)) {
		return;
	}
	imageStore(sortie, c, vec4(texelFetch(prof, c, 0).r));
}
"""

var texture := Texture2DRD.new()
## Repère (monde) de la caméra lors de la dernière copie, et nombre de copies (tests).
var vue := Transform3D.IDENTITY
var copies := 0
var taille := Vector2i.ZERO
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _sampler := RID()
var _tex := RID()
var _fini := false

func _init() -> void:
	# après la passe transparente : le rendu Mobile n'appelle pas POST_OPAQUE (essayé) ; l'eau et les vitres du monde
	# n'écrivent pas la profondeur, ce qui revient au même
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_preparer)

func _preparer() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = GLSL
	var spirv := _rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("ProfondeurMagie : " + spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = _rd.sampler_create(ss)

func pret() -> bool:
	return _pipeline.is_valid()

func _render_callback(_type: int, donnees: RenderData) -> void:
	if not _pipeline.is_valid() or _fini:
		return
	var sb := donnees.get_render_scene_buffers() as RenderSceneBuffersRD
	if sb == null:
		return
	var t := sb.get_internal_size()
	if t.x <= 0 or t.y <= 0:
		return
	if t != taille or not _tex.is_valid():
		if _tex.is_valid():
			_rd.free_rid(_tex)
		var f := RDTextureFormat.new()
		f.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
		f.width = t.x
		f.height = t.y
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		_tex = _rd.texture_create(f, RDTextureView.new())
		texture.texture_rd_rid = _tex
		taille = t
	var prof := sb.get_depth_layer(0)
	if not prof.is_valid():
		return
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u0.binding = 0
	u0.add_id(_sampler)
	u0.add_id(prof)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(_tex)
	var us := UniformSetCacheRD.get_cache(_shader, 0, [u0, u1])
	var pc := PackedFloat32Array([float(t.x), float(t.y), 0.0, 0.0]).to_byte_array()
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _pipeline)
	_rd.compute_list_bind_uniform_set(cl, us, 0)
	_rd.compute_list_set_push_constant(cl, pc, pc.size())
	_rd.compute_list_dispatch(cl, (t.x + 7) / 8, (t.y + 7) / 8, 1)
	_rd.compute_list_end()
	vue = donnees.get_render_scene_data().get_cam_transform()
	copies += 1

## Plus de copie (la couche s'éteint) ; les RID sont libérées avec l'objet.
func finir() -> void:
	_fini = true
	enabled = false

func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_PREDELETE and _rd != null:
		for r in [_tex, _pipeline, _shader, _sampler]:
			if r.is_valid():
				_rd.free_rid(r)
