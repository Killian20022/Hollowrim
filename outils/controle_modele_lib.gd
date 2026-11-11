class_name ControleModele
extends RefCounted
## CONTRÔLE AUTOMATIQUE d'un modèle rigué (PNJ / armure Tripo) AVANT de le montrer. Bibliothèque ; l'outil en ligne de commande est
## outils/controle_modele.gd, la documentation docs/CONTROLE_MODELE.md.
##   var c := ControleModele.new(racine, {"clips": ["Idle", "Walk"], "budget_tris": 12000})
##   var rapport: Dictionary = c.controler()      # rapport["ok"] : bool ; rapport["echecs"] : Array[String]
## Tout est calculé sur le CPU à partir du Skeleton3D (peau recalculée sommet par sommet, comme le GPU : sommets pondérés par les os) :
## aucune fenêtre, aucun rendu. Les clips sont posés os par os à partir des pistes de l'Animation (comme AnimationPlayer) ; les
## modificateurs du jeu (PoignetRepos, ressorts, IK des pieds...) NE sont PAS rejoués (voir docs/CONTROLE_MODELE.md, limites).

## Seuils par défaut (calibrés sur les modèles validés, docs/CONTROLE_MODELE.md). Tous remplaçables par les options.
const SEUILS := {
	"budget_tris": 12000,           # triangles visibles au total
	"eclat_faces": 12,              # composante connexe de moins de N faces = éclat
	"eclat_rayon": 0.15,            # (m) rayon autour de l'axe avant-bras/main de la zone « poignet » où un éclat est un ÉCHEC (ailleurs : avertissement)
	"etirement_max": 0.15,          # étirement de segment (os ou géométrie) pose / repos : au-delà = ÉCHEC
	"largeur_min": 0.6,             # rapport largeur main / largeur avant-bras : ÉCHEC hors [min ; max]
	"largeur_max": 1.4,
	"cible_min": 0.75,              # cible indicative (avertissement hors de la plage)
	"cible_max": 0.80,
	"ecart_max": 0.025,              # (m) écart sans géométrie entre brassard et main (le long de l'avant-bras) : au-delà = ÉCHEC
	"soudure": 0.0005,               # (m) tolérance de soudure des sommets pour les composantes et les trous
	"trou_perimetre": 0.03,         # (m) une boucle d'arêtes ouvertes plus petite que cela = trou
	"trous_max": 250,                 # nombre de trous tolérés
	"arme_paume_max": 0.10,         # (m) distance milieu de poignée -> paume
	"arme_angle_max": 85.0,         # (°) angle lame / avant-bras (sens ignoré, donc 0-90°) ; l'armure de verre tient la lame fléchie à ~78° en Idle
	# EXCEPTION, désactivée par défaut (--seuil.arme_skinnee=1) : arme SKINNÉE dans le maillage du corps sur l'os de la main (lance des
	# gardes lanciers Tripo, tripo_rig.py : 100 % hand_r). Sans elle, la hampe qui traverse la paume est mesurée comme de la main (rapport
	# main / avant-bras 4,53 : faux ÉCHEC). Voir _exclure_armes_skinnees ; aucun autre seuil n'est changé.
	"arme_skinnee": 0.0,
	"arme_skinnee_dist": 0.20,      # (m) sommet de main à plus de cela du segment poignet -> bout des doigts = hampe
	"arme_skinnee_rayon": 0.035,    # (m) rayon de la hampe autour de sa droite ajustée (la partie qui traverse la paume)
}
const GROUPES := ["haut", "avant", "main"]
## Centile du rapport d'arêtes pose / repos retenu par segment : médiane à l'épaule (le mélange de poids clavicule / bras y étire de 100 %
## les arêtes extrêmes des modèles validés), 75e centile à l'avant-bras et à la paume.
const Q_ETIREMENT := [0.5, 0.75, 0.75]      # segments de bras : épaule-coude, coude-poignet, poignet-main

var racine: Node3D
var sq: Skeleton3D
var opts: Dictionary
var pieces: Array = []          # {nom, mi, rigide(bool), os(int, rigide), xf(Transform3D rigide), arme(bool), V, T, B, W, K, bind_os, bind_pose, debut(int), n(int)}
var nb_sommets := 0
var tri_global := PackedInt32Array()       # indices globaux (3 par triangle)
var tri_piece := PackedInt32Array()        # pièce de chaque triangle
var groupe := PackedInt32Array()           # par sommet : cote*3 + segment, -1 sinon
var dominant := PackedInt32Array()         # par sommet : os dominant
var os_bras := {}                          # "l"/"r" -> {haut, avant, main, bout}
var groupe_de_os := {}                     # os -> cote*3+segment
var anims: Dictionary = {}                 # nom -> Animation
var avert: Array = []
var _est_arme := PackedByteArray()
var _est_poing := PackedByteArray()
var _hampe := PackedByteArray()          # hampe d'une arme skinnée sur la main (--seuil.arme_skinnee) : hors largeur de main

func _init(r: Node3D, o := {}) -> void:
	racine = r
	opts = o
	sq = r.find_child("Skeleton3D", true, false) as Skeleton3D

func seuil(nom: String) -> Variant:
	return opts.get(nom, SEUILS[nom])

## Charge un modèle : « garde:<id> » (GardeTripo.creer), « dore » (armure dorée du garde halle_e), fichier .glb/.gltf (lu sans import,
## n'importe où sur le disque), sinon ressource res:// (.tscn / .glb importé).
static func charger(spec: String) -> Node3D:
	if spec.begins_with("garde:"):
		return GardeTripo.creer(spec.substr(6), false, false)
	if spec == "dore":
		return GardesVillage.creer_modele_dore({})
	if spec.get_extension().to_lower() in ["glb", "gltf"] and not spec.begins_with("res://"):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(spec, st) != OK:
			return null
		return doc.generate_scene(st) as Node3D
	var res := load(spec)
	if res is PackedScene:
		return (res as PackedScene).instantiate() as Node3D
	return null

# ===================================================================== collecte des pièces

func _visible(n: Node) -> bool:
	var c: Node = n
	while c != null and c != racine.get_parent():
		if c is Node3D and not (c as Node3D).visible:
			return false
		c = c.get_parent()
	return true

## Arme : pièce rigide dont un nœud entre elle et son BoneAttachment3D porte un nom d'arme (EpeeJeu, EpeeMain, Lance...).
func _nom_arme(n: Node, att: Node) -> bool:
	if att == null:
		return false
	var c: Node = n
	while c != null and c != att.get_parent():
		var nm := String(c.name).to_lower()
		if nm.contains("poing") or nm.contains("gantelet"):      # poing fermé / gantelet porté avec l'arme : fait partie de la main
			return false
		if nm.contains("epee") or nm.contains("sword") or nm.begins_with("arme") or nm.contains("lance") or nm.contains("arc_"):
			return true
		c = c.get_parent()
	return false

func _nom_poing(n: Node, att: Node) -> bool:
	var c: Node = n
	while att != null and c != null and c != att.get_parent():
		if String(c.name).to_lower().contains("poing"):
			return true
		c = c.get_parent()
	return false

func collecter() -> void:
	pieces.clear()
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not _visible(mi):
			continue
		# rigide : sous un BoneAttachment3D ; sinon peau (squelette de la racine)
		var att: BoneAttachment3D = null
		var xf := Transform3D.IDENTITY
		var c: Node = mi
		while c != null and c != racine:
			if c is BoneAttachment3D:
				att = c as BoneAttachment3D
				break
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		var p := {"nom": String(mi.name), "mi": mi, "rigide": att != null, "arme": _nom_arme(mi, att), "poing": _nom_poing(mi, att), "os": -1, "xf": xf}
		if att != null:
			p["os"] = sq.find_bone(att.bone_name)
			if p["os"] < 0:
				continue
		elif mi.skin == null and mi.get_node_or_null(mi.skeleton) != sq:
			continue
		_extraire(p, mi)
		if p["V"].size() > 0:
			pieces.append(p)
	# tableaux globaux
	nb_sommets = 0
	tri_global = PackedInt32Array()
	tri_piece = PackedInt32Array()
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		p["debut"] = nb_sommets
		nb_sommets += (p["V"] as PackedVector3Array).size()
		for t in (p["T"] as PackedInt32Array):
			tri_global.append(p["debut"] + t)
		for k in (p["T"] as PackedInt32Array).size() / 3:
			tri_piece.append(i)
	_os_des_bras()
	_groupes()

func _extraire(p: Dictionary, mi: MeshInstance3D) -> void:
	var V := PackedVector3Array()
	var T := PackedInt32Array()
	var lignes: Array = []
	var K := 0
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var base := V.size()
		V.append_array(v)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).size() == 0:
			for i in v.size():
				T.append(base + i)
		else:
			for i: int in (idx as PackedInt32Array):
				T.append(base + i)
		var b: Variant = a[Mesh.ARRAY_BONES]
		var w: Variant = a[Mesh.ARRAY_WEIGHTS]
		var k := 0
		if b != null and (b as PackedInt32Array).size() > 0:
			k = (b as PackedInt32Array).size() / maxi(v.size(), 1)
		lignes.append({"n": v.size(), "k": k, "b": b, "w": w})
		K = maxi(K, k)
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	if not p["rigide"] and K > 0:
		B.resize(V.size() * K)
		W.resize(V.size() * K)
		var o := 0
		for l in lignes:
			var k: int = l["k"]
			for i in int(l["n"]):
				for q in K:
					if q < k:
						B[(o + i) * K + q] = (l["b"] as PackedInt32Array)[i * k + q]
						W[(o + i) * K + q] = (l["w"] as PackedFloat32Array)[i * k + q]
			o += int(l["n"])
		var skin := mi.skin if mi.skin != null else sq.create_skin_from_rest_transforms()
		var nb := skin.get_bind_count()
		var bos := PackedInt32Array()
		var bps: Array[Transform3D] = []
		for i in nb:
			var ib := skin.get_bind_bone(i)
			if ib < 0:
				ib = sq.find_bone(skin.get_bind_name(i))
			bos.append(ib)
			bps.append(skin.get_bind_pose(i))
		p["bind_os"] = bos
		p["bind_pose"] = bps
	p["V"] = V
	p["T"] = T
	p["B"] = B
	p["W"] = W
	p["K"] = K

func _os_des_bras() -> void:
	os_bras.clear()
	for c in ["l", "r"]:
		var d := {"haut": sq.find_bone("upperarm_" + c), "avant": sq.find_bone("lowerarm_" + c), "main": sq.find_bone("hand_" + c), "bout": -1}
		if d["haut"] < 0 or d["avant"] < 0 or d["main"] < 0:
			continue
		d["bout"] = sq.find_bone("middle_01_" + c)      # base du majeur : longueur de main constante quand les doigts se plient
		os_bras[c] = d

func _groupes() -> void:
	groupe_de_os.clear()
	var cotes := ["l", "r"]
	for ci in 2:
		if not os_bras.has(cotes[ci]):
			continue
		var d: Dictionary = os_bras[cotes[ci]]
		groupe_de_os[d["haut"]] = ci * 3
		groupe_de_os[d["avant"]] = ci * 3 + 1
		for i in sq.get_bone_count():      # la main et tous ses doigts
			var j := i
			while j >= 0 and j != d["main"]:
				j = sq.get_bone_parent(j)
			if j == d["main"]:
				groupe_de_os[i] = ci * 3 + 2

# ===================================================================== peau CPU

## Poses globales recalculées ici (parent * pose locale) : get_bone_global_pose() de Skeleton3D renvoie une base SANS l'échelle propre
## de l'os après un reset_bone_poses (cache), ce qui masquerait les étirements par échelle.
var _glob: Array[Transform3D] = []
func gp(i: int) -> Transform3D:
	return _glob[i]
func _recalculer_globales() -> void:
	var n := sq.get_bone_count()
	_glob.resize(n)
	var fait := PackedByteArray()
	fait.resize(n)
	for i in n:
		var chaine: Array = []
		var j := i
		while j >= 0 and fait[j] == 0:
			chaine.append(j)
			j = sq.get_bone_parent(j)
		for k in range(chaine.size() - 1, -1, -1):
			var b: int = chaine[k]
			var par := sq.get_bone_parent(b)
			_glob[b] = (_glob[par] if par >= 0 else Transform3D.IDENTITY) * sq.get_bone_pose(b)
			fait[b] = 1

func poser_neutre() -> void:
	sq.reset_bone_poses()
	_recalculer_globales()

## Pose le squelette sur l'Animation à l'instant t (pistes de rotation / position / échelle des os).
func poser_clip(a: Animation, t: float, nom := "") -> void:
	sq.reset_bone_poses()
	for tr in a.get_track_count():
		var ty := a.track_get_type(tr)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		if not a.track_is_enabled(tr):
			continue
		var i := sq.find_bone(String(a.track_get_path(tr)).get_slice(":", 1))
		if i < 0:
			continue
		match ty:
			Animation.TYPE_ROTATION_3D:
				sq.set_bone_pose_rotation(i, a.rotation_track_interpolate(tr, t))
			Animation.TYPE_POSITION_3D:
				sq.set_bone_pose_position(i, a.position_track_interpolate(tr, t))
			Animation.TYPE_SCALE_3D:
				sq.set_bone_pose_scale(i, a.scale_track_interpolate(tr, t))
	# PoignetRepos (armure de verre) : poignet fléchi hors des clips Sword_* ; seul modificateur du jeu rejoué ici
	var pr := racine.find_child("PoignetRepos", true, false)
	if pr != null and not nom.begins_with("Sword_") and pr.get("os_main") != null and int(pr.get("os_main")) >= 0:
		var im: int = pr.get("os_main")
		sq.set_bone_pose_rotation(im, sq.get_bone_pose_rotation(im) * Quaternion(GardeTripo.POIGNET_AXE.normalized(), deg_to_rad(GardeTripo.POIGNET_REPOS_DEG)))
	_recalculer_globales()

## Sommets de TOUTES les pièces dans l'espace du squelette, pour la pose courante.
func sommets_poses() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(nb_sommets)
	for p: Dictionary in pieces:
		var V: PackedVector3Array = p["V"]
		var d: int = p["debut"]
		if p["rigide"]:
			var m: Transform3D = gp(p["os"]) * (p["xf"] as Transform3D)
			for i in V.size():
				out[d + i] = m * V[i]
			continue
		var bos: PackedInt32Array = p["bind_os"]
		var bps: Array = p["bind_pose"]
		var mats: Array[Transform3D] = []
		for i in bos.size():
			mats.append(gp(bos[i]) * (bps[i] as Transform3D) if bos[i] >= 0 else Transform3D.IDENTITY)
		var K: int = p["K"]
		var B: PackedInt32Array = p["B"]
		var W: PackedFloat32Array = p["W"]
		for i in V.size():
			if K == 0:
				out[d + i] = V[i]
				continue
			var acc := Vector3.ZERO
			var sw := 0.0
			for q in K:
				var w := W[i * K + q]
				if w > 0.0:
					acc += (mats[B[i * K + q]] * V[i]) * w
					sw += w
			out[d + i] = acc / sw if sw > 1e-6 else V[i]
	return out

## Os dominant de chaque sommet (pièces rigides : leur os d'attache) et groupe de bras.
func calculer_groupes() -> void:
	dominant = PackedInt32Array()
	dominant.resize(nb_sommets)
	groupe = PackedInt32Array()
	groupe.resize(nb_sommets)
	_est_arme = PackedByteArray()
	_est_arme.resize(nb_sommets)
	_hampe = PackedByteArray()
	_hampe.resize(nb_sommets)
	_est_poing = PackedByteArray()
	_est_poing.resize(nb_sommets)
	for p: Dictionary in pieces:
		var d: int = p["debut"]
		var n := (p["V"] as PackedVector3Array).size()
		for i in n:
			var os := -1
			if p["rigide"]:
				os = p["os"]
			elif p["K"] > 0:
				var K: int = p["K"]
				var best := -1.0
				for q in K:
					var w: float = p["W"][i * K + q]
					if w > best:
						best = w
						os = (p["bind_os"] as PackedInt32Array)[(p["B"] as PackedInt32Array)[i * K + q]]
			dominant[d + i] = os
			groupe[d + i] = int(groupe_de_os.get(os, -1))
			if p["arme"]:
				groupe[d + i] = -1
				_est_arme[d + i] = 1
			if p["poing"]:
				_est_poing[d + i] = 1

## EXCEPTION --seuil.arme_skinnee=1 (lance des gardes lanciers Tripo, fondue dans le maillage et skinnée à 100 % sur hand_r ; la main
## fait partie du même îlot que la hampe, on ne peut donc pas exclure par composante). Par côté : les sommets dominés par un os de main à
## plus de `arme_skinnee_dist` du segment poignet -> bout des doigts (base du majeur prolongée d'une paume) sont la hampe (une main n'en
## sort pas) ; une droite est ajustée sur eux (axe principal) et tout sommet de main à moins de `arme_skinnee_rayon` de cette droite en fait
## partie aussi (la hampe qui traverse la paume). Ces sommets sont exclus de la SEULE mesure de largeur de la main (rapport main /
## avant-bras) ; éclats, continuité, étirement et budget restent mesurés sur tout le maillage, hampe comprise. Le nombre est rapporté en
## avertissement. Les seuils globaux ne changent pas.
func _exclure_armes_skinnees(pos: PackedVector3Array) -> void:
	var lim: float = seuil("arme_skinnee_dist")
	var ray: float = seuil("arme_skinnee_rayon")
	for ci in 2:
		var c: String = ["l", "r"][ci]
		if not os_bras.has(c):
			continue
		var d: Dictionary = os_bras[c]
		var pw := _pos_os(d["main"])
		var pb := _pos_os(d["bout"]) if d["bout"] >= 0 else pw
		var ax := (pb + (pb - pw)) - pw
		var loin: Array[int] = []
		var main: Array[int] = []
		for i in nb_sommets:
			if groupe[i] != ci * 3 + 2:
				continue
			main.append(i)
			var t := clampf((pos[i] - pw).dot(ax) / maxf(ax.length_squared(), 1e-8), 0.0, 1.0)
			if pos[i].distance_to(pw + ax * t) > lim:
				loin.append(i)
		if loin.size() < 10:
			continue
		var cg := Vector3.ZERO
		for i in loin:
			cg += pos[i]
		cg /= loin.size()
		var u := Vector3.ZERO      # axe principal (itérations de puissance sur la covariance)
		for i in loin:
			var q := pos[i] - cg
			if q.length() > u.length():
				u = q
		u = u.normalized()
		for it in 12:
			var nu := Vector3.ZERO
			for i in loin:
				var q := pos[i] - cg
				nu += q * q.dot(u)
			if nu.length() < 1e-9:
				break
			u = nu.normalized()
		# rayon réel de la hampe : médiane de la distance des sommets « loin » à la droite (+ 4 mm ; lance du garde : 2,5 cm -> 2,9), plafonné par arme_skinnee_rayon,
		# pour ne pas avaler la paume qui l'entoure
		var dl := PackedFloat32Array()
		for i in loin:
			var q := pos[i] - cg
			dl.append((q - u * q.dot(u)).length())
		var rh := minf(ray, _pct(dl, 0.5) + 0.004)
		var n := 0
		for i in main:
			var q := pos[i] - cg
			if (q - u * q.dot(u)).length() < rh or loin.has(i):
				_hampe[i] = 1
				n += 1
		avert.append("bras %s : arme skinnée sur la main (--seuil.arme_skinnee) : %d sommets (hampe à %d sommets hors de la main, rayon %.1f cm) exclus de la largeur de main (rien d'autre ne change)" % [c, n, loin.size(), rh * 100])

# ===================================================================== utilitaires

static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(roundi(q * (b.size() - 1)), 0, b.size() - 1)]

static func _dir(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	return d.normalized() if d.length() > 1e-6 else Vector3.UP

func _pos_os(i: int) -> Vector3:
	return gp(i).origin

# ===================================================================== volets

## Triangles visibles (hors armes) et budget.
func controle_tris() -> Dictionary:
	var total := 0
	var par_piece := {}
	for p: Dictionary in pieces:
		var n := (p["T"] as PackedInt32Array).size() / 3
		par_piece[p["nom"]] = n
		if not p["arme"]:
			total += n
	var budget: int = seuil("budget_tris")
	return {"total": total, "budget": budget, "ok": total <= budget, "pieces": par_piece}

## Composantes connexes (sommets soudés par position) au repos : éclats, trous (boucles d'arêtes ouvertes minuscules).
var _uf := PackedInt32Array()
func _trouver(x: int) -> int:
	while _uf[x] != x:
		_uf[x] = _uf[_uf[x]]
		x = _uf[x]
	return x

## Zone « poignet » (là où les défauts se voient de près) : de la moitié de l'avant-bras à 0,8 longueur de paume après le poignet,
## à moins de `eclat_rayon` de l'axe coude -> poignet -> base du majeur. Le coude (pli de l'articulation) et le bout des doigts sont exclus.
func _zone_poignet(p: Vector3) -> bool:
	for c in os_bras:
		var d: Dictionary = os_bras[c]
		var pe := _pos_os(d["avant"])
		var pw := _pos_os(d["main"])
		var pb := _pos_os(d["bout"])
		var Lf := pe.distance_to(pw)
		var Lh := pw.distance_to(pb)
		var a1 := _dir(pe, pw)
		var s := (p - pe).dot(a1)
		if s < 0.5 * Lf or s > Lf + 0.8 * Lh:
			continue
		var axe := _dir(pw, pb) if s > Lf else a1
		var o := pe if s <= Lf else pw
		var rad := ((p - o) - axe * (p - o).dot(axe)).length()
		if rad <= float(seuil("eclat_rayon")):
			return true
	return false

func controle_composantes(pos: PackedVector3Array) -> Dictionary:
	var nf_max: int = seuil("eclat_faces")
	var pas := 1.0 / float(seuil("soudure"))
	var soude := {}                # clé de position -> id soudé
	var id_v := PackedInt32Array()
	id_v.resize(nb_sommets)
	for i in nb_sommets:
		var p := pos[i]
		var cle := Vector3i(roundi(p.x * pas), roundi(p.y * pas), roundi(p.z * pas))
		if not soude.has(cle):
			soude[cle] = soude.size()
		id_v[i] = soude[cle]
	var n := soude.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	_uf = parent
	var nt := tri_global.size() / 3
	for t in nt:
		var a: int = id_v[tri_global[t * 3]]
		var b: int = id_v[tri_global[t * 3 + 1]]
		var c: int = id_v[tri_global[t * 3 + 2]]
		_uf[_trouver(b)] = _trouver(a)
		_uf[_trouver(c)] = _trouver(a)
	# faces, boîte, pièce par composante (les armes sont ignorées)
	var comp := {}
	var aretes := {}               # (a,b) triés -> nombre de faces
	for t in nt:
		if pieces[tri_piece[t]]["arme"]:
			continue
		var i0 := tri_global[t * 3]
		var r: int = _trouver(id_v[i0])
		if not comp.has(r):
			comp[r] = {"faces": 0, "min": pos[i0], "max": pos[i0], "piece": pieces[tri_piece[t]]["nom"], "somme": Vector3.ZERO, "nsom": 0, "os": {}}
		var d: Dictionary = comp[r]
		d["faces"] += 1
		for k in 3:
			var iv := tri_global[t * 3 + k]
			d["min"] = (d["min"] as Vector3).min(pos[iv])
			d["max"] = (d["max"] as Vector3).max(pos[iv])
			d["somme"] += pos[iv]
			d["nsom"] += 1
			var os: int = dominant[iv]
			d["os"][os] = int(d["os"].get(os, 0)) + 1
			var a: int = id_v[iv]
			var b: int = id_v[tri_global[t * 3 + (k + 1) % 3]]
			var ck := Vector2i(mini(a, b), maxi(a, b))
			aretes[ck] = int(aretes.get(ck, 0)) + 1
	# os de bras / main pour mesurer la proximité des éclats
	var os_zone: Array = []
	for c in os_bras:
		for k in ["avant", "main", "bout"]:
			if os_bras[c][k] >= 0:
				os_zone.append(os_bras[c][k])
	var liste: Array = []
	var eclats: Array = []
	for r in comp:
		var d: Dictionary = comp[r]
		var centre: Vector3 = d["somme"] / maxi(int(d["nsom"]), 1)
		var os_nom := ""
		var best := -1
		for os in d["os"]:
			if int(d["os"][os]) > best:
				best = int(d["os"][os])
				os_nom = sq.get_bone_name(os) if os >= 0 else "?"
		var dist_zone := 1e9
		for io: int in os_zone:
			dist_zone = minf(dist_zone, centre.distance_to(_pos_os(io)))
		var en_zone := _zone_poignet(centre)
		var e := {"faces": d["faces"], "centre": _v(centre), "taille": _v((d["max"] as Vector3) - (d["min"] as Vector3)), "os": os_nom, "piece": d["piece"], "distance_main_avant_bras": snappedf(dist_zone, 0.001), "zone_poignet": en_zone}
		liste.append(e)
		if int(d["faces"]) < nf_max:
			eclats.append(e)
	liste.sort_custom(func(a, b): return a["faces"] > b["faces"])
	eclats.sort_custom(func(a, b): return a["faces"] < b["faces"])
	var eclats_proches: Array = eclats.filter(func(e): return e["zone_poignet"])
	# trous : boucles d'arêtes ouvertes (une seule face) plus petites que le seuil de périmètre
	var ouvertes := {}
	var pos_soude := {}
	for i in nb_sommets:
		pos_soude[id_v[i]] = pos[i]
	for ck: Vector2i in aretes:
		if aretes[ck] == 1:
			if not ouvertes.has(ck.x):
				ouvertes[ck.x] = []
			if not ouvertes.has(ck.y):
				ouvertes[ck.y] = []
			ouvertes[ck.x].append(ck.y)
			ouvertes[ck.y].append(ck.x)
	var vus := {}
	var petits_trous: Array = []
	var nb_boucles := 0
	var per_max: float = seuil("trou_perimetre")
	for s in ouvertes:
		if vus.has(s):
			continue
		var pile := [s]
		vus[s] = true
		var per := 0.0
		var cc := Vector3.ZERO
		var nn := 0
		while not pile.is_empty():
			var x: int = pile.pop_back()
			cc += pos_soude[x]
			nn += 1
			for y: int in ouvertes[x]:
				per += (pos_soude[x] as Vector3).distance_to(pos_soude[y]) * 0.5
				if not vus.has(y):
					vus[y] = true
					pile.append(y)
		nb_boucles += 1
		if per < per_max and nn >= 3:
			petits_trous.append({"perimetre": snappedf(per, 0.001), "centre": _v(cc / nn)})
	var non_manifold := 0
	for ck in aretes:
		if aretes[ck] > 2:
			non_manifold += 1
	return {"composantes": comp.size(), "faces_min": liste.back()["faces"] if not liste.is_empty() else 0,
		"petites": liste.filter(func(e): return e["faces"] < nf_max * 3).slice(0, 25), "eclats": eclats, "eclats_proches": eclats_proches,
		"bords_ouverts_boucles": nb_boucles, "petits_trous": petits_trous, "aretes_non_manifold": non_manifold,
		"ok": eclats_proches.is_empty() and petits_trous.size() <= int(seuil("trous_max"))}

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

## Longueurs des segments d'un bras pour la pose courante : sur les os et sur la géométrie (étendue des sommets pondérés vers l'os).
## Diamètre de Feret maximal (12 directions) d'un nuage de points dans le plan perpendiculaire à l'axe a.
static func _feret(pts: Array, a: Vector3) -> float:
	if pts.size() < 3:
		return 0.0
	var u := a.cross(Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var v := a.cross(u)
	var w := 0.0
	for k in 12:
		var ang := PI * k / 12.0
		var dir := u * cos(ang) + v * sin(ang)
		var pr := PackedFloat32Array()
		for q: Vector3 in pts:
			pr.append(q.dot(dir))
		w = maxf(w, _pct(pr, 0.99) - _pct(pr, 0.01))
	return w

func mesures_bras(cote: String, pos: PackedVector3Array) -> Dictionary:
	var d: Dictionary = os_bras[cote]
	var ci := 0 if cote == "l" else 1
	var ph := _pos_os(d["haut"])
	var pe := _pos_os(d["avant"])
	var pw := _pos_os(d["main"])
	var pb := _pos_os(d["bout"]) if d["bout"] >= 0 else pw + _dir(pe, pw) * 0.08
	var axes := [_dir(ph, pe), _dir(pe, pw), _dir(pw, pb)]
	var orig := [ph, pe, pw]
	var os_long := [ph.distance_to(pe), pe.distance_to(pw), pw.distance_to(pb)]
	var geo := []
	var larg := []
	for g in 3:
		var ts := PackedFloat32Array()
		for i in nb_sommets:
			if groupe[i] == ci * 3 + g and (g < 2 or dominant[i] == d["main"]):
				ts.append((pos[i] - (orig[g] as Vector3)).dot(axes[g]))
		geo.append(_pct(ts, 0.98) - _pct(ts, 0.02) if ts.size() > 3 else 0.0)
	# largeurs (diamètre de Feret max dans le plan perpendiculaire à l'axe) : avant-bras (milieu), main (corps de la main, sans les doigts)
	for g in [1, 2]:
		var a: Vector3 = axes[g]
		var u := a.cross(Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
		var v := a.cross(u)
		var L: float = os_long[g]
		var lo := 0.35 * L if g == 1 else 0.15 * L
		var hi := 0.65 * L if g == 1 else 0.60 * L
		var pts: Array = []
		for i in nb_sommets:
			if g == 1 and groupe[i] != ci * 3 + 1:
				continue
			if g == 2 and groupe[i] != ci * 3 + 1 and groupe[i] != ci * 3 + 2:      # poing lié à l'avant-bras (gardes à l'épée) compris
				continue
			if g == 2 and _hampe[i] == 1:
				continue
			var s := (pos[i] - (orig[g] as Vector3)).dot(a)
			if s >= lo and s <= hi:
				pts.append(pos[i])
		var deduite := false
		if g == 2 and pts.size() < 3:
			# main absente à l'emplacement de l'os (poing plein des gardes à l'épée, lié à l'avant-bras et plus court que l'os) :
			# on mesure l'extrémité distale de la géométrie du bras (6 cm avant son bout)
			var ss := PackedFloat32Array()
			for i in nb_sommets:
				if groupe[i] == ci * 3 + 1 or groupe[i] == ci * 3 + 2:
					ss.append((pos[i] - pe).dot(axes[1]))
			var fin_d := _pct(ss, 0.98)
			for i in nb_sommets:
				if (groupe[i] == ci * 3 + 1 or groupe[i] == ci * 3 + 2) and (pos[i] - pe).dot(axes[1]) >= fin_d - 0.06:
					pts.append(pos[i])
			deduite = true
		var w := 0.0
		if pts.size() >= 3:
			for k in 12:
				var ang := PI * k / 12.0
				var dir := u * cos(ang) + v * sin(ang)
				var pr := PackedFloat32Array()
				for q: Vector3 in pts:
					pr.append(q.dot(dir))
				w = maxf(w, _pct(pr, 0.99) - _pct(pr, 0.01))
		larg.append(w)
		if deduite:
			avert.append("bras %s : main mesurée à l'extrémité de l'avant-bras (pas de géométrie sur l'os de main)" % cote)
	# effilement de l'avant-bras (« tige ») : largeur près du poignet (70-95 % de l'os) / largeur près du coude (5-30 %)
	var tr_coude: Array = []
	var tr_poignet: Array = []
	for i in nb_sommets:
		if groupe[i] != ci * 3 + 1:
			continue
		var f := (pos[i] - pe).dot(axes[1]) / maxf(os_long[1], 1e-6)
		if f >= 0.05 and f <= 0.30:
			tr_coude.append(pos[i])
		elif f >= 0.70 and f <= 0.95:
			tr_poignet.append(pos[i])
	var w_coude := _feret(tr_coude, axes[1])
	var w_poignet := _feret(tr_poignet, axes[1])
	# continuité : couverture des triangles du bras (avant-bras + main) le long de l'axe coude -> poignet -> bout des doigts
	var Lf: float = os_long[1]
	var a1: Vector3 = axes[1]
	var a2: Vector3 = axes[2]
	var ints: Array = []
	var nt := tri_global.size() / 3
	for t in nt:
		var gs := [groupe[tri_global[t * 3]], groupe[tri_global[t * 3 + 1]], groupe[tri_global[t * 3 + 2]]]
		var ok := false
		for gg: int in gs:
			if gg == ci * 3 + 1 or gg == ci * 3 + 2:
				ok = true
		if not ok:
			continue
		var smin := 1e9
		var smax := -1e9
		for k in 3:
			var q := pos[tri_global[t * 3 + k]]
			var s1 := (q - pe).dot(a1)
			var s := s1 if s1 < Lf else Lf + (q - pw).dot(a2)
			smin = minf(smin, s)
			smax = maxf(smax, s)
		ints.append(Vector2(smin, smax))
	ints.sort_custom(func(a, b): return a.x < b.x)
	var fin := -1e9
	var ecart := 0.0
	var ecart_a := 0.0
	for iv: Vector2 in ints:
		if fin > -1e8 and iv.x - fin > ecart:
			ecart = iv.x - fin
			ecart_a = fin
		fin = maxf(fin, iv.y)
	return {"os": os_long, "geo": geo, "largeur_avant": larg[0], "largeur_main": larg[1], "largeur_coude": w_coude, "largeur_poignet": w_poignet, "ecart": ecart, "ecart_a": ecart_a}

## Arêtes internes à un segment de bras (haut / avant / main = paume seule) : {a, b, l0 (repos), seg}.
func _aretes_bras(cote: String, pos0: PackedVector3Array) -> Dictionary:
	var ci := 0 if cote == "l" else 1
	var main: int = os_bras[cote]["main"]
	var vus := {}
	var A := PackedInt32Array()
	var B := PackedInt32Array()
	var L0 := PackedFloat32Array()
	var SEG := PackedInt32Array()
	for t in tri_global.size() / 3:
		for k in 3:
			var a := tri_global[t * 3 + k]
			var b := tri_global[t * 3 + (k + 1) % 3]
			var g := groupe[a] - ci * 3
			if g < 0 or g > 2 or groupe[b] != groupe[a]:
				continue
			if g == 2 and (dominant[a] != main or dominant[b] != main):
				continue
			var cle := mini(a, b) * nb_sommets + maxi(a, b)
			if vus.has(cle):
				continue
			vus[cle] = true
			var l := pos0[a].distance_to(pos0[b])
			if l < 0.001:
				continue
			A.append(a)
			B.append(b)
			L0.append(l)
			SEG.append(g)
	return {"a": A, "b": B, "l0": L0, "seg": SEG}

## Étirement local des arêtes de chaque segment : centile Q_ETIREMENT du rapport pose / repos, moins 1 (plus grand sur les 3 segments).
func _etirement_aretes(ed: Dictionary, pos: PackedVector3Array) -> Dictionary:
	var r_h := PackedFloat32Array()
	var r_a := PackedFloat32Array()
	var r_m := PackedFloat32Array()
	var rat: Array = [r_h, r_a, r_m]
	var A: PackedInt32Array = ed["a"]
	var B: PackedInt32Array = ed["b"]
	var L0: PackedFloat32Array = ed["l0"]
	var SEG: PackedInt32Array = ed["seg"]
	for i in A.size():
		var r := pos[A[i]].distance_to(pos[B[i]]) / L0[i]
		match SEG[i]:
			0: r_h.append(r)
			1: r_a.append(r)
			_: r_m.append(r)
	rat = [r_h, r_a, r_m]
	var best := 0.0
	var seg := ""
	for g in 3:
		if (rat[g] as PackedFloat32Array).size() < 10:
			continue
		var e := _pct(rat[g], Q_ETIREMENT[g]) - 1.0
		if e > best:
			best = e
			seg = GROUPES[g]
	return {"e": best, "seg": seg}

func controle_bras(clips: Array, nb_images: int) -> Dictionary:
	var res := {}
	for cote in os_bras:
		poser_neutre()
		var pos0 := sommets_poses()
		var ed := _aretes_bras(cote, pos0)
		var m0 := mesures_bras(cote, pos0)
		var rapport := {"repos": _arrondi(m0), "poses": [], "etirement_os_max": 0.0, "etirement_geo_max": 0.0, "echecs": [], "avert": []}
		var worst_ecart: float = m0["ecart"]
		var w_os := 0.0
		var w_geo := 0.0
		var w_nom := ""
		for nom: String in clips:
			if not anims.has(nom):
				continue
			var a: Animation = anims[nom]
			for k in nb_images:
				var t := a.length * float(k) / float(maxi(nb_images, 1))
				poser_clip(a, t, nom)
				var pos := sommets_poses()
				var m := mesures_bras(cote, pos)
				var e_os := 0.0
				for g in 3:
					e_os = maxf(e_os, absf(float(m["os"][g]) / maxf(float(m0["os"][g]), 1e-6) - 1.0))
				var ea := _etirement_aretes(ed, pos)
				var e_geo: float = ea["e"]
				var seg: String = ea["seg"]
				worst_ecart = maxf(worst_ecart, m["ecart"])
				if e_os > w_os:
					w_os = e_os
				if e_geo > w_geo:
					w_geo = e_geo
					w_nom = "%s@%.2fs, segment %s" % [nom, t, seg]
				rapport["poses"].append({"clip": nom, "t": snappedf(t, 0.01), "etirement_os": snappedf(e_os, 0.001), "etirement_geo": snappedf(e_geo, 0.001), "ecart": snappedf(m["ecart"], 0.001)})
		poser_neutre()
		rapport["etirement_os_max"] = snappedf(w_os, 0.001)
		rapport["etirement_geo_max"] = snappedf(w_geo, 0.001)
		rapport["etirement_geo_pose"] = w_nom
		rapport["ecart_max"] = snappedf(worst_ecart, 0.001)
		var et: float = seuil("etirement_max")
		if w_os > et:
			rapport["echecs"].append("bras %s : os étirés de %.0f %% (max %.0f %%)" % [cote, w_os * 100, et * 100])
		if w_geo > et:
			rapport["echecs"].append("bras %s : géométrie étirée de %.0f %% en %s (max %.0f %%)" % [cote, w_geo * 100, w_nom, et * 100])
		var rl := 0.0
		if float(m0["largeur_avant"]) > 1e-4:
			rl = float(m0["largeur_main"]) / float(m0["largeur_avant"])
		rapport["rapport_largeur"] = snappedf(rl, 0.001)
		if rl < float(seuil("largeur_min")) or rl > float(seuil("largeur_max")):
			rapport["echecs"].append("bras %s : largeur main / avant-bras = %.2f (hors %.2f-%.2f)" % [cote, rl, seuil("largeur_min"), seuil("largeur_max")])
		elif rl < float(seuil("cible_min")) or rl > float(seuil("cible_max")):
			rapport["avert"].append("bras %s : largeur main / avant-bras = %.2f (cible %.2f-%.2f)" % [cote, rl, seuil("cible_min"), seuil("cible_max")])
		if worst_ecart > float(seuil("ecart_max")):
			rapport["echecs"].append("bras %s : %.1f cm sans géométrie entre brassard et main (max %.1f cm)" % [cote, worst_ecart * 100, float(seuil("ecart_max")) * 100])
		rapport["ok"] = rapport["echecs"].is_empty()
		res[cote] = rapport
	return res

static func _arrondi(m: Dictionary) -> Dictionary:
	var o := {}
	for k in m:
		var v: Variant = m[k]
		if v is float:
			o[k] = snappedf(v, 0.0001)
		elif v is Array:
			o[k] = (v as Array).map(func(x): return snappedf(x, 0.0001))
		else:
			o[k] = v
	return o

## Arme tenue (BoneAttachment3D sous la main droite ou l'avant-bras droit) : distance milieu de poignée -> paume (centre des sommets de
## la main, hors arme) et angle lame / avant-bras (sens de la lame ignoré), au repos puis sur les images des clips ; pire cas gardé.
func controle_arme(clips: Array, nb_images: int) -> Dictionary:
	if not os_bras.has("r"):
		return {}
	var arme: Node3D = null
	var att: BoneAttachment3D = null
	for a: BoneAttachment3D in racine.find_children("*", "BoneAttachment3D", true, false):
		for c in a.get_children():
			if c is Node3D and (String(c.name).to_lower().contains("epee") or String(c.name).to_lower().contains("sword")):
				arme = c
				att = a
	if arme == null:
		return {}
	var os := sq.find_bone(att.bone_name)
	var d: Dictionary = os_bras["r"]
	var mesure := func() -> Dictionary:
		var pos := sommets_poses()
		var m := gp(os) * arme.transform
		var lame := m.basis.y.normalized()
		var poignee := m * Vector3(0, GardeTripo.MILIEU_POIGNEE, 0)
		var c := Vector3.ZERO
		var n := 0
		for i in nb_sommets:
			if dominant[i] == d["main"] and not _est_arme[i]:
				c += pos[i]
				n += 1
		if n <= 8:      # pas de géométrie sur l'os de main : le poing fermé rapporté, sinon le milieu des os
			c = Vector3.ZERO
			n = 0
			for i in nb_sommets:
				if _est_poing[i]:
					c += pos[i]
					n += 1
		var paume := c / n if n > 8 else (_pos_os(d["main"]) + _pos_os(d["bout"])) * 0.5
		var avant := _dir(_pos_os(d["avant"]), _pos_os(d["main"]))
		return {"dist": poignee.distance_to(paume), "angle": rad_to_deg(acos(clampf(absf(lame.dot(avant)), 0.0, 1.0)))}
	poser_neutre()
	var r0: Dictionary = mesure.call()
	var dmax: float = r0["dist"]
	var amin: float = r0["angle"]
	var amax: float = r0["angle"]
	var poses: Array = [{"clip": "repos", "t": 0.0, "distance": snappedf(r0["dist"], 0.001), "angle": snappedf(r0["angle"], 0.1)}]
	for nom: String in clips:
		if not anims.has(nom):
			continue
		var an: Animation = anims[nom]
		for k in nb_images:
			var t := an.length * float(k) / float(maxi(nb_images, 1))
			poser_clip(an, t, nom)
			var r: Dictionary = mesure.call()
			dmax = maxf(dmax, r["dist"])
			amin = minf(amin, r["angle"])
			amax = maxf(amax, r["angle"])
			poses.append({"clip": nom, "t": snappedf(t, 0.01), "distance": snappedf(r["dist"], 0.001), "angle": snappedf(r["angle"], 0.1)})
	poser_neutre()
	var echecs: Array = []
	if dmax > float(seuil("arme_paume_max")):
		echecs.append("arme : poignée à %.1f cm de la paume (max %.1f cm)" % [dmax * 100, float(seuil("arme_paume_max")) * 100])
	if amax > float(seuil("arme_angle_max")):
		echecs.append("arme : lame à %.0f° de l'avant-bras (max %.0f°)" % [amax, float(seuil("arme_angle_max"))])
	return {"os": att.bone_name, "distance_poignee_paume_max": snappedf(dmax, 0.001), "angle_lame_avant_bras_min": snappedf(amin, 0.1),
		"angle_lame_avant_bras_max": snappedf(amax, 0.1), "poses": poses, "echecs": echecs, "ok": echecs.is_empty()}

# ===================================================================== contrôle complet

func controler() -> Dictionary:
	var rap := {"echecs": [], "avertissements": []}
	if sq == null:
		rap["echecs"].append("aucun Skeleton3D dans le modèle")
		rap["ok"] = false
		return rap
	collecter()
	# clips : ceux de l'AnimationPlayer du modèle, sinon la bibliothèque du jeu
	anims.clear()
	var lib: AnimationLibrary = null
	for p: AnimationPlayer in racine.find_children("*", "AnimationPlayer", true, false):
		if p.get_animation_list().size() > 2:
			lib = p.get_animation_library("") if p.has_animation_library("") else null
	if lib == null:
		lib = Humain.bibliotheque()
	var clips: Array = opts.get("clips", ["Idle", "Walk", "Sword_Idle", "Sword_Attack"])
	for nom: String in clips:
		if lib.has_animation(nom):
			anims[nom] = lib.get_animation(nom)
		else:
			rap["avertissements"].append("clip absent : " + nom)
	poser_neutre()
	var pos0 := sommets_poses()
	calculer_groupes()
	if float(seuil("arme_skinnee")) > 0.0:
		_exclure_armes_skinnees(pos0)
	rap["tris"] = controle_tris()
	rap["composantes"] = controle_composantes(pos0)
	rap["bras"] = controle_bras(clips, int(opts.get("images", 5)))
	var arme := controle_arme(clips, int(opts.get("images", 5)))
	if not arme.is_empty():
		rap["arme"] = arme
	if not (rap["tris"]["ok"]):
		rap["echecs"].append("triangles : %d > budget %d" % [rap["tris"]["total"], rap["tris"]["budget"]])
	for e: Dictionary in rap["composantes"]["eclats_proches"]:
		rap["echecs"].append("éclat flottant : %d faces en %s près de %s (%.1f cm)" % [e["faces"], e["centre"], e["os"], float(e["distance_main_avant_bras"]) * 100])
	if rap["composantes"]["petits_trous"].size() > int(seuil("trous_max")):
		rap["echecs"].append("%d petits trous (max %d)" % [rap["composantes"]["petits_trous"].size(), int(seuil("trous_max"))])
	for c in rap["bras"]:
		rap["echecs"].append_array(rap["bras"][c]["echecs"])
		rap["avertissements"].append_array(rap["bras"][c]["avert"])
	if not arme.is_empty():
		rap["echecs"].append_array(arme["echecs"])
	for w in avert:
		if not rap["avertissements"].has(w):
			rap["avertissements"].append(w)
	rap["ok"] = rap["echecs"].is_empty()
	return rap
