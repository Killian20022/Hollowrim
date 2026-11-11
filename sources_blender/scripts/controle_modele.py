# Contrôle de maillage d'un modèle (complément Blender de outils/controle_modele.gd, docs/CONTROLE_MODELE.md) :
# composantes connexes (sommets soudés à --soudure m), éclats de moins de --eclat faces avec leur position, arêtes ouvertes / non-manifold,
# trous (boucles d'arêtes ouvertes de périmètre < --trou m). INVENTAIRE NON BLOQUANT : les modèles validés ont eux aussi des éclats (tête, tabard, capuchons de doigts) ; le verdict
# OK / ECHEC est celui de l'outil Godot (zone poignet, bras, arme). Ce script sert à localiser et lister.
#   blender.exe -b --python controle_modele.py -- --glb=<modele.glb> [--eclat=12] [--soudure=0.0005] [--trou=0.03] [--json=<rapport.json>]
# Repère affiché : celui de Godot (x = x, y = z Blender, z = -y Blender). Code de sortie : 0 (1 seulement avec --strict, si un éclat ou petit trou existe).
import bpy, bmesh, sys, json, math
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
GLB = arg("glb")
ECLAT = int(arg("eclat", "12"))
SOUDURE = float(arg("soudure", "0.0005"))
TROU = float(arg("trou", "0.03"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
bm = bmesh.new()
for o in bpy.data.objects:
    if o.type == "MESH":
        tmp = bmesh.new(); tmp.from_mesh(o.data); bmesh.ops.transform(tmp, matrix=o.matrix_world, verts=tmp.verts)
        me = bpy.data.meshes.new("t"); tmp.to_mesh(me); tmp.free(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=SOUDURE)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table(); bm.edges.ensure_lookup_table()
def godot(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]
# composantes (parcours par faces)
vu = set(); comps = []
for f0 in bm.faces:
    if f0.index in vu: continue
    pile = [f0]; vu.add(f0.index); faces = []
    while pile:
        f = pile.pop(); faces.append(f)
        for e in f.edges:
            for g in e.link_faces:
                if g.index not in vu:
                    vu.add(g.index); pile.append(g)
    c = sum((f.calc_center_median() for f in faces), type(faces[0].calc_center_median())()) / len(faces)
    comps.append({"faces": len(faces), "centre": godot(c)})
comps.sort(key=lambda c: c["faces"])
eclats = [c for c in comps if c["faces"] < ECLAT]
ouvertes = [e for e in bm.edges if len(e.link_faces) == 1]
non_manifold = [e for e in bm.edges if len(e.link_faces) > 2]
# boucles d'arêtes ouvertes
vv = {}
for e in ouvertes:
    for v in e.verts: vv.setdefault(v.index, []).append(e)
vus = set(); trous = []; boucles = 0
for e0 in ouvertes:
    if e0.index in vus: continue
    pile = [e0]; vus.add(e0.index); per = 0.0; pts = []
    while pile:
        e = pile.pop(); per += e.calc_length(); pts.append((e.verts[0].co + e.verts[1].co) / 2)
        for v in e.verts:
            for g in vv[v.index]:
                if g.index not in vus: vus.add(g.index); pile.append(g)
    boucles += 1
    if per < TROU: trous.append({"perimetre": round(per, 3), "centre": godot(sum(pts, pts[0] * 0) / len(pts))})
rap = {"modele": GLB, "triangles": sum(len(f.verts) - 2 for f in bm.faces), "composantes": len(comps), "eclats": eclats,
       "aretes_ouvertes": len(ouvertes), "boucles_ouvertes": boucles, "petits_trous": trous, "aretes_non_manifold": len(non_manifold)}
rap["ok"] = not eclats and not trous
print("composantes %d, éclats (< %d faces) : %d, boucles ouvertes %d dont %d petits trous, non-manifold %d" % (len(comps), ECLAT, len(eclats), boucles, len(trous), len(non_manifold)))
for c in eclats: print("   éclat %d faces en %s" % (c["faces"], c["centre"]))
print(("INVENTAIRE sans éclat ni petit trou " if rap["ok"] else "INVENTAIRE %d éclats, %d petits trous (non bloquant, verdict = outil Godot) " % (len(eclats), len(trous))) + GLB)
if arg("json"): open(arg("json"), "w").write(json.dumps(rap, indent=1))
sys.exit(1 if ("--strict" in ARGS and not rap["ok"]) else 0)
