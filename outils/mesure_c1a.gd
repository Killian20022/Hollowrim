extends SceneTree
## [C1a] Perf du sol v2 généralisé à l'ouest/nord : avant (sol_carte + SolV2 coupés) / après. Dérivé de mesure_sol_v2.gd.
## Audit de non-régression perf : temps d'image (moyenne, PIRE image, nombre d'images > 33 ms) à des postes fixes et sur des marches
## scriptées, chargement du monde compris (construction des intérieurs différés). Fenêtre nécessaire, vsync coupé.
##   godot --path . --disable-vsync --script res://outils/mesure_images.gd -- --nouvelle --paisible [--chrono] [--seulement=a,b]
## Sortie : une ligne « IMG nom moy=.. pire=.. >33=.. gpu=.. » par poste. Mesures indicatives (charge machine).
const SEUIL := 33.0
const SETTLE := 1.5     # s : arrivée (le pire de cette fenêtre = saccade de 1re vue, shaders, visibilité)
const DUREE := 4.0      # s : mesure stabilisée

var monde: Node3D
var rid: RID
var t0 := 0
var dernier := 0
var etape := "chargement"
var sel: PackedStringArray = []
var file: Array = []    # [nom, Callable placer] ou [nom, depart, arrivee, vitesse, lacet, tangage]
var cur: Array = []
var t_etape := 0.0
var frames: Array = []  # ms
var gpus: Array = []
var settle_frames: Array = []
var marche_t := 0.0
var ready_t := 0.0

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			sel = a.substr(12).split(",")
	_demarrer.call_deferred()

func _demarrer() -> void:
	t0 = Time.get_ticks_usec()
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	dernier = Time.get_ticks_usec()
	print("IMG _ready monde: %.0f ms" % ((dernier - t0) / 1000.0))

func _ip(id: String, x: float, z: float, lacet: float, tang := -3.0) -> Callable:
	return func() -> void:
		var ip: Interieur = monde.village.interieur(id)
		_poser(ip.to_global(Vector3(x, ip.sol_y + 0.12, z)), ip.global_rotation.y + deg_to_rad(lacet), tang)

func _mond(x: float, z: float, lacet: float, tang: float) -> Callable:
	return func() -> void: _poser(Vector3(x, monde.hauteur(x, z) + 0.1, z), deg_to_rad(lacet), tang)

func _poser(p: Vector3, lacet: float, tang: float) -> void:
	monde.joueur.global_position = p
	monde.joueur.velocity = Vector3.ZERO
	monde.joueur.rotation.y = lacet
	monde.joueur.tete.rotation.x = deg_to_rad(tang)

func _mode(apres: bool) -> void:
	SolV2.regler(monde, apres)
	monde.mat_terrain.set_shader_parameter("sol_carte", apres)   # avant = rendu d'avant C1 hors zone témoin

## décomposition (--decompo) : 0 = avant, 1 = carte à tuiles seule, 2 = sol v2 sans rochers/touffes, 3 = après
func _mode_d(k: int) -> void:
	_mode(k >= 2)
	monde.mat_terrain.set_shader_parameter("sol_carte", k >= 1)
	if k == 2 and SolV2._decor != null:
		SolV2._decor.visible = false

func _pose_d(nom: String, k: int, x: float, z: float, lacet: float, tang: float) -> Array:
	return [nom, func() -> void:
		_mode_d(k)
		_poser(Vector3(x, monde.hauteur(x, z) + 0.1, z), deg_to_rad(lacet), tang)]

func _pose(nom: String, apres: bool, x: float, z: float, lacet: float, tang: float) -> Array:
	return [nom, func() -> void:
		_mode(apres)
		_poser(Vector3(x, monde.hauteur(x, z) + 0.1, z), deg_to_rad(lacet), tang)]

func _plan() -> void:
	file = [["demarrage", func() -> void: _mode(false)]]
	if "--decompo" in OS.get_cmdline_user_args():
		for r in 2:
			for p in [["O1", -82.0, 34.0, 270.0, -12.0], ["N2", -18.0, -74.0, 0.0, -12.0]]:
				for k in 4:
					file.append(_pose_d("%s_d%d_%d" % [p[0], k, r], k, p[1], p[2], p[3], p[4]))
		return
	for r in 2:   # deux passes alternées : le bruit de la machine partagée se voit
		for p in [["O1", -82.0, 34.0, 270.0, -12.0], ["N1", -46.0, -86.0, 270.0, -12.0], ["N2", -18.0, -74.0, 0.0, -12.0]]:
			file.append(_pose("%s_avant_%d" % [p[0], r], false, p[1], p[2], p[3], p[4]))
			file.append(_pose("%s_apres_%d" % [p[0], r], true, p[1], p[2], p[3], p[4]))
	file.append(["bascule_avant", func() -> void: _mode(false)])
	file.append(["marche_avant", Vector2(-80, 30), Vector2(-60, -20), 2.5, -22.0, -10.0])
	file.append(["bascule_apres", func() -> void: _mode(true)])
	file.append(["marche_apres", Vector2(-80, 30), Vector2(-60, -20), 2.5, -22.0, -10.0])
	if not sel.is_empty():
		file = file.filter(func(e: Array) -> bool: return e[0] in sel)

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - dernier) / 1000.0
	dernier = now
	if monde == null:
		return false
	if etape == "chargement":
		if monde.village != null and monde.village.prets:
			print("IMG chargement: %.0f ms jusqu'a interieurs prets (hors moteur)" % ((now - t0) / 1000.0))
			_plan()
			_suivant()
			return false
		if ms > SEUIL:
			print("IMG   image de chargement %.1f ms (t=%.0f ms)" % [ms, (now - t0) / 1000.0])
		return false
	if etape == "fin":
		return false
	t_etape += ms / 1000.0
	if ms > SEUIL and etape != "crypte_arene":
		var jp: Vector3 = monde.joueur.global_position
		print("IMG   pic %.1f ms [%s t=%.2f s] joueur=(%.1f, %.1f, %.1f) process=%.1f physique=%.1f gpu=%.1f cpu_rendu=%.1f" % [ms, etape, t_etape, jp.x, jp.y, jp.z,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(rid), RenderingServer.viewport_get_measured_render_time_cpu(rid)])
	if cur.size() == 2:
		if t_etape < 0.2:
			return false
		if t_etape < 0.2 + SETTLE:
			settle_frames.append(ms)
		else:
			frames.append(ms)
			gpus.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			if t_etape > 0.2 + SETTLE + DUREE:
				_rapport()
	else:
		var a: Vector2 = cur[1]
		var b: Vector2 = cur[2]
		marche_t += ms / 1000.0 * float(cur[3])
		var f := clampf(marche_t / a.distance_to(b), 0.0, 1.0)
		var p := a.lerp(b, f)
		if f >= 1.0 and t_etape > 0.5:
			_rapport()
			return false
		_poser(Vector3(p.x, monde.hauteur(p.x, p.y) + 0.1, p.y), deg_to_rad(float(cur[4])), float(cur[5]))
		frames.append(ms)
		gpus.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	return false

func _suivant() -> void:
	if file.is_empty():
		etape = "fin"
		print("IMG FIN")
		quit(0)
		return
	cur = file.pop_front()
	frames = []
	gpus = []
	settle_frames = []
	t_etape = 0.0
	marche_t = 0.0
	etape = cur[0]
	if cur.size() == 2:
		(cur[1] as Callable).call()
	else:
		var a: Vector2 = cur[1]
		_poser(Vector3(a.x, monde.hauteur(a.x, a.y) + 0.1, a.y), deg_to_rad(float(cur[4])), float(cur[5]))

func _stats(l: Array) -> Array:
	if l.is_empty():
		return [0.0, 0.0, 0]
	var s := 0.0
	var mx := 0.0
	var n := 0
	for x: float in l:
		s += x
		mx = maxf(mx, x)
		if x > SEUIL:
			n += 1
	return [s / l.size(), mx, n]

func _rapport() -> void:
	var st := _stats(frames)
	var se := _stats(settle_frames)
	var g := 0.0
	for x: float in gpus:
		g += x
	g = g / maxf(gpus.size(), 1)
	var nb_l := 0
	for l in monde.find_children("*", "OmniLight3D", true, false):
		if (l as OmniLight3D).is_visible_in_tree():
			nb_l += 1
	print("IMG %-22s moy=%6.2f pire=%7.1f >33=%d gpu=%5.2f ms n=%d | arrivee pire=%7.1f >33=%d lumieres=%d" % [cur[0], st[0], st[1], st[2], g, frames.size(), se[1], se[2], nb_l])
	_suivant()
