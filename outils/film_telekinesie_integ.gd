extends SceneTree
## FILM INTÉGRÉ (télékinésie + impacts + cassables partout), vue FPS, pilote automatique, dans la VRAIE crypte :
##   1. un tonneau de la crypte saisi et lancé sur un draugr : il se brise sur lui ;
##   2. une urne de la crypte saisie et lancée contre un mur : elle se brise ;
##   3. une épée ramassée par télékinésie qui transperce un draugr et le CLOUE au mur derrière lui ;
##   4. une épée qui se plante dans un squelette et le disloque.
## Lumière de tournage (film seulement) : une lampe douce qui suit la caméra, ambiance relevée.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_telekinesie_integ.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible [--images=<dossier>]

const DT := 1.0 / 30.0

var s: Node
var j: CharacterBody3D
var magie: MainSort
var l: Label
var _dossier := ""
var _n_cap := 0
var _n := 0
var _lampe: OmniLight3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await process_frame
		_suivre_lampe()

func _suivre_lampe() -> void:
	if _lampe != null and is_instance_valid(_lampe):
		_lampe.global_position = j.camera.global_position + Vector3.UP * 0.6 - j.camera.global_basis.z * 1.2

func _texte(t: String) -> void:
	if l != null:
		l.text = t

func _capture(nom: String) -> void:
	if _dossier == "":
		return
	await process_frame
	_n_cap += 1
	root.get_viewport().get_texture().get_image().save_png(_dossier.path_join("%02d_%s.png" % [_n_cap, nom]))

func _regarder(p: Vector3, duree: float) -> void:
	var n := maxi(1, roundi(duree / DT))
	var y0 := j.rotation.y
	var x0: float = j.tete.rotation.x
	for k in n:
		var o: Vector3 = j.camera.global_position
		var d := p - o
		var u := smoothstep(0.0, 1.0, float(k + 1) / n)
		j.rotation.y = lerp_angle(y0, atan2(-d.x, -d.z), u)
		j.tete.rotation.x = lerpf(x0, atan2(d.y, Vector2(d.x, d.z).length()), u)
		await process_frame
		_suivre_lampe()

func _rayon(a: Vector3, b: Vector3, ex: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var e2: Array[RID] = ex.duplicate()
	e2.append(j.get_rid())
	q.exclude = e2
	return j.get_world_3d().direct_space_state.intersect_ray(q)

func _sol(p: Vector3) -> Vector3:
	var r := _rayon(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0)
	return r["position"] if not r.is_empty() else p

## Ennemi qui reste sur place (il encaisse, titube, tombe : IA active, sans marche ; même réglage que video_impacts_lances.gd).
func _ennemi(type: String, pos: Vector3, vie: float) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(load("res://scripts/draugr.gd"))
	d.type = type
	d.joueur = j
	d.hud = s.get("hud")
	d.ident = "film_tk_integ_%d" % _n
	s.add_child(d)
	d.global_position = _sol(pos)
	var v := j.global_position - d.global_position
	d.rotation.y = atan2(v.x, v.z)
	d.vie = vie
	d.vie_max = maxf(vie, 80.0)
	d.combat.profil.chance_blocage = 0.0
	d._marche = 0.0
	d._marche_proche = 0.0
	d._course = 0.0
	return d

## Cassable de la crypte du genre voulu, le plus proche, visible de l'œil.
func _cassable(genre: String, sauf: Array) -> Node3D:
	var o: Vector3 = j.camera.global_position
	var meilleur: Node3D = null
	var dm := 11.0
	for c in root.get_tree().get_nodes_in_group(Telekinesie.GROUPE):
		if not (c is Cassable) or sauf.has(c) or (c as Cassable).casse or (c as Cassable).genre != genre:
			continue
		var p := Telekinesie.centre(c)
		var dist := o.distance_to(p)
		if dist < dm and dist > 1.5:
			var r := _rayon(o, p, [(c as CollisionObject3D).get_rid()])
			if r.is_empty():
				dm = dist
				meilleur = c
	return meilleur

## Un mur droit devant (cap balayé tous les 10°) entre `dmin` et `dmax` m : {"cap", "point", "normale"}.
func _mur(dmin: float, dmax: float) -> Dictionary:
	var o: Vector3 = j.camera.global_position - Vector3.UP * 0.4
	for k in 36:
		var cap := j.rotation.y + deg_to_rad(10.0 * k)
		var dir := Vector3(-sin(cap), 0, -cos(cap))
		var r := _rayon(o, o + dir * dmax)
		if r.is_empty():
			continue
		var p: Vector3 = r["position"]
		var n: Vector3 = r["normal"]
		if o.distance_to(p) < dmin or n.dot(-dir) < 0.85 or not (r["collider"] is StaticBody3D):
			continue
		# vrai mur plein (pas une herse ni un pilier) : quatre rayons voisins touchent le même plan
		var plein := true
		var lat := dir.cross(Vector3.UP).normalized()
		for dec in [lat * 0.45, -lat * 0.45, Vector3.UP * 0.6 + lat * 0.25, Vector3.UP * 0.6 - lat * 0.25]:
			var r2 := _rayon(o + dec, o + dec + dir * (dmax + 0.5))
			if r2.is_empty() or absf((Vector3(r2["position"]) - p).dot(n)) > 0.12:
				plein = false
				break
		if not plein:
			continue
		# rien de bas (table, sarcophage) entre le joueur et le mur : le corps cloué se voit en entier
		var bas := j.global_position + Vector3.UP * 0.5
		var r3 := _rayon(bas, bas + dir * (o.distance_to(p) + 0.3))
		if not r3.is_empty() and (Vector3(r3["position"]) - p).dot(n) > 0.15:
			continue
		# sol devant le mur, au niveau du joueur
		var pied := _sol(p - dir * 0.5)
		if absf(pied.y - j.global_position.y) > 0.4:
			continue
		return {"cap": cap, "point": p, "normale": n, "dir": dir}
	return {}

## Lumière de tournage posée au-dessus d'un ennemi (film seulement : lire le corps cloué, la dislocation).
func _lumiere_sur(p: Vector3) -> void:
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.86, 0.7)
	o.light_energy = 2.0
	o.omni_range = 5.0
	o.shadow_enabled = false
	s.add_child(o)
	o.global_position = p + Vector3.UP * 2.2 + (j.global_position - p).normalized() * 0.8

## Quelques pas vers `p` (s'arrête à `reste` m).
func _approcher(p: Vector3, reste: float, duree: float) -> void:
	var a := j.global_position
	var d := Vector3(p.x - a.x, 0, p.z - a.z)
	var b := a + d.normalized() * maxf(d.length() - reste, 0.0)
	var n := maxi(1, roundi(duree / DT))
	for k in n:
		j.global_position = a.lerp(b, smoothstep(0.0, 1.0, float(k + 1) / n))
		var v: Vector3 = p + Vector3.UP * 1.0 - j.camera.global_position
		j.rotation.y = atan2(-v.x, -v.z)
		j.tete.rotation.x = atan2(v.y, Vector2(v.x, v.z).length())
		await process_frame
		_suivre_lampe()

## `charge` >= 0 : charge du lancer imposée (durée de tenue ramenée), pour régler la vitesse (une épée lente se plante sans traverser).
func _saisir_lancer(objet: Node3D, but: Vector3, tenue: float, nom: String, charge := -1.0) -> void:
	_texte("Télékinésie : viser, maintenir")
	await _regarder(Telekinesie.centre(objet), 0.55)
	await _attendre(0.2)
	magie.appuyer("gauche")
	await _attendre(0.45)
	await _capture("saisie_" + nom)
	await _regarder(but.lerp(j.camera.global_position, 0.5) + Vector3.UP * 0.25, maxf(tenue * 0.45, 0.3))
	await _capture("tenue_" + nom)
	_texte("…relâcher : lancer")
	await _regarder(but, maxf(tenue * 0.45, 0.3))
	await _attendre(0.08)
	if charge >= 0.0 and magie.tk.tient("gauche"):
		magie.tk.tenue["gauche"]["t"] = 0.2 + charge * magie.eq.sort("gauche").temps_charge_lancer   # Telekinesie.charge_de inversée
	magie.relacher("gauche")
	await _attendre(0.15)
	await _capture("lancer_" + nom)
	await _attendre(0.3)
	await _capture("impact_" + nom)

func _go() -> void:
	RetourImpact.muet = false
	_dossier = _arg("images", "")
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	magie = j.mains.magie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var y0 := j.global_position.y
	var n := 0
	while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
		await process_frame
		n += 1
	await _attendre(2.5)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "telekinesie")
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.visible = false
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	# lumière de tournage (film seulement)
	_lampe = OmniLight3D.new()
	_lampe.name = "LumiereTournage"
	_lampe.light_color = Color(1.0, 0.88, 0.72)
	_lampe.light_energy = 2.2
	_lampe.omni_range = 9.0
	_lampe.shadow_enabled = false
	s.add_child(_lampe)
	for we in s.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		if env != null:
			env.ambient_light_energy = maxf(env.ambient_light_energy, 1.0) * 1.6
	_suivre_lampe()
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 500)
	calque.add_child(l)
	# --- mise en place : murs, ennemis, objets de la crypte
	var mur := _mur(3.6, 8.0)
	print("mur : ", mur)
	var tonneau := _cassable("tonneau", [])
	var urne := _cassable("urne", [tonneau])
	print("tonneau : ", tonneau, "  urne : ", urne)
	var devant := Vector3(-sin(j.rotation.y), 0, -cos(j.rotation.y))
	var draugr_a := _ennemi("guerrier", j.global_position + devant * 4.5 + devant.cross(Vector3.UP) * 0.8, 30.0)   # le tonneau le terrasse
	print("DEBUT_SEQUENCE %.3f (images d'attente : %d)" % [Engine.get_process_frames() * DT, n])
	await _regarder(draugr_a.global_position + Vector3.UP * 1.2, 0.4)
	await _attendre(0.6)
	await _capture("depart")
	# 1. tonneau sur le draugr
	if tonneau != null:
		await _saisir_lancer(tonneau, Elements._centre(draugr_a), 1.4, "tonneau")
		await _attendre(1.0)
	# 2. urne contre un mur
	if urne != null:
		var cible_mur: Vector3 = mur["point"] + Vector3.UP * 0.6 if not mur.is_empty() else j.camera.global_position + devant * 5.0
		await _saisir_lancer(urne, cible_mur, 1.0, "urne")
		await _attendre(0.9)
	# 3. épée qui transperce un draugr et le cloue au mur
	if not mur.is_empty():
		var dir: Vector3 = mur["dir"]
		await _regarder(Vector3(mur["point"]) + Vector3.UP * 0.4, 0.6)
		# quelques pas vers le mur : on le lance à ~4 m (le corps cloué se lit)
		if j.global_position.distance_to(Vector3(mur["point"])) > 4.4:
			await _approcher(Vector3(mur["point"]), 4.0, 1.0)
		j.rotation.y = float(mur["cap"])
		await _attendre(0.1)
		var draugr_b := _ennemi("guerrier", Vector3(mur["point"]) - dir * 0.42, 15.0)
		_lumiere_sur(draugr_b.global_position)
		var epee := ObjetMonde.creer("epee_soldat", 1, j, s.get("dialogue"))
		s.add_child(epee)
		epee.global_position = _sol(j.global_position + dir * 1.9 + dir.cross(Vector3.UP) * 0.15)
		epee.rotation.y = j.rotation.y + PI * 0.5
		await _attendre(0.5)
		await _saisir_lancer(epee, Elements._centre(draugr_b) + Vector3.UP * 0.1, 1.4, "epee_cloue")
		await _attendre(0.4)
		print("cloue : ", ImpactsLances.dernier.get("issue", "?"))
		# l'épée plantée (ArmeLancee du groupe « armes_plantees ») : on s'approche et on la regarde, avec le corps cloué
		var lame: Node3D = null
		for a in root.get_tree().get_nodes_in_group("armes_plantees"):
			if lame == null or (a as Node3D).global_position.distance_to(Vector3(mur["point"])) < lame.global_position.distance_to(Vector3(mur["point"])):
				lame = a
		var vise: Vector3 = lame.global_position if lame != null else Vector3(mur["point"]) + Vector3.UP * 1.0
		await _approcher(vise - Vector3.UP * 1.0, 2.7, 1.3)
		await _regarder(vise - Vector3.UP * 0.25, 0.4)
		await _attendre(0.9)
		await _capture("cloue")
	# 4. épée dans un squelette qui se disloque
	# une direction dégagée (4 m libres à hauteur de torse, sol au même niveau)
	var cap0 := j.rotation.y
	for dcap in [-70.0, 70.0, -110.0, 110.0, 180.0, -35.0, 35.0]:
		var c := cap0 + deg_to_rad(dcap)
		var dd := Vector3(-sin(c), 0, -cos(c))
		var o: Vector3 = j.global_position + Vector3.UP * 1.1
		# … et rien derrière le squelette sur 3,5 m : l'épée s'y plante et il se disloque (pas cloué)
		if _rayon(o, o + dd * 8.0).is_empty() and absf(_sol(j.global_position + dd * 3.6).y - j.global_position.y) < 0.4:
			cap0 = c
			break
	await _regarder(j.global_position + Vector3(-sin(cap0), 0, -cos(cap0)) * 4.0 + Vector3.UP * 1.2, 0.7)
	j.rotation.y = cap0
	var dv := Vector3(-sin(j.rotation.y), 0, -cos(j.rotation.y))
	var sq := _ennemi("squelette", j.global_position + dv * 3.6, 10.0)
	_lumiere_sur(sq.global_position)
	var epee2 := ObjetMonde.creer("epee_soldat", 1, j, s.get("dialogue"))
	s.add_child(epee2)
	epee2.global_position = _sol(j.global_position + dv * 1.8 + dv.cross(Vector3.UP) * -0.2)
	epee2.rotation.y = j.rotation.y + PI * 0.5
	await _attendre(0.5)
	await _saisir_lancer(epee2, Elements._centre(sq), 1.2, "epee_squelette", 0.05)
	print("squelette : ", ImpactsLances.dernier.get("issue", "?"))
	await _attendre(0.6)
	await _approcher(sq.global_position, 1.6, 1.0)
	await _attendre(0.6)
	await _capture("squelette")
	_texte("")
	await _attendre(0.5)
	print("FIN_SEQUENCE")
	for e in magie.tk.journal:
		print("TK %.2f %s" % [e[0], e[1]])
	quit(0)
