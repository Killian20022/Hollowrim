extends Node
## Garde l'arme dans l'axe naturel de la main : au repos et en marche la pointe regarde vers le bas / l'avant (jamais « en broche »
## à l'horizontale), quel que soit le clip. Les clips de l'IA tiennent la main d'une façon différente (marche : poing en avant, lame
## horizontale). On pivote donc l'arme autour de l'axe X de la main (δ) pour amener l'élévation de la lame sur CIBLE ; pendant les
## attaques on rend la main au clip (arc de frappe d'origine, INCL de base).
const CIBLE := Vector3(-0.1, -0.62, 0.78)   # lame vers l'avant et le bas (le -x est l'extérieur de la main droite)
const ATTAQUES := ["Sword_Attack", "Punch_Cross", "Zombie_Attaque", "Zombie_Coup"]
var sq: Skeleton3D
var ap: AnimationPlayer
var arme: Node3D
var base: Basis
var centre: Vector3
var ech := 1.0
var grip := 0.04
var incl := -35.0
var os := -1

const LIMITE := 85.0   # écart maximal (°) imposé par rapport à l'orientation du clip
var _w := 0.0

func _process(dt: float) -> void:
	if sq == null or arme == null or ap == null or not is_inside_tree():
		return
	var clip := String(ap.current_animation)
	var veut := 1.0
	if ATTAQUES.has(clip) or clip.begins_with("Death") or clip.begins_with("Hit"):
		veut = 0.0
	_w = lerpf(_w, veut, clampf(dt * 8.0, 0.0, 1.0))
	var b0 := Basis(Vector3.RIGHT, deg_to_rad(incl)) * base
	var bs := b0
	if _w > 0.001:
		var main := sq.get_bone_global_pose(os).basis.orthonormalized()
		var cur := (main * b0.y).normalized()
		var cib := CIBLE.normalized()
		var ang := minf(cur.angle_to(cib), deg_to_rad(LIMITE)) * _w
		var axe := cur.cross(cib)
		if axe.length() > 0.0001 and ang > 0.0001:
			var rot := Basis(axe.normalized(), ang)
			bs = main.inverse() * rot * main * b0
	bs = bs.orthonormalized().scaled(Vector3.ONE * ech)
	arme.transform = Transform3D(bs, centre - bs.y.normalized() * grip * ech)
