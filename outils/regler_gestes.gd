extends SceneTree
## Vérification des gestes d'attaque (ProfilsAnimation, clés EN ESPACE ÉCRAN, passe 4) sans fenêtre :
##   godot --headless --path . --script res://outils/regler_gestes.gd -- [--gestes=diag_dg,horizontale_gd]
## Pour 9 points de l'arc de chaque geste (et le suivi), pose la lame, place le coude comme en jeu (mains._pole_ecran,
## épaule glissée si la main est hors de portée), laisse l'IK et le poignet agir, puis mesure :
##   - l'écart (degrés) entre la lame affichée et la pose du geste (= ce que suit le tracé de lame) ;
##   - l'angle avant-bras / poignée À L'ÉCRAN visé par le coude (0 = alignés).
## Les clés se règlent à la main dans profils_animation.gd (position écran de la garde et de la pointe) ; les mesures
## image par image (lame visible, angle de visée, couverture du bras) : outils/captures_combat_epee.gd -- --mesures.
## (La recherche de pôles de la passe 3, poignet rigide, n'a plus lieu d'être : le coude est calculé à chaque image.)

const SCENE := preload("res://scenes/test_combat.tscn")

var m: Node3D
var cam: Camera3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

## [écart lame affichée / pose (°), écart avant-bras / poignée visé à l'écran (°)] pour une pose.
func _mesurer(pose: Transform3D) -> Array:
	m.pivot_epee.transform = pose
	var main: Vector3 = (pose * m.PRISE_D.affine_inverse()).origin
	var epaule: Vector3 = m._bras_base * m._epaule_bras
	var portee: float = (m._l_bras + m._l_avant_bras) * m.ALLONGE_BRAS
	var dec := Vector3.ZERO
	if main.distance_to(epaule) > portee:
		dec = (main - epaule).normalized() * (main.distance_to(epaule) - portee)
	m._glisser_epaule(dec)
	m._coude_d.position = m._pole_ecran(pose, epaule + dec)
	m._orient_d.angle_min = 0.0
	m._orient_d.angle_max = PI
	m._orient_d.flexion_max = PI
	for i in 4:
		m._reposer_doigts()
		await process_frame
	var vu: Transform3D = m.global_transform.affine_inverse() * m._modele_arme_d.global_transform
	return [rad_to_deg(vu.basis.y.angle_to(pose.basis.y)), m.ecart_coude]

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	s.options = {"draugr": "aucun"}
	root.add_child(s)
	for i in 10:
		await process_frame
	m = s.joueur.mains
	cam = s.joueur.camera
	m.pas_manuel = true
	m.passifs.amplitude = 0.0
	var noms := _arg("gestes", "diag_dg,horizontale_gd,verticale_l,diag_gd,horizontale,estoc,verticale").split(",")
	var pire := 0.0
	for nom in noms:
		var g := ProfilsAnimation.geste(m.arme.profil, nom)
		var e_max := 0.0
		var ligne := ""
		var coude := ""
		for i in 9:
			var r: Array = await _mesurer(ProfilsAnimation.pose_active(g, i / 8.0))
			e_max = maxf(e_max, r[0])
			ligne += " %.0f" % r[0]
			coude += " %.0f" % r[1]
		var rs: Array = await _mesurer(ProfilsAnimation.pose_cle(g, "suivi"))
		print("VERIF %-15s lame affichée / tracé (°) :%s   suivi %.0f   max %.0f   | avant-bras / poignée à l'écran (°) :%s" % [nom, ligne, rs[0], maxf(e_max, rs[0]), coude])
		pire = maxf(pire, maxf(e_max, rs[0]))
	print("PIRE ÉCART : %.0f°" % pire)
	quit()
