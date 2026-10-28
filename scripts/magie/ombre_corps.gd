class_name OmbreCorps
## Comportement « ténèbres sur le corps » du socle ImpactCorps (docs/MAGIE_IMPACT_CORPS.md, agent B) — référence :
## references/magie/tenebres_fps_1100.jpg. Pas de tache noire posée devant l'ennemi :
##   - DRAIN DE VIE : des FILAMENTS sombres sont ARRACHÉS à plusieurs points de la surface (côté lanceur surtout : torse,
##     bras, tête) et s'enroulent en spirale jusqu'à la main (arcs du socle, genre « main ») ; des fragments sombres et des
##     lueurs violettes se détachent du corps et sont ASPIRÉS vers la paume (mode « aspire ») ; des volutes de la coque sont
##     entraînées vers la main ; contour violet, veines sombres ; la victime PÂLIT ;
##   - TRAIT D'OMBRE : éclaboussure sombre qui s'étale sur la surface autour du point touché, contour violet qui pulse ;
##   - CORRUPTION (statut) : volutes sombres qui montent lentement du corps, lueurs violettes, contour qui palpite ;
##   - après : les ténèbres se DISSIPENT (volutes qui s'élèvent et s'effilochent, pâleur qui revient) en ~1,5 s.

const TEN := ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"]
## Coque : volutes aspirées vers la main / qui montent (magie_corps_coque_ecoles, école 1).
const COQUE := 1
## Filaments du drain : halo sombre (mélange) bordé d'un cœur violet clair.
## (2026-10-28) filaments plus épais (halo 6 → 8,5 px, cœur 2,5 → 3,5 px), cf. tenebres_fps_1100.jpg
const ARCS := {"halo": "#2a0a48", "coeur": "#a050e8", "halo_px": 8.5, "coeur_px": 3.5, "eclat": 1.2, "sombre": true, "ampl": 0.1}

const REGLAGES := [
	# 0 fragments sombres arrachés à la surface et aspirés vers la main (carrés nets, pas de fumée floue)
	{"mode": "aspire", "n": 70, "vie": 0.9, "vitesse": Vector2(0.4, 1.2), "gravite": Vector3(0, 0, 0), "amorti": Vector2(0.4, 0.8),
		"ouvert": 0.35, "ecarte": 0.03, "taille": Vector2(0.03, 0.06), "courbe": 1, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"], "cap": 6.0, "eclat": 1.0,
		"fin": {"n": 200, "taille": Vector2(0.012, 0.028), "cap": 9.0}},
	# 1 lueurs violettes aspirées (additives, fines)
	{"mode": "aspire", "add": true, "n": 40, "vie": 0.8, "vitesse": Vector2(0.3, 1.0), "gravite": Vector3(0, 0, 0), "amorti": Vector2(0.4, 0.8),
		"ouvert": 0.4, "ecarte": 0.04, "taille": Vector2(0.01, 0.018), "courbe": 2, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#f0d0ff", "#d08aff", "#9a3ae0", "#5a1a8a"], "cap": 3.0, "eclat": 1.8,
		"fin": {"n": 120, "taille": Vector2(0.004, 0.008), "etire": 3.0}},
	# 2 éclaboussure sombre tangente (trait d'ombre)
	{"mode": "eclabousse", "n": 60, "vie": 0.35, "vitesse": Vector2(1.5, 3.5), "gravite": Vector3(0, -1.0, 0), "amorti": Vector2(3.0, 5.0),
		"ouvert": 0.25, "ecarte": 0.03, "taille": Vector2(0.03, 0.06), "courbe": 1, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"], "cap": 6.0, "eclat": 1.2,
		"fin": {"n": 160, "taille": Vector2(0.012, 0.026), "cap": 9.0, "etire": 2.0}},
	# 3 motes violettes qui quittent les bords (corruption)
	{"mode": "escarbilles", "add": true, "n": 24, "vie": 0.9, "vitesse": Vector2(0.2, 0.6), "gravite": Vector3(0, 0.5, 0), "amorti": Vector2(0.8, 1.5),
		"ouvert": 0.5, "turb": 2.0, "suit_jet": 0.0, "taille": Vector2(0.01, 0.018), "courbe": 2, "alea": 0.4, "chaud": 0.0,
		"rampe": ["#d08aff", "#9a3ae0", "#5a1a8a"], "cap": 3.0, "eclat": 1.7,
		"fin": {"n": 70, "taille": Vector2(0.004, 0.008)}},
	# 4 volutes sombres qui montent des foyers de corruption et se dissipent
	{"mode": "fumee", "n": 18, "vie": 1.3, "vitesse": Vector2(0.2, 0.5), "gravite": Vector3(0, 0.6, 0), "amorti": Vector2(0.8, 1.4),
		"ouvert": 0.35, "turb": 2.0, "taille": Vector2(0.08, 0.15), "courbe": 2, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#2a0e3ea0", "#1a0a2890", "#0c061470", "#0c061430"], "cap": 10.0, "eclat": 1.0,
		"fin": {"n": 44, "taille": Vector2(0.05, 0.1), "cap": 14.0}},
	# 5 ombre violette au sol, aux pieds de la victime
	{"mode": "sol", "add": true, "n": 20, "vie": 0.7, "vitesse": Vector2(0.05, 0.3), "gravite": Vector3(0, 0.4, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.6, "suit_jet": 0.0, "taille": Vector2(0.03, 0.06), "courbe": 2, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#9a3ae0", "#5a1a8a", "#2a0e3e"], "cap": 6.0, "eclat": 1.3,
		"fin": {"n": 50, "taille": Vector2(0.012, 0.024)}},
]

const SOUS_JET := [1.0, 1.0, 0.0, 0.3, 0.2, 1.0]
const CORRUPTION := [0.15, 0.2, 0.0, 1.0, 1.0, 0.0]
const RETOMBEE := 0.12
const SALVE := 0.08
const DISSIPE := 1.5            # s : les ténèbres se dissipent après le statut
const FILAMENTS := 5            # couche fine (4 en rétro)

static func debut(_ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	f.d = {"jets": {}, "vu": -INF, "dir": Vector3.FORWARD, "imp_i": -1, "k_jet": 0.0, "main": Vector3.ZERO,
		"corr_fin": -INF, "k_corr": 0.0, "salve_fin": -INF, "k_salve": 0.0, "paleur": 0.0, "dissipe": 0.0,
		"sources": PackedInt32Array(), "t_source": -INF, "k_source": 0, "foyers": PackedInt32Array(), "graine": randf() * 100.0,
		"t_forme": -INF}

static func jet(ic: ImpactCorps, f: ImpactCorps.Foyer, info: Dictionary) -> void:
	var d := f.d
	(d.jets as Dictionary)[info.id] = {"o": info.o, "dir": info.dir, "dbl": info.dbl, "vu": ic.gm.horloge}
	d.vu = ic.gm.horloge
	var j: Variant = info.get("j")
	if j is Dictionary:
		# le drain finit SUR la surface ; ses brins d'origine (spirale posée sur l'axe) cèdent la place aux filaments
		var s := f.surface
		var o := f.origine()
		s.actualiser(o, false)   # (perf) normales : celles de l'image d'avant, ImpactCorps les refait
		var i: int = d.imp_i
		if i >= 0 and i < s.nb:
			j.fin_pos = o + s.pos[i] + s.nor[i] * 0.05
		var e: Variant = j.get("eclair")
		if e is Dictionary and not (e as Dictionary).is_empty():
			if not j.has("_gen0"):
				j["_gen0"] = e.gen
				j["_gen_corps"] = _gen_drain.bind(ic, j)
			e.gen = j._gen_corps

## Brins du drain d'origine quand le corps n'est plus pris en charge ; sinon rien (les filaments sont dessinés sur le corps).
static func _gen_drain(ic: ImpactCorps, j: Dictionary) -> Array:
	var f: ImpactCorps.Foyer = ic.trouver(j.cible, "tenebres") if ic.gm.valide(j.cible) else null
	if f == null or f.surface == null or f.surface.nb <= 0:
		return (j._gen0 as Callable).call()
	return []

static func statut(ic: ImpactCorps, f: ImpactCorps.Foyer, _nom: String, duree: float) -> bool:
	var d := f.d
	if duree <= 0.0:
		d.corr_fin = ic.gm.horloge
		return true
	d.corr_fin = maxf(float(d.corr_fin), ic.gm.horloge + duree)
	if (d.foyers as PackedInt32Array).is_empty() and f.surface != null and f.surface.nb > 0:
		f.surface.actualiser(f.origine())
		var p := f.surface.pos[int(d.imp_i)] if int(d.imp_i) >= 0 and int(d.imp_i) < f.surface.nb else f.surface.centre
		d.foyers = f.surface.foyers_pres_de(p, 4, ic.rng)
	return true

static func embraser(ic: ImpactCorps, f: ImpactCorps.Foyer, point: Vector3, direction: Vector3, force: float, duree: float) -> void:
	var d := f.d
	var o := f.origine()
	f.surface.actualiser(o)
	d.dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var i := f.surface.point_vise(point - o - d.dir * 1.5, d.dir)
	d.imp_i = i
	d.salve_fin = ic.gm.horloge + SALVE * clampf(force, 0.6, 1.8)
	d.corr_fin = maxf(float(d.corr_fin), ic.gm.horloge + 0.9)
	d.foyers = f.surface.foyers_pres_de(f.surface.pos[i] if i >= 0 else point - o, 4, ic.rng)
	if duree > 0.0:
		statut(ic, f, "corruption", duree)
	ic.gm.lumiere("corps%d" % f.id, o + (f.surface.pos[i] if i >= 0 else f.surface.centre) - d.dir * 0.5, GestionMagie.LUMIERE.tenebres, 3.0 * clampf(force, 0.6, 1.5), 3.5, 5.0, 0.35)

static func maj(ic: ImpactCorps, f: ImpactCorps.Foyer, dt: float) -> bool:
	var d := f.d
	var h := ic.gm.horloge
	var s := f.surface
	var org := f.origine()
	if ic.surface_changee(f):
		s.actualiser(org)
		d.imp_i = ImpactCorps.plus_proche(s, d.get("imp_p", s.centre)) if int(d.imp_i) >= 0 else -1
		d.sources = PackedInt32Array()
		d.foyers = PackedInt32Array()
	var jets: Dictionary = d.jets
	var n_jets := 0
	var dir := Vector3.ZERO
	var o := Vector3.ZERO
	var dbl := false
	for k in jets.keys():
		var jj: Dictionary = jets[k]
		if h - float(jj.vu) > RETOMBEE:
			jets.erase(k)
			continue
		n_jets += 1
		dir += jj.dir
		o += jj.o
		dbl = dbl or bool(jj.dbl)
	var sous_jet := n_jets > 0
	if sous_jet:
		dir = dir.normalized()
		o /= n_jets
		d.dir = dir
		d.main = o
		var i := ic.point_vise(f, o - org, dir)
		if i >= 0:
			d.imp_i = i
		d.k_jet = minf(float(d.k_jet) + dt / 0.15, 1.0)
		d.paleur = minf(float(d.paleur) + dt / 2.0, 0.7)
	else:
		d.k_jet = maxf(float(d.k_jet) - dt / 0.2, 0.0)
		d.paleur = maxf(float(d.paleur) - dt / 2.0, 0.0)
	var corr := h < float(d.corr_fin)
	d.k_corr = clampf(float(d.k_corr) + (dt / 0.3 if corr else -dt / DISSIPE), 0.0, 1.0)
	var salve := h < float(d.salve_fin)
	d.k_salve = 1.0 if salve else maxf(float(d.k_salve) - dt / 0.25, 0.0)
	var kj := float(d.k_jet)
	var kc := float(d.k_corr)
	var ks := float(d.k_salve)
	var imp := s.pos[int(d.imp_i)] if int(d.imp_i) >= 0 and int(d.imp_i) < s.nb else s.centre
	d.imp_p = imp
	# aspiration vers la main sous le drain ; sinon les fragments montent et se dissipent
	var main: Vector3 = d.main if kj > 0.05 else org + s.masse_centre + Vector3.UP * 1.6
	# ------------------------------------------------ filaments arrachés (sources renouvelées une à une)
	var fin := ic.gm.fin_actif
	var nf := (FILAMENTS if fin else 4) + (2 if dbl else 0)
	var src: PackedInt32Array = d.sources
	if kj > 0.05:
		if src.size() != nf:
			src.resize(nf)
			for k in nf:
				src[k] = _source(s, d.dir, imp, ic.rng)
		if h - float(d.t_source) > 0.22:
			d.t_source = h
			var k0 := int(d.k_source) % nf
			src[k0] = _source(s, d.dir, imp, ic.rng)
			d.k_source = k0 + 1
		d.sources = src
		if h - float(d.t_forme) > 0.1:
			d.t_forme = h
			ic.arcs_debut(f)
			for k in nf:
				var lg := 0.95 + 0.55 * float(k % 2 == 0)
				ic.arc(f, src[k], -1, 3, 12 if fin else 8, float(d.graine) + k * 1.618, lg * kj, 1.0 if k % 2 == 0 else 0.67)
				# accroche : petite pointe sombre là où le filament s'arrache
				ic.arc(f, src[k], -1, 2, 1, float(d.graine) + k * 2.7, 0.8, 0.67)
			ic.arcs_fin(f)
		ic.arcs_regler(f, main)
	elif f.nb_segs > 0:
		ic.arcs_debut(f)
		ic.arcs_fin(f)
		d.sources = PackedInt32Array()
	# ------------------------------------------------ émetteurs, uniformes
	if kc > 0.05 and (d.foyers as PackedInt32Array).is_empty():
		d.foyers = s.foyers_pres_de(imp, 4, ic.rng)
	var fo: Array = []
	var ids: PackedInt32Array = d.foyers
	for k in 4:
		if k < ids.size() and ids[k] < s.nb:
			fo.append(Vector4(s.pos[ids[k]].x, s.pos[ids[k]].y, s.pos[ids[k]].z, 0.16 + 0.04 * k))
		else:
			fo.append(Vector4.ZERO)
	ic.uniformes(f, "foyers", fo)
	ic.uniformes(f, "dir_jet", d.dir)
	ic.uniformes(f, "point_impact", imp)
	ic.uniformes(f, "rayon_jet", 0.45)
	ic.uniformes(f, "k_jet", maxf(kj, ks))
	ic.uniformes(f, "k_foyers", kc)
	ic.uniformes(f, "point_main", main.snapped(Vector3.ONE * 0.01))
	ic.uniformes(f, "sol_y", minf(s.bas, 0.0) + 0.02)
	for k in f.em.size():
		var r := maxf(SOUS_JET[k] * kj, CORRUPTION[k] * kc)
		if k == 2:
			r = ks
		ic.activer(f.em[k], r)
	# ------------------------------------------------ voile et coque
	var om := clampf(maxf(maxf(kj, ks), kc * 0.6), 0.0, 1.0)
	ic.ecoles(f, 0.0, 0.0, snappedf(om, 0.02), 0.0, snappedf(float(d.paleur), 0.02), org + imp, 0.0)
	var vers := (main - (org + s.masse_centre)).normalized()
	var mv := Vector4(snappedf(vers.x, 0.02), snappedf(vers.y, 0.02), snappedf(vers.z, 0.02), snappedf(kj, 0.05))
	if f.d.get("_mv") != mv:
		f.d["_mv"] = mv
		for c: MeshInstance3D in f.coques:
			if c.visible:
				c.set_instance_shader_parameter("mc_vers", mv)
	if kc > 0.05 and kj < 0.3:
		ic.gm.lumiere("corps%d" % f.cible.get_instance_id(), org + s.masse_centre, GestionMagie.LUMIERE.tenebres, (0.9 + 0.3 * sin(h * 5.0)) * kc, 2.8, 0.8)
	return sous_jet or corr or salve or kj > 0.0 or kc > 0.0 or ks > 0.0 or float(d.paleur) > 0.005

## Point de surface d'où s'arrache un filament : tourné vers le lanceur, plutôt dans le haut du corps, jamais trop loin de
## la zone visée (un « bouquet » de filaments, pas tout le corps).
static func _source(s: SurfaceCorps, dir: Vector3, imp: Vector3, rng: RandomNumberGenerator) -> int:
	var meilleur := -1
	var score := -INF
	for k in 16:
		var j := rng.randi_range(0, s.nb - 1)
		var face := -s.nor[j].dot(dir)
		var sc := face + rng.randf() * 0.6 - s.pos[j].distance_to(imp) * 0.9 + (0.3 if s.pos[j].y > lerpf(s.bas, s.haut, 0.4) else 0.0)
		if sc > score:
			score = sc
			meilleur = j
	return maxi(meilleur, 0)
