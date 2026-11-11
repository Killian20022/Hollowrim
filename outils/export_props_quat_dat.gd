extends SceneTree
## Exporte les props TEXTURÉS (pq_*, glb de assets/modeles/props_quat/) en UN fichier binaire lu par FileAccess dans les fils de
## construction (aucun .glb chargé dans un fil) : assets/modeles/props_quat/props_quat.dat. Format « PQD1 » (petit-boutiste) :
##   « PQD1 », u32 nb_props ; par prop : str8 id (pq_*), str8 ancien (q_* qu'il remplace, ou « » ), u8 nb_surfaces ;
##   par surface : str8 atlas (« pq_bois »…), u32 nb_sommets, nb x 12 float32 (position 3, normale 3, UV 2, couleur 4),
##   u32 nb_index, nb x int32 (ordre Godot). str8 = u8 longueur + octets UTF-8.
## Lancer après toute régénération des glb (sources_blender/scripts/props_quaternius.py + outils/props_quat_catalogue.py) :
##   godot --headless --path . --script res://outils/export_props_quat_dat.gd
const SORTIE := "res://assets/modeles/props_quat/props_quat.dat"
## Props sans « ancien » dans le catalogue mais remplaçants d'un q_* virtuel (variante du jeu) : pq -> nom q.
const ANCIENS_EN_PLUS := {"pq_coffre_ferme": "q_coffre_ferme"}

func _str8(f: FileAccess, s: String) -> void:
	var b := s.to_utf8_buffer()
	f.store_8(b.size())
	f.store_buffer(b)

func _init() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/props_quaternius.json"))
	var f := FileAccess.open(SORTIE, FileAccess.WRITE)
	f.store_buffer("PQD1".to_ascii_buffer())
	var props: Array = cat["props"]
	f.store_32(props.size())
	var tris := 0
	for e: Dictionary in props:
		var id: String = e["id"]
		var sc := (load(String(e["fichier"])) as PackedScene).instantiate()
		var mis: Array = sc.find_children("*", "MeshInstance3D", true, false)
		if sc is MeshInstance3D:
			mis = [sc]
		var surfs: Array = []
		for mi: MeshInstance3D in mis:
			var xf := Transform3D.IDENTITY
			var nd: Node = mi
			while nd != sc and nd is Node3D:
				xf = (nd as Node3D).transform * xf
				nd = nd.get_parent()
			var m: Mesh = mi.mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var mat := m.surface_get_material(s)
				var atlas := mat.resource_name if mat != null and mat.resource_name.begins_with("pq_") else "pq_bois"
				surfs.append([atlas, arr, xf])
		var anc := String(e.get("ancien", "")) if e.get("ancien") != null else ""
		anc = ANCIENS_EN_PLUS.get(id, anc)
		_str8(f, id)
		_str8(f, anc)
		f.store_8(surfs.size())
		for su: Array in surfs:
			var arr: Array = su[1]
			var xf: Transform3D = su[2]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var c: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ii.is_empty():
				for k in v.size():
					ii.append(k)
			_str8(f, String(su[0]))
			f.store_32(v.size())
			var fl := PackedFloat32Array()
			fl.resize(v.size() * 12)
			for k in v.size():
				var p := xf * v[k]
				var nn := (xf.basis * (n[k] if k < n.size() else Vector3.UP)).normalized()
				var u := uv[k] if k < uv.size() else Vector2.ZERO
				var cc := c[k] if k < c.size() else Color.WHITE
				var o := k * 12
				fl[o] = p.x; fl[o + 1] = p.y; fl[o + 2] = p.z
				fl[o + 3] = nn.x; fl[o + 4] = nn.y; fl[o + 5] = nn.z
				fl[o + 6] = u.x; fl[o + 7] = u.y
				fl[o + 8] = cc.r; fl[o + 9] = cc.g; fl[o + 10] = cc.b; fl[o + 11] = cc.a
			f.store_buffer(fl.to_byte_array())
			f.store_32(ii.size())
			f.store_buffer(ii.to_byte_array())
			tris += ii.size() / 3
		sc.free()
	f.close()
	print("export_props_quat_dat : %d props, %d triangles -> %s (%d octets)" % [props.size(), tris, SORTIE, FileAccess.get_file_as_bytes(SORTIE).size()])
	quit(0)
