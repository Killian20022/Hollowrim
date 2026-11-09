class_name ArcherTripo
extends Node
## Comportement d'archer d'ESSAI pour l'archer Tripo (scripts/garde_tripo.gd, actif par défaut, voir ModelesTripo) : se tourne vers une cible, bande l'arc
## (clip Pistol_Aim_Neutral : PoseArcher de la chasseresse tire la corde vers la main droite, flèche encochée), lâche (Pistol_Shoot : l'arc
## relâché prend le relais) et lance une VRAIE flèche (Projectile.tirer, comme les archers bandits de draugr.gd) qui vole, chute et se plante.
## Nœud enfant du villageois ; pendant la rafale l'IA du villageois est suspendue. N'est installé que par les outils d'essai (outils/film_tripo_gardes_v2.gd).
##   ArcherTripo.poser(villageois).tirer_sur(point_monde, nb_flèches)   (attendre le résultat avec await)

const VISEE := 1.0       # s de visée avant chaque lâcher
const DEGATS := 8.0
var v: CharacterBody3D

static func poser(villageois: CharacterBody3D) -> ArcherTripo:
	var a := ArcherTripo.new()
	a.name = "ArcherTripo"
	a.v = villageois
	villageois.add_child(a)
	return a

## `cible` : point visé (monde). Rend la main à l'IA du villageois à la fin.
func tirer_sur(cible: Vector3, nb := 1, pause := 0.9) -> void:
	v.set_physics_process(false)
	var ap: AnimationPlayer = v.anim
	# face à la cible (le haut du corps de PoseArcher suppose la cible droit devant)
	var d := cible - v.global_position
	var lacet := atan2(d.x, d.z)
	var tw := create_tween()
	tw.tween_property(v, "rotation:y", lacet_proche(v.rotation.y, lacet), 0.35)
	await tw.finished
	for i in nb:
		ap.speed_scale = 1.0
		ap.play("Pistol_Aim_Neutral", 0.15)
		await get_tree().create_timer(VISEE).timeout
		ap.play("Pistol_Shoot", 0.05)
		await get_tree().create_timer(ChasseresseNordique.LACHER).timeout
		_lacher(cible)
		await get_tree().create_timer(maxf(ap.get_animation("Pistol_Shoot").length - ChasseresseNordique.LACHER, 0.3) + pause).timeout
	ap.play("Idle", 0.3)
	v.set_physics_process(true)

static func lacet_proche(de: float, vers: float) -> float:
	return de + wrapf(vers - de, -PI, PI)

func _lacher(cible: Vector3) -> void:
	var main := EnnemisNordiques.main_de_tir(v.modele)      # la flèche part de la main qui tient l'arc
	var depart := v.global_position + Vector3(0, 1.4, 0)
	if main != Vector3.INF:
		depart = main + (cible - main).normalized() * 0.3
	var dir := Projectile.cap_visee(depart, cible)
	Projectile.tirer(v.get_parent(), depart, dir, v, DEGATS, null)
	Sons.jouer_a(v, ["swing2", "swing3"], depart, -2.0, 0.1)
