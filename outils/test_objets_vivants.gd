extends SceneTree
## Petits objets de décor VIVANTS (scripts/objets_vivants.gd, objet_vivant.gd, data/objets/decor.json) :
##   - recensement : objets créés dans les intérieurs et sur les étals du marché, tous endormis (gelés), propriétaire hérité ;
##   - physique : un objet lâché au-dessus d'une table tombe, s'y pose (pas de traversée) et se rendort ; coup de lame et souffle de sort ;
##   - interaction : viser -> invite « Voler … (valeur) » en rouge ; prendre l'ajoute au sac, marqué volé, signaler_vol(objet, propriétaire,
##     position) appelé sur le nœud du groupe « crime » ; objet sans propriétaire : « Prendre », rien de signalé ; manger une pomme ;
##   - saisir / lancer ; sauvegarde (Monde.sauvegarder / charger) : objets pris et déplacés relus ; réassort des denrées d'étal.
##   godot --headless --path . --script res://outils/test_objets_vivants.gd -- --nouvelle

const SCENE := preload("res://scenes/foret_test.tscn")

var _ok := true
var _n := 0
var _vols: Array = []

class Crime extends Node:
	var recus: Array
	func signaler_vol(objet: Node, proprietaire: String, position: Vector3) -> void:
		recus.append([objet, proprietaire, position])

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		await physics_frame

func _de(lieu: String) -> Array:
	return ObjetsVivants._vivants().filter(func(o: ObjetVivant) -> bool: return o.ident.begins_with(lieu + ":"))

func _premier(l: Array, genre: String) -> ObjetVivant:
	for o: ObjetVivant in l:
		if o.genre == genre and not o.has_meta("pris") and not o.coince:
			return o
	return null

## Place le joueur pour que sa caméra soit à ~1 m de `o`, un peu au-dessus, et la tourne vers lui.
func _devant(j: CharacterBody3D, o: Node3D) -> void:
	var cam: Camera3D = j.camera
	var voulu := o.global_position + Vector3(0.0, 0.45, 0.9)
	j.global_position += voulu - cam.global_position
	j.velocity = Vector3.ZERO
	await _images(2)
	j.global_position += voulu - cam.global_position
	var d := o.global_position - cam.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _images(2)
	cam.look_at(o.global_position)

func _attendre_repos(o: ObjetVivant, max_images := 360) -> int:
	for i in max_images:
		await physics_frame
		if o.freeze:
			return i
	return -1

func _tester() -> void:
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	for i in 1800:      # intérieurs posés après le chargement (fil + pose étalée)
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	await _images(10)
	var j: CharacterBody3D = s.joueur
	var inv: Inventaire = j.inventaire
	var ov: ObjetsVivants = s.objets_vivants
	var crime := Crime.new()
	crime.recus = _vols
	crime.add_to_group("crime")
	s.add_child(crime)

	# --- recensement
	var halle := _de("halle")
	var marche := _de("marche_0") + _de("marche_1") + _de("marche_2")
	var tous := ObjetsVivants._vivants()
	var gel := tous.all(func(o: ObjetVivant) -> bool: return o.freeze)
	var lieux := {}
	for o: ObjetVivant in tous:
		lieux[o.ident.get_slice(":", 0)] = true
	_verif(ov != null and tous.size() >= 120 and halle.size() >= 30 and marche.size() >= 25 and gel,
		"%d objets vivants (%d dans la halle, %d sur les étals), tous endormis ; lieux %s" % [tous.size(), halle.size(), marche.size(), str(lieux.keys())])
	var mm_halle := 0
	for c in s.village.interieur("halle").racine.get_children():
		if c is MultiMeshInstance3D:
			mm_halle += 1
	_verif(mm_halle > 0 and mm_halle < halle.size() / 2, "halle : un MultiMesh par apparence (%d pour %d objets)" % [mm_halle, halle.size()])
	var chope := _premier(halle, "q_chope")
	var pain := _premier(halle, "q_pain")
	_verif(chope != null and pain != null and chope.proprietaire() == "chef" and _premier(marche, "q_pomme").proprietaire() == "etal_maraicher",
		"propriétaires hérités : halle -> chef, étal des primeurs -> etal_maraicher")

	# --- physique : tombe sur la table, ne la traverse pas, se rendort (joueur dans la halle : au-delà de 25 m tout objet se rendort)
	var ip: Interieur = s.village.interieur("halle")
	j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
	j.velocity = Vector3.ZERO
	await _images(5)
	var y_table := chope.global_position.y
	chope.global_position += Vector3(0, 0.6, 0)
	chope.actualiser_visuel()
	_verif(chope.reveiller() and not chope.freeze, "chope soulevée de 60 cm et réveillée")
	var n_img := await _attendre_repos(chope)
	_verif(n_img > 0 and absf(chope.global_position.y - y_table) < 0.08, "elle retombe sur la table et s'y rendort en %d images (y %.3f, table %.3f)" % [n_img, chope.global_position.y, y_table])
	_verif(chope.deplace or chope.global_position.distance_to(chope.get_parent().to_global(chope.depart.origin)) < 0.02, "état « déplacé » noté si elle a bougé")
	# coup de lame : projetée
	var assiette := _premier(halle, "q_assiette")
	var p0 := assiette.global_position
	_verif(assiette.frapper(true, p0 + Vector3(0.8, 0, 0)), "coup de lame : l'assiette cède (la lame continue)")
	await _images(8)
	_verif(assiette.global_position.distance_to(p0) > 0.08, "assiette projetée (%.2f m)" % assiette.global_position.distance_to(p0))
	await _attendre_repos(assiette, 600)
	_verif(assiette.freeze and assiette.global_position.y > ip.to_global(Vector3(0, ip.sol_y, 0)).y - 0.01, "assiette rendormie au-dessus du plancher (y %.2f)" % assiette.global_position.y)
	# souffle d'un sort au milieu d'une table de la halle
	var n_souffle := ObjetsVivants.souffle_a(pain.global_position, 1.0, 5.0)
	_verif(n_souffle >= 2, "souffle d'un sort : %d objets proches projetés" % n_souffle)
	for i in 600:
		await physics_frame
		if ObjetsVivants._eveilles.is_empty():
			break
	var reveilles := []
	for o in ObjetsVivants._eveilles:
		if is_instance_valid(o):
			reveilles.append("%s v=%.2f w=%.2f y=%.2f" % [o.genre, o.linear_velocity.length(), o.angular_velocity.length(), o.global_position.y])
	_verif(ObjetsVivants._eveilles.is_empty(), "tout se rendort après le souffle (%d encore réveillés %s)" % [reveilles.size(), str(reveilles)])

	# --- viser : invite « Voler … » en rouge
	var cible: ObjetVivant = null
	for o: ObjetVivant in halle:
		if o.genre == "q_chope" and not o.deplace and not o.has_meta("pris") and cible == null:
			cible = o
	await _devant(j, cible)
	var cam: Camera3D = j.camera
	ov._viser()
	_verif(ov.objet_vise() == cible and s.dialogue.invite_courante() == ov._proxy and ov._texte_visee().begins_with("Voler Chope de bois (2)")
		and ov._couleur_visee() == ObjetsVivants.ROUGE, "objet visé : « %s » en rouge" % ov._texte_visee())

	# --- prendre (vol) : au sac, marqué volé, signalé au lot crime
	var n0 := inv.nombre("chope")
	_verif(ov.prendre(cible) and inv.nombre("chope") == n0 + 1 and inv.est_vole("chope") and inv.get_meta("vole", false),
		"prendre la chope : au sac (%d), marquée volée" % inv.nombre("chope"))
	_verif(_vols.size() == 1 and _vols[0][0] == cible and _vols[0][1] == "chef" and (_vols[0][2] as Vector3).distance_to(cible.global_position) < 0.01,
		"signaler_vol(objet, « chef », position) appelé sur le nœud du groupe « crime »")
	var cachee := DisplayServer.get_name() == "headless" or cible.mm.get_instance_transform(cible.idx).basis.get_scale().length() < 0.001   # serveur de rendu factice : instances non stockées
	_verif(cible.has_meta("pris") and cible.collision_layer == 0 and not cible.visible and cachee, "la chope a disparu du décor (plus de collision, instance effacée)")
	# objet sans propriétaire : « Prendre », pas de vol
	var libre := _premier(halle, "q_pain")
	libre.set_meta("proprietaire", "")
	ov._visee = libre
	var nv := _vols.size()
	var pn := inv.nombre("pain_seigle")
	_verif(ov._texte_visee().begins_with("Prendre ") and ov.prendre(libre) and inv.nombre("pain_seigle") == pn + 1 and not inv.est_vole("pain_seigle") and _vols.size() == nv,
		"pain sans propriétaire : « Prendre », au sac, rien de signalé")
	# manger une pomme prise sur l'étal
	var pomme := _premier(marche, "q_pomme")
	ov.prendre(pomme)
	j.vie = j.vie_max - 20.0
	_verif(inv.nombre("pomme") >= 1 and Consommables.est("pomme") and Consommables.utiliser(j, "pomme") == "" and inv.nombre("pomme") == 0,
		"la pomme se mange depuis le sac (%s)" % Consommables.description("pomme"))

	# --- saisir et lancer
	var lance: ObjetVivant = null
	for g in ["q_pomme", "q_pomme_verte", "q_tranche_pain", "q_cuisse"]:
		for o: ObjetVivant in halle:
			if lance == null and o.genre == g and not o.deplace and not o.has_meta("pris") and not o.coince:
				lance = o
	await _devant(j, lance)
	_verif(ov.saisir(lance) and ov.objet_tenu() == lance and not lance.freeze, "E maintenu : %s saisi(e)" % lance.nom_objet())
	await _images(30)
	var devant := cam.global_position - cam.global_transform.basis.z * ov._dist_tenu
	_verif(lance.global_position.distance_to(devant) < 0.35, "l'objet suit le regard (%.2f m de la visée ; objet %s, visée %s)" % [lance.global_position.distance_to(devant), lance.global_position, devant])
	ov.lancer()
	await _images(3)
	_verif(ov.objet_tenu() == null and lance.linear_velocity.length() > 3.0, "clic gauche : lancé à %.1f m/s" % lance.linear_velocity.length())
	await _attendre_repos(lance, 900)
	_verif(lance.freeze, "l'objet lancé retombe et se rendort")

	# --- sauvegarde et rechargement (clé « objets_vivants » de Monde)
	var deplacee := _premier(halle, "q_assiette")
	deplacee.global_position += Vector3(0.3, 0.0, 0.0)
	deplacee.deplace = true
	var pos_sauvee := deplacee.position
	_verif(s.sauvegarder(1), "partie sauvegardée")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sauvegardes.fichier(1)))
	var e: Dictionary = d.get("objets_vivants", {})
	_verif(e.has(cible.ident) and e.has(deplacee.ident) and (e[deplacee.ident] as Dictionary).has("p"), "sauvegarde : objets pris et déplacés (%d entrées)" % e.size())
	ObjetsVivants.reinitialiser()
	_verif(not cible.has_meta("pris") and deplacee.position.distance_to(deplacee.depart.origin) < 0.001, "nouvelle partie : tout est remis en place")
	s.charger()
	await _images(2)
	_verif(cible.has_meta("pris") and deplacee.position.distance_to(pos_sauvee) < 0.005 and inv.est_vole("chope"),
		"rechargement : chope toujours prise (et volée au sac), assiette à sa nouvelle place")
	# réassort : la pomme de l'étal revient après 3 jours de jeu, la chope de la halle jamais
	_verif(pomme.has_meta("pris"), "pomme de l'étal prise")
	Marchand.heures += 24.0 * MobilierVillage.REASSORT_JOURS + 1.0
	ov._acc = 10.0
	await process_frame
	await process_frame
	_verif(not pomme.has_meta("pris") and cible.has_meta("pris"), "3 jours plus tard : la pomme est revenue sur l'étal, la chope non")

	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
