extends SceneTree
## FilVerrou.lancer en --headless (correctifs/rid_lit) : le stockage factice des maillages de Godot 4.7.2 n'est pas sûr entre fils ;
## une construction lancée par FilVerrou.lancer doit donc s'exécuter EN LIGNE (aucun maillage du fil principal pendant qu'elle tourne)
## et rendre un vrai identifiant de tâche. Avant le correctif, la même charge lancée par WorkerThreadPool.add_task donnait des
## centaines de « Initializing already initialized RID » / « Parameter "m" is null » (sonde : 498 et 530 erreurs sur 2 lancements).

var _echecs := 0
var _dedans := false
var _vu_en_construction := false
var _faits := 0

func _verif(ok: bool, msg: String) -> void:
	print(("OK     " if ok else "ÉCHEC  ") + msg)
	if not ok:
		_echecs += 1

static func _maillage() -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)      # c'est ici que le RID du maillage est alloué
	return m

func _travail() -> void:
	_dedans = true
	_vu_en_construction = FilVerrou.en_construction()
	var garde: Array = []
	for i in 20000:
		garde.append(_maillage())
		if garde.size() > 64:
			garde.pop_front()
	_faits += 1
	_dedans = false

func _initialize() -> void:
	_verif(DisplayServer.get_name() == "headless", "lancé en --headless")
	_verif(not FilVerrou.en_construction(), "hors construction sur le fil principal")
	var taches: Array[int] = []
	for k in 2:
		taches.append(FilVerrou.lancer(_travail, "test_fil_verrou"))
	_verif(_faits == 2 and not _dedans, "les 2 constructions sont faites au retour de lancer (exécutées en ligne)")
	_verif(_vu_en_construction, "FilVerrou.en_construction() vrai pendant la construction en ligne")
	_verif(not FilVerrou.en_construction(), "en_construction() redevient faux après")
	_verif(taches.all(func(t: int) -> bool: return t >= 0), "lancer renvoie de vrais identifiants de tâche %s" % [taches])
	var pendant := 0
	var garde: Array = []
	while taches.any(func(t: int) -> bool: return not WorkerThreadPool.is_task_completed(t)):
		garde.append(_maillage())        # le fil principal crée des maillages tant qu'une tâche « tourne »
		pendant += 1
		if pendant > 2000:
			break
	for t in taches:
		FilVerrou.attendre(t)
	_verif(pendant <= 2000, "les tâches rendues par lancer se terminent (%d maillages du fil principal en attendant)" % pendant)
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(1 if _echecs > 0 else 0)
