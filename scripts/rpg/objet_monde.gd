class_name ObjetMonde
extends Node3D
## OBJET PHYSIQUE DANS LE MONDE, pour tout objet du registre (data/objets/, Inventaire.objet) : le modèle 3D posé (au sol, sur un
## étal, sur un râtelier) au lieu d'un nom dans un sac.
##
## MODÈLE d'un identifiant (ObjetMonde.chemin_modele), dans cet ordre :
##   1. champ `modele_sol` de la fiche (armures : posé par l'agent X, convention docs CONVENTION_ARMURES_3D) ;
##   2. champ `modele` de la fiche (bijoux : assets/modeles/bijoux/<id>.glb ; potions, vivres, tomes, ingrédients, divers, quête :
##      assets/modeles/objets/<id>.glb, source sources_blender/objets/objets_divers.py, matériaux ObjetsDiversMateriaux ; pose au sol) ;
##   3. assets/modeles/armures/sol/<id>.glb (armures dont la fiche n'a pas encore le champ) ;
##   4. armes : modèle de la DonneesArme (CatalogueArmes.donnees / data/armes/<id>.tres), COUCHÉ à plat ;
##   5. petits objets de boutique sans glb, en primitives ps1 (ObjetMonde.accessoire) : fioles (potion_*), livres (tome_*), miche
##      (pain_seigle), lanières de viande (viande_sechee) ;
##   6. sinon REPLI : sacoche de cuir nouée (même allure que le sac des objets lâchés, Lacher), jamais un cube.
## Tous les modèles passent par le shader ps1 (matériaux par nom : BijouxMateriaux, EpeesLongues, ClaymoreMateriaux, BouclierNordique).
## Pivot AU SOL, centré : le visuel renvoyé se pose tel quel sur une surface (y = 0 = dessus du sol / de la table).
##
## API (statique, sans état global) :
##   ObjetMonde.visuel(id, pose := "sol", graine := 0) -> Node3D   modèle habillé, pivot au sol ; pose « sol » (couché, bijoux exagérés
##                                                                ×ECHELLE_BIJOU, anneaux ×ECHELLE_ANNEAU), « etal » (couché, bijoux ×ECHELLE_ETAL), « ratelier »
##                                                                (arme debout, pointe en haut, pommeau à y = 0), « studio » (taille
##                                                                réelle, couché : scripts/rendu_objet.gd). `graine` : petit lacet stable.
##   ObjetMonde.chemin_modele(id) -> String                       "" = repli sacoche
##   ObjetMonde.a_modele(id) -> bool
##   ObjetMonde.creer(id, n := 1, joueur = null, dialogue = null) -> ObjetMonde
##                                                                objet RAMASSABLE posé (touche E « Prendre », au sac par
##                                                                ButinTables.prendre) ; sans joueur : décor seul.
##   ObjetMonde.tas(contenu: Dictionary, pose := "sol", max_objets := 4) -> Node3D
##                                                                plusieurs objets côte à côte (sac lâché, butin posé) ; au-delà de
##                                                                max_objets, ou si rien n'a de modèle, la sacoche en plus.
##   ObjetMonde.hausse_sol(point, monde) -> float                à ajouter au point de sol physique (pavés du village sans collision)
##   ObjetMonde.exposer(parent, ids: Array, largeur, profondeur, pose := "etal") -> Array[Node3D]
##                                                                pièces d'un ÉTAL alignées sur un plateau (repère du parent : plateau
##                                                                centré en 0, dessus à y = 0).
## Points d'accroche des autres lots : Lacher.habiller (objet lâché), Butin (« lache: »), EtalMarchand (étals de Brodd et Grima), et
## pour le RÂTELIER de la maison (lot E, ServicesPnj._actualiser_ratelier) : remplacer l'instanciation EpeesLongues par
## `ObjetMonde.visuel(id, "ratelier")` posé à la place (pommeau sur l'encoche : y = 0 du visuel = bas du pommeau).

const DOSSIER_SOL := "res://assets/modeles/armures/sol/%s.glb"
const ECHELLE_BIJOU := 1.8     # au sol : un anneau de 3 cm fait ~1 px à 6 m en 480 x 270 ; exagéré pour rester lisible
const ECHELLE_ETAL := 1.5
## Anneaux : jonc de 2 mm, sous le pixel à 2 m ; seule la pierre se lirait. Exagérés davantage (au sol / sur un étal).
const ECHELLE_ANNEAU := 3.0
const ECHELLE_ANNEAU_ETAL := 2.2
const PORTEE := 30.0
const MAX_TAS := 4

var id := ""
var nombre := 1
var _inter: Node3D

## Chemin du modèle de `oid` (voir l'ordre en tête) ; "" = pas de modèle (repli sacoche).
static func chemin_modele(oid: String) -> String:
	var f := Inventaire.objet(oid)
	for cle in ["modele_sol", "modele"]:
		var c := String(f.get(cle, ""))
		if c != "" and ResourceLoader.exists(c):
			return c
	if oid.is_valid_filename() and ResourceLoader.exists(DOSSIER_SOL % oid):
		return DOSSIER_SOL % oid
	var d := _arme(oid)
	if d != null and d.modele != "" and ResourceLoader.exists(d.modele):
		return d.modele
	return ""

static func a_modele(oid: String) -> bool:
	return chemin_modele(oid) != "" or a_accessoire(oid)

static func a_accessoire(oid: String) -> bool:
	return oid.begins_with("potion_") or oid.begins_with("tome_") or oid in ["pain_seigle", "viande_sechee"]

static func _arme(oid: String) -> DonneesArme:
	if CatalogueArmes.connu(oid):
		return CatalogueArmes.donnees(oid)
	# arme du registre, ou objet de main hors registre (epee_metal, bouclier, torche : data/armes/<id>.tres ; icônes, aperçu 3D)
	if Inventaire.categorie_de(oid) != "arme" and Inventaire.connu(oid):
		return null
	var c := "res://data/armes/%s.tres" % oid
	if oid.is_valid_filename() and ResourceLoader.exists(c):
		return load(c) as DonneesArme
	return null

## Modèle habillé de `oid`, pivot au sol (y = 0), centré en x/z. Toujours un nœud (repli : sacoche).
static func visuel(oid: String, pose := "sol", graine := 0) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Visuel_" + oid
	var chemin := chemin_modele(oid)
	var m: Node3D = null
	if chemin != "":
		var sc: Variant = load(chemin)
		if sc is PackedScene:
			m = (sc as PackedScene).instantiate() as Node3D
	if m == null and a_accessoire(oid):
		m = accessoire(oid)
		racine.add_child(m)
		_lacet(racine, m, graine)
		return racine
	if m == null:
		m = sacoche()
		racine.set_meta("repli", true)
		racine.add_child(m)
		_lacet(racine, m, graine)
		return racine
	var d := _arme(oid)
	if d != null and d.modele != chemin:
		d = null
	if d != null:
		_habiller_arme(m, d)
	elif Inventaire.categorie_de(oid) == "armure":
		_habiller_armure(m, chemin)
	else:
		BijouxMateriaux.habiller(m)
		ObjetsDiversMateriaux.habiller(m)      # potions, vivres, tomes, ingrédients, quête (noms propres à ces objets)
	_sans_squelette(m)
	var pivot := Node3D.new()      # porte la pose (rotation) ; le recalage au sol se fait sur la racine
	pivot.add_child(m)
	racine.add_child(pivot)
	var cat := Inventaire.categorie_de(oid)
	if d != null:
		if pose == "ratelier":
			pivot.basis = Basis.IDENTITY                                   # +Y le long de la lame : debout, pointe en haut
		else:
			pivot.basis = _coucher(m)
	var ech := 1.0
	var genre := _genre_petit(oid)
	if genre != "":
		var anneau := genre == "anneau"
		if pose == "sol":
			ech = ECHELLE_ANNEAU if anneau else ECHELLE_BIJOU
		elif pose == "etal":
			ech = ECHELLE_ANNEAU_ETAL if anneau else ECHELLE_ETAL
	pivot.scale = Vector3.ONE * ech
	if pose != "ratelier":
		pivot.rotate_y(_lacet_de(oid, graine))
	_poser_au_sol(racine, pivot)
	for g in racine.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(g as GeometryInstance3D).visibility_range_end = PORTEE if pose != "studio" else 0.0
	return racine

## Bijou (ou bijou-objet de quête / divers : anneau_cuivre, anneau_givre, collier_or, amulette_eirik, broche_sigrun) : « anneau »,
## « bijou » ou "" ; sert à l'exagération au sol / sur un étal (ECHELLE_*), sinon taille réelle.
static func _genre_petit(oid: String) -> String:
	if Inventaire.categorie_de(oid) == "bijou":
		return "anneau" if Inventaire.emplacement_de(oid) == "anneau" else "bijou"
	if oid.begins_with("anneau_"):
		return "anneau"
	for p in ["collier_", "amulette_", "broche_"]:
		if oid.begins_with(p):
			return "bijou"
	return ""

## Petit lacet stable (aucun hasard global) : objets d'un tas ou d'un étal pas tous alignés.
static func _lacet_de(oid: String, graine: int) -> float:
	if graine == 0:
		return 0.0
	return (float(hash(oid + str(graine)) % 1000) / 1000.0 - 0.5) * 0.9

static func _lacet(racine: Node3D, m: Node3D, graine: int) -> void:
	if graine != 0:
		m.rotate_y(_lacet_de(racine.name, graine))

static func _habiller_arme(m: Node3D, d: DonneesArme) -> void:
	match d.habillage:
		"claymore":
			ClaymoreMateriaux.habiller(m)
		"bouclier":
			BouclierNordique.habiller(m)
		_:
			EpeesLongues.habiller(m)

## Modèle porté (skinné) importé tel quel : on garde le maillage dans sa pose de liaison (un glb « sol » n'a pas de squelette).
## Armure au sol (glb des agents X / Y : texture cuite, alpha = brillance) : matériaux d'ArmureVisible s'il est là (même rendu
## que la pièce portée), sinon un équivalent minimal ici (shader_matiere, preset par nom de matériau Blender).
const MATIERES_ARMURE := {
	"fourrure": {"bord": 0.05, "poli": 0.05}, "os": {"bord": 0.1, "poli": 0.3},
	"fer": {"metal": 0.5, "poli": 0.35}, "acier": {"metal": 0.75, "poli": 0.7}, "or": {"metal": 0.72, "poli": 0.6},
}
static func _habiller_armure(m: Node3D, chemin: String) -> void:
	var av: Script = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == "ArmureVisible":
			av = load(c["path"])
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if av != null and av.has_method("_habiller_maillage"):
			av.call("_habiller_maillage", mi, chemin)
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
			if tex == null:
				continue
			var nom := src.resource_name.get_slice(".", 0)
			var p: Dictionary = MATIERES_ARMURE.get(nom, {"bord": 0.14, "poli": 0.22})
			var mat := Palette.materiau(tex, Vector2.ONE)
			mat.shader = EpeesLongues.shader_matiere(false)
			mat.set_shader_parameter("tex_neige", tex)
			mat.set_shader_parameter("mt_boite", 0.0)
			for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
				mat.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
			mat.set_shader_parameter("mt_opacite", 1.0)
			mat.set_shader_parameter("reflet_force", 0.0)
			mat.set_shader_parameter("reflet_fil", 0.0)
			mi.set_surface_override_material(s, mat)

static func _sans_squelette(m: Node3D) -> void:
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			mi.skeleton = NodePath("")

## Rotation qui couche une arme à plat : axe le plus mince de sa boîte -> vertical, le plus long -> le long de X.
static func _coucher(m: Node3D) -> Basis:
	var b := boite(m, Transform3D.IDENTITY)
	var t := b.size
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var ordre := [0, 1, 2]
	ordre.sort_custom(func(a: int, c: int) -> bool: return t[a] < t[c])
	var haut: Vector3 = axes[ordre[0]]       # le plus mince -> Y monde
	var long: Vector3 = axes[ordre[2]]       # le plus long -> X monde
	var x_l := long
	var y_l := haut
	var z_l := x_l.cross(y_l)
	# matrice dont les LIGNES sont les axes locaux : envoie long -> X, haut -> Y
	return Basis(Vector3(x_l.x, y_l.x, z_l.x), Vector3(x_l.y, y_l.y, z_l.y), Vector3(x_l.z, y_l.z, z_l.z))

## Boîte englobante (repère de `ref` appliqué au nœud) de toutes les MeshInstance3D sous `n`.
static func boite(n: Node3D, ref: Transform3D) -> AABB:
	var res := AABB()
	var premier := true
	var mailles: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		mailles.append(n)
	for mi: MeshInstance3D in mailles:
		if mi.mesh == null:
			continue
		var xf := ref * _vers(n, mi)
		var a := xf * mi.mesh.get_aabb()
		res = a if premier else res.merge(a)
		premier = false
	return res

static func _vers(haut: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != haut:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf

static func _poser_au_sol(racine: Node3D, pivot: Node3D) -> void:
	var b := boite(pivot, pivot.transform)
	pivot.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)

## Sacoche de cuir nouée (repli des objets sans modèle) : panse aplatie, goulot froncé, lien ; ~0,3 m, pivot au sol.
static var _mat_sac: ShaderMaterial
static func sacoche() -> Node3D:
	if _mat_sac == null:
		_mat_sac = BijouxMateriaux.materiaux()["cuir"].duplicate() as ShaderMaterial
		_mat_sac.set_shader_parameter("teinte", Color(1.25, 1.12, 0.95))
	var n := Node3D.new()
	n.name = "Sacoche"
	var specs := [
		[0.17, 0.2, Vector3(0, 0.1, 0), Vector3(1.0, 0.85, 0.9)],        # panse
		[0.07, 0.1, Vector3(0, 0.215, 0), Vector3(1.0, 1.0, 1.0)],       # goulot froncé
		[0.085, 0.05, Vector3(0, 0.27, 0), Vector3(1.0, 0.7, 1.0)],      # collerette
	]
	for s: Array in specs:
		var sm := SphereMesh.new()
		sm.radius = s[0]
		sm.height = s[1]
		sm.radial_segments = 9
		sm.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = _mat_sac
		mi.position = s[2]
		mi.scale = s[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	var lien := TorusMesh.new()
	lien.inner_radius = 0.058
	lien.outer_radius = 0.072
	lien.rings = 8
	lien.ring_segments = 4
	var ml := MeshInstance3D.new()
	ml.mesh = lien
	ml.material_override = BijouxMateriaux.materiaux()["bronze"]
	ml.position = Vector3(0, 0.235, 0)
	n.add_child(ml)
	return n

## Petits objets de boutique en primitives (pivot au sol) : fiole de verre teinté (rubis / saphir / jade du shader_matiere) bouchée de
## bois, livre relié de cuir (tranche claire), miche de seigle, lanières de viande séchée.
static func accessoire(oid: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Accessoire"
	var bm := BijouxMateriaux.materiaux()
	var em := EpeesLongues.materiaux()
	if oid.begins_with("potion_"):
		var verre: Material = bm["rubis"]
		if oid.contains("mana"):
			verre = bm["saphir"]
		elif oid.contains("endurance"):
			verre = bm["jade"]
		var forte := oid.contains("forte")
		var r := 0.05 if forte else 0.042
		_prim(n, _sphere(r, r * 2.0), verre, Vector3(0, r, 0))
		_prim(n, _cyl(r * 0.32, r * 0.38, r * 1.1), verre, Vector3(0, r * 2.2, 0))
		_prim(n, _cyl(r * 0.36, r * 0.3, r * 0.5), em["bois"], Vector3(0, r * 2.9, 0))
	elif oid.begins_with("tome_"):
		var cuir := (bm["cuir"] as ShaderMaterial).duplicate() as ShaderMaterial
		var teintes := {"feu": Color(1.5, 0.75, 0.6), "givre": Color(0.8, 1.0, 1.4), "glace": Color(0.8, 1.0, 1.4), "eclair": Color(1.2, 1.0, 1.5),
			"electricite": Color(1.2, 1.0, 1.5), "statique": Color(1.2, 1.0, 1.5), "tenebres": Color(0.8, 0.7, 0.9), "obscure": Color(0.8, 0.7, 0.9)}
		var t := Color(1.2, 1.0, 0.8)
		for k: String in teintes:
			if oid.contains(k):
				t = teintes[k]
		cuir.set_shader_parameter("teinte", t)
		_prim(n, _boite(Vector3(0.17, 0.045, 0.23)), cuir, Vector3(0, 0.0225, 0))
		_prim(n, _boite(Vector3(0.155, 0.034, 0.215)), em["planches"], Vector3(0.012, 0.0225, 0))      # tranche des pages
		_prim(n, _boite(Vector3(0.05, 0.005, 0.05)), bm["or"], Vector3(0, 0.0465, 0))                # fermoir / ornement
	elif oid == "pain_seigle":
		var croute := (em["bois"] as ShaderMaterial).duplicate() as ShaderMaterial
		croute.set_shader_parameter("teinte", Color(1.5, 1.15, 0.8))
		var mi := _prim(n, _sphere(0.09, 0.09), croute, Vector3(0, 0.045, 0))
		mi.scale = Vector3(1.3, 1.0, 0.9)
	else:
		var viande := (bm["cuir"] as ShaderMaterial).duplicate() as ShaderMaterial
		viande.set_shader_parameter("teinte", Color(1.4, 0.75, 0.65))
		for k in 3:
			var mi := _prim(n, _boite(Vector3(0.22, 0.014, 0.045)), viande, Vector3(0, 0.007 + k * 0.012, (k - 1) * 0.04))
			mi.rotation.y = (k - 1) * 0.25
	return n

static func _prim(n: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return mi

static func _sphere(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 5
	return m

static func _cyl(rh: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rh
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m

static func _boite(t: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = t
	return m

## Plusieurs objets côte à côte (tas d'un sac lâché, butin posé). Ordre stable (identifiants triés).
static func tas(contenu: Dictionary, pose := "sol", max_objets := MAX_TAS) -> Node3D:
	var r := Node3D.new()
	r.name = "Tas"
	var ids: Array = []
	for oid: String in contenu:
		if oid != "pieces" and int(contenu[oid]) > 0:
			ids.append(oid)
	ids.sort()
	var montres: Array = []
	var sac := false
	for oid: String in ids:
		if montres.size() < max_objets and a_modele(oid):
			montres.append(oid)
		else:
			sac = true
	if montres.is_empty():
		sac = true
	var places := montres.size() + (1 if sac else 0)
	var k := 0
	for oid: String in montres:
		var v := visuel(oid, pose, k + 1)
		v.position = _place(k, places)
		r.add_child(v)
		k += 1
	if sac:
		var s := sacoche()
		s.position = _place(k, places)
		r.add_child(s)
	return r

## Petite couronne autour du centre (1 objet = au centre).
static func _place(k: int, n: int) -> Vector3:
	if n <= 1:
		return Vector3.ZERO
	var a := TAU * k / n + 0.4
	var rr := 0.22 + 0.04 * n
	return Vector3(cos(a) * rr, 0.0, sin(a) * rr)

## Pièces d'un étal sur un plateau `largeur` x `profondeur` (centré en 0, dessus à y = 0 du parent) : rangement en ÉTAGÈRES (les plus
## longues d'abord, rangs du fond vers l'avant, chaque rang centré) ; une pièce qui ne tient plus sur le plateau n'est pas posée.
static func exposer(parent: Node3D, ids: Array, largeur: float, profondeur: float, pose := "etal") -> Array[Node3D]:
	var res: Array[Node3D] = []
	var items: Array = []
	for i in ids.size():
		var oid := String(ids[i])
		var v := visuel(oid, pose, 0)
		var t := boite(v, Transform3D.IDENTITY).size
		if t.z > t.x:                      # pièce longue (lame couchée le long de z) : tournée en travers du plateau
			v.rotation.y = PI * 0.5
			t = Vector3(t.z, t.y, t.x)
		items.append([v, t, i])
	items.sort_custom(func(a: Array, c: Array) -> bool: return (a[1] as Vector3).x > (c[1] as Vector3).x)
	var jeu := 0.04
	var limite := profondeur * 0.5 + 0.08          # un bord de bouclier peut dépasser du plateau
	var rangs: Array = []          # [[items], z du fond, profondeur du rang, largeur occupée]
	var z := -profondeur * 0.5
	for e: Array in items:
		var t: Vector3 = e[1]
		var place := false
		for r: Array in rangs:
			if float(r[3]) + jeu + t.x <= largeur and t.z <= float(r[2]) + 0.05:
				(r[0] as Array).append(e)
				r[3] = float(r[3]) + jeu + t.x
				place = true
				break
		if not place:
			if z + t.z <= limite:
				rangs.append([[e], z, t.z, t.x])
				z += t.z + jeu
			else:
				(e[0] as Node3D).free()            # ne tient plus sur le plateau
	# rangs les plus HAUTS au fond (bouclier, bottes), rangs plats (lames couchées) devant : rien n'en cache un autre
	for r: Array in rangs:
		var hmax := 0.0
		for e: Array in r[0]:
			hmax = maxf(hmax, (e[1] as Vector3).y)
		r.append(hmax)
	rangs.sort_custom(func(a: Array, c: Array) -> bool: return float(a[4]) > float(c[4]))
	z = -profondeur * 0.5
	for r: Array in rangs:
		r[1] = z
		z += float(r[2]) + jeu
	for r: Array in rangs:
		var x := -float(r[3]) * 0.5
		for e: Array in r[0]:
			var v: Node3D = e[0]
			var t: Vector3 = e[1]
			v.position = Vector3(x + t.x * 0.5, 0.0, float(r[1]) + float(r[2]) * 0.5)
			x += t.x + jeu
			parent.add_child(v)
			res.append(v)
	return res

## Les PAVÉS du village (RuesVillage : dalles de 2-5 cm bombées, SANS collision) suivent le MAILLAGE du terrain (triangles de 2 m),
## pas la hauteur exacte du sol physique : un objet posé au point du rayon y est noyé (jusqu'à ~15 cm sous les pavés). Hausse à
## ajouter à un point de sol physique `p` pour poser sur les pavés : maillage (comme RuesVillage._sol) + épaisseur des pavés - p.y.
## `monde` : le nœud Monde (hauteur, TAILLE, CASES) ; sans lui, une hausse fixe.
const HAUSSE_PAVES := 0.13
const DESSUS_PAVES := 0.13   # mesuré en jeu : le dessus rendu des pavés monte jusqu'à ~13 cm au-dessus du sol physique
static func hausse_sol(p: Vector3, monde: Node = null) -> float:
	if RuesVillage.profondeur_pave(Vector2(p.x, p.z)) <= -0.05:
		return 0.0
	var cst: Dictionary = monde.get_script().get_script_constant_map() if monde != null and monde.get_script() != null else {}
	if not monde.has_method("hauteur") or not cst.has("TAILLE") or not cst.has("CASES") if monde != null else true:
		return HAUSSE_PAVES
	var pas: float = float(cst["TAILLE"]) / float(cst["CASES"])
	var demi: float = float(cst["TAILLE"]) * 0.5
	var u := (p.x + demi) / pas
	var v := (p.z + demi) / pas
	var i := floori(u)
	var j := floori(v)
	var fu := u - i
	var fv := v - j
	var h := func(a: int, b: int) -> float: return float(monde.hauteur(a * pas - demi, b * pas - demi))
	var y: float
	if fu + fv <= 1.0:
		var ha: float = h.call(i, j)
		y = ha + (float(h.call(i + 1, j)) - ha) * fu + (float(h.call(i, j + 1)) - ha) * fv
	else:
		var hd: float = h.call(i + 1, j + 1)
		y = hd + (float(h.call(i, j + 1)) - hd) * (1.0 - fu) + (float(h.call(i + 1, j)) - hd) * (1.0 - fv)
	return maxf(0.0, y + DESSUS_PAVES - p.y)

## Objet ramassable posé (touche E « Prendre ») ; sans joueur / dialogue : simple décor.
static func creer(oid: String, n := 1, joueur: CharacterBody3D = null, dialogue: Control = null) -> ObjetMonde:
	var o := ObjetMonde.new()
	o.name = "ObjetMonde_" + oid
	o.id = oid
	o.nombre = n
	o.add_child(visuel(oid, "sol", 1))
	if joueur != null and dialogue != null:
		var it := Node3D.new()
		it.set_script(preload("res://scripts/interactif.gd"))
		it.joueur = joueur
		it.dialogue = dialogue
		it.nom = Inventaire.objet(oid).get("nom", oid) + ("" if n <= 1 else " (%d)" % n)
		it.verbe = "Prendre"
		it.rayon = 1.8
		it.unique = true
		it.action = func() -> Array:
			o.prendre(joueur.inventaire)
			return []
		it.position = Vector3(0, 0.15, 0)
		o.add_child(it)
		o._inter = it
	return o

## Met l'objet au sac (ButinTables.prendre : règle des uniques), puis disparaît.
func prendre(inv: Inventaire) -> Array[Dictionary]:
	var res := ButinTables.prendre(inv, [{"id": id, "n": nombre, "rarete": ButinTables.rarete_de(id)}])
	queue_free()
	return res
