class_name Furtivite
extends RefCounted
## FURTIVITÉ MINIMALE (docs/COMBAT.md « Furtivité ») : règles pures, sans état, partagées par le joueur, les ennemis (draugr, troll,
## mage), les PNJ du village (crime.gd) et le HUD. Tout réglage est une constante ici.
##   bruit(j)         rayon (m) dans lequel on ENTEND le joueur selon son allure : accroupi < marche < course (le jeu n'a qu'une
##                    allure de course : elle tient lieu de sprint) ; armure lourde = plus bruyant ; immobile = silencieux.
##   visibilite(j)    facteur de la portée de vue : accroupi ×0,5 ; nuit / sous terre ×0,5 ; torche allumée = visible (pas de gain
##                    de la nuit, ×1,25 : on voit la flamme de loin). Cumulable (accroupi de nuit sans torche = ×0,25).
##   progression(...) détection PROGRESSIVE : la jauge de vigilance (0..1) monte d'autant plus vite que le joueur est près, et
##                    retombe quand il n'est plus perçu ; à 1 l'ennemi le repère (TRAQUE).
const BRUIT_ACCROUPI := 3.0
const BRUIT_MARCHE := 8.0
const BRUIT_COURSE := 14.0
const SEUIL_MOUVEMENT := 0.3        # m/s : en dessous, le joueur est immobile (aucun bruit de pas)
const BRUIT_PIECE_LOURDE := 0.15    # +15 % de bruit par pièce d'armure lourde portée (jusqu'à 4 : +60 %)
const VUE_ACCROUPI := 0.5
const VUE_NUIT := 0.5
const VUE_TORCHE := 1.25
const VUE_DOS := 0.5                # joueur dans le dos de l'ennemi : portée de vue réduite (le bruit, lui, porte toujours)
const GAIN_LOIN := 0.6              # /s de jauge au bord de la portée (≈ 1,7 s pour repérer)
const GAIN_PRES := 2.5              # /s au contact (≈ 0,4 s)
const PERTE := 0.5                  # /s quand le joueur n'est plus perçu
const SEUIL_SURPRIS := 0.5          # un ennemi dont la jauge est sous ce seuil n'a rien remarqué : un coup furtif de face compte
const SEUIL_TEMOIN := 0.6           # PNJ du village : jauge minimale pour témoigner d'un crime quand le joueur est accroupi
const PRATIQUE := 0.4               # points de Furtivité par seconde passée accroupi, en mouvement, près d'un ennemi qui ne voit pas

static func _lire(j: Object, nom: String, defaut: Variant) -> Variant:
	if j == null or not is_instance_valid(j):
		return defaut
	var v: Variant = j.get(nom)
	return defaut if v == null else v

static func accroupi(j: Object) -> bool:
	return _lire(j, "accroupi", false) == true

## "immobile", "accroupi" (en mouvement), "marche" ou "course".
static func allure(j: Object) -> String:
	var v: Vector3 = _lire(j, "velocity", Vector3.ZERO)
	if Vector2(v.x, v.z).length() < SEUIL_MOUVEMENT:
		return "immobile"
	if accroupi(j):
		return "accroupi"
	return "course" if _lire(j, "est_court", false) == true else "marche"

## Facteur de bruit de l'armure portée : +BRUIT_PIECE_LOURDE par pièce « lourde » (type_armure des objets), 4 pièces au plus.
static func facteur_armure(j: Object) -> float:
	var eq: Variant = _lire(j, "equipement_corps", null)
	if eq == null:
		return 1.0
	return 1.0 + BRUIT_PIECE_LOURDE * minf(float(eq.nombre_pieces("lourde")), 4.0)

## Rayon (m) dans lequel les PNJ et ennemis entendent le joueur.
static func bruit(j: Object) -> float:
	var r := 0.0
	match allure(j):
		"accroupi": r = BRUIT_ACCROUPI
		"marche": r = BRUIT_MARCHE
		"course": r = BRUIT_COURSE
	return r * facteur_armure(j)

## Rayon d'ouïe de référence `base` (R_OUIE de crime.gd pour une marche normale) mis à l'échelle du bruit actuel.
static func ouie(j: Object, base: float) -> float:
	return base * bruit(j) / BRUIT_MARCHE if allure(j) != "immobile" else base * 0.2

## Nuit (19 h – 6 h 30) ou sous terre : le décor est sombre.
static func est_sombre(j: Object) -> bool:
	var monde: Node = (j as Node).get_parent() if j is Node else null
	if monde == null:
		return false
	if monde.get("_sous_terre_actif") == true:
		return true
	var c: Variant = monde.get("cycle")
	if c == null:
		return false
	var h := float(c.heure)
	return h >= 19.0 or h < 6.5

## Torche allumée dans la main gauche (un sort ou un bouclier n'éclaire pas).
static func torche(j: Object) -> bool:
	var m: Variant = _lire(j, "mains", null)
	var eq: Variant = m.get("equipement") if m != null else null
	return eq != null and eq.get("main_gauche") == Equipement.TORCHE

## Facteur de la portée de vue des ennemis et PNJ.
static func visibilite(j: Object) -> float:
	var f := 1.0
	if accroupi(j):
		f *= VUE_ACCROUPI
	if torche(j):
		f *= VUE_TORCHE
	elif est_sombre(j):
		f *= VUE_NUIT
	return f

## Jauge de vigilance après `dt` : `portee` = portée de vue (déjà × visibilite), `voit` = ligne de vue libre, `dos` = joueur derrière
## l'observateur, `bruit` = rayon d'ouïe. Perçu = dans la portée de vue (réduite de dos) avec ligne de vue, ou dans le rayon d'ouïe.
static func progression(vigilance: float, dt: float, dist: float, portee: float, voit: bool, dos: bool, bruit_m: float) -> float:
	var rayon := bruit_m
	if voit:
		rayon = maxf(rayon, portee * (VUE_DOS if dos else 1.0))
	if dist < rayon:
		var proche := clampf(1.0 - dist / rayon, 0.0, 1.0)
		return minf(1.0, vigilance + dt * lerpf(GAIN_LOIN, GAIN_PRES, proche))
	return maxf(0.0, vigilance - dt * PERTE)

## Un observateur `obs` (ennemi) met sa jauge à jour et en informe le joueur (œil du HUD). Renvoie la nouvelle jauge (1 = repéré).
static func observer(obs: Node3D, j: Node3D, vigilance: float, dt: float, dist: float, portee: float, voit: bool) -> float:
	var vers := j.global_position - obs.global_position
	var dos := vers.length() > 0.1 and obs.global_transform.basis.z.dot(vers.normalized()) < -0.3
	var v := progression(vigilance, dt, dist, portee * visibilite(j), voit, dos, bruit(j))
	if v > 0.0 and j.has_method("signaler_vigilance"):
		j.signaler_vigilance(v)
	return v

## Facteur de la distance de réveil des dormeurs : accroupi 3/8, marche 1, course 14/8 (immobile debout = marche : on ne dort pas mieux).
static func facteur_reveil(j: Object) -> float:
	match allure(j):
		"accroupi": return BRUIT_ACCROUPI / BRUIT_MARCHE
		"course": return BRUIT_COURSE / BRUIT_MARCHE
	return 1.0 if not accroupi(j) else BRUIT_ACCROUPI / BRUIT_MARCHE
