class_name Liquides
extends Node3D
## LIQUIDES RÉALISTES (2026-11-23, branche monde/liquides, docs/LIQUIDES.md) — système commun de tous les liquides du jeu :
## sangs (humain, draugr, troll, araignée), eau, saumure, bière, hydromel, vin, huile, lait, potions. Chaque SORTE a sa couleur, sa
## viscosité, son absorption et son séchage ; chaque SURFACE (pierre, métal, bois, terre, neige) boit plus ou moins.
## - Gouttes balistiques (GouttesSang, pool unique) : gravité, vitesse initiale, rayon le long du vol ; une goutte ne s'arrête jamais
##   en l'air (fin de vie ou pool plein : sa trajectoire est résolue jusqu'au contact, ou elle tombe dans le vide).
## - Impact : tache ronde ou allongée selon la vitesse et l'angle, éclaboussures secondaires, mur : tache + COULURE.
## - Coulures : le liquide descend la pente d'un mur ou d'un plan incliné, se dépose en route (s'arrête quand il n'y en a plus),
##   se détache en goutte au bord (table, étagère) et finit en flaque sur le plat.
## - Flaques : seulement sur le quasi horizontal ; rayon tiré du VOLUME (épaisseur de film de la sorte × surface) ; ne débordent pas
##   dans le vide : chaque direction s'arrête au bord (ou au mur), le surplus s'égoutte par le bord et retombe ; suivent la pente ;
##   deux flaques de même sorte qui se touchent n'en font qu'une (volumes additionnés).
## - Vie : séchage (sang : fonce et mate ; eau : s'évapore, le film mince d'abord), effacement en paliers, jamais de fondu ni de tramage.
## - Contenants : verser_contenant (tonneau, jarre, bouteille, potion brisés) : gerbe puis filet qui faiblit, tout en vraies gouttes.
## Perf : un seul nœud « Liquides » par scène, `_process` coupé dès qu'aucune coulure / flaque qui s'étale / source ne vit ; pools
## plafonnés (MAX_*). Cosmétique : chaque poste rejoue localement (la casse passe déjà par l'évènement réseau objet_casse).
## `--sans-liquides` : ancien comportement (flaque posée par CasseObjets.Flaque, gouttes de sang v3 telles quelles).

static var actif := not OS.get_cmdline_user_args().has("--sans-liquides")
static var instance: Liquides
## Temps CPU cumulé (µs) et compteurs (tests, mesures).
static var cout_us := 0
static var stats := {"flaques": 0, "fusions": 0, "coulures": 0, "taches": 0, "egouttures": 0, "sources": 0, "absorbees": 0}

const MAX_FLAQUES := 24
const MAX_TACHES := 48
const MAX_COULURES := 16          ## coulures qui coulent en même temps
const MAX_FILETS := 32            ## tracés de coulures gardés (segments)
const MAX_SOURCES := 6            ## contenants qui versent en même temps
const PLAT := 0.85                ## normale.y au-dessus : surface « horizontale » (flaque possible)
const R_MAX := 1.7                ## rayon maximal d'une flaque (m)
const SEUIL_FLAQUE_ML := 20.0     ## sous ce volume, une goutte fait une tache, pas une flaque (sauf sur une flaque existante)
const TEXEL := 0.0125             ## taille d'un texel de flaque / filet (m) : comme les traces de sang

# ------------------------------------------------------------------ sortes

## frais : liquide fraîchement versé (opaque : couleur ; translucide : teinte multipliée, le support assombri / teinté) ;
## sec : tache sèche ; vol : gouttes en vol ; halo : liseré sur la neige.
## visc : viscosité relative (eau 1) ; film : épaisseur d'une flaque (mm) ; absorbe : combien les surfaces poreuses le boivent (0-1) ;
## seche / vie : secondes avant séchage complet / avant effacement ; brille : reflet mouillé ; lueur : potions.
const SORTES := {
	"sang_humain": {"frais": Color(0.38, 0.03, 0.024), "sec": Color(0.12, 0.03, 0.024), "vol": Color(0.34, 0.032, 0.026), "halo": Color(0.55, 0.19, 0.19),
		"visc": 4.0, "film": 3.0, "absorbe": 0.3, "seche": 45.0, "vie": 150.0, "brille": 0.75, "opaque": true, "sang": "vif"},
	"sang_draugr": {"frais": Color(0.19, 0.05, 0.042), "sec": Color(0.075, 0.05, 0.045), "vol": Color(0.18, 0.045, 0.038), "halo": Color(0.36, 0.25, 0.24),
		"visc": 6.0, "film": 3.5, "absorbe": 0.25, "seche": 60.0, "vie": 150.0, "brille": 0.6, "opaque": true, "sang": "draugr"},
	"sang_troll": {"frais": Color(0.22, 0.035, 0.065), "sec": Color(0.10, 0.035, 0.05), "vol": Color(0.26, 0.04, 0.075), "halo": Color(0.48, 0.24, 0.32),
		"visc": 5.0, "film": 3.5, "absorbe": 0.3, "seche": 50.0, "vie": 150.0, "brille": 0.65, "opaque": true, "sang": "troll"},
	"sang_araignee": {"frais": Color(0.20, 0.24, 0.06), "sec": Color(0.11, 0.12, 0.045), "vol": Color(0.24, 0.28, 0.07), "halo": Color(0.48, 0.52, 0.30),
		"visc": 3.0, "film": 3.0, "absorbe": 0.35, "seche": 40.0, "vie": 150.0, "brille": 0.7, "opaque": true, "sang": "araignee"},
	"eau": {"frais": Color(0.66, 0.69, 0.74), "sec": Color(0.88, 0.9, 0.92), "vol": Color(0.56, 0.62, 0.68), "halo": Color(0.78, 0.82, 0.88),
		"visc": 1.0, "film": 2.0, "absorbe": 1.0, "seche": 22.0, "vie": 45.0, "brille": 1.0, "opaque": false},
	"saumure": {"frais": Color(0.68, 0.7, 0.64), "sec": Color(0.86, 0.87, 0.82), "vol": Color(0.42, 0.45, 0.4), "halo": Color(0.8, 0.82, 0.76),
		"visc": 1.1, "film": 2.0, "absorbe": 0.9, "seche": 30.0, "vie": 60.0, "brille": 0.9, "opaque": false},
	"biere": {"frais": Color(0.9, 0.74, 0.48), "sec": Color(0.9, 0.82, 0.68), "vol": Color(0.29, 0.22, 0.12), "halo": Color(0.86, 0.74, 0.5),
		"visc": 1.2, "film": 2.2, "absorbe": 0.9, "seche": 35.0, "vie": 75.0, "brille": 0.9, "opaque": false},
	"hydromel": {"frais": Color(0.86, 0.66, 0.34), "sec": Color(0.78, 0.62, 0.38), "vol": Color(0.38, 0.25, 0.08), "halo": Color(0.86, 0.7, 0.4),
		"visc": 3.0, "film": 3.0, "absorbe": 0.55, "seche": 90.0, "vie": 140.0, "brille": 1.0, "opaque": false},
	"vin": {"frais": Color(0.66, 0.3, 0.34), "sec": Color(0.68, 0.44, 0.48), "vol": Color(0.16, 0.015, 0.035), "halo": Color(0.7, 0.42, 0.48),
		"visc": 1.1, "film": 2.0, "absorbe": 0.85, "seche": 40.0, "vie": 120.0, "brille": 0.9, "opaque": false},
	"huile": {"frais": Color(0.66, 0.56, 0.32), "sec": Color(0.68, 0.6, 0.4), "vol": Color(0.4, 0.32, 0.1), "halo": Color(0.8, 0.72, 0.5),
		"visc": 7.0, "film": 2.5, "absorbe": 0.35, "seche": 400.0, "vie": 220.0, "brille": 1.1, "opaque": false},
	"lait": {"frais": Color(0.82, 0.8, 0.74), "sec": Color(0.72, 0.7, 0.63), "vol": Color(0.88, 0.86, 0.8), "halo": Color(0.86, 0.85, 0.82),
		"visc": 1.3, "film": 2.0, "absorbe": 0.75, "seche": 40.0, "vie": 70.0, "brille": 0.55, "opaque": true},
	"potion_soin": {"frais": Color(0.62, 0.06, 0.08), "sec": Color(0.38, 0.06, 0.08), "vol": Color(0.55, 0.05, 0.07), "halo": Color(0.8, 0.4, 0.42),
		"visc": 1.6, "film": 2.2, "absorbe": 0.6, "seche": 50.0, "vie": 90.0, "brille": 1.0, "opaque": true, "lueur": 0.5},
	"potion_mana": {"frais": Color(0.1, 0.2, 0.62), "sec": Color(0.08, 0.14, 0.36), "vol": Color(0.1, 0.18, 0.55), "halo": Color(0.45, 0.55, 0.85),
		"visc": 1.6, "film": 2.2, "absorbe": 0.6, "seche": 50.0, "vie": 90.0, "brille": 1.0, "opaque": true, "lueur": 0.6},
	"potion_vigueur": {"frais": Color(0.16, 0.5, 0.12), "sec": Color(0.12, 0.3, 0.08), "vol": Color(0.12, 0.38, 0.08), "halo": Color(0.5, 0.75, 0.45),
		"visc": 1.6, "film": 2.2, "absorbe": 0.6, "seche": 50.0, "vie": 90.0, "brille": 1.0, "opaque": true, "lueur": 0.5},
}
## Sorte par numéro (les gouttes portent un octet).
const NOMS := ["sang_humain", "sang_draugr", "sang_troll", "sang_araignee", "eau", "saumure", "biere", "hydromel", "vin", "huile", "lait",
	"potion_soin", "potion_mana", "potion_vigueur"]
const SANG_DE := {"vif": "sang_humain", "draugr": "sang_draugr", "troll": "sang_troll", "araignee": "sang_araignee"}

## absorbe : part bue par la surface ; brille : reflet gardé ; film : épaisseur relative d'une flaque ; seche : vitesse relative du séchage.
const SURFACES := {
	"pierre": {"absorbe": 0.0, "brille": 1.0, "film": 1.0, "seche": 1.0},
	"metal": {"absorbe": 0.0, "brille": 1.1, "film": 0.9, "seche": 1.0},
	"bois": {"absorbe": 0.35, "brille": 0.6, "film": 1.25, "seche": 0.75},
	"terre": {"absorbe": 0.75, "brille": 0.3, "film": 1.7, "seche": 0.4},
	"neige": {"absorbe": 1.0, "brille": 0.0, "film": 3.0, "seche": 1.0},
}

static func sorte(nom: String) -> Dictionary:
	return SORTES.get(nom, SORTES["eau"])

static func indice(nom: String) -> int:
	return maxi(NOMS.find(nom), 0)

static func nom(i: int) -> String:
	return NOMS[clampi(i, 0, NOMS.size() - 1)]

static func est_sang(nom_: String) -> bool:
	return nom_.begins_with("sang_")

## Sorte de sang d'après la couleur d'un profil (ProfilCible.couleur_sang), via la palette du sang v3.
static func sang_de(c: Color) -> String:
	return SANG_DE.get(SangV3.sorte_sang(c), "sang_humain")

## Contenu d'un objet brisé : [sorte, litres] ou [] (rien de liquide). Tonneaux et jarres : contenu tiré de l'identifiant (stable en coop).
static func contenu(genre: String, oid: String, ident: String, liquide: bool) -> Array:
	var h := absi(ident.hash()) % 100
	if oid == "potion_soin" or oid == "potion_mana" or oid == "potion_vigueur":
		return [oid, 0.25]
	if oid == "hydromel":
		return ["hydromel", 0.6]
	if oid == "cruche":
		return [] if h < 40 else (["lait", 1.0] if h < 60 else ["eau", 1.2])
	if not liquide:
		return []
	if genre.contains("tonneau"):
		if genre.contains("pommes"):
			return []
		return [("biere" if h < 60 else ("hydromel" if h < 80 else ("eau" if h < 90 else "vin"))), 28.0]
	if genre.contains("jarre"):
		return [["eau", "vin", "huile", "lait", "saumure"][h % 5], 3.0]
	return ["saumure", 3.0]

# ------------------------------------------------------------------ nœud de scène

static func obtenir(n: Node) -> Liquides:
	if is_instance_valid(instance) and instance.is_inside_tree():
		return instance
	if n == null or not n.is_inside_tree():
		return null
	var arbre := n.get_tree()
	var l := Liquides.new()
	l.name = "Liquides"
	(arbre.current_scene if arbre.current_scene != null else arbre.root).add_child(l)
	instance = l
	return l

var flaques: Array = []           ## Flaque (les plus anciennes d'abord)
var taches: Array = []            ## MeshInstance3D
var filets: Array = []            ## MeshInstance3D (segments de coulure)
var coulures: Array = []          ## Coulure en mouvement
var sources: Array = []           ## Source (contenant qui verse)
var _acc := 0.0
var _exclus: Array[RID] = []

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	set_process(false)

func _reveiller() -> void:
	if not is_processing():
		_exclus = Sang._exclus(get_tree())
		set_process(true)

## Pas de 1/20 s : sources, coulures, flaques qui s'étalent ou s'égouttent. Coupé dès qu'il n'y a plus rien à faire.
func _process(dt: float) -> void:
	_acc += dt
	if _acc < 0.05:
		return
	var pas := minf(_acc, 0.1)
	_acc = 0.0
	var t0 := Time.get_ticks_usec()
	var espace := get_world_3d().direct_space_state
	var i := 0
	while i < sources.size():
		if not (sources[i] as Source).avancer(self, pas):
			sources.remove_at(i)
			continue
		i += 1
	i = 0
	while i < coulures.size():
		if not (coulures[i] as Coulure).avancer(self, espace, pas):
			coulures.remove_at(i)
			continue
		i += 1
	var vivantes := false
	for f0: Variant in flaques:
		if is_instance_valid(f0) and (f0 as Flaque).vit:
			(f0 as Flaque).avancer(self, pas)
			vivantes = vivantes or (f0 as Flaque).vit
	cout_us += Time.get_ticks_usec() - t0
	if sources.is_empty() and coulures.is_empty() and not vivantes:
		set_process(false)

# ------------------------------------------------------------------ surfaces

## Matière de la surface touchée (rayon) : méta « surface_liquide » du corps s'il en a une ; neige au sol dehors ; props (bois ou
## fer) ; souterrain (crypte, grotte) : pierre ; intérieur : bois ; dehors : terre au sol, pierre aux murs.
static func surface(r: Dictionary) -> String:
	var c: Object = r.get("collider")
	var p: Vector3 = r["position"]
	var nrm: Vector3 = r["normal"]
	if c is Node and (c as Node).has_meta("surface_liquide"):
		return String((c as Node).get_meta("surface_liquide"))
	if nrm.y > 0.6 and EffetsSol.est_neige(p.x, p.z):
		return "neige"
	if c is RigidBody3D:
		var m := String((c as Object).get("matiere")) if (c as Object).get("matiere") != null else "bois"
		return "metal" if m == "fer" else ("pierre" if m in ["poterie", "verre", "pierre"] else "bois")
	if p.y < -8.0:
		return "pierre"
	if not EffetsSol.neige_dehors() or not EffetsSol.dehors:
		return "bois"
	return "terre" if nrm.y > 0.6 else "pierre"

## Corps qui peut recevoir du liquide (décor, props) ; pas un personnage, ni un os de ragdoll.
static func _support_ok(r: Dictionary) -> bool:
	var c: Object = r.get("collider")
	if c == null or c is CharacterBody3D or c is PhysicalBone3D:
		return false
	return not (c is Node and (c as Node).is_in_group("ennemis"))

## Le point est dans une eau (lac, rivière, mare) : le liquide s'y dilue, rien ne reste.
static func dans_eau(p: Vector3) -> bool:
	var e := EffetsSol.instance
	if e == null:
		return false
	for w in e._eaux:
		if is_instance_valid(w) and w.contient(p.x, p.z) and p.y < float(w.niveau) + 0.3:
			return true
	return false

# ------------------------------------------------------------------ impact d'une goutte

## Une goutte de `vol_ml` mL de `nom_` arrive en `r` (rayon) à la vitesse `v`. `couleur` : celle de la goutte de sang (palette v3).
## Sang : tache par Sang.trace (rendu du sang v3) ; autres : tache, flaque ou coulure du système liquide.
static func impact(n: Node, r: Dictionary, v: Vector3, nom_: String, vol_ml: float, taille: float, couleur := Color.BLACK, tacher := true) -> void:
	var t0 := Time.get_ticks_usec()
	var l := obtenir(n)
	if l == null or not _support_ok(r):
		return
	var p: Vector3 = r["position"]
	var nrm: Vector3 = r["normal"]
	if dans_eau(p):
		return
	var surf := surface(r)
	var sup: Node3D = r["collider"] if r["collider"] is RigidBody3D else null
	var vn := v.dot(nrm)
	var tang := v - nrm * vn
	var rasant := tang.length() > absf(vn) * 1.1
	var sang := est_sang(nom_)
	# éclaboussures secondaires : un impact rapide renvoie quelques gouttelettes (pas sur la neige, qui boit)
	var dans_flaque: Flaque = l._flaque_sous(p, nrm, nom_) if nrm.y > PLAT and sup == null else null
	if v.length() > 3.5 and vol_ml > 0.8 and surf != "neige" and dans_flaque == null and GouttesSang.en_vol() < GouttesSang._max() * 0.5:
		var nb := clampi(int(v.length() * 0.35 + vol_ml * 0.2), 1, 3)
		for k in nb:
			var dv := tang * randf_range(0.15, 0.4) + nrm * randf_range(0.6, 1.4) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
			GouttesSang.lacher_liquide(n, p + nrm * 0.02, dv, nom_, vol_ml * 0.06, 0.5, couleur)
		vol_ml *= 0.8
	if nrm.y > PLAT and sup == null:
		var f := dans_flaque
		var cumul := vol_ml if sang else l._cumuler(p, nom_, vol_ml)      # gouttes qui tombent au même endroit (égouttement) : elles s'additionnent
		if f != null:
			f.ajouter(l, vol_ml / 1000.0, p)
		elif cumul >= SEUIL_FLAQUE_ML:
			l._oublier(p, nom_)
			l._nouvelle_flaque(n, p, nrm, nom_, cumul / 1000.0, surf)
		elif tacher and (sang or cumul <= vol_ml + 0.01):
			l._tache(n, p, nrm, v, nom_, vol_ml, taille, rasant, surf, couleur, null)
	elif nrm.y < -0.3:
		# dessous (plafond, dessous de table) : une tache, et le reste retombe en goutte
		if tacher:
			l._tache(n, p, nrm, v, nom_, vol_ml * 0.4, taille * 0.8, false, surf, couleur, sup)
		if vol_ml > 0.3:
			GouttesSang.lacher_liquide(n, p + nrm * 0.012, Vector3.ZERO, nom_, vol_ml * 0.6, taille * 0.8, couleur)
	else:
		# mur, pente, prop : tache, et un filet qui coule si la goutte est assez grosse
		if tacher:
			l._tache(n, p, nrm, v, nom_, vol_ml, taille, rasant or nrm.y < PLAT, surf, couleur, sup)
		if sup == null and vol_ml >= 0.7 * float(sorte(nom_)["visc"]) * (1.0 if not sang else 0.9) and surf != "neige" and (not sang or randf() < 0.6):
			l.coulure(n, p, nrm, nom_, vol_ml * 0.75, couleur)
	cout_us += Time.get_ticks_usec() - t0

# ------------------------------------------------------------------ cumul des petites gouttes

## Petites gouttes tombées au même endroit (case de 12 cm) depuis moins de 8 s : leur volume s'additionne ; au-delà du seuil, une
## flaque naît là (un filet qui goutte d'une étagère finit en flaque, pas en 600 taches).
var _cumul := {}

func _cle_cumul(p: Vector3, nom_: String) -> String:
	return "%s|%d|%d|%d" % [nom_, floori(p.x / 0.12), floori(p.y / 0.12), floori(p.z / 0.12)]

func _cumuler(p: Vector3, nom_: String, ml: float) -> float:
	var maintenant := Time.get_ticks_msec()
	if _cumul.size() > 96:
		for k: String in _cumul.keys():
			if maintenant - int((_cumul[k] as Array)[1]) > 8000:
				_cumul.erase(k)
	var cle := _cle_cumul(p, nom_)
	var e: Array = _cumul.get(cle, [0.0, maintenant])
	if maintenant - int(e[1]) > 8000:
		e = [0.0, maintenant]
	e[0] = float(e[0]) + ml
	e[1] = maintenant
	_cumul[cle] = e
	return float(e[0])

func _oublier(p: Vector3, nom_: String) -> void:
	_cumul.erase(_cle_cumul(p, nom_))

# ------------------------------------------------------------------ taches

## Tache d'impact : sang (Sang.trace, rendu sang v3) ou liquide (plan ou grille projetée, matériau du liquide). Pool MAX_TACHES.
func _tache(n: Node, p: Vector3, nrm: Vector3, v: Vector3, nom_: String, vol_ml: float, taille: float, allongee: bool, surf: String,
		couleur: Color, sup: Node3D) -> void:
	var t := randf_range(0.07, 0.115) * taille * (1.3 if allongee else 1.0)
	if not bool(sorte(nom_).get("opaque", false)) and nrm.y < PLAT:
		t *= 0.7      # un liquide clair éclabousse un mur en taches plus petites (il coule aussitôt)
	if surf == "neige":
		t *= 1.35     # la neige boit : tache plus large et diffuse
	if est_sang(nom_):
		var c: Color = couleur if couleur != Color.BLACK else sorte(nom_)["frais"]
		Sang.trace(n, p, nrm, v, t, c, "giclure" if allongee else "goutte", 0.0, 0.0, sup)
		return
	stats["taches"] += 1
	var t_us := Time.get_ticks_usec()
	var mi := _recycler(taches, MAX_TACHES)
	var forme := "giclure" if allongee else "goutte"
	mi.material_override = materiau(nom_, surf, 0, SangV3.texture(forme, randi() % 3))
	_poser_plan(mi, n, p, nrm, v, t * (1.35 if allongee else 1.0), t, sup)
	_vieillir(mi, nom_, surf)
	stats["us_taches"] = int(stats.get("us_taches", 0)) + Time.get_ticks_usec() - t_us

## Une place dans un pool (plein : le plus ancien est repris).
func _recycler(pool: Array, maxi: int) -> MeshInstance3D:
	var i := 0
	while i < pool.size():
		if not is_instance_valid(pool[i]):
			pool.remove_at(i)
		else:
			i += 1
	var mi: MeshInstance3D
	if pool.size() >= maxi:
		mi = pool.pop_front()
		mi.visible = true
		if mi.get_parent() != self:
			mi.reparent(self, false)
	else:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	pool.append(mi)
	return mi

static var _plan: PlaneMesh

func _poser_plan(mi: MeshInstance3D, n: Node, p: Vector3, nrm: Vector3, dir: Vector3, demi_long: float, demi_larg: float, sup: Node3D) -> void:
	if _plan == null:
		_plan = PlaneMesh.new()
		_plan.size = Vector2.ONE
	var y := nrm.normalized()
	var x := dir - y * dir.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).rotated(y, randf() * TAU)
	x = x.normalized()
	var z := x.cross(y)
	var leve := 0.035 if y.y > 0.6 else 0.012
	var xf := Transform3D(Basis(x, y, z), p + y * leve)
	mi.mesh = SangV3.maille_projetee(n as Node3D if n is Node3D else null, xf, demi_long, demi_larg, leve) if demi_long > 0.12 else _plan
	if is_instance_valid(sup) and sup.is_inside_tree() and mi.get_parent() != sup:
		mi.reparent(sup, false)
	mi.global_transform = Transform3D(Basis(x * demi_long * 2.0, y, z * demi_larg * 2.0), p + y * leve)

## Séchage et effacement (SangV3.Vieillissement, horloge du jeu) aux durées de la sorte sur cette surface.
static func _vieillir(mi: MeshInstance3D, nom_: String, surf: String, facteur := 1.0) -> void:
	# uniformes d'instance remis à zéro APRÈS le matériau et l'entrée dans l'arbre (piège du sang v3 : trace invisible sinon)
	mi.set_instance_shader_parameter("seche", 0.0)
	mi.set_instance_shader_parameter("efface", 0.0)
	var g := Sang.gestion_racine(mi.get_tree())
	if g == null:
		return
	var so := sorte(nom_)
	var su: Dictionary = SURFACES.get(surf, SURFACES["pierre"])
	var bu := float(su["absorbe"]) * float(so["absorbe"])
	var seche := float(so["seche"]) * lerpf(1.0, float(su["seche"]), float(so["absorbe"])) * facteur
	var vie := float(so["vie"]) * (1.0 - 0.5 * bu) * facteur
	SangV3.vieillissement(g).ajouter(mi, maxf(seche, 4.0), maxf(vie, seche + 2.0))

# ------------------------------------------------------------------ flaques

## Flaque existante de cette sorte qui contient (ou touche) le point, sur le même plan.
func _flaque_sous(p: Vector3, nrm: Vector3, nom_: String) -> Flaque:
	for f0: Variant in flaques:
		if is_instance_valid(f0) and (f0 as Flaque).liquide == nom_ and (f0 as Flaque).touche(p, nrm):
			return f0
	return null

func _nouvelle_flaque(n: Node, p: Vector3, nrm: Vector3, nom_: String, litres: float, surf: String) -> Flaque:
	var i := 0
	while i < flaques.size():
		if not is_instance_valid(flaques[i]):
			flaques.remove_at(i)
		else:
			i += 1
	while flaques.size() >= MAX_FLAQUES:
		(flaques.pop_front() as Node).queue_free()
	stats["flaques"] += 1
	var f := Flaque.new()
	f.liquide = nom_
	f.surf = surf
	f.centre = p
	f.nrm = nrm
	f.volume = litres
	f.add_to_group("flaques")
	add_child(f)
	f.construire(self)
	flaques.append(f)
	_vieillir(f, nom_, surf, 1.5)
	_reveiller()
	return f

## Deux flaques de même sorte sur le même plan qui se touchent : la plus grosse boit l'autre (volumes additionnés, centre pondéré).
func _fusionner(f: Flaque) -> void:
	for g0: Variant in flaques:
		if not is_instance_valid(g0) or g0 == f or (g0 as Node).is_queued_for_deletion():
			continue
		var g := g0 as Flaque
		if g.liquide != f.liquide or g.nrm.dot(f.nrm) < 0.95 or absf((g.centre - f.centre).dot(f.nrm)) > 0.05:
			continue
		var d := g.centre - f.centre
		d -= f.nrm * d.dot(f.nrm)
		if d.length() > (f.r_bati + g.r_bati) * 0.95:
			continue
		var gros := f if f.volume >= g.volume else g
		var petit := g if gros == f else f
		stats["fusions"] += 1
		var w := petit.volume / maxf(gros.volume + petit.volume, 0.0001)
		gros.centre += (petit.centre - gros.centre) * w
		gros.volume += petit.volume
		gros.exces += petit.exces
		gros._e = maxf(gros._e, petit._e * petit.r_bati / maxf(gros.r_bati, 0.01))
		gros._attente = true
		gros.vit = true
		petit.queue_free()
		_reveiller()
		return

## Verse `litres` de `nom_` en `p` (déjà sur la surface) : rejoint une flaque qui touche, sinon en crée une. Sur un mur : coulure.
static func flaque(n: Node, p: Vector3, nrm: Vector3, nom_: String, litres: float) -> Node3D:
	var l := obtenir(n)
	if l == null:
		return null
	if nrm.y < PLAT:
		l.coulure(n, p, nrm, nom_, litres * 1000.0)
		return null
	var f := l._flaque_sous(p, nrm, nom_)
	if f != null:
		f.ajouter(l, litres, p)
		return f
	# la surface sous le point (sa matière)
	var q := PhysicsRayQueryParameters3D.create(p + nrm * 0.05, p - nrm * 0.1, 1, l._exclus)
	var r := l.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		r = {"position": p, "normal": nrm, "collider": null}
	return l._nouvelle_flaque(n, p, nrm, nom_, litres, surface(r))

## Épaisseur (m) d'une flaque de cette sorte sur cette surface : la surface poreuse en boit une part (le film paraît plus épais).
static func film(nom_: String, surf: String) -> float:
	var so := sorte(nom_)
	var su: Dictionary = SURFACES.get(surf, SURFACES["pierre"])
	return float(so["film"]) / 1000.0 * lerpf(1.0, float(su["film"]), clampf(float(so["absorbe"]) * 1.5, 0.0, 1.0))

static func rayon_pour(nom_: String, surf: String, litres: float) -> float:
	return clampf(sqrt(maxf(litres, 0.0) * 0.001 / film(nom_, surf) / PI), 0.05, R_MAX)

class Flaque extends MeshInstance3D:
	const DIRS := 16
	var liquide := "eau"
	var surf := "pierre"
	var centre := Vector3.ZERO
	var nrm := Vector3.UP
	var volume := 0.0          ## litres retenus par la flaque
	var exces := 0.0           ## litres qui débordent et s'égouttent par les bords
	var r_cible := 0.1
	var r_bati := 0.0
	var portee := PackedFloat32Array()    ## portée par direction (m), bord ou mur
	var bords: Array = []                 ## [point du bord, direction vers l'extérieur] où le liquide déborde dans le vide
	var etendue := 0.0
	var _e := 0.0               ## étendue continue (l'uniforme avance par paliers de 1/15)
	var vit := true            ## s'étale, s'égoutte ou attend une reconstruction
	var _t := 0.0
	var _depuis_bati := 0.0
	var _attente := false

	func touche(p: Vector3, n2: Vector3) -> bool:
		if n2.dot(nrm) < 0.95 or absf((p - centre).dot(nrm)) > 0.05:
			return false
		var d := p - centre
		d -= nrm * d.dot(nrm)
		return d.length() <= maxf(r_bati, r_cible) * 1.05 + 0.04

	func capacite() -> float:
		var a := 0.0
		for k in DIRS:
			a += 0.5 * portee[k] * portee[k] * TAU / DIRS
		return a * Liquides.film(liquide, surf) * 1.15 * 1000.0      # litres

	## Ajoute du liquide (goutte, filet, autre flaque) : la flaque grandit (reconstruite par paliers), le surplus s'égoutte.
	func ajouter(l: Liquides, litres: float, p: Vector3) -> void:
		# le centre glisse vers ce qui arrive (pondéré par le volume) : la flaque se forme là où tombe le gros du liquide
		var d := p - centre
		d -= nrm * d.dot(nrm)
		var w := litres / maxf(volume + litres, 0.0001)
		volume += litres
		if d.length() * w > 0.04 and portee.size() > 0:
			centre += d * w
			_attente = true
		Liquides.stats["fusions"] += 1
		var r := Liquides.rayon_pour(liquide, surf, volume)
		if r > r_bati * 1.18 and r_bati < Liquides.R_MAX:
			r_cible = r
			_attente = true
		else:
			var cap := capacite()
			if volume > cap:
				exces += volume - cap
				volume = cap
		# remise à neuf : du liquide frais sur une flaque qui séchait (son âge repart de zéro)
		Liquides._vieillir(self, liquide, surf, 1.5)
		vit = true
		l._reveiller()

	## Rayons : la portée de chaque direction s'arrête au mur ou au bord (le surplus coule par les bords), le relief est suivi.
	func construire(l: Liquides) -> void:
		var t_us := Time.get_ticks_usec()
		Liquides.stats["constructions"] = int(Liquides.stats.get("constructions", 0)) + 1
		var espace := l.get_world_3d().direct_space_state
		r_cible = Liquides.rayon_pour(liquide, surf, volume)
		var y := nrm.normalized()
		# pente : la flaque glisse un peu vers le bas de la pente et s'y allonge
		var aval := Vector3.DOWN - y * Vector3.DOWN.dot(y)
		var pente := aval.length()
		var x := (aval / pente) if pente > 0.02 else y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		var c := centre + x * (r_cible * clampf(pente * 2.5, 0.0, 0.45) if pente > 0.02 else 0.0)
		var R := r_cible * 1.2
		if r_bati > 0.0:      # reconstruite plus grande : le bord visible ne saute pas, il reprend son étalement
			_e *= r_bati / r_cible
			etendue = ceilf(_e * 15.0) / 15.0
		portee.resize(DIRS)
		bords.clear()
		var hauts := PackedFloat32Array()
		hauts.resize(DIRS)
		var ex := l._exclus
		for k in DIRS:
			var a := TAU * k / DIRS
			var d := (x * cos(a) + z * sin(a)).normalized()
			var lim := R * (1.0 + (0.35 * pente * 2.0 if cos(a) > 0.5 and pente > 0.02 else 0.0))
			# mur : rayon rasant depuis le centre
			var q := PhysicsRayQueryParameters3D.create(c + y * 0.025, c + y * 0.025 + d * lim, 1, ex)
			var h := espace.intersect_ray(q)
			if not h.is_empty():
				lim = maxf(c.distance_to(h["position"]) - 0.015, 0.02)
			# bord : sondes descendantes, de plus en plus loin, sur le plan de la surface
			var ok := 0.0
			var hh := 0.0
			var vide := false
			var nb := 4 if lim < 0.8 else 6
			for j in range(1, nb + 1):
				var s := lim * j / nb
				var dz := _sonder(espace, c + d * s, y, ex)
				if dz == INF or absf(dz) > 0.025:
					vide = dz == INF or dz < 0.0
					# affinage : à mi-chemin du dernier bon point
					var m := (ok + s) * 0.5
					var dm := _sonder(espace, c + d * m, y, ex)
					if dm != INF and absf(dm) <= 0.025:
						ok = m
						hh = dm
					break
				ok = s
				hh = dz
			portee[k] = maxf(ok - 0.01, 0.0) if ok < lim - 0.001 else lim
			hauts[k] = hh
			if vide and ok < R * 0.98:
				bords.append([c + d * (ok + 0.015) + y * hh, d])
		centre = c
		r_bati = r_cible
		_depuis_bati = 0.0
		_attente = false
		# maille : éventail à deux couronnes, sommets à la hauteur du relief sondé ; UV planes sur ±R
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var nn := PackedVector3Array()
		var ind := PackedInt32Array()
		v.append(Vector3.ZERO)
		uv.append(Vector2(0.5, 0.5))
		nn.append(Vector3.UP)
		for anneau in 2:
			var f := 0.5 if anneau == 0 else 1.0
			for k in DIRS:
				var a := TAU * k / DIRS
				var pl := Vector3(cos(a), 0, sin(a)) * portee[k] * f
				v.append(pl + Vector3(0, hauts[k] * f, 0))
				uv.append(Vector2(pl.x, pl.z) / (2.0 * R) + Vector2(0.5, 0.5))
				nn.append(Vector3.UP)
		for k in DIRS:
			var k1 := (k + 1) % DIRS
			ind.append_array([0, 1 + k1, 1 + k])
			ind.append_array([1 + k, 1 + k1, 1 + DIRS + k])
			ind.append_array([1 + k1, 1 + DIRS + k1, 1 + DIRS + k])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = ind
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh = am
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material_override = Liquides.materiau(liquide, surf, 1)
		global_transform = Transform3D(Basis(x, y, z), centre + y * (0.035 if surf != "pierre" else 0.03) + y * 0.0009 * (l.flaques.size() % 8))
		set_instance_shader_parameter("texels", 2.0 * R / Liquides.TEXEL)
		set_instance_shader_parameter("etendue", maxf(etendue, 0.05))
		# capacité : ce qui ne tient pas déborde par les bords (ou, sans bord, reste : la flaque est pleine)
		var cap := capacite()
		if volume > cap:
			if not bords.is_empty():
				exces += volume - cap
			volume = cap
		vit = true
		l._fusionner(self)
		Liquides.stats["us_constructions"] = int(Liquides.stats.get("us_constructions", 0)) + Time.get_ticks_usec() - t_us

	## Hauteur (le long de la normale) de la surface sous `p` par rapport au plan, ou INF (vide).
	static func _sonder(espace: PhysicsDirectSpaceState3D, p: Vector3, y: Vector3, ex: Array[RID]) -> float:
		var q := PhysicsRayQueryParameters3D.create(p + y * 0.06, p - y * 0.12, 1, ex)
		var h := espace.intersect_ray(q)
		if h.is_empty() or h["collider"] is CharacterBody3D or h["collider"] is PhysicalBone3D:
			return INF
		return (h["position"] as Vector3 - p).dot(y)

	## Étalement (paliers nets de l'étendue, plus lents pour un liquide visqueux), égouttement du surplus par les bords.
	func avancer(l: Liquides, dt: float) -> void:
		_t += dt
		_depuis_bati += dt
		if _attente and _depuis_bati > 0.25:
			construire(l)
		var visc := float(Liquides.sorte(liquide)["visc"])
		var duree := 0.8 * sqrt(visc) * (0.6 + r_bati)
		# s'étale vite au début puis ralentit (le front s'épaissit), plus lentement pour un liquide visqueux
		_e = minf(1.0, _e + dt / duree * (1.6 - _e))
		var q := ceilf(_e * 15.0) / 15.0
		if q != etendue:
			etendue = q
			set_instance_shader_parameter("etendue", etendue)
		if exces > 0.0005 and not bords.is_empty():
			var debit := 0.5 / sqrt(visc) * dt      # litres par pas
			var nb := mini(bords.size(), 2 if GouttesSang.en_vol() < GouttesSang._max() * 0.6 else 1)
			var part := minf(exces, debit) / nb
			for k in nb:
				var b: Array = bords[(int(_t * 20.0) + k * 7) % bords.size()]
				var d: Vector3 = b[1]
				var pt: Vector3 = b[0] + d * 0.012 - nrm * 0.012
				GouttesSang.lacher_liquide(l, pt + Vector3(randf_range(-0.01, 0.01), 0, randf_range(-0.01, 0.01)), d * randf_range(0.15, 0.35),
					liquide, part * 1000.0, clampf(pow(part * 1000.0 / 4.0, 0.333), 0.6, 1.4))
				Liquides.stats["egouttures"] += 1
			exces -= minf(exces, debit)
		elif bords.is_empty():
			exces = 0.0
		vit = _e < 1.0 or (exces > 0.0005 and not bords.is_empty()) or _attente

# ------------------------------------------------------------------ coulures

## Filet qui coule sur un mur ou une pente depuis `p` : il descend, se dépose en route et s'arrête quand il est épuisé ; au bord il se
## détache en goutte ; sur le plat il finit en tache ou en flaque.
func coulure(n: Node, p: Vector3, nrm: Vector3, nom_: String, vol_ml: float, couleur := Color.BLACK) -> void:
	if coulures.size() >= MAX_COULURES:
		var vieille: Coulure = coulures.pop_front()
		vieille.finir(self, false)
	stats["coulures"] += 1
	var c := Coulure.new()
	c.liquide = nom_
	c.p = p
	c.nrm = nrm.normalized()
	c.vol = vol_ml
	c.couleur = couleur
	c.surf = surface({"position": p, "normal": nrm, "collider": null})
	c.largeur = clampf(0.012 + vol_ml * 0.004, 0.014, 0.04) * (1.0 + 0.08 * float(sorte(nom_)["visc"]))
	c.nouveau_segment(self)
	coulures.append(c)
	_reveiller()

class Coulure extends RefCounted:
	var liquide := "eau"
	var surf := "pierre"
	var p := Vector3.ZERO
	var nrm := Vector3.FORWARD
	var vol := 1.0
	var couleur := Color.BLACK
	var largeur := 0.02
	var depart := Vector3.ZERO
	var dir := Vector3.DOWN
	var mi: MeshInstance3D
	var t := 0.0
	var parcouru := 0.0
	var col: Object = null      ## dernier corps du décor touché (matière du sol où il finit)

	func nouveau_segment(l: Liquides) -> void:
		depart = p
		mi = l._recycler(l.filets, Liquides.MAX_FILETS)
		mi.mesh = Liquides._plan_unite()
		mi.material_override = Liquides.materiau(liquide, surf, 2, null, couleur)
		mi.set_instance_shader_parameter("texels", maxf(largeur / 0.006, 3.0))
		mi.set_instance_shader_parameter("allonge", 1.0)
		mi.visible = false
		Liquides._vieillir(mi, liquide, surf)

	## Un pas : faux quand la coulure est finie.
	func avancer(l: Liquides, espace: PhysicsDirectSpaceState3D, dt: float) -> bool:
		t += dt
		var g := Vector3.DOWN - nrm * Vector3.DOWN.dot(nrm)
		var gl := g.length()
		if gl < 0.3 or t > 25.0 or parcouru > 3.0:
			finir(l, true)
			return false
		dir = g / gl
		var so := Liquides.sorte(liquide)
		var visc := float(so["visc"])
		var vitesse := clampf(0.45 / visc, 0.05, 0.5) * gl * (0.7 + 0.6 * minf(vol / 4.0, 1.0))
		var pas := vitesse * dt
		var ex := l._exclus
		# obstacle dans le sens de l'écoulement (sol au pied du mur, rebord)
		var q1 := PhysicsRayQueryParameters3D.create(p + nrm * 0.01, p + nrm * 0.01 + dir * (pas + 0.01), 1, ex)
		var h1 := espace.intersect_ray(q1)
		if not h1.is_empty() and Liquides._support_ok(h1):
			var n1: Vector3 = h1["normal"]
			_etirer(h1["position"] as Vector3 - nrm * 0.01)
			p = h1["position"]
			col = h1["collider"]
			if n1.y > Liquides.PLAT:
				nrm = n1
				finir(l, true)
				return false
			nrm = n1
			nouveau_segment(l)
			return true
		var p2 := p + dir * pas
		var q2 := PhysicsRayQueryParameters3D.create(p2 + nrm * 0.04, p2 - nrm * 0.08, 1, ex)
		var h2 := espace.intersect_ray(q2)
		if h2.is_empty() or not Liquides._support_ok(h2):
			# bord : le filet se détache et tombe
			_etirer(p2)
			GouttesSang.lacher_liquide(l, p2 + dir * 0.006 + nrm * 0.006, dir * vitesse, liquide, vol, clampf(pow(vol / 1.5, 0.333), 0.6, 2.0), couleur)
			vol = 0.0
			finir(l, false)
			return false
		var n2: Vector3 = h2["normal"]
		p = h2["position"]
		col = h2["collider"]
		parcouru += pas
		var bu := float(Liquides.SURFACES.get(surf, Liquides.SURFACES["pierre"])["absorbe"]) * float(so["absorbe"])
		vol -= pas * (3.0 + 2.5 * visc) * (1.0 + bu * 2.0)       # dépôt (mL par m) : un liquide épais se dépose vite (coulure courte)
		if n2.dot(nrm) < 0.97:
			nrm = n2
			nouveau_segment(l)
		else:
			_etirer(p)
		if vol <= 0.0:
			finir(l, false)
			return false
		return true

	## Le segment va de `depart` à `jusqu_a` (plan sur la surface, x le long de l'écoulement).
	func _etirer(jusqu_a: Vector3) -> void:
		if not is_instance_valid(mi):
			return
		var d := jusqu_a - depart
		var lg := d.length()
		if lg < 0.01:
			return
		var x := d / lg
		var y := nrm
		var z := x.cross(y).normalized()
		mi.visible = true
		mi.global_transform = Transform3D(Basis(x * (lg + largeur * 0.5), y, z * largeur), (depart + jusqu_a) * 0.5 + x * largeur * 0.25 + y * 0.012)
		mi.set_instance_shader_parameter("allonge", (lg + largeur * 0.5) / largeur)

	## Fin : sur le plat, le reste fait une tache ou rejoint une flaque ; sinon une perle au bout du filet.
	func finir(l: Liquides, sur_plat: bool) -> void:
		if vol <= 0.0 and not sur_plat:
			# perle au bout du filet (le liquide s'accumule là où il s'arrête)
			l._tache(l, p + dir * largeur * 0.3, nrm, dir, liquide, 0.5, clampf(largeur / 0.03, 0.45, 0.9), false, surf, couleur, null)
			return
		if sur_plat and vol > 0.0:
			Liquides.impact(l, {"position": p, "normal": nrm, "collider": col if is_instance_valid(col) else l}, Vector3.DOWN * 0.3, liquide, vol, 0.8, couleur)
		vol = 0.0

static var _unite: PlaneMesh
static func _plan_unite() -> PlaneMesh:
	if _unite == null:
		_unite = PlaneMesh.new()
		_unite.size = Vector2.ONE
	return _unite

# ------------------------------------------------------------------ contenants

## Contenant brisé (tonneau, jarre, bouteille, potion) en `centre`, animé de `vitesse` : le contenu jaillit (gerbe de vraies gouttes),
## puis s'écoule en filet qui faiblit pendant ~1-2 s ; tout retombe (étagère, sol) et s'y étale / coule / s'égoutte.
static func verser_contenant(n: Node, centre: Vector3, vitesse: Vector3, nom_: String, litres: float, taille := 0.6) -> void:
	var l := obtenir(n)
	if l == null:
		return
	var t0 := Time.get_ticks_usec()
	stats["sources"] += 1
	while l.sources.size() >= MAX_SOURCES:
		l.sources.pop_front()
	var s := Source.new()
	s.liquide = nom_
	s.centre = centre
	s.vitesse = vitesse
	s.reste = litres
	s.total = litres
	s.taille = taille
	s.duree = clampf(0.5 + litres * 0.06, 0.5, 2.2)
	# gerbe : 40 % du contenu d'un coup, des gouttes plus ou moins grosses dans toutes les directions horizontales, un peu vers le haut
	var libres := GouttesSang._max() - GouttesSang.en_vol()
	var nb := clampi(mini(int(14 + litres * 1.6), int(libres * 0.6)), 4, 56)
	var gerbe := litres * 0.4
	for k in nb:
		var a := randf() * TAU
		var dh := Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 2.4) * clampf(taille * 1.6, 0.5, 1.4)
		var v := vitesse * 0.6 + dh + Vector3(0, randf_range(-0.3, 1.6), 0)
		var ml := gerbe * 1000.0 / nb * randf_range(0.5, 1.5)
		var p := centre + Vector3(cos(a), randf_range(-0.4, 0.4), sin(a)) * taille * 0.35
		GouttesSang.lacher_liquide(l, p, v, nom_, ml, clampf(pow(ml / 4.0, 0.333), 0.7, 1.9))
	s.reste -= gerbe
	l.sources.append(s)
	l._reveiller()
	cout_us += Time.get_ticks_usec() - t0

class Source extends RefCounted:
	var liquide := "eau"
	var centre := Vector3.ZERO
	var vitesse := Vector3.ZERO
	var reste := 0.0
	var total := 0.0
	var taille := 0.6
	var duree := 1.0
	var t := 0.0

	## Filet qui faiblit : le débit suit le niveau qui baisse (vidange), l'origine descend avec lui.
	func avancer(l: Liquides, dt: float) -> bool:
		t += dt
		if reste <= 0.0 or t > duree:
			return false
		var k := 1.0 - t / duree
		var debit := reste * clampf(dt / maxf(duree - t, dt) * 1.3, 0.0, 1.0)
		var nb := 5 if k > 0.6 else (3 if k > 0.3 else (2 if k > 0.12 else 1))
		# pool presque plein (plusieurs contenants à la fois) : moins de gouttes, plus grosses (le volume versé ne change pas)
		if GouttesSang.en_vol() > GouttesSang._max() * 0.7:
			nb = 1
		for j in nb:
			var a := randf() * TAU
			var ml := debit * 1000.0 / nb
			var p := centre + Vector3(cos(a) * taille * 0.3, -taille * 0.3 * (1.0 - k), sin(a) * taille * 0.3)
			var v := vitesse * 0.2 + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.1) * k + Vector3(0, -0.2, 0)
			GouttesSang.lacher_liquide(l, p, v, liquide, ml, clampf(pow(ml / 4.0, 0.333), 0.7, 1.9))
		reste -= debit
		return true

# ------------------------------------------------------------------ empreintes

## Semelle mouillée : sorte et nombre d'empreintes qu'il reste à laisser (marcher dans une flaque fraîche, de sang surtout).
var _semelle := ""
var _semelle_reste := 0
var _semelle_max := 1
const MAX_EMPREINTES := 12
var empreintes: Array = []
static var _tex_botte: ImageTexture

## Un pas du joueur (appelé tous les ~0,7 m par EffetsSol.empreinte_pas) : dans une flaque encore humide, la semelle se charge ;
## ensuite quelques empreintes de plus en plus pâles (le film mince d'abord : seuil d'effacement qui monte). Rien sans flaque.
static func pas(j: Node3D, vitesse: Vector2, gauche: bool) -> void:
	if not actif or not is_instance_valid(instance) or j == null:
		return
	var l := instance
	if l.flaques.is_empty() and l._semelle_reste <= 0:
		return
	var p := j.global_position
	for f0: Variant in l.flaques:
		if not is_instance_valid(f0):
			continue
		var f := f0 as Flaque
		var sec: Variant = f.get_instance_shader_parameter("seche")
		if f.touche(p, Vector3.UP) and (sec == null or float(sec) < 0.5) and _dedans(f, p):
			l._semelle = f.liquide
			l._semelle_max = 7 if est_sang(f.liquide) or float(sorte(f.liquide)["visc"]) > 2.5 else 3
			l._semelle_reste = l._semelle_max
			return      # dans la flaque elle-même : pas d'empreinte
	if l._semelle_reste <= 0:
		return
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.4, 1, [(j as CollisionObject3D).get_rid()] if j is CollisionObject3D else [])
	var r := j.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r["normal"] as Vector3).y < PLAT:
		return
	var d := Vector3(vitesse.x, 0, vitesse.y)
	d = d.normalized() if d.length() > 0.05 else -j.global_transform.basis.z
	var cote := d.cross(Vector3.UP).normalized() * (0.09 if gauche else -0.09)
	var force := float(l._semelle_reste) / l._semelle_max
	l._semelle_reste -= 1
	var mi := l._recycler(l.empreintes, MAX_EMPREINTES)
	mi.material_override = materiau(l._semelle, surface(r), 0, _botte())
	l._poser_plan(mi, l, (r["position"] as Vector3) + cote, r["normal"], d, 0.15, 0.075, null)      # x = sens de la marche (talon -> pointe)
	_vieillir(mi, l._semelle, surface(r))
	mi.set_instance_shader_parameter("efface", (1.0 - force) * 0.75)

static func _dedans(f: Flaque, p: Vector3) -> bool:
	var loc := f.global_transform.affine_inverse() * p
	var a := atan2(loc.z, loc.x)
	var k := int(round(a / TAU * Flaque.DIRS)) % Flaque.DIRS
	if k < 0:
		k += Flaque.DIRS
	return Vector2(loc.x, loc.z).length() < f.portee[k] * f.etendue * 0.85

## Masque d'une botte (R épaisseur, A couverture), le long de U (talon en 0, pointe en 1).
static func _botte() -> ImageTexture:
	if _tex_botte == null:
		var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in 16:
			for x in 32:
				var v := (x + 0.5) / 32.0 * 0.5 - 0.26
				var u := ((y + 0.5) / 16.0 - 0.5) * 0.24
				var f := EffetsSol._forme_botte(u, v, 1.0)
				if f > 0.0:
					var ep := clampf(f * 1.6 + sin(x * 1.7) * 0.12, 0.05, 1.0)
					# crampons : quelques rainures de la semelle restent sèches
					if (x % 5 == 2) and f > 0.25:
						ep *= 0.35
					img.set_pixel(x, y, Color(ep, 0, 0, 1))
		_tex_botte = ImageTexture.create_from_image(img)
	return _tex_botte

# ------------------------------------------------------------------ matériaux

static var _shaders := {}
static var _mats := {}
static var _bruit: ImageTexture

## Matériau partagé d'une sorte sur une surface. forme 0 : tache (masque peint, `masque`) ; 1 : flaque (bord procédural, étendue) ;
## 2 : filet de coulure. Translucides (eau, bière, vin, huile…) : teinte MULTIPLIÉE (le support assombri, teinté) ; opaques (sangs,
## lait, potions) : couleur, reflet mouillé. Neige : pas de reflet, liseré dilué.
static func materiau(nom_: String, surf: String, forme: int, masque: Texture2D = null, couleur := Color.BLACK) -> ShaderMaterial:
	var so := sorte(nom_)
	var cle := "%s|%s|%d|%d|%s" % [nom_, surf, forme, masque.get_rid().get_id() if masque != null else 0, couleur.to_html() if couleur != Color.BLACK else ""]
	if _mats.has(cle):
		return _mats[cle]
	var opaque := bool(so.get("opaque", false))
	var code_cle := "mix" if opaque else "mul"
	if not _shaders.has(code_cle):
		var sh := Shader.new()
		sh.code = ("" if opaque else "#define MUL\n") + CODE
		_shaders[code_cle] = sh
	var su: Dictionary = SURFACES.get(surf, SURFACES["pierre"])
	var bu := float(su["absorbe"]) * float(so["absorbe"])
	var m := ShaderMaterial.new()
	m.shader = _shaders[code_cle]
	m.set_shader_parameter("forme", forme)
	m.set_shader_parameter("masque", masque if masque != null else bruit())
	m.set_shader_parameter("bruit", bruit())
	var fr: Color = so["frais"] if couleur == Color.BLACK else couleur
	var se: Color = so["sec"]
	var neige := surf == "neige"
	if neige:
		# la neige boit : tache diffuse, plus foncée (opaques) ou teinte plus marquée (translucides), aucun reflet
		fr = fr.darkened(0.12) if opaque else fr.lerp(Color.WHITE, 0.25)
	elif bu > 0.2 and opaque:
		fr = fr.darkened(0.06 * bu)
	if not opaque and forme != 1:
		fr = fr.lerp(Color.WHITE, 0.4)      # tache / filet d'un liquide clair : film mince, le support mouillé reste lisible
	m.set_shader_parameter("frais", fr)
	m.set_shader_parameter("sec", se)
	m.set_shader_parameter("halo", so["halo"])
	m.set_shader_parameter("neige", 1.0 if neige else 0.0)
	m.set_shader_parameter("brille", float(so["brille"]) * float(su["brille"]) * (1.0 - bu * 0.6))
	m.set_shader_parameter("lueur", float(so.get("lueur", 0.0)))
	m.render_priority = -1
	if not opaque and not neige:
		# deuxième passe : reflet humide ADDITIF (albédo noir, seul le spéculaire des torches et des rais s'ajoute)
		if not _shaders.has("reflet"):
			var shr := Shader.new()
			shr.code = "#define REFLET\n" + CODE
			_shaders["reflet"] = shr
		var r := ShaderMaterial.new()
		r.shader = _shaders["reflet"]
		for k: String in ["forme", "masque", "bruit", "frais", "sec", "halo", "neige", "brille", "lueur"]:
			r.set_shader_parameter(k, m.get_shader_parameter(k))
		r.set_shader_parameter("brille", clampf(float(so["brille"]) * (0.5 + 0.5 * float(su["brille"])) * (1.0 - bu * 0.35), 0.0, 1.2))
		r.render_priority = 0
		m.next_pass = r
	_mats[cle] = m
	return m

## Bruit 32 x 32 (R) répété : bord des flaques, épaisseur, épaisseur des filets.
static func bruit() -> ImageTexture:
	if _bruit == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var b := FastNoiseLite.new()
		b.seed = 5150
		b.frequency = 0.11
		var b2 := FastNoiseLite.new()
		b2.seed = 77
		b2.frequency = 0.32
		for y in 32:
			for x in 32:
				# bruit périodique : 4D sur un tore pour que la texture se répète sans couture
				var ax := TAU * x / 32.0
				var ay := TAU * y / 32.0
				var v := b.get_noise_3d(cos(ax) * 5.0, sin(ax) * 5.0, cos(ay) * 5.0 + sin(ay) * 2.0) * 0.7 + b2.get_noise_2d(x, y) * 0.3
				var w := clampf(v * 0.5 + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(w, w, w, 1.0))
		_bruit = ImageTexture.create_from_image(img)
	return _bruit

const CODE := """shader_type spatial;
#ifdef REFLET
render_mode blend_add, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx, fog_disabled;
#elif defined(MUL)
render_mode blend_mul, unshaded, depth_draw_never, cull_disabled, fog_disabled;
#else
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;
#endif
uniform sampler2D masque : filter_nearest, repeat_enable;
uniform sampler2D bruit : filter_nearest, repeat_enable;
uniform int forme = 0;
uniform vec3 frais : source_color;
uniform vec3 sec : source_color;
uniform vec3 halo : source_color;
uniform float neige = 0.0;
uniform float brille = 0.7;
uniform float lueur = 0.0;
instance uniform float seche = 0.0;
instance uniform float efface = 0.0;
instance uniform float etendue = 1.0;
instance uniform float texels = 32.0;
instance uniform float allonge = 1.0;
#ifdef REFLET
varying float v_reflet;
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap, repeat_disable;
float n2_reflet(vec2 uv) {
	return texture(bruit, uv * 0.9 + vec2(0.31, 0.77)).r;
}
#endif
void fragment() {
	float ep;
	float garde;
	float lisere = 0.0;
	float n = 0.5;
	if (forme == 0) {
		vec4 m = texture(masque, UV);
		ep = m.r;
		lisere = step(0.5, m.g);
		garde = step(0.5, m.a) * (1.0 - lisere * (1.0 - neige));
		n = texture(bruit, UV * 1.3).r;
	} else if (forme == 1) {
		// flaque : bord procédural (bruit) qui avance avec l'étendue, par texels nets ; la maille coupe là où la surface s'arrête
		vec2 q = (floor(UV * texels) + 0.5) / texels;
		float d = length((q - 0.5) * 2.0);
		n = texture(bruit, q * 2.1).r;
		vec2 v = (q - 0.5) * 2.0;
		float ang = atan(v.y, v.x) / 6.2832;
		float lobes = texture(bruit, vec2(ang * 1.0, 0.21)).r * 0.6 + texture(bruit, vec2(ang * 3.0, 0.67)).r * 0.4;
		float n2 = texture(bruit, q * 0.7 + vec2(0.37, 0.61)).r;
		float bord = etendue * (0.5 + 0.42 * lobes + 0.1 * n2 + 0.05 * n);
		garde = step(d, bord);
		ep = clamp((bord - d) / max(bord * 0.5, 0.02) + (n - 0.5) * 0.3, 0.04, 1.0);
		lisere = neige * (1.0 - garde) * step(d, bord + 2.4 / texels);
		garde = max(garde, lisere);
	} else {
		// filet : U le long de l'écoulement (haut -> bas), V en travers ; s'épaissit en descendant, ondule un peu
		float lx = texels * allonge;
		vec2 q = vec2((floor(UV.x * lx) + 0.5) / lx, (floor(UV.y * texels) + 0.5) / texels);
		n = texture(bruit, vec2(q.x * allonge * 0.09, 0.3)).r;
		float ondule = (texture(bruit, vec2(q.x * allonge * 0.04, 0.8)).r - 0.5) * 0.3;
		float demi = 0.16 + 0.12 * n + 0.14 * q.x;
		float dv = abs(q.y - 0.5 - ondule);
		garde = step(dv, demi);
		ep = clamp((1.0 - dv / demi) * mix(0.45, 1.0, q.x) + 0.1, 0.08, 1.0);
	}
	garde *= step(efface * 1.02, ep + 0.001 - lisere * 0.35);
	if (garde < 0.5) {
		discard;
	}
	float s = step(ep * 0.85 + 0.1, seche);
	vec3 c = mix(frais, sec, s);
	float mouille = (1.0 - s) * (1.0 - lisere);
#ifdef REFLET
	// film d'eau : rien que le reflet des lumières (albédo noir en addition) ; surface lisse, petits éclats nets du bruit
	// rien que le reflet : albédo noir (addition), éclat des lumières calculé dans light() (lobe large : la torche se reflète
	// sur une bonne part de la flaque, pas en un point) ; plus le reflet de ce qui est derrière
	float b = clamp(brille, 0.0, 1.2) * mouille * mix(0.55, 1.0, ep);
	v_reflet = b * (forme == 1 ? 0.65 : 0.15);      // flaque : vrai miroir ; tache, filet : film mince, à peine un éclat
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	// reflet de ce qui est derrière la flaque : un sol mouillé renvoie l'image du mur, de la torche, d'un rai de lumière, plus haut à
	// l'écran ; lu dans l'écran décalé vers le haut (miroir plan approché), par blocs de 4 pixels et flou (stable, sans scintillement)
	vec3 V = normalize(VERTEX);
	float nv = clamp(dot(-V, NORMAL), 0.0, 1.0);
	float fres = 0.12 + 0.88 * pow(1.0 - nv, 3.0);
	vec2 px = 4.0 / VIEWPORT_SIZE;
	vec2 uh = SCREEN_UV - vec2(0.0, 0.1 + 0.55 * (1.0 - nv)) + (vec2(n, n2_reflet(UV)) - 0.5) * 0.01;
	uh = (floor(uh / px) + 0.5) * px;
	vec3 refl = vec3(0.0);
	if (uh.y > 0.0) {
		refl = textureLod(ecran, uh, 2.0).rgb * smoothstep(0.0, 0.08, uh.y);
	}
	EMISSION = refl * fres * b * mix(vec3(1.0), frais, 0.4) * (forme == 1 ? 1.3 : 0.2);
	EMISSION += vec3(step(0.9, n) * 0.035 * b);
#elif defined(MUL)
	// teinte multipliée : film mince plus léger ; quelques texels de reflet sur une surface dure (éclat de la flaque)
	// les couleurs (source_color) arrivent en linéaire : la teinte multipliée est reprise en gamma (sinon la bière noircit le sol)
	c = sqrt(c);
	c = mix(c, vec3(1.0), (1.0 - ep) * 0.15 + (forme == 1 ? 0.35 : 0.0));      // film mince plus léger ; flaque : le reflet fait le reste
	c = mix(c, halo, lisere);
	c *= 1.0 + step(0.8, n) * 0.9 * clamp(brille + 0.25, 0.0, 1.2) * mouille;
	ALBEDO = c;
#else
	c *= mix(1.15, 0.94, ep);
	c = mix(c, halo, lisere);
	ALBEDO = c;
	ROUGHNESS = mix(0.9, 0.12, mouille * clamp(brille, 0.0, 1.0));
	SPECULAR = mix(0.2, 0.8, mouille * clamp(brille, 0.0, 1.0));
	METALLIC = 0.0;
	EMISSION = c * lueur * (1.0 - s);
#endif
}
#ifdef REFLET
void light() {
	vec3 H = normalize(VIEW + LIGHT);
	float sp = pow(max(dot(NORMAL, H), 0.0), 18.0) + 0.35 * pow(max(dot(NORMAL, H), 0.0), 4.0);
	SPECULAR_LIGHT += sp * ATTENUATION * LIGHT_COLOR * v_reflet * 0.9;
}
#endif
"""
