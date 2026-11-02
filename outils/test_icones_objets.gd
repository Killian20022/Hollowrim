extends SceneTree
## Icônes d'objets dessinées depuis les modèles 3D (IconesObjets, atlas d'outils/generer_icones.gd) et aperçu 3D tournant des
## fiches du menu (ApercuObjet) :
##   godot --headless --path . --script res://outils/test_icones_objets.gd -- --nouvelle
## 1. atlas : TOUT objet du registre qui a un modèle 3D a son icône 16 et 32 px (non vide, contour sombre, pixels nets : alpha 0 ou 1) ;
##    sans modèle (clé de la maison, torche) : pas d'icône dessinée, l'ancienne icône pixel reste (repli) ; sorts : IconesCombat.
## 2. branchements : MenuStyle.icone_objet, LivreParchemin.icone_de (16 / 32), barre d'objets (IconesObjets.icone_main).
## 3. menu (scenes/test_combat.tscn) : Sac et Équipement montrent l'aperçu 3D de l'objet choisi (studio RenduObjet vivant, bon
##    objet), caché pour un objet sans modèle, tourne (tour lent + glisser), LIBÉRÉ quand on change d'onglet ou ferme le menu.
## Si ce test échoue après l'arrivée de nouveaux modèles : bash outils/generer_icones.sh

const SCENE := preload("res://scenes/test_combat.tscn")

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await process_frame

## Nombre de studios RenduObjet vivants dans l'arbre.
func _studios() -> int:
	return root.find_children("*", "RenduObjet", true, false).size()

func _tester() -> void:
	# --- 1. atlas
	var gen: Script = load("res://outils/generer_icones.gd")
	var ids: Array = gen.call("ids_a_rendre")
	var manquent: Array = []
	var vides: Array = []
	var floues: Array = []
	var avec_modele := 0
	for id: String in ids:
		if not ObjetMonde.a_modele(id):
			continue
		avec_modele += 1
		var t16 := IconesObjets.icone(id, 16)
		var t32 := IconesObjets.icone(id, 32)
		if t16 == null or t32 == null:
			manquent.append(id)
			continue
		if Vector2i(t16.get_size()) != Vector2i(16, 16) or Vector2i(t32.get_size()) != Vector2i(32, 32):
			vides.append(id)
			continue
		var img := t16.get_image()
		var pleins := 0
		var sombres := 0
		for y in 16:
			for x in 16:
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.a < 1.0:
					floues.append(id)
				if c.a > 0.5:
					pleins += 1
					if c.get_luminance() < 0.12:
						sombres += 1
		if pleins < 12 or sombres < 4:
			vides.append(id)
	_verif(avec_modele >= 80, "registre : %d objets avec un modèle 3D (armes, bijoux, potions, tomes, ingrédients, quête, divers…)" % avec_modele)
	_verif(manquent.is_empty(), "atlas : chaque objet à modèle a son icône 16 et 32 px (manquent : %s ; régénérer : bash outils/generer_icones.sh)" % [manquent])
	_verif(vides.is_empty(), "icônes non vides, au bon format, avec leur contour sombre (fautives : %s)" % [vides])
	_verif(floues.is_empty(), "pixels nets : alpha 0 ou 1, ni flou ni demi-teinte (fautives : %s)" % [floues.slice(0, 6)])
	var categories := {}
	for id: String in IconesObjets.ids():
		categories[Inventaire.categorie_de(id)] = true
	for c in ["arme", "bijou", "consommable", "ingredient", "quete", "divers"]:
		_verif(categories.has(c), "atlas : catégorie « %s » représentée" % c)
	_verif(IconesObjets.icone("cle_maison") == null and MenuStyle.icone_objet("cle_maison") != null,
		"objet sans modèle (clé de la maison) : pas d'icône dessinée, repli sur l'ancienne icône pixel")
	_verif(IconesObjets.icone_main("torche") == IconesCombat.icone("torche") and IconesObjets.icone_main("boule_feu") == IconesCombat.icone("boule_feu")
		and IconesObjets.icone_main("") == IconesCombat.icone("vide"), "barre : torche, sorts et main nue gardent les icônes d'IconesCombat")
	_verif(IconesObjets.icone_main("epee") == IconesObjets.icone("epee_metal") and IconesObjets.icone_main("epee") != null,
		"barre : « epee » de la main = icône de l'épée de métal (modèle 3D)")
	_verif(IconesObjets.icone("hache_guerre+2") == IconesObjets.icone("hache_guerre") and IconesObjets.icone("hache_guerre") != null,
		"objet amélioré à la forge (id+2) : icône de l'objet de base")
	# --- 2. branchements
	_verif(MenuStyle.icone_objet("epee_rubis") == IconesObjets.icone("epee_rubis", 16), "menu (Sac / Équipement / Magie) : MenuStyle.icone_objet = icône dessinée")
	_verif(MenuStyle.icone_objet("vide", true) != null and MenuStyle.icone_emplacement("tete") != null, "silhouettes pâles (emplacement vide) : toujours les motifs pixel")
	var livre := LivreParchemin.new()
	_verif(livre.icone_de("potion_soin", 16) == IconesObjets.icone("potion_soin", 16) and livre.icone_de("potion_soin", 32) == IconesObjets.icone("potion_soin", 32),
		"coffre / boutique / forge / butin (LivreParchemin) : icône 16 dans les listes, 32 dans les fiches")
	livre.free()

	# --- 3. aperçu 3D dans le menu
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _images(20)
	var j: CharacterBody3D = s.joueur
	var ui: InventaireMains = s.inventaire_ui
	var inv: Inventaire = j.inventaire
	for id in ["epee_rubis", "potion_soin", "anneau_braise", "cle_maison"]:
		inv.ajouter(id, 1)
	j.mains.magie.equiper("droite", "epee_rubis")
	_verif(_studios() == 0, "menu fermé : aucun studio 3D (coût nul)")
	ui.ouvrir("sac")
	var sac := ui.onglet("sac") as OngletSac
	sac.filtrer("tout")
	sac.choisir("anneau_braise")
	sac.queue_redraw()
	await _images(6)
	var ap: ApercuObjet = sac._apercu
	_verif(ap != null and ap.visible and ap.rendu != null and ap.rendu.id == "anneau_braise" and ap.texture == ap.rendu.get_texture(),
		"Sac : la fiche montre l'aperçu 3D de l'objet choisi (anneau de braise)")
	_verif(ap != null and ap.size == Vector2(OngletLivre.COTE_APERCU - 6.0, OngletLivre.COTE_APERCU - 6.0), "aperçu : dans le cadre de vélin de la fiche")
	var l0 := ap.rendu.lacet if ap != null and ap.rendu != null else 0.0
	await _images(20)
	_verif(ap != null and ap.rendu != null and absf(ap.rendu.lacet - l0) > 0.01, "aperçu : tourne lentement tout seul (menu en pause)")
	if ap != null and ap.rendu != null:
		var e1 := InputEventMouseButton.new()
		e1.button_index = MOUSE_BUTTON_LEFT
		e1.pressed = true
		ap._gui_input(e1)
		var mv := InputEventMouseMotion.new()
		mv.relative = Vector2(20, 0)
		var avant := ap.rendu.lacet
		ap._gui_input(mv)
		_verif(absf(ap.rendu.lacet - avant - 20 * 0.045) < 0.001 and ap.rendu.tourner == 0.0, "glisser à la souris : l'objet tourne à la main (tour automatique suspendu)")
		e1.pressed = false
		ap._gui_input(e1)
	sac.choisir("epee_rubis")
	sac.queue_redraw()
	await _images(4)
	_verif(ap.visible and ap.rendu != null and ap.rendu.id == "epee_rubis", "Sac : changer d'objet change l'aperçu (épée en rubis)")
	sac.choisir("cle_maison")
	sac.queue_redraw()
	await _images(4)
	_verif(not ap.visible, "objet sans modèle 3D (clé de la maison) : pas d'aperçu, l'icône à la place")
	sac.choisir("potion_soin")
	sac.queue_redraw()
	await _images(4)
	_verif(ap.visible and ap.rendu != null and ap.rendu.id == "potion_soin", "Sac : potion de soin en aperçu")
	ui.changer_onglet("equipement")
	var oe := ui.onglet("equipement") as OngletEquipement
	oe.sel = 3
	oe.queue_redraw()
	await _images(6)
	_verif(ap.rendu == null and not ap.is_visible_in_tree(), "changer d'onglet : l'aperçu du Sac est libéré")
	var ae: ApercuObjet = oe._apercu
	_verif(ae != null and ae.visible and ae.rendu != null and ae.rendu.id == "epee_rubis", "Équipement : la main droite (épée en rubis) en aperçu 3D")
	_verif(_studios() == 1, "un seul studio 3D vivant à la fois (%d)" % _studios())
	ui.fermer()
	await _images(4)
	_verif(_studios() == 0, "menu fermé : studios libérés (aucun SubViewport ne rend plus)")
	ui.ouvrir("sac")
	sac.choisir("anneau_braise")
	sac.queue_redraw()
	await _images(4)
	_verif(sac._apercu.visible and sac._apercu.rendu != null and sac._apercu.rendu.id == "anneau_braise", "réouverture : l'aperçu revient")
	ui.fermer()
	await _images(4)
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
