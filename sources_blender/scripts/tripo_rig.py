# Gardes Tripo animés : habillage du squelette nordique (65 os de homme_vetu.glb) + tabard à chaînes d'os, arme rigide sur la main/le dos.
#   blender.exe -b --python tripo_rig.py -- --modele=garde_lance|garde_epee|archer [--sortie=<glb>] [--debug=<dossier de rendus>] [--blend=<ctl.blend>]
# Entrée : assets/pnj/tripo_<modele>.glb (6 000 tris, texture 512 empaquetée, pose A, pieds à z=0, face -Y). Sortie : assets/pnj/tripo_<modele>_rig.glb.
# Même méthode que tripo_jarl_rig.py : poids auto sur une copie soudée, pose A -> T cuite dans le maillage, mêmes poses de repos que les humains
# (les clips Humain.bibliotheque() s'appliquent tels quels). Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut.
# Différences avec le jarl : pas de cape mais un tabard (chaîne de 3 os devant « tab_f_* », une derrière « tab_b_* », parent pelvis) ; l'ARME est
# rigide (100 % main droite pour la lance et l'épée, 100 % spine_03 pour l'arc et le carquois) ; pas de retouche de texture.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, kdtree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELE = arg("modele", "garde_lance")
SRC = os.path.join(BASE, "assets", "pnj", "tripo_%s.glb" % MODELE)
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "pnj", "tripo_%s_rig.glb" % MODELE))

# Position approximative de chaque main dans le maillage en pose A (mesurée sur les vues de face / profil) : sert à orienter les os des bras.
CONF = {
    "garde_lance": dict(mains={"r": (-0.33, -0.255, 1.20), "l": (0.345, -0.03, 0.85)}),
    "garde_epee": dict(mains={"r": (-0.264, -0.03, 0.85), "l": (0.264, -0.03, 0.85)}, retirer=True),
    "archer": dict(mains={"r": (-0.32, -0.03, 0.87), "l": (0.285, -0.03, 0.87)}, rogner_z=1.93, rouge=1.5, zmin=0.52, retirer=True),
}[MODELE]
J = [1.02, 0.80, 0.62, 0.44]        # articulations du tabard (3 os) ; la hauteur est ramenée à celle du bord inférieur du tissu

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
    if MODELE == "garde_lance":
        rig = np.hypot(x + 0.33, y + 0.255) < 0.065            # hampe verticale tenue à droite (fût, fer et poing)
    elif MODELE == "garde_epee":
        epee = (dist_segment((-0.28, -0.02, 0.95), (-0.40, -0.34, 0.10)) < (0.18 if "retirer" in CONF else 0.05)) & (z < 0.95) & (x < -0.28)
        if "retirer" in CONF:
            retire = epee & (z < 0.84)       # lame et garde ; le poing (gant) reste
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
    if MODELE == "garde_epee":      # avant-bras + main droits (maillage Tripo déformé, main en griffes) remplacés par le symétrique du gauche, depuis le coude
        ZC, ZB, XM = 1.05, 0.80, 0.235
        bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
        # anneau du coude (z 1.03..1.07) : centre des deux côtés pour recaler le miroir en y
        def anneau(sg): 
            q = [v.co for v in bm.verts if sg * v.co.x > XM and 1.03 <= v.co.z <= 1.07]
            return np.array([[c.x, c.y, c.z] for c in q]).mean(axis=0)
        al, ar = anneau(1), anneau(-1)
        dy = ar[1] - al[1]; dx = ar[0] + al[0]      # le miroir place l'anneau à -al.x ; recalé sur l'anneau droit
        print("COUDE : gauche", al, "droit", ar, "dy", dy)
        droit = [v for v in bm.verts if v.co.x < -XM and ZB <= v.co.z < ZC]
        bmesh.ops.delete(bm, geom=droit, context="VERTS")
        bm.verts.ensure_lookup_table()
        gv = set(v for v in bm.verts if v.co.x > XM and ZB <= v.co.z < ZC)
        gf = [f for f in bm.faces if all(v in gv for v in f.verts)]
        dup = bmesh.ops.duplicate(bm, geom=gf)["geom"]
        nvs = [e for e in dup if isinstance(e, bmesh.types.BMVert)]
        nfs = [e for e in dup if isinstance(e, bmesh.types.BMFace)]
        for v in nvs:
            v.co.x = -v.co.x + dx
            v.co.y += dy
        bmesh.ops.reverse_faces(bm, faces=nfs)
        hl = np.array([[v.co.x, v.co.y, v.co.z] for v in gv if v.co.z < 0.93]).mean(axis=0)
        CONF["mains"]["r"] = (-hl[0] + dx, hl[1] + dy, hl[2])
        print("BRAS DROIT SYMETRISE : %d sommets supprimes, %d faces copiees ; main droite cible" % (len(droit), len(nfs)), CONF["mains"]["r"])
        # éclats isolés laissés par le retrait de l'épée (petits îlots soudés par position, côté droit, sous la poitrine) : supprimés
        pos = {v.index: (round(v.co.x / 0.003), round(v.co.y / 0.003), round(v.co.z / 0.003)) for v in bm.verts}
        par = {}
        def rac(k):
            while par.setdefault(k, k) != k:
                par[k] = par[par[k]]; k = par[k]
            return k
        for f in bm.faces:
            ks = [pos[v.index] for v in f.verts]
            for k in ks[1:]:
                par[rac(k)] = rac(ks[0])
        comp = {}
        for v in bm.verts:
            comp.setdefault(rac(pos[v.index]), []).append(v)
        eclats = [v for vs in comp.values() if len(vs) < 100 and np.mean([w.co.x for w in vs]) < -0.15 and np.mean([w.co.z for w in vs]) < 1.2 for v in vs]
        bmesh.ops.delete(bm, geom=eclats, context="VERTS")
        print("ÉCLATS SUPPRIMÉS :", len(eclats))
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
    return (abs(float(cuisse[:, 0].mean())) + abs(float(botte[:, 0].mean()))) / 2.0
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
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
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

# ---------------------------------------------------------------- 4. tabard : classe (rouge lissé dans l'espace), chaînes d'os, poids
rr = CONF.get("rouge", 1.3)       # le cuir brun de l'archer ressemble au rouge : seuil plus strict
rouge_v = ((col[:, 0] > col[:, 1] * rr) & (col[:, 0] > col[:, 2] * rr) & (col[:, 0] > 0.04)).astype(float)
c0 = rouge_v * ((z < 1.15) & (z > CONF.get("zmin", 0.30)) & (np.abs(x) < 0.34)).astype(float)
kd2 = kdtree.KDTree(nv)
for i in range(nv):
    kd2.insert(Vector(P[i]), i)
kd2.balance()
cs = np.zeros(nv)
for i in range(nv):
    pts = kd2.find_range(Vector(P[i]), 0.10)
    cs[i] = sum(c0[j] for _, j, _ in pts) / len(pts)
c = sstep(0.20, 0.45, cs) * np.clip((J[0] + 0.05 - z) / 0.06, 0.0, 1.0) * (~arme)
print("tabard : sommets (c>0.5) :", int((c > 0.5).sum()))
sel = c > 0.6
zbas = float(z[sel].min()) if sel.any() else J[-1]
J[-1] = max(zbas + 0.03, 0.30)
J = [J[0]] + [J[0] + (J[-1] - J[0]) * k / 3.0 for k in (1, 2, 3)]
print("articulations du tabard :", [round(v, 2) for v in J])

def y_pan(zz, face):
    s = (c > 0.6) & (np.abs(z - zz) < 0.08) & (np.abs(x) < 0.15) & ((y < 0) if face else (y > 0))
    if not s.any():
        return -0.18 if face else 0.18
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
    dos = float(sstep(-0.06, 0.06, y[i]))       # flancs : mélange devant / derrière
    w = {}
    for k in range(3):
        if vz[k] * (1 - dos) > 1e-4: w["tab_f_%d" % (k + 1)] = vz[k] * (1 - dos)
        if vz[k] * dos > 1e-4: w["tab_b_%d" % (k + 1)] = vz[k] * dos
    return w

def poids_jambe(i):      # un peu du tabard suit les jambes (il ne les traverse pas en marche)
    xi, zi = x[i], z[i]
    quant = 0.12 * float(sstep(0.95, 0.65, zi)) * float(1.0 - sstep(0.16, 0.30, abs(xi)))
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
