extends SceneTree
## Test sans fenêtre des ennemis Tripo (scripts/ennemi_tripo.gd) : chaque corps est créé, 65 os, clips de l'IA, budget de triangles, arme en main
## (BoneAttachment hand_r), matériau PS1, échelle ; le gobelin fait ~1,2 m ; EnnemisNordiques et squelette() les renvoient PAR DÉFAUT ;
## anciens corps : option modele_ancien, zombie, --modeles-anciens[=groupes] (ModelesTripo).
##   godot --headless --path . --script res://outils/test_ennemis_tripo.gd -- --nouvelle
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01", "Pistol_Aim_Neutral", "Pistol_Shoot"]
var echecs := 0

func ok(c: bool, msg: String) -> void:
	print(("OK     " if c else "ECHEC  ") + msg)
	if not c:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _hauteur(n: Node3D, sq: Skeleton3D) -> float:
	var h := 0.0
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		h = maxf(h, mi.get_aabb().end.y)
	return h * n.scale.y

func _lancer() -> void:
	ok(EnnemiTripo.actif(), "modèles Tripo des ennemis actifs par défaut (sans --modeles-anciens)")
	var cas := [["draugr", "epee"], ["draugr", "hache"], ["archer", "arc"], ["squelette", "epee"], ["squelette", "hache"], ["gobelin", "epee_courte"]]
	for c: Array in cas:
		var n := EnnemiTripo.creer(c[0], c[1])
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sq != null and sq.get_bone_count() == 65, "%s/%s : 65 os (%d)" % [c[0], c[1], sq.get_bone_count()])
		var ap := n.get_node("Animations") as AnimationPlayer
		var manque: Array = []
		for a: String in ANIMS:
			if not ap.has_animation(a):
				manque.append(a)
		ok(manque.is_empty(), "%s/%s : clips de l'IA présents %s" % [c[0], c[1], manque])
		var t := _tris(n)
		ok(t < 9500, "%s/%s : %d triangles" % [c[0], c[1], t])
		ok(n.has_meta("armes_nordiques"), "%s : arme posée (méta)" % c[0])
		if c[1] != "arc":
			ok(sq.get_node_or_null("Arme") != null, "%s/%s : arme en main (hand_r)" % [c[0], c[1]])
		var h := _hauteur(n, sq)
		print("       hauteur du maillage : %.2f m, échelle méta %s" % [h, n.get_meta("echelle_tripo", 1.0)])
		var ech: float = n.get_meta("echelle_tripo", 1.0)
		ok((h * ech > 1.1 and h * ech < 1.35) if c[0] == "gobelin" else (h > 1.7 and h < 2.0), "%s : taille cohérente (%.2f m)" % [c[0], h * ech])
		ap.play("Walk")
		ap.advance(0.4)
		n.queue_free()
	# intégration : spec EnnemisNordiques (draugr, archer) et squelette
	for sp: Dictionary in [{"type": "guerrier", "ident": "g0", "apparence": {"corps": "homme", "draugr": true, "tenue": {}}}, {"type": "sbire", "archer": true, "ident": "s2", "apparence": {"corps": "homme", "draugr": true, "tenue": {}}}]:
		var n := EnnemisNordiques.creer(sp)
		ok(n != null and n.has_meta("tripo_ennemi") and n.has_meta("draugr_nordique"), "EnnemisNordiques.creer(%s) -> corps Tripo %s" % [sp["ident"], n.get_meta("variante", "")])
		if n:
			n.free()
	var sqn := EnnemisNordiques.squelette({"type": "squelette", "ident": "sq1"})
	ok(sqn.has_meta("tripo_ennemi"), "EnnemisNordiques.squelette -> corps Tripo (%s)" % sqn.get_meta("variante", ""))
	sqn.free()
	await _archer_squelette()
	# anciens corps toujours chargeables (factions) : option « modele_ancien », zombie, et --modeles-anciens[=groupes] (ModelesTripo)
	var app_d := {"corps": "homme", "draugr": true, "tenue": {}}
	var anc := EnnemisNordiques.creer({"type": "guerrier", "ident": "g_anc", "apparence": app_d, "modele_ancien": true})
	ok(anc != null and not anc.has_meta("tripo_ennemi") and anc.has_meta("draugr_nordique"), "modele_ancien : ancien corps DraugrNordique (%s)" % (anc.get_meta("variante", "") if anc else "null"))
	if anc:
		anc.free()
	var zb := EnnemisNordiques.creer({"type": "sbire", "ident": "z0", "apparence": app_d, "zombie": true})
	ok(zb != null and not zb.has_meta("tripo_ennemi"), "draugr zombie : garde l'ancien corps (mains nues)")
	if zb:
		zb.free()
	# boss jarl gelé (docs/ARMURES_TRIPO.md) : corps draugr Tripo + couronne ; Svanhild garde l'ancien corps ; modele_ancien le rend
	var jt := EnnemisNordiques.creer({"type": "guerrier", "boss": "jarl", "ident": "jarl_t", "apparence": app_d})
	var jsq: Skeleton3D = jt.find_child("Skeleton3D", true, false) if jt else null
	ok(jt != null and String(jt.get_meta("tripo_ennemi", "")) == "draugr" and jsq.get_node_or_null("Couronne") != null and jsq.get_node_or_null("CapeRoyale") == null, "boss jarl : draugr Tripo couronné (%s)" % (jt.get_meta("variante", "") if jt else "null"))
	# copie d'un gabarit : l'aplomb de l'arme est relié à la copie (sinon lame du clip, de travers)
	var apl: Node = jsq.get_node_or_null("Arme/Aplomb") if jsq else null
	ok(apl != null and apl.get("ap") == jt.get_node("Animations") and apl.get("sq") == jsq and apl.get("arme") != null, "boss jarl : aplomb de l'épée relié à la copie")
	if jt:
		jt.free()
	var ja := EnnemisNordiques.creer({"type": "guerrier", "boss": "jarl", "ident": "jarl_a", "apparence": app_d, "modele_ancien": true})
	ok(ja != null and not ja.has_meta("tripo_ennemi") and String(ja.get_meta("variante", "")) == "boss_jarl", "boss jarl modele_ancien : ancien DraugrNordique (%s)" % (ja.get_meta("variante", "") if ja else "null"))
	if ja:
		ja.free()
	var sv := EnnemisNordiques.creer({"type": "guerrier", "boss": "svanhild", "ident": "sv_t", "apparence": app_d})
	ok(sv != null and not sv.has_meta("tripo_ennemi"), "boss svanhild : ancien corps (femme)")
	if sv:
		sv.free()
	var sqa := EnnemisNordiques.squelette({"type": "squelette", "ident": "sq_anc", "modele_ancien": true})
	ok(not sqa.has_meta("tripo_ennemi"), "modele_ancien : ancien SqueletteGuerrier")
	sqa.free()
	ModelesTripo.relire(["--modeles-anciens=ennemis,gobelin"])
	ok(not EnnemiTripo.actif() and not EnnemiTripo.gobelin_actif() and ModelesTripo.actif("gardes") and ModelesTripo.actif("jarl"), "--modeles-anciens=ennemis,gobelin : seulement ces groupes")
	var anc2 := EnnemisNordiques.creer({"type": "guerrier", "ident": "g_anc2", "apparence": app_d})
	ok(anc2 != null and not anc2.has_meta("tripo_ennemi"), "--modeles-anciens=ennemis : ancien corps sans option")
	if anc2:
		anc2.free()
	var ja2 := EnnemisNordiques.creer({"type": "guerrier", "boss": "jarl", "ident": "jarl_a2", "apparence": app_d})
	ok(ja2 != null and not ja2.has_meta("tripo_ennemi"), "--modeles-anciens=ennemis : boss jarl sur l'ancien corps")
	if ja2:
		ja2.free()
	ModelesTripo.relire(["--modeles-anciens"])
	ok(not ModelesTripo.actif("gardes") and not ModelesTripo.actif("jarl") and not EnnemiTripo.actif(), "--modeles-anciens : tous les groupes")
	ok(not ModelesTripo.actif("mage") and not ModelesTripo.actif("puits") and not ModelesTripo.actif("maison"), "--modeles-anciens : aussi mage, puits, auberge h2 (lot 2)")
	ModelesTripo.relire(["--modeles-anciens=puits"])
	ok(not ModelesTripo.actif("puits") and ModelesTripo.actif("mage") and ModelesTripo.actif("gardes"), "--modeles-anciens=puits : seulement le puits")
	ModelesTripo.relire()
	ok(EnnemiTripo.actif() and ModelesTripo.actif("gardes"), "arguments réels relus : Tripo par défaut")
	# lot 2 : actifs par défaut, garde en armure dorée (halle_e) à côté des gardes Tripo
	ok(PuitsTripo.actif and not MaisonTripo.actif and MageTripo.pnj_actif() and not MageTripo.actif(), "lot 2 par défaut : puits, PNJ mage (auberge h2 Tripo retirée, mages ennemis inchangés)")
	var VILL: Script = load("res://scripts/villageois.gd")
	var hab_essai: Array = VILL.habitants_essai()
	var mage_hab := false
	for h: Dictionary in hab_essai:
		mage_hab = mage_hab or String(h.get("pnj", "")) == "tripo_mage"
	ok(mage_hab and hab_essai.size() == 1, "habitants en plus par défaut : le seul Mage Eirwen")
	var dore := {}
	for g: Dictionary in GardesVillage.donnees()["gardes"]:
		if g.get("armure_tripo", false):
			dore = g
	ok(String(dore.get("id", "")) == "halle_e" and not GardesVillage.GARDES_TRIPO.has("halle_e"), "armure dorée sur halle_e, hors des trois gardes Tripo")
	# 2026-11-11 : armures Tripo des gardes abandonnées, défaut = armure maison (GardeMaison) ; l'armure dorée Tripo reste chargeable
	var mdm := GardesVillage.creer_modele(dore)
	ok(mdm != null and GardeMaison.pieces_portees(mdm).has("cuirasse_acier_nordique"), "halle_e : acier nordique maison par défaut (l'or est réservé au joueur, 8b47f722)")
	if mdm:
		mdm.free()
	var md := GardesVillage.creer_modele_dore(dore)
	ok(md != null and md.name == "GardeDore", "halle_e : armure dorée Tripo toujours chargeable (--gardes-armures-tripo)")
	if md:
		md.free()
	var dore_anc := dore.duplicate()
	dore_anc["modele_ancien"] = true
	var mda := GardesVillage.creer_modele(dore_anc)
	ok(mda != null and mda.name != "GardeDore", "halle_e + modele_ancien : ancien Gardien")
	if mda:
		mda.free()
	# armure de verre Tripo (garde n_e) : corps GardeTripo « tripo_garde_verre » par défaut, épée en main, ancien Gardien avec modele_ancien
	var verre := {}
	for g: Dictionary in GardesVillage.donnees()["gardes"]:
		if g.get("armure_verre", false):
			verre = g
	ok(String(verre.get("id", "")) == "n_e" and not verre.get("armure_tripo", false) and not GardesVillage.GARDES_TRIPO.has("n_e"), "armure de verre sur n_e, seule")
	var mvm := GardesVillage.creer_modele(verre)
	ok(mvm != null and GardeMaison.pieces_portees(mvm).has("cuirasse_acier_nordique"), "n_e : acier nordique maison par défaut (le verre est réservé au joueur, 8b47f722)")
	if mvm:
		mvm.free()
	var mv := GardeTripo.creer("tripo_garde_verre")
	ok(mv != null and String(mv.get_meta("pnj_nordique", "")) == "tripo_garde_verre", "n_e : armure de verre Tripo toujours chargeable (--gardes-armures-tripo)")
	if mv:
		var sqv := mv.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sqv != null and sqv.find_bone("tab_f_1") >= 0 and sqv.find_bone("hand_r") >= 0, "armure de verre : squelette des gardes + tabard")
		ok(mv.find_child("EpeeJeu", true, false) != null, "armure de verre : épée tenue")
		var tris := 0
		for mi: MeshInstance3D in sqv.find_children("*", "MeshInstance3D", false, false):
			for si in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		ok(tris > 4000 and tris < 9000, "armure de verre : %d triangles (4 000..9 000)" % tris)
		mv.free()
	var verre_anc := verre.duplicate()
	verre_anc["modele_ancien"] = true
	var mva := GardesVillage.creer_modele(verre_anc)
	ok(mva != null and not mva.has_meta("pnj_nordique"), "n_e + modele_ancien : ancien Gardien")
	if mva:
		mva.free()
	print("RESULTAT : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)

## Sommets (repos) d'un maillage dont le poids sur `os_nom` est >= 0,5, dans le repère de repos de l'os.
func _pts_os(sq: Skeleton3D, mi: MeshInstance3D, os_nom: String) -> Array[Vector3]:
	var r: Array[Vector3] = []
	var inv := sq.get_bone_global_rest(sq.find_bone(os_nom)).affine_inverse()
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var k := b.size() / maxi(v.size(), 1)
		for i in v.size():
			var p := 0.0
			for q in k:
				var nom: String = mi.skin.get_bind_name(b[i * k + q]) if mi.skin.get_bind_name(b[i * k + q]) != "" else sq.get_bone_name(mi.skin.get_bind_bone(b[i * k + q]))
				if nom == os_nom:
					p += w[i * k + q]
			if p >= 0.5:
				r.append(inv * (mi.transform * v[i]))
	return r

func _plus_pres(p: Vector3, pts: Array[Vector3]) -> float:
	var d := INF
	for q in pts:
		d = minf(d, p.distance_to(q))
	return d

## Archer squelette : corps Tripo, arc du jeu des archers (porté / bandé / relâché, PoseArcher) tenu par la VRAIE main, prise mesurée ;
## dépouille (sauvegarde du butin) refaite avec le même corps.
func _archer_squelette() -> void:
	var n := EnnemisNordiques.squelette({"type": "squelette_archer", "ident": "sq_arch"})
	ok(n.has_meta("tripo_ennemi") and String(n.get_meta("variante", "")) == "squelette_arc" and not bool(n.get_meta("squelette_poings", true)), "squelette_archer : corps Tripo, variante squelette_arc, pas à mains nues")
	await _archer_tripo(n, "squelette", "squelette_archer", 9500)
	await _archer_tripo(EnnemiTripo.creer("archer", "arc"), "archer", "draugr_archer", 8000)
	var DR: GDScript = load("res://scripts/draugr.gd")
	for spec: Dictionary in [{"type": "squelette_archer", "archer": true, "ident": "sq_arch"}, {"type": "sbire", "archer": true, "ident": "dr_arch"}]:
		var dep: Node3D = DR.call("modele_depouille", spec)
		var sqd := dep.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(dep.has_meta("tripo_ennemi") and sqd.get_node_or_null("arc_porte") != null and sqd.get_node_or_null("arc") == null, "%s : dépouille / sauvegarde (spec_depouille) : même corps Tripo, même arc" % spec["type"])
		dep.free()

## Arc du jeu (ChasseresseNordique.equiper_arc) tenu par la vraie main Tripo `id` (prise EnnemiTripo.PRISE_ARC mesurée sur le maillage).
func _archer_tripo(n: Node3D, id: String, nom: String, max_tris: int) -> void:
	root.add_child(n)
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var porte := sq.get_node_or_null("arc_porte") as MeshInstance3D
	var vise := sq.get_node_or_null("arc_vise") as MeshInstance3D
	var relache := sq.get_node_or_null("arc_relache") as MeshInstance3D
	ok(porte != null and vise != null and relache != null and sq.get_node_or_null("PoseArcher") != null, "%s : arc porté / bandé / relâché + PoseArcher" % nom)
	ok(sq.get_node_or_null("arc") == null, "%s : plus l'ancien arc skinné (EnnemisNordiques._arc, horizontal en visée)" % nom)
	var t := _tris(n)
	ok(t < max_tris, "%s : %d triangles (corps + arc porté)" % [nom, t])
	if porte != null and vise != null:
		var tb: Variant = (porte.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("tex_base")
		var tv: Variant = (vise.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("tex_base")
		ok(tb != ChasseresseTextures.tex("accessoires") and tb == tv, "%s : bois de l'arc teinté pour l'ennemi (pas celui de la chasseresse)" % nom)
		var corps: MeshInstance3D = null
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			if mi.skin != null and not String(mi.name).begins_with("arc"):
				corps = mi
		var main := _pts_os(sq, corps, "hand_l")
		var paume: Vector3 = EnnemiTripo.PRISE_ARC[id]["paume_l"]
		ok(_plus_pres(paume, main) < 0.02, "%s : prise mesurée DANS la main gauche (%.1f cm du maillage)" % [nom, _plus_pres(paume, main) * 100])
		for mi: MeshInstance3D in [porte, vise]:
			var arc := _pts_os(sq, mi, "hand_l")
			var d := INF
			for q in arc:
				d = minf(d, _plus_pres(q, main))
			ok(arc.size() > 20 and d < 0.015, "%s %s : la poignée touche la main gauche (%.1f cm)" % [nom, mi.name, d * 100])
		var ap := n.get_node("Animations") as AnimationPlayer
		for c: Array in [["Idle", true, false], ["Pistol_Aim_Neutral", false, true]]:
			ap.play(String(c[0]))
			ap.advance(0.3)
			for k in 3:
				await process_frame
			ok(porte.visible == c[1] and vise.visible == c[2], "%s %s : bon arc visible (porté %s, bandé %s)" % [nom, c[0], porte.visible, vise.visible])
	n.free()
