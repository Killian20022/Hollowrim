extends SceneTree
## Test sans fenêtre de l'ARC DU JOUEUR (ArcJoueur, data/arc/arc_joueur.json, Projectile.tirer_joueur) :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_arc_joueur.gd
## Données (arc + flèches au registre, marchand, butin) ; équipement (refus sans arc, épée rangée) ; pas de bandage sans flèche ;
## tir annulé sous la tension minimale (flèche gardée) ; dégâts et vitesse croissants avec la tension ; une flèche par tir ;
## zoom et ralenti de marche pendant le bandage ; la flèche touche le mannequin visé ; flèche plantée récupérable ;
## troisième personne (clips, modèle) ; rangement de l'arc.

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

func _viser() -> void:
	var c: Vector3 = cible.global_position + Vector3(0, 1.1, 0)
	j.rotation.y = 0.0
	var d: Vector3 = c - j.camera.global_position
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await physics_frame

## Appui de `tenu` s puis relâché ; rend l'état mesuré à la fin de l'appui.
func _tirer(tenu: float) -> Dictionary:
	await _viser()
	var n0 := arc.tirs
	arc.appuyer()
	await _sim(tenu)
	var m := {"tension": arc.tension, "facteur": arc.facteur_vitesse(), "fov": j.camera.fov, "etat": arc.etat, "clip": arc.clip_tps()}
	arc.relacher()
	await _sim(0.1)
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
	# équipement
	_verif(arc.equiper() != "" and not arc.actif, "sans arc au sac : refus (« %s »)" % arc.equiper())
	j.inventaire.ajouter("arc_chasseur", 1)
	var epee_avant: bool = j.mains._peut_agir()
	_verif(arc.equiper() == "" and arc.actif and epee_avant and not j.mains._peut_agir(), "arc équipé : l'épée ne peut plus frapper")
	_verif(not j.mains.visible and arc._vm.visible, "première personne : mains de l'épée cachées, arc visible")
	# pas de flèche
	var sans_n := [0]
	arc.sans_fleche.connect(func() -> void: sans_n[0] += 1)
	var r0 := await _tirer(0.5)
	_verif(sans_n[0] == 1 and r0["etat"] == ArcJoueur.REPOS and not r0["parti"] and arc.tirs == 0, "sans flèche : pas de bandage, pas de tir (avis donné)")
	# tension minimale
	j.inventaire.ajouter("fleche", 6)
	await _sim(0.6)
	var r1 := await _tirer(0.05)
	_verif(not r1["parti"] and j.inventaire.nombre("fleche") == 6, "appui trop bref : tir annulé, flèche gardée (%d)" % j.inventaire.nombre("fleche"))
	# tir faible
	var fov0: float = j.camera.fov
	var r2 := await _tirer(0.3)
	var d_faible: float = arc.dernier_tir.get("degats", 0.0)
	var v_faible: float = arc.dernier_tir.get("vitesse", 0.0)
	_verif(r2["parti"] and j.inventaire.nombre("fleche") == 5, "tir faible : une flèche consommée (reste %d)" % j.inventaire.nombre("fleche"))
	await _sim(1.5)
	# tir plein
	var n_coups: int = cible.coups.size()
	var r3 := await _tirer(1.3)
	var d_plein: float = arc.dernier_tir.get("degats", 0.0)
	var v_plein: float = arc.dernier_tir.get("vitesse", 0.0)
	_verif(r3["parti"] and r3["tension"] >= 0.999 and j.inventaire.nombre("fleche") == 4, "tir plein : tension %.2f, reste %d flèches" % [r3["tension"], j.inventaire.nombre("fleche")])
	_verif(d_plein > d_faible * 2.0 and v_plein > v_faible, "dégâts (%.0f contre %.0f) et vitesse (%.0f contre %.0f) croissent avec la tension" % [d_plein, d_faible, v_plein, v_faible])
	_verif(r3["facteur"] < 0.7 and r3["fov"] < fov0 - 3.0, "bandage : marche ×%.2f, champ de vision %.1f → %.1f" % [r3["facteur"], fov0, r3["fov"]])
	await _sim(1.2)
	_verif(cible.coups.size() == n_coups + 1 and absf(float(cible.coups[-1]["degats"]) - d_plein) < 0.01, "la flèche pleine touche le mannequin visé (%.0f dégâts envoyés)" % d_plein)
	_verif(absf(j.camera.fov - fov0) < 0.2 and arc.etat == ArcJoueur.REPOS, "zoom rendu après le tir (fov %.1f)" % j.camera.fov)
	# flèche plantée récupérable (on vise le mur de gauche)
	ArcJoueur._r["fleche_recuperable"] = 1.0
	j.rotation.y = PI * 0.5
	j.tete.rotation.x = 0.0
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
	# troisième personne
	j.global_position = Vector3(0, 0, 0)
	j.basculer_vue(true)
	await _sim(0.2)
	_verif(arc._tp.visible and not arc._vm.visible, "troisième personne : modèle de corps visible, celui de la caméra caché")
	var r4 := await _tirer(0.9)
	_verif(r4["parti"] and r4["clip"] == "Pistol_Aim_Neutral", "troisième personne : bandage avec le clip d'archer (%s), flèche partie" % r4["clip"])
	await _sim(0.6)
	j.basculer_vue(false)
	# rangement
	arc.ranger()
	_verif(not arc.actif and j.mains._peut_agir() and j.mains.visible, "arc rangé : l'épée reprend la main")
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)
