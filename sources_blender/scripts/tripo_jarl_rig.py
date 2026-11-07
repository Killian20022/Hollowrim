# Jarl Tripo animé : retouche du dos de la texture, habillage du squelette nordique (65 os de homme_vetu.glb) + 3 chaînes d'os de cape,
# export assets/pnj/tripo_jarl_rig.glb.   blender.exe -b --python tripo_jarl_rig.py -- [--sortie=<dossier>] [--blend=<fichier.blend de contrôle>]
# Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut. Le jarl source est en pose A (bras ~18° du corps), le squelette
# des humains en T : les poids sont calculés en pose A, puis le maillage est « cuit » en T (modificateur appliqué avec les bras relevés) :
# au repos Godot le jarl est en T comme tous les humains, et les clips Humain.bibliotheque() le replient correctement.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, kdtree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_BLEND = os.path.join(BASE, "sources_blender", "tripo", "jarl_tripo.blend")
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = os.path.join(BASE, "assets", "pnj", "tripo_jarl_rig.glb")
OUT_TEX = os.path.join(BASE, "sources_blender", "tripo", "jarl_512_dos.png")
ANG = math.radians(72.0)        # relèvement des bras de la pose A du jarl vers le T du squelette
DECAL_JAMBES = 0.034            # les cuisses du jarl (armure) sont plus écartées que celles du squelette
J = [1.40, 1.10, 0.80, 0.50, 0.20]            # hauteurs des articulations de chaque chaîne de cape (4 os)
XC = {"l": 0.20, "c": 0.0, "r": -0.20}

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- 0. scène
bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)
for n in ("jarl_src", "jarl_low_v1"):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])
jarl = bpy.data.objects["jarl_low"]
me = jarl.data
nv = len(me.vertices)
P = np.array([v.co[:] for v in me.vertices])

# ---------------------------------------------------------------- 1. texture (retouchée plus bas, une fois la cape repérée)
im = bpy.data.images["jarl_512"]
W, H = im.size
px = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
orig = px.copy()
uv = me.uv_layers["bake"].data

# ---------------------------------------------------------------- 2. squelette : humain en T -> pose A
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != jarl:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)

def arms(angle):
    bpy.ops.object.mode_set(mode="POSE")
    for s, sg in (("l", 1), ("r", -1)):
        pb = arm.pose.bones["upperarm_" + s]
        h = arm.matrix_world @ pb.head
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(sg * angle, 4, "Y") @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()
    bpy.ops.pose.armature_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
arms(ANG)

# jambes plus écartées (translation seule : l'orientation des os, donc les clips, ne change pas)
bpy.ops.object.mode_set(mode="EDIT")
for s, sg in (("l", 1), ("r", -1)):
    for nom in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        eb = arm.data.edit_bones[nom + "_" + s]
        eb.head.x += sg * DECAL_JAMBES
        eb.tail.x += sg * DECAL_JAMBES
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm.data.bones:
    n = b.name
    b.use_deform = not (n == "root" or n.endswith("_leaf_l") or n.endswith("_leaf_r") or
                        any(n.startswith(f) for f in ("index_", "middle_", "pinky_", "ring_", "thumb_")))

# ---------------------------------------------------------------- 3. poids du corps (auto, sur une copie soudée : le maillage est découpé par îlots UV)
cp_me = me.copy()
cp = bpy.data.objects.new("jarl_soude", cp_me)
bpy.context.scene.collection.objects.link(cp)
bm = bmesh.new()
bm.from_mesh(cp_me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
bm.to_mesh(cp_me)
bm.free()
print("soudé :", len(cp_me.vertices), "sommets (", nv, "avant )")
for o in bpy.context.selected_objects:
    o.select_set(False)
cp.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
gn = {g.index: g.name for g in cp.vertex_groups}
kd = kdtree.KDTree(len(cp_me.vertices))
for v in cp_me.vertices:
    kd.insert(v.co, v.index)
kd.balance()
body = []
for i in range(nv):
    _, j, _ = kd.find(Vector(P[i]))
    body.append({gn[g.group]: g.weight for g in cp_me.vertices[j].groups if g.weight > 1e-4})
print("poids auto : sommets sans poids :", sum(1 for w in body if not w))
bpy.data.objects.remove(cp)

# ---------------------------------------------------------------- 4. manteau : classe (rouge lissé dans l'espace), os de cape, poids
col = np.zeros((nv, 3)); cnt = np.zeros(nv)
for p in me.polygons:
    for li in p.loop_indices:
        v = me.loops[li].vertex_index
        u = uv[li].uv
        col[v] += orig[min(H - 1, int(u.y * H)), min(W - 1, int(u.x * W)), :3]
        cnt[v] += 1
col /= np.maximum(cnt, 1)[:, None]
rouge_v = ((col[:, 0] > col[:, 1] * 1.3) & (col[:, 0] > col[:, 2] * 1.3) & (col[:, 0] > 0.04)).astype(float)
x, y, z = P[:, 0], P[:, 1], P[:, 2]
c0 = rouge_v * (((y > 0.0) | (np.abs(x) > 0.22)).astype(float))
kd2 = kdtree.KDTree(nv)
for i in range(nv):
    kd2.insert(Vector(P[i]), i)
kd2.balance()
cs = np.zeros(nv)
for i in range(nv):
    pts = kd2.find_range(Vector(P[i]), 0.075)
    cs[i] = sum(c0[j] for _, j, _ in pts) / len(pts)
c = sstep(0.30, 0.60, cs) * np.clip((1.40 - z) / 0.10, 0.0, 1.0)
print("cape : sommets (c>0.5) :", int((c > 0.5).sum()))


# ---------------------------------------------------------------- 4b. texture : le dos du manteau était presque noir (le rouge ne se lisait pas)
c_poly = lambda p: float(np.mean([c[me.loops[li].vertex_index] for li in p.loop_indices]))
masque = np.zeros((H, W), dtype=np.float32)
for p in me.polygons:
    ny = p.normal.y
    if c_poly(p) < 0.5 or p.center.z > 1.36:
        continue                      # col de fourrure, tête, armure : intacts
    niv = 1.0 if ny >= 0.55 else 0.66 if ny >= 0.35 else 0.33 if ny >= 0.20 else 0.0   # 3 paliers : pas de dégradé lisse (rendu PS1)
    if niv == 0.0:
        continue
    if p.center.z > 1.30:
        niv *= 0.5                    # au bord du col : transition
    pts = [np.array([uv[li].uv.x * W, uv[li].uv.y * H]) for li in p.loop_indices]
    for k in range(1, len(pts) - 1):
        a, b, c3 = pts[0], pts[k], pts[k + 1]
        x0, x1 = int(max(0, math.floor(min(a[0], b[0], c3[0]) - 1))), int(min(W - 1, math.ceil(max(a[0], b[0], c3[0]) + 1)))
        y0, y1 = int(max(0, math.floor(min(a[1], b[1], c3[1]) - 1))), int(min(H - 1, math.ceil(max(a[1], b[1], c3[1]) + 1)))
        d = (b[1] - c3[1]) * (a[0] - c3[0]) + (c3[0] - b[0]) * (a[1] - c3[1])
        if abs(d) < 1e-9:
            continue
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                qx, qy = xx + 0.5, yy + 0.5
                l1 = ((b[1] - c3[1]) * (qx - c3[0]) + (c3[0] - b[0]) * (qy - c3[1])) / d
                l2 = ((c3[1] - a[1]) * (qx - c3[0]) + (a[0] - c3[0]) * (qy - c3[1])) / d
                if min(l1, l2, 1 - l1 - l2) > -0.12:
                    masque[yy, xx] = max(masque[yy, xx], niv)
rgb = orig[:, :, :3]
lum = rgb[:, :, 0] * 0.3 + rgb[:, :, 1] * 0.59 + rgb[:, :, 2] * 0.11
rouge = (rgb[:, :, 0] > rgb[:, :, 1] * 1.2) & (rgb[:, :, 0] > rgb[:, :, 2] * 1.2) & (rgb[:, :, 0] > 0.03)      # teinte rouge (ni armure grise, ni bleus)
t = sstep(0.26, 0.12, lum) * rouge                      # étoffe sombre : on la rougit ; galons clairs : juste un peu plus de lumière, teinte gardée
m = masque * rouge
gain = np.array([2.3, 1.4, 1.4], dtype=np.float32)
g_tot = 1 + (m * t)[:, :, None] * (gain - 1) + (m * (1 - t))[:, :, None] * 0.45
px[:, :, :3] = np.clip(rgb * g_tot + (m * t)[:, :, None] * np.array([0.05, 0.0, 0.0], dtype=np.float32), 0, 1)
im.pixels.foreach_set(px.ravel())
im.update()
im.filepath_raw = OUT_TEX
im.file_format = "PNG"
im.save()
im2 = bpy.data.images.load(OUT_TEX)      # l'export lit les octets EMPAQUETÉS : on recharge la retouche et on la remet dans le matériau
im2.pack()
for mat in bpy.data.materials:
    if mat.use_nodes:
        for nd in mat.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image == im:
                nd.image = im2
print("TEXTURE texels éclaircis :", int((m > 0).sum()))

# profondeur du dos de la cape à chaque hauteur (pour placer les os dans l'épaisseur)
def y_dos(zz):
    sel = (c > 0.6) & (np.abs(z - zz) < 0.08) & (np.abs(x) < 0.12)
    return float(np.max(y[sel])) - 0.03 if sel.any() else 0.14
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
cape_os = []
for s in ("l", "c", "r"):
    parent = arm.data.edit_bones["spine_03"]
    for k in range(4):
        eb = arm.data.edit_bones.new("cape_%s_%d" % (s, k + 1))
        eb.head = Vector((XC[s], y_dos(J[k]), J[k]))
        eb.tail = Vector((XC[s], y_dos(J[k + 1]), J[k + 1]))
        eb.parent = parent
        eb.use_connect = False
        eb.use_deform = True
        parent = eb
        cape_os.append(eb.name)
bpy.ops.object.mode_set(mode="OBJECT")

zc_ = [(J[k] + J[k + 1]) / 2 for k in range(4)]
def poids_cape(i):
    xi, zi = x[i], z[i]
    lat = {"l": float(np.clip(xi / XC["l"], 0, 1)), "r": float(np.clip(-xi / XC["l"], 0, 1))}
    lat["c"] = max(0.0, 1.0 - lat["l"] - lat["r"]) if abs(xi) < XC["l"] else 0.0
    # hauteur : tente entre centres de segments
    vz = [0.0] * 4
    if zi >= zc_[0]:
        vz[0] = 1.0
    elif zi <= zc_[3]:
        vz[3] = 1.0
    else:
        for k in range(3):
            if zc_[k + 1] <= zi <= zc_[k]:
                t = (zi - zc_[k + 1]) / (zc_[k] - zc_[k + 1])
                vz[k], vz[k + 1] = t, 1 - t
                break
    w = {}
    for s in "lcr":
        for k in range(4):
            if lat[s] * vz[k] > 1e-4:
                w["cape_%s_%d" % (s, k + 1)] = lat[s] * vz[k]
    return w

def poids_jambe(i):
    # un peu de la cape suit les jambes (elle ne les traverse pas en marche)
    xi, zi = x[i], z[i]
    quant = 0.14 * float(sstep(1.00, 0.70, zi)) * float(1.0 - sstep(0.12, 0.28, abs(xi)))      # seulement derrière les jambes, pas sur les pans latéraux
    if quant <= 0:
        return {}, 0.0
    side = {"l": float(sstep(-0.04, 0.04, xi))}
    side["r"] = 1.0 - side["l"]
    bas = float(sstep(0.62, 0.48, zi))
    out = {}
    for s in "lr":
        out["thigh_" + s] = side[s] * (1 - bas)
        out["calf_" + s] = side[s] * bas
    return out, quant

final = []
for i in range(nv):
    ci = float(c[i])
    w = {}
    if ci < 0.999:
        for n_, v_ in body[i].items():
            w[n_] = w.get(n_, 0.0) + v_ * (1 - ci)
    if ci > 0.001:
        wc = poids_cape(i)
        wj, q = poids_jambe(i)
        for n_, v_ in wc.items():
            w[n_] = w.get(n_, 0.0) + v_ * ci * (1 - q)
        for n_, v_ in wj.items():
            w[n_] = w.get(n_, 0.0) + v_ * ci * q
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(v for _, v in top) or 1.0
    final.append([(n_, v / tot) for n_, v in top if v / tot > 0.015])

for g in list(jarl.vertex_groups):
    jarl.vertex_groups.remove(g)
groupes = {}
for i, lst in enumerate(final):
    for n_, v_ in lst:
        if n_ not in groupes:
            groupes[n_] = jarl.vertex_groups.new(name=n_)
        groupes[n_].add([i], v_, "REPLACE")
print("groupes :", len(groupes), "dont cape :", sum(1 for n_ in groupes if n_.startswith("cape_")))
jarl.parent = arm
jarl.matrix_parent_inverse = Matrix.Identity(4)
for md in list(jarl.modifiers):
    jarl.modifiers.remove(md)
md = jarl.modifiers.new("Armature", "ARMATURE")
md.object = arm

if arg("blend_a"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("blend_a"))

# ---------------------------------------------------------------- 5. cuisson en T (clips des humains) puis export
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    pb = arm.pose.bones["upperarm_" + s]
    h = arm.matrix_world @ pb.head
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(-sg * ANG, 4, "Y") @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
for o in bpy.context.selected_objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = jarl
jarl.select_set(True)
bpy.ops.object.modifier_apply(modifier="Armature")
md = jarl.modifiers.new("Armature", "ARMATURE")
md.object = arm
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
jarl.name = "tripo_jarl"
arm.name = "Armature"

if arg("blend"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("blend"))
out = arg("sortie", OUT_GLB)
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
jarl.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_skins=True, export_animations=False, export_apply=False)
print("EXPORT OK", out, "tris", len(me.polygons), "os", len(arm.data.bones))
