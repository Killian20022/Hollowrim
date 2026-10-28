extends SceneTree
## Test sans fenêtre du lot L7 (HUD et police des titres) :
##   godot --headless --path . --script res://outils/test_hud_l7.gd -- --nouvelle
## 1. Police des titres (MenuStyle.police_gothique : Jacquard 12 / 24, OFL) : chargée, nette (ni lissage ni sous-pixel),
##    tous les caractères des noms affichés (accents, apostrophe typographique) ; licence copiée (OFL_Jacquard.txt, LICENCES.md).
## 2. Cadre ornementé (MenuStyle.cadre_orne) : 32x32, marges 12, coins symétriques (nœud or), utilisé par MenuStyle.cadre().
## 3. Annonces centrées (hud.annonce) : affichée, fondu, durée ~2,6 s, file d'attente ; « Nouvelle quête : X » / « Quête terminée : X »
##    (avis de quetes.gd) deviennent des annonces ; un niveau de compétence aussi ; les autres avis restent en haut à gauche.
## 4. Lieux découverts : rien avant demarrer() ; annonce au premier passage seulement ; pas sous terre (écart de hauteur).
## 5. Aide des touches : visible après demarrer(), masquée par le panneau Tab, s'éteint au bout de 60 s, F1 la rallume / l'éteint.
## 6. Invite (dialogue.gd) : nom de l'objet sous « Ouvrir le coffre » ; pas de doublon quand le verbe contient déjà le nom.

const HUD := preload("res://scripts/hud.gd")
const DIALOGUE := preload("res://scripts/dialogue.gd")
const FAUX_JOUEUR := """extends CharacterBody3D
var competences := Competences.new()
var ennemi_vise: Node = null
var en_dialogue := false
var mort := false
var camera: Camera3D
var inventaire = null
"""
const FAUX_OBJET := """extends Node3D
var nom := ""
var verbe := ""
func nom_affiche() -> String:
	return nom
func texte_action() -> String:
	return verbe
"""

var _ok := 0
var _ko := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _script(source: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = source
	s.reload()
	return s

func _avancer(hud: Control, secondes: float) -> void:
	var n := ceili(secondes / 0.1)
	for i in n:
		hud._process(0.1)

func _tester() -> void:
	# --- 1. police des titres
	var textes := "Draugr ancien Gardien des Os Tertre de Svanhild Grotte des bandits Skarnholt Cercle des pierres runiques " \
		+ "Lieu découvert Nouvelle quête Quête terminée Compétences Épée Parade Athlétisme Sac Quêtes Commandes L’anneau de givre " \
		+ "Le frère d’Ylva Reliquaire Coffre givré Coffre du jarl Urne funéraire Bandelettes cousues Troll de givre Gunnhild Brodd Ægir"
	for grande in [false, true]:
		var p := MenuStyle.police_gothique(grande)
		var manque := ""
		for ch in textes:
			if ch != " " and not p.has_char(ch.unicode_at(0)):
				manque += ch
		_verif(p != null and manque == "", "police %s : tous les caractères présents (manque « %s »)" % ["Jacquard 24" if grande else "Jacquard 12", manque])
		_verif(p.antialiasing == TextServer.FONT_ANTIALIASING_NONE and p.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED \
			and p.hinting == TextServer.HINTING_NONE, "police %s : nette (ni lissage, ni sous-pixel, ni hinting)" % ("24" if grande else "12"))
	var lic := FileAccess.get_file_as_string("res://assets/LICENCES.md")
	var ofl := FileAccess.get_file_as_string("res://assets/polices/OFL_Jacquard.txt")
	_verif(lic.contains("Jacquard12-Regular.ttf") and lic.contains("SIL OFL 1.1") and ofl.contains("SIL OPEN FONT LICENSE Version 1.1") \
		and ofl.contains("The Soft Type Project Authors"), "licence OFL copiée (OFL_Jacquard.txt) et listée dans assets/LICENCES.md")

	# --- 2. cadre ornementé
	var c := MenuStyle.cadre_orne()
	var img := c.texture.get_image()
	_verif(img.get_width() == 32 and img.get_height() == 32 and c.texture_margin_left == 12 and c.texture_margin_bottom == 12, "cadre ornementé : 32x32, marges 12")
	var sym := true
	for y in 12:
		for x in 12:
			var o := img.get_pixel(x, y)
			for q: Color in [img.get_pixel(31 - x, y), img.get_pixel(x, 31 - y), img.get_pixel(31 - x, 31 - y)]:
				if (o == MenuStyle.OR) != (q == MenuStyle.OR):
					sym = false
	_verif(sym and img.get_pixel(3, 2) == MenuStyle.OR, "cadre ornementé : nœud or dans les 4 coins (symétrique)")
	_verif(img.get_pixel(15, 7) == Color("#b8762a") and img.get_pixel(15, 0) == MenuStyle.FOND, "cadre ornementé : contour sombre et filet or intérieur sur les bords")
	_verif((MenuStyle.cadre() as StyleBoxTexture).texture_margin_top == 12, "MenuStyle.cadre() (menus, inventaire) = cadre ornementé")

	# --- HUD réel avec un faux joueur
	var monde := Node3D.new()
	root.add_child(monde)
	var fj := CharacterBody3D.new()
	fj.set_script(_script(FAUX_JOUEUR))
	monde.add_child(fj)
	var hud := Control.new()
	hud.set_script(HUD)
	hud.joueur = fj
	monde.add_child(hud)
	await process_frame

	# --- 3. annonces
	_verif(hud.annonce_courante() == "" and hud.alpha_annonce() == 0.0, "pas d'annonce au départ")
	hud.annonce("Épée", "Niveau 16")
	hud._process(0.1)
	_verif(hud.annonce_courante() == "Épée|Niveau 16", "annonce affichée : « %s »" % hud.annonce_courante())
	_avancer(hud, 0.4)
	_verif(is_equal_approx(hud.alpha_annonce(), 1.0), "annonce opaque après le fondu d'entrée (%.2f)" % hud.alpha_annonce())
	hud.avis("Nouvelle quête : Les sceaux brisés")
	_verif(hud._avis.is_empty() and hud._annonces.size() == 2, "« Nouvelle quête : … » → annonce en file, pas d'avis à gauche")
	_avancer(hud, 2.4)
	_verif(hud.annonce_courante() == "Nouvelle quête|Les sceaux brisés", "la 2e annonce suit la 1re (~2,6 s) : « %s »" % hud.annonce_courante())
	_avancer(hud, 2.8)
	_verif(hud.annonce_courante() == "", "annonce effacée à la fin")
	hud.avis("Quête terminée : L’anneau de givre")
	_verif(hud.annonce_courante() == "Quête terminée|L’anneau de givre", "« Quête terminée : … » → annonce")
	hud.avis("+ 22 Pièces")
	_verif(hud._avis.size() == 1, "un avis ordinaire reste en haut à gauche")
	_avancer(hud, 3.0)
	fj.competences.niveau_gagne.emit("epee", 17)
	_verif(hud.annonce_courante() == "Épée|Niveau 17", "niveau de compétence → annonce « %s »" % hud.annonce_courante())
	_avancer(hud, 3.0)

	# --- 4. lieux découverts
	hud.lieu_nomme(Vector3(10, 0, 0), 5.0, "Lieu test")
	hud.lieu_nomme(Vector3(-10, 0, 0), 5.0, "Lieu de surface")
	fj.global_position = Vector3(9, 0, 0)
	_avancer(hud, 1.2)
	_verif(hud.annonce_courante() == "" and hud.lieux_vus.is_empty(), "aucune découverte avant demarrer() (partie pas encore chargée)")
	hud.demarrer()
	_avancer(hud, 0.6)
	_verif(hud.annonce_courante() == "Lieu test|Lieu découvert" and hud.lieux_vus.has("Lieu test"), "premier passage → « Lieu découvert » (%s)" % hud.annonce_courante())
	_avancer(hud, 3.0)
	fj.global_position = Vector3(0, 0, 0)
	_avancer(hud, 1.0)
	fj.global_position = Vector3(9, 0, 0)
	_avancer(hud, 1.0)
	_verif(hud.annonce_courante() == "", "pas de deuxième annonce au retour dans le lieu")
	fj.global_position = Vector3(-10, -140, 0)
	_avancer(hud, 1.0)
	_verif(not hud.lieux_vus.has("Lieu de surface"), "sous terre (140 m plus bas) : le lieu de surface n'est pas découvert")

	# --- 5. aide des touches (demarrer() l'a lancée pour 60 s)
	_verif(hud.aide_visible(), "aide des touches visible au début de la partie")
	hud.panneau_ouvert = true
	_verif(not hud.aide_visible(), "aide masquée quand le panneau Tab est ouvert")
	hud.panneau_ouvert = false
	_avancer(hud, 60.0)
	_verif(not hud.aide_visible(), "aide éteinte au bout de 60 s")
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	hud._unhandled_input(f1)
	_verif(hud.aide_visible() and hud.aide_forcee, "F1 rallume l'aide")
	_avancer(hud, 70.0)
	_verif(hud.aide_visible(), "rallumée par F1 : elle reste (pas de minuterie)")
	hud._unhandled_input(f1)
	_verif(not hud.aide_visible(), "F1 l'éteint")
	hud.demarrer()
	hud._unhandled_input(f1)
	_verif(not hud.aide_visible(), "F1 pendant l'aide du début : elle s'éteint tout de suite")

	# --- 6. invite (dialogue.gd)
	var dia := Control.new()
	dia.set_script(DIALOGUE)
	dia.joueur = fj
	monde.add_child(dia)
	fj.global_position = Vector3.ZERO
	var coffre := Node3D.new()
	coffre.set_script(_script(FAUX_OBJET))
	coffre.set("nom", "Grand coffre")
	coffre.set("verbe", "Ouvrir le coffre")
	monde.add_child(coffre)
	dia.inviter(coffre)
	dia._process(0.1)
	_verif(dia._invite.visible and dia._invite_texte.text == "Ouvrir le coffre" and dia._invite_nom == "Grand coffre",
		"invite « %s » + nom de l'objet « %s » sous le réticule" % [dia._invite_texte.text, dia._invite_nom])
	_verif(dia._invite.position.y > floorf(dia.size.y * 0.5), "invite placée sous le réticule (y = %d, centre %d)" % [dia._invite.position.y, floorf(dia.size.y * 0.5)])
	dia.retirer_invite(coffre)
	var porte := Node3D.new()
	porte.set_script(_script(FAUX_OBJET))
	porte.set("nom", "Coffre")
	porte.set("verbe", "Ouvrir le coffre")
	monde.add_child(porte)
	dia.inviter(porte)
	dia._process(0.1)
	_verif(dia._invite_nom == "", "pas de nom en double quand le verbe le contient (« Coffre » / « Ouvrir le coffre »)")
	dia.retirer_invite(porte)
	dia._process(0.1)
	_verif(not dia._invite.visible, "invite retirée")

	print("RÉSULTAT test_hud_l7 : %d OK, %d en échec" % [_ok, _ko])
	monde.queue_free()
	await process_frame
	quit(1 if _ko > 0 else 0)
