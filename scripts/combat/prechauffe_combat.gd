class_name PrechauffeCombat
## Préchauffage des effets de combat pendant le chargement (bug « ça rame quand je frappe », 2026-10-27).
## Le PREMIER coup qui portait payait d'un coup : génération des textures de sang peintes par code, compilation des shaders de
## particules (giclées, éclats d'os, étincelles, jets), des traces au sol, des plaies, des bouchons de cou et de la traînée de lame
## (mesuré dans la vraie crypte : 150-200 ms dans l'appel du coup + 11 à 30 pipelines compilés, image de 190-290 ms ; idem au
## premier squelette, au premier draugr guerrier).
## Ici : (1) les caches CPU sont remplis tout de suite (textures, sons) ; (2) une « vitrine » des effets, avec les VRAIS matériaux
## et les mêmes ressources de particules que Sang / Effets, est rendue hors écran par PrechauffeRendu (SubViewport qui partage le
## monde) dans les deux éclairages du jeu : sous terre (environnement de la crypte, sans soleil, lumière de torche) et dehors
## (soleil, torche). La vitrine est posée sous le sol (invisible du joueur) et supprimée après ses images.
## Ses matériaux viennent des caches statiques de Sang / Effets / Decapitation : ils survivent à la vitrine (un shader de matériau
## standard ou de particules est libéré, puis recompilé, dès que son dernier matériau disparaît).

const COULEURS := [Color(0.26, 0.04, 0.03), Color(0.40, 0.025, 0.02), Color(0.72, 0.68, 0.56), Color(0.62, 0.48, 0.30)]
static var _caches_faits := false

## Caches CPU (sans rendu) : textures de sang / plaies peintes par code, sons de combat lus en tâche de fond, profils d'impact.
static func caches() -> void:
	if _caches_faits:
		return
	_caches_faits = true
	for sorte in ["flaque", "giclure", "trainee", "entaille", "fissure", "copeau"]:
		for v in 3:
			Sang.texture(sorte, v)
	RetourImpact.precharger()
	for n: String in ProfilImpact.NOMS:
		ProfilImpact.de(n)
	# matériaux partagés des effets (caches statiques de Sang / Effets / Decapitation) : leurs shaders (particules, matériaux
	# standard) sont générés pendant le chargement et restent vivants tant que le cache les tient
	for c: Color in COULEURS:
		Sang._cube(Vector3(0.022, 0.06, 0.022), c)
		Sang._cube(Vector3(0.022, 0.022, 0.022), c * 0.85)
		Decapitation.mat_bouchon(c)
		for sorte in ["flaque", "giclure", "trainee"]:
			for k in 3:
				Sang._mat_trace(sorte, c)
	Decapitation.mat_bouchon(Color(0.55, 0.06, 0.05))
	Decapitation.mat_bouchon(Color(0.7, 0.66, 0.55))
	Sang._pm_giclee(22.0, 1.8, 5.2, true)
	Sang._pm_giclee(55.0, 0.8, 2.6, true)
	Sang._pm_giclee(45.0, 1.2, 4.0, false)
	Sang.pm_jet(1)
	Sang.pm_jet(2)
	for v in [1.6, 2.2, 2.4, 2.5, 2.8, 3.0, 3.2]:
		Effets._pm_eclats(v)
	for c: Color in [Color(3.0, 2.2, 0.8), Color(3.0, 2.4, 1.0), Color(3.2, 2.6, 1.2), Color(3.0, 2.1, 0.7), Color(3.0, 2.0, 0.7)]:
		Effets._cube_eclats(c, true)
	Effets._cube_eclats(Color(0.6, 0.45, 0.3), false)

## Lance le préchauffage rendu d'une vitrine posée en `lieu` (monde, sous le sol) : `soleil` exclu de la caméra si donné (sous
## terre), `env` = environnement du lieu (null = celui du monde). Renvoie la vitrine (libérée toute seule à la fin).
static func lancer(hote: Node, lieu: Vector3, soleil: Light3D = null, env: Environment = null) -> Node3D:
	caches()
	var v := vitrine()
	v.name = "VitrineEffetsCombat"
	hote.add_child(v)
	v.global_position = lieu
	v.visible = false
	var pts: Array = []
	for k in 3:
		var oeil := lieu + Vector3(0.25 * (k - 1), 0.15, 1.6)
		pts.append(Transform3D(Basis.looking_at(lieu - oeil, Vector3.UP), oeil))
	var p := PrechauffeRendu.lancer(v, hote, pts, soleil, env, 0.0)
	p.tree_exited.connect(func() -> void:
		if is_instance_valid(v):
			v.queue_free())
	return v

## Vitrine des effets (nœuds éphémères de Sang, Effets, Plaies, Decapitation, TraineeLame), sur ~1 m autour de son origine.
static func vitrine() -> Node3D:
	var v := Node3D.new()
	# torche du joueur : les effets sont presque toujours vus sous une lumière ponctuelle
	var l := OmniLight3D.new()
	l.omni_range = 3.0
	l.light_energy = 1.4
	l.light_color = Color(1.0, 0.7, 0.4)
	l.position = Vector3(0.6, 0.8, 0.8)
	v.add_child(l)
	var x := -0.9
	# giclées (rampe de couleur, alignées ou non), éclats d'os (rampe, non alignés), jets (alignés, sans rampe), étincelles
	for c: Color in COULEURS:
		_particules(v, Vector3(x, 0.3, 0), Sang._pm_giclee(22.0, 1.8, 5.2, true), Sang._cube(Vector3(0.022, 0.06, 0.022), c))
		_particules(v, Vector3(x, 0.6, 0), Sang._pm_giclee(45.0, 1.2, 4.0, false), Sang._cube(Vector3(0.022, 0.022, 0.022), c * 0.85))
		x += 0.2
	_particules(v, Vector3(0.0, 0.0, -0.2), Sang.pm_jet(2), Sang._cube(Vector3(0.03, 0.08, 0.03), COULEURS[0]))
	_particules(v, Vector3(0.3, 0.0, -0.2), Effets._pm_eclats(3.0), Effets._cube_eclats(Color(3.0, 2.2, 0.8), true))
	_particules(v, Vector3(0.5, 0.0, -0.2), Effets._pm_eclats(2.2), Effets._cube_eclats(Color(0.6, 0.45, 0.3), false))
	# traces au sol / au mur (plans à découpe alpha) et bouchon de cou (cylindre texturé opaque)
	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE * 0.3
	var i := 0
	for sorte in ["flaque", "giclure", "trainee"]:
		var mi := MeshInstance3D.new()
		mi.mesh = plan
		mi.material_override = Sang._mat_trace(sorte, COULEURS[i % COULEURS.size()])
		mi.position = Vector3(-0.6 + i * 0.35, -0.2, 0.2)
		v.add_child(mi)
		i += 1
	var bouchon := Node3D.new()
	v.add_child(bouchon)
	Decapitation._bouchon(bouchon, Transform3D(Basis(), Vector3(0.6, -0.1, 0.2)), COULEURS[0], 0.06)
	# plaie : décal sur un maillage du calque des plaies, avec le shader des personnages
	var corps := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = Vector3(0.3, 0.4, 0.2)
	corps.mesh = boite
	var sh := load("res://shaders/perso.gdshader") as Shader
	if sh != null:
		var sm := ShaderMaterial.new()
		sm.shader = sh
		corps.material_override = sm
	corps.layers |= Plaies.CALQUE
	corps.position = Vector3(0.0, 0.5, -0.5)
	v.add_child(corps)
	var d := Decal.new()
	d.texture_albedo = Sang.texture("entaille", 0)
	d.cull_mask = Plaies.CALQUE
	d.size = Vector3(0.3, 0.5, 0.25)
	d.rotation_degrees = Vector3(90, 0, 0)
	d.position = Vector3(0.0, 0.5, -0.35)
	v.add_child(d)
	# traînée de lame (ruban ImmediateMesh, shader trainee_lame)
	var tr := TraineeLame.new()
	v.add_child(tr)
	tr.ajouter(Vector3(-0.4, 0.9, 0), Vector3(0.4, 1.1, 0))
	tr.ajouter(Vector3(-0.3, 0.7, 0), Vector3(0.5, 0.8, 0))
	tr.avancer(0.0)
	return v

static func _particules(parent: Node3D, pos: Vector3, pm: ParticleProcessMaterial, maillage: Mesh) -> void:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.8
	p.preprocess = 0.4            # déjà des particules en vie à la 1re image rendue
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = pm
	p.draw_pass_1 = maillage
	parent.add_child(p)
	p.position = pos
	p.emitting = true
