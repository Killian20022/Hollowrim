extends SceneTree
## Audit chiffré des VIDES de la crypte du tertre (retours du soir 2026-11-25 : « toujours des espaces de vide dans la crypte »), vu
## comme le joueur, EN MODE JEU (scène complète, salle active, portée de dessin, brume, matériaux du jeu avec leur culling et l'accroche
## des sommets PS1). Dans chaque salle (SalleActive : modules du donjon + vestibule, alcôve, couloir de la herse), aux points du sol
## libres pour le joueur (grille de PAS m, escaliers compris), la caméra (œil à 1,62 m, champ 72°, 640x360 = rendu interne) tourne à
## 360° (N_YAW lacets x 3 tangages : sol, paroi, voûte). Deux rendus par vue, dans une SubViewport qui partage le monde du jeu :
##  J (jeu)    : tout comme en jeu (salle active, portée de dessin, culling, accroche PS1), mais le FOND est MAGENTA et la brume coupée
##               (elle noie aussi le fond) : un pixel magenta = rien n'est dessiné ; le dehors est caché (vu par un trou, il ne compte pas) ;
##  P (profondeur) : TOUTE la géométrie de la crypte visible, sans portée, matériau de diagnostic : distance de la 1re surface,
##               face avant ou face ARRIÈRE (l'envers d'une paroi à culling : en jeu on voit au travers).
## Classement d'un pixel :
##  - VIDE        : magenta en J et, en P, rien ou une surface à moins de PORTEE_VUE m (la brume n'est pas encore pleine : le joueur
##                  voit un trou noir-bleu là où il devrait voir de la pierre) ; au-delà, la coupure est noyée dans la brume (normal) ;
##  - TRAVERSANT  : en P, la surface la plus proche est une face ARRIÈRE à culling, à moins de PORTEE_VUE m (paroi vue de dos).
##   godot --path . --script res://outils/audit_trous_crypte.gd -- --nouvelle --paisible --crypte=0,0.5,0,0 --sortie=C:/chemin
##         [--pas=4] [--yaw=8] [--salle=id,id] [--planche] [--grotte-non]
## --planche : en plus, 4 vues joueur RÉELLES (fenêtre du jeu, post-traitement compris) par salle au point le plus central :
##             <sortie>/vues/<salle>_<lacet>.png (planche avant/après).
## Écrit <sortie>/audit_trous_crypte.csv, <sortie>/bilan.txt, <sortie>/pires/*.png et imprime « BILAN ».
const L := 640
const H := 360
const PORTEE_VUE := 24.0          # brume pleine à 31 m (BrumePortee.FIN) ; à 24 m elle laisse encore ~25 % de la pierre
const TANGAGES := [-28.0, 0.0, 32.0]
const OEIL := 1.62
const SHADER_P := "shader_type spatial; render_mode unshaded, %s, fog_disabled, depth_draw_opaque;
void fragment(){ float d = clamp(length(VERTEX) / 64.0, 0.0, 1.0); if (FRONT_FACING) { ALBEDO = vec3(d, 0.5, 0.25); } else { ALBEDO = vec3(d, %s, 0.0); } }"

var s: Node3D
var t: Node3D
var j: Node3D
var sortie := ""
var pas := 4.0
var n_yaw := 8
var filtre: Array = []
var sv: SubViewport
var cam: Camera3D
var mat_p_cull: ShaderMaterial
var mat_p_double: ShaderMaterial
var _sauve := {}      # GeometryInstance3D -> [override, visible, range_begin, range_end]

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	sortie = _arg("sortie", "")
	pas = float(_arg("pas", "4"))
	n_yaw = int(_arg("yaw", "8"))
	if _arg("salle") != "":
		filtre = Array(_arg("salle").split(","))
	DirAccess.make_dir_recursive_absolute(sortie + "/pires")
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	var n := 0
	while n < 60 * 90 and not (s.tertre != null and s.tertre.dedans):
		await process_frame
		n += 1
	t = s.tertre
	t.attendre_donjon()
	for i in 90:
		await process_frame
	if not t.crypte.visible:
		print("AVERTISSEMENT : crypte cachée alors que le joueur est dedans (préchauffage ?) : remontrée")
		t.crypte.visible = true
	# dehors caché : par un trou, le joueur verrait le dessous du terrain noyé dans la brume (= le vide) ; caché, le trou reste magenta
	for c in s.get_children():
		if c is Node3D and c != t.crypte and c != j and (c as Node3D).visible:
			(c as Node3D).visible = false
	# toutes les portes ouvertes (on voit d'une salle à l'autre comme en fin de partie), mur secret pivoté, herse levée
	s._ouvrir_donjon("s1,s2,s3,secret,herse")
	if t.donjon.portes.has("secret"):
		(t.donjon.portes["secret"] as Node3D).rotation.y = -PI * 0.5
	for k in get_nodes_in_group("cassables"):
		if not (k is Cassable) and k.has_method("casser"):
			k.casser(false)
	j.set_physics_process(false)
	j.set_process(false)
	j.visible = false
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.set_process(false)
		cip.set("visible", false)
	var hud = s.get("hud")
	if hud != null and hud is CanvasItem:
		(hud as CanvasItem).visible = false
	for i in 30:
		await process_frame
	sv = SubViewport.new()
	sv.size = Vector2i(L, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.positional_shadow_atlas_size = 0
	root.add_child(sv)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	cam.make_current()
	mat_p_cull = _mat_p("cull_disabled", "1.0")
	mat_p_double = _mat_p("cull_disabled", "0.5")
	# points de chaque salle
	var points := _points()
	var nb := 0
	for id in points:
		nb += (points[id] as Array).size()
	print("salles : %d, points : %d, vues : %d" % [points.size(), nb, nb * n_yaw * TANGAGES.size()])
	if _arg("planche") != "":
		await _planche(points)
		if _arg("planche") == "seule":
			quit(0)
			return
	# --- témoin : la crypte cachée, la vue doit être entièrement magenta (sinon la détection est aveugle)
	if true:
		var p0: Vector3 = (points.values()[0] as Array)[0]
		j.global_position = p0
		cam.environment = _env_j()
		_viser(p0, 0)
		t.crypte.visible = false
		for k in 3:
			await RenderingServer.frame_post_draw
		var ic := sv.get_texture().get_image()
		ic.convert(Image.FORMAT_RGB8)
		print("TEMOIN crypte cachée : %d px magenta sur %d, pixel central %s" % [_magenta(ic).size(), L * H, ic.get_pixel(L / 2, H / 2)])
		var variantes := {}
		var e1 := Environment.new()
		e1.background_mode = Environment.BG_COLOR
		e1.background_color = Color(1, 0, 1)
		variantes["neuf"] = e1
		var e2 := _env_j()
		e2.fog_enabled = false
		variantes["jeu_sans_brume"] = e2
		var e3 := _env_j()
		e3.volumetric_fog_enabled = false
		e3.ssao_enabled = false
		e3.ssil_enabled = false
		e3.sdfgi_enabled = false
		variantes["jeu_sans_effets"] = e3
		for nm in variantes:
			cam.environment = variantes[nm]
			for k in 3:
				await RenderingServer.frame_post_draw
			var iv := sv.get_texture().get_image()
			iv.convert(Image.FORMAT_RGB8)
			print("TEMOIN %s : %d px magenta, centre %s, objets %d" % [nm, _magenta(iv).size(), iv.get_pixel(L / 2, H / 2), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
		var tous_caches: Array = []
		for c in root.get_children():
			if c is Node3D and (c as Node3D).visible:
				tous_caches.append(c)
				(c as Node3D).visible = false
		cam.environment = e1
		for k in 3:
			await RenderingServer.frame_post_draw
		var iw := sv.get_texture().get_image()
		iw.convert(Image.FORMAT_RGB8)
		print("TEMOIN racine cachée : %d px magenta, centre %s, autres enfants de la racine %s" % [_magenta(iw).size(), iw.get_pixel(L / 2, H / 2), root.get_children()])
		for c in tous_caches:
			(c as Node3D).visible = true
		print("TEMOIN env du jeu : fond %s mode %d brume %s mode %d" % [s._env.background_color, s._env.background_mode, s._env.fog_enabled, s._env.fog_mode])
		cam.environment = _env_j()
		ic.save_png(sortie + "/temoin_crypte_cachee.png")
		t.crypte.visible = true
		for k in 3:
			await RenderingServer.frame_post_draw
		ic = sv.get_texture().get_image()
		ic.convert(Image.FORMAT_RGB8)
		print("TEMOIN crypte visible : %d px magenta" % _magenta(ic).size())
		ic.save_png(sortie + "/temoin_crypte_visible.png")
		if _arg("temoin-seul") != "":
			quit(0)
			return
	# --- passe J (jeu) : point par point, salle active du joueur ; on garde les pixels magenta des vues touchées
	var nb_img := 0
	var seuil_img := 0
	var vues: Array = []      # [salle, point (monde), k, PackedInt32Array pixels magenta, Image J]
	var t0 := Time.get_ticks_msec()
	for id: String in points:
		for p: Vector3 in points[id]:
			j.global_position = p
			for k in 3:
				t._gerer_zones()
			if t.salles != null:
				t.salles.rafraichir(true)
			cam.environment = _env_j()
			for kk in n_yaw * TANGAGES.size():
				_viser(p, kk)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := sv.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				var mg := _magenta(img)
				var garde := mg.size() > 0 and (nb_img < 120 or mg.size() > seuil_img)
				vues.append([id, p, kk, mg, img if garde else null])
				if garde:
					nb_img += 1
					if nb_img > 120:      # mémoire : on ne garde que les ~120 pires images J
						var mini_ := -1
						for vi in vues.size() - 1:
							if vues[vi][4] != null and (mini_ < 0 or (vues[vi][3] as PackedInt32Array).size() < (vues[mini_][3] as PackedInt32Array).size()):
								mini_ = vi
						if mini_ >= 0:
							seuil_img = maxi(seuil_img, (vues[mini_][3] as PackedInt32Array).size())
							vues[mini_][4] = null
							nb_img -= 1
	print("passe J : %d vues en %d s" % [vues.size(), (Time.get_ticks_msec() - t0) / 1000])
	# --- passe P (profondeur) : toute la crypte visible, matériau de diagnostic, sans portée ni salle active
	t.process_mode = Node.PROCESS_MODE_DISABLED
	_mode_p(true)
	var env_p := Environment.new()
	env_p.background_mode = Environment.BG_COLOR
	env_p.background_color = Color(1, 0, 1)
	env_p.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_p.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	cam.environment = env_p
	var par_salle := {}
	var csv := "salle;x;y;z;vue;vide_px;traversant_px;magenta_loin_px\n"
	var pires: Array = []
	var t1 := Time.get_ticks_msec()
	for v: Array in vues:
		var p: Vector3 = v[1]
		j.global_position = p
		_viser(p, v[2])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ip := sv.get_texture().get_image()
		ip.convert(Image.FORMAT_RGB8)
		var dp := ip.get_data()
		var vide := 0
		var loin := 0
		var trav := 0
		var masque := PackedByteArray()
		masque.resize(L * H)
		for idx: int in (v[3] as PackedInt32Array):
			var o := idx * 3
			var r := dp[o] / 255.0
			var g := dp[o + 1] / 255.0
			var b := dp[o + 2] / 255.0
			if r > 0.9 and b > 0.9 and g < 0.2:
				vide += 1          # rien du tout derrière : trou franc
				masque[idx] = 1
			else:
				var dist := Color(r, 0, 0).srgb_to_linear().r * 64.0
				if dist < PORTEE_VUE:
					vide += 1
					masque[idx] = 1
				else:
					loin += 1
		# faces arrière les plus proches (vert ~1 = arrière à culling)
		for idx in L * H:
			var o := idx * 3
			if dp[o + 1] > 240 and dp[o + 2] < 20:
				var dist := Color(dp[o] / 255.0, 0, 0).srgb_to_linear().r * 64.0
				if dist < PORTEE_VUE and masque[idx] == 0:
					trav += 1
					masque[idx] = 2
		var ps: Array = par_salle.get(v[0], [0, 0, 0, 0, 0])
		ps[0] += vide
		ps[1] += trav
		ps[2] += 1
		ps[3] += 1 if vide > 0 else 0
		ps[4] += 1 if trav > 0 else 0
		par_salle[v[0]] = ps
		var lp: Vector3 = t.crypte.to_local(p)
		csv += "%s;%.1f;%.1f;%.1f;%d;%d;%d;%d\n" % [v[0], lp.x, lp.y, lp.z, v[2], vide, trav, loin]
		if vide > 0 or (vide + trav > 0 and _arg("traversant") != ""):
			pires.append([vide * 10 + trav if _arg("traversant") == "" else vide + trav, v, ip, masque])
	print("passe P : %d vues en %d s" % [vues.size(), (Time.get_ticks_msec() - t1) / 1000])
	_mode_p(false)
	var f := FileAccess.open(sortie + "/audit_trous_crypte.csv", FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	pires.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	# 2 pires vues PAR SALLE d'abord (une salle très touchée ne cache pas les autres), puis les suivantes
	var par_s := {}
	var tri: Array = []
	var reste: Array = []
	for pv: Array in pires:
		var sid: String = (pv[1] as Array)[0]
		if int(par_s.get(sid, 0)) < 2:
			par_s[sid] = int(par_s.get(sid, 0)) + 1
			tri.append(pv)
		else:
			reste.append(pv)
	pires = tri + reste
	# pires vues : rendues de nouveau EN JEU (salle active, lumières), à gauche telles quelles, à droite défauts en couleur
	t.process_mode = Node.PROCESS_MODE_INHERIT
	for i in mini(int(_arg("nb_pires", "60")), pires.size()):
		var v: Array = pires[i][1]
		var p: Vector3 = v[1]
		j.global_position = p
		for k in 3:
			t._gerer_zones()
		t.salles.rafraichir(true)
		cam.environment = _env_j()
		_viser(p, v[2])
		for k in 3:
			await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var marque := img.duplicate()
		var mq: PackedByteArray = pires[i][3]
		for idx in L * H:     # vide en magenta plein, traversant en jaune
			if mq[idx] == 1:
				marque.set_pixel(idx % L, idx / L, Color(1, 0, 1))
			elif mq[idx] == 2:
				marque.set_pixel(idx % L, idx / L, Color(1, 1, 0))
		var duo := Image.create(L * 2 + 4, H, false, Image.FORMAT_RGB8)
		duo.fill(Color(0.1, 0.1, 0.1))
		duo.blit_rect(img, Rect2i(0, 0, L, H), Vector2i(0, 0))
		duo.blit_rect(marque, Rect2i(0, 0, L, H), Vector2i(L + 4, 0))
		var lp: Vector3 = t.crypte.to_local(p)
		duo.save_png("%s/pires/%02d_%s_%.0f_%.0f_v%d_%dpx.png" % [sortie, i, v[0], lp.x, lp.z, v[2], pires[i][0]])
	var tot_v := 0
	var tot_t := 0
	var nv := 0
	var bilan := "BILAN crypte : %d vues (%d px chacune)\n" % [vues.size(), L * H]
	var ids := par_salle.keys()
	ids.sort()
	for id in ids:
		var ps: Array = par_salle[id]
		tot_v += ps[0]
		tot_t += ps[1]
		nv += ps[2]
		bilan += "   %-22s vues %4d | vide %7d px (%3d vues) | traversant %7d px (%3d vues)\n" % [id, ps[2], ps[0], ps[3], ps[1], ps[4]]
	bilan = bilan.replace("BILAN crypte : %d vues" % vues.size(), "BILAN crypte : %d vues, vide %d px, traversant %d px" % [vues.size(), tot_v, tot_t])
	print(bilan)
	var fb := FileAccess.open(sortie + "/bilan.txt", FileAccess.WRITE)
	fb.store_string(bilan)
	fb.close()
	quit(0)

func _mat_p(cull: String, vert_arriere: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER_P % [cull, vert_arriere]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

## Environnement de la passe J : celui du jeu (brume, ambiance de la salle), fond magenta que la brume ne teinte pas.
func _env_j() -> Environment:
	var e: Environment = (s._env as Environment).duplicate()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(1, 0, 1)
	e.fog_sky_affect = 0.0
	e.fog_enabled = false      # témoin : la brume en profondeur noie aussi le FOND (rendu noir) ; la distance est jugée par la passe P
	e.glow_enabled = false
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR      # le fond reste magenta pur (le tonemap du jeu l'assombrissait : 0 détection)
	e.tonemap_exposure = 1.0
	e.adjustment_enabled = false
	e.background_energy_multiplier = 1.0
	return e

func _viser(p: Vector3, kk: int) -> void:
	var k: int = kk % n_yaw
	cam.global_position = p + Vector3(0, OEIL, 0)
	cam.global_rotation = Vector3(deg_to_rad(float(TANGAGES[kk / n_yaw])), t.crypte.global_rotation.y + TAU * float(k) / float(n_yaw), 0)

func _magenta(img: Image) -> PackedInt32Array:
	var d := img.get_data()
	var res := PackedInt32Array()
	for idx in L * H:
		var o := idx * 3
		if d[o] > 225 and d[o + 2] > 225 and d[o + 1] < 60:
			res.append(idx)
	return res

## Matériau de diagnostic sur toute la géométrie de la crypte (et du donjon), tout visible, sans portée de dessin ; cartes
## transparentes / additives, flammes et particules cachées. `actif` false : tout est rendu tel quel.
func _mode_p(actif: bool) -> void:
	if not actif:
		for gi: GeometryInstance3D in _sauve:
			if is_instance_valid(gi):
				var sv_: Array = _sauve[gi]
				gi.material_override = sv_[0]
				gi.visible = sv_[1]
				gi.visibility_range_begin = sv_[2]
				gi.visibility_range_end = sv_[3]
		_sauve.clear()
		return
	var pile: Array = [t.crypte]
	while not pile.is_empty():
		var nd: Node = pile.pop_back()
		pile.append_array(nd.get_children())
		if nd is Node3D and not (nd as Node3D).visible and not (nd is GeometryInstance3D):
			(nd as Node3D).visible = true      # nœuds intermédiaires cachés par SalleActive
		if not (nd is GeometryInstance3D):
			continue
		var gi := nd as GeometryInstance3D
		_sauve[gi] = [gi.material_override, gi.visible, gi.visibility_range_begin, gi.visibility_range_end]
		gi.visibility_range_begin = 0.0
		gi.visibility_range_end = 0.0
		var genre := _genre(gi)
		if genre == "transparent":
			gi.visible = false
			continue
		gi.visible = true
		# « traversant » : seulement la MAÇONNERIE (murs, sols, voûtes, modules de pierre) ; personnages, accessoires, givre, glaçons et
		# cartes à une face vus de dos ne sont pas des trous du décor (ils masquent quand même : matériau sans culling)
		gi.material_override = mat_p_cull if (genre == "cull" and _structure(gi)) else mat_p_double

const STRUCTURE := ["mur0", "mur1", "mur2", "mur3", "dalle0", "dalle1", "dalle2", "dalle3", "voute", "pierre_v2", "pierre_sol", "dalle_v2",
	"ossuaire", "gravure", "entrelacs", "noir", "statue_v2"]

func _structure(gi: GeometryInstance3D) -> bool:
	if not String(gi.name).begins_with("Decor_"):
		return false
	var parts := String(gi.name).split("_")
	for k in range(4, parts.size()):
		var nom := "_".join(parts.slice(k))
		if nom in STRUCTURE:
			return true
	return false

## "transparent" (cartes additives, alpha, flammes, particules), "double" (sans culling) ou "cull".
func _genre(gi: GeometryInstance3D) -> String:
	if gi is GPUParticles3D or gi is CPUParticles3D or String(gi.name).begins_with("Flammes"):
		return "transparent"
	var m: Material = gi.material_override
	if m == null and gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null and (gi as MeshInstance3D).mesh.get_surface_count() > 0:
		m = (gi as MeshInstance3D).get_active_material(0)
	if m == null and gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null and mm.mesh.get_surface_count() > 0:
			m = mm.mesh.surface_get_material(0)
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
			return "transparent"
		return "double" if b.cull_mode == BaseMaterial3D.CULL_DISABLED else "cull"
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var code := (m as ShaderMaterial).shader.code
		var rm := ""
		var i := code.find("render_mode")
		if i >= 0:
			rm = code.substr(i, code.find(";", i) - i)
		if rm.contains("blend_add") or rm.contains("blend_mul") or rm.contains("blend_sub") or code.contains("ALPHA =") or code.contains("ALPHA=") and not code.contains("ALPHA_SCISSOR"):
			return "transparent"
		return "double" if rm.contains("cull_disabled") else "cull"
	return "cull"

## Points du sol libres (capsule du joueur) de chaque salle, grille de `pas` m décalée de la moitié ; escaliers : plusieurs étages de départ.
func _points() -> Dictionary:
	var res := {}
	var ss: PhysicsDirectSpaceState3D = s.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	var c: Node3D = t.crypte
	var exclus: Array[RID] = []
	for nd in s.find_children("*", "CharacterBody3D", true, false):
		exclus.append((nd as CharacterBody3D).get_rid())
	for id: String in t.salles.salles:
		if not filtre.is_empty() and not filtre.has(id):
			continue
		var sa: Dictionary = t.salles.salles[id]
		var r: Rect2 = sa["rect"]
		if r.size == Vector2.ZERO:
			continue
		var y0: float = sa["y0"]
		var y1: float = sa["y1"]
		var liste: Array = []
		var nx := maxi(1, int(round(r.size.x / pas)))
		var nz := maxi(1, int(round(r.size.y / pas)))
		for ix in nx:
			for iz in nz:
				var x := r.position.x + r.size.x * (ix + 0.5) / nx
				var z := r.position.y + r.size.y * (iz + 0.5) / nz
				var y := y1 - 0.3
				while y > y0 - 0.5:
					var a := c.to_global(Vector3(x, y, z))
					var q := PhysicsRayQueryParameters3D.create(a, c.to_global(Vector3(x, y0 - 0.6, z)))
					q.exclude = exclus
					q.collision_mask = 1
					var rr := ss.intersect_ray(q)
					if rr.is_empty():
						break
					var ps: Vector3 = rr["position"]
					var qp := PhysicsShapeQueryParameters3D.new()
					qp.shape = cap
					qp.transform = Transform3D(Basis(), ps + Vector3(0, 0.13 + 0.85, 0))
					qp.exclude = exclus
					qp.collision_mask = 1
					if ss.intersect_shape(qp, 1).is_empty() and (rr["normal"] as Vector3).y > 0.6:
						var deja := false
						for o: Vector3 in liste:
							if o.distance_to(ps) < 1.0:
								deja = true
						if not deja:
							liste.append(ps)
					y = c.to_local(ps).y - 2.0
		if not liste.is_empty():
			res[id] = liste
	return res

## Vues joueur réelles (fenêtre du jeu, post-traitement) : 4 lacets au point le plus proche du centre de chaque salle.
func _planche(points: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(sortie + "/vues")
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var jc: Camera3D = j.camera
	jc.make_current()
	j.visible = true      # mains et torche du joueur : la vue réelle (la torche éclaire la salle)
	for id: String in points:
		var sa: Dictionary = t.salles.salles[id]
		var ctr: Vector2 = (sa["rect"] as Rect2).get_center()
		var best: Vector3 = points[id][0]
		for p: Vector3 in points[id]:
			var lp: Vector3 = t.crypte.to_local(p)
			var lb: Vector3 = t.crypte.to_local(best)
			if Vector2(lp.x, lp.z).distance_to(ctr) < Vector2(lb.x, lb.z).distance_to(ctr):
				best = p
		j.global_position = best + Vector3(0, 0.1, 0)
		for k in 3:
			t._gerer_zones()
		t.salles.rafraichir(true)
		for a in 4:
			j.rotation.y = t.crypte.global_rotation.y + TAU * a / 4.0
			j.tete.rotation.x = deg_to_rad(-4.0)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/vues/%s_%d.png" % [sortie, id, a * 90])
	j.visible = false
	cam.make_current()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	print("planche : %d salles" % points.size())
