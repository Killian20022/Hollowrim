class_name Mannequin
extends StaticBody3D
## Mannequin d'entraînement : poteau, sac de paille, bras de bois et tête en sac. Il ne meurt jamais : chaque coup est mesuré
## (dégâts, total, posture, réaction, finisher disponible) avec le même calcul que les ennemis (CombatEnnemi, profil « mannequin »).
## Il oscille dans le sens du coup (ressort), se couvre d'entailles (copeaux), et sa posture se brise : un coup lourd en posture
## brisée déclenche le finisher (la tête vole, elle repousse après 3 s). Groupe « ennemis » : l'épée du joueur le frappe comme un ennemi.

var joueur: Node3D
var vie := 100.0
var vie_max := 100.0
var nom_affiche := "Mannequin"
var total := 0.0
var coups := 0
var dernier := 0.0
var combat: CombatEnnemi
var pivot: Node3D
var tete: MeshInstance3D
var _tilt := Vector2.ZERO
var _v := Vector2.ZERO
var _t := 0.0
var _etiquette: Label3D

func _ready() -> void:
	add_to_group("ennemis")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.9
	cs.shape = cyl
	cs.position.y = 0.95
	add_child(cs)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	var bois := Palette.materiau(Palette.tex("bois_mannequin", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.6), Vector2(1, 3))
	var paille := Palette.materiau(Palette.tex("paille_mannequin", ["#4a3c1e", "#6a582c", "#8a743c", "#a8904e"], 4, 0.7), Vector2(2, 2))
	var toile := Palette.materiau(Palette.tex("toile_mannequin", ["#3a3226", "#544836", "#6e604a", "#86785e"], 4, 0.5), Vector2(1, 1))
	_boite(pivot, Vector3(0.11, 1.75, 0.11), Vector3(0, 0.875, 0), bois)
	_boite(pivot, Vector3(1.05, 0.08, 0.08), Vector3(0, 1.36, 0), bois)
	var torse := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.2
	cy.bottom_radius = 0.24
	cy.height = 0.62
	cy.radial_segments = 10
	torse.mesh = cy
	torse.material_override = paille
	torse.position = Vector3(0, 1.15, 0)
	pivot.add_child(torse)
	tete = MeshInstance3D.new()
	tete.name = "Tete"
	var sp := SphereMesh.new()
	sp.radius = 0.13
	sp.height = 0.28
	sp.radial_segments = 10
	sp.rings = 6
	tete.mesh = sp
	tete.material_override = toile
	tete.position = Vector3(0, 1.68, 0)
	pivot.add_child(tete)
	# socle en croix
	_boite(self, Vector3(0.7, 0.08, 0.12), Vector3(0, 0.04, 0), bois)
	_boite(self, Vector3(0.12, 0.08, 0.7), Vector3(0, 0.04, 0), bois)
	combat = CombatEnnemi.equiper(self, pivot, ProfilCible.pour("mannequin"))
	combat.etiquette = false
	_etiquette = Label3D.new()
	_etiquette.font = Palette.police()
	_etiquette.font_size = 26
	_etiquette.pixel_size = 0.005
	_etiquette.outline_size = 6
	_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiquette.no_depth_test = true
	_etiquette.position = Vector3(0, 2.55, 0)
	add_child(_etiquette)

func _boite(parent: Node3D, taille: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

func vivant() -> bool:
	return true

func en_combat() -> bool:
	return false

func point_impact() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)

func recevoir_coup(quantite: float, origine_coup: Vector3, puissant := false, info: Dictionary = {}) -> String:
	var r := combat.analyser(quantite, origine_coup, puissant, info, {"de_face": true, "peut_bloquer": false, "hauteur_visee": CombatEnnemi.hauteur_visee(joueur, self)})
	if String(r["info"]["attaque"]) in ["lourde", "chargee_max", "contre"] and joueur != null:
		var cat := finisher_possible(joueur)
		if cat != "":
			return subir_finisher(cat, r["info"])
	dernier = float(r["degats"])
	total += dernier
	coups += 1
	combat.effets_impact(r, joueur)
	var d: Vector3 = r["info"]["direction"]
	var f := {"leger": 0.5, "moyen": 0.8, "lourd": 1.3, "recul": 1.7, "chute": 1.6, "etourdi": 1.5}
	_v += Vector2(d.x, d.z).normalized() * float(f.get(r["reaction"], 0.6))
	if r["reaction"] == "etourdi" and combat.etourdi <= 0.0:
		combat.briser_posture()
	return "touche"

func finisher_possible(j: Node3D) -> String:
	if tete == null or not tete.visible:
		return ""
	return combat.finisher_possible(j, vie, vie_max)

## Finisher sur le mannequin : la tête de toile s'envole (copie en corps rigide), puis repousse.
func subir_finisher(categorie: String, info: Dictionary = {}) -> String:
	var o: Vector3 = info.get("origine", joueur.global_position if joueur else global_position + Vector3.BACK)
	var i := CalculDegats.completer(info, self, 100.0, o, true, combat.hauteur)
	i["attaque"] = "finisher"
	var r := {"info": i, "degats": 0.0, "stagger": 0.0, "critique": true, "impact": "finisher", "reaction": "finisher", "finisher": categorie}
	RetourImpact.jouer(self, ProfilImpact.de("finisher"), joueur)
	RetourImpact.son_finisher(self, tete.global_position, "bois")
	var rb := RigidBody3D.new()
	rb.mass = 2.0
	rb.collision_layer = 16
	rb.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.13
	cs.shape = sph
	rb.add_child(cs)
	var copie := MeshInstance3D.new()
	copie.mesh = tete.mesh
	copie.material_override = tete.material_override
	rb.add_child(copie)
	get_parent().add_child(rb)
	rb.global_transform = tete.global_transform
	var dir := (Vector3(i["direction"]) * 0.6 + Vector3.UP * 0.6).normalized()
	rb.apply_central_impulse(dir * 9.0)
	rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-5, 5), randf_range(-8, 8))
	Sang.eclats_matiere(self, tete.global_position, dir, 3.0, combat.profil.couleur_sang)
	tete.visible = false
	combat.etourdi = 0.0
	combat.posture = combat.profil.posture_max
	if combat.reaction_os:
		combat.reaction_os.etourdi = false
	_v += Vector2(dir.x, dir.z) * 2.0
	set_meta("dernier_finisher", r)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			tete.visible = true)
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(rb):
			rb.queue_free())
	if CombatEnnemi.debug:
		combat._flottant("FINISHER " + categorie.to_upper(), global_position + Vector3(0, 2.1, 0), Color(1.0, 0.3, 0.25))
	return "tue"

func _process(dt: float) -> void:
	_t += dt
	# ressort d'oscillation (le poteau plie au pied)
	var cible := Vector2.ZERO
	if combat.etourdi > 0.0:
		cible = Vector2(sin(_t * 2.6), cos(_t * 2.1)) * 0.12
	_v += (-(_tilt - cible) * 60.0 - _v * 6.0) * dt
	_tilt += _v * dt
	_tilt = _tilt.limit_length(0.45)
	var ang := _tilt.length()
	if ang > 0.0005:
		var axe := Vector3.UP.cross(Vector3(_tilt.x, 0, _tilt.y) / ang).normalized()
		pivot.basis = Basis(axe, ang)
	else:
		pivot.basis = Basis()
	var fin := finisher_possible(joueur) if joueur else ""
	_etiquette.text = "MANNEQUIN  dernier %d  total %d  coups %d\nposture %d%%  %s%s" % [roundi(dernier), roundi(total), coups, roundi(combat.ratio_posture() * 100.0),
		"ETOURDI " if combat.etourdi > 0.0 else "", ("FINISHER: " + fin) if fin != "" else ""]
	_etiquette.modulate = Color(1.0, 0.85, 0.3) if fin != "" else Color(0.9, 0.92, 1.0)
