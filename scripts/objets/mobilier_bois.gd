class_name ObjMobilierBois
## Mobilier de bois et tissus de la crypte (lot L3) : étagères, lits, râteliers, boucliers muraux, barricade, tapis, bannières.
## Corps des objets sortis de CrypteDecor (scripts/crypte_decor.gd) sans changer le rendu : chaque fonction reçoit le décor `dcr`
## (CrypteDecor ou GrotteDecor) et l'appelle comme avant (dcr.boite, dcr.solide, dcr.rng…) ; CrypteDecor garde une fonction d'une ligne
## du même nom (mêmes paramètres), que GrotteDecor peut toujours surcharger. Ne pas appeler ces fonctions directement : passer par le décor.

static func etagere(dcr: CrypteDecor, pos: Vector3, lacet: float, largeur := 1.8, haut := 2.0) -> void:
	dcr.j0("etagere", lacet)
	pos = dcr._ecarter(pos, Vector2(largeur * 0.5 + 0.04, 0.17), lacet)
	dcr.emprise("etagere", pos, Vector2(largeur * 0.5 + 0.04, 0.17), lacet, haut)
	dcr.occupations.append([pos, largeur * 0.5 + 0.15])
	var b := Basis(Vector3.UP, lacet)
	for sx in [-largeur * 0.5, largeur * 0.5]:
		dcr.boite("bois", pos + b * Vector3(sx, haut * 0.5, 0), Vector3(0.07, haut, 0.34), lacet)
	for y in [0.05, 0.7, 1.35, haut - 0.03]:
		dcr.boite("bois", pos + Vector3(0, y, 0), Vector3(largeur, 0.05, 0.34), lacet)
	dcr.boite("bois", pos + b * Vector3(0, haut * 0.5, -0.15), Vector3(largeur, haut, 0.03), lacet)
	for k in 7:        # rouleaux et grimoires posés
		var x := -largeur * 0.4 + k * (largeur * 0.8 / 6.0)
		var yy: float = [0.075, 0.725, 1.375][k % 3]
		dcr.boite("parchemin" if k % 2 == 0 else "bois", pos + b * Vector3(x, yy + 0.09, 0.0), Vector3(0.16, 0.2 if k % 2 else 0.14, 0.22), lacet)
	dcr.urne(pos + b * Vector3(largeur * 0.3, 0.0, 0.0) + Vector3(0, 1.38, 0), 0.5)
	dcr.j1()

## Étagère renversée (cadre couché et rayons obliques) : décor d'archives en ruine.
static func etagere_renversee(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, largeur := 1.8) -> void:
	dcr.j0("etagere_renversee", lacet)
	pos = dcr._ecarter(pos, Vector2(largeur * 0.5, 0.41), lacet)
	dcr.emprise("etagere_renversee", pos, Vector2(largeur * 0.5, 0.41), lacet, 0.8)
	var b := Basis(Vector3.UP, lacet)
	dcr.boite("bois", pos + b * Vector3(0, 0.07, 0), Vector3(largeur, 0.1, 0.8), lacet, false)
	for k in 4:
		dcr.boite("bois", pos + b * Vector3(0, 0.14 + k * 0.01, -0.3 + k * 0.2), Vector3(largeur, 0.05, 0.06), lacet + 0.05)
	for sx in [-largeur * 0.5, largeur * 0.5]:
		dcr.boite("bois", pos + b * Vector3(sx, 0.4, 0.38), Vector3(0.07, 0.8, 0.07), lacet + 0.1)
	var s := b * Vector3(largeur, 0, 0.8)
	dcr.solide(pos + Vector3(0, 0.25, 0), Vector3(absf(s.x), 0.5, absf(s.z)))
	dcr.j1()

## Lit de caserne : cadre de bois, paillasse, couverture (teinte) ; collision.
static func lit(dcr: CrypteDecor, pos: Vector3, lacet := 0.0, teinte := Color(0.5, 0.4, 0.36)) -> void:
	dcr.j0("lit", lacet)
	pos = dcr._ecarter(pos, Vector2(1.0, 0.45), lacet)
	dcr.emprise("lit", pos, Vector2(1.0, 0.45), lacet, 0.8)
	var b := Basis(Vector3.UP, lacet)
	for sz in [-0.4, 0.4]:
		dcr.boite("bois", pos + b * Vector3(0, 0.3, sz), Vector3(1.95, 0.1, 0.07), lacet)
	for sx in [-0.95, 0.95]:
		dcr.boite("bois", pos + b * Vector3(sx, 0.22, 0), Vector3(0.08, 0.44, 0.88), lacet)
	dcr.boite("bois", pos + b * Vector3(-0.95, 0.5, 0), Vector3(0.08, 0.6, 0.88), lacet)
	dcr.boite("jute", pos + Vector3(0, 0.4, 0), Vector3(1.8, 0.12, 0.78), lacet, false, Vector3.ZERO)      # paillasse : toile de sac
	dcr.boite("laine", pos + b * Vector3(0.3, 0.47, 0), Vector3(1.1, 0.05, 0.8), lacet)      # couverture de laine
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
	dcr.boite("bois", pos + b * Vector3(0, 0.95, 0), Vector3(largeur, 1.5, 0.05), lacet)
	for y in [0.55, 1.3]:
		dcr.boite("bois", pos + b * Vector3(0, y, 0.1), Vector3(largeur, 0.06, 0.1), lacet)
	for sx in [-largeur * 0.5, largeur * 0.5]:
		dcr.boite("bois", pos + b * Vector3(sx, 0.9, 0.04), Vector3(0.08, 1.8, 0.1), lacet)
	var n := int(largeur / 0.3)
	for k in n:
		var x := -largeur * 0.5 + 0.2 + k * (largeur - 0.4) / maxf(1.0, n - 1.0)
		match k % 3:
			0:
				dcr.boite("lame", pos + b * Vector3(x, 1.0, 0.13), Vector3(0.06, 0.95, 0.015), lacet)
				dcr.boite("fer", pos + b * Vector3(x, 0.52, 0.13), Vector3(0.2, 0.04, 0.04), lacet)
			1:
				dcr.boite("bois", pos + b * Vector3(x, 1.0, 0.13), Vector3(0.04, 1.7, 0.04), lacet)
				dcr.boite("lame", pos + b * Vector3(x, 1.9, 0.13), Vector3(0.07, 0.22, 0.015), lacet)
			_:
				dcr.boite("bois", pos + b * Vector3(x, 0.95, 0.13), Vector3(0.04, 1.2, 0.04), lacet)
				dcr.boite("fer", pos + b * Vector3(x + 0.07, 1.45, 0.13), Vector3(0.2, 0.22, 0.02), lacet)
	var s := b * Vector3(largeur, 0, 0.3)
	dcr.solide(pos + b * Vector3(0, 0.9, 0.05), Vector3(absf(s.x), 1.8, maxf(0.3, absf(s.z))))
	dcr.j1()

## Bouclier rond accroché au mur (octogone de bois cerclé de fer).
static func bouclier_mural(dcr: CrypteDecor, centre: Vector3, vers: Vector3, rayon := 0.32, teinte := Color(0.6, 0.4, 0.3)) -> void:
	dcr.j0("bouclier_mural", atan2(vers.x, vers.z))
	var n := vers.normalized()
	centre += dcr._saillie(centre, n, 0.33)
	var ax := dcr._axes(n)
	dcr._rect("bois", centre + n * 0.03, ax[0], ax[1], 0.0, 0.0, rayon * 2.0, rayon * 2.0, 0.0, n, teinte)
	dcr._rect("bois", centre + n * 0.032, ax[0], ax[1], 0.0, 0.0, rayon * 2.0, rayon * 2.0, PI * 0.25, n, teinte)
	dcr._rect("fer", centre + n * 0.045, ax[0], ax[1], 0.0, 0.0, rayon * 0.5, rayon * 0.5, PI * 0.25, n)
	dcr._rect("fer", centre + n * 0.04, ax[0], ax[1], 0.0, 0.0, rayon * 2.1, 0.04, 0.0, n)
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
		for k in 5:
			dcr.boite("bois", pos + b * Vector3(m + dcr.rng.randf_range(-0.1, 0.1), 0.2 + k * 0.32, dcr.rng.randf_range(-0.1, 0.1)), Vector3(z - a + dcr.rng.randf_range(-0.1, 0.1), 0.15, 0.06), lacet + dcr.rng.randf_range(-0.07, 0.07))
		dcr.boite("bois", pos + b * Vector3(a + 0.1, 0.8, 0.12), Vector3(0.1, 1.7, 0.1), lacet)
		dcr.boite("bois", pos + b * Vector3(z - 0.1, 0.8, 0.12), Vector3(0.1, 1.7, 0.1), lacet)
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
	var a := b * Vector3(-taille.x * 0.5, 0, -taille.y * 0.5)
	var bb := b * Vector3(taille.x * 0.5, 0, -taille.y * 0.5)
	var cc := b * Vector3(taille.x * 0.5, 0, taille.y * 0.5)
	var dd := b * Vector3(-taille.x * 0.5, 0, taille.y * 0.5)
	dcr.quad("laine", centre + a + Vector3(0, 0.015, 0), centre + bb + Vector3(0, 0.015, 0), centre + cc + Vector3(0, 0.015, 0), centre + dd + Vector3(0, 0.015, 0), Vector3.UP, [], [], [c, c, c, c])
	for sz in [-1.0, 1.0]:
		dcr.boite("or", centre + b * Vector3(0, 0.017, sz * (taille.y * 0.5 - 0.1)), Vector3(taille.x, 0.004, 0.05), lacet)
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
	dcr.boite("bois", haut + n * 0.1, Vector3(larg + 0.24, 0.05, 0.05), lacet)
	dcr.boite("fer", haut + n * 0.1 + dr * (larg * 0.5 + 0.13), Vector3(0.06, 0.07, 0.07), lacet)
	dcr.boite("fer", haut + n * 0.1 - dr * (larg * 0.5 + 0.13), Vector3(0.06, 0.07, 0.07), lacet)
	var teinte := Color(couleur.r, couleur.g, couleur.b)
	var haut_plein := long * (1.0 if usure == 0 else 0.42)
	var p0 := haut + n * 0.07
	# partie haute pleine
	dcr.quad("laine", p0 - dr * larg * 0.5, p0 + dr * larg * 0.5, p0 + dr * larg * 0.5 - Vector3(0, haut_plein, 0) + n * 0.03, p0 - dr * larg * 0.5 - Vector3(0, haut_plein, 0) + n * 0.03, n, [], [], [teinte, teinte, teinte, teinte])
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
