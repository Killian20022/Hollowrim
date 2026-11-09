# Mage Tripo animé : habillage du squelette nordique (65 os de homme_vetu.glb) + JUPE DE ROBE à chaînes d'os (devant « tab_f_* », derrière « tab_b_* »,
# parent pelvis) et poids lissés sur les cuisses (la robe longue suit les jambes sans exploser).
#   blender.exe -b --python tripo_mage_rig.py -- [--sortie=<glb>] [--debug=<dossier de rendus>] [--blend=<ctl.blend>]
# Entrée : assets/pnj/tripo_mage.glb (tripo_mage_prep.py : 3 263 tris, texture 512 empaquetée, pose A, pieds à z=0, face -Y, 1,82 m).
# Sortie : assets/pnj/tripo_mage_rig.glb. Même méthode que tripo_rig.py (gardes) : poids auto sur une copie soudée, pose A -> T cuite dans le maillage,
# mêmes poses de repos que les humains (les clips Humain.bibliotheque() s'appliquent tels quels). Repère Blender : x = gauche du perso, -y = devant, z = haut.
# Différence avec les gardes : la classe « robe » ne vient pas de la couleur mais de la géométrie (z entre l'ourlet et la ceinture, hors bras).
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, kdtree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELE = "mage"
SRC = os.path.join(BASE, "assets", "pnj", "tripo_%s.glb" % MODELE)
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "pnj", "tripo_%s_rig.glb" % MODELE))

# Position approximative de chaque main dans le maillage en pose A (mesurée sur les vues de face / profil) : sert à orienter les os des bras.
# mains mesurées sur le maillage en pose A (centre de la paume gantée) ; robe : ourlet / ceinture (z), centre devant-derrière (y)
CONF = dict(mains={"r": (-0.385, -0.01, 0.90), "l": (0.385, -0.01, 0.90)}, zhem=(0.44, 0.54), zceint=(1.04, 1.14), ycent=0.03)
J = [1.10, 0.90, 0.70, 0.50]        # articulations du tabard (3 os) ; la hauteur est ramenée à celle du bord inférieur du tissu

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- 0. scène
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
garde = next(o for o in bpy.data.objects if o.type == "MESH")
me = garde.data
if "rogner_z" in CONF:      # éclats flottants au-dessus du casque (défaut du modèle généré)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > CONF["rogner_z"]], context="VERTS")
    bm.to_mesh(me); bm.free()
nv = len(me.vertices)
P = np.array([v.co[:] for v in me.vertices])
x, y, z = P[:, 0], P[:, 1], P[:, 2]
print("maillage :", nv, "sommets,", len(me.polygons), "tris")

def dist_segment(a, b):
    a = np.array(a); b = np.array(b); ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

def regions():
    """(arme rigide, os qui la porte, sommets à RETIRER du maillage) pour le maillage courant."""
    n = len(P)
    rig = np.zeros(n, dtype=bool); retire = np.zeros(n, dtype=bool); os_ = "hand_r"
    if MODELE == "mage":
        return rig, os_, retire      # pas d'arme dans le maillage (le bâton du jeu est posé dans Godot)
    if MODELE == "garde_lance":
        rig = np.hypot(x + 0.33, y + 0.255) < 0.065            # hampe verticale tenue à droite (fût, fer et poing)
    elif MODELE == "garde_epee":
        epee = (dist_segment((-0.28, -0.02, 0.95), (-0.40, -0.34, 0.10)) < (0.11 if "retirer" in CONF else 0.05)) & (z < 0.95) & (x < -0.31)
        if "retirer" in CONF:
            retire = epee & (z < 0.82)       # lame et garde ; le poing (gant) reste
        else:
            rig = epee
    else:
        os_ = "spine_03"                                      # arc en bandoulière et carquois dans le dos
        # l'arc (courbe fine) est le seul élément à dépasser de 0.20 derrière le dos : on prend ces sommets et leurs voisins à 3 cm
        loin = [i for i in range(n) if y[i] > 0.20]
        kda = kdtree.KDTree(len(loin))
        for k, i in enumerate(loin):
            kda.insert(Vector(P[i]), k)
        kda.balance()
        arc = np.array([y[i] > 0.10 and len(kda.find_range(Vector(P[i]), 0.06 if "retirer" in CONF else 0.03)) > 0 for i in range(n)])
        if "retirer" in CONF:
            arc |= (np.abs(x) > 0.36) & (z > 0.30) & (z < 0.80) & (y > 0.02)      # bouts bas de l'arc, de part et d'autre des hanches
        carquois = (x > -0.42) & (x < 0.02) & (z > 1.05) & (z < 1.95) & (y > 0.12)
        if "retirer" in CONF:
            retire = arc & ~carquois      # l'arc du jeu (ChasseresseNordique) remplace celui de Tripo ; le carquois reste
            rig = carquois
        else:
            rig = arc | carquois
    return rig, os_, retire

if "retirer" in CONF:       # arme du modèle retirée du maillage (remplacée par l'arme du jeu, posée dans Godot)
    _, _, retire = regions()
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in range(nv) if retire[i]], context="VERTS")
    bm.to_mesh(me); bm.free()
    nv = len(me.vertices)
    P = np.array([v.co[:] for v in me.vertices])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    print("ARME RETIRÉE : %d sommets ; reste %d sommets, %d tris" % (int(retire.sum()), nv, len(me.polygons)))

# couleur (rouge du tabard) échantillonnée dans la texture
im = next(nd.image for m in me.materials for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE")
W, H = im.size
px = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
uv = me.uv_layers[0].data
col = np.zeros((nv, 3)); cnt = np.zeros(nv)
for p in me.polygons:
    for li in p.loop_indices:
        v = me.loops[li].vertex_index
        u = uv[li].uv
        col[v] += px[min(H - 1, int(u.y * H)), min(W - 1, int(u.x * W)), :3]
        cnt[v] += 1
col /= np.maximum(cnt, 1)[:, None]

# ---------------------------------------------------------------- 1. squelette : humain en T -> pose A
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != garde:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)

# rotation de chaque bras : de la direction du T (±x) vers l'épaule -> main mesurée
ROT = {}
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    h = arm.matrix_world @ arm.pose.bones["upperarm_" + s].head
    d = (Vector(CONF["mains"][s]) - h).normalized()
    ROT[s] = Vector((sg, 0, 0)).rotation_difference(d)
    print("bras", s, "angle depuis le T : %.1f deg" % math.degrees(ROT[s].angle))
    q = ROT[s]      # même rotation dans le repère de Godot (x, y, z)gltf = (x, z, -y)blender : sert à figer le bras dans scripts/garde_tripo.gd
    print("ROTGODOT", s, "Quaternion(%.5f, %.5f, %.5f, %.5f)" % (q.x, q.z, -q.y, q.w))
def arms(inverse):
    bpy.ops.object.mode_set(mode="POSE")
    for s in ("l", "r"):
        pb = arm.pose.bones["upperarm_" + s]
        h = arm.matrix_world @ pb.head
        q = ROT[s].inverted() if inverse else ROT[s]
        pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()
    if not inverse:
        bpy.ops.pose.armature_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
arms(False)

# jambes : décalage en x (translation seule, l'orientation des os et donc les clips ne change pas), mesuré sur les cuisses et les bottes
def jambe_x(sg):
    cuisse = P[(z > 0.70) & (z < 0.90) & (sg * x > 0.03) & (np.abs(x) < 0.30) & (y > -0.12) & (y < 0.12)]
    botte = P[(z > 0.04) & (z < 0.30) & (sg * x > 0.03) & (np.abs(x) < 0.32) & (y > -0.2) & (y < 0.2)]
    return abs(float(botte[:, 0].mean()))      # mage : la robe recouvre les cuisses, seules les bottes donnent l'écart des jambes
bpy.ops.object.mode_set(mode="EDIT")
for s, sg in (("l", 1), ("r", -1)):
    dx = jambe_x(sg) - 0.114
    print("jambe", s, "décalage x : %.3f" % dx)
    for nom in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        eb = arm.data.edit_bones[nom + "_" + s]
        eb.head.x += sg * dx
        eb.tail.x += sg * dx
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm.data.bones:
    n = b.name
    b.use_deform = not (n == "root" or n.endswith("_leaf_l") or n.endswith("_leaf_r") or
                        any(n.startswith(f) for f in ("index_", "middle_", "pinky_", "ring_", "thumb_")))

# ---------------------------------------------------------------- 2. poids du corps (auto, copie soudée : le maillage est découpé par îlots UV)
cp_me = me.copy()
cp = bpy.data.objects.new("soude", cp_me)
bpy.context.scene.collection.objects.link(cp)
bm = bmesh.new(); bm.from_mesh(cp_me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(arg("soude", "0.012")))
bm.to_mesh(cp_me); bm.free()
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
sans = [i for i in range(nv) if not body[i]]
print("poids auto : sommets sans poids :", len(sans))
if sans:        # éclats isolés (hors de la copie soudée) : ils prennent les poids du sommet pondéré le plus proche
    kdp = kdtree.KDTree(nv - len(sans))
    for i in range(nv):
        if body[i]:
            kdp.insert(Vector(P[i]), i)
    kdp.balance()
    for i in sans:
        body[i] = body[kdp.find(Vector(P[i]))[1]]
bpy.data.objects.remove(cp)

# ---------------------------------------------------------------- 3. arme : région rigide
arme, os_arme, _ = regions()
print("ARME : %d sommets rigides sur %s" % (int(arme.sum()), os_arme))

# ---------------------------------------------------------------- 4. jupe de robe : classe géométrique, chaînes d'os, poids
ARMS = ("clavicle_", "upperarm_", "lowerarm_", "hand_")
def part_bras(i):
    return sum(v for n_, v in body[i].items() if n_.startswith(ARMS))
bras_ = np.array([part_bras(i) for i in range(nv)])
h0, h1 = CONF["zhem"]; c0_, c1_ = CONF["zceint"]
c = sstep(h0, h1, z) * sstep(c1_, c0_, z) * np.clip(1.0 - 1.6 * bras_, 0.0, 1.0) * (np.abs(x) < 0.34)
c = c * (~arme)
print("robe : sommets (c>0.5) :", int((c > 0.5).sum()))
sel = c > 0.6
zbas = float(z[sel].min()) if sel.any() else J[-1]
J[-1] = max(zbas + 0.03, 0.30)
J = [J[0]] + [J[0] + (J[-1] - J[0]) * k / 3.0 for k in (1, 2, 3)]
print("articulations de la robe :", [round(v, 2) for v in J])

YC = CONF["ycent"]
def y_pan(zz, face):
    s = (c > 0.6) & (np.abs(z - zz) < 0.08) & (np.abs(x) < 0.15) & ((y < YC) if face else (y > YC))
    if not s.any():
        return YC - 0.18 if face else YC + 0.18
    return float(y[s].min()) + 0.03 if face else float(y[s].max()) - 0.03
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for tag, face in (("f", True), ("b", False)):
    parent = arm.data.edit_bones["pelvis"]
    for k in range(3):
        eb = arm.data.edit_bones.new("tab_%s_%d" % (tag, k + 1))
        eb.head = Vector((0.0, y_pan(J[k], face), J[k]))
        eb.tail = Vector((0.0, y_pan(J[k + 1], face), J[k + 1]))
        eb.parent = parent
        eb.use_connect = False
        eb.use_deform = True
        parent = eb
bpy.ops.object.mode_set(mode="OBJECT")

zc_ = [(J[k] + J[k + 1]) / 2 for k in range(3)]
def poids_tabard(i):
    zi = z[i]
    vz = [0.0] * 3
    if zi >= zc_[0]:
        vz[0] = 1.0
    elif zi <= zc_[2]:
        vz[2] = 1.0
    else:
        for k in range(2):
            if zc_[k + 1] <= zi <= zc_[k]:
                t = (zi - zc_[k + 1]) / (zc_[k] - zc_[k + 1])
                vz[k], vz[k + 1] = t, 1 - t
                break
    dos = float(sstep(YC - 0.06, YC + 0.06, y[i]))       # flancs : mélange devant / derrière
    w = {}
    for k in range(3):
        if vz[k] * (1 - dos) > 1e-4: w["tab_f_%d" % (k + 1)] = vz[k] * (1 - dos)
        if vz[k] * dos > 1e-4: w["tab_b_%d" % (k + 1)] = vz[k] * dos
    return w

def poids_jambe(i):      # la robe suit les cuisses : poids lissés sur thigh_l / thigh_r (mélange doux au milieu), plus fort vers l'ourlet
    xi, zi = x[i], z[i]
    quant = 0.60 * float(sstep(1.05, 0.62, zi))
    if quant <= 0:
        return {}, 0.0
    l = float(sstep(-0.10, 0.10, xi))
    out = {"thigh_l": l, "thigh_r": 1.0 - l}
    return out, quant

final = []
for i in range(nv):
    if arme[i]:
        final.append([(os_arme, 1.0)])
        continue
    ci = float(c[i])
    w = {}
    if ci < 0.999:
        for n_, v_ in body[i].items():
            w[n_] = w.get(n_, 0.0) + v_ * (1 - ci)
    if ci > 0.001:
        wc = poids_tabard(i)
        wj, q = poids_jambe(i)
        for n_, v_ in wc.items():
            w[n_] = w.get(n_, 0.0) + v_ * ci * (1 - q)
        for n_, v_ in wj.items():
            w[n_] = w.get(n_, 0.0) + v_ * ci * q
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(v for _, v in top) or 1.0
    final.append([(n_, v / tot) for n_, v in top if v / tot > 0.015])

for g in list(garde.vertex_groups):
    garde.vertex_groups.remove(g)
groupes = {}
for i, lst in enumerate(final):
    for n_, v_ in lst:
        if n_ not in groupes:
            groupes[n_] = garde.vertex_groups.new(name=n_)
        groupes[n_].add([i], v_, "REPLACE")
print("groupes :", len(groupes), "dont tabard :", sum(1 for n_ in groupes if n_.startswith("tab_")))
garde.parent = arm
garde.matrix_parent_inverse = Matrix.Identity(4)
for md in list(garde.modifiers):
    garde.modifiers.remove(md)
md = garde.modifiers.new("Armature", "ARMATURE")
md.object = arm

# ---------------------------------------------------------------- 4b. rendu de contrôle (pose A) : os en vert, arme en rouge, tabard devant jaune / derrière bleu
if arg("debug"):
    os.makedirs(arg("debug"), exist_ok=True)
    ca = me.color_attributes.new("dbg", "FLOAT_COLOR", "POINT")
    for i in range(nv):
        ca.data[i].color = (1, 0, 0, 1) if arme[i] else ((0.9, 0.8, 0.1, 1) if (c[i] > 0.5 and y[i] < 0) else (0.2, 0.4, 1, 1) if c[i] > 0.5 else (0.6, 0.6, 0.6, 1))
    cu = bpy.data.curves.new("osdbg", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = 0.01
    for b in arm.pose.bones:
        if b.name.startswith(("index_", "middle_", "pinky_", "ring_", "thumb_")):
            continue
        sp = cu.splines.new("POLY"); sp.points.add(1)
        sp.points[0].co = (*(arm.matrix_world @ b.head), 1); sp.points[1].co = (*(arm.matrix_world @ b.tail), 1)
    ob = bpy.data.objects.new("osdbg", cu); bpy.context.scene.collection.objects.link(ob)
    mt = bpy.data.materials.new("osm"); mt.diffuse_color = (0, 1, 0, 1); cu.materials.append(mt)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "VERTEX"
    sc.render.resolution_x, sc.render.resolution_y = 400, 640
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.2, 0.2, 0.25)
    cam = bpy.data.objects.new("CAMX", bpy.data.cameras.new("CAMX")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.6; sc.camera = cam
    for k, nom in enumerate(("face", "profil", "dos")):
        r = math.radians([0, 90, 180][k])
        cam.location = Vector((0, 0, 1.1)) + Vector((math.sin(r), -math.cos(r), 0)) * 6
        cam.rotation_euler = (Vector((0, 0, 1.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(arg("debug"), nom + ".png")
        bpy.ops.render.render(write_still=True)
    me.color_attributes.remove(ca)
    bpy.data.objects.remove(ob)

# ---------------------------------------------------------------- 5. cuisson en T (clips des humains) puis export
bpy.context.view_layer.objects.active = arm
arms(True)
for o in bpy.context.selected_objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = garde
garde.select_set(True)
bpy.ops.object.modifier_apply(modifier="Armature")
md = garde.modifiers.new("Armature", "ARMATURE")
md.object = arm
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
garde.name = "tripo_" + MODELE
arm.name = "Armature"

if arg("blend"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("blend"))
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
garde.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_skins=True, export_animations=False, export_apply=False)
print("EXPORT OK", OUT_GLB, "tris", len(me.polygons), "os", len(arm.data.bones))
