class_name RunesOrbite
extends Node3D
## Runes nordiques en orbite autour de la magie tenue en main (références Jeux/references/avant_bras_magie/bras_*_1100.jpg) :
## un fil d'orbite fin et lumineux, des runes posées dessus qui tournent lentement dans un sens, et une seconde orbite plus
## serrée, inclinée autrement, dont les runes tournent dans l'autre sens. Variations de taille, de hauteur et d'éclat par
## rune. Le cercle suit la paume (mouvements des mains) mais reste tourné vers l'œil : les runes restent lisibles.
## MainSort (main_sort.gd) le crée quand un sort est tenu ; `intensite` suit l'aura, `charge` (0..1) resserre les orbites
## et accélère (état de charge, à brancher à l'étape suivante). Shader : shaders/runes_orbite.gdshader (additif, WebGL2).

const SH := preload("res://shaders/runes_orbite.gdshader")
## Par école : couleurs, signes (shader), rayon moyen des orbites (m), taille d'une rune (m), hauteur du centre des
## orbites au-dessus de la paume (m : le milieu de la flamme / du cristal tenu).
const ECOLES := {
	"feu": {"couleur": Color("#ff6a1a"), "coeur": Color("#ffc27a"), "signes": [6, 7, 8, 9, 1, 10, 6, 7], "rayon": 0.115, "taille": 0.026, "centre": 0.15},
	"glace": {"lueur_k": 2.0, "couleur": Color("#4fb4ff"), "coeur": Color("#e2f6ff"), "signes": [5, 3, 10, 0, 5, 3, 9, 8], "rayon": 0.115, "taille": 0.029, "centre": 0.15},
	"electricite": {"lueur_k": 1.7, "couleur": Color("#8a6cff"), "coeur": Color("#e6deff"), "signes": [2, 4, 2, 9, 2, 4, 8, 10], "rayon": 0.115, "taille": 0.029, "centre": 0.15},
	"tenebres": {"lueur_k": 1.8, "couleur": Color("#a23cff"), "coeur": Color("#e7b8ff"), "signes": [4, 1, 5, 7, 4, 1, 5, 6], "rayon": 0.115, "taille": 0.029, "centre": 0.15},
}
## Deux anneaux très fins, PARTIELS (un arc qui tourne, ni cercle complet ni grand cercle devant la caméra) : rayon (m),
## inclinaison (rad), fraction du tour visible, vitesse de rotation propre (rad/s), épaisseur du trait.
const ANNEAUX := [
	{"rayon": 0.115, "incl": Vector3(-0.95, 0.25, 0.15), "arc": 0.55, "vit": 0.34},
	{"rayon": 0.082, "incl": Vector3(0.7, -0.5, -0.7), "arc": 0.4, "vit": -0.5},
]
## États : cibles (rayon des orbites, vitesse, éclat) vers lesquelles les runes glissent sans à-coup.
## REPOS : lentes ; INCANTE : elles s'emballent un peu ; CHARGE : se resserrent et brillent (cf. `charge` 0..1) ;
## CANALISE : serrées et vives ; RECUPERATION : retour doux (elles regagnent leurs orbites).
const ETAT := {
	0: {"rayon": 1.0, "vit": 1.0, "eclat": 1.0},
	1: {"rayon": 0.96, "vit": 1.9, "eclat": 1.3},
	2: {"rayon": 0.9, "vit": 2.2, "eclat": 1.35},
	3: {"rayon": 0.8, "vit": 2.4, "eclat": 1.45},
	4: {"rayon": 1.0, "vit": 1.3, "eclat": 1.1},
}
const LARGEUR_FIL := 0.0016
const NB_RUNES := 7
## TRANSITION AU LANCER (TransitionSort, docs/MAGIE_TRANSITIONS.md) : par école, comment les runes de la main se transforment en sort.
## Une école absente de ce tableau garde l'orbite au repos pendant le lancer (comportement d'avant) ; pour brancher une école :
## ajouter une entrée (les valeurs de "feu" servent de modèle) et lire `transition` ailleurs si besoin.
##   jet      : sort canalisé → les runes quittent l'orbite, glissent en HÉLICE le long du jet et s'estompent au bout ; `anneaux`
##              cercles runiques perpendiculaires au jet avancent à son rythme (rayon qui s'évase comme le cône du jet)
##   depart   : sort lancé → les runes filent le long du tir en traînée, puis reviennent orbiter en grossissant
##   longueur : plage de la longueur de l'hélice (m) ; cone : évasement (rayon = r0 + cone × distance) ; vitesse : tours de l'hélice / s
const MODE_JET := {
	"feu": {"jet": true, "depart": true, "anneaux": 6, "r0": 0.06, "cone": 0.1, "rmax": 0.5, "longueur": Vector2(1.5, 3.6), "vitesse": 0.5, "torsion": 4.5, "spin": 2.2},
}
const LARGEUR_ANNEAU_JET := 0.03

var ecole := "feu"
## Outil de capture (outils/captures_sorts_vfx.gd, film_ecoles_runiques.gd) : >= 0 impose l'état CHARGE à cette charge (0..1),
## sans lancer de sort. Les sorts canalisés (arc électrique) tirent dès qu'on les tient : jamais de vraie « charge ».
static var forcer_charge := -1.0
var suivi: Node3D
## +1 main gauche, -1 main droite (sens et inclinaison en miroir : gauche ≠ droite).
var cote := 1.0
var intensite := 0.35
var charge := 0.0
## État d'incantation de la main (Incantation.REPOS..RECUPERATION) : MainSort le recopie à chaque image.
var etat := 0
## Réglages (composant réutilisable) : nombre de runes (≤ 8), vitesse, taille, luminosité.
var nombre := NB_RUNES
var vitesse_k := 1.0
var taille_k := 1.0
var lumi_k := 1.0
## Réutilisation hors main (projectile lancé, pont de la double magie) : échelle des orbites et des runes, hauteur du centre
## (-1 = celle de l'école), sans les lueurs d'avant-bras, apparition progressive (orbites qui s'ouvrent en `germe` s).
## Double magie (les deux mains lancent ce sort) : posé par MainSort.
var double := false
var echelle := 1.0
var centre_force := -1.0
var avec_lueurs := true
var germe := 0.0
## Transition de la main (TransitionSort) posée par MainSort ; null = pas de transition (projectile, pont de la double magie).
var transition: TransitionSort
var _runes: Array = []          # [{mi, base, vit, rayon, phase, taille, eclat, bat, haut}]
var _fils: Array[MeshInstance3D] = []
var _extras: Array = []                    # runes supplémentaires du jet [{mi, taille, eclat, bat}]
var _anneaux: Array[MeshInstance3D] = []   # cercles runiques du jet (MODE_JET, école à jet)
var _w_jet := 0.0                          # fondu de la transformation en jet (lissé)
var _etat_prec := 0
var _k_rayon := 1.0             # valeurs lissées vers la cible de l'état
var _k_vit := 1.0
var _k_eclat := 1.0
var _conv := 0.0                # convergence brève des runes au départ du sort (1 → 0)
var _mat_rune: ShaderMaterial
var _mat_fil: ShaderMaterial
var _t := 0.0
## Lueur courte de l'énergie tenue : n'éclaire QUE les avant-bras (AvantBras.CALQUE), creux de la paume et intérieur des
## doigts orangés, brassard dans la pénombre (références) ; l'aura du sort éclaire le monde, pas les bras.
var lueur: OmniLight3D
const LUEUR := 1.7              # énergie au repos (atténuation 1/d)
## La lueur est avancée vers l'œil (m) : le dos de la main et les jointures, tournés vers la caméra, prennent le reflet
## orangé de l'énergie comme sur les références, au lieu d'une silhouette noire.
const LUEUR_AVANCE := 0.025
## Reflet plus faible et plus large posé sous la main, côté poignet : les arêtes des rouleaux, des plaques et des clous du
## brassard prennent l'orange de l'énergie (références : bras sombres mais lisibles), sans brûler le gant.
var lueur_bras: OmniLight3D
## Noyau 3D propre à l'école (glace, électricité, ténèbres ; la flamme du feu est dessinée par l'aura) : NoyauEcole.
var noyau: NoyauEcole
const LUEUR_BRAS := 0.45
const LUEUR_BRAS_POS := Vector3(-0.14, -0.02, 0.3)   # main gauche (x en miroir pour la droite), repère caméra

func _ready() -> void:
	top_level = true
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	_mat_rune = ShaderMaterial.new()
	_mat_rune.shader = SH
	_mat_rune.set_shader_parameter("couleur", e.couleur)
	_mat_rune.set_shader_parameter("coeur", e.coeur)
	_mat_fil = _mat_rune.duplicate()
	_mat_fil.set_shader_parameter("ligne", true)
	var mj: Dictionary = MODE_JET.get(ecole, {})
	if mj.get("jet", false) and avec_lueurs:
		var mesh_a := _ruban(1.0, LARGEUR_ANNEAU_JET)
		for h in int(mj.anneaux):
			var an := MeshInstance3D.new()
			an.mesh = mesh_a
			an.material_override = _mat_fil
			an.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			an.extra_cull_margin = 4.0
			an.set_instance_shader_parameter("arc", 0.78)
			an.visible = false
			add_child(an)
			_anneaux.append(an)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var signes: Array = e.signes
	for o in ANNEAUX.size():
		var fil := MeshInstance3D.new()
		fil.mesh = _ruban(float(ANNEAUX[o].rayon))
		fil.material_override = _mat_fil
		fil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fil.extra_cull_margin = 1.0
		fil.set_instance_shader_parameter("arc", float(ANNEAUX[o].arc))
		add_child(fil)
		_fils.append(fil)
	for k in mini(nombre, 8):
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _mat_rune
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		mi.set_instance_shader_parameter("symbole", float(signes[k % signes.size()]))
		add_child(mi)
		var h := _h(k * 7 + (0 if cote > 0.0 else 3))
		# orbite propre : plan incliné au hasard (mais stable), rayon et hauteur variés, sens alterné (horaire / antihoraire)
		var incl := Vector3(lerpf(-1.1, 1.1, _h(k * 17 + 5)), lerpf(-0.8, 0.8, _h(k * 19 + 8)), lerpf(-1.5, 1.5, _h(k * 23 + 2)))
		_runes.append({"mi": mi, "base": Basis.from_euler(incl),
			"vit": (0.42 + 0.5 * _h(k * 29 + 6)) * (1.0 if k % 2 == 0 else -1.0) * cote,
			"rayon": float(e.rayon) * (0.72 + 0.62 * _h(k * 31 + 3)), "phase": TAU * h,
			"taille": float(e.taille) * (0.85 + 0.3 * _h(k * 13 + 1)), "haut": 0.03 * (_h(k * 5 + 2) - 0.5),
			"eclat": 0.75 + 0.45 * _h(k * 11 + 4), "bat": TAU * _h(k * 3 + 9)})
	if mj.get("jet", false) and avec_lueurs:
		for x in mini(nombre, 8):
			var mx := MeshInstance3D.new()
			mx.mesh = quad
			mx.material_override = _mat_rune
			mx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mx.extra_cull_margin = 4.0
			mx.set_instance_shader_parameter("symbole", float(signes[(x + 3) % signes.size()]))
			mx.visible = false
			add_child(mx)
			_extras.append({"mi": mx, "taille": float(e.taille) * (0.9 + 0.3 * _h(x * 13 + 5)), "eclat": 0.85 + 0.35 * _h(x * 11 + 2), "bat": TAU * _h(x * 3 + 1)})
	if not avec_lueurs:
		_suivre()
		return
	lueur = OmniLight3D.new()
	lueur.light_color = (e.couleur as Color).lerp(e.coeur, 0.35)
	lueur.light_cull_mask = AvantBras.CALQUE
	lueur.shadow_enabled = false
	lueur.light_specular = 0.25
	lueur.omni_range = 0.32
	lueur.light_energy = LUEUR
	add_child(lueur)
	lueur_bras = OmniLight3D.new()
	lueur_bras.light_color = (e.couleur as Color).lerp(Color(0.8, 0.7, 0.62), 0.5)
	lueur_bras.light_cull_mask = AvantBras.CALQUE
	lueur_bras.shadow_enabled = false
	lueur_bras.light_specular = 0.12
	lueur_bras.omni_range = 0.5
	lueur_bras.omni_attenuation = 1.6
	lueur_bras.light_energy = LUEUR_BRAS
	add_child(lueur_bras)
	if NoyauEcole.possede(ecole):
		noyau = NoyauEcole.new()
		noyau.ecole = ecole
		noyau.runes = self
		noyau.taille_k = taille_k
		noyau.lumi_k = lumi_k
		noyau.vitesse_k = vitesse_k
		add_child(noyau)
	_suivre()

func _h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Ruban circulaire (rayon r, largeur LARGEUR_FIL) dans le plan XY ; UV.x = fraction du tour, UV.y = travers.
func _ruban(r: float, largeur := LARGEUR_FIL) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 96
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		var w := largeur * 0.5
		var p := [d0 * (r - w), d1 * (r - w), d1 * (r + w), d0 * (r + w)]
		var uv := [Vector2(float(i) / n, 0.0), Vector2(float(i + 1) / n, 0.0), Vector2(float(i + 1) / n, 1.0), Vector2(float(i) / n, 1.0)]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[t])
			st.add_vertex(p[t])
	return st.commit()

func _suivre() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if suivi == null or not is_instance_valid(suivi) or not suivi.is_inside_tree():
		return
	var b := cam.global_basis if cam != null else Basis.IDENTITY
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	# centre des orbites : le milieu de l'énergie tenue, AU-DESSUS de la paume (haut du monde, main penchée ou non)
	# double magie : toute la main (noyau, runes, lueur) glisse vers le point de fusion (TransitionSort.decalage)
	var dec := transition.decalage if transition != null else Vector3.ZERO
	global_transform = Transform3D(b, suivi.global_position + dec + Vector3.UP * (float(e.centre) if centre_force < 0.0 else centre_force))

## Point `i` sur `n` de l'hélice du jet (repère local) : [position, enveloppe 0..1 (fondu à la source et au bout), facteur de taille].
## Les points avancent le long du jet (vitesse), tournent autour de l'axe, et le rayon suit le cône du jet.
func _helice(i: int, n: int, h: Dictionary, dec: float) -> Array:
	var f := fposmod(float(i) / float(n) + dec + _t * float(h.vit), 1.0)
	var ang: float = TransitionSort.anneau_phase(i, n, cote) if h.commun else (float(i) * TAU * 0.382 + (0.0 if cote > 0.0 else 2.1))
	ang += (_t * float(h.spin) + f * float(h.tors)) * cote
	var ray := minf(float(h.r0) + float(h.cone) * f * float(h.lg), float(h.rmax)) * (0.85 + 0.3 * _h(i * 3 + 7)) * 1.2
	var pos: Vector3 = (h.d as Vector3) * (f * float(h.lg)) + ((h.u as Vector3) * cos(ang) + (h.v as Vector3) * sin(ang)) * ray
	var env := TransitionSort.lisse(f / 0.1) * (1.0 - TransitionSort.lisse((f - 0.55) / 0.45))
	return [pos, env, (3.2 + 3.0 * f) * (1.0 + 0.2 * (float(h.pu) - 1.0))]

func _process(dt: float) -> void:
	_t += dt
	if forcer_charge >= 0.0:
		etat = 2
		charge = forcer_charge
	_suivre()
	var e: Dictionary = ECOLES.get(ecole, ECOLES["feu"])
	var tr := transition
	var mj: Dictionary = MODE_JET.get(ecole, {}) if tr != null else {}
	# cible de l'état, lissée : jamais de saut (charge : resserre et accélère selon `charge`)
	var cib: Dictionary = ETAT.get(etat, ETAT[0])
	var kc := charge if etat == 2 else 0.0
	var v_rayon := float(cib.rayon) * (1.0 - 0.15 * kc)
	var v_vit := float(cib.vit) * (1.0 + 1.6 * kc)
	var v_eclat := float(cib.eclat) * (1.0 + 0.4 * kc)
	var lis := 1.0 - exp(-dt * 5.0)
	_k_rayon = lerpf(_k_rayon, v_rayon, lis)
	_k_vit = lerpf(_k_vit, v_vit, lis)
	_k_eclat = lerpf(_k_eclat, v_eclat, lis)
	# départ du sort : les runes convergent brièvement vers le centre puis regagnent leurs orbites
	# (école à transition : pas après un jet, les runes reviennent de l'hélice en douceur au lieu de se pincer)
	if etat == 4 and _etat_prec in ([1, 2] if not mj.is_empty() else [1, 2, 3]):
		_conv = 1.0
	_etat_prec = etat
	_conv = maxf(_conv - dt * 3.2, 0.0)
	var conv := sin(minf(_conv, 1.0) * PI * 0.5)
	var ouvre := 1.0 if germe <= 0.0 else clampf(0.35 + 0.65 * _t / germe, 0.35, 1.0)
	var resserre := _k_rayon * (1.0 - 0.55 * conv) * echelle * ouvre
	var acc := _k_vit * vitesse_k
	var force := clampf(0.7 + 0.6 * intensite, 0.0, 1.8) * _k_eclat * lumi_k * (1.0 + 0.4 * conv)
	var vif := _k_eclat * (1.0 + 0.4 * kc) * float(e.get("lueur_k", 1.0))
	# transformation en jet / départ (TransitionSort) : repère local = repère de la caméra
	var w := 0.0
	var dp := 1.0
	var dirl := Vector3.FORWARD
	var pu := 1.0
	var commun := false
	if tr != null and not mj.is_empty():
		w = TransitionSort.lisse(tr.canal) if mj.get("jet", false) else 0.0
		dp = tr.depart_p if mj.get("depart", false) and tr.forme == "lance" else 1.0
		dirl = (global_basis.inverse() * tr.direction).normalized()
		pu = tr.puissance
		commun = tr.anneau_commun
		force *= 1.0 + 0.25 * (pu - 1.0) * w
	_w_jet = w
	if lueur != null:
		lueur.position = Vector3(0.025 * cote, 0.0, LUEUR_AVANCE)
		lueur_bras.position = Vector3(LUEUR_BRAS_POS.x * cote, LUEUR_BRAS_POS.y, LUEUR_BRAS_POS.z)
		lueur_bras.light_energy = LUEUR_BRAS * (0.5 + 0.8 * intensite) * vif
		lueur.light_energy = LUEUR * (0.5 + 0.8 * intensite) * vif * (0.94 + 0.06 * sin(_t * 17.0) * sin(_t * 6.3)) * (1.0 + 0.5 * w * pu)
	var fondu_fils := 1.0 - w
	for o in _fils.size():
		var f := _fils[o]
		var an: Dictionary = ANNEAUX[o]
		var ie: Vector3 = an.incl
		var bs := Basis.from_euler(Vector3(ie.x, ie.y * cote, ie.z * cote)) * Basis(Vector3.BACK, _t * float(an.vit) * acc * cote)
		f.basis = bs.scaled(Vector3.ONE * resserre)
		f.set_instance_shader_parameter("defile", _t * 0.02 * signf(float(an.vit)) * cote)
		f.set_instance_shader_parameter("eclat", force * 0.8 * (0.85 + 0.15 * sin(_t * 2.3 + o)) * fondu_fils)
		f.visible = fondu_fils > 0.02
	# hélice du jet : longueur, profil du cône
	var lg := 2.0
	var r0 := 0.05
	var cone := 0.12
	var rmax := 0.4
	var spin := 2.2
	var tors := 4.5
	var vit_h := 0.5
	if w > 0.0 or dp < 1.0:
		var plage: Vector2 = mj.longueur
		# l'hélice s'allonge avec le jet (la flamme avance, les runes l'accompagnent au lieu de la devancer)
		lg = clampf(tr.longueur, plage.x, plage.y) * (0.8 + 0.2 * pu) * (0.12 + 0.88 * TransitionSort.lisse(tr.t_canal / 0.4))
		r0 = float(mj.r0) * echelle
		cone = float(mj.cone) * (1.0 + 0.2 * (pu - 1.0))
		rmax = float(mj.rmax) * pu
		spin = float(mj.spin)
		tors = float(mj.torsion)
		vit_h = float(mj.vitesse)
	var ax_u := dirl.cross(Vector3.UP)
	if ax_u.length() < 0.1:
		ax_u = dirl.cross(Vector3.RIGHT)
	ax_u = ax_u.normalized()
	var ax_v := dirl.cross(ax_u).normalized()
	var nb := _runes.size()
	var hel := {"u": ax_u, "v": ax_v, "d": dirl, "lg": lg, "r0": r0, "cone": cone, "rmax": rmax, "spin": spin, "tors": tors,
		"vit": vit_h * (1.0 + 0.2 * (pu - 1.0)), "pu": pu, "w": w, "commun": commun}
	for k in nb:
		var r: Dictionary = _runes[k]
		var a: float = float(r.phase) + _t * float(r.vit) * acc
		var rr: float = float(r.rayon) * resserre
		var p: Vector3 = (r.base as Basis) * Vector3(cos(a) * rr, sin(a) * rr, 0.0)
		p.y = p.y * 0.6 + float(r.haut) + 0.003 * sin(_t * 1.7 + float(r.bat))
		var mi: MeshInstance3D = r.mi
		# profondeur : les runes devant (vers l'œil, +Z caméra) sont plus grandes et plus vives, celles du fond plus petites et pâles
		var dev := clampf(p.z / maxf(rr, 0.01), -1.0, 1.0)
		var s: float = float(r.taille) * taille_k * echelle * (0.9 + 0.2 * dev) * (1.0 + 0.06 * sin(_t * 2.9 + float(r.bat)))
		var vis := 1.0
		if dp < 1.0:
			# lancer : les runes se détachent de l'orbite, filent le long du tir en traînée (hauteur propre à chacune), puis
			# reviennent orbiter en grossissant depuis le centre
			var hh := _h(k * 5 + 1 + (0 if cote > 0.0 else 40))
			var rad := lerpf(1.0, 0.4, TransitionSort.lisse(dp / 0.4)) if dp < 0.5 else lerpf(0.4, 1.0, TransitionSort.lisse((dp - 0.5) / 0.5))
			var depl := TransitionSort.lisse(dp / 0.35) * (1.0 - TransitionSort.lisse((dp - 0.4) / 0.1))
			p = p * rad + dirl * (1.7 * depl * (0.3 + 0.7 * hh))
			vis = minf(1.0 - TransitionSort.lisse((dp - 0.1) / 0.3) + TransitionSort.lisse((dp - 0.5) / 0.4), 1.0)
			s *= lerpf(1.0, 0.6 + 0.6 * hh, depl)
		if w > 0.001:
			# jet : la rune glisse de l'orbite à un point de l'hélice, qui avance le long du jet puis s'estompe
			var hl := _helice(2 * k, 2 * nb, hel, (0.5 / float(2 * nb)) if (commun and cote < 0.0) else 0.0)
			p = p.lerp(hl[0], w)
			vis *= lerpf(1.0, float(hl[1]), w)
			s *= lerpf(1.0, float(hl[2]), w)
		mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p)
		var pulse := 0.8 + 0.2 * sin(_t * 3.3 + float(r.bat) * 2.0)
		mi.set_instance_shader_parameter("eclat", float(r.eclat) * pulse * force * (0.7 + 0.3 * dev) * vis * lerpf(1.0, 1.6, w))
		mi.visible = vis > 0.01
	# runes supplémentaires du jet (nées à la source, invisibles hors jet) : elles garnissent l'hélice entre les runes de l'orbite
	for e_i in _extras.size():
		var ex: Dictionary = _extras[e_i]
		var mx: MeshInstance3D = ex.mi
		mx.visible = w > 0.01
		if w <= 0.01:
			continue
		var hl := _helice(2 * e_i + 1, 2 * nb, hel, (0.5 / float(2 * nb)) if (commun and cote < 0.0) else 0.0)
		var sx: float = float(ex.taille) * taille_k * echelle * float(hl[2]) * w
		mx.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sx), (hl[0] as Vector3) * w)
		var pulx := 0.8 + 0.2 * sin(_t * 3.3 + float(ex.bat) * 2.0)
		mx.set_instance_shader_parameter("eclat", float(ex.eclat) * pulx * force * float(hl[1]) * w * 1.6)
	# cercles runiques du jet : perpendiculaires à l'axe, avancent au rythme du jet, s'évasent avec lui et s'estompent au bout
	var porte_anneaux := w > 0.01 and not (tr != null and tr.double and not tr.meneuse and commun)
	for h in _anneaux.size():
		var an := _anneaux[h]
		an.visible = porte_anneaux
		if not porte_anneaux:
			continue
		var f := fposmod(float(h) / float(_anneaux.size()) + _t * vit_h * 1.1, 1.0)
		var ray := lerpf(0.115 * resserre, minf(r0 * 1.4 + cone * f * lg * 1.25, rmax * 1.25), w)
		var bas := Basis(Quaternion(Vector3.BACK, dirl)) * Basis(Vector3.BACK, _t * 1.6 * cote + float(h) * 1.3)
		an.transform = Transform3D(bas.scaled(Vector3.ONE * ray), dirl * (f * lg * w))
		var env := TransitionSort.lisse(f / 0.12) * (1.0 - TransitionSort.lisse((f - 0.45) / 0.55))
		an.set_instance_shader_parameter("defile", _t * 0.1 * cote)
		an.set_instance_shader_parameter("eclat", force * 2.2 * w * env * (0.9 + 0.1 * sin(_t * 5.0 + h)))
