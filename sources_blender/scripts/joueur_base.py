# MODÈLES DU JOUEUR (homme / femme) : modèles « de base » fournis par l'utilisateur (Tripo, ~4,9 M tris, 1 maillage, 3 textures 4K, sans
# squelette) -> personnage de jeu rigué sur le squelette des humains (65 os de homme_vetu.glb : mêmes clips Humain.bibliotheque(),
# PiedsAuSol, Ragdoll, coups 3e personne, armures portées).
#   blender.exe -b --python joueur_base.py -- --sexe=homme|femme [--src=<glb>] [--sortie=<glb>] [--debug=<dossier>] [--tris=11000] [--tex=256]
# Entrée : Jeux/references/joueur_base/<sexe>_base.glb. ATTENTION : le fichier est une PLANCHE de 3 vues (face / profil / dos côte à côte
# en x, chacune un personnage 3D complet, ~1,6 M tris) en pose A, pieds à z=0, hauteur 0,787. On garde la copie de FACE (x < -0,13, regarde -Y).
# Sortie : assets/modeles/joueur/joueur_<sexe>.glb (os + maillages SKINNÉS en T comme les humains, une texture atlas basse déf).
# Étapes :
#   1. copie de face, recentrée, mise à l'échelle (homme 1,75 m, femme 1,65 m), éclats < 0,2 % retirés ;
#   2. version « haute » (~300 k tris, source de cuisson) puis basse (~11 k tris) par décimation pondérée : visage et mains gardent ~3x
#      plus de détail (groupe de sommets), le reste suit la silhouette ;
#   3. UV neuves (îlots à densité égale, tête et mains agrandies x1,6) et CUISSON de la couleur de base x relief de la carte normale
#      (le shader ps1 n'a pas de carte normale) en 1024 px, réduite en atlas <tex> px (boîte) ;
#   4. découpe en pièces nommées comme le héros (peau, cheveux, tunique, pantalon, bottes) : ArmureVisible masque ce qu'une pièce
#      d'armure recouvre par ces noms ;
#   5. squelette : celui des humains mis à l'échelle (k = hauteur / 1,82), épaules et longueurs des bras mesurées sur le maillage, jambes
#      recalées en x (orientations des os INCHANGÉES : les clips s'appliquent tels quels ; seul « pelvis » a une piste de position,
#      compensée dans Godot par Skeleton3D.motion_scale = k) ; bras tournés vers la pose A, poids automatiques sur une copie soudée,
#      doigts pondérés au plus proche segment d'os, puis pose A -> T cuite dans le maillage (même méthode que tripo_rig.py) ;
#   6. export glTF (os + maillages, sans animation).
import bpy, bmesh, math, os, sys, time
import numpy as np
from mathutils import Vector, Matrix, kdtree

T0 = time.time()
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
def log(*a):
    print("[%5.0f s]" % (time.time() - T0), *a, flush=True)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JEUX = os.path.dirname(BASE)
SEXE = arg("sexe", "homme")
SRC = arg("src", os.path.join(JEUX, "references", "joueur_base", "%s_base.glb" % SEXE))
OUT = arg("sortie", os.path.join(BASE, "assets", "modeles", "joueur", "joueur_%s.glb" % SEXE))
DEBUG = arg("debug")
TRIS = int(arg("tris", "11000"))
TEX = int(arg("tex", "512"))      # passe 3 : 512 (les coutures et plis du dos se lisent ; 256 les fondait)
HAUT_TRIS = int(arg("haut", "300000"))
HAUTEUR = {"homme": 1.75, "femme": 1.65}[SEXE]
HQ = 1.82                      # hauteur du corps des humains (homme_vetu.glb, sommet de la tête)
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def sel_seul(*objs, actif=None):
    for o in list(bpy.context.scene.objects):
        if o is not None:
            o.select_set(o in objs)
    bpy.context.view_layer.objects.active = actif or (objs[0] if objs else None)

def coords(me):
    P = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", P)
    return P.reshape(-1, 3)

ETAPE3 = os.path.join(DEBUG or os.path.join(BASE, "sources_blender", "joueur"), "etape3_%s.blend" % SEXE)
RIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "joueur_base_rig.py")
if arg("depuis") == "3":        # itération sur le rig : repart du maillage bas + atlas sauvés à l'étape 3
    bpy.ops.wm.open_mainfile(filepath=ETAPE3)
    exec(open(RIG, encoding="utf-8").read())
    sys.exit(0)

# ---------------------------------------------------------------------------------------------------- 1. copie de face, échelle
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
src = next(o for o in bpy.data.objects if o.type == "MESH")
bpy.ops.object.select_all(action="DESELECT")
src.select_set(True); bpy.context.view_layer.objects.active = src
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = src.data
log("source :", len(me.vertices), "sommets,", len(me.polygons), "faces")
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > -0.13], context="VERTS")
bm.to_mesh(me); bm.free()
P = coords(me)
z0, z1 = P[:, 2].min(), P[:, 2].max()
pieds = P[P[:, 2] < z0 + 0.04 * (z1 - z0)]
cx, cy = (pieds[:, 0].min() + pieds[:, 0].max()) / 2, (P[:, 1].min() + P[:, 1].max()) / 2
k_src = HAUTEUR / (z1 - z0)
P = (P - np.array([cx, cy, z0])) * k_src
me.vertices.foreach_set("co", P.ravel())
me.update()
log("copie de face :", len(me.vertices), "sommets, échelle x%.3f, boîte" % k_src, P.min(0).round(3), P.max(0).round(3))

# éclats : composantes connexes minuscules (après soudure à 0,1 mm)
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
bm.verts.ensure_lookup_table()
vu = set(); comps = []
for v in bm.verts:
    if v in vu: continue
    pile = [v]; vu.add(v); c = []
    while pile:
        a = pile.pop(); c.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b not in vu:
                vu.add(b); pile.append(b)
    comps.append(c)
comps.sort(key=len, reverse=True)
seuil = max(50, int(0.002 * len(bm.verts)))
petits = [v for c in comps if len(c) < seuil for v in c]
log("composantes :", len(comps), "tailles", [len(c) for c in comps[:8]], "; retirées (<%d sommets) :" % seuil, sum(1 for c in comps if len(c) < seuil))
bmesh.ops.delete(bm, geom=petits, context="VERTS")
bm.to_mesh(me); bm.free()

# couleur de base échantillonnée par sommet (classes : peau, cheveux…)
mat_src = me.materials[0]
def image_src(cle):
    return next(nd.image for nd in mat_src.node_tree.nodes if nd.type == "TEX_IMAGE" and cle in nd.image.name)
IMG_BC, IMG_NOR = image_src("basecolor"), image_src("normal")
IMG_NOR.colorspace_settings.name = "Non-Color"
W_, H_ = IMG_BC.size
PX = np.array(IMG_BC.pixels[:], dtype=np.float32).reshape(H_, W_, 4)

def couleurs_sommets(m):
    uv = np.empty(len(m.loops) * 2); m.uv_layers[0].data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
    vi = np.empty(len(m.loops), dtype=np.int64); m.loops.foreach_get("vertex_index", vi)
    xs = np.clip((uv[:, 0] % 1.0) * W_, 0, W_ - 1).astype(int); ys = np.clip((uv[:, 1] % 1.0) * H_, 0, H_ - 1).astype(int)
    c = PX[ys, xs, :3]
    col = np.zeros((len(m.vertices), 3)); n = np.zeros(len(m.vertices))
    np.add.at(col, vi, c); np.add.at(n, vi, 1)
    return col / np.maximum(n, 1)[:, None]

# ---------------------------------------------------------------------------------------------------- 2. haute (cuisson) et basse
def decimer(o, cible, groupe=None, facteur=0.0):
    md = o.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = min(1.0, cible / max(1, len(o.data.polygons)))
    md.use_collapse_triangulate = True
    if groupe:
        md.vertex_group = groupe
        md.invert_vertex_group = True
        md.vertex_group_factor = facteur
    sel_seul(o)
    bpy.ops.object.modifier_apply(modifier=md.name)

decimer(src, HAUT_TRIS)
haut = src; haut.name = "haut"
log("haute :", len(haut.data.polygons), "tris")

# zones à préserver (visage, mains) : couleur de peau, au-dessus du cou ou au bout des bras
Ph = coords(haut.data)
colh = couleurs_sommets(haut.data)
r, g, b = colh[:, 0], colh[:, 1], colh[:, 2]
H = HAUTEUR
peau_h = (r > g * 1.12) & (g > b * 1.05) & (r > 0.16) & ((r - b) > 0.07)
tete_z = 0.865 * H
garder = np.zeros(len(Ph))
garder[Ph[:, 2] > tete_z] = 0.75                        # toute la tête (cheveux compris)
garder[(Ph[:, 2] > tete_z) & peau_h & (Ph[:, 1] < 0.02)] = 1.0   # visage
garder[peau_h & (Ph[:, 2] < 0.60 * H) & (Ph[:, 2] > 0.36 * H) & (np.abs(Ph[:, 0]) > 0.13 * H / 1.75)] = 1.0   # mains
basse = haut.copy(); basse.data = haut.data.copy(); basse.name = "corps"
bpy.context.scene.collection.objects.link(basse)
vg = basse.vertex_groups.new(name="garder")
for i in np.nonzero(garder > 0)[0]:
    vg.add([int(i)], float(garder[i]), "REPLACE")
FACT = float(arg("facteur", "0"))   # 0 = décimation uniforme (retenue : la tête et les mains, très détaillées dans la source, gardent d elles-mêmes ~2,3 k et ~1,8 k tris)
if FACT > 0:
    decimer(basse, TRIS, "garder", FACT)
nb = len(basse.data.polygons)
if abs(nb - TRIS) > 0.08 * TRIS:          # le groupe pondéré change le compte : un second passage recale
    decimer(basse, TRIS)
basse.vertex_groups.clear()
def compter_zones(o):
    o.data.calc_loop_triangles()
    Pz = coords(o.data)
    C = np.array([Pz[list(t.vertices)].mean(0) for t in o.data.loop_triangles])
    zz = C[:, 2] / H
    return {"tete": int((zz > 0.865).sum()), "torse_bras": int(((zz > 0.55) & (zz <= 0.865)).sum()),
            "mains": int(((zz > 0.36) & (zz < 0.60) & (np.abs(C[:, 0]) > 0.15)).sum()),
            "jambes": int(((zz > 0.10) & (zz <= 0.55) & (np.abs(C[:, 0]) <= 0.15)).sum()), "pieds": int((zz <= 0.10).sum())}
log("zones (tris) :", compter_zones(basse))
log("basse :", len(basse.data.polygons), "tris (cible %d) ; mains/visage protégés : %d sommets hauts" % (TRIS, int((garder >= 1).sum())))

# ---------------------------------------------------------------------------------------------------- 3. UV + cuisson
mb = basse.data
for u in list(mb.uv_layers):
    if u.name != mb.uv_layers[0].name:
        mb.uv_layers.remove(u)
uv_at = mb.uv_layers.new(name="atlas")
mb.uv_layers.active = uv_at
# tête et mains : plus de texels là où on regarde (agrandies plus bas)
Pb = coords(mb)
colb = couleurs_sommets(mb)  # (UV source encore en couche 0)
rb_, gb_, bb_ = colb[:, 0], colb[:, 1], colb[:, 2]
peau_b = (rb_ > gb_ * 1.12) & (gb_ > bb_ * 1.05) & (rb_ > 0.16) & ((rb_ - bb_) > 0.07)
grand = (Pb[:, 2] > tete_z) | (peau_b & (Pb[:, 2] < 0.60 * H) & (Pb[:, 2] > 0.36 * H))
mains_b = peau_b & (Pb[:, 2] < 0.60 * H) & (Pb[:, 2] > 0.36 * H) & (np.abs(Pb[:, 0]) > 0.13 * H / 1.75)
# UV « 6 vues » (passe 3) : chaque face est dépliée par PROJECTION depuis la vue qui la regarde le mieux - face, dos, profils, dessus,
# dessous -, en grands îlots d'un seul tenant (le dos de la chemise : un îlot projeté depuis le dos, ses côtés depuis le profil).
# L'ancien dépliage automatique (angle 60°) découpait le corps en centaines d'îlots de quelques pixels, bordés de noir : à 256 px et
# avec la texture affine du PS1, le dos virait à l'aplat sombre. Les mains (doigts repliés devant la paume : une projection se
# recouvrirait) restent en dépliage automatique.
VUES = np.array([[0, -1, 0], [0, 1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]], dtype=float)
POIDS_VUES = np.array([1.0, 1.0, 0.92, 0.92, 0.85, 0.85])     # à égalité, la face ou le dos (les grandes vues) l'emportent
bm = bmesh.new(); bm.from_mesh(mb); bm.faces.ensure_lookup_table()
la = bm.loops.layers.uv["atlas"]
NF = len(bm.faces)
nrm = np.array([tuple(f.normal) for f in bm.faces])
vue_f = np.argmax((nrm @ VUES.T) * POIDS_VUES, axis=1)
main_f = np.array([np.mean([mains_b[v.index] for v in f.verts]) > 0.5 for f in bm.faces])
voisins = [[g.index for e in f.edges for g in e.link_faces if g != f] for f in bm.faces]
def lisser(vf, tours):
    for _ in range(tours):
        nv_ = vf.copy()
        for i in range(NF):
            vs = [vf[j] for j in voisins[i]]
            if vs:
                m_ = max(set(vs), key=vs.count)
                if vs.count(m_) >= 2 and vs.count(vf[i]) <= 1:
                    nv_[i] = m_
        vf = nv_
    return vf
vue_f = lisser(vue_f, 4)
def composantes(vf):
    comp = -np.ones(NF, dtype=int); n_ = 0
    for i in range(NF):
        if comp[i] >= 0 or main_f[i]: continue
        pile = [i]; comp[i] = n_
        while pile:
            a_ = pile.pop()
            for j in voisins[a_]:
                if comp[j] < 0 and not main_f[j] and vf[j] == vf[a_]:
                    comp[j] = n_; pile.append(j)
        n_ += 1
    return comp, n_
for _ in range(3):      # petits îlots (< 16 faces) absorbés par la vue voisine majoritaire
    comp, n_ = composantes(vue_f)
    taille = np.bincount(comp[comp >= 0], minlength=n_)
    chg = 0
    for i in range(NF):
        if comp[i] >= 0 and taille[comp[i]] < 16:
            vs = [vue_f[j] for j in voisins[i] if comp[j] >= 0 and taille[comp[j]] >= 16]
            if vs:
                vue_f[i] = max(set(vs), key=vs.count); chg += 1
    if not chg: break
comp, n_ = composantes(vue_f)
def proj(co, k):
    x_, y_, z_ = co
    return ((x_, z_), (-x_, z_), (y_, z_), (-y_, z_), (x_, y_), (x_, -y_))[k]
for f in bm.faces:
    if main_f[f.index]: continue
    k_ = int(vue_f[f.index])
    off = Vector((comp[f.index] * 0.0, 0))
    for l in f.loops:
        u_, v_ = proj(l.vert.co, k_)
        l[la].uv = Vector((u_, v_)) + off
    f.select = False
for f in bm.faces:
    f.select = bool(main_f[f.index])
bm.to_mesh(mb); bm.free()
log("UV 6 vues : %d îlots projetés (face/dos/profils/dessus/dessous : %s), %d faces de main en dépliage automatique" % (
    n_, np.bincount(vue_f[~main_f], minlength=6).tolist(), int(main_f.sum())))
sel_seul(basse)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_mode(type="FACE")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale()
bpy.ops.object.mode_set(mode="OBJECT")
bm = bmesh.new(); bm.from_mesh(mb)
la = bm.loops.layers.uv["atlas"]
bm.faces.ensure_lookup_table()
# îlots UV (faces reliées par des arêtes non coupées en UV)
def cle_uv(l): return (round(l[la].uv.x, 6), round(l[la].uv.y, 6))
par = list(range(len(bm.faces)))
def rac(i):
    while par[i] != i:
        par[i] = par[par[i]]; i = par[i]
    return i
for e in bm.edges:
    if len(e.link_faces) != 2: continue
    f1, f2 = e.link_faces
    def uvs(f):
        d = {}
        for l in f.loops: d[l.vert.index] = cle_uv(l)
        return d
    u1, u2 = uvs(f1), uvs(f2)
    if all(u1.get(v.index) == u2.get(v.index) for v in e.verts):
        par[rac(f1.index)] = rac(f2.index)
ilots = {}
for f in bm.faces:
    ilots.setdefault(rac(f.index), []).append(f)
ECH = float(arg("ech_tete", "1.6"))
n_gr = 0
for fs in ilots.values():
    vs = {v.index for f in fs for v in f.verts}
    if np.mean([grand[i] for i in vs]) > 0.5:
        n_gr += 1
        ls = [l for f in fs for l in f.loops]
        c = sum((l[la].uv for l in ls), Vector((0, 0))) / len(ls)
        for l in ls:
            l[la].uv = c + (l[la].uv - c) * ECH
bm.to_mesh(mb); bm.free()
sel_seul(basse)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(rotate=True, margin=0.006, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
log("UV : %d îlots, %d agrandis (tête, mains)" % (len(ilots), n_gr))

# matière de cuisson : couleur de base x éclairage du relief (normale de la carte, lumière = normale géométrique relevée)
uv_src = haut.data.uv_layers[0].name
mhd = bpy.data.materials.new("hd_cuisson"); mhd.use_nodes = True
nt = mhd.node_tree; nt.nodes.clear()
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = uv_src
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = IMG_BC
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = IMG_NOR
nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = uv_src
geo = nt.nodes.new("ShaderNodeNewGeometry")
lv = nt.nodes.new("ShaderNodeVectorMath"); lv.operation = "ADD"; lv.inputs[1].default_value = (0, 0, 0.6)
ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "NORMALIZE"
dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"
mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = -0.2; mr.inputs[2].default_value = 1.0
mr.inputs[3].default_value = float(arg("ombre", "0.62")); mr.inputs[4].default_value = float(arg("lumiere", "1.22"))
mu = nt.nodes.new("ShaderNodeMix"); mu.data_type = "RGBA"; mu.blend_type = "MULTIPLY"; mu.inputs[0].default_value = 1.0
em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
for a_, b_ in ((uvn.outputs["UV"], ti.inputs["Vector"]), (uvn.outputs["UV"], tn.inputs["Vector"]), (tn.outputs["Color"], nm.inputs["Color"]),
               (geo.outputs["Normal"], lv.inputs[0]), (lv.outputs[0], ln.inputs[0]), (ln.outputs[0], dp.inputs[1]),
               (nm.outputs["Normal"], dp.inputs[0]), (dp.outputs["Value"], mr.inputs[0]), (ti.outputs["Color"], mu.inputs[6]),
               (mr.outputs[0], mu.inputs[7]), (mu.outputs[2], em.inputs["Color"]), (em.outputs[0], out.inputs[0])):
    nt.links.new(a_, b_)
haut.data.materials.clear(); haut.data.materials.append(mhd)
TB = int(arg("cuisson", "2048"))
CUIT = bpy.data.images.new("cuit", TB, TB, alpha=False)
mat = bpy.data.materials.new("joueur_%s" % SEXE); mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
cible = nt.nodes.new("ShaderNodeTexImage"); cible.image = CUIT; nt.nodes.active = cible
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(cible.outputs[0], bsdf.inputs["Base Color"]); nt.links.new(bsdf.outputs[0], out.inputs[0])
mb.materials.clear(); mb.materials.append(mat)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
sc.render.bake.margin = 24; sc.render.bake.margin_type = "EXTEND"; sc.render.bake.use_clear = True
sc.render.bake.use_selected_to_active = True; sc.render.bake.cage_extrusion = 0.015; sc.render.bake.max_ray_distance = 0.05
sel_seul(basse, haut, actif=basse)
bpy.ops.object.bake(type="EMIT")
log("cuisson %d px faite" % TB)
# réduction en atlas basse déf (moyenne par blocs : pas de flou de rééchantillonnage)
A = np.array(CUIT.pixels[:], dtype=np.float32).reshape(TB, TB, 4)
f = TB // TEX
A = A.reshape(TEX, f, TEX, f, 4).mean(axis=(1, 3))
# fond de l'atlas (hors îlots) rempli par la couleur des îlots voisins : la texture affine du PS1 déborde des îlots de près
cuit = np.array(CUIT.pixels[:], dtype=np.float32).reshape(TB, TB, 4)
plein = (cuit[:, :, :3].sum(2) > 0.003).reshape(TEX, f, TEX, f).mean(axis=(1, 3)) > 0.5
ok_ = plein.copy()
for _ in range(TEX):
    if ok_.all(): break
    acc = np.zeros_like(A[:, :, :3]); n_ = np.zeros(ok_.shape)
    for dy_, dx_ in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(ok_, (dy_, dx_), (0, 1)); col_ = np.roll(A[:, :, :3], (dy_, dx_), (0, 1))
        acc += col_ * sh[:, :, None]; n_ += sh
    neuf = (~ok_) & (n_ > 0)
    A[neuf, :3] = acc[neuf] / n_[neuf][:, None]
    ok_ = ok_ | neuf
A[:, :, 3] = 1.0
ATLAS = bpy.data.images.new("joueur_%s_atlas" % SEXE, TEX, TEX, alpha=False)
ATLAS.pixels[:] = A.ravel()
ATLAS.filepath_raw = os.path.join(os.path.dirname(ETAPE3), "joueur_%s_atlas_%d.png" % (SEXE, TEX))
ATLAS.file_format = "PNG"
os.makedirs(os.path.dirname(ETAPE3), exist_ok=True)
ATLAS.save()
ATLAS.pack()
cible.image = ATLAS
cible.interpolation = "Closest"
bsdf.inputs["Roughness"].default_value = 1.0
mb.uv_layers.remove(mb.uv_layers[0])          # UV source (inutile désormais)
bpy.data.objects.remove(haut)
log("atlas %d px" % TEX)

os.makedirs(os.path.dirname(ETAPE3), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=ETAPE3)
log("ÉTAPE 3 FINIE :", ETAPE3)
if arg("jusqua") == "3":
    sys.exit(0)
exec(open(RIG, encoding="utf-8").read())
