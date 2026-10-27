extends SceneTree
## Test sans fenêtre de l'interface de combat (scripts/hud_combat.gd, scripts/icones_combat.gd) :
##   godot --headless --path . --script res://outils/test_hud_combat.gd -- --nouvelle
## 1. IconesCombat.icone() : une texture 16x16 pour les 18 ids (4 armes/objets + 14 sorts), un repli pour un id inconnu ;
##    icone_statut() : 8x8 pour les statuts connus, repli pour un nom inconnu.
## 2. HudCombat avec un joueur factice qui a le contrat de données (signal etat_mains_change, mana, charges, recharges,
##    statuts, raccourcis) : lecture correcte, double incantation, recharge en ratio, dessin sans erreur.
## 3. Joueur factice SANS ces membres (état actuel du jeu) : valeurs par défaut, repli épée / main nue.
## 4. Mode démo.

const HUD_COMBAT := preload("res://scripts/hud_combat.gd")
const IDS := ["epee", "torche", "bouclier", "vide", "jet_flammes", "boule_feu", "explosion_incendiaire", "eclat_glace",
	"lance_givre", "nova_gelee", "arc_electrique", "chaine_eclairs", "tempete_statique", "trait_ombre", "drain_vie",
	"explosion_obscure", "soin", "protection"]
const STATUTS := ["brulure", "gel", "choc", "corruption", "soin", "protection", "enchant_feu", "enchant_glace",
	"enchant_electricite", "enchant_tenebres"]
const JOUEUR_CONTRAT := """extends Node
signal etat_mains_change(gauche: Dictionary, droite: Dictionary)
var vie := 80.0
var vie_max := 100.0
var vigueur := 50.0
var vigueur_max := 100.0
var mana := 40.0
var mana_max := 120.0
var charge_gauche := 0.5
var charge_droite := 0.0
var recharges := {}
var statuts_actifs: Array = []
var raccourcis: Array = ["epee", "boule_feu", "", "", "", "", "", ""]
var raccourci_choisi := 1
"""

var _ok := true

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _hud(j: Node) -> Control:
	var ui := Control.new()
	ui.set_script(HUD_COMBAT)
	ui.joueur = j
	ui.size = Vector2(640, 360)
	root.add_child(ui)
	return ui

func _tester() -> void:
	# 1. icônes
	var tailles_ok := true
	var distinctes := {}
	for id in IDS:
		var t := IconesCombat.icone(id)
		if t == null or t.get_size() != Vector2(16, 16) or not IconesCombat.connu(id):
			tailles_ok = false
			print("  icône manquante : ", id)
		else:
			distinctes[t.get_image().get_data()] = true
	_verif(tailles_ok, "18 icônes 16x16 (armes, objets, 14 sorts)")
	_verif(distinctes.size() == IDS.size(), "les 18 icônes sont toutes différentes (%d)" % distinctes.size())
	var repli := IconesCombat.icone("sort_qui_n_existe_pas")
	_verif(repli != null and repli == IconesCombat.icone("inconnu") and not IconesCombat.connu("sort_qui_n_existe_pas"),
		"id inconnu → icône de repli")
	_verif(IconesCombat.icone("") == IconesCombat.icone("vide"), "id vide → main nue")
	var st_ok := true
	for nom in STATUTS:
		var t := IconesCombat.icone_statut(nom)
		st_ok = st_ok and t != null and t.get_size() == Vector2(8, 8) and t != IconesCombat.icone_statut("???")
	_verif(st_ok, "10 icônes de statut 8x8 + repli")
	_verif(IconesCombat.ecole_de("boule_feu") == "feu" and IconesCombat.ecole_de("drain_vie") == "tenebres"
		and IconesCombat.ecole_de("epee") == "" and IconesCombat.ecole_de("torche") == "", "école déduite des ids")

	# 2. joueur avec le contrat de données
	var sc := GDScript.new()
	sc.source_code = JOUEUR_CONTRAT
	sc.reload()
	var j := Node.new()
	j.set_script(sc)
	root.add_child(j)
	var ui := _hud(j)
	await _images(3)
	var sort := {"id": "boule_feu", "nom": "Boule de feu", "ecole": "feu", "type": "sort", "cout": 25.0}
	j.emit_signal("etat_mains_change", sort, {"id": "epee", "nom": "Épée", "type": "arme"})
	j.statuts_actifs = [{"nom": "brulure", "duree": 3.0, "duree_max": 8.0}, "protection", {"nom": "gel", "duree": 1.0, "duree_max": 5.0},
		{"nom": "inconnu_xyz"}, 42]
	j.recharges = {"droite": 2.0}
	await _images(2)
	j.recharges = {"droite": 1.0}
	await _images(2)
	_verif(ui.gauche.get("id") == "boule_feu" and ui.droite.get("id") == "epee", "signal etat_mains_change lu")
	_verif(is_equal_approx(ui._v.mana, 40.0) and is_equal_approx(ui._v.mana_max, 120.0), "mana lu")
	_verif(is_equal_approx(ui._v.charge_g, 0.5), "charge gauche lue")
	_verif(absf(ui._v.rech_d - 0.5) < 0.01, "recharge en secondes → ratio (1 s restante sur 2 = %.2f)" % ui._v.rech_d)
	_verif(ui._v.statuts.size() == 5, "statuts lus (formes mêlées tolérées)")
	_verif(ui._t_mains > 0.0 and ui._t_barre > 0.0, "mains et raccourcis affichés après un changement")
	j.recharges = {"boule_feu": {"restant": 3.0, "total": 4.0}}
	j.emit_signal("etat_mains_change", sort, sort)
	j.raccourci_choisi = 3
	await _images(3)
	_verif(absf(ui._v.rech_g - 0.75) < 0.01, "recharge par id du sort, forme {restant, total}")
	ui.queue_redraw()
	await _images(2)
	_verif(ui.nb_dessins > 0, "dessin effectué sans erreur (%d)" % ui.nb_dessins)
	ui.queue_free()
	j.queue_free()

	# 3. joueur actuel (aucun membre du contrat)
	var j2 := Node.new()
	root.add_child(j2)
	var ui2 := _hud(j2)
	await _images(3)
	_verif(is_equal_approx(ui2._v.mana, 100.0) and ui2._v.statuts.is_empty() and ui2._v.choisi == -1, "défauts sans le contrat")
	_verif(ui2.droite.get("id") == "epee" and ui2.gauche.get("id", "") == "", "repli : épée à droite, main nue à gauche")
	ui2.queue_redraw()
	await _images(2)
	_verif(ui2.nb_dessins > 0, "dessin sans le contrat")
	ui2.queue_free()
	j2.queue_free()

	# 4. démo (sans joueur)
	var ui3 := _hud(null)
	ui3.demo = true
	ui3.demo_double = true
	await _images(4)
	_verif(ui3._a_mains == 1.0 and ui3.gauche.get("id") == "boule_feu" and ui3.droite.get("id") == "boule_feu" and ui3.nb_dessins > 0,
		"mode démo (double incantation)")
	ui3.queue_free()
	await _images(2)
	IconesCombat.vider()
	print("RESULTAT : " + ("OK" if _ok else "ÉCHEC"))
	quit(0 if _ok else 1)
