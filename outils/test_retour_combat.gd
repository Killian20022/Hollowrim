extends SceneTree
## Test sans fenêtre du RETOUR DE COMBAT au corps à corps (lot L6) — décor scenes/test_degats.tscn en mode --test :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_retour_combat.gd -- --nouvelle --test
## 1. Noms lisibles des ennemis (barre du HUD) : « Draugr ancien », « Draugr », « Squelette », « Bandit » ; statut « Étourdi ».
## 2. HUD réel (scripts/hud.gd) : un ennemi frappé ou VISÉ (réticule) devient la cible de la barre.
## 3. Option « Chiffres de dégâts » : désactivée par défaut, aucun chiffre si coupée, persistée dans options.cfg (le fichier
##    du joueur est sauvegardé puis remis tel quel) ; activée : un chiffre par coup, les tics canalisés s'additionnent.
## 4. Gerbes : matière selon la cible (os, draugr, sang, bois ; poussière / os si gore coupé), couleur → matière (Sang.matiere_de).
## 5. AUCUNE ALLOCATION PAR COUP : après un premier coup, 30 coups (légers, lourds, parés) sur un squelette et un draugr à
##    bouclier ne créent aucun GPUParticles3D ni RigidBody3D (les pools gardent leur taille) ; les éclats d'os volent aux coups
##    lourds et s'éteignent (corps désactivés) après leur durée.

const SCENE := preload("res://scenes/test_degats.tscn")
const HUD := preload("res://scripts/hud.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const FAUX_JOUEUR := """extends CharacterBody3D
var competences := Competences.new()
var ennemi_vise: Node = null
var en_dialogue := false
var mort := false
var camera: Camera3D
var inventaire = null
"""

var _ok := 0
var _ko := 0
var sc: Node3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _draugr(type: String, x: float, ident: String, opts := {}) -> CharacterBody3D:
	var o := opts.duplicate()
	o["ident"] = ident
	var d: CharacterBody3D = sc.creer_draugr(type, Vector3(x, 0.05, 0.5), o)
	await _frames(5)
	d.set_physics_process(false)
	return d

## Nœuds d'une classe dans tout l'arbre, hors pools du lot L6.
func _compter(classe: String) -> int:
	var n := 0
	for c in root.find_children("*", classe, true, false):
		var p := c.get_parent()
		if p is GerbePixels or p is EclatsOs:
			continue
		n += 1
	return n

func _tester() -> void:
	RetourImpact.muet = true
	RetourImpact.arret_actif = false
	Sang.niveau_force = 2
	sc = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	var j: CharacterBody3D = sc.joueur
	j.global_position = Vector3(0, 0, 3.0)

	# --- 1. noms lisibles
	var g := await _draugr("guerrier", -2.0, "r_guerrier")
	var sb := await _draugr("sbire", -1.0, "r_sbire")
	var sq := await _draugr("squelette", 0.0, "r_squelette")
	var ba := await _draugr("sbire", 1.5, "r_bandit", {"apparence": GROTTE.apparence_humain(1)})
	var boss := await _draugr("guerrier", 3.0, "r_boss", {"nom_affiche": "Gardien des Os"})
	_verif(HUD.nom_ennemi(g) == "Draugr ancien", "draugr guerrier nommé « %s »" % HUD.nom_ennemi(g))
	_verif(HUD.nom_ennemi(sb) == "Draugr", "draugr sbire nommé « %s »" % HUD.nom_ennemi(sb))
	_verif(HUD.nom_ennemi(sq) == "Squelette", "squelette nommé « %s »" % HUD.nom_ennemi(sq))
	_verif(HUD.nom_ennemi(ba) in ["Bandit", "Bandit archer"], "bandit nommé « %s » (profil %s)" % [HUD.nom_ennemi(ba), ba.combat.profil.nom])
	_verif(HUD.nom_ennemi(boss) == "Gardien des Os", "nom imposé gardé : « %s »" % HUD.nom_ennemi(boss))
	_verif(HUD.nom_ennemi(null) == "Ennemi", "repli sans cible : « Ennemi »")
	sb.combat.briser_posture()
	_verif(HUD.statut_ennemi(sb).begins_with("Étourdi"), "posture brisée : statut « %s » sous la barre" % HUD.statut_ennemi(sb))

	# --- 2. HUD réel : cible frappée puis visée
	var fj := CharacterBody3D.new()
	var scr := GDScript.new()
	scr.source_code = FAUX_JOUEUR
	scr.reload()
	fj.set_script(scr)
	sc.add_child(fj)
	fj.set("camera", j.camera)
	var hud := Control.new()
	hud.set_script(HUD)
	hud.joueur = fj
	sc.add_child(hud)
	await process_frame
	fj.set("ennemi_vise", g)
	await process_frame
	await process_frame
	_verif(hud.get("_cible") == g, "HUD : l'ennemi frappé devient la cible de la barre")
	# visée : un squelette en combat juste devant la caméra
	hud.set("_cible", null)
	hud.set("_a_cible", 0.0)
	sq.etat = sq.TRAQUE
	j.global_position = sq.global_position + Vector3(0, 0, 3.0)
	j.camera.global_transform = Transform3D(Basis.looking_at(sq.global_position + Vector3(0, 1.1, 0) - (j.global_position + Vector3(0, 1.62, 0)), Vector3.UP), j.global_position + Vector3(0, 1.62, 0))
	for k in 12:
		await process_frame
	_verif(hud.get("_cible") == sq, "HUD : ennemi en combat sous le réticule → barre affichée sans le frapper (%s)" % str(hud.get("_cible")))
	sq.etat = sq.GARDE

	# --- 3. option chiffres de dégâts
	_verif(Jeu.OPTIONS_DEFAUT["combat"].has("chiffres_degats") and Jeu.OPTIONS_DEFAUT["combat"]["chiffres_degats"] == false, "option « chiffres_degats » : désactivée par défaut")
	var sauve := FileAccess.get_file_as_bytes(Jeu.FICHIER_OPTIONS) if FileAccess.file_exists(Jeu.FICHIER_OPTIONS) else PackedByteArray()
	var existait := FileAccess.file_exists(Jeu.FICHIER_OPTIONS)
	Jeu.regler("combat", "chiffres_degats", false)
	ChiffresDegats.force_actif = -1
	ChiffresDegats.vider()
	var a0 := ChiffresDegats.ajouts
	g.vie = 500.0
	g.recevoir_coup(10.0, g.global_position + Vector3(0, 0, -2.0), false, {"attaque": "legere", "zone": "torse"})
	_verif(not ChiffresDegats.actif() and ChiffresDegats.ajouts == a0, "option coupée : aucun chiffre ajouté")
	Jeu.regler("combat", "chiffres_degats", true)
	Jeu.options = {}
	Jeu.charger_options()
	_verif(Jeu.option("combat", "chiffres_degats") == true, "option activée : relue depuis options.cfg (persistée)")
	g.recevoir_coup(10.0, g.global_position + Vector3(0, 0, -2.0), false, {"attaque": "legere", "zone": "torse"})
	_verif(ChiffresDegats.ajouts == a0 + 1 and ChiffresDegats.visibles() >= 1, "option active : un chiffre par coup (%d visible)" % ChiffresDegats.visibles())
	var a1 := ChiffresDegats.ajouts
	for k in 4:
		ChiffresDegats.ajouter(g, g.global_position, 2.0, ChiffresDegats.FEU, true)
	_verif(ChiffresDegats.ajouts == a1 + 1, "tics canalisés : additionnés dans un seul chiffre")
	_verif(ChiffresDegats.sorte_de({"critique": true, "info": {}}) == ChiffresDegats.CRITIQUE and ChiffresDegats.sorte_de({"critique": false, "info": {"ecole": "glace"}}) == ChiffresDegats.GLACE, "couleur : critique / école de magie")
	# remise en l'état du fichier d'options du joueur
	if existait:
		var f := FileAccess.open(Jeu.FICHIER_OPTIONS, FileAccess.WRITE)
		f.store_buffer(sauve)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Jeu.FICHIER_OPTIONS))
	Jeu.options = {}
	Jeu.charger_options()
	ChiffresDegats.force_actif = 1

	# --- 4. matières des gerbes
	_verif(sq.combat.matiere_gerbe() == "os" and g.combat.matiere_gerbe() == "draugr" and ba.combat.matiere_gerbe() == "sang", "gerbes : squelette os, draugr os+sang noirci, bandit sang (%s/%s/%s)" % [sq.combat.matiere_gerbe(), g.combat.matiere_gerbe(), ba.combat.matiere_gerbe()])
	Sang.niveau_force = 0
	_verif(g.combat.matiere_gerbe() == "os" and ba.combat.matiere_gerbe() == "poussiere", "gore coupé : draugr os, bandit poussière")
	Sang.niveau_force = 2
	_verif(Sang.matiere_de(Color(0.72, 0.68, 0.56)) == "os" and Sang.matiere_de(Color(0.62, 0.48, 0.30)) == "bois" and Sang.matiere_de(Color(0.45, 0.42, 0.38)) == "poussiere", "couleur → matière (os, bois, poussière)")
	for m: String in GerbePixels.MATIERES:
		var cs: Array = GerbePixels.MATIERES[m]["couleurs"]
		_verif(cs.size() >= 3, "matière « %s » : %d couleurs de palette" % [m, cs.size()])

	# --- 5. aucune allocation par coup
	var gp := GerbePixels.obtenir(sc)
	var eo := EclatsOs.obtenir(sc)
	_verif(gp != null and gp.get_child_count() == GerbePixels.TAILLE_POOL, "pool de gerbes : %d émetteurs" % (gp.get_child_count() if gp else 0))
	_verif(eo != null and eo.get_child_count() == EclatsOs.TAILLE_POOL, "pool d'os : %d corps" % (eo.get_child_count() if eo else 0))
	j.global_position = Vector3(0, 0, 3.0)
	var dos := sq.global_position + Vector3(0, 0, -2.0)
	sq.vie = 5000.0
	sq.recevoir_coup(12.0, dos, false, {"attaque": "legere", "zone": "torse"})
	sq.recevoir_coup(30.0, dos, true, {"attaque": "lourde", "zone": "torse"})
	await _frames(2)
	var p0 := _compter("GPUParticles3D")
	var r0 := _compter("RigidBody3D")
	var e0 := GerbePixels.emissions
	var l0 := EclatsOs.lances
	for k in 30:
		sq.vie = 5000.0
		sq.combat.etourdi = 0.0
		var lourd := k % 3 == 0
		sq.recevoir_coup(30.0 if lourd else 12.0, dos, lourd, {"attaque": "lourde" if lourd else "legere", "zone": ["torse", "tete", "bras"][k % 3]})
		if k % 5 == 0:
			await physics_frame
	await _frames(2)
	var p1 := _compter("GPUParticles3D")
	var r1 := _compter("RigidBody3D")
	_verif(GerbePixels.emissions - e0 >= 30, "30 coups sur le squelette : %d gerbes émises" % (GerbePixels.emissions - e0))
	_verif(p1 == p0, "aucun GPUParticles3D créé par coup (%d → %d)" % [p0, p1])
	_verif(r1 == r0, "aucun corps rigide créé par coup (%d → %d)" % [r0, r1])
	_verif(EclatsOs.lances > l0 and eo.vivants() > 0, "coups lourds : os qui volent (%d lancés, %d en vol)" % [EclatsOs.lances - l0, eo.vivants()])
	_verif(gp.get_child_count() == GerbePixels.TAILLE_POOL and eo.get_child_count() == EclatsOs.TAILLE_POOL, "pools inchangés après 30 coups")
	# coup paré au bouclier (draugr guerrier de face) : échardes + étincelles, chiffre « bloqué »
	var e1 := GerbePixels.emissions
	var c0 := _cubes_effets()
	var n_bloque := 0
	for k in 20:
		g.vie = 500.0
		g.etat = g.TRAQUE
		g.combat.posture = g.combat.profil.posture_max
		if g.recevoir_coup(8.0, g.global_position + Vector3(0, 0, 2.0), false, {"attaque": "legere", "zone": "torse"}) == "bloque":
			n_bloque += 1
	_verif(n_bloque == 0 or GerbePixels.emissions - e1 >= n_bloque * 2, "coups parés au bouclier : %d (gerbes bois + étincelles : %d)" % [n_bloque, GerbePixels.emissions - e1])
	_verif(_cubes_effets() == c0, "draugr touché / paré : plus aucun ancien cube d'Effets.eclats (%d → %d)" % [c0, _cubes_effets()])
	# les os s'éteignent après leur durée (corps désactivés : hors de l'espace physique)
	await _frames(int((EclatsOs.DUREE + 0.6) * 60.0))
	_verif(eo.vivants() == 0, "os éteints après %.0f s (%d restants)" % [EclatsOs.DUREE, eo.vivants()])
	var desactives := 0
	for c in eo.get_children():
		if (c as Node).process_mode == Node.PROCESS_MODE_DISABLED and not (c as Node3D).visible:
			desactives += 1
	_verif(desactives == EclatsOs.TAILLE_POOL, "tous les corps d'os désactivés et cachés (%d/%d)" % [desactives, EclatsOs.TAILLE_POOL])
	_verif(Engine.time_scale == 1.0, "échelle de temps rendue à 1")

	ChiffresDegats.force_actif = -1
	print("RETOUR_COMBAT : %d OK, %d en échec" % [_ok, _ko])
	print("ECHECS : %d" % _ko)
	quit(1 if _ko > 0 else 0)

## Anciens éclats (Effets.eclats : cubes de 5 cm) encore en vie dans la scène.
func _cubes_effets() -> int:
	var n := 0
	for c in root.find_children("*", "GPUParticles3D", true, false):
		var m := (c as GPUParticles3D).draw_pass_1 as BoxMesh
		if m != null and m.size.is_equal_approx(Vector3.ONE * 0.05):
			n += 1
	return n
