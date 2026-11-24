class_name PropsQuaternius
## Props Quaternius (CC0, Fantasy Props MegaKit + Medieval Village MegaKit) adaptés par sources_blender/scripts/importer_quaternius.py
## (references/quaternius_props/CATALOGUE.md). Fichier : assets/crypte/modules/props_quaternius.dat, entrées « q_<nom>__<matière> »,
## triangles non indexés (sommet = position + couleur ton × occlusion, alpha 1 = matière sans neige).
##
## Trois usages, toujours FONDUS dans les lots existants (aucun nœud par objet, aucun appel de dessin en plus quand la matière est déjà
## dans le lot) :
##   - intérieurs (Interieurs.q) : Village._ajouter, lots par (pièce, matière) ;
##   - village (MobilierVillage, marché) : SurfaceTool par matière du mobilier ;
##   - crypte (crypte()) : CrypteDecor.modele (tampons de la case de 8 m, emprise automatique).
## Règle fer → fer_mat (CATALOGUE §6) : le fer des props se pose MAT partout (la variante brillante sortait beige-doré).

const DAT := "res://assets/crypte/modules/props_quaternius.dat"
## Essai bâti (`--bati-quaternius`, scripts/village_bati_q.gd) : façades assemblées, chargées SEULEMENT avec l'option.
const DAT_BATI := "res://assets/modeles/bati_quaternius.dat"

## Crypte : matières des props → matières de CrypteDecor (pierre → pierre_v2 par MAT_MODELE ; lin, jute, os, or… gardés : TUILE).
const MATS_CRYPTE := {"fer": "fer_mat", "herbe": "jute"}      # herbe (lot 4 : légumes, verre vert) : pas de matière verte dans la crypte

## `-- --sans-props-q` : rien n'est posé (captures « avant » et mesures A/B du coût, même lancement que le jeu).
static var actif := not ("--sans-props-q" in OS.get_cmdline_user_args())
## `-- --sans-remplacement` : ANCIENS props faits maison (mobilier procédural / modules Blender maison) à la place des Quaternius qui les
## remplacent (props/remplacement, 2026-11-03) ; sert aux captures « avant » et aux mesures A/B. Implique actif.
static var remplace := actif and not ("--sans-remplacement" in OS.get_cmdline_user_args())
## `-- --sans-lot4` : état de l'exe 3 (props du lot 3) sans les pièces du lot 4 (Medieval Dungeon, Survival, Ultimate Food ; props/lot4,
## 2026-11-04) : captures « avant » et mesures A/B du lot 4. Toute pose ou substitution du lot 4 teste `PropsQuaternius.lot4`.
static var lot4 := remplace and not ("--sans-lot4" in OS.get_cmdline_user_args())
## Props TEXTURÉS PS1 (pq_*, props/quaternius_remplacement, 2026-11-10) : partout où le code pose un q_* qui a son pq_* (catalogue
## data/props_quaternius.json, champ « ancien »), c'est le pq_* qui est fondu dans les mêmes lots, AU MÊME ENCOMBREMENT (le pq_* est mis à
## l'échelle de la boîte du q_*, origine au pied : poses, plateaux et collisions inchangés). Données : assets/modeles/props_quat/props_quat.dat
## (outils/export_props_quat_dat.gd : UV + couleur de sommet + atlas, lu par FileAccess, aucun .glb dans un fil) ; matière d'un morceau
## = nom d'atlas « pq_bois », « pq_fer »… -> un matériau partagé par (atlas, contexte) (PropsQuat.materiau) : lots regroupés PAR ATLAS.
## `-- --props-quat-ancien` : retour aux q_* (couleurs de face), même lancement que le jeu (captures « avant », mesures A/B).
static var pq := actif and not ("--props-quat-ancien" in OS.get_cmdline_user_args())
## props/maximum v3 (abords, replis de la grotte et de la crypte, coins de métier) ; `-- --sans-props-v3` rend la v2 (A/B des mesures).
static var v3 := pq and not ("--sans-props-v3" in OS.get_cmdline_user_args())
## props/crypte_v5 (2026-11-19) : souterrains (crypte, tertre, grotte) : tables, coffres de décor, boucliers muraux, toiles, coffres
## forcés, gravats en briques et compositions de donjon ; `-- --sans-props-v5` rend EXACTEMENT la v3 (captures « avant », mesures A/B).
## props/exterieurs_v5 (2026-11-19) : derniers props maison du DEHORS remplacés et tables / postes de vie ajoutés (AbordsProps.LIEUX_V5,
## foyer des bandits) ; `-- --sans-props-v5` rend exactement l'état d'avant (captures « avant », mesures A/B). `--sans-remplacement`
## (remplace faux) l'éteint aussi : les anciens props maison reviennent.
static var v5 := v3 and remplace and not ("--sans-props-v5" in OS.get_cmdline_user_args())
const DAT_PQ := "res://assets/modeles/props_quat/props_quat.dat"
const ATLAS_PQ := ["pq_bois", "pq_fer", "pq_fer_v", "pq_tissu", "pq_tissu_v", "pq_props", "pq_props_v", "pq_page"]
## Kitbash : ces q_* servent aussi de PIÈCES RETEINTES (carotte retournée = saucisson, bourse = jambon, toile de bannière = peau ou tapis,
## sac = foin ou cuir de soufflet, marmite d'argile, épée = fer de lance) : quand la pose remplace une matière par une autre (hors fer mat),
## le q_* reste (le prop texturé y montrerait une carotte, un sac de jute…).
const KITBASH_SI_MATS := ["q_carotte", "q_bourse", "q_banniere_toile", "q_banniere_2_toile", "q_sac", "q_marmite", "q_epee_mur"]
## Recolorations sans effet sur l'identité du prop (fer mat, étain, matières de la crypte) : n'empêchent pas le pq_*.
const MATS_NEUTRES := {"fer": ["fer", "fer_mat", "etain", "fer_noir", "noir", "or"], "herbe": ["jute"], "os": ["os", "cire"], "bois": ["bois"]}
## Jamais remplacés : les tas de pièces texturés n'ont que quelques gros disques ; agrandis aux tas d'or de la crypte (bornes des anciens
## modules) ils sortaient en meules de fromage (captures avant/après, trésor). Les q_* (nombreuses petites pièces) restent.
const PQ_EXCLUS := ["q_pieces", "q_tas_pieces", "q_tas_pieces_2"]
## props/maximum (2026-11-11) : q_* du Modular Dungeon / Medieval Village SANS pq_* propre, servis par le pq_* texturé du même objet
## (tonneau, caisse ferrée, sac, vase) à l'encombrement de CE pq_* (celui de son propre q_*) : un tonneau 2 de 1,34 m devient un tonneau
## ordinaire de 0,95 m ; les poses ajustées à une taille cible (SUBST de la crypte, SUBST_FIT du village) ne changent pas.
const ALIAS_PQ := {"q_tonneau_2": "pq_tonneau", "q_caisse_2": "pq_caisse_fer", "q_sac_debout": "pq_sac", "q_vase_5": "pq_vase_4",
	"q_coffre_2": "pq_coffre_ferme", "q_seau_2": "pq_seau_bois", "q_chaise_2": "pq_chaise",
	"q_bouteille_1": "pq_bouteille", "q_bouteille_2": "pq_bouteille",
	# props/crypte_v5 : pièces de donjon posées par la v5 (tables, toiles, os, coffre de crypte) -> leurs pq_* texturés de props/sources_v5
	# (même modèle source, même échelle : docs/PROPS_SOURCES_V5.md, « equivalent_q ») ; la boucle de _charger_pq ne pose un alias que si
	# son pq_* est dans props_quat.dat. Pièces de DONJON seulement (briques et rochers servent aussi au village : la crypte pose
	# directement pq_brique_*, pq_coffre_or, pq_bougie_d).
	"q_table_petite_2": "pq_table_petite_2", "q_toile_araignee_1": "pq_toile_araignee_1", "q_toile_araignee_2": "pq_toile_araignee_2",
	"q_os_tas": "pq_os_tas", "q_os_tas_2": "pq_os_tas_2", "q_coffre_d": "pq_coffre_d"}
static var audit_pose := "--audit-poses" in OS.get_cmdline_user_args()
static var audit := {}        # nom -> nombre de poses fondues dans le décor (--audit-poses seulement)
## Inventaire télékinésie : une pose FONDUE dans le décor (donc non saisissable) du prop `nom`, notée seulement avec --audit-poses.
static func fondu(nom: String, src := "") -> void:
	if audit_pose:
		var k := nom + " <" + src + ">"
		audit[k] = int(audit.get(k, 0)) + 1
static var _pq_de := {}       # nom q_* (ou pq_* posé directement) -> id pq_*
static var _pq_mods := {}     # id pq_* -> [[atlas, arrays indexés (UV, normales, couleurs)], …], déjà à l'encombrement du q_*
static var _pq_boites := {}   # id pq_* -> AABB
static var _pq_lu := false
## Poses servies en pq_* (une par morceaux() / triangles() / module de crypte) : « PropsQuaternius : pq_* posés » dans le journal.
static var nb_pq := 0
static var nb_pq_ajouts := 0

## Compteur de props posés par les remplacements (zone -> nombre) : « PropsQuaternius : remplacements … » dans le journal (bilan du rapport).
static var compte := {}
static func compter(zone: String, n := 1) -> void:
	compte[zone] = int(compte.get(zone, 0)) + n
static var _mods := {}        # nom -> [[matière, arrays indexés (ordre Godot, normales plates)]]
static var _boites := {}      # nom -> AABB (repère du prop : origine au sol, au centre de l'emprise)
static var _brut := {}        # nom -> [[matière, PackedVector3Array, PackedColorArray]] (ordre Godot)
static var _verrou := Mutex.new()
static var _crypte_lu := false

static func _charger() -> void:
	_verrou.lock()
	if _brut.is_empty():
		for chemin: String in [DAT] + ([DAT_BATI] if VillageBatiQ.actif else []):
			var f := FileAccess.open(chemin, FileAccess.READ)
			if f == null:
				push_error("PropsQuaternius : %s introuvable" % chemin)
			else:
				var n := f.get_32()
				for _k in n:
					var cle := f.get_buffer(f.get_8()).get_string_from_utf8()
					var nb := f.get_32()
					var fl := f.get_buffer(nb * 28).to_float32_array()
					var pos := PackedVector3Array()
					var col := PackedColorArray()
					pos.resize(nb)
					col.resize(nb)
					for q in nb:
						var o := q * 7
						pos[q] = Vector3(fl[o], fl[o + 1], fl[o + 2])
						col[q] = Color(fl[o + 3], fl[o + 4], fl[o + 5], 1.0)
					for t in range(0, nb, 3):     # Godot : face avant = sens horaire → a, c, b
						var p := pos[t + 1]
						pos[t + 1] = pos[t + 2]
						pos[t + 2] = p
						var c := col[t + 1]
						col[t + 1] = col[t + 2]
						col[t + 2] = c
					var mc := cle.split("__")
					if not _brut.has(mc[0]):
						_brut[mc[0]] = []
					(_brut[mc[0]] as Array).append([mc[1], pos, col])
					var bb: AABB = _boites.get(mc[0], AABB(pos[0], Vector3.ZERO)) if nb > 0 else _boites.get(mc[0], AABB())
					for q in nb:
						bb = bb.expand(pos[q])
					_boites[mc[0]] = bb
	if pq and not _pq_lu:
		_pq_lu = true
		_charger_pq()
	_verrou.unlock()

## Lecture de props_quat.dat (sous le verrou de _charger) ; chaque pq_* est ramené à l'encombrement de son q_* : échelle UNIFORME
## (rapport des sommes des côtés des deux boîtes), centre de l'emprise et pied alignés.
static func _charger_pq() -> void:
	var f := FileAccess.open(DAT_PQ, FileAccess.READ)
	if f == null:
		push_error("PropsQuaternius : %s introuvable (outils/export_props_quat_dat.gd)" % DAT_PQ)
		return
	f.get_buffer(4)
	var n := f.get_32()
	for _k in n:
		var id := f.get_buffer(f.get_8()).get_string_from_utf8()
		var anc := f.get_buffer(f.get_8()).get_string_from_utf8()
		var ns := f.get_8()
		var surfs := []
		var bb := AABB()
		var premier := true
		for _s in ns:
			var atlas := f.get_buffer(f.get_8()).get_string_from_utf8()
			var nv := f.get_32()
			var fl := f.get_buffer(nv * 48).to_float32_array()
			var ni := f.get_32()
			var ii := f.get_buffer(ni * 4).to_int32_array()
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var uv := PackedVector2Array()
			var cc := PackedColorArray()
			v.resize(nv)
			nn.resize(nv)
			uv.resize(nv)
			cc.resize(nv)
			for q in nv:
				var o := q * 12
				v[q] = Vector3(fl[o], fl[o + 1], fl[o + 2])
				nn[q] = Vector3(fl[o + 3], fl[o + 4], fl[o + 5])
				uv[q] = Vector2(fl[o + 6], fl[o + 7])
				cc[q] = Color(fl[o + 8], fl[o + 9], fl[o + 10], fl[o + 11])
				if premier:
					bb = AABB(v[q], Vector3.ZERO)
					premier = false
				else:
					bb = bb.expand(v[q])
			surfs.append([atlas, v, nn, uv, cc, ii])
		if PropsQuat.detail():
			_varier_pieces(id, surfs)
		var ech := 1.0
		var dep := Vector3.ZERO
		if anc != "" and _boites.has(anc) and _boites[anc].size.length() > 0.001 and bb.size.length() > 0.001:
			var bq: AABB = _boites[anc]
			ech = (bq.size.x + bq.size.y + bq.size.z) / (bb.size.x + bb.size.y + bb.size.z)
			var cq := bq.get_center()
			var cp := bb.get_center() * ech
			dep = Vector3(cq.x - cp.x, bq.position.y - bb.position.y * ech, cq.z - cp.z)
		var res := []
		for su: Array in surfs:
			var v: PackedVector3Array = su[1]
			for q in v.size():
				v[q] = v[q] * ech + dep
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = v
			a[Mesh.ARRAY_NORMAL] = su[2]
			a[Mesh.ARRAY_TEX_UV] = su[3]
			a[Mesh.ARRAY_COLOR] = su[4]
			a[Mesh.ARRAY_INDEX] = su[5]
			res.append([su[0], a])
		_pq_mods[id] = res
		_pq_boites[id] = AABB(bb.position * ech + dep, bb.size * ech)
		_pq_de[id] = id
		if anc != "":
			_pq_de[anc] = id
	for al: String in ALIAS_PQ:
		if _pq_mods.has(ALIAS_PQ[al]) and not _pq_de.has(al):
			_pq_de[al] = ALIAS_PQ[al]

## props/detail_v5 : variation PAR PIÈCE (planche, pied, traverse, cerclage…) dans la couleur de sommet : chaque morceau d'un seul
## tenant (sommets soudés par position à 1 mm près, toutes surfaces confondues) reçoit un ton (x 0,88-1,12), une pointe chaude ou
## froide (± 4 %) et, une fois sur cinq, une usure plus marquée (x 0,84) ; tirage stable (nom du prop, rang du morceau). Sans
## effet sur un prop d'un seul tenant. Aucun sommet ni atlas en plus.
static func _varier_pieces(id: String, surfs: Array) -> void:
	var cle := {}       # position quantifiée -> sommet représentant
	var parent: Array[int] = []      # Array (référence) : partagé avec la fermeture `trouver`
	var base := []      # par surface : indice du 1er représentant global de ses sommets
	for su: Array in surfs:
		var v: PackedVector3Array = su[1]
		var rep := PackedInt32Array()
		rep.resize(v.size())
		for q in v.size():
			var k := Vector3i((v[q] * 1000.0).round())
			var r: int = cle.get(k, -1)
			if r < 0:
				r = parent.size()
				parent.append(r)
				cle[k] = r
			rep[q] = r
		base.append(rep)
	var trouver := func(a: int) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for s in surfs.size():
		var ii: PackedInt32Array = surfs[s][5]
		var rep: PackedInt32Array = base[s]
		for t in range(0, ii.size() - 2, 3):
			var a: int = trouver.call(rep[ii[t]])
			for j in [1, 2]:
				var b: int = trouver.call(rep[ii[t + j]])
				if a != b:
					parent[b] = a
	var rang := {}
	for s in surfs.size():
		var rep: PackedInt32Array = base[s]
		for q in rep.size():
			var r: int = trouver.call(rep[q])
			if not rang.has(r):
				rang[r] = rang.size()
	if rang.size() < 2:
		return
	var h0 := id.hash()
	for s in surfs.size():
		var cc: PackedColorArray = surfs[s][4]
		var rep: PackedInt32Array = base[s]
		for q in cc.size():
			var k: int = rang[trouver.call(rep[q])]
			var h1 := fposmod(sin(float(h0 % 9973) * 0.731 + k * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(float(h0 % 7919) * 0.377 + k * 78.233) * 24634.6345, 1.0)
			var f := lerpf(0.88, 1.12, h1) * (0.84 if h2 > 0.8 else 1.0)
			var w := (h2 - 0.5) * 0.08
			var c := cc[q]
			cc[q] = Color(c.r * f * (1.0 + w), c.g * f, c.b * f * (1.0 - w), c.a)
		surfs[s][4] = cc

## Id du pq_* posé à la place de `nom` pour cette pose ("" = le q_* reste) : interrupteur global, prop sans équivalent, kitbash reteint.
static func pq_de(nom: String, mats := {}) -> String:
	if not pq:
		return ""
	_charger()
	if nom in PQ_EXCLUS:
		return ""
	var id: String = _pq_de.get(nom, "")
	if id == "" or mats.is_empty() or not (nom in KITBASH_SI_MATS):
		return id
	for k: String in mats:
		var cible := String(mats[k])
		if k.begins_with("@") or cible == k or cible in (MATS_NEUTRES.get(k, []) as Array):
			continue
		return ""
	return id

## Vrai pour une matière de morceau texturée (atlas pq_*).
static func est_pq(matiere: String) -> bool:
	return matiere.begins_with("pq_")

## Matériaux partagés des atlas pour un contexte (exterieur / interieur / crypte) : {"pq_bois": Material, …}.
static func mats_pq(contexte: String) -> Dictionary:
	var r := {}
	for a: String in ATLAS_PQ:
		r[a] = PropsQuat.materiau(a, contexte)
	return r

## À appeler du fil principal au démarrage : atlas et matériaux des trois contextes créés (aucune ressource chargée dans un fil ;
## le .dat, lui, est lu par FileAccess dans le fil qui en a besoin le premier).
static func prechauffer_pq() -> void:
	if not pq:
		return
	for c: String in PropsQuat.CONTEXTES:
		mats_pq(c)

static func existe(nom: String) -> bool:
	_charger()
	return _brut.has(nom) or (pq and _pq_de.has(nom))

## Boîte englobante du prop dans son repère (origine au sol, au centre de l'emprise ; X largeur, Y hauteur, Z profondeur).
## Celle du pq_* qui le remplace pour cette pose (même encombrement, à quelques mm près).
static func boite(nom: String, mats := {}) -> AABB:
	_charger()
	var id := pq_de(nom, mats)
	if id != "":
		return _pq_boites[id]
	return _boites.get(nom, AABB())

## Tableaux indexés (sommets dédoublonnés, normales plates) de chaque matière du prop : [[matière, arrays], …] (cache).
## Version texturée (pq_*) : matière = atlas (« pq_bois »…), tableaux AVEC UV ; `avec_pq` false : toujours le q_* (objets ramassables).
static func morceaux(nom: String, mats := {}, avec_pq := true) -> Array:
	_charger()
	if avec_pq:
		var id := pq_de(nom, mats)
		if id != "":
			nb_pq += 1
			return _pq_mods[id]
	_verrou.lock()
	if not _mods.has(nom):
		var res := []
		for e: Array in _brut.get(nom, []):
			var pos: PackedVector3Array = e[1]
			var col: PackedColorArray = e[2]
			var v := PackedVector3Array()
			var nn := PackedVector3Array()
			var cc := PackedColorArray()
			var ii := PackedInt32Array()
			var vus := {}
			for t in range(0, pos.size(), 3):
				var nf := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])
				if nf.length_squared() < 1e-14:
					continue
				nf = nf.normalized()
				for j in 3:
					var cle := [pos[t + j], nf, col[t + j]]
					var k: int = vus.get(cle, -1)
					if k < 0:
						k = v.size()
						vus[cle] = k
						v.append(pos[t + j])
						nn.append(nf)
						cc.append(col[t + j])
					ii.append(k)
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = v
			a[Mesh.ARRAY_NORMAL] = nn
			a[Mesh.ARRAY_COLOR] = cc
			a[Mesh.ARRAY_INDEX] = ii
			res.append([e[0], a])
		_mods[nom] = res
	var r: Array = _mods[nom]
	_verrou.unlock()
	return r

## Triangles bruts (ordre Godot) d'une matière, pour un SurfaceTool : [[matière, positions, couleurs], …].
## Version texturée : [[atlas, positions, couleurs]] (triangles dépliés) ; maillage_brut(nom, atlas) donne alors le maillage avec UV.
static func triangles(nom: String, mats := {}) -> Array:
	_charger()
	var id := pq_de(nom, mats)
	if id != "":
		nb_pq += 1
		var cle := "pq_tri:" + id
		_verrou.lock()
		var r: Array = _brut_pq_tri.get(cle, [])
		_verrou.unlock()
		if r.is_empty():
			for m: Array in _pq_mods[id]:
				var a: Array = m[1]
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
				var pp := PackedVector3Array()
				var pc := PackedColorArray()
				for k: int in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
					pp.append(v[k])
					pc.append(c[k])
				r.append([m[0], pp, pc])
			_verrou.lock()
			_brut_pq_tri[cle] = r
			_verrou.unlock()
		return r
	return _brut.get(nom, [])
static var _brut_pq_tri := {}

## v5 : la bûche KITBASH maison (q_buche, OBJ à 8 pans de sources_blender/quaternius/kitbash) est servie par le rondin Quaternius
## (q_rondin, Survival : écorce et bouts sciés) ramené à la boîte de la bûche (0,6 x 0,2 x 0,2 ; rapports 0,43 / 0,50 / 0,49 : presque
## uniforme, l'écorce n'est pas déformée). Renvoie [id, Transform3D à composer À DROITE de la pose] ; inchangé sans v5.
static func buche_v5(nom: String) -> Array:
	if v5 and nom == "q_buche":
		for r: String in ["pq_rondin", "q_rondin"]:      # rondin TEXTURÉ du catalogue v5 (props/sources_v5) s'il est là
			if existe(r):
				compter("v5:q_buche")
				return [r, ajuste(r, "q_buche")]
	return [nom, Transform3D.IDENTITY]

## v5 DEHORS seulement : q_* (couleurs de face) servis par leur pq_* TEXTURÉ du catalogue v5 (props/sources_v5, champ
## « equivalent_q » : même modèle, même échelle, même emprise), aux sites d'appel du dehors (MobilierVillage, PropsQuaternius.village,
## AbordsProps) ; pas de champ « ancien » (les intérieurs, la crypte et la grotte ne changent pas). Rien sans v5 ni sans le pq_*.
## Pièces de nourriture des étals (objets vivants), kitbash reteints et pièces de construction sans pq_* (q_buche à part, q_poutre_ronde,
## q_souche, q_tronc) : absents de la table.
const EXT_V5 := {"q_barriere_bois": "pq_barriere_bois", "q_barriere_ext_1": "pq_barriere_ext_1", "q_barriere_ext_2": "pq_barriere_ext_2",
	"q_bordure_1": "pq_bordure_1", "q_bordure_2": "pq_bordure_2", "q_bordure_angle": "pq_bordure_angle",
	"q_brique_1": "pq_brique_1", "q_brique_2": "pq_brique_2", "q_brique_3": "pq_brique_3", "q_brique_4": "pq_brique_4",
	"q_bucher": "pq_bucher", "q_caisse_village": "pq_caisse_village", "q_chariot": "pq_chariot", "q_feu_bois": "pq_feu_bois",
	"q_hache_camp": "pq_hache_camp", "q_hachette": "pq_hachette", "q_marmite_camp": "pq_marmite_camp", "q_piege_ours": "pq_piege_ours",
	"q_piege_ours_ferme": "pq_piege_ours_ferme", "q_planches_sol": "pq_planches_sol", "q_rondin": "pq_rondin", "q_support_bois": "pq_support_bois",
	"q_tente": "pq_tente", "q_pelle": "pq_pelle", "q_crane": "pq_crane", "q_pain": "pq_pain", "q_pomme": "pq_pomme", "q_viande": "pq_viande",
	"q_poisson": "pq_poisson", "q_porte_1_plate": "pq_porte_1_plate", "q_porte_1_ronde": "pq_porte_1_ronde", "q_porte_2_plate": "pq_porte_2_plate",
	"q_porte_2_ronde": "pq_porte_2_ronde", "q_porte_8_plate": "pq_porte_8_plate", "q_porte_8_ronde": "pq_porte_8_ronde",
	"q_volets_thin_flat_open": "pq_volets_etroits_ouverts", "q_volets_thin_flat_closed": "pq_volets_etroits_fermes",
	"q_volets_wide_flat_open": "pq_volets_larges_ouverts", "q_volets_wide_flat_closed": "pq_volets_larges_fermes"}
## Admis même avec des matières imposées par la pose (elles teignaient le q_* ; le pq_* porte sa propre texture) : toile de la tente,
## manche de cuir de la hache, piège en fer mat.
const EXT_V5_MATS_IGNOREES := ["q_tente", "q_hache_camp", "q_piege_ours"]

static func ext_v5(nom: String, mats := {}) -> String:
	if not v5 or not EXT_V5.has(nom):
		return nom
	if not mats.is_empty() and not (nom in EXT_V5_MATS_IGNOREES):
		return nom
	var id: String = EXT_V5[nom]
	if not existe(id):
		return nom
	compter("v5:" + nom)
	return id

## Transformation qui envoie la boîte de `src` dans celle de `cible` (échelle par axe, pied et centre de l'emprise alignés).
static func ajuste(src: String, cible: String) -> Transform3D:
	var a := boite(src)
	var b := boite(cible)
	var s := Vector3(b.size.x / maxf(a.size.x, 0.001), b.size.y / maxf(a.size.y, 0.001), b.size.z / maxf(a.size.z, 0.001))
	var ca := a.get_center() * s
	var cb := b.get_center()
	return Transform3D(Basis.from_scale(s), Vector3(cb.x - ca.x, b.position.y - a.position.y * s.y, cb.z - ca.z))

## Nombre de triangles d'un prop (mesure du coût).
static func nb_triangles(nom: String, mats := {}) -> int:
	var n := 0
	for e: Array in triangles(nom, mats):
		n += (e[1] as PackedVector3Array).size() / 3
	return n

# ------------------------------------------------------------------------------------------------ crypte

## Pose un prop dans la crypte (repère local du module en cours de `d`), fondu dans les tampons du décor, emprise automatique
## (la pose aléatoire des détritus l'évite). `solide` : boîte de collision (gros objets). `mats` s'ajoute à MATS_CRYPTE.
static func preparer_crypte() -> void:
	_verrou.lock()
	if not _crypte_lu:
		_crypte_lu = true
		CrypteDecor._charger_modeles()
		CrypteDecor._modeles_verrou.lock()
		CrypteDecor._lire_dat(DAT)
		if pq:
			_verser_pq_crypte()
		CrypteDecor._modeles_verrou.unlock()
	_verrou.unlock()

## Verse les pq_* dans les modules de CrypteDecor sous « pq:<q_*> » (matière = atlas, UV du prop gardés ; ordre Blender comme les
## autres .dat : CrypteDecor._modele_cache le remet dans l'ordre de Godot). CrypteDecor.modele() choisit « pq:<nom> » (voir nom_crypte).
static func _verser_pq_crypte() -> void:
	_charger()
	for nom: String in _pq_de:
		var id: String = _pq_de[nom]
		var cle := "pq:" + nom
		if CrypteDecor._modeles_de.has(cle):
			continue
		var mats := []
		for m: Array in _pq_mods[id]:
			var a: Array = m[1]
			var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var sc: PackedColorArray = a[Mesh.ARRAY_COLOR]
			var v := PackedVector3Array()
			var u := PackedVector2Array()
			var c := PackedColorArray()
			for t in range(0, ii.size(), 3):
				for j: int in [0, 2, 1]:
					var k := ii[t + j]
					v.append(sv[k])
					u.append(su[k])
					c.append(sc[k])
			CrypteDecor._modeles["%s__%s" % [cle, m[0]]] = {"v": v, "c": c, "u": u}
			mats.append(m[0])
		CrypteDecor._modeles_de[cle] = mats

## Module de la crypte / de la grotte à poser pour `nom` : « pq:<nom> » si son pq_* le remplace pour cette pose, sinon `nom`.
static func nom_crypte(nom: String, mats := {}) -> String:
	if not pq or nom.begins_with("pq:") or not (nom.begins_with("q_") or nom.begins_with("pq_")):
		return nom
	preparer_crypte()
	if pq_de(nom, mats) != "" and CrypteDecor._modeles_de.has("pq:" + nom):
		nb_pq += 1
		return "pq:" + nom
	return nom

static func crypte(d: CrypteDecor, nom: String, pos: Vector3, lacet := 0.0, e := 1.0, solide := false, mats := {}) -> void:
	if not actif:
		return
	preparer_crypte()
	if pos.y < 0.05:      # au sol : écarté du soubassement des murs (même règle que le mobilier de la crypte)
		var bb0 := boite(nom, mats)
		pos = d._ecarter(pos, Vector2(bb0.size.x, bb0.size.z) * 0.5 * e, lacet)
	var m := MATS_CRYPTE.duplicate()
	m.merge(mats, true)
	# télékinésie partout : règle unique ObjetsVivants.mobile (CrypteDecor.modele la fait aussi pour les poses directes) ; un prop MOBILE
	# solide (tonneau, caisse) garde son passage bloqué par son propre corps et n'a plus de boîte fixe
	var obj := CasseObjets.actif and ObjetsVivants.tk_partout and not d.muet and ObjetsVivants.capte_meuble(nom) and d.lot == "" \
		and (ObjetsVivants.regle_unique or (not solide and pq_de(nom) != ""))
	if obj:
		var md: Array = ObjetsVivants.fiche_meuble(nom)
		var tb := (Basis(Vector3.UP, lacet) * (boite(nom, mats).size * e)).abs()
		obj = d.cassable_debut("objet", pos, e, tb, [md[0], md[1], bool(md[4]) or solide])
	d.modele(nom, pos, lacet, Vector3.ONE * e, m, true)
	if obj:
		d.cassable_fin()
		return
	if solide:
		var bb := boite(nom, mats)
		var c := pos + Basis(Vector3.UP, lacet) * (bb.get_center() * e)
		var t := bb.size * e
		var b := Basis(Vector3.UP, lacet)
		var demi := (b * Vector3(t.x, 0, 0)).abs() + (b * Vector3(0, 0, t.z)).abs()     # boîte alignée sur les axes (solide() ne tourne pas)
		d.solide(c, Vector3(demi.x, t.y, demi.z))

# ------------------------------------------------------------------------------------------------ village (dehors)

static var _mats_v := {}
static var _mats_v_de: Object = null

## Matières du village pour les props (lots fondus avec le bâti : bois = poutres, fer = ferrures, jute = foin, pierre = pierre chaude
## des soubassements) ; lin, os, or, argile : textures de la crypte sur le shader du bâti (comme les intérieurs).
static func mats_village(v) -> Dictionary:
	if _mats_v_de != v:
		_mats_v_de = v
		for nom in ["os", "lin", "or", "argile"]:
			if not TexturesBati._cache.has(nom):
				var img: Image = ResourceLoader.load("res://assets/crypte/%s.res" % nom)
				TexturesBati._cache[nom] = [ImageTexture.create_from_image(img), TexturesBati.relief_neutre()]
		_mats_v = {"bois": v.m_poutres_h, "fer": v.m_fer, "jute": v.m_foin, "pierre": v.m_brute_soub, "noir": v.m_fer,
			"lin": TexturesBati.materiau("lin", Color(1.0, 0.96, 0.9), 64.0, 0.4),
			"os": TexturesBati.materiau("os", Color(1.1, 1.05, 0.95), 64.0, 0.0),
			"or": TexturesBati.materiau("or", Color(1.0, 0.95, 0.85), 64.0, 0.3),
			"argile": TexturesBati.materiau("argile", Color(1.05, 0.95, 0.9), 64.0, 0.4)}
		_mats_v["laine"] = _mats_v["lin"]
		# lot 4 : nourriture des étals (mats {"laine": "laine_q", "herbe": "herbe"}) : laine rouge sourde et foin teinté vert
		if not TexturesBati._cache.has("laine"):
			TexturesBati._cache["laine"] = [ImageTexture.create_from_image(ResourceLoader.load("res://assets/crypte/laine.res")), TexturesBati.relief_neutre()]
		_mats_v["laine_q"] = TexturesBati.materiau("laine", Color(0.92, 0.86, 0.84), 64.0, 0.4)
		_mats_v["herbe"] = TexturesBati.m_foin_e(Color(0.55, 0.78, 0.45))
		_mats_v["toile"] = _mats_v["lin"]
		if pq:
			_mats_v.merge(mats_pq("exterieur"), true)
	return _mats_v

## Pose un prop dehors, fondu dans les lots du village (Village._ajouter) ; `xf` dans le repère de `parent` (sol à y 0) ; `mats` :
## matière du prop -> nom de matière de mats_village (ex. {"fer": "argile"}) ; `solide` : boîte de collision de l'emprise.
static func village(v, parent: Node3D, nom: String, xf: Transform3D, solide := false, mats := {}) -> void:
	var nv := ext_v5(nom, mats)      # v5 : q_* du kit -> son pq_* texturé (dehors seulement)
	if nv != nom:
		nom = nv
		mats = {}
	if not actif or not existe(nom):
		return
	if ObjetsVivants.meuble_differe(v, parent, nom, xf, mats):      # cassables partout : meuble physique (corps = solide)
		return
	fondu(nom, "village")
	var mv := mats_village(v)
	for m: Array in morceaux(nom, mats):
		var arr: Array = patine_v5(m[1], m[0], xf, not SANS_NEIGE_V5.has(nom)) if v5 and est_pq(String(m[0])) else m[1]
		v._ajouter(parent, arr, xf, mv[mats.get(m[0], m[0])] if mv.has(mats.get(m[0], m[0])) else mv["bois"])
	if v5:
		PropsQuat.neige_exterieur()
	if solide:
		var bb := boite(nom, mats)
		var s := xf.basis.get_scale()
		v._collision(parent, BoxShape3D.new(), Transform3D(xf.basis.orthonormalized(), xf * bb.get_center()), bb.size * s)

static var _brut_mesh := {}
## Maillage NON indexé (triangles bruts, ordre Godot, couleurs) d'une matière du prop, pour SurfaceTool.append_from (copie en C++ :
## le marché passait ~150 ms à recopier 11 000 triangles sommet par sommet). Cache.
static func maillage_brut(nom: String, mat: String) -> ArrayMesh:
	var cle := nom + "__" + mat
	_verrou.lock()
	var m: ArrayMesh = _brut_mesh.get(cle)
	_verrou.unlock()
	if m != null:
		return m
	if est_pq(mat):      # maillage déplié (non indexé) avec UV, normales et couleurs du pq_*
		for e: Array in _pq_mods.get(String(_pq_de.get(nom, "")), []):
			if e[0] != mat:
				continue
			var a: Array = e[1]
			var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var sc: PackedColorArray = a[Mesh.ARRAY_COLOR]
			var dv := PackedVector3Array()
			var dn := PackedVector3Array()
			var du := PackedVector2Array()
			var dc := PackedColorArray()
			for k: int in ii:
				dv.append(sv[k])
				dn.append(sn[k])
				du.append(su[k])
				dc.append(sc[k])
			var d := []
			d.resize(Mesh.ARRAY_MAX)
			d[Mesh.ARRAY_VERTEX] = dv
			d[Mesh.ARRAY_NORMAL] = dn
			d[Mesh.ARRAY_TEX_UV] = du
			d[Mesh.ARRAY_COLOR] = dc
			m = ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, d)
			break
		_verrou.lock()
		_brut_mesh[cle] = m
		_verrou.unlock()
		return m
	for e: Array in triangles(nom):
		if e[0] != mat:
			continue
		var pos: PackedVector3Array = e[1]
		var nn := PackedVector3Array()
		nn.resize(pos.size())
		for t in range(0, pos.size(), 3):
			var nf := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])
			nf = nf.normalized() if nf.length_squared() > 1e-14 else Vector3.UP
			nn[t] = nf
			nn[t + 1] = nf
			nn[t + 2] = nf
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_NORMAL] = nn
		a[Mesh.ARRAY_COLOR] = e[2]
		m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	_verrou.lock()
	_brut_mesh[cle] = m
	_verrou.unlock()
	return m

# ------------------------------------------------------------------ props/exterieurs_v5 : patine et neige des pq_* dehors
## Retour utilisateur « certains font plus jouet » (2026-11-19) : dehors, avec la v5, chaque pq_* est PATINÉ dans sa couleur de sommet
## (pas de nouvel atlas) : bois assombri et grisé de gel, fer terni, tissus éteints ; le pied (15 premiers cm) plus sombre, humide.
## Les triangles tournés vers le haut (normale MONDE y > 0,72, et une part des faces inclinées) passent en alpha 0 = tex_neige du
## matériau, comme les calottes de neige peintes des anciens props et du bâti (shaders/ps1.gdshader : mix(neige, base, step(0.5, a))) ;
## découpe stable tirée de la position monde (pas de motif répété d'un prop à l'autre). `--sans-props-v5` : rien de tout cela.
const PATINE_V5 := {"pq_bois": Color(0.50, 0.50, 0.54), "pq_fer": Color(0.56, 0.57, 0.61), "pq_fer_v": Color(0.56, 0.57, 0.61),
	"pq_tissu": Color(0.66, 0.66, 0.70), "pq_tissu_v": Color(0.66, 0.66, 0.70), "pq_props": Color(0.62, 0.62, 0.67),
	"pq_props_v": Color(0.62, 0.62, 0.67), "pq_page": Color(0.70, 0.70, 0.74)}
## props/detail_v5 : atlas repeints (bois K_BOIS du bâti, déjà usé et grisé planche par planche) : patine de gel un peu moins sombre.
const PATINE_V5_D := {"pq_bois": Color(0.58, 0.57, 0.6), "pq_fer": Color(0.62, 0.62, 0.66)}
const NEIGE_V5 := Color(0.92, 0.94, 1.0, 0.0)
## Sous un toit ou au mur : patinés mais sans calotte de neige.
## Armes et bouclier rangés au râtelier (inclinés : la calotte les coupait en deux), foyers et marmites au feu : patinés seulement.
const SANS_NEIGE_V5 := ["pq_cloche", "pq_torche_murale", "pq_lanterne_murale", "pq_banniere_mur", "pq_volets_etroits_ouverts",
	"pq_volets_etroits_fermes", "pq_volets_larges_ouverts", "pq_volets_larges_fermes", "pq_bouclier_bois", "pq_epee_mur",
	"pq_hache_outil", "pq_pioche", "pq_pelle", "pq_hachette", "pq_hache_camp", "pq_epee_support",
	"pq_foyer_pierres", "pq_feu_bois", "q_feu_bois", "pq_marmite_camp", "q_marmite_camp"]      # au feu : la neige y fond

## maillage_brut patiné pour la pose `xf` (v5 dehors, MobilierVillage) ; sinon le maillage brut partagé.
static func brut_v5(nom: String, mat: String, xf: Transform3D) -> ArrayMesh:
	var m := maillage_brut(nom, mat)
	if not v5 or not est_pq(mat) or m == null:
		return m
	var r := ArrayMesh.new()
	r.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patine_v5(m.surface_get_arrays(0), mat, xf, not SANS_NEIGE_V5.has(nom)))
	PropsQuat.neige_exterieur()
	return r

static func _hash_v5(p: Vector3) -> float:
	var q := (p * 4.0).floor()
	return fposmod(sin(q.x * 12.9898 + q.y * 78.233 + q.z * 37.719) * 43758.5453, 1.0)

## Copie NON indexée des tableaux `a` d'un morceau pq_* (`atlas`), couleurs patinées et calottes de neige pour la pose `xf`
## (sommets restés dans le repère du prop : à poser avec le même `xf`).
## `neige` faux : patine seule (sous un toit : cloche du beffroi, luminaires muraux). Petits objets (moins de 35 cm : chopes,
## assiettes, nourriture) : pas de calotte, du GIVRE (dessus éclairci, bleuté).
static func patine_v5(a: Array, atlas: String, xf: Transform3D, neige_ok := true) -> Array:
	var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var su: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var sc: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if ii.is_empty():
		ii.resize(sv.size())
		for k in sv.size():
			ii[k] = k
	var t_c: Color = (PATINE_V5_D.get(atlas, PATINE_V5.get(atlas, Color(0.6, 0.6, 0.64))) if PropsQuat.detail()
		else PATINE_V5.get(atlas, Color(0.6, 0.6, 0.64)))
	var bn := xf.basis.inverse().transposed()
	var bas := INF
	var bmin := Vector3(INF, INF, INF)
	var bmax := -bmin
	for v in sv:
		bas = minf(bas, v.y)
		bmin = bmin.min(v)
		bmax = bmax.max(v)
	var tl := (bmax - bmin) * xf.basis.get_scale()
	var petit := maxf(tl.x, maxf(tl.y, tl.z)) < 0.35
	var dv := PackedVector3Array()
	var dn := PackedVector3Array()
	var du := PackedVector2Array()
	var dc := PackedColorArray()
	dv.resize(ii.size())
	dn.resize(ii.size())
	du.resize(ii.size())
	dc.resize(ii.size())
	for t in range(0, ii.size() - 2, 3):
		var i0 := ii[t]
		var i1 := ii[t + 1]
		var i2 := ii[t + 2]
		var nl := sn[i0] + sn[i1] + sn[i2]
		var nm := (bn * nl).normalized() if nl.length_squared() > 1e-10 else Vector3.UP
		var cm := xf * ((sv[i0] + sv[i1] + sv[i2]) / 3.0)
		var h := _hash_v5(cm)
		var neige := neige_ok and not petit and ((nm.y > 0.72 and h > 0.22) or (nm.y > 0.4 and h > 0.66))
		var givre := neige_ok and petit and nm.y > 0.3
		for j in 3:
			var k := ii[t + j]
			var c := sc[k]
			if neige:
				var o := lerpf(0.8, 1.0, clampf(c.r / 0.7, 0.0, 1.0))      # garde un peu de l'occlusion du prop (creux, pied)
				c = Color(NEIGE_V5.r * o, NEIGE_V5.g * o, NEIGE_V5.b * o, 0.0)
			else:
				var pied := clampf((sv[k].y - bas) / 0.15, 0.0, 1.0)
				c = Color(c.r * t_c.r, c.g * t_c.g, c.b * t_c.b, c.a) * lerpf(0.62, 1.0, pied)
				if givre:
					c = c.lerp(Color(0.78, 0.83, 0.94), 0.35)
				c.a = sc[k].a
			dv[t + j] = sv[k]
			dn[t + j] = sn[k]
			du[t + j] = su[k] if not su.is_empty() else Vector2.ZERO
			dc[t + j] = c
	var d := []
	d.resize(Mesh.ARRAY_MAX)
	d[Mesh.ARRAY_VERTEX] = dv
	d[Mesh.ARRAY_NORMAL] = dn
	d[Mesh.ARRAY_TEX_UV] = du
	d[Mesh.ARRAY_COLOR] = dc
	return d

## Congère tassée au pied d'un prop posé dehors (v5) : ellipse de neige autour de la boîte `bb` (repère du prop) posée en `xf`,
## bord à fleur du sol, bourrelet de quelques cm sur les pieds (ils s'enfoncent), centre ombré (contact : les lots ne portent pas
## d'ombre). `hauteur` (Callable x, z -> y monde) colle chaque sommet au terrain ; sinon sol plat y = 0 du repère de `xf`.
## Renvoie des tableaux dans le repère de `xf` (comme patine_v5) : à poser avec `xf`.
static func congere_v5(bb: AABB, xf: Transform3D, hauteur: Callable = Callable()) -> Array:
	const N := 12
	var c0 := bb.get_center()
	var e := Vector2(bb.size.x * 0.5, bb.size.z * 0.5)
	var sc := xf.basis.get_scale()
	var marge := Vector2(0.16 / maxf(sc.x, 0.05), 0.16 / maxf(sc.z, 0.05))
	var inv := xf.affine_inverse()
	var anneaux := [[0.0, 0.07, Color(0.60, 0.65, 0.78, 0.0)], [0.82, 0.075, Color(0.74, 0.78, 0.88, 0.0)], [1.0, -0.035, Color(0.95, 0.97, 1.0, 0.0)]]
	var pts := []      # [anneau][i] -> Vector3 (repère de xf)
	for an: Array in anneaux:
		var rang := []
		for i in N:
			var ang := TAU * float(i) / N
			var f: float = an[0]
			var dir := Vector2(cos(ang), sin(ang))
			var r := (e + marge) * f
			if f > 0.9:
				r += marge * (0.6 * _hash_v5(xf * Vector3(dir.x, 0, dir.y) * 3.0) - 0.2)
			var pl := Vector3(c0.x + dir.x * r.x, bb.position.y, c0.z + dir.y * r.y)
			var pw := xf * pl
			var y0 := float(hauteur.call(pw.x, pw.z)) if hauteur.is_valid() else (xf * Vector3(pl.x, bb.position.y, pl.z)).y
			pw.y = y0 + float(an[1])
			rang.append(inv * pw)
		pts.append(rang)
	var dv := PackedVector3Array()
	var dc := PackedColorArray()
	for a in 2:
		for i in N:
			var j := (i + 1) % N
			var q := [pts[a][i], pts[a + 1][i], pts[a + 1][j], pts[a][i], pts[a + 1][j], pts[a][j]]
			var cq := [anneaux[a][2], anneaux[a + 1][2], anneaux[a + 1][2], anneaux[a][2], anneaux[a + 1][2], anneaux[a][2]]
			for k in 6:
				dv.append(q[k])
				dc.append(cq[k])
	var dn := PackedVector3Array()
	var du := PackedVector2Array()
	var nl := (xf.basis.inverse() * Vector3.UP).normalized()
	for k in range(0, dv.size(), 3):
		var n := (dv[k + 2] - dv[k]).cross(dv[k + 1] - dv[k])
		if n.dot(nl) < 0.0:      # même sens que le reste du lot (double face de toute façon)
			n = -n
		n = n.normalized() if n.length_squared() > 1e-12 else nl
		for j in 3:
			dn.append(n)
			var w := xf * dv[k + j]
			du.append(Vector2(w.x, w.z) * 0.37)
	var d := []
	d.resize(Mesh.ARRAY_MAX)
	d[Mesh.ARRAY_VERTEX] = dv
	d[Mesh.ARRAY_NORMAL] = dn
	d[Mesh.ARRAY_TEX_UV] = du
	d[Mesh.ARRAY_COLOR] = dc
	return d

# ------------------------------------------------------------------ props/maximum : lot autonome de props texturés
## Un groupe de pq_* (ou q_* servis en pq_*) posé d'un bloc sous `parent` : UN MeshInstance3D (une surface par atlas, matériaux
## partagés de `contexte`) et UN StaticBody3D (boîtes des items marqués solides). Poses : [[id, Transform3D (repère de parent), solide]].
## Aucun nœud par prop. Renvoie le MeshInstance3D (null sans props texturés).
## `v` (le village, v3 abords) : les q_* sans pq_* (charrette, tente, rondins, souche…) y sont admis, une surface par matière de
## mats_village (bois, fer, jute…) ; sans `v` ils sont ignorés.
## v5 dehors : les morceaux pq_* sont patinés (patine_v5) ; une pose [id, xf, solide, congère, neige] avec congère = true (ou un
## Callable de hauteur du terrain) ajoute une congère au pied (congere_v5) ; neige = false : sous un toit, patine sans calotte.
static func lot_pq(parent: Node3D, nom: String, poses: Array, contexte := "exterieur", v: Object = null) -> MeshInstance3D:
	if not pq:
		return null
	var patine := v5 and contexte == "exterieur"
	var sts := {}
	var mats_q := {}
	var corps: StaticBody3D = null
	var specs: Array = []
	for p: Array in poses:
		var id: String = p[0]
		var xf: Transform3D = p[1]
		var parts: Array = []
		var meuble := ObjetsVivants.capte_meuble(id) and (pq_de(id) != "" or id.begins_with("pq_") or v != null)
		if meuble:      # cassables partout : tonneau, caisse, sac… PHYSIQUE (son corps tient lieu de boîte de collision)
			var mv_q := mats_village(v) if v != null else {}
			specs.append(ObjetsVivants.spec_meuble(id, xf, ObjetsVivants.morceaux_contexte(id, contexte, xf.basis.get_scale(),
				func(m: String) -> Material: return mv_q[m] if mv_q.has(m) else (mv_q["bois"] if mv_q.has("bois") else PropsQuat.materiau("pq_bois", contexte))),
				70.0 if contexte == "exterieur" else 30.0, false))
		elif pq_de(id) != "":
			fondu(id, "lot_pq")
			parts = morceaux(id)
		elif v != null and existe(id):
			fondu(id, "lot_pq_q")
			var mv := mats_village(v)
			for m: Array in morceaux(id, {}, false):
				var cle := "q:" + String(m[0])
				mats_q[cle] = mv[m[0]] if mv.has(m[0]) else mv["bois"]
				parts.append([cle, m[1]])
		else:
			continue
		for m: Array in parts:
			if not sts.has(m[0]):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts[m[0]] = st
			var mesh := ArrayMesh.new()
			var nok: bool = not SANS_NEIGE_V5.has(id) and not (p.size() > 4 and p[4] == false)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patine_v5(m[1], m[0], xf, nok) if patine and est_pq(String(m[0])) else m[1])
			(sts[m[0]] as SurfaceTool).append_from(mesh, 0, xf)
		if patine and p.size() > 3 and (p[3] is Callable or p[3] == true):
			var cg := ArrayMesh.new()
			cg.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, congere_v5(boite(id), xf, p[3] if p[3] is Callable else Callable()))
			if not sts.has("pq_bois"):
				var st2 := SurfaceTool.new()
				st2.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts["pq_bois"] = st2
			(sts["pq_bois"] as SurfaceTool).append_from(cg, 0, xf)
		if p.size() > 2 and bool(p[2]) and not meuble:
			if corps == null:
				corps = StaticBody3D.new()
				corps.name = nom + "_corps"
				parent.add_child(corps)
			var bb := boite(id)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bb.size * xf.basis.get_scale()
			cs.shape = bs
			cs.transform = Transform3D(xf.basis.orthonormalized(), xf * bb.get_center())
			corps.add_child(cs)
	if not specs.is_empty():
		ObjetsVivants.peupler(parent, specs, "lot_" + nom)
	if sts.is_empty():
		return null
	var am := ArrayMesh.new()
	for a: String in sts:
		var st: SurfaceTool = sts[a]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		am.surface_set_material(am.get_surface_count() - 1, mats_q[a] if mats_q.has(a) else PropsQuat.materiau(a, contexte))
	if patine:
		PropsQuat.neige_exterieur()
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
