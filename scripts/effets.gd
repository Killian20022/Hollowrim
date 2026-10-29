class_name Effets
## Effets de combat partagés : arrêt sur image, ralenti. (Les éclats en cubes StandardMaterial3D — Effets.eclats — sont
## remplacés le 2026-10-28 par les gerbes de gros pixels en palette : GerbePixels.emettre(nœud, point, direction, matière, force).)

## Demandes d'échelle de temps en cours ([échelle, fin en ms réelles] par demande) : la plus lente l'emporte ; quand la dernière se
## termine, le temps reprend à 1. (Avant : deux arrêts superposés — épée + dégâts — se coupaient l'un l'autre au premier qui finissait.)
## Garde-fou : une demande échue (son minuteur n'a pas rendu la main) est ignorée ; une échelle n'est jamais tenue plus de DUREE_MAX s.
static var _demandes: Array = []
const DUREE_MAX := 1.5

## Option « Arrêt sur image » (Jeu.option("combat", "arret_image")) : 0 désactivé, 1 bref (défaut), 2 appuyé (réglages d'origine).
## Bref (2026-10-27, « très peu de FPS quand je frappe ») : l'arrêt complet (×0,03) de 50-110 ms à CHAQUE coup se lisait comme des
## saccades, surtout à 30 i/s (2-4 images figées par coup). En bref : ralenti ×0,2 au lieu du gel, durée ÷2, rien sous 40 ms (coups
## légers ou moyens — tous les coups légers sur un squelette — et parade : aucun arrêt ; lourd 55 ms, critique 70 ms, finisher
## 100 ms) ; ralenti de finisher plus court et moins lent.
## Niveau imposé (tests) ; -1 = option du joueur.
static var niveau_force := -1

static func niveau_arret() -> int:
	if niveau_force >= 0:
		return niveau_force
	return clampi(int(Jeu.option("combat", "arret_image")), 0, 2)

## Fige le jeu une fraction de seconde (temps réel) : donne du poids aux coups.
static func arret_image(arbre: SceneTree, duree: float) -> void:
	match niveau_arret():
		0:
			return
		1:
			duree *= 0.5
			if duree < 0.04:
				return
			await _echelle_temps(arbre, 0.2, duree)
		_:
			await _echelle_temps(arbre, 0.03, duree)

## Ralenti (échelle < 1) pendant `duree` s de temps réel (finishers).
static func ralenti(arbre: SceneTree, echelle: float, duree: float) -> void:
	match niveau_arret():
		0:
			return
		1:
			await _echelle_temps(arbre, maxf(echelle, 0.5), duree * 0.6)
		_:
			await _echelle_temps(arbre, echelle, duree)

static func _echelle_temps(arbre: SceneTree, echelle: float, duree: float) -> void:
	if arbre == null or duree <= 0.0:
		return
	duree = minf(duree, DUREE_MAX)
	var d := [echelle, Time.get_ticks_msec() + int(duree * 1000.0) + 250]
	_demandes.append(d)
	_maj_temps()
	await arbre.create_timer(duree, true, false, true).timeout
	_demandes.erase(d)
	_maj_temps()

static func _maj_temps() -> void:
	var e := 1.0
	var maintenant := Time.get_ticks_msec()
	for d: Array in _demandes.duplicate():
		if maintenant > int(d[1]):
			_demandes.erase(d)      # échue : on ne la laisse pas bloquer le temps
			continue
		e = minf(e, float(d[0]))
	Engine.time_scale = e

## Remet le temps à 1 et oublie toutes les demandes (mort du joueur, menu, changement de scène).
static func reinitialiser_temps() -> void:
	_demandes.clear()
	Engine.time_scale = 1.0
