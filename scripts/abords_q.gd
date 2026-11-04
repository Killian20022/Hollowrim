class_name AbordsQ
## Lot « abords + enceinte » (gen/abords, 2026-11-04) : props Quaternius DÉJÀ convertis (props_quaternius.dat, API PropsQuaternius)
## fondus dans les maillages existants des abords (barrières des abords, camp des bandits). Aucun nœud par prop.
## Interrupteur : `-- --abords-anciens` rend les anciennes pièces maison (captures « avant », mesures A/B) ; `--sans-remplacement`
## et `--sans-lot4` les rendent aussi (les rochers et les pièges viennent du lot 4).
## Doc : docs/ABORDS_QUATERNIUS.md.

static var actif := PropsQuaternius.lot4 and not ("--abords-anciens" in OS.get_cmdline_user_args())

## Ajoute toutes les matières du prop `nom` (repère du prop : origine au sol) à `dst`, transformées par `xf` (base quelconque,
## cisaillement compris). Couleur de sommet = couleur du prop × `teinte` ; alpha 0 (neige du shader ps1_bati) sur les faces dont la
## normale monte au-dessus de `neige` (> 1 : jamais). `uv_m` : UV en mètres par projection sur le plan de la face (rondins, uv_metres).
static func vers_maillage(dst: BatiGeo.Maillage, nom: String, xf: Transform3D, teinte := Color.WHITE, neige := 2.0, uv_m := false) -> int:
	if not PropsQuaternius.existe(nom):
		return 0
	var bn := xf.basis.inverse().transposed()
	var n := 0
	for e: Array in PropsQuaternius.triangles(nom):
		var pos: PackedVector3Array = e[1]
		var col: PackedColorArray = e[2]
		for t in range(0, pos.size(), 3):
			var a := xf * pos[t]
			var b := xf * pos[t + 1]
			var c := xf * pos[t + 2]
			var nf := (c - a).cross(b - a)
			if nf.length_squared() < 1e-12:
				continue
			nf = nf.normalized()
			# ordre Godot (horaire) déjà fait par PropsQuaternius ; un repère miroir l'inverse
			if xf.basis.determinant() < 0.0:
				var s := b
				b = c
				c = s
				nf = -nf
			var blanc := nf.y > neige
			var ax := nf.abs()
			for j in 3:
				var p: Vector3 = [a, b, c][j]
				var k: Color = col[t + [0, 1, 2][j] if xf.basis.determinant() >= 0.0 else t + [0, 2, 1][j]]
				dst.v.append(p)
				dst.n.append(nf)
				if blanc:
					var kn := lerpf(0.86, 1.0, k.r)
					dst.c.append(Color(kn, kn, kn * 1.02, 0.0))
				else:
					dst.c.append(Color(k.r * teinte.r, k.g * teinte.g, k.b * teinte.b, 1.0))
				if uv_m:
					var q := xf.basis.inverse() * (p - xf.origin)    # repère du prop, puis mètres réels le long de son X
					var sx := xf.basis.x.length()
					if ax.y >= ax.x and ax.y >= ax.z:
						dst.uv.append(Vector2(q.x * sx, p.z))
					elif ax.z >= ax.x:
						dst.uv.append(Vector2(q.x * sx, p.y))
					else:
						dst.uv.append(Vector2(p.y, p.z))
				else:
					dst.uv.append(Vector2.ZERO)
			n += 1
	return n

## Plusieurs props fondus en UN maillage (une surface, une matière) : [[nom, Transform3D], …] ; mêmes règles que vers_maillage.
static func mesh_fondu(liste: Array, teinte := Color.WHITE, neige := 2.0) -> ArrayMesh:
	var m := BatiGeo.Maillage.new()
	for e: Array in liste:
		vers_maillage(m, e[0], e[1], teinte, neige)
	return m.mesh()

## Base qui envoie le X du prop (largeur l0) de `a` à `b` (pente suivie, montants restant verticaux), Y × hy, Z × hz.
static func base_segment(a: Vector3, b: Vector3, l0: float, hy: float, hz: float) -> Basis:
	var d := b - a
	var h := Vector3(d.x, 0, d.z).normalized()
	return Basis(d / l0, Vector3(0, hy, 0), Vector3(-h.z, 0, h.x) * hz)
