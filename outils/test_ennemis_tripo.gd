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
	var sqa := EnnemisNordiques.squelette({"type": "squelette", "ident": "sq_anc", "modele_ancien": true})
	ok(not sqa.has_meta("tripo_ennemi"), "modele_ancien : ancien SqueletteGuerrier")
	sqa.free()
	ModelesTripo.relire(["--modeles-anciens=ennemis,gobelin"])
	ok(not EnnemiTripo.actif() and not EnnemiTripo.gobelin_actif() and ModelesTripo.actif("gardes") and ModelesTripo.actif("jarl"), "--modeles-anciens=ennemis,gobelin : seulement ces groupes")
	var anc2 := EnnemisNordiques.creer({"type": "guerrier", "ident": "g_anc2", "apparence": app_d})
	ok(anc2 != null and not anc2.has_meta("tripo_ennemi"), "--modeles-anciens=ennemis : ancien corps sans option")
	if anc2:
		anc2.free()
	ModelesTripo.relire(["--modeles-anciens"])
	ok(not ModelesTripo.actif("gardes") and not ModelesTripo.actif("jarl") and not EnnemiTripo.actif(), "--modeles-anciens : tous les groupes")
	ok(not ModelesTripo.actif("mage") and not ModelesTripo.actif("puits") and not ModelesTripo.actif("maison"), "--modeles-anciens : aussi mage, puits, auberge h2 (lot 2)")
	ModelesTripo.relire(["--modeles-anciens=puits"])
	ok(not ModelesTripo.actif("puits") and ModelesTripo.actif("mage") and ModelesTripo.actif("maison") and ModelesTripo.actif("gardes"), "--modeles-anciens=puits : seulement le puits")
	ModelesTripo.relire()
	ok(EnnemiTripo.actif() and ModelesTripo.actif("gardes"), "arguments réels relus : Tripo par défaut")
	# lot 2 : actifs par défaut, garde en armure dorée (halle_e) à côté des gardes Tripo
	ok(PuitsTripo.actif and MaisonTripo.actif and MageTripo.pnj_actif() and not MageTripo.actif(), "lot 2 par défaut : puits, auberge h2, PNJ mage (mages ennemis inchangés)")
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
	var md := GardesVillage.creer_modele(dore)
	ok(md != null and md.name == "GardeDore", "halle_e : corps en armure dorée par défaut")
	if md:
		md.free()
	var dore_anc := dore.duplicate()
	dore_anc["modele_ancien"] = true
	var mda := GardesVillage.creer_modele(dore_anc)
	ok(mda != null and mda.name != "GardeDore", "halle_e + modele_ancien : ancien Gardien")
	if mda:
		mda.free()
	print("RESULTAT : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
