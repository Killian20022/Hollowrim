class_name ObjGarnitures
## Lot C6 (2026-10-28, INSPIRATION_IGNITE §2.8 « tout objet porte d'autres objets ») : GARNITURES DE SURFACE des tables, autels et
## étagères de la CRYPTE — livres, rouleaux, bols (os, pièces, fond noirci), cruche, gobelet, crânes, chandeliers ÉTEINTS (aucune
## lumière, aucune flamme). Modules « garniture_table_a..c », « garniture_autel_a/b », « garniture_etagere_a/b » de
## sources_blender/scripts/objets_donjon.py (objets_donjon.dat, lu en FileAccess : sûr dans le fil). Autels et étagères : posés DANS
## l'objet meuble (j0/j1 du meuble : pour l'audit, la garniture fait partie de son hôte, comme l'urne de l'étagère) ; tables : un module
## et un objet d'audit par objet posé (« garniture_table_a1 »… : crâne, livres…, petits objets SUR la table, comme une bougie, sans
## changer le dessus de la table sur lequel les bougies s'appuient). Sans emprise, sans collision, sans tirage de
## dcr.rng : variante (ou rien) tirée de la position du meuble. Grotte et intérieurs : rien (dcr.est_crypte). Appelé par
## ObjPetitMobilier.table, ObjMobilierBois.etagere et ObjPierreStatuaire.autel (une ligne chacun) : le placement des meubles n'est pas
## touché. Chaque objet de la garniture laisse un disque (meta « c6_disques ») : les bougies posées APRÈS sur le même meuble
## (crypte_donjon.gd, tertre.gd) s'en écartent (ObjLuminaires.bougie_c6).

## Disques occupés [x, z, rayon] (repère de la garniture, avant échelle), relevés sur les modules d'objets_donjon.py.
const DISQUES := {
	"garniture_table_a1": [[-0.33, -0.22, 0.13]], "garniture_table_a2": [[0.06, 0.17, 0.06]], "garniture_table_a3": [[0.04, -0.22, 0.06]],
	"garniture_table_b1": [[-0.47, 0.17, 0.09]], "garniture_table_b2": [[-0.45, -0.12, 0.04]], "garniture_table_b3": [[0.05, 0.14, 0.08]],
	"garniture_table_c1": [[0.05, 0.1, 0.11]], "garniture_table_c2": [[-0.3, -0.215, 0.14]], "garniture_table_c3": [[0.47, -0.18, 0.1]],
	"garniture_autel_a": [[0.0, 0.05, 0.11], [-0.3, -0.18, 0.11], [0.32, -0.2, 0.14], [0.12, 0.22, 0.06]],
	"garniture_autel_b": [[-0.28, -0.25, 0.06], [0.06, 0.02, 0.09], [0.3, -0.14, 0.04], [-0.12, 0.22, 0.11]],
}

## Indice stable tiré de la position (repère du lieu), dans [0, n).
static func _tirage(dcr: CrypteDecor, pos: Vector3, n: int, decal := 0) -> int:
	var w := dcr.xf * pos
	return (absi(floori(w.x * 2.9) * 19349663 ^ floori(w.z * 2.9) * 73856093 ^ floori(w.y * 2.0) * 83492791) + decal) % n

static func _actif(dcr: CrypteDecor) -> bool:
	return dcr.est_crypte and not dcr.muet and CrypteDecor.modele_existe("garniture_autel_a")

static func _poser(dcr: CrypteDecor, nom: String, pos: Vector3, lacet: float, ech := Vector3.ONE) -> void:
	dcr.modele(nom, pos, lacet, ech, {}, false)
	var b := Basis(Vector3.UP, lacet)
	var disques: Array = dcr.get_meta("c6_disques", [])
	for d: Array in DISQUES.get(nom, []):
		disques.append([pos + b * Vector3(d[0], 0.0, d[1]), float(d[2]), dcr.emprises])
	dcr.set_meta("c6_disques", disques)

## Table (pos = position réelle, après l'écart au mur) : a, b, c ou rien (une table sur quatre reste nue).
static func table(dcr: CrypteDecor, pos: Vector3, lacet: float) -> void:
	if not _actif(dcr):
		return
	var k := _tirage(dcr, pos, 4)
	if k < 3:
		for i in 3:
			var nom := "garniture_table_%s%d" % ["abc"[k], i + 1]
			dcr.j0("crane" if nom == "garniture_table_c1" else "garniture", lacet)
			_poser(dcr, nom, pos, lacet)
			dcr.j1()

## Autel : garniture centrée sur la nappe ; autel large (offrandes au centre) : une de chaque côté, entre les offrandes et les bougies.
static func autel(dcr: CrypteDecor, pos: Vector3, lacet: float, largeur: float) -> void:
	if not _actif(dcr):
		return
	var b := Basis(Vector3.UP, lacet)
	var y := Vector3(0, 1.01, 0)
	var k := _tirage(dcr, pos, 2)
	if largeur < 3.8:
		_poser(dcr, "garniture_autel_" + "ab"[k], pos + y, lacet)
	else:
		for s in [-1.0, 1.0]:
			_poser(dcr, "garniture_autel_" + "ab"[(k + int(s > 0.0)) % 2], pos + y + b * Vector3(s * 0.95, 0, 0), lacet)

## Étagère debout : crâne au bout libre du 3e rayon, objets sur le dessus du bâti (variante du bâti `cadre`, même échelle).
static func etagere(dcr: CrypteDecor, pos: Vector3, lacet: float, cadre: String, ech: Vector3) -> void:
	if not _actif(dcr):
		return
	_poser(dcr, "garniture_etagere_" + cadre, pos, lacet, ech)
