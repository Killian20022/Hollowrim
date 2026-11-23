extends SceneTree
## Charge chaque shaders/*.gdshader (le compilateur du moteur tourne même sans fenêtre) : cherchez « SHADER ERROR » dans la sortie.
func _init() -> void:
	var n := 0
	for f in DirAccess.get_files_at("res://shaders"):
		if f.ends_with(".gdshader"):
			var s := load("res://shaders/" + f) as Shader
			var m := ShaderMaterial.new()
			m.shader = s
			RenderingServer.material_get_param(m.get_rid(), "x")
			n += 1
	print("verif_compile_shaders : %d shaders chargés" % n)
	quit()
