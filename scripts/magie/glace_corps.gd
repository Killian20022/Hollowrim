class_name GlaceCorps
## Comportement « glace sur le corps » du socle ImpactCorps (docs/MAGIE_IMPACT_CORPS.md, agent B) — référence :
## references/magie/glace_fps_1100.jpg et Frostbite de Skyrim. Pas de bouffée ni de pics posés devant l'ennemi :
##   - le GIVRE SE DÉPOSE sur la silhouette depuis le point touché et GAGNE la surface (rayon qui grandit, bord irrégulier) :
##     la texture blanchit (voile), une croûte de cristaux à facettes pousse dessus (coque : sommets poussés le long de la
##     normale, elle suit les os), des scintillements y naissent, une buée froide en tombe et roule au sol ;
##   - impact de projectile (éclat de glace, lance de givre) : éclats et poudre qui partent TANGENTS à la surface autour du
##     point touché, plaque de givre à cet endroit, plus grande pour la lance ;
##   - gel « complet » (puissance du statut, nova gelée, coups répétés) : tout le corps est recouvert ; la nova gèle depuis
##     les pieds (aucun point d'impact : le froid monte du sol) ;
##   - après le statut : le givre FOND (la croûte se troue et rentre, le blanc s'efface, des gouttes tombent) en 2,5 s.

const GLACE := ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8"]
## Coque : croûte de givre à facettes (magie_corps_coque_ecoles, école 0).
const COQUE := 0

const REGLAGES := [
	# 0 scintillements sur la zone gelée (cristaux qui accrochent la lumière)
	{"mode": "givre", "add": true, "n": 30, "vie": 0.35, "vitesse": Vector2(0.0, 0.05), "gravite": Vector3(0, 0, 0), "amorti": Vector2(4.0, 6.0),
		"ouvert": 0.5, "ecarte": 0.03, "taille": Vector2(0.01, 0.018), "courbe": 2, "alea": 0.5, "chaud": 0.0,
		"rampe": ["#ffffff", "#e8f6ff", "#a8d8f8"], "cap": 3.0, "eclat": 2.0,
		"fin": {"n": 90, "taille": Vector2(0.004, 0.008)}},
	# 1 éclats TANGENTS à la surface (projectile) : partent en étoile le long du corps puis tombent
	{"mode": "eclabousse", "n": 60, "vie": 0.45, "vitesse": Vector2(2.2, 5.0), "gravite": Vector3(0, -9.0, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.25, "ecarte": 0.03, "taille": Vector2(0.025, 0.05), "courbe": 1, "alea": 0.3, "chaud": 0.0, "rampe": GLACE, "cap": 5.0, "eclat": 1.45,
		"fin": {"n": 140, "taille": Vector2(0.012, 0.026), "cap": 8.0, "etire": 3.0}},
	# 2 buée froide : glisse sur la zone gelée et retombe (l'air froid descend)
	{"mode": "givre", "n": 18, "vie": 1.1, "vitesse": Vector2(0.05, 0.25), "gravite": Vector3(0, -0.35, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.5, "ecarte": 0.05, "turb": 1.0, "taille": Vector2(0.09, 0.16), "courbe": 2, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#e8f6ff40", "#a8d8f838", "#5f9fe828", "#2f5fb818"], "cap": 12.0, "eclat": 1.0,
		"fin": {"n": 40, "taille": Vector2(0.06, 0.12), "cap": 16.0}},
	# 3 poudre de glace au point touché (additive, fine)
	{"mode": "eclabousse", "add": true, "n": 40, "vie": 0.5, "vitesse": Vector2(1.0, 3.5), "gravite": Vector3(0, -2.0, 0), "amorti": Vector2(2.0, 4.0),
		"ouvert": 0.5, "ecarte": 0.03, "taille": Vector2(0.01, 0.018), "courbe": 1, "alea": 0.4, "chaud": 0.0,
		"rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8"], "cap": 3.0, "eclat": 1.6,
		"fin": {"n": 50, "taille": Vector2(0.004, 0.008), "etire": 2.0}},
	# 4 brume froide qui roule au sol autour des pieds (corps très gelé)
	{"mode": "sol", "n": 14, "vie": 1.4, "vitesse": Vector2(0.05, 0.2), "gravite": Vector3(0, 0.0, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.8, "suit_jet": 0.0, "taille": Vector2(0.14, 0.24), "courbe": 2, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#e8f6ff30", "#a8d8f830", "#5f9fe820", "#2f5fb810"], "cap": 14.0, "eclat": 1.0,
		"fin": {"n": 30, "taille": Vector2(0.1, 0.18), "cap": 18.0}},
	# 5 gouttes de la fonte
	{"mode": "fonte", "n": 24, "vie": 0.6, "vitesse": Vector2(0.1, 0.4), "gravite": Vector3(0, -9.0, 0), "amorti": Vector2(0.2, 0.5),
		"ouvert": 0.15, "ecarte": 0.02, "taille": Vector2(0.01, 0.016), "courbe": 0, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#e8f6ffd0", "#a8d8f8c0", "#5f9fe8a0"], "cap": 3.0, "eclat": 1.3,
		"fin": {"n": 60, "taille": Vector2(0.004, 0.007), "etire": 3.0}},
]

const RETOMBEE := 0.12
const SALVE := 0.07             # s : éclats d'un projectile (salve)
const FONTE := 2.5              # s : le givre fond après le statut
const VITESSE_GIVRE := 1.6      # m/s : le front du givre gagne la surface
const RAYON_PLEIN := 2.2        # m : rayon qui couvre tout le corps

static func debut(_ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	f.d = {"jets": {}, "vu": -INF, "dir": Vector3.FORWARD, "imp": Vector3(0, 1.1, 0), "imp_i": -1, "k_jet": 0.0,
		"gel": 0.0, "rayon": 0.0, "rayon_cible": 0.0, "gel_fin": -INF, "salve_fin": -INF, "k_salve": 0.0, "t_imp": -INF,
		"fonte": 0.0, "vu_gel": -INF}

static func jet(ic: ImpactCorps, f: ImpactCorps.Foyer, info: Dictionary) -> void:
	var d := f.d
	(d.jets as Dictionary)[info.id] = {"o": info.o, "dir": info.dir, "dbl": info.dbl, "vu": ic.gm.horloge}
	d.vu = ic.gm.horloge

static func statut(ic: ImpactCorps, f: ImpactCorps.Foyer, _nom: String, duree: float) -> bool:
	var d := f.d
	var h := ic.gm.horloge
	if duree <= 0.0:
		d.gel_fin = h
		return true
	d.gel_fin = maxf(float(d.gel_fin), h + duree)
	# couverture : selon la puissance du gel (Statuts, lu seulement) et les coups répétés. Un coup : plaque autour du point
	# touché (éclat ~0,6 m, lance ~1 m) ; chaque nouveau coup pendant le gel l'agrandit ; sans impact (nova) : tout le corps
	var p := Statuts.puissance(f.cible, "gel") if is_instance_valid(f.cible) else 0.3
	var cible := lerpf(0.35, 0.75, clampf(p / 0.45, 0.0, 1.0))
	var sans_impact := h - float(d.t_imp) > 0.4
	if sans_impact:
		cible = RAYON_PLEIN * clampf(p / 0.55, 0.45, 1.0)
		if float(d.rayon) < 0.05 and f.surface != null:
			f.surface.actualiser(f.origine())
			# nova gelée, lame de givre… : le froid monte des pieds
			d.imp = Vector3(0.0, f.surface.bas if f.surface != null else 0.0, 0.0)
			d.imp_i = -1
	elif h - float(d.vu_gel) > 0.25 and h - float(d.vu_gel) < 4.0 and float(d.rayon_cible) > 0.0:
		# nouveau coup (pas les éclats d'une même salve) pendant le gel : la plaque s'agrandit
		cible = maxf(cible, float(d.rayon_cible) + 0.35)
	d.vu_gel = h
	d.rayon_cible = clampf(maxf(float(d.rayon_cible), cible), 0.0, RAYON_PLEIN)
	return true

static func embraser(ic: ImpactCorps, f: ImpactCorps.Foyer, point: Vector3, direction: Vector3, force: float, duree: float) -> void:
	var d := f.d
	var o := f.origine()
	f.surface.actualiser(o)
	d.dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var i := f.surface.point_vise(point - o - d.dir * 1.5, d.dir)
	if float(d.rayon) < 0.1 or ic.gm.horloge - float(d.t_imp) > 0.6:
		# nouvelle plaque de givre au point touché (le front repart de là)
		d.imp = f.surface.pos[i] if i >= 0 else point - o
		d.imp_i = i
		d.rayon = minf(float(d.rayon), 0.05)
	d.t_imp = ic.gm.horloge
	d.rayon_cible = clampf(maxf(float(d.rayon_cible), 0.2 + 0.25 * force), 0.0, RAYON_PLEIN)
	d.gel_fin = maxf(float(d.gel_fin), ic.gm.horloge + 0.8)   # le statut (s'il prend) prolonge
	d.salve_fin = ic.gm.horloge + SALVE * clampf(force, 0.6, 1.8)
	d.fonte = 0.0
	if duree > 0.0:
		statut(ic, f, "gel", duree)
	ic.gm.lumiere("corps%d" % f.id, o + d.imp - d.dir * 0.5 + Vector3.UP * 0.2, GestionMagie.LUMIERE.glace, 3.5 * clampf(force, 0.6, 1.5), 4.0, 5.0, 0.3)

static func maj(ic: ImpactCorps, f: ImpactCorps.Foyer, dt: float) -> bool:
	var d := f.d
	var h := ic.gm.horloge
	var s := f.surface
	var org := f.origine()
	if ic.surface_changee(f) and int(d.imp_i) >= 0:
		s.actualiser(org)
		d.imp_i = ImpactCorps.plus_proche(s, d.imp)
	var jets: Dictionary = d.jets
	var n_jets := 0
	var dir := Vector3.ZERO
	var o := Vector3.ZERO
	for k in jets.keys():
		var jj: Dictionary = jets[k]
		if h - float(jj.vu) > RETOMBEE:
			jets.erase(k)
			continue
		n_jets += 1
		dir += jj.dir
		o += jj.o
	var sous_jet := n_jets > 0
	if sous_jet:
		dir = dir.normalized()
		o /= n_jets
		d.dir = dir
		var i := ic.point_vise(f, o - org, dir)
		if i >= 0 and (float(d.rayon) < 0.1 or int(d.imp_i) < 0):
			d.imp_i = i
		d.k_jet = minf(float(d.k_jet) + dt / 0.1, 1.0)
		d.rayon_cible = minf(float(d.rayon_cible) + dt * 0.9, RAYON_PLEIN)
		d.gel_fin = maxf(float(d.gel_fin), h + 0.3)
	else:
		d.k_jet = maxf(float(d.k_jet) - dt / RETOMBEE, 0.0)
	# le point d'origine du givre suit son point de surface (le corps bouge, tombe)
	if int(d.imp_i) >= 0 and int(d.imp_i) < s.nb:
		d.imp = s.pos[d.imp_i]
	var gele := h < float(d.gel_fin)
	var salve := h < float(d.salve_fin)
	d.k_salve = 1.0 if salve else maxf(float(d.k_salve) - dt / 0.05, 0.0)
	# front du givre : il gagne la surface ; intensité : prend en 0,25 s, fond en FONTE s
	d.rayon = move_toward(float(d.rayon), float(d.rayon_cible), dt * VITESSE_GIVRE)
	if gele:
		d.gel = minf(float(d.gel) + dt / 0.25, 1.0)
		d.fonte = 0.0
	else:
		d.gel = maxf(float(d.gel) - dt / FONTE, 0.0)
		d.fonte = 1.0 if float(d.gel) > 0.02 else 0.0
		if float(d.gel) <= 0.0:
			d.rayon_cible = 0.0
			d.rayon = 0.0
	var gel := float(d.gel)
	var rayon := float(d.rayon)
	var ks := float(d.k_salve)
	# couverture vue par les émetteurs : force du givre × part couverte (plein corps : plus de buée au sol)
	var plein := clampf(rayon / RAYON_PLEIN, 0.0, 1.0)
	ic.uniformes(f, "dir_jet", d.dir)
	ic.uniformes(f, "point_impact", d.imp)
	ic.uniformes(f, "rayon_jet", maxf(rayon, 0.001))
	ic.uniformes(f, "k_jet", maxf(gel * (1.0 - float(d.fonte) * 0.5), ks))
	ic.uniformes(f, "k_foyers", float(d.fonte) * gel)
	ic.uniformes(f, "sol_y", minf(s.bas, 0.0) + 0.02)
	var parts := [gel * (0.5 + 0.5 * plein) * (1.0 - float(d.fonte) * 0.6), ks, gel * 0.8, ks, gel * smoothstep(0.45, 0.9, plein), float(d.fonte) * gel]
	if sous_jet:
		parts[1] = maxf(parts[1], 0.35)
		parts[3] = maxf(parts[3], 0.5)
	for k in f.em.size():
		ic.activer(f.em[k], parts[k])
	ic.ecoles(f, snappedf(gel, 0.02), 0.0, 0.0, 0.0, 0.0, org + d.imp, snappedf(rayon, 0.02))
	# coque : la croûte pousse d'abord du côté du tir (sauf gel complet)
	var vt := -(d.dir as Vector3)
	var mv := Vector4(snappedf(vt.x, 0.02), snappedf(vt.y, 0.02), snappedf(vt.z, 0.02), 0.0 if int(d.imp_i) < 0 else snappedf(1.0 - plein, 0.05))
	if f.d.get("_mv") != mv:
		f.d["_mv"] = mv
		for c: MeshInstance3D in f.coques:
			if c.visible:
				c.set_instance_shader_parameter("mc_vers", mv)
	return sous_jet or gele or salve or gel > 0.0 or ks > 0.0
