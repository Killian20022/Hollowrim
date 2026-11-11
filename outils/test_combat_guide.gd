extends SceneTree
## Test sans fenêtre : premier combat guidé (bloquer → frapper → coup puissant → se soigner, une seule fois, sautable, sauvegardé) et bulles
## des nouvelles mécaniques (vol vu, prime, sommeil, serrure, rang de faction), touches lues dans la configuration des contrôles.
##   godot --headless --path . --script res://outils/test_combat_guide.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var a: Aides
var d: CharacterBody3D
var bon := true

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	bon = bon and ok

func _remise() -> void:
	a.vues = {}
	a._file.clear()
	a._cle = ""
	a._repit = 0.0
	a._g_t = 0.0
	a._g_faits = {}

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 20:
		await process_frame
	a = m.aides
	d = a.guide_cible
	_verif(a.crime != null and a.rangs != null and a.cycle != null, "aides branchées sur crime, rangs et cycle")
	var j = m.joueur
	Touches.charger()

	print("1. Textes et touches de la configuration")
	for cle in a.TEXTES:
		_verif(a.texte_de(cle).length() > 20 and not a.texte_de(cle).contains("{"), "texte « %s » complet, sans jeton restant" % cle)
	for cle in a.GUIDE:
		_verif(a.texte_de(cle).length() > 20 and not a.texte_de(cle).contains("{"), "bulle du guide « %s » complète, sans jeton restant" % cle)
	for cle in ["vol", "prime", "sommeil", "crochetage", "rang"]:
		_verif(a.TEXTES.has(cle), "nouvelle bulle « %s »" % cle)
	_verif(a.texte_de("guide_soin").contains(Touches.libelles("inventaire")), "la bulle de soin affiche la touche du sac (%s)" % Touches.libelles("inventaire"))
	var avant: Array = (Touches.liaisons["inventaire"] as Array).duplicate()
	Touches.liaisons["inventaire"] = [KEY_X, KEY_NONE]
	_verif(a.texte_de("guide_soin").contains("X"), "touche du sac remappée sur X : la bulle suit")
	Touches.liaisons["inventaire"] = avant
	_verif(a.passer_de().contains(Touches.libelles("aide")), "« passer » affiche la touche d'aide (%s)" % Touches.libelles("aide"))
	for cle in a.GUIDE:
		_verif(a.texte_de(cle).length() <= 125, "bulle du guide « %s » compacte (%d caractères)" % [cle, a.texte_de(cle).length()])
	var t_att := a.texte_de("sommeil")
	_verif(t_att.contains(Touches.libelle("attendre")), "le sommeil affiche la touche d'attente (%s)" % Touches.libelle("attendre"))

	print("2. Premier combat guidé")
	_verif(d != null and d.has_method("differer_geste_annonce"), "le rôdeur isolé (monde.sbire) est branché sur le guide")
	var c: EtatCombat = j.mains.combat
	_remise()
	d.etat = d.GARDE
	j.global_position = d.global_position + Vector3(0, 0, 6)
	j.vie = j.vie_max
	a._sonder()
	_verif(a.cle_courante() == "", "draugr paisible : aucune bulle")
	d._cd_lourd = -1.0
	a._retenir_geste()
	_verif(d._cd_lourd >= 4.9, "tant que la leçon n'est pas faite, le geste rouge est retenu")
	d.etat = d.TRAQUE
	a._sonder()
	_verif(a.cle_courante() == "guide_garde" and a.vues.has("guide_garde"), "il marche sur le joueur → bulle « bloquer »")
	_verif(a.vues.has("ennemi") and not a._file.has("ennemi"), "pas de doublon avec la bulle « Premier combat »")
	m.hud._cible = d
	m.hud._a_cible = 3.0
	a._sonder()
	_verif(not a._file.has("ennemi"), "cible = draugr de la leçon : pas de bulle « ennemi » en file")
	m.hud._cible = null
	for i in 8:
		a._sonder()
	_verif(a.cle_courante() == "guide_garde", "sans garde levée, la bulle reste (2 s)")
	var t_avant: float = a._t
	a._t = 9.0
	_verif(a.alpha() > 0.9 and a.DUREE_GUIDE > a.DUREE, "une bulle du guide tient plus longtemps qu'une bulle ordinaire (%.0f s)" % a.DUREE_GUIDE)
	a._t = t_avant
	c.forcer(EtatCombat.GARDE)
	a._sonder()
	_verif(a.cle_courante() == "guide_frappe", "garde levée → bulle « frapper »")
	c.forcer(EtatCombat.REPOS)
	a._sonder()
	_verif(a.cle_courante() == "guide_frappe", "sans coup donné, « frapper » reste")
	c.forcer(EtatCombat.ATTAQUE_LEGERE)
	a._sonder()
	c.forcer(EtatCombat.REPOS)
	_verif(a.cle_courante() == "guide_puissant", "coup léger donné → bulle « coup puissant »")
	c.forcer(EtatCombat.ATTAQUE_LEGERE)
	c.forcer(EtatCombat.CHARGE_LOURDE)
	a._sonder()
	c.forcer(EtatCombat.REPOS)
	_verif(a._t >= a.DUREE_GUIDE - 0.61 and not a.vues.has("guide_soin"), "coup puissant donné → la bulle se retire ; pleine vie : pas encore de soin")
	_verif(d._cd_lourd >= 4.9, "leçon pas finie : geste rouge toujours retenu")
	a._cle = ""
	j.vie = j.vie_max * 0.45
	a._sonder()
	_verif(a.cle_courante() == "guide_soin", "vie sous 60 % → bulle « se soigner »")
	a._sonder()
	_verif(a.cle_courante() == "guide_soin" and a._t < a.DUREE_GUIDE - 1.0, "sans soin, la bulle reste")
	j.soigner(25.0)
	a._sonder()
	_verif(a._t >= a.DUREE_GUIDE - 0.61, "vie remontée → la bulle se retire")
	var ancien: int = a.vues.size()
	a._cle = ""
	for i in 3:
		a._sonder()
	_verif(a.cle_courante() == "" and a.vues.size() == ancien, "la leçon ne revient pas")
	var sauve: Array = a.exporter()
	_verif(sauve.has("guide_garde") and sauve.has("guide_frappe") and sauve.has("guide_puissant") and sauve.has("guide_soin"), "étapes sauvegardées avec les autres aides")
	a.vues = {}
	a.importer(JSON.parse_string(JSON.stringify(sauve)))
	a._sonder()
	_verif(a.cle_courante() == "", "partie relue : plus de leçon")
	d._cd_lourd = 0.0
	a._retenir_geste()
	_verif(d._cd_lourd <= 0.0, "leçon faite : le draugr redevient normal")

	print("3. Délais, leçon sautable, option, vétéran, draugr tombé")
	_remise()
	j.vie = j.vie_max
	d.etat = d.TRAQUE
	a._sonder()
	for i in 41:
		a._sonder()
	_verif(a.cle_courante() == "guide_frappe", "sans garde levée, « frapper » vient au bout de %.0f s" % a.DELAI_ETAPE)
	a.passer_guide()
	_verif(a.cle_courante() == "" and a.vues.has("guide_puissant") and a.vues.has("guide_soin"), "passer : la bulle et la suite sont écartées")
	_remise()
	Jeu.options["jeu"]["aides"] = false
	a._sonder()
	_verif(a.cle_courante() == "", "option « Bulles d'aide » désactivée : pas de leçon")
	Jeu.options["jeu"]["aides"] = true
	_remise()
	a.tout_vu()
	a._sonder()
	_verif(a.cle_courante() == "", "ancienne sauvegarde : pas de leçon")
	_remise()
	d.etat = d.TRAQUE
	a._sonder()
	var cle_tuee: String = a.cle_courante()
	d.etat = d.MORT
	a._sonder()
	_verif(cle_tuee == "guide_garde" and a.vues.has("guide_soin") and a.cle_courante() == "", "draugr tué sans une égratignure : la leçon se termine")
	_remise()
	d.etat = d.TRAQUE
	a._sonder()
	d.etat = d.MORT
	j.vie = j.vie_max * 0.8
	a._sonder()
	_verif(a.cle_courante() == "guide_soin", "draugr tué mais joueur blessé : bulle « se soigner »")
	d.etat = d.TRAQUE
	j.vie = j.vie_max

	print("4. Bulles des mécaniques")
	_remise()
	m.crime.crime_commis.emit("vol", "skarnholt", 1)
	_verif(a._file.has("vol") and a._file.has("prime"), "vol vu → bulles « vol vu » et « prime »")
	_remise()
	m.crime.crime_commis.emit("agression", "skarnholt", 1)
	_verif(a._file.has("prime") and not a._file.has("vol"), "autre crime vu → « prime » seule")
	_remise()
	m.rangs.rang_change.emit("garde", 0)
	_verif(a._file.has("rang"), "rang de faction gagné → bulle")
	m.rangs.rang_change.emit("garde", -1)
	_remise()
	m.rangs.rang_change.emit("garde", -1)
	_verif(not a._file.has("rang"), "rang perdu ou exclusion → pas de bulle")
	_remise()
	var h0: float = m.cycle.heure
	m.cycle.heure = 23.0
	a._sonder()
	_verif(a._file.has("sommeil"), "nuit avancée → bulle « repos »")
	m.cycle.heure = h0
	_remise()
	var fausse := GDScript.new()
	fausse.source_code = "extends Control\nvar p: Node3D\nfunc invite_courante():\n\treturn p\n"
	fausse.reload()
	var dlg := Control.new()
	dlg.set_script(fausse)
	var porte := Node3D.new()
	porte.set_meta("verrou", 2)
	dlg.p = porte
	var vieux_dialogue = a.dialogue
	a.dialogue = dlg
	a._sonder()
	_verif(a._file.has("crochetage"), "invite d'une serrure → bulle « serrure »")
	a.dialogue = vieux_dialogue
	_remise()
	_verif(a.proposer("vol") and not a.proposer("vol"), "une bulle ne se met pas deux fois en file")
	a.vues["vol"] = true
	_verif(not a.proposer("vol"), "déjà vue : jamais revue")
	a.tout_vu()
	for cle in ["vol", "prime", "sommeil", "crochetage", "rang"]:
		_verif(a.vues.has(cle), "ancienne sauvegarde : « %s » considérée vue" % cle)

	print("TEST COMBAT GUIDE : ", "OK" if bon else "ÉCHEC")
	quit()
