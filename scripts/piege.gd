class_name Piege
extends RefCounted
## Pièges des donjons. Chaque fabrique renvoie un Node3D posé à l'origine de `parent` (positions dans le repère de `parent`).
##
## API (le dernier paramètre facultatif `ctx` est un Dictionnaire) :
##   Piege.dalle_flechettes(parent, pos_dalle, pos_bouche, dir, ident, ctx := {}) -> Node3D
##   Piege.souffle_givre(parent, pos, dir, longueur, periode, ident, ctx := {}) -> Node3D
## `ctx` : "joueur" (sinon trouvé en remontant les parents : propriété `joueur` du monde / du tertre) ; souffle : "largeur" (m, défaut 2,3).
## Conventions : pos_dalle = SOL sous la dalle (1,3 m de côté) ; pos_bouche = centre de la plaque percée dans le mur (≈ 1 m du sol) ;
## dir = sens du tir / du souffle (horizontal, normalisé en interne) ; souffle : pos = centre de la bouche (≈ 1 m du sol), la zone de
## givre part de la bouche sur `longueur` m ; periode (≥ 3 s) = durée d'un cycle calme -> annonce -> souffle.
##
## Dalle : seul le JOUEUR au sol la déclenche (jamais les ennemis). Elle s'enfonce avec un clic, 0,45 s plus tard 2 fléchettes (0,3 s
## d'écart, 18 m/s, 12 dégâts chacune) partent de la bouche. On évite en quittant la ligne de tir ; garde/parade valent de face
## (joueur.recevoir_coup(degats, position de la fléchette)). Rechargée 3 s après, une fois la dalle libre. Indices : dalle fendue,
## os et crâne devant, plaque aux trois trous.
## Souffle : cycle calme (≥ 3 s) -> annonce 0,6-1,2 s (givre qui fume, sifflement) -> souffle (30 % de la période) : 5 dégâts toutes les
## 0,5 s à qui est dans la zone. Givre au sol toujours visible. Rien n'est jamais permanent : on traverse pendant le calme.
## Aucun état sauvegardé (les pièges se réarment seuls).

const DEGATS_FLECHETTE := 12.0
const DEGATS_SOUFFLE := 5.0

static func dalle_flechettes(parent: Node, pos_dalle: Vector3, pos_bouche: Vector3, dir: Vector3, ident: String, ctx := {}) -> Node3D:
	var n := Dalle.new()
	n.pos_dalle = pos_dalle
	n.pos_bouche = pos_bouche
	n.dir = Vector3(dir.x, dir.y, dir.z).normalized()
	return Mecanisme._poser(n, parent, ident, ctx)

static func souffle_givre(parent: Node, pos: Vector3, dir: Vector3, longueur: float, periode: float, ident: String, ctx := {}) -> Node3D:
	var n := Souffle.new()
	n.pos = pos
	n.dir = Vector3(dir.x, 0.0, dir.z).normalized()
	n.longueur = longueur
	n.periode = maxf(periode, 3.0)
	return Mecanisme._poser(n, parent, ident, ctx)

# ------------------------------------------------------------------ fléchette
class Fleche extends Node3D:
	var vitesse := 18.0
	var direction := Vector3.FORWARD     # globale
	var joueur: CharacterBody3D
	var degats := 12.0
	var _vie := 1.6
	var _plantee := false

	func _ready() -> void:
		var fer := Mecanisme.materiau(Palette.ACIER, "piege_fleche", Vector2.ONE, Color(0.8, 0.8, 0.85))
		var bois := Mecanisme.materiau(Palette.PLANCHES, "piege_fleche_bois", Vector2.ONE)
		Mecanisme.boite(self, Vector3(0.025, 0.025, 0.55), Vector3(0, 0, 0.1), bois)
		Mecanisme.boite(self, Vector3(0.04, 0.04, 0.12), Vector3(0, 0, -0.2), fer)
		look_at(global_position + direction, Vector3.UP) if absf(direction.y) < 0.99 else null

	func _physics_process(dt: float) -> void:
		_vie -= dt
		if _vie <= 0.0:
			queue_free()
			return
		if _plantee:
			return
		var ancien := global_position
		var nouveau := ancien + direction * vitesse * dt
		var rq := PhysicsRayQueryParameters3D.create(ancien, nouveau)
		if joueur != null:
			rq.exclude = [joueur.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(rq)
		if joueur != null and not joueur.mort:
			var seg := nouveau - ancien
			var t := clampf((joueur.global_position + Vector3(0, 0.9, 0) - ancien).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
			var c := ancien + seg * t
			var v := c - (joueur.global_position + Vector3(0, 0.9, 0))
			if Vector2(v.x, v.z).length() < 0.45 and absf(v.y) < 0.95 and (r.is_empty() or ancien.distance_to(c) < ancien.distance_to(r["position"])):
				joueur.recevoir_coup(degats, ancien)
				queue_free()
				return
		if not r.is_empty():
			global_position = r["position"]
			_plantee = true
			_vie = 4.0
			Sons.jouer_a(self, ["impactWood_heavy_000"], global_position, -10.0)
			return
		global_position = nouveau

# ------------------------------------------------------------------ dalle à fléchettes
class Dalle extends Mecanisme.Base:
	enum { ARMEE, AMORCE, RECHARGE }
	var pos_dalle := Vector3.ZERO
	var pos_bouche := Vector3.ZERO
	var dir := Vector3.FORWARD
	var etat := ARMEE
	var tirs_restants := 0
	var fleches_tirees := 0          # compteur (tests)
	var _delai := 0.0
	var _dalle: MeshInstance3D

	func construire() -> void:
		var pierre := Mecanisme.texture_fissures(Palette.ROCHE, 900 + ident.hash() % 500, 4)
		var m_dalle := Palette.materiau(pierre, Vector2.ONE, Color(1.05, 1.05, 1.1))
		_mats["dalle"] = m_dalle
		_dalle = Mecanisme.boite(self, Vector3(1.3, 0.1, 1.3), pos_dalle, m_dalle)
		_dalle.rotation.y = atan2(-dir.x, -dir.z)
		var os_m := mat(Palette.OSSEMENT, "piege_os", Vector2.ONE)
		var back := -Vector3(dir.x, 0, dir.z).normalized()
		var lat := Vector3(-back.z, 0, back.x)
		# os et crâne devant la dalle (côté d'où l'on vient) : l'avertissement
		var rng := RandomNumberGenerator.new()
		rng.seed = ident.hash()
		for i in 4:
			var o := pos_dalle + back * rng.randf_range(1.0, 1.7) + lat * rng.randf_range(-0.5, 0.5)
			Mecanisme.boite(self, Vector3(0.05, 0.05, rng.randf_range(0.22, 0.4)), o + Vector3(0, 0.03, 0), os_m, Vector3(0, rng.randf() * TAU, 0))
		var crane := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.1
		sp.height = 0.2
		sp.radial_segments = 8
		sp.rings = 4
		crane.mesh = sp
		crane.material_override = os_m
		crane.position = pos_dalle + back * 1.2 + lat * 0.35 + Vector3(0, 0.1, 0)
		add_child(crane)
		# plaque percée dans le mur : trois trous sombres, visibles de face
		var plaque := Node3D.new()
		plaque.position = pos_bouche
		plaque.rotation.y = atan2(-dir.x, -dir.z)
		add_child(plaque)
		var fer := mat(Palette.ACIER, "piege_plaque", Vector2.ONE, Color(0.6, 0.55, 0.5))
		Mecanisme.boite(plaque, Vector3(0.55, 0.55, 0.06), Vector3.ZERO, fer)
		var noir := Palette.lueur(Color(0.02, 0.02, 0.03))
		for dx in [-0.16, 0.0, 0.16]:
			Mecanisme.boite(plaque, Vector3(0.09, 0.09, 0.03), Vector3(dx, 0.0, -0.035), noir)

	func _physics_process(dt: float) -> void:
		if joueur == null or joueur.mort:
			return
		var l := to_local(joueur.global_position) - pos_dalle
		var dessus: bool = absf(l.x) < 0.65 and absf(l.z) < 0.65 and l.y > -0.3 and l.y < 0.5 and joueur.is_on_floor()
		match etat:
			ARMEE:
				if dessus:
					_declencher()
			AMORCE:
				_delai -= dt
				if _delai <= 0.0:
					_tirer()
					tirs_restants -= 1
					if tirs_restants > 0:
						_delai = 0.3
					else:
						etat = RECHARGE
						_delai = 3.0
			RECHARGE:
				_delai -= dt
				if _delai <= 0.0 and not dessus:
					etat = ARMEE
					_dalle.position.y = pos_dalle.y

	func _declencher() -> void:
		etat = AMORCE
		_delai = 0.45
		tirs_restants = 2
		_dalle.position.y = pos_dalle.y - 0.04
		son(["impactPlate_medium_001", "creak1"], pos_dalle, 0.0)

	func _tirer() -> void:
		var f := Fleche.new()
		f.joueur = joueur
		f.degats = Piege.DEGATS_FLECHETTE
		f.direction = global_transform.basis * dir
		f.position = pos_bouche + dir * 0.2
		add_child(f)
		fleches_tirees += 1
		son(["swing2"], pos_bouche, -4.0)

# ------------------------------------------------------------------ souffle de givre
class Souffle extends Mecanisme.Base:
	var pos := Vector3.ZERO
	var dir := Vector3.FORWARD
	var longueur := 6.0
	var periode := 6.0
	var largeur := 2.3
	var temps := 0.0
	var _tick := 0.0
	var _phase_prec := ""
	var _brume: MeshInstance3D
	var _jet: GPUParticles3D
	var _froid: OmniLight3D
	var _vent: AudioStreamPlayer3D
	var degats_infliges := 0.0      # compteur (tests)

	func construire() -> void:
		largeur = float(ctx.get("largeur", 2.3))
		temps = float(ident.hash() % 1000) / 1000.0 * periode        # cycles décalés d'un piège à l'autre
		rotation.y = 0.0
		var lacet := atan2(-dir.x, -dir.z)
		var sol := pos.y - 1.0
		# plaque de la bouche avec stalactites de givre
		var bouche := Node3D.new()
		bouche.position = pos
		bouche.rotation.y = lacet
		add_child(bouche)
		var pierre := mat(Palette.ROCHE, "souffle_bouche", Vector2.ONE, Color(0.8, 0.85, 1.0))
		var glace := mat(Palette.NEIGE, "souffle_glace", Vector2.ONE, Color(1.0, 1.05, 1.2))
		Mecanisme.boite(bouche, Vector3(0.9, 0.7, 0.1), Vector3.ZERO, pierre)
		Mecanisme.boite(bouche, Vector3(0.62, 0.34, 0.06), Vector3(0, 0, -0.06), Palette.lueur(Color(0.02, 0.03, 0.05)))
		for i in 5:
			var h := 0.14 + 0.07 * float(i % 3)
			var c := Mecanisme.cylindre(bouche, 0.045, 0.0, h, Vector3(-0.28 + 0.14 * i, 0.17 - h * 0.5, -0.07), glace, 5)
			c.rotation.x = 0.0
		# givre sur le sol le long de la zone : toujours visible
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(largeur, longueur)
		q.mesh = pm
		q.material_override = _mat_givre()
		q.position = Vector3(pos.x, sol + 0.02, pos.z) + dir * longueur * 0.5
		q.rotation.y = lacet
		add_child(q)
		# brume du souffle (visible pendant le souffle seulement)
		_brume = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(largeur, 1.9, longueur)
		var mb := StandardMaterial3D.new()
		mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mb.albedo_color = Color(0.75, 0.9, 1.0, 0.16)
		mb.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.material = mb
		_brume.mesh = bm
		_brume.position = Vector3(pos.x, sol + 0.95, pos.z) + dir * longueur * 0.5
		_brume.rotation.y = lacet
		_brume.visible = false
		_brume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_brume)
		# jet de givre : cubes blancs qui filent le long de la zone
		var vit := 6.0
		_jet = Mecanisme.particules(self, pos + dir * 0.3, Color(0.85, 0.95, 1.0), 50, longueur / vit, vit, dir, 9.0, Vector3(0.15, 0.2, 0.15), 0.06)
		_jet.emitting = false
		_froid = OmniLight3D.new()
		_froid.position = Vector3(pos.x, sol + 1.2, pos.z) + dir * longueur * 0.4
		_froid.light_color = Color(0.5, 0.8, 1.0)
		_froid.light_energy = 0.0
		_froid.omni_range = longueur * 0.8
		_froid.shadow_enabled = false
		add_child(_froid)

	func _mat_givre() -> StandardMaterial3D:
		var rng := RandomNumberGenerator.new()
		rng.seed = 31 + ident.hash() % 900
		var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var fond := 1.0 - float(y) / 63.0          # le givre s'épaissit vers la bouche (y = 0 côté bouche)
			for x in 32:
				var bord := 1.0 - absf(float(x) - 15.5) / 15.5
				var a := fond * 0.55 + bord * 0.45 - rng.randf() * 0.6
				if a > 0.15:
					img.set_pixel(x, y, Color(0.8 + rng.randf() * 0.2, 0.9 + rng.randf() * 0.1, 1.0, clampf(a * 1.3, 0.0, 0.85)))
				else:
					img.set_pixel(x, y, Color(1, 1, 1, 0))
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		return m

	## "calme", "annonce" ou "souffle" à l'instant t du cycle.
	func phase_a(t: float) -> String:
		var annonce := clampf(periode * 0.2, 0.6, 1.2)
		var souffle := periode * 0.3
		var c := fposmod(t, periode)
		if c < periode - annonce - souffle:
			return "calme"
		if c < periode - souffle:
			return "annonce"
		return "souffle"

	func phase() -> String:
		return phase_a(temps)

	func dans_zone(p_global: Vector3) -> bool:
		var v := to_local(p_global) - pos
		var along := v.dot(dir)
		var perp := Vector3(-dir.z, 0, dir.x)
		return along >= -0.2 and along <= longueur and absf(v.dot(perp)) <= largeur * 0.5 and v.y >= -1.1 and v.y <= 1.2

	func _physics_process(dt: float) -> void:
		temps += dt
		var ph := phase()
		if ph != _phase_prec:
			_changer_phase(ph)
			_phase_prec = ph
		if ph != "souffle" or joueur == null or joueur.mort:
			return
		_tick -= dt
		if _tick <= 0.0 and dans_zone(joueur.global_position):
			_tick = 0.5
			degats_infliges += Piege.DEGATS_SOUFFLE
			joueur.recevoir_coup(Piege.DEGATS_SOUFFLE, global_transform * pos)

	func _changer_phase(ph: String) -> void:
		_brume.visible = ph == "souffle"
		_jet.emitting = ph != "calme"
		_jet.amount_ratio = 1.0 if ph == "souffle" else 0.12
		_froid.light_energy = 1.2 if ph == "souffle" else (0.4 if ph == "annonce" else 0.0)
		if ph == "souffle":
			_tick = 0.15
		if ph == "annonce" and is_inside_tree():
			if _vent == null:
				_vent = AudioStreamPlayer3D.new()
				_vent.stream = Sons.flux("ambiance_vent")
				_vent.unit_size = 5.0
				_vent.volume_db = -4.0
				add_child(_vent)
				_vent.position = pos
			if _vent.stream != null:
				_vent.play()
		elif ph == "calme" and _vent != null:
			_vent.stop()
