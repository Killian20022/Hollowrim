extends SceneTree
## Audit chiffré des TROUS de la roche du repaire (retours exe 4, 2026-11-25), vu comme le joueur : à chaque point du sol de chaque
## branche (tous les PAS m) et sous N_YAW angles, un rendu 256x144 de la seule coque de roche (props masqués, portée de dessin levée),
## fond MAGENTA unlit sans brume : un pixel magenta = du vide visible à travers la roche ; matériau qui montre les FACES ARRIÈRE en
## JAUNE : un pixel jaune = on regarde l'envers d'une paroi (trou de rendu avec cull_back).
##   godot --path . --script res://outils/audit_trous_repaire.gd -- --sortie=C:/chemin [--pas=3] [--lat=0]
## Écrit <sortie>/audit_trous.csv (branche, s, yaw, pixels vide, pixels face arrière), <sortie>/pires_*.png et imprime le bilan.
const N_YAW := 8
const L := 256
const H := 144
const SHADER := "shader_type spatial; render_mode unshaded, cull_disabled;
void fragment(){ if (FRONT_FACING) { ALBEDO = vec3(0.45, 0.5, 0.55) * (0.55 + 0.45 * abs(dot(NORMAL, vec3(0.0, 0.0, 1.0)))); } else { ALBEDO = vec3(1.0, 1.0, 0.0); } }"

var g: Grotte
var sortie := ""
var pas := 3.0
var lat := 0.0

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--pas="):
			pas = float(a.substr(6))
		elif a.begins_with("--lat="):
			lat = float(a.substr(6))
	DirAccess.make_dir_recursive_absolute(sortie)
	var pere := Node3D.new()
	root.add_child(pere)
	g = Grotte.creer(pere, null, {})
	for i in 4:
		await physics_frame
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var nb_coque := 0
	var pile: Array = [g]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		pile.append_array(n.get_children())
		if n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			if String(n.name).begins_with("Coque") and n is MeshInstance3D:
				gi.material_override = mat
				gi.visibility_range_end = 0.0
				gi.visibility_range_begin = 0.0
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				nb_coque += 1
			elif not (n is Light3D):
				gi.visible = false
		if n is Light3D:
			(n as Light3D).visible = false
	print("coques de roche : ", nb_coque)
	var sv := SubViewport.new()
	sv.size = Vector2i(L, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 90.0
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	cam.make_current()
	var csv := "branche;s;yaw;vide;face_arriere\n"
	var tot_vide := 0
	var tot_arr := 0
	var vues := 0
	var vues_vide := 0
	var vues_arr := 0
	var pires: Array = []
	var par_br := {}
	for id: String in g.ordre:
		var Lb := g.longueur(id)
		var s := 1.0
		while s < Lb - 0.5:
			var dl := g.demi_l(id, s)
			var la := clampf(lat, -dl.x + 0.8, dl.y - 0.8)
			var p := g.to_global(g.sol_en(id, s, la)) + Vector3(0, 1.6, 0)
			for k in N_YAW:
				cam.global_position = p
				cam.global_rotation = Vector3(0, TAU * float(k) / float(N_YAW), 0)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := sv.get_texture().get_image()
				var vide := 0
				var arr := 0
				for y in range(0, H, 1):
					for x in range(0, L, 1):
						var c := img.get_pixel(x, y)
						if c.r > 0.9 and c.b > 0.9 and c.g < 0.25:
							vide += 1
						elif c.r > 0.9 and c.g > 0.9 and c.b < 0.3:
							arr += 1
				vues += 1
				if vide > 0:
					vues_vide += 1
				if arr > 0:
					vues_arr += 1
				tot_vide += vide
				tot_arr += arr
				var pb: Array = par_br.get(id, [0, 0, 0])
				pb[0] += vide
				pb[1] += arr
				pb[2] += 1
				par_br[id] = pb
				csv += "%s;%.1f;%d;%d;%d\n" % [id, s, k, vide, arr]
				if vide + arr > 0:
					pires.append([vide + arr, img, "%s_s%.0f_y%d" % [id, s, k]])
			s += pas
	var f := FileAccess.open(sortie + "/audit_trous.csv", FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	pires.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for i in mini(12, pires.size()):
		(pires[i][1] as Image).save_png("%s/pire_%02d_%s_%dpx.png" % [sortie, i, pires[i][2], pires[i][0]])
	print("BILAN vues %d (%d px chacune) : vide %d px (%d vues touchées, %.4f %% des pixels), faces arrière %d px (%d vues, %.4f %%)" % [vues, L * H, tot_vide, vues_vide, 100.0 * tot_vide / float(vues * L * H), tot_arr, vues_arr, 100.0 * tot_arr / float(vues * L * H)])
	for id in par_br:
		print("   %s : vide %d px, face arrière %d px sur %d vues" % [id, par_br[id][0], par_br[id][1], par_br[id][2]])
	quit(0)
