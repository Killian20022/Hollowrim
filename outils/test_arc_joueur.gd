extends SceneTree
## Test sans fenêtre de l'ARC DU JOUEUR (ArcJoueur, ArcModele, data/arc/arc_joueur.json, Projectile.tirer_joueur) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_arc_joueur.gd
## Données (arc + flèches au registre, marchand, butin) ; modèle (arc_chasseur.glb : clé de forme « bande », corde de longueur
## constante, flèche du modèle) ; équipement (refus sans arc, épée rangée, vrais bras à la 1re personne) ; pas de bandage sans
## flèche ; tir annulé sous la tension minimale (flèche gardée) ; dégâts et vitesse croissants avec la tension ; une flèche par tir ;
## zoom et ralenti de marche ; la flèche touche le mannequin visé (dégâts selon la vitesse d'IMPACT) et y reste fichée ;
## PHYSIQUE : portée croissante avec la tension, le nez suit la vitesse, départ exactement vers le centre de l'écran, pas de
## traversée d'une palissade de 2 cm à pleine vitesse, flèche plantée à l'angle de son vol ; tremblement si la pleine tension est
## tenue ; rechargement (flèche encochée de nouveau) ; flèche plantée récupérable ; troisième personne (IK du corps) ; rangement.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var arc: ArcJoueur
var cible: StaticBody3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		j.mains.avancer(DT)
		await physics_frame

func _viser_point(c: Vector3) -> void:
	var d: Vector3 = c - j.camera.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await physics_frame

## Distance (m, monde) du fût de la flèche encochée (segment encoche -> pointe) au sommet de l'arc le plus proche.
func _fut_arc(a: ArcModele) -> float:
	var n := a.encoche_monde()
	var p := a.pointe()
	var t := a.mi_arc.global_transform
	var d := INF
	for v in a.mi_arc.mesh.get_faces():
		var w := t * v
		d = minf(d, w.distance_to(Geometry3D.get_closest_point_to_segment(w, n, p)))
	return d

## Corde : "" si elle est faite de 2 segments droits (encoche -> attache haute, encoche -> attache basse) et si ses attaches sont sur
## les branches (à moins de 2 cm d'un sommet de l'arc fléchi par la clé de forme) ; sinon ce qui ne va pas.
func _corde(a: ArcModele) -> String:
	var w := a.mi_arc.get_blend_shape_value(a._cle)
	var haut := a.attache(w, true)
	var bas := a.attache(w, false)
	var nk := a.encoche_locale()
	var ecart := 0.0
	for v in a.mi_corde.mesh.get_faces():
		var e1 := v.distance_to(Geometry3D.get_closest_point_to_segment(v, bas, nk))
		var e2 := v.distance_to(Geometry3D.get_closest_point_to_segment(v, nk, haut))
		ecart = maxf(ecart, minf(e1, e2))
	if ecart > ArcModele.RAYON_CORDE * 1.6:
		return "(sommet de la corde à %.1f mm de ses 2 segments)" % (ecart * 1000.0)
	var m := a.mi_arc.mesh as ArrayMesh
	var base: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var fl: PackedVector3Array = m.surface_get_blend_shape_arrays(0)[a._cle][Mesh.ARRAY_VERTEX]
	var dh := INF
	var db := INF
	for i in base.size():
		var q := base[i].lerp(fl[i], w)
		dh = minf(dh, q.distance_to(haut))
		db = minf(db, q.distance_to(bas))
	if maxf(dh, db) > 0.02:
		return "(attaches à %.1f / %.1f cm des branches)" % [dh * 100.0, db * 100.0]
	return ""

func _viser() -> void:
	await _viser_point(cible.global_position + Vector3(0, 1.1, 0))

## Appui de `tenu` s puis relâché ; rend l'état mesuré à la fin de l'appui.
func _tirer(tenu: float, viser := true) -> Dictionary:
	if viser:
		await _viser()
	var n0 := arc.tirs
	arc.appuyer()
	await _sim(tenu)
	var m := {"tension": arc.tension, "facteur": arc.facteur_vitesse(), "fov": j.camera.fov, "etat": arc.etat, "clip": arc.clip_tps(),
		"tremblement": arc.tremblement}
	if not j.troisieme:
		# pose de visée de la 1re personne (repère de la caméra, fractions de l'écran)
		var inv: Transform3D = j.camera.global_transform.affine_inverse()
		var taille := Vector2(j.camera.get_viewport().get_visible_rect().size)
		m["pointe_cam"] = inv * arc._vm.pointe()
		m["poignee_ecran"] = j.camera.unproject_position(arc._vm.global_position) / taille
		m["encoche_cam"] = inv * arc._vm.encoche_monde()
		m["ecran"] = arc.mesure_ecran(0.04, 0.02)
		m["echelle"] = arc._vm.transform.basis.get_scale().x
		m["fut_arc"] = _fut_arc(arc._vm)
		m["allonge"] = arc._vm.allonge
		m["z_encoche"] = arc._vm.encoche_locale().z
		m["echelle_fleche"] = arc._vm.fleche.global_transform.basis.get_scale().z
		m["corde"] = _corde(arc._vm)
	arc.relacher()
	await _sim(DT * 2.0)
	m["parti"] = arc.tirs > n0
	return m

func _donnees() -> void:
	_verif(Inventaire.connu("arc_chasseur") and Inventaire.categorie_de("arc_chasseur") == "arme", "registre : arc_chasseur (arme)")
	_verif(Inventaire.connu("fleche") and bool(Inventaire.objet("fleche").get("munition", false)), "registre : fleche (munition)")
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/marchands.json"))
	var texte := JSON.stringify(m)
	_verif(texte.contains("\"arc_chasseur\"") and texte.contains("\"fleche\""), "marchand : arc et flèches en vente")
	_verif(FileAccess.get_file_as_string("res://data/butin/cadavres.json").contains("\"fleche\""), "butin : flèches sur les bandits")
	_verif(ArcJoueur.reglage("degats_max", 0.0) > ArcJoueur.reglage("degats_min", 99.0), "réglages lus (dégâts %.0f à %.0f)" % [ArcJoueur.reglage("degats_min", 0.0), ArcJoueur.reglage("degats_max", 0.0)])

func _modele() -> void:
	var a := ArcModele.new()
	root.add_child(a)
	var cle := a.mi_arc.find_blend_shape_by_name(&"bande")
	var tris := 0
	for k in a.mi_arc.mesh.get_surface_count():
		tris += a.mi_arc.mesh.surface_get_array_len(k) / 3 if a.mi_arc.mesh.surface_get_format(k) & Mesh.ARRAY_FORMAT_INDEX == 0 else (a.mi_arc.mesh.surface_get_array_index_len(k) / 3)
	_verif(cle >= 0 and tris >= 250 and tris <= 700, "modèle : arc_chasseur.glb, clé de forme « bande », %d triangles (PS1)" % tris)
	var demi := float(ArcModele.infos()["demi_corde"])
	var poids: Array[float] = []
	for u in [0.0, 0.5, 1.0]:
		a.regler(u, true)
		poids.append(a._poids)
	_verif(poids[0] < 0.02 and poids[1] > 0.1 and poids[2] > 0.95 and poids[1] < poids[2], "l'arc plie avec l'allonge (clé « bande » %.2f / %.2f / %.2f)" % poids)
	var corde_ok := true
	for u in [0.0, 0.3, 0.7, 1.0]:
		a.regler(u, true)
		var n := Vector3(0.0, 0.0, a.encoche_locale().z)
		corde_ok = corde_ok and absf(n.distance_to(a.attache(a._poids)) - demi) < 0.004
	_verif(corde_ok, "la corde garde sa longueur (demi-corde %.3f m) de l'arc au repos à la pleine allonge" % demi)
	a.regler(1.0, true)
	var lf := a.fleche.global_position.distance_to(a.pointe())
	_verif(a.fleche.visible and absf(lf - ArcModele.longueur_pointe()) < 0.01, "flèche encochée visible, %.2f m de l'encoche à la pointe" % lf)
	a.queue_free()

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	arc = j.arc
	arc.souris_reelle = false
	cible = s.mannequin
	cible.position = Vector3(0, 0, -9)
	j.mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	_donnees()
	_modele()
	# équipement
	_verif(arc.equiper() != "" and not arc.actif, "sans arc au sac : refus (« %s »)" % arc.equiper())
	j.inventaire.ajouter("arc_chasseur", 1)
	var epee_avant: bool = j.mains._peut_agir()
	arc.mesure = true
	_verif(arc.equiper() == "" and arc.actif and epee_avant and not j.mains._peut_agir(), "arc équipé : l'épée ne peut plus frapper")
	_verif(not j.mains.visible and arc._rig.visible and arc._sq != null, "première personne : mains de l'épée cachées, vrais bras + arc visibles")
	# pas de flèche
	var sans_n := [0]
	arc.sans_fleche.connect(func() -> void: sans_n[0] += 1)
	var r0 := await _tirer(0.5)
	_verif(sans_n[0] == 1 and r0["etat"] == ArcJoueur.REPOS and not r0["parti"] and arc.tirs == 0 and not arc._vm.fleche.visible, "sans flèche : pas de bandage, pas de tir, rien d'encoché (avis donné)")
	# tension minimale
	j.inventaire.ajouter("fleche", 20)
	await _sim(0.6)
	_verif(arc._vm.fleche.visible, "flèches au sac : une flèche est encochée au repos")
	var r1 := await _tirer(0.05)
	_verif(not r1["parti"] and j.inventaire.nombre("fleche") == 20, "appui trop bref : tir annulé, flèche gardée (%d)" % j.inventaire.nombre("fleche"))
	# tir faible
	var fov0: float = j.camera.fov
	var r2 := await _tirer(0.3)
	var d_faible: float = arc.dernier_tir.get("degats", 0.0)
	var v_faible: float = arc.dernier_tir.get("vitesse", 0.0)
	_verif(r2["parti"] and j.inventaire.nombre("fleche") == 19, "tir faible : une flèche consommée (reste %d)" % j.inventaire.nombre("fleche"))
	_verif(not arc._vm.fleche.visible or arc._vm.fleche_libre != null, "juste après le tir : plus de flèche sur la corde")
	await _sim(1.5)
	_verif(arc._vm.fleche.visible and arc._vm.fleche_libre == null and arc.etat == ArcJoueur.REPOS, "rechargement : nouvelle flèche encochée")
	# tir plein
	var n_coups: int = cible.coups.size()
	var r3 := await _tirer(1.3)
	var d_plein: float = arc.dernier_tir.get("degats", 0.0)
	var v_plein: float = arc.dernier_tir.get("vitesse", 0.0)
	var p_plein: Projectile = arc.dernier_tir["projectile"]
	_verif(r3["parti"] and r3["tension"] >= 0.999 and j.inventaire.nombre("fleche") == 18, "tir plein : tension %.2f, reste %d flèches" % [r3["tension"], j.inventaire.nombre("fleche")])
	_verif(d_plein > d_faible * 2.0 and v_plein > v_faible * 1.5, "dégâts (%.0f contre %.0f) et vitesse (%.0f contre %.0f m/s) croissent avec la tension" % [d_plein, d_faible, v_plein, v_faible])
	_verif(r3["facteur"] < 0.7 and r3["fov"] < fov0 - 3.0, "bandage : marche ×%.2f, champ de vision %.1f → %.1f" % [r3["facteur"], fov0, r3["fov"]])
	var axe: Vector3 = -j.camera.global_transform.basis.z
	var vise := (arc.dernier_tir["cible"] - arc.dernier_tir["depart"]).normalized() as Vector3
	_verif(vise.angle_to(arc.dernier_tir["direction"]) < 0.001 and axe.angle_to(arc.dernier_tir["direction"]) < deg_to_rad(0.5),
		"départ exactement vers le point visé par le centre de l'écran (écart %.2f° avec l'axe de la caméra)" % rad_to_deg(axe.angle_to(arc.dernier_tir["direction"])))
	# 1re personne, pleine tension (composition Skyrim) : pointe AU réticule, arc levé (poing juste sous le centre, à gauche),
	# encoche à la joue, hors du champ (main de corde hors champ)
	var pc: Vector3 = r3["pointe_cam"]
	var pe: Vector2 = r3["poignee_ecran"]
	var ec: Vector3 = r3["encoche_cam"]
	_verif(Vector2(pc.x, pc.y).length() < 0.002 and pc.z < -0.4, "visée 1re personne : pointe de la flèche au centre de l'écran (écart %.1f mm à %.2f m)" % [Vector2(pc.x, pc.y).length() * 1000.0, -pc.z])
	_verif(pe.x > 0.4 and pe.x < 0.65 and pe.y > 0.5 and pe.y < 0.75, "visée 1re personne : arc levé, poignée sous le réticule (%d %% × %d %% de l'écran)" % [roundi(pe.x * 100.0), roundi(pe.y * 100.0)])
	var me: Dictionary = r3["ecran"]
	var pg: Array = me["poing"]
	_verif(me["arc"] == 0 and me["mains"] == 0, "visée 1re personne : la cible reste visible (aucun point de l'arc ni des mains dans le carré de 8 %% autour du réticule : arc %d, mains %d)" % [me["arc"], me["mains"]])
	_verif(pg[1] >= 0.53 and pg[1] <= 0.62, "visée 1re personne : poing sous le repose-flèche, la cible au-dessus reste visible (haut du poing à %d %% de la hauteur)" % roundi(pg[1] * 100.0))
	_verif(r3["fut_arc"] < 0.01, "visée 1re personne : la flèche repose sur l'arc (fût à %.1f mm du flanc de la poignée)" % (r3["fut_arc"] * 1000.0))
	_verif(r3["allonge"] <= 1.0 + 1e-4 and r3["z_encoche"] <= float(ArcModele.infos()["encoche_pleine_z"]) + 1e-4 and absf(r3["echelle_fleche"] - ArcJoueur.ECHELLE_ARC_VM) < 0.001,
		"visée 1re personne : allonge %.2f au plus celle du modèle (encoche à %.3f), flèche ni corde étirées" % [r3["allonge"], r3["z_encoche"]])
	_verif(String(r3["corde"]) == "", "visée 1re personne : corde en 2 segments droits finissant aux bouts de branche, à pleine tension %s" % r3["corde"])
	var corde_tir := _corde(arc._vm)
	_verif(corde_tir == "" and arc._vm.claque_en_cours(), "au lâcher : la corde claque en restant droite entre les bouts de branche %s" % corde_tir)
	_verif(absf(r3["echelle"] - ArcJoueur.ECHELLE_ARC_VM) < 0.001, "visée 1re personne : l'arc garde son échelle (%.2f)" % r3["echelle"])
	_verif(ec.x > 0.0 and ec.y < 0.0 and ec.z > -0.1 and absf(ec.x / ec.z) > 1.2, "visée 1re personne : encoche à la joue droite, hors du champ (%.2f, %.2f, %.2f)" % [ec.x, ec.y, ec.z])
	await _sim(1.2)
	var dern: Dictionary = cible.coups[-1] if cible.coups.size() > 0 else {}
	_verif(cible.coups.size() == n_coups + 1 and is_instance_valid(p_plein) and absf(float(dern.get("degats", -1.0)) - p_plein.degats_impact) < 0.01
		and p_plein.vitesse_impact < v_plein and absf(p_plein.degats_impact - p_plein.degats_pour(p_plein.vitesse_impact)) < 0.01,
		"la flèche pleine touche le mannequin : %.1f dégâts à l'impact (%.1f m/s, partie à %.0f)" % [p_plein.degats_impact if is_instance_valid(p_plein) else -1.0, p_plein.vitesse_impact if is_instance_valid(p_plein) else -1.0, v_plein])
	_verif(is_instance_valid(p_plein) and p_plein.plantee and p_plein.get_parent() == cible, "la flèche reste fichée dans le mannequin (elle suit le corps)")
	_verif(absf(j.camera.fov - fov0) < 0.2 and arc.etat == ArcJoueur.REPOS, "zoom rendu après le tir (fov %.1f)" % j.camera.fov)
	await _physique()
	# flèche plantée récupérable (on vise le mur de gauche)
	ArcJoueur._r["fleche_recuperable"] = 1.0
	j.global_position = Vector3.ZERO
	j.rotation.y = PI * 0.5
	j.tete.rotation.x = 0.0
	await _sim(0.2)
	var n1: int = j.inventaire.nombre("fleche")
	arc.appuyer()
	await _sim(0.8)
	arc.relacher()
	await _sim(1.0)
	var p: Projectile = arc.dernier_tir["projectile"]
	var plantee := is_instance_valid(p) and p.plantee
	_verif(plantee and j.inventaire.nombre("fleche") == n1 - 1, "flèche tirée sur le mur : fichée, une de moins au sac (%d)" % j.inventaire.nombre("fleche"))
	if plantee:
		j.global_position = p.global_position + Vector3(0.9, 0, 0.0)
		await _sim(0.4)
		_verif(j.inventaire.nombre("fleche") == n1 and not is_instance_valid(p), "flèche ramassée en passant dessus (%d au sac)" % j.inventaire.nombre("fleche"))
	# tremblement
	j.global_position = Vector3.ZERO
	var r5 := await _tirer(5.6)
	_verif(r5["tremblement"] > 0.5 and r5["parti"], "pleine tension tenue 5,6 s : les bras tremblent (%.0f %%)" % (r5["tremblement"] * 100.0))
	await _sim(1.0)
	# troisième personne
	j.global_position = Vector3(0, 0, 0)
	j.basculer_vue(true)
	await _sim(0.3)
	_verif(arc._tp.visible and not arc._rig.visible, "troisième personne : arc tenu par le corps, celui de la caméra caché")
	_verif(arc._ik_corps.size() == 2 and arc._ik_corps[0].active, "troisième personne : IK du bras gauche du corps sur la poignée")
	arc.appuyer()
	await _sim(1.1)
	var sq: Skeleton3D = arc._sq_corps
	var mes := [INF, INF, false]   # main gauche -> poignée, main droite -> encoche, mesuré (après les modificateurs du squelette)
	var mesurer := func() -> void:
		var mg: Vector3 = sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_l")).origin
		var md: Vector3 = sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
		mes[0] = mg.distance_to(arc._tp.global_position)
		mes[1] = md.distance_to(arc._tp.encoche_monde())
		mes[2] = true
	sq.skeleton_updated.connect(mesurer, CONNECT_ONE_SHOT)
	await _sim(0.1)
	_verif(mes[2] and mes[0] < 0.14 and mes[1] < 0.14, "troisième personne, arc bandé : main gauche à %.2f m de la poignée, main droite à %.2f m de l'encoche" % [mes[0], mes[1]])
	_verif(arc.clip_tps() == "Pistol_Aim_Neutral" and absf(arc.lacet_tps()) > 0.5, "troisième personne : clip d'archer, buste de profil (lacet %.2f rad)" % arc.lacet_tps())
	arc.relacher()
	await _sim(0.8)
	_verif(arc.tirs > 0 and arc.dernier_tir.get("tension", 0.0) > 0.9, "troisième personne : flèche partie")
	j.basculer_vue(false)
	# rangement
	arc.ranger()
	_verif(not arc.actif and j.mains._peut_agir() and j.mains.visible, "arc rangé : l'épée reprend la main")
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

## Balistique des flèches du joueur, avec le vrai arc (tirs sur le sol dégagé, sur une palissade fine).
func _physique() -> void:
	cible.position = Vector3(30, 0, 30)   # mannequin hors du chemin
	s.mur.position = Vector3(-30, 1.3, 30)
	j.global_position = Vector3(0, 0, 4)
	j.rotation.y = 0.0
	await _sim(0.3)
	# portée : même visée légèrement plongeante, tensions croissantes -> impacts au sol de plus en plus loin
	var portees: Array[float] = []
	var nez_ok := true
	var nez_max := 0.0
	for tenu in [0.13, 0.35, 1.2]:
		j.tete.rotation.x = deg_to_rad(-3.0)
		await _sim(0.7)
		await _tirer(tenu, false)
		var p: Projectile = arc.dernier_tir["projectile"]
		var depart: Vector3 = arc.dernier_tir["depart"]
		for k in 90:
			await _sim(DT)
			if not is_instance_valid(p) or p.plantee:
				break
			if p.vitesse.length() > 1.0:
				var ang := (-p.global_transform.basis.z).angle_to(p.vitesse)
				nez_max = maxf(nez_max, ang)
				nez_ok = nez_ok and ang < deg_to_rad(2.0)
		portees.append(Vector2(p.point_impact.x - depart.x, p.point_impact.z - depart.z).length() if is_instance_valid(p) and p.plantee else -1.0)
	_verif(portees[0] > 0.0 and portees[0] < portees[1] and portees[1] < portees[2], "portée croissante avec la tension : %.1f m, %.1f m, %.1f m (visée -3°)" % portees)
	_verif(nez_ok, "en vol, le nez de la flèche suit sa vitesse (écart max %.2f°)" % rad_to_deg(nez_max))
	var p_lob: Projectile = arc.dernier_tir["projectile"]
	# palissade de 2 cm à 6 m : à pleine vitesse la flèche s'y fiche (raycast entre deux images), sans la traverser
	var pal := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 3.0, 0.02)
	f.shape = bs
	pal.add_child(f)
	s.add_child(pal)
	pal.global_position = Vector3(0, 1.5, -2.0)
	await _sim(0.7)
	await _viser_point(Vector3(0, 1.5, -2.0))
	var rp := await _tirer(1.2, false)
	var p2: Projectile = arc.dernier_tir["projectile"]
	await _sim(0.4)
	var ok_pal: bool = rp["parti"] and is_instance_valid(p2) and p2.plantee and absf(p2.point_impact.z - (-1.99)) < 0.02
	var dz := p2.global_position.z if is_instance_valid(p2) else 0.0
	_verif(ok_pal and dz > -2.0 - 0.3, "palissade de 2 cm à pleine vitesse (%.0f m/s, %.2f m par image) : flèche fichée à z %.2f, pointe à z %.2f (pas de traversée)"
		% [arc.dernier_tir["vitesse"], float(arc.dernier_tir["vitesse"]) / 60.0, p2.point_impact.z if is_instance_valid(p2) else 99.0, dz])
	if is_instance_valid(p2):
		_verif((-p2.global_transform.basis.z).angle_to(p2.dir_impact) < deg_to_rad(1.0), "flèche plantée à l'angle de son vol (écart %.2f°)" % rad_to_deg((-p2.global_transform.basis.z).angle_to(p2.dir_impact)))
	_verif(is_instance_valid(p_lob) and p_lob.plantee and p_lob.dir_impact.y < -0.05 and (-p_lob.global_transform.basis.z).y < -0.05,
		"tir plongeant : la flèche se fiche dans le sol le nez en bas (pente %.0f°)" % (rad_to_deg(asin(clampf(-p_lob.dir_impact.y, -1.0, 1.0))) if is_instance_valid(p_lob) else 0.0))
	var d1 := Projectile.new()
	d1.degats = 36.0
	d1.vitesse_reference = 46.0
	_verif(d1.degats_pour(46.0) > d1.degats_pour(30.0) * 2.0 and d1.degats_pour(10.0) >= d1.degats_min, "dégâts selon la vitesse d'impact : %.1f à 46 m/s, %.1f à 30, %.1f à 10" % [d1.degats_pour(46.0), d1.degats_pour(30.0), d1.degats_pour(10.0)])
	d1.free()
	pal.queue_free()
	cible.position = Vector3(0, 0, -9)
	s.mur.position = Vector3(-3.2, 1.3, 1.0)
	await _sim(0.2)
