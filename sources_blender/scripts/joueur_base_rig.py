# Suite de joueur_base.py (étapes 4 à 6) : exécutée par joueur_base.py (exec, mêmes globales), ou seule sur le .blend de l'étape 3 :
#   blender.exe -b --python joueur_base.py -- --sexe=homme --depuis=3 [--debug=<dossier>]
# 4. classes de sommets -> pièces nommées comme la tenue du héros (peau, cheveux, tunique, pantalon, bottes) ;
# 5. squelette des humains ajusté au corps, poids, pose A -> T cuite ; 6. export.
import colorsys

corps = bpy.data.objects["corps"]
mb = corps.data
ATLAS = next(nd.image for nd in mb.materials[0].node_tree.nodes if nd.type == "TEX_IMAGE")
TEX = ATLAS.size[0]
A = np.array(ATLAS.pixels[:], dtype=np.float32).reshape(TEX, TEX, 4)
H = HAUTEUR
for p in mb.polygons:
    p.use_smooth = True

# ---------------------------------------------------------------------------------------------------- 4. classes
Pb = coords(mb)
nv = len(Pb)
uv = np.empty(len(mb.loops) * 2); mb.uv_layers[0].data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
vi = np.empty(len(mb.loops), dtype=np.int64); mb.loops.foreach_get("vertex_index", vi)
xs = np.clip(uv[:, 0] * TEX, 0, TEX - 1).astype(int); ys = np.clip(uv[:, 1] * TEX, 0, TEX - 1).astype(int)
col = np.zeros((nv, 3)); nn = np.zeros(nv)
np.add.at(col, vi, A[ys, xs, :3]); np.add.at(nn, vi, 1); col /= np.maximum(nn, 1)[:, None]
hsv = np.array([colorsys.rgb_to_hsv(*c) for c in col])
hh, ss, vv = hsv[:, 0], hsv[:, 1], hsv[:, 2]
x, y, z = Pb[:, 0], Pb[:, 1], Pb[:, 2]
zn = z / H
PEAU_V = float(arg("peau_v", "0.40"))
peau_c = (hh < 0.085) & (vv > PEAU_V) & (ss > 0.28)
mains_zone = (zn < 0.62) & (zn > 0.30) & (np.abs(x) > 0.12 * H / 1.75)
yface = float(y[(zn > 0.88) & (zn < 0.96)].min())
face = (zn > 0.86) & (y < yface + 0.045) & (np.abs(x) < 0.058 * H / 1.75) & (zn < 0.965)
barbe = (zn > 0.84) & (zn < 0.925) & (y < yface + 0.07) & (np.abs(x) < 0.07 * H / 1.75)
tete = zn > 0.855
Z_BOT = float(arg("z_bottes", "0.16"))
classe = np.full(nv, "pantalon", dtype=object)
classe[zn >= 0.555] = "tunique"
bande = (zn > 0.49) & (zn < 0.60)
classe[bande & (vv > 0.36)] = "tunique"        # ourlet de la tunique (beige, plus clair que le pantalon)
classe[bande & (vv <= 0.30)] = "pantalon"
classe[zn < Z_BOT] = "bottes"
classe[(zn >= Z_BOT) & (zn < Z_BOT + 0.03) & (vv > 0.30)] = "bottes"     # revers des bottes
classe[tete] = "cheveux"
classe[tete & (peau_c | face | barbe)] = "peau"
classe[(zn > 0.78) & (zn <= 0.885) & ~peau_c & ~barbe & ~face & ~((y > 0.0) & (zn > 0.86))] = "tunique"   # col de la tunique (devant et côtés)
classe[(zn > 0.78) & (zn <= 0.855) & peau_c] = "peau"                     # cou, encolure
classe[mains_zone & peau_c] = "peau"
for c_ in ("peau", "cheveux", "tunique", "pantalon", "bottes"):
    log("classe %-9s : %5d sommets" % (c_, int((classe == c_).sum())))

# classe par face : majorité, puis lissage (une face isolée prend la classe de ses voisines)
mb.calc_loop_triangles()
NOMS = ["peau", "cheveux", "tunique", "pantalon", "bottes"]
fcl = np.zeros(len(mb.polygons), dtype=int)
for p in mb.polygons:
    vs = [classe[i] for i in p.vertices]
    fcl[p.index] = NOMS.index(max(set(vs), key=vs.count))
bm = bmesh.new(); bm.from_mesh(mb); bm.faces.ensure_lookup_table()
for _ in range(3):
    nouv = fcl.copy()
    for f in bm.faces:
        vois = [fcl[g.index] for e in f.edges for g in e.link_faces if g != f]
        if vois and vois.count(fcl[f.index]) == 0:
            nouv[f.index] = max(set(vois), key=vois.count)
    fcl = nouv
bm.free()

# ---------------------------------------------------------------------------------------------------- 5. squelette
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != corps:
        bpy.data.objects.remove(o)
for o in list(bpy.data.objects):
    if o.type == "EMPTY" or (o.type not in ("MESH", "ARMATURE")):
        bpy.data.objects.remove(o)
k = H / HQ
sel_seul(arm)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for b in eb:
    b.head = b.head * k
    b.tail = b.tail * k
# mesures sur le maillage (pose A)
def centre(m):
    return Pb[m].mean(0) if m.any() else None
MES = {}
for s, sg in (("l", 1), ("r", -1)):
    main = peau_c & mains_zone & (sg * x > 0)
    # la main = peau autour du bout des doigts (point de peau le plus bas) : un faux positif de couleur ailleurs (ceinture, ourlet) ne
    # déplace pas le poignet
    bout0 = Pb[main][np.argmin(z[main])]
    main = main & (np.linalg.norm(Pb - bout0, axis=1) < 0.24 * H / 1.75)
    zt = z[main].max()
    poignet = centre(main & (z > zt - 0.025))
    bout = Pb[main][np.argmin(z[main])]
    epaule = Vector(eb["upperarm_" + s].head)
    MES[s] = dict(poignet=Vector(poignet), bout=Vector(bout), epaule=epaule)
    # jambes : x moyen des cuisses et des bottes
    cuisse = (zn > 0.40) & (zn < 0.50) & (sg * x > 0.03) & (np.abs(x) < 0.17) & ~peau_c
    botte = (zn > 0.03) & (zn < 0.14) & (sg * x > 0.03)
    MES[s]["jambe_x"] = (abs(float(x[cuisse].mean())) + abs(float(x[botte].mean()))) / 2.0
    log("mesures %s : poignet %s bout %s épaule %s jambe x %.3f" % (s, tuple(round(v, 3) for v in poignet), tuple(round(v, 3) for v in bout),
                                                              tuple(round(v, 3) for v in epaule), MES[s]["jambe_x"]))
LQ = {"up": 0.251, "lo": 0.243, "main": 0.244}       # longueurs des humains (bras, avant-bras, poignet -> bout du majeur)
for s, sg in (("l", 1), ("r", -1)):
    m = MES[s]
    L = (m["poignet"] - m["epaule"]).length
    l1 = L * LQ["up"] / (LQ["up"] + LQ["lo"]); l2 = L - l1
    lm = (m["bout"] - m["poignet"]).length
    up, lo, ha = eb["upperarm_" + s], eb["lowerarm_" + s], eb["hand_" + s]
    d_up = (up.tail - up.head).normalized(); d_lo = (lo.tail - lo.head).normalized()
    h0 = up.head.copy()
    up.tail = h0 + d_up * l1
    lo.head = up.tail.copy(); lo.tail = lo.head + d_lo * l2
    # main et doigts : translatés sur le poignet, mis à l'échelle de la main mesurée
    origine = ha.head.copy()
    km = lm / (LQ["main"] * k)
    for b in [ha] + [b for b in eb if b.name.startswith(("index_", "middle_", "ring_", "pinky_", "thumb_")) and b.name.endswith("_" + s)]:
        b.head = lo.tail + (b.head - origine) * km
        b.tail = lo.tail + (b.tail - origine) * km
    log("bras %s : longueur %.3f (épaule->poignet), main %.3f (x%.2f des humains)" % (s, L, lm, km))
    dx = MES[s]["jambe_x"] - 0.114 * k
    for nom in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        b = eb[nom + "_" + s]
        b.head.x += sg * dx; b.tail.x += sg * dx
bpy.ops.object.mode_set(mode="OBJECT")
# doigts RIGIDES par défaut (comme les gardes Tripo) : la main du modèle garde sa forme sculptée (doigts mi-fléchis), entière sur
# hand_* ; fermés par les clips, les doigts décimés se froissaient en éclats autour de la poignée (essai 1). --doigts=souples : phalanges.
DOIGTS_SOUPLES = arg("doigts", "rigides") == "souples"
for b in arm.data.bones:
    n = b.name
    doigt = n.startswith(("index_", "middle_", "pinky_", "ring_", "thumb_"))
    b.use_deform = not (n == "root" or n.endswith("_leaf_l") or n.endswith("_leaf_r") or (doigt and not DOIGTS_SOUPLES))

# bras : pose T -> pose A mesurée (rotation de l'épaule)
ROT = {}
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    pb = arm.pose.bones["upperarm_" + s]
    h = arm.matrix_world @ pb.head
    d0 = ((arm.matrix_world @ arm.pose.bones["hand_" + s].head) - h).normalized()
    d = (MES[s]["poignet"] - h).normalized()
    ROT[s] = d0.rotation_difference(d)
    log("bras %s : %.1f deg depuis le T" % (s, math.degrees(ROT[s].angle)))
def bras(inverse):
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
bras(False)

# poids automatiques (copie soudée)
cp = bpy.data.objects.new("soude", mb.copy())
bpy.context.scene.collection.objects.link(cp)
bm = bmesh.new(); bm.from_mesh(cp.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.to_mesh(cp.data); bm.free()
sel_seul(cp, arm, actif=arm)
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
gn = {g.index: g.name for g in cp.vertex_groups}
kd = kdtree.KDTree(len(cp.data.vertices))
for v in cp.data.vertices:
    kd.insert(v.co, v.index)
kd.balance()
poids = []
for i in range(nv):
    _, j, _ = kd.find(Vector(Pb[i]))
    poids.append({gn[g.group]: g.weight for g in cp.data.vertices[j].groups if g.weight > 1e-4})
bpy.data.objects.remove(cp)
sans = [i for i in range(nv) if not poids[i]]
log("poids auto : sommets sans poids :", len(sans))
if sans:
    kdp = kdtree.KDTree(nv - len(sans))
    for i in range(nv):
        if poids[i]:
            kdp.insert(Vector(Pb[i]), i)
    kdp.balance()
    for i in sans:
        poids[i] = dict(poids[kdp.find(Vector(Pb[i]))[1]])

# doigts : chaque sommet de la main au-delà des articulations des doigts suit le segment d'os de doigt le plus proche (les poids
# automatiques mélangent les doigts voisins, qui se collent en moufle quand le poing se ferme)
DOIGTS = ("thumb", "index", "middle", "ring", "pinky")
def seg(pb):
    return np.array(arm.matrix_world @ pb.head), np.array(arm.matrix_world @ pb.tail)
for s, sg in ((("l", 1), ("r", -1)) if DOIGTS_SOUPLES else ()):
    segs = []
    for d_ in DOIGTS:
        for n_ in ("01", "02", "03"):
            segs.append((d_ + "_" + n_ + "_" + s,) + seg(arm.pose.bones[d_ + "_" + n_ + "_" + s]))
    hh_, ht_ = seg(arm.pose.bones["hand_" + s])
    axe = (ht_ - hh_) / np.linalg.norm(ht_ - hh_)
    base_doigts = min(float((seg(arm.pose.bones[d_ + "_01_" + s])[0] - hh_) @ axe) for d_ in DOIGTS if d_ != "thumb")
    n_d = 0
    for i in range(nv):
        if not (peau_c[i] and mains_zone[i] and sg * x[i] > 0):
            continue
        p = Pb[i]
        t_axe = float((p - hh_) @ axe)
        best, bd = None, 1e9
        for nom, a_, b_ in segs:
            ab = b_ - a_
            t = np.clip(((p - a_) @ ab) / (ab @ ab), 0.0, 1.0)
            dd = np.linalg.norm(p - (a_ + t * ab))
            if dd < bd:
                bd, best = dd, nom
        # mélange vers la paume près des jointures (pouce : depuis sa base)
        if best.startswith("thumb"):
            f = float(sstep(0.0, 0.025, np.linalg.norm(p - seg(arm.pose.bones["thumb_01_" + s])[0])))
        else:
            f = float(sstep(base_doigts - 0.012, base_doigts + 0.012, t_axe))
        # paume : les poids automatiques y mêlent les phalanges (la paume s'étirait de 18-33 % quand les doigts se ferment) -> main seule
        w = {n_: v_ for n_, v_ in poids[i].items() if not n_.startswith(DOIGTS)}
        reste = sum(poids[i].get(n_, 0.0) for n_ in poids[i] if n_.startswith(DOIGTS))
        if reste > 0:
            w["hand_" + s] = w.get("hand_" + s, 0.0) + reste
        if f <= 0.0:
            poids[i] = w
            continue
        w = {n_: v_ * (1 - f) for n_, v_ in w.items()}
        w[best] = w.get(best, 0.0) + f
        poids[i] = w
        n_d += 1
    log("doigts %s : %d sommets sur les phalanges" % (s, n_d))

for i in range(nv):
    if not (peau_c[i] and mains_zone[i]) and any(n_.startswith(DOIGTS) for n_ in poids[i]):
        s_ = "l" if x[i] > 0 else "r"
        w = {n_: v_ for n_, v_ in poids[i].items() if not n_.startswith(DOIGTS)}
        w["hand_" + s_] = w.get("hand_" + s_, 0.0) + sum(v_ for n_, v_ in poids[i].items() if n_.startswith(DOIGTS))
        poids[i] = w
for g in list(corps.vertex_groups):
    corps.vertex_groups.remove(g)
grp = {}
for i, w in enumerate(poids):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(v for _, v in top) or 1.0
    for n_, v_ in top:
        if v_ / tot < 0.015:
            continue
        if n_ not in grp:
            grp[n_] = corps.vertex_groups.new(name=n_)
        grp[n_].add([i], v_ / tot, "REPLACE")
corps.parent = arm
corps.matrix_parent_inverse = Matrix.Identity(4)
md = corps.modifiers.new("Armature", "ARMATURE"); md.object = arm
log("groupes de poids :", len(grp))

# rendu de contrôle (pose A) : classes en couleurs + os
if DEBUG:
    COUL = {0: (0.95, 0.6, 0.45, 1), 1: (0.45, 0.25, 0.1, 1), 2: (0.85, 0.85, 0.3, 1), 3: (0.2, 0.3, 0.9, 1), 4: (0.2, 0.8, 0.3, 1)}
    ca = mb.color_attributes.new("dbg", "BYTE_COLOR", "CORNER")
    for p in mb.polygons:
        for li in p.loop_indices:
            ca.data[li].color = COUL[int(fcl[p.index])]
    cu = bpy.data.curves.new("osdbg", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = 0.006
    for b in arm.pose.bones:
        sp = cu.splines.new("POLY"); sp.points.add(1)
        sp.points[0].co = (*(arm.matrix_world @ b.head), 1); sp.points[1].co = (*(arm.matrix_world @ b.tail), 1)
    ob = bpy.data.objects.new("osdbg", cu); bpy.context.scene.collection.objects.link(ob)
    mt = bpy.data.materials.new("osm"); mt.diffuse_color = (1, 0, 0, 1); cu.materials.append(mt)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "VERTEX"
    sc.display.shading.show_xray = False
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.2, 0.2, 0.25)
    cam = bpy.data.objects.new("CAMX", bpy.data.cameras.new("CAMX")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; sc.camera = cam
    def vue(nom, c, ang, ech, rx=400, ry=640):
        sc.render.resolution_x, sc.render.resolution_y = rx, ry
        cam.data.ortho_scale = ech
        r_ = math.radians(ang)
        cam.location = c + Vector((math.sin(r_), -math.cos(r_), 0)) * 6
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(DEBUG, "rig_" + nom + ".png")
        bpy.ops.render.render(write_still=True)
    for nom, ang in (("face", 0), ("profil", 90), ("dos", 180)):
        vue(nom, Vector((0, 0, H / 2)), ang, H * 1.1)
    mt.diffuse_color = (1, 0, 0, 1)
    cu.bevel_depth = 0.002
    vue("main_g", MES["l"]["poignet"] + Vector((0, 0, -0.07)), 90, 0.22, 500, 500)
    vue("main_g_face", MES["l"]["poignet"] + Vector((0, 0, -0.07)), 0, 0.22, 500, 500)
    mb.color_attributes.remove(ca)
    bpy.data.objects.remove(ob)

# pose A -> T cuite dans le maillage (les clips des humains partent du T)
sel_seul(arm)
bras(True)
sel_seul(corps)
bpy.ops.object.modifier_apply(modifier="Armature")
md = corps.modifiers.new("Armature", "ARMATURE"); md.object = arm
sel_seul(arm)
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
arm.name = "Armature"

# normales lissées sur le corps entier, gardées (normales personnalisées) avant la découpe en pièces : pas de couture d'éclairage
mb = corps.data
mb.calc_loop_triangles()
cn = [tuple(mb.vertices[l.vertex_index].normal) for l in mb.loops]
mb.normals_split_custom_set(cn)
# ---------------------------------------------------------------------------------------------------- découpe en pièces
pieces = {}
for ci, nom in enumerate(NOMS):
    faces = [p.index for p in mb.polygons if fcl[p.index] == ci]
    if not faces:
        continue
    o = corps.copy(); o.data = mb.copy(); o.name = nom; o.data.name = nom
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    garde_ = set(faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in garde_], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.parent = arm; o.matrix_parent_inverse = Matrix.Identity(4)
    pieces[nom] = o
    log("pièce %-9s : %5d tris" % (nom, len(o.data.polygons)))
bpy.data.objects.remove(corps)
tot = sum(len(o.data.polygons) for o in pieces.values())
log("TOTAL %d tris, %d os" % (tot, len(arm.data.bones)))

if DEBUG:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "final_%s.blend" % SEXE))
# ---------------------------------------------------------------------------------------------------- 6. export
sel_seul(arm, *pieces.values(), actif=arm)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_apply=False, export_image_format="AUTO")
log("EXPORT OK", OUT, "tris", tot)
