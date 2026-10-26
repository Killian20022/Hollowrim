class_name ObjMobilierBois
## Mobilier de bois et tissus de la crypte (lot L3) : étagères, lits, râteliers, boucliers muraux, barricade, tapis, bannières.
## Corps des objets sortis de CrypteDecor (scripts/crypte_decor.gd) sans changer le rendu : chaque fonction reçoit le décor `dcr`
## (CrypteDecor ou GrotteDecor) et l'appelle comme avant (dcr.boite, dcr.solide, dcr.rng…) ; CrypteDecor garde une fonction d'une ligne
## du même nom (mêmes paramètres), que GrotteDecor peut toujours surcharger. Ne pas appeler ces fonctions directement : passer par le décor.

## Lot L3 (2026-10-26) : étagères, lits, râteliers, boucliers et planches de barricade sont des modules Blender (objets_donjon.dat,
## voir ObjPetitMobilier) posés par dcr.modele(), variantes tirées de la position ; tapis et bannières restent procéduraux (tailles
## libres) mais gagnent franges, motif, plis et tringle à pommeaux. Emprises, collisions et tirages de dcr.rng inchangés.

static func etagere(dcr: CrypteDecor, pos: Vector3, lacet: float, largeur := 1.8, haut := 2.0) -> void:
	dcr.j0("etagere", lacet)
	pos = dcr._ecarter(pos, Vector2(largeur * 0.5 + 0.04, 0.17), lacet)
	dcr.emprise("etagere", pos, Vector2(largeur * 0.5 + 0.04, 0.17), lacet, haut)
	dcr.occupations.append([pos, largeur * 0.5 + 0.15])
	var b := Basis(Vector3.UP, lacet)
	var ech := Vector3(largeur / 1.8, haut / 2.0, 1.0)
	dcr.modele("etagere_cadre_" + ObjPetitMobilier.variante(dcr, pos, 2), pos, lacet, ech, {}, false)
	dcr.modele("etagere_contenu_" + ObjPetitMobilier.variante(dcr, pos, 3, 1), pos, lacet, ech, {}, false)      # livres, rouleaux, coffrets
	dcr.urne(pos + b * Vector3(largeur * 0.3, 0.0, 0.0) + Vector3(0, 1.38, 0), 0.5)
	dcr.j1()

## Étagère renversée (cadre couché et rayons obliques) : décor d'archives en ruine.
static func etagere_renversee(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, largeur := 1.8) -> void:
	dcr.j0("etagere_renversee", lacet)
	pos = dcr._ecarter(pos, Vector2(largeur * 0.5, 0.41), lacet)
	dcr.emprise("etagere_renversee", pos, Vector2(largeur * 0.5, 0.41), lacet, 0.8)
	var b := Basis(Vector3.UP, lacet)
	dcr.modele("etagere_couchee_" + ObjPetitMobilier.variante(dcr, pos, 2), pos, lacet, Vector3(largeur / 1.92, 1.0, 1.0), {}, false)
	var s := b * Vector3(largeur, 0, 0.8)
	dcr.solide(pos + Vector3(0, 0.25, 0), Vector3(absf(s.x), 0.5, absf(s.z)))
	dcr.j1()

## Lit de caserne : cadre de bois, paillasse, couverture (teinte) ; collision.
static func lit(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, teinte := Color(0.5, 0.4, 0.36)) -> void:
	dcr.j0("lit", lacet)
	pos = dcr._ecarter(pos, Vector2(1.0, 0.45), lacet)
	dcr.emprise("lit", pos, Vector2(1.0, 0.45), lacet, 0.8)
	var b := Basis(Vector3.UP, lacet)
	dcr.modele("lit_" + ObjPetitMobilier.variante(dcr, pos, 2), pos, lacet, Vector3.ONE, {}, false)      # cadre, paillasse de jute, couverture drapée
	var s := b * Vector3(2.0, 0, 0.9)
	dcr.solide(pos + Vector3(0, 0.3, 0), Vector3(absf(s.x), 0.6, absf(s.z)))
	dcr.j1()

## Râtelier d'armes contre un mur (dos vers -Z local) : épées, lances, haches.
static func ratelier_armes(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, largeur := 1.8) -> void:
	dcr.j0("ratelier_armes", lacet)
	pos = dcr._ecarter(pos + Basis(Vector3.UP, lacet) * Vector3(0, 0, 0.05), Vector2(largeur * 0.5 + 0.04, 0.15), lacet) - Basis(Vector3.UP, lacet) * Vector3(0, 0, 0.05)
	dcr.emprise("ratelier_armes", pos + Basis(Vector3.UP, lacet) * Vector3(0, 0, 0.05), Vector2(largeur * 0.5 + 0.04, 0.15), lacet, 2.0)
	dcr.occupations.append([pos, largeur * 0.5 + 0.15])
	var b := Basis(Vector3.UP, lacet)
	dcr.modele("ratelier_cadre_" + ObjPetitMobilier.variante(dcr, pos, 2), pos, lacet, Vector3(largeur / 1.8, 1.0, 1.0), {}, false)
	var n := int(largeur / 0.3)
	for k in n:       # épée, lance, hache (mêmes places que l'ancienne version)
		var x := -largeur * 0.5 + 0.2 + k * (largeur - 0.4) / maxf(1.0, n - 1.0)
		dcr.modele("arme_v_" + "abc"[k % 3], pos + b * Vector3(x, 0.0, 0.13), lacet, Vector3.ONE, {}, false)
	var s := b * Vector3(largeur, 0, 0.3)
	dcr.solide(pos + b * Vector3(0, 0.9, 0.05), Vector3(absf(s.x), 1.8, maxf(0.3, absf(s.z))))
	dcr.j1()

## Bouclier rond accroché au mur (octogone de bois cerclé de fer).
static func bouclier_mural(dcr: CrypteDecor, centre: Vector3, vers: Vector3, rayon := 0.32, teinte := Color(0.6, 0.4, 0.3)) -> void:
	dcr.j0("bouclier_mural", atan2(vers.x, vers.z))
	var n := vers.normalized()
	centre += dcr._saillie(centre, n, 0.33)
	# planches peintes (teinte en couleur de sommet, comme avant), cerclage et umbo de fer
	dcr.modele("bouclier_" + ObjPetitMobilier.variante(dcr, centre), centre, atan2(n.x, n.z), Vector3.ONE * (rayon / 0.32), {"peint": "bois", "@peint": teinte}, false)
	dcr.j1()

## Barricade de planches, tonneaux et table renversée en travers d'un passage (largeur `largeur`) ; `trou` > 0 : brèche de cette largeur,
## décalée de `decal` le long du passage (jamais bloquée : les deux blocs de collision laissent la brèche libre).
static func barricade(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, largeur := 3.0, trou := 1.3, decal := 0.0) -> void:
	dcr.j0("barricade", lacet)
	dcr.emprise("barricade", pos, Vector2(largeur * 0.5, 0.64), lacet, 1.7)
	var b := Basis(Vector3.UP, lacet)
	var g0 := decal - trou * 0.5
	var g1 := decal + trou * 0.5
	for seg in [[-largeur * 0.5, g0], [g1, largeur * 0.5]]:
		var a: float = seg[0]
		var z: float = seg[1]
		if z - a < 0.1:
			continue
		var m := (a + z) * 0.5
		dcr.solide(pos + b * Vector3(m, 0.8, 0), (b * Vector3(z - a, 1.6, 0.5)).abs())
		for k in 5:       # planches clouées (modules étirés), mêmes tirages qu'avant
			var px := m + dcr.rng.randf_range(-0.1, 0.1)
			var pz := dcr.rng.randf_range(-0.1, 0.1)
			var lg := z - a + dcr.rng.randf_range(-0.1, 0.1)
			dcr.modele("planche_" + "abc"[k % 3], pos + b * Vector3(px, 0.2 + k * 0.32, pz), lacet + dcr.rng.randf_range(-0.07, 0.07), Vector3(lg, 1.0, 1.0), {}, false)
		dcr.modele("poteau", pos + b * Vector3(a + 0.1, 0.8, 0.12), lacet, Vector3.ONE, {}, false)
		dcr.modele("poteau", pos + b * Vector3(z - 0.1, 0.8, 0.12), lacet + 1.3, Vector3.ONE, {}, false)
	dcr.tonneau(pos + b * Vector3(-largeur * 0.5 + 0.35, 0, 0.5), 0.9)
	dcr.boite("bois", pos + b * Vector3(largeur * 0.5 - 0.7, 0.5, 0.55), Vector3(1.0, 0.07, 0.65), lacet + 0.3)       # table renversée
	dcr.boite("bois", pos + b * Vector3(largeur * 0.5 - 0.7, 0.28, 0.55), Vector3(0.07, 0.5, 0.07), lacet + 0.3)
	for k in 3:       # planches tombées devant
		dcr.boite("bois", pos + b * Vector3(dcr.rng.randf_range(-largeur * 0.4, largeur * 0.4), 0.04, dcr.rng.randf_range(0.4, 1.0)), Vector3(1.2, 0.05, 0.14), lacet + dcr.rng.randf_range(-0.6, 0.6))
	dcr.j1()

## Tapis processionnel (étoffe teintée, deux liserés) posé au sol.
static func tapis(dcr: CrypteDecor, centre: Vector3, taille: Vector2, lacet := 0.0, teinte := Color(0.5, 0.2, 0.2)) -> void:
	dcr.j0("tapis", lacet)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("laine", centre + Vector3(0, 0.008, 0), Vector3(taille.x, 0.012, taille.y), lacet, true)
	var c := Color(teinte.r, teinte.g, teinte.b)
	var hx := taille.x * 0.5
	var hz := taille.y * 0.5
	var P := func(x: float, z: float, y: float) -> Vector3: return centre + b * Vector3(x, 0, z) + Vector3(0, y, 0)
	dcr.quad("laine", P.call(-hx, -hz, 0.015), P.call(hx, -hz, 0.015), P.call(hx, hz, 0.015), P.call(-hx, hz, 0.015), Vector3.UP, [], [], [c, c, c, c])
	for sz in [-1.0, 1.0]:
		dcr.boite("or", centre + b * Vector3(0, 0.017, sz * (hz - 0.1)), Vector3(taille.x, 0.004, 0.05), lacet)
	# lot L3 : liseré intérieur et losanges tissés (teinte foncée), franges aux deux bouts
	var f := Color(c.r * 0.35, c.g * 0.35, c.b * 0.35)
	var cf := [f, f, f, f]
	var i0 := 0.24
	var e := 0.05
	for q: Array in [[-hx + i0, -hz + i0, hx - i0, -hz + i0 + e], [-hx + i0, hz - i0 - e, hx - i0, hz - i0], [-hx + i0, -hz + i0, -hx + i0 + e, hz - i0], [hx - i0 - e, -hz + i0, hx - i0, hz - i0]]:
		dcr.quad("laine", P.call(q[0], q[1], 0.0165), P.call(q[2], q[1], 0.0165), P.call(q[2], q[3], 0.0165), P.call(q[0], q[3], 0.0165), Vector3.UP, [], [], cf)
	var nl := maxi(1, int(taille.x / 1.6))
	var dl := minf(0.32, hz - i0 - 0.12)
	if dl > 0.08:
		for k in nl:
			var x := -hx + taille.x * (k + 0.5) / nl
			dcr.quad("laine", P.call(x - dl * 1.4, 0, 0.017), P.call(x, -dl, 0.017), P.call(x + dl * 1.4, 0, 0.017), P.call(x, dl, 0.017), Vector3.UP, [], [], cf)
	var cl := Color(minf(1.0, c.r * 1.25 + 0.08), minf(1.0, c.g * 1.25 + 0.08), minf(1.0, c.b * 1.25 + 0.08))
	var cc := [cl, cl, cl, cl]
	var nf := int(taille.y / 0.06)
	for sx in [-1.0, 1.0]:
		for k in nf:
			var z := -hz + 0.03 + k * (taille.y - 0.06) / maxf(1.0, nf - 1.0)
			var lg := 0.07 + 0.015 * float(k % 3)
			dcr.quad("laine", P.call(sx * hx, z - 0.012, 0.006), P.call(sx * (hx + lg), z - 0.01, 0.004), P.call(sx * (hx + lg), z + 0.01, 0.004), P.call(sx * hx, z + 0.012, 0.006), Vector3.UP, [], [], cc)
	dcr.j1()

## Bannière accrochée à une tringle : `haut` = point du mur (hauteur de la tringle), `vers` = normale vers la pièce, usure 0 intacte, 1 déchirée, 2 en lambeaux.
static func banniere(dcr: CrypteDecor, haut: Vector3, vers: Vector3, long := 1.7, larg := 0.75, couleur := Color(0.62, 0.3, 0.26), sujet := "", usure := 1, teinte_embleme := Color(0.9, 0.85, 0.7)) -> void:
	dcr.j0("banniere", atan2(vers.x, vers.z))
	var n := vers.normalized()
	haut += dcr._saillie(haut, n, 0.33)      # devant les blocs des panneaux v2 (saillie jusqu'à 0,3 m)
	dcr.nb_bannieres += 1
	var cb := dcr.saillie_cb
	dcr.saillie_cb = Callable()
	var dr: Vector3 = dcr._axes(n)[0]
	var lacet := atan2(n.x, n.z)
	# lot L3 : tringle ronde à pommeaux de fer et pattes jusqu'au mur (module), à la place de la barre et des deux blocs
	dcr.modele("tringle_" + ObjPetitMobilier.variante(dcr, haut, 2), haut + n * 0.1, lacet, Vector3((larg + 0.24) / 0.99, 1.0, 1.0), {}, false)
	var teinte := Color(couleur.r, couleur.g, couleur.b)
	var ombre := Color(teinte.r * 0.72, teinte.g * 0.72, teinte.b * 0.72)
	var haut_plein := long * (1.0 if usure == 0 else 0.42)
	var p0 := haut + n * 0.07
	# partie haute pleine : 4 lés plissés (creux plus sombres)
	var bas := -Vector3(0, haut_plein, 0) + n * 0.03
	for k in 4:
		var xa := -larg * 0.5 + larg * k / 4.0
		var xb := -larg * 0.5 + larg * (k + 1) / 4.0
		var da := n * (0.014 if k % 2 == 1 else 0.0)
		var db := n * (0.014 if k % 2 == 0 else 0.0)
		var ca := ombre if k % 2 == 0 else teinte
		var cbb := teinte if k % 2 == 0 else ombre
		dcr.quad("laine", p0 + dr * xa + da, p0 + dr * xb + db, p0 + dr * xb + db + bas, p0 + dr * xa + da + bas, n, [], [], [ca, cbb, cbb, ca])
	if usure == 0:      # bas en queue d'aronde
		var yb := p0 + bas
		var pointe := Vector3(0, 0.2, 0)
		dcr.quad("laine", yb - dr * larg * 0.5, yb, yb - dr * larg * 0.25 - pointe * 0.25, yb - dr * larg * 0.5 - pointe, n, [], [], [ombre, teinte, teinte, ombre])
		dcr.quad("laine", yb, yb + dr * larg * 0.5, yb + dr * larg * 0.5 - pointe, yb + dr * larg * 0.25 - pointe * 0.25, n, [], [], [teinte, ombre, ombre, teinte])
	if usure > 0:
		var nb := 3 if usure == 1 else 2
		var lw := larg / nb
		for k in nb:
			var lon := long * dcr.rng.randf_range(0.5, 0.85) if usure == 1 else long * dcr.rng.randf_range(0.5, 0.65)
			var x0 := -larg * 0.5 + k * lw
			var ya := p0 - Vector3(0, haut_plein, 0) + n * 0.03
			var yb := p0 - Vector3(0, lon, 0) + n * (0.03 + dcr.rng.randf() * 0.05)
			var inc := dcr.rng.randf_range(-0.05, 0.05)
			dcr.quad("laine", ya + dr * x0, ya + dr * (x0 + lw * 0.9), yb + dr * (x0 + lw * 0.9 + inc), yb + dr * (x0 + inc), n, [], [], [teinte, teinte, Color(teinte.r * 0.8, teinte.g * 0.8, teinte.b * 0.8), Color(teinte.r * 0.8, teinte.g * 0.8, teinte.b * 0.8)])
	if sujet != "":
		dcr.embleme(sujet, p0 + n * 0.045 - Vector3(0, minf(haut_plein, long) * 0.32, 0), n, larg * 0.5, teinte_embleme)
	dcr.saillie_cb = cb
	dcr.j1()
