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

# ---------------------------------------------------------------------------------------------------- 3 bis. fissures (passe 2)
# La décimation laisse quelques arêtes non-manifold (une arête à 3 faces, une fente de 2 arêtes ouvertes : homme 1, femme 4). On retire
# les faces autour, on rebouche (triangles) ; les UV des faces neuves reprennent celles d'une face voisine au même sommet.
def reparer_fissures(me):
    bm = bmesh.new(); bm.from_mesh(me)
    la = bm.loops.layers.uv.active
    neuves = []
    for _ in range(4):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        mauvais = {v for e in bm.edges if not e.is_manifold for v in e.verts}
        if not mauvais:
            break
        faces = {f for v in mauvais for f in v.link_faces}
        bmesh.ops.delete(bm, geom=list(faces), context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        r = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=40)
        t = bmesh.ops.triangulate(bm, faces=r["faces"])
        neuves += t["faces"]
    neuves = [f for f in neuves if f.is_valid]
    for f in neuves:
        f.smooth = True
        for l in f.loops:
            autre = next((l2 for f2 in l.vert.link_faces if f2 not in neuves for l2 in f2.loops if l2.vert == l.vert), None)
            if autre is not None:
                l[la].uv = autre[la].uv.copy()
    ouv = sum(1 for e in bm.edges if not e.is_manifold)
    bm.to_mesh(me); bm.free()
    return len(neuves), ouv
n_f, n_o = reparer_fissures(mb)
log("fissures : %d faces de rebouchage, arêtes non-manifold restantes %d, %d tris" % (n_f, n_o, len(mb.polygons)))

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
# garde-fou (passe 3) : une manche classée « peau » allonge la main d'un côté (femme, main gauche : 0,223 m contre 0,167) ; les deux
# mains ont la même longueur : la plus longue est ramenée à la plus courte, poignet replacé sur la même ligne bout -> poignet
_lm = {s_: (MES[s_]["poignet"] - MES[s_]["bout"]).length for s_ in ("l", "r")}
_court = min(_lm, key=_lm.get); _long = "r" if _court == "l" else "l"
if _lm[_long] > 1.15 * _lm[_court]:
    d_ = (MES[_long]["poignet"] - MES[_long]["bout"]).normalized()
    MES[_long]["poignet"] = MES[_long]["bout"] + d_ * _lm[_court]
    log("poignet %s recalé : main %.3f -> %.3f m (comme la main %s)" % (_long, _lm[_long], _lm[_court], _court))
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

# ---------------------------------------------------------------------------------------------------- mains affinées (passe 2)
# Les mains de la source sont larges et épaisses (largeur main / avant-bras : homme 0,90, femme 1,03 ; cible 0,75-0,80 : « ça fait
# jouet »). Leur longueur est déjà juste (0,75-0,77 de l'avant-bras) : on resserre seulement autour de l'axe poignet -> main, en T,
# chaque sommet au prorata de son poids de main (le poignet se raccorde en douceur). --main_largeur=<facteur>.
# facteurs par côté (mesurés au contrôle : la main gauche et la droite de la source ne réagissent pas pareil, pouce plus écarté)
# main droite de la femme (passe 3) : elle sort de Tripo hérissée d'éclats (faces repliées aux doigts et dans la paume, visibles même
# main ouverte, et qui pointent hors du poing ; un lissage fond les doigts, une projection garde les replis). Sa main gauche est
# propre : la main droite est REMPLACÉE par une copie miroir de la gauche (x -> -x, recalée au poignet et sur l'axe de la main, en T,
# faces retournées, poids _l -> _r, UV et classe de la gauche). Coupe au plan du poignet ; la copie part 15 mm plus tôt et son bord
# rentre de 4 % dans l'ancien poignet (recouvrement caché, pas de jour). --main_miroir=<l|r|aucune>.
MIROIR = arg("main_miroir", {"homme": "aucune", "femme": "r"}[SEXE])
if MIROIR in ("l", "r"):
    src_ = "l" if MIROIR == "r" else "r"
    gnom = {g.index: g.name for g in corps.vertex_groups}
    gidx = {g.name: g.index for g in corps.vertex_groups}
    def _de_main(nom, s):
        return nom == "hand_" + s or (nom.startswith(DOIGTS) and nom.endswith("_" + s))
    bm = bmesh.new(); bm.from_mesh(mb)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    dl = bm.verts.layers.deform.active
    cl = bm.faces.layers.int.new("cl_")
    for f in bm.faces:
        f[cl] = int(fcl[f.index])
    def _w(v, s):
        return min(1.0, sum(w for g, w in v[dl].items() if _de_main(gnom[g], s)))
    wS = {v: _w(v, src_) for v in bm.verts}
    wD = {v: _w(v, MIROIR) for v in bm.verts}
    oS = arm.matrix_world @ arm.data.bones["hand_" + src_].head_local
    oD = arm.matrix_world @ arm.data.bones["hand_" + MIROIR].head_local
    def _moy(ws):
        c_ = [v.co for v in bm.verts if ws[v] > 0.9]
        return sum(c_, Vector()) / len(c_)
    axS = (_moy(wS) - oS).normalized(); axD = (_moy(wD) - oD).normalized()
    axSm = Vector((-axS.x, axS.y, axS.z))
    R_ = axSm.rotation_difference(axD).to_matrix()
    # coupe GÉOMÉTRIQUE (les poids de la main droite d'origine sont faux par endroits : des faces de doigts à poids faible restaient
    # et flottaient en éclats autour du poing) : on retire tout ce qui passe le plan du poignet (tête de l'os de la main) près de l'axe,
    # on copie ce qui passe 15 mm avant le même plan côté gauche (recouvrement).
    def _t(f, o_, ax_):
        c_ = f.calc_center_median() - o_
        t_ = c_.dot(ax_)
        return t_, (c_ - t_ * ax_).length
    anciennes = [f for f in bm.faces if _t(f, oD, axD)[0] > 0.0 and _t(f, oD, axD)[1] < 0.09]
    modeles = [f for f in bm.faces if _t(f, oS, axS)[0] > -0.015 and _t(f, oS, axS)[1] < 0.09]
    d_ = bmesh.ops.duplicate(bm, geom=modeles)
    nv_ = [g for g in d_["geom"] if isinstance(g, bmesh.types.BMVert)]
    nf_ = [g for g in d_["geom"] if isinstance(g, bmesh.types.BMFace)]
    for v in nv_:
        q = v.co - oS
        q = R_ @ Vector((-q.x, q.y, q.z))
        if (v.co - oS).dot(axS) < 0.004:                # bande du poignet : rentrée dans l'ancien poignet
            par_ = q.dot(axD) * axD
            q = par_ + (q - par_) * 0.96
        v.co = oD + q
        poids = dict(v[dl].items()); v[dl].clear()
        for g, w in poids.items():
            n_ = gnom[g]
            n2 = n_[:-2] + "_" + MIROIR if n_.endswith("_" + src_) else n_
            v[dl][gidx.get(n2, g)] = w
    bmesh.ops.reverse_faces(bm, faces=nf_)
    bmesh.ops.delete(bm, geom=anciennes, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.faces.ensure_lookup_table()
    fcl = np.array([f[cl] for f in bm.faces], dtype=int)
    bm.faces.layers.int.remove(cl)
    bm.to_mesh(mb); bm.free(); mb.update()
    log("main %s remplacée par le miroir de la main %s : %d faces retirées, %d faces copiées" % (MIROIR, src_, len(anciennes), len(nf_)))

MAIN_L = {s: float(arg("main_largeur_" + s, arg("main_largeur", {"homme": {"l": "0.91", "r": "0.78"}, "femme": {"l": "0.60", "r": "0.61"}}[SEXE][s])))
          for s in ("l", "r")}
if MAIN_L["l"] != 1.0 or MAIN_L["r"] != 1.0:
    gi = {g.name: g.index for g in corps.vertex_groups}
    Pm = coords(mb)
    for s in ("l", "r"):
        b_ = arm.data.bones["hand_" + s]
        w = np.zeros(len(Pm))
        for v in mb.vertices:
            for g in v.groups:
                n_ = corps.vertex_groups[g.group].name
                if n_ == "hand_" + s or (n_.startswith(DOIGTS) and n_.endswith("_" + s)):
                    w[v.index] += g.weight
        w = np.clip(w, 0.0, 1.0)
        o_ = np.array(arm.matrix_world @ b_.head_local)
        coeur = w > 0.9
        ax = Pm[coeur].mean(0) - o_
        ax /= np.linalg.norm(ax)
        d = Pm - o_
        par_ = (d @ ax)[:, None] * ax
        perp = d - par_
        f_ = 1.0 - (1.0 - MAIN_L[s]) * w[:, None]
        Pm = np.where((w > 0)[:, None], o_ + par_ + perp * f_, Pm)
        log("main %s : %d sommets resserrés x%.2f autour de l'axe du poignet" % (s, int((w > 0).sum()), MAIN_L[s]))
    mb.vertices.foreach_set("co", Pm.ravel())
    mb.update()

# ---------------------------------------------------------------------------------------------------- poings (passe 3)
# La main du modèle est sculptée mi-ouverte et RIGIDE (doigts pondérés à hand_* : les phalanges décimées se froissaient en éclats),
# et les os des doigts (ceux des humains, translatés) ne suivent pas les doigts sculptés : rien ne fermait la main sur la poignée,
# placée d'après ces os (elle passait entre le pouce et l'index). Ici, tout part du MAILLAGE de la main :
#   repère de la main par analyse en composantes (longueur poignet -> doigts, travers de la paume, épaisseur ; la paume est du côté
#   où les bouts des doigts sont déjà repliés), jointures à JOINT x la longueur de la main ;
#   FUSÉE : cylindre de rayon POIGNEE couché en travers de la paume, au pied des doigts, posé contre la paume ;
#   deux FORMES (shape keys glTF -> blend shapes Godot) « poing_l » / « poing_r » : les quatre doigts enroulés autour de la fusée
#   (cintrage à rayon constant depuis les jointures), le pouce rabattu sur les doigts.
# Godot ferme le poing qui tient quelque chose (PostureJoueur) et pose l'objet sur l'axe de la fusée : centre et axes écrits, en
# coordonnées du modèle Godot, dans assets/modeles/joueur/joueur_<sexe>_poings.gd (JoueurBase.prise).
# rayon de la fusée par main : la droite tient l'épée (fusée ~16 mm), la gauche la torche (manche 21-24 mm, lanière 27 mm), la poignée
# du bouclier et l'arc : avec 16 mm à gauche, les doigts de la femme traversaient le manche de la torche et ressortaient en éclats
# (femme 19 mm : sa main, plus petite, n'entoure plus rien au-delà ; homme 23 mm).
POIGNEES = {"l": float(arg("poignee_l", {"homme": "0.023", "femme": "0.019"}[SEXE])), "r": float(arg("poignee_r", arg("poignee", "0.016")))}
POIGNEE = POIGNEES["r"]
JOINT = float(arg("joint", "0.55"))
def v3(b, bout=False):
    bb = arm.data.bones[b]
    return np.array(arm.matrix_world @ (bb.tail_local if bout else bb.head_local))
def unit(v):
    return v / np.linalg.norm(v)
def godot(v):
    return (float(v[0]), float(v[2]), float(-v[1]))
PO = {}
Pm = coords(mb)
CO = {}
for s in ("l", "r"):
    POIGNEE = POIGNEES[s]
    sg = 1.0 if s == "l" else -1.0
    w = np.zeros(len(Pm))
    for v in mb.vertices:
        for g in v.groups:
            if corps.vertex_groups[g.group].name == "hand_" + s:
                w[v.index] += g.weight
    main = (w > 0.5) & (sg * Pm[:, 0] > 0)
    W = v3("hand_" + s)
    Q = Pm[main]
    c_ = Q.mean(0)
    val, vec = np.linalg.eigh(np.cov((Q - c_).T))
    e1, e2, e3 = vec[:, 2], vec[:, 1], vec[:, 0]
    if (c_ - W) @ e1 < 0: e1 = -e1
    sv = (Pm - W) @ e1
    L = float(sv[main].max())
    bouts = main & (sv > 0.85 * L)
    if ((Pm[bouts] - c_) @ e3).mean() < 0: e3 = -e3       # e3 : vers la paume
    e2 = np.cross(e3, e1)
    hv = (Pm - W) @ e3
    wv = (Pm - W) @ e2
    sK = JOINT * L
    paume = main & (sv > 0.18 * L) & (sv < sK - 0.01)
    h_p = float(np.percentile(hv[paume], 92)); h_d = float(np.percentile(hv[paume], 8))
    w_lo, w_hi = np.percentile(wv[paume], 4), np.percentile(wv[paume], 96)
    # pouce : ce qui dépasse du travers de la paume avant les jointures (côté du pouce : celui où ça dépasse le plus)
    deb_hi = main & (sv < sK + 0.01) & (wv > w_hi + 0.004); deb_lo = main & (sv < sK + 0.01) & (wv < w_lo - 0.004)
    # en T, paumes vers le sol, les pouces regardent DEVANT (-Y de Blender) : plus sûr que le compte des sommets qui dépassent
    cote_pouce = 1.0 if e2[1] < 0 else -1.0
    pouce = deb_hi if cote_pouce > 0 else deb_lo
    # étend le pouce à ses bouts (sommets reliés au-delà des jointures, du même côté)
    pouce = pouce | (main & (cote_pouce * (wv - (w_hi if cote_pouce > 0 else w_lo)) > -0.006) & (sv < 0.8 * L) & (hv > h_d + 0.004))
    # fusée contre la paume, son quart enfoncé dans le pli (paume / doigts) ; doigts cintrés autour, peau contre la fusée
    # Fermeture : les doigts (au-delà des jointures) pivotent en bloc à deux charnières (jointures, mi-doigt ; transitions douces de
    # 6 mm), vers la paume. On cherche les deux angles qui laissent dans le poing un trou du rayon de la fusée : coupe des doigts du
    # milieu dans le plan (longueur, épaisseur), plus grand cercle vide à l'intérieur de leur enveloppe convexe.
    racines = main & (sv > sK) & (sv < sK + 0.02)
    h_c = float(np.median(hv[racines])) if racines.any() else 0.0
    s2 = sK + 0.42 * (L - sK)
    doigt = main & ~pouce & (sv > sK - 0.008)
    w_mid = float(np.median(wv[main & (sv > sK) & (sv < sK + 0.03)]))
    nz_ = np.array([tuple(v.normal) for v in mb.vertices]) @ e3
    # coupe : les doigts entiers, et de la paume sa seule surface côté paume (l'intérieur de la chair n'est pas un trou)
    tranche = main & (np.abs(wv - w_mid) < 0.012) & (sv > 0.15 * L) & ((sv > sK - 0.004) | (nz_ > 0.25))
    def plier(a1, a2, idx):
        P_ = Pm[idx] - W
        s_, h_, w_ = P_ @ e1, P_ @ e3, P_ @ e2
        f1 = sstep(sK - 0.006, sK + 0.006, s_); f2 = sstep(s2 - 0.006, s2 + 0.006, s_)
        # charnière 2 (mi-doigt) d'abord, puis charnière 1 (jointures) ; rotation dans le plan (e1, e3) vers +e3
        for (sc_, hc_, a_, f_) in ((s2, h_c, a2, f2), (sK, h_c, a1, f1)):
            t_ = a_ * f_
            ds_, dh_ = s_ - sc_, h_ - hc_
            s_, h_ = sc_ + ds_ * np.cos(t_) - dh_ * np.sin(t_), hc_ + ds_ * np.sin(t_) + dh_ * np.cos(t_)
        return W + np.outer(s_, e1) + np.outer(h_, e3) + np.outer(w_, e2), s_, h_
    def enveloppe(pts):
        pts = sorted(set(map(tuple, np.round(pts, 5))))
        if len(pts) < 3: return pts
        def cr(o, a_, b_): return (a_[0]-o[0])*(b_[1]-o[1]) - (a_[1]-o[1])*(b_[0]-o[0])
        lo, hi = [], []
        for q_ in pts:
            while len(lo) >= 2 and cr(lo[-2], lo[-1], q_) <= 0: lo.pop()
            lo.append(q_)
        for q_ in reversed(pts):
            while len(hi) >= 2 and cr(hi[-2], hi[-1], q_) <= 0: hi.pop()
            hi.append(q_)
        return lo[:-1] + hi[:-1]
    def trou(a1, a2):
        idx = np.nonzero(tranche)[0]
        _, s_, h_ = plier(a1 if True else 0, a2, idx)
        ok = doigt[idx]
        s_ = np.where(ok, s_, (Pm[idx] - W) @ e1); h_ = np.where(ok, h_, (Pm[idx] - W) @ e3)
        pts = np.stack([s_, h_], 1)
        hull = np.array(enveloppe(pts))
        gs = np.linspace(pts[:, 0].min(), pts[:, 0].max(), 48); gh = np.linspace(pts[:, 1].min(), pts[:, 1].max(), 48)
        G_ = np.array([(a_, b_) for a_ in gs for b_ in gh])
        dedans = np.ones(len(G_), bool)
        for k_ in range(len(hull)):
            a_, b_ = hull[k_], hull[(k_ + 1) % len(hull)]
            dedans &= ((b_[0]-a_[0])*(G_[:, 1]-a_[1]) - (b_[1]-a_[1])*(G_[:, 0]-a_[0])) >= 0
        if not dedans.any(): return 0.0, None
        G_ = G_[dedans]
        d_ = np.sqrt(((G_[:, None, :] - pts[None, :, :]) ** 2).sum(2)).min(1)
        k_ = int(np.argmax(d_))
        return float(d_[k_]), G_[k_]
    # fusée posée contre la paume au pli des doigts ; on cherche les charnières qui l'ENTOURENT le plus (angle couvert par les doigts
    # à moins de 12 mm de sa surface) sans qu'aucun doigt n'y entre (marge 1 mm)
    c2 = np.array([sK + float(arg("pli", "0.004")), h_p + POIGNEE * float(arg("enfonce", "0.85"))])
    idx_t = np.nonzero(tranche & doigt)[0]
    best = None
    for a1 in np.radians(np.arange(0, 100, 5)):
        for a2 in np.radians(np.arange(0, 110, 10)):
            _, s_, h_ = plier(a1, a2, idx_t)
            d_ = np.hypot(s_ - c2[0], h_ - c2[1])
            dedans = int((d_ < POIGNEE - 0.002).sum())
            proche = d_ < POIGNEE + 0.012
            ang = np.degrees(np.arctan2(h_[proche] - c2[1], s_[proche] - c2[0]))
            couvert = len(set(np.floor(ang / 15.0).astype(int).tolist())) * 15.0
            note = couvert - 6.0 * dedans
            if best is None or note > best[0]:
                best = (note, a1, a2, couvert, dedans)
    _, a1, a2, couvert, dedans = best
    r_trou = POIGNEE
    co = Pm.copy()
    idx = np.nonzero(doigt)[0]
    co[idx] = plier(a1, a2, idx)[0]
    n_d = len(idx)
    # pouce : rabattu autour de l'axe de la main (e1) passant par sa base, vers la paume
    for i in np.nonzero(pouce)[0]:
        pt = Pm[i]
        base = W + e1 * (0.25 * L) + e2 * (w_hi if cote_pouce > 0 else w_lo)
        f_ = float(sstep(0.0, 0.03, np.linalg.norm(pt - base)))
        ang = math.radians(float(arg("pouce", "35"))) * f_ * -cote_pouce
        q = np.array(Matrix.Rotation(ang, 3, Vector(e1)))
        co[i] = base + q @ (pt - base)
    n_p = int(pouce.sum())
    C = W + e1 * c2[0] + e3 * c2[1] + e2 * w_mid
    rc = float(c2[1])
    log("poing %s : charnières %.0f° / %.0f°, fusée entourée sur %.0f° par les doigts, %d sommets dedans (fusée %.1f mm)" % (s, math.degrees(a1), math.degrees(a2), couvert, dedans, POIGNEE * 1000))
    CO[s] = co
    PO[s] = dict(centre=godot(C), axe=godot(e2 * cote_pouce), doigts=godot(e1))
    log("poing %s : main %.3f m, paume %+.3f / dos %+.3f (épaisseur %.3f), pouce côté %+d (%d sommets), %d sommets de doigts enroulés ; fusée à %.3f m du dos de l'os" % (
        s, L, h_p, h_d, h_p - h_d, cote_pouce, n_p, n_d, rc))
if not corps.data.shape_keys:
    corps.shape_key_add(name="Basis", from_mix=False)
for s in ("l", "r"):
    k_ = corps.shape_key_add(name="poing_" + s, from_mix=False)
    k_.data.foreach_set("co", CO[s].ravel())
def gv(t):
    return "Vector3(%.5f, %.5f, %.5f)" % t
with open(os.path.join(os.path.dirname(OUT), "joueur_%s_poings.gd" % SEXE), "w", encoding="utf-8") as fp:   # à côté du glb
    fp.write("## Généré par sources_blender/scripts/joueur_base_rig.py (poings) : ne pas modifier à la main.\n")
    fp.write("## Par main, repère du MODÈLE Godot au repos : centre de la fusée, son axe (du petit doigt vers le pouce), direction des doigts.\n")
    fp.write("const POINGS := {\n")
    for c_ in ("l", "r"):
        fp.write('\t"%s": {"centre": %s, "axe": %s, "doigts": %s},\n' % (c_, gv(PO[c_]["centre"]), gv(PO[c_]["axe"]), gv(PO[c_]["doigts"])))
    fp.write("}\nconst RAYON_POIGNEE := {\"l\": %.4f, \"r\": %.4f}\n" % (POIGNEES["l"], POIGNEES["r"]))

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
for o in list(bpy.data.objects):       # forme de « custom shape » des os créée par l'import glTF des humains : jamais exportée
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
for pb_ in arm.pose.bones:
    pb_.custom_shape = None
sel_seul(arm, *pieces.values(), actif=arm)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_apply=False, export_image_format="AUTO")
log("EXPORT OK", OUT, "tris", tot)
