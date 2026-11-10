# Inspection des 94 props du Fantasy Props MegaKit (données : importées, rien n'est exécuté d'elles).
#   blender.exe -b --python props_quat_inspecter.py -- src=<dossier glTF> sortie=<json>
import bpy, bmesh, sys, os, json, math, glob
args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a)
res = {}
for f in sorted(glob.glob(os.path.join(args["src"], "*.gltf"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    mn = [9e9] * 3; mx = [-9e9] * 3; tris = 0
    mats = {}
    for o in obs:
        me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        mw = o.matrix_world
        bm = bmesh.new(); bm.from_mesh(me); bm.transform(mw)
        uvl = bm.loops.layers.uv.active
        col = bm.loops.layers.float_color.active or bm.loops.layers.color.active
        for v in bm.verts:
            for i in range(3):
                mn[i] = min(mn[i], v.co[i]); mx[i] = max(mx[i], v.co[i])
        for fa in bm.faces:
            nt = len(fa.verts) - 2; tris += nt
            mname = o.material_slots[fa.material_index].material.name if o.material_slots and o.material_slots[fa.material_index].material else "?"
            d = mats.setdefault(mname, {"tris": 0, "aire": 0.0, "aire_uv": 0.0, "col": [0, 0, 0], "ncol": 0})
            d["tris"] += nt; a = fa.calc_area(); d["aire"] += a
            if uvl:
                uv = [l[uvl].uv for l in fa.loops]
                s = 0
                for k in range(1, len(uv) - 1):
                    s += abs((uv[k].x - uv[0].x) * (uv[k + 1].y - uv[0].y) - (uv[k + 1].x - uv[0].x) * (uv[k].y - uv[0].y)) / 2
                d["aire_uv"] += s
            if col:
                for l in fa.loops:
                    c = l[col]
                    for i in range(3): d["col"][i] += c[i]
                    d["ncol"] += 1
        bm.free()
    for m, d in mats.items():
        if d["ncol"]:
            d["col"] = [round(x / d["ncol"], 3) for x in d["col"]]
        d["texels_m_2048"] = round(math.sqrt(d["aire_uv"] / d["aire"]) * 2048, 1) if d["aire"] > 0 else 0
        del d["ncol"]
    res[os.path.basename(f)[:-5]] = {"dim": [round(mx[i] - mn[i], 3) for i in range(3)], "min": [round(x, 3) for x in mn], "tris": tris, "objets": len(obs), "mats": mats}
json.dump(res, open(args["sortie"], "w"), indent=1)
print("INSPECTION", len(res))
