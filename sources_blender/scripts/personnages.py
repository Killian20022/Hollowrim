# Lot 4 (graphisme) : UV METRIQUES et PIECES DE SILHOUETTE (personnages_accessoires.py)
# UV METRIQUES des vetements des deux corps (homme_vetu, femme_vetue). L'atlas d'origine (Quaternius) etait
# inexploitable pour des textures dessinees : on projette chaque piece en cylindre (torse, bras, jambes) ou en plan (dessus des
# epaules, pied des bottes) avec u et v en METRES, puis on divise par la taille de la texture a 64 texels/m (PX_M).
#   v = hauteur depuis l'ourlet (torse, jambes) ou distance depuis le poignet (bras) : les bordures brodees de l'ourlet,
#   de la manchette et du col sont donc aux memes lignes de texture sur toute la piece.
#   u = angle x rayon local (couture au milieu du dos / sous le bras) : un tissage garde la meme taille de maille partout.
#   blender.exe -b --python personnages_uv.py -- homme|femme       (ecrit assets/modeles/humains/<corps>.glb ; copie d'origine *_lot1.glb)
import bpy, bmesh, math, os, sys, shutil
base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
corps = sys.argv[sys.argv.index("--") + 1]
nom_glb = {"homme": "homme_vetu", "femme": "femme_vetue"}[corps]
glb = os.path.join(base, "assets", "modeles", "humains", nom_glb + ".glb")
sauve = os.path.join(base, "sources_blender", nom_glb + "_lot1.glb")
if not os.path.exists(sauve):
    shutil.copy(glb, sauve)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sauve)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
obj = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
PX_M = 64.0
# [largeur px, hauteur px] de chaque texture (voir scripts/personnages_textures.gd : memes valeurs)
TAILLE = {"tunique": (128, 64), "pantalon": (128, 64), "bottes": (64, 64), "ceinture": (128, 16), "mante": (128, 64),
          "brassards": (64, 32), "gants": (64, 32)}
YC, ZC = 0.065, 1.456

def centre_tranches(me, filtre, pas=0.05):
    """Centre (x, y) des sommets retenus par tranche de hauteur, interpole : l'axe local du tube."""
    acc = {}
    for v in me.vertices:
        if filtre(v.co):
            k = round(v.co.z / pas)
            a = acc.setdefault(k, [0.0, 0.0, 0])
            a[0] += v.co.x; a[1] += v.co.y; a[2] += 1
    cles = sorted(acc)
    pts = [(k * pas, acc[k][0] / acc[k][2], acc[k][1] / acc[k][2]) for k in cles]
    def f(z):
        if not pts:
            return (0.0, 0.03)
        if z <= pts[0][0]: return (pts[0][1], pts[0][2])
        if z >= pts[-1][0]: return (pts[-1][1], pts[-1][2])
        for i in range(len(pts) - 1):
            if pts[i][0] <= z <= pts[i + 1][0]:
                t = (z - pts[i][0]) / max(pts[i + 1][0] - pts[i][0], 1e-6)
                return (pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t, pts[i][2] + (pts[i + 1][2] - pts[i][2]) * t)
    return f

def uv_piece(nom):
    o = obj[nom]; me = o.data
    W, H = TAILLE[nom]
    su, sv = PX_M / W, PX_M / H           # metres -> uv
    bm = bmesh.new(); bm.from_mesh(me)
    layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bras = nom in ("brassards", "gants")
    def est_bras(c):
        return bras or (nom in ("tunique",) and abs(c.x) > 0.23 and c.z > 1.25)
    def est_jambe(c):
        return nom in ("pantalon", "bottes") and c.z < (0.95 if nom == "pantalon" else 9)
    verts = [v.co.copy() for v in bm.verts]
    zmin_t = min([c.z for c in verts if not est_bras(c)] or [0.0])
    zmin_j = {s: min([c.z for c in verts if est_jambe(c) and (c.x > 0) == (s > 0)] or [0.0]) for s in (1, -1)}
    axe_t = centre_tranches(me, lambda c: not est_bras(c) and not est_jambe(c))
    axe_j = {s: centre_tranches(me, lambda c, s=s: est_jambe(c) and (c.x > 0) == (s > 0)) for s in (1, -1)}
    xcuff = {s: max([abs(c.x) for c in verts if (c.x > 0) == (s > 0)] or [0.6]) for s in (1, -1)}
    for f in bm.faces:
        c = f.calc_center_median()
        s = 1 if c.x > 0 else -1
        n = f.normal
        if est_bras(c):
            reg = "bras"
        elif est_jambe(c):
            reg = "jambe"
        else:
            reg = "torse"
        plan = reg != "bras" and abs(n.z) > 0.72 and (c.z > 1.2 or c.z < 0.12)
        th = []
        for l in f.loops:
            p = l.vert.co
            if plan:
                u, v = p.x, -p.y + 0.3
                th.append((u, v))
                continue
            if reg == "bras":
                ang = math.atan2(p.y - YC, p.z - ZC)
                r = max(math.hypot(p.y - YC, p.z - ZC), 0.02)
                th.append((ang, r, abs(p.x)))
            else:
                ax, ay = (axe_j[s] if reg == "jambe" else axe_t)(p.z)
                ang = math.atan2(p.x - ax, -(p.y - ay))
                r = max(math.hypot(p.x - ax, p.y - ay), 0.03)
                th.append((ang, r, p.z))
        if plan:
            for l, (u, v) in zip(f.loops, th):
                l[layer].uv = (u * su, v * sv)
            continue
        a0 = th[0][0]
        for l, t in zip(f.loops, th):
            ang = t[0]
            while ang - a0 > math.pi: ang -= 2 * math.pi
            while ang - a0 < -math.pi: ang += 2 * math.pi
            r = t[1]
            if reg == "bras":
                u = ang * r + (0.0)
                v = xcuff[s] - t[2]
            elif reg == "jambe":
                u = ang * max(r, 0.08)
                v = t[2] - zmin_j[s]
            else:
                u = ang * max(r, 0.10)
                v = t[2] - zmin_t
            l[layer].uv = (u * su, v * sv)
    bm.to_mesh(me); bm.free()

for n in TAILLE:
    if n in obj:
        uv_piece(n)
        print("UV", n)

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "personnages_accessoires.py")).read())

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH', 'ARMATURE'):
        o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=False, export_apply=False)
print("EXPORT OK")
