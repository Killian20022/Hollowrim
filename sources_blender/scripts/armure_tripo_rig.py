# Armure dorée Tripo -> armure COMPLÈTE habillée sur le squelette humain du jeu (65 os de homme_vetu.glb).
#   blender.exe -b --python armure_tripo_rig.py -- [--source=<planche.glb>] [--cache=<pieces.blend>] [--etape=ajuster|tout] [--debug=<dossier>]
# Source : « fantasy armor 3d model.glb » (Tripo) = PLANCHE de présentation, chaque pièce 3 fois (face, profil, dos), 1 M de sommets.
# On garde la vue de FACE de chaque pièce (modèle 3D complet tourné vers -y), on la pose à l'échelle d'un humain de 1,81 m (pose de repos
# des bras abaissée en A, l'angle des manches de la cuirasse), puis : allègement adaptatif, atlas 512 recuit, miroir des pièces paires
# (gantelet, jambière, botte), poids transférés du corps (lissés), export d'un GLB habillé (assets/essai_tripo/armure_complete.glb).
# Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = arg("source", r"C:\Users\lopezk19\Downloads\fantasy armor 3d model.glb")
CACHE = arg("cache", os.path.join(os.environ.get("TEMP", "C:\\Temp"), "armure_tripo_pieces.blend"))
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "essai_tripo", "armure_complete.glb"))
ETAPE = arg("etape", "tout")
DEBUG = arg("debug", "")

# Boîtes (x, z) de la vue de face de chaque pièce sur la planche.
BOITES = {"casque": (-0.495, -0.37, 0.44, 1), "cuirasse": (-0.055, 0.17, 0.44, 1), "gantelet": (-0.48, -0.36, 0.15, 0.44),
          "jambiere": (0.05, 0.16, 0.15, 0.44), "botte": (-0.195, -0.10, -1, 0.15)}
# Budget de triangles par pièce UNIQUE (les pièces paires sont doublées par miroir) : ~7 500 au total.
BUDGET = {"casque": 1300, "cuirasse": 2900, "gantelet": 500, "jambiere": 700, "botte": 450, "main": 100000}
ALPHA = float(arg("alpha", "74"))     # bras abaissés de ALPHA degrés sous l'horizontale (angle des manches de la cuirasse)

# ---------------------------------------------------------------- 0. pièces de face (cache)
def extraire():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    src = next(o for o in bpy.data.objects if o.type == "MESH")
    P = np.empty(len(src.data.vertices) * 3); src.data.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    for nom, (x0, x1, z0, z1) in BOITES.items():
        sel = (P[:, 0] > x0) & (P[:, 0] < x1) & (P[:, 2] >= z0) & (P[:, 2] < z1)
        o = src.copy(); o.data = src.data.copy(); o.name = nom; o.data.name = nom
        bpy.context.collection.objects.link(o)
        bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not sel[v.index]], context="VERTS")
        bm.to_mesh(o.data); bm.free()
    bpy.data.objects.remove(src)
    for im in bpy.data.images:
        if im.size[0] > 0:
            im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=CACHE)

if not os.path.exists(CACHE):
    extraire()
bpy.ops.wm.open_mainfile(filepath=CACHE)
PIECES = {o.name: o for o in bpy.data.objects if o.type == "MESH"}

def pts(o):
    P = np.empty(len(o.data.vertices) * 3); o.data.vertices.foreach_get("co", P); return P.reshape(-1, 3)
def set_pts(o, P):
    o.data.vertices.foreach_set("co", P.astype(np.float32).ravel()); o.data.update()

# ---------------------------------------------------------------- 1. squelette : bras abaissés en A, appliqué au repos
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
corps = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("SuperHero"))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in PIECES.values() and o != corps:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    pb = arm.pose.bones["upperarm_" + s]
    h = arm.matrix_world @ pb.head
    q = Matrix.Rotation(math.radians(ALPHA) * sg, 4, "Y")
    pb.matrix = Matrix.Translation(h) @ q @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.objects.active = corps
for m in corps.modifiers:
    if m.type == "ARMATURE":
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
CORPS_P = np.array([v.co[:] for v in corps.data.vertices])
B = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
def tete(n): return np.array(B[n][0][:])
def queue(n): return np.array(B[n][1][:])

# ---------------------------------------------------------------- 2. pose des pièces (côté gauche pour les paires)
def normaliser(o):
    """Centre la pièce : x, y au milieu de la boîte, z min à 0."""
    P = pts(o)
    c = np.array([(P[:, 0].min() + P[:, 0].max()) / 2, (P[:, 1].min() + P[:, 1].max()) / 2, P[:, 2].min()])
    return P - c

def poser_casque(o):
    P = normaliser(o)
    s = float(arg("s_casque", "2.15"))
    P *= s
    # base de la tête : le menton ; le casque descend sur la nuque (bas du casque ~ 1,50)
    P += np.array([0, float(arg("y_casque", "-0.005")), float(arg("z_casque", "1.46"))])
    set_pts(o, P)

def poser_cuirasse(o):
    P = normaliser(o)          # z 0 = bas des tassettes ; taille (ceinture) à z 0,06 ; col à 0,205
    sx, sy, sz = (float(v) for v in arg("s_cuirasse", "4.1,3.7,4.0").split(","))
    P *= np.array([sx, sy, sz])
    P += np.array([0, float(arg("y_cuirasse", "0.005")), float(arg("z_cuirasse", "0.80"))])
    set_pts(o, P)

def lisse01(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
def dseg(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
def pseg(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1); return a + t[:, None] * ab

def affiner_cuirasse(o):
    """Silhouette d'un garde : torse resserré vers l'axe du corps (largeur kx, profondeur ky), épaulières rentrées (ke au-delà de
    x0), manches resserrées autour de l'os du bras (km) ; fondu entre torse et manches (même règle que les poids)."""
    P = pts(o)
    kx, ky = (float(v) for v in arg("k_torse", "0.88,0.88").split(","))
    ke, x0, km = float(arg("k_epaule", "0.8")), float(arg("x_epaule", "0.14")), float(arg("k_manche", "0.9"))
    pel, cou = tete("pelvis"), tete("neck_01")
    yc = np.interp(P[:, 2], [pel[2], cou[2]], [pel[1], cou[1]])
    T = P.copy()
    ax_ = np.abs(P[:, 0])
    haut = lisse01((P[:, 2] - (cou[2] - 0.30)) / 0.12)             # épaulières : seulement en haut du torse
    xe = np.where(ax_ > x0, x0 * kx + (ax_ - x0) * (kx * (1 - haut) + ke * haut), ax_ * kx)
    T[:, 0] = np.sign(P[:, 0]) * xe
    T[:, 1] = yc + (P[:, 1] - yc) * ky
    d_tor = dseg(P, pel, cou)
    for s_ in ("l", "r"):
        segs = [(tete("upperarm_" + s_), tete("lowerarm_" + s_)), (tete("lowerarm_" + s_), tete("hand_" + s_))]
        ds = np.stack([dseg(P, a, b) for a, b in segs]); qs = np.stack([pseg(P, a, b) for a, b in segs])
        ib = np.argmin(ds, axis=0); d_b = ds.min(0); q = qs[ib, np.arange(len(P))]
        cote = (P[:, 0] > 0) if s_ == "l" else (P[:, 0] < 0)
        m = lisse01((float(arg("manche", "0.75")) * d_tor - d_b) / 0.05 + 0.5) * cote
        A = q + (P - q) * km
        T = T * (1 - m[:, None]) + A * m[:, None]
    set_pts(o, T)
    print("CUIRASSE affinée : %s -> %s" % (P.min(0).round(3), T.max(0).round(3)))

def poser_gantelet(o):
    # source = main DROITE pendante (doigts vers -z, dos de la main vers -y, pouce vers +x) -> main gauche par miroir x,
    # puis doigts le long de l'avant-bras gauche (abaissé de ALPHA), dos de la main vers le haut/l'extérieur
    P = normaliser(o)
    P[:, 0] *= -1                                            # main gauche
    z1 = P[:, 2].max()
    s = float(arg("s_gantelet", "2.5"))
    P *= s
    P[:, :2] *= float(arg("k_canon", "0.86"))                   # canon moins épais (avant-bras humain), même longueur
    P[:, 2] -= z1 * s                                       # haut du canon (coude) à z 0, doigts vers -z
    # repère : doigts (-z) -> axe de l'avant-bras ; dos de la main (-y) -> haut/extérieur (perpendiculaire dans le plan frontal)
    coude, poignet = tete("lowerarm_l"), tete("hand_l")
    ax = (poignet - coude) / np.linalg.norm(poignet - coude)
    up = np.array([0, 0, 1.0]); dos = up - ax * ax.dot(up); dos /= np.linalg.norm(dos)
    av = np.cross(ax, dos)                                   # direction perpendiculaire restante
    # colonnes : image de (x, y, z) source
    #   -z (doigts) -> ax ; -y (dos) -> dos ; x (pouce, côté extérieur de la main gauche après miroir... ) -> complète le repère direct
    R = np.column_stack([np.cross(dos, ax) * 1.0, -dos, -ax])   # x' = ?, y -> -dos, z -> -ax
    if np.linalg.det(R) < 0:
        R[:, 0] *= -1
    P = P @ R.T
    P += coude + ax * float(arg("d_gantelet", "-0.08")) + dos * float(arg("h_gantelet", "0.0"))
    set_pts(o, P)

def poser_jambiere(o):
    P = normaliser(o)          # z 0 = bas du pied de la jambière
    zc = float(arg("coupe_jambe", "0.068"))                 # coupe au-dessus du soleret intégré (la botte le remplace)
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    garde = P[:, 2] >= zc
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not garde[v.index]], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    P = P[garde]
    # z : cheville (source 0,069) -> 0,20 (dans le revers de la botte), genou (0,142) -> 0,542, haut (0,242) -> 1,0
    ks = [float(v) for v in arg("k_jambe", "0.068,0.142,0.242").split(",")]
    kd = [float(v) for v in arg("k_jambe_d", "0.19,0.53,1.0").split(",")]
    P[:, 2] = np.interp(P[:, 2], ks, kd, left=None, right=None)
    sx, sy = (float(v) for v in arg("s_jambe", "2.9,3.0").split(","))
    P[:, 0] *= sx; P[:, 1] *= sy
    P[:, 0] += tete("thigh_l")[0] + float(arg("x_jambe", "0.0"))
    # axe de la jambière recalé sur celui de la jambe du corps (le mollet est en arrière de la cuisse) : décalage en y lissé par tranche
    C = CORPS_P[(CORPS_P[:, 0] > 0.02) & (CORPS_P[:, 0] < 0.35)]
    zs = np.arange(0.15, 1.05, 0.05); dec = []
    for z in zs:
        c = C[(C[:, 2] >= z - 0.05) & (C[:, 2] < z + 0.05)]; a = P[(P[:, 2] >= z - 0.05) & (P[:, 2] < z + 0.05)]
        dec.append(((c[:, 1].min() + c[:, 1].max()) - (a[:, 1].min() + a[:, 1].max())) / 2 if len(c) and len(a) else np.nan)
    dec = np.array(dec); ok = ~np.isnan(dec)
    dec = np.interp(zs, zs[ok], dec[ok]); dec = np.convolve(np.pad(dec, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    P[:, 1] += np.interp(P[:, 2], zs, dec) + float(arg("y_jambe", "0.0"))
    set_pts(o, P)

def poser_botte(o):
    # botte AJUSTÉE au pied du corps : longueur du talon à la pointe = pied + jeu, semelle à plat au niveau de la plante du pied,
    # talon calé sur le talon du corps (ni trop longue, ni enfoncée, ni flottante)
    P = normaliser(o)
    F = CORPS_P[(CORPS_P[:, 0] > 0.02) & (CORPS_P[:, 2] < 0.10)]
    long_pied = F[:, 1].max() - F[:, 1].min()
    s = (long_pied + float(arg("jeu_botte", "0.03"))) / (P[:, 1].max() - P[:, 1].min())
    P *= s
    P[P[:, 2] < float(arg("semelle", "0.012")), 2] = 0.0             # semelle plane
    P += np.array([(F[:, 0].min() + F[:, 0].max()) / 2 - (P[:, 0].min() + P[:, 0].max()) / 2 + float(arg("x_botte", "0.0")),
                   F[:, 1].max() + float(arg("talon", "0.014")) - P[:, 1].max(), F[:, 2].min() - P[:, 2].min()])
    print("BOTTE échelle %.3f ; pied %.3f m de long, botte %s -> %s" % (s, long_pied, P.min(0).round(3), P.max(0).round(3)))
    set_pts(o, P)

for nom, f in (("casque", poser_casque), ("cuirasse", poser_cuirasse), ("gantelet", poser_gantelet), ("jambiere", poser_jambiere), ("botte", poser_botte)):
    f(PIECES[nom])
    if nom == "cuirasse":
        affiner_cuirasse(PIECES[nom])
    P = pts(PIECES[nom])
    print("POSE %-9s %7d sommets  min %s  max %s" % (nom, len(P), P.min(0).round(3), P.max(0).round(3)))

# ---------------------------------------------------------------- 2b. main de gantelet reconstruite (la main Tripo, recourbée en griffe,
# ne se pose pas proprement) : plaque du dos de la main + 4 doigts et pouce en lames dorées articulées, mi-fermés, sur les os du corps ;
# UV de chaque face pris sur la face la plus proche ET de même orientation du gantelet source (dos des lames dorées, paume en cuir).
# Le gantelet source est ensuite coupé au poignet : il ne reste que son canon d'avant-bras.
def rot(v, ang, k):
    k = k / np.linalg.norm(k); return v * math.cos(ang) + np.cross(k, v) * math.sin(ang) + k * (k @ v) * (1 - math.cos(ang))
def nrm(v): return v / np.linalg.norm(v)
def construire_main(donneur):
    me_d = donneur.data
    uvd = me_d.uv_layers[0]
    C = np.array([p.center[:] for p in me_d.polygons]); N = np.array([p.normal[:] for p in me_d.polygons])
    UV = [[uvd.data[li].uv[:] for li in p.loop_indices] for p in me_d.polygons]
    im = next(nd.image for m in me_d.materials if m for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and "basecolor" in nd.image.name)
    W, H = im.size; PX = np.array(im.pixels[:]).reshape(H, W, 4)
    def clair(uvs):
        t = np.array(uvs); xs = (t[:, 0] % 1 * (W - 1)).astype(int); ys = (t[:, 1] % 1 * (H - 1)).astype(int)
        mid = t.mean(0); xm = int(mid[0] % 1 * (W - 1)); ym = int(mid[1] % 1 * (H - 1))
        return (PX[ys, xs, :3].sum(1).min() + PX[ym, xm, :3].sum()) / 2
    CLAIR = np.array([clair(u) for u in UV])
    h0 = tete("hand_l")
    k = np.mean([tete(f + "_01_l") for f in ("index", "middle", "ring", "pinky")], axis=0)
    axh = nrm(k - h0)
    cote = nrm(tete("index_01_l") - tete("pinky_01_l"))
    dos = nrm(np.cross(cote, axh))
    paume = -dos
    bm = bmesh.new()
    ROLE = {}
    def boite(a, b, u, w, t, fin=0.92, haut=0.78, dz=0.0):
        d = nrm(b - a); u = nrm(u - d * (d @ u)); sd = np.cross(d, u)
        vs = []
        for c, f in ((a, 1.0), (b, fin)):
            c = c + u * dz
            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vs.append(bm.verts.new(c + sd * x * w / 2 * f * (haut if y > 0 else 1.0) + u * y * t / 2 * f))
        for q, r in (((0, 1, 2, 3), "or"), ((4, 7, 6, 5), "or"), ((0, 4, 5, 1), "cuir"), ((1, 5, 6, 2), "or"), ((2, 6, 7, 3), "or"), ((3, 7, 4, 0), "or")):
            ROLE[bm.faces.new([vs[i] for i in q])] = r
    # dos de la main : du canon (rentré dedans) aux jointures, plus large que la main du corps
    larg = np.linalg.norm(tete("index_01_l") - tete("pinky_01_l")) + float(arg("main_larg", "0.015"))
    centre_k = (tete("index_01_l") + tete("pinky_01_l")) / 2
    boite(h0 - axh * 0.02, centre_k + axh * 0.004, dos, larg * 0.9, float(arg("main_ep", "0.022")), fin=1.06, haut=0.68, dz=0.004)
    boite(centre_k - axh * 0.018, centre_k + axh * 0.012, dos, larg * 0.98, 0.036, fin=1.0, haut=0.72, dz=0.008)   # garde des jointures
    # doigts : 3 lames chacun, mi-fermés vers la paume
    angles = [math.radians(float(v)) for v in arg("doigts_angles", "24,40,28").split(",")]
    for f, w in (("index", 0.021), ("middle", 0.022), ("ring", 0.021), ("pinky", 0.018)):
        a = tete(f + "_01_l"); d0 = nrm(queue(f + "_01_l") - a)
        L = [np.linalg.norm(queue(f + "_0%d_l" % i) - tete(f + "_0%d_l" % i)) for i in (1, 2, 3)]
        L[2] += 0.5 * np.linalg.norm(queue(f + "_04_leaf_l") - tete(f + "_04_leaf_l"))
        kx = np.cross(d0, paume); cum = 0.0; p0 = a - d0 * 0.008
        for i in range(3):
            cum += angles[i]
            d = rot(d0, cum, kx); u = rot(dos, cum, kx)
            p1 = p0 + d * (L[i] + (0.008 if i == 0 else 0.0))
            boite(p0 - d * 0.005, p1, u, w, 0.019, fin=0.6 if i == 2 else 0.92, dz=0.002)
            p0 = p1
    # pouce : 2 lames ; la seconde vient se poser devant la 2e phalange de l'index, côté paume (pouce refermé sur les doigts)
    a = tete("thumb_01_l"); d0 = nrm(queue("thumb_01_l") - a)
    L1 = np.linalg.norm(queue("thumb_01_l") - a) + np.linalg.norm(queue("thumb_02_l") - tete("thumb_02_l")) * 0.6
    p1 = a - d0 * 0.008 + d0 * L1
    boite(a - d0 * 0.012, p1, dos, 0.027, 0.024, fin=0.95)
    ci = tete("index_02_l") + paume * float(arg("pouce_avant", "0.022"))
    d2 = nrm(ci - p1); L2 = min(np.linalg.norm(ci - p1), 0.055)
    boite(p1 - d2 * 0.006, p1 + d2 * L2, dos - d2 * (d2 @ dos), 0.024, 0.021, fin=0.62)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # arêtes chanfreinées : lames arrondies plutôt que des briques
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=float(arg("main_chanfrein", "0.0035")), segments=1, affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    uvl = bm.loops.layers.uv.new(uvd.name)
    # projection par sommet sur la surface du gantelet source (posé sur la même main) : le dos doré, les lames des doigts
    # et le cuir de la paume gardent leur dessin ; si les coins d'une face tombent sur des îlots différents, repli sur une face entière
    from mathutils.bvhtree import BVHTree
    from mathutils import geometry as mgeo
    bmd = bmesh.new(); bmd.from_mesh(me_d); bmesh.ops.triangulate(bmd, faces=bmd.faces); bmd.faces.ensure_lookup_table()
    uvdl = bmd.loops.layers.uv[uvd.name]
    arbre = BVHTree.FromBMesh(bmd)
    Minv = donneur.matrix_world.inverted()
    print("MAIN donneur matrice identité :", donneur.matrix_world == Matrix.Identity(4))
    def uv_proj(p):
        loc, nor, fi, dist = arbre.find_nearest(Minv @ Vector(p))
        f = bmd.faces[fi]; v = [l.vert.co for l in f.loops]; t = [Vector((*l[uvdl].uv, 0)) for l in f.loops]
        r = mgeo.barycentric_transform(loc, v[0], v[1], v[2], t[0], t[1], t[2])
        return (r.x, r.y), dist
    ecart_max = float(arg("main_ecart_uv", "0.03"))
    n_proj = 0; DIAG = []
    for fa in bm.faces:
        res = [uv_proj(l.vert.co) for l in fa.loops]
        u4 = [r[0] for r in res]; U = np.array(u4)
        cote3d = max((fa.loops[i].vert.co - fa.loops[i - 1].vert.co).length for i in range(len(fa.loops)))
        DIAG.append((np.ptp(U, axis=0).max(), max(r[1] for r in res), cote3d))
        if np.ptp(U, axis=0).max() < ecart_max * max(cote3d / 0.03, 1.0) and max(r[1] for r in res) < float(arg("main_dist", "0.15")):
            for lo, uv in zip(fa.loops, u4):
                lo[uvl].uv = uv
            n_proj += 1
            continue
        c = np.array(fa.calc_center_median()[:]); n = np.array(fa.normal[:])
        # lames : dos doré du gantelet source (faces tournées vers le dos de la main) ; dessous : cuir de la paume
        ok = (N @ dos) > 0.5 if ROLE.get(fa, "or") == "or" else (N @ dos) < -0.5
        cand = np.nonzero(ok)[0] if ok.any() else np.arange(len(C))
        proches = cand[np.argsort(np.linalg.norm(C[cand] - c, axis=1))[:int(arg("main_voisins", "300"))]]
        # parmi les faces voisines, la plus claire pour l'or (évite les creux sombres), la plus proche pour le cuir
        j = proches[np.argmax(CLAIR[proches])] if ROLE.get(fa, "or") == "or" else proches[0]
        u = UV[j]; u4 = [u[0], u[1], u[2], (u[0][0] + u[2][0] - u[1][0], u[0][1] + u[2][1] - u[1][1]) if len(u) == 3 else u[3]]
        for lo, uv in zip(fa.loops, u4):
            lo[uvl].uv = uv
    print("MAIN UV projetées %d / %d faces" % (n_proj, len(bm.faces))); bmd.free()
    D = np.array(DIAG); print("MAIN DIAG ecart uv", np.percentile(D[:, 0], [10, 50, 90]).round(3), "dist", np.percentile(D[:, 1], [10, 50, 90]).round(3), "cote", np.percentile(D[:, 2], [10, 50, 90]).round(3))
    me_m = bpy.data.meshes.new("main"); bm.to_mesh(me_m); bm.free()
    om = bpy.data.objects.new("main", me_m); bpy.context.collection.objects.link(om)
    for mt in me_d.materials:
        me_m.materials.append(mt)
    return om

def couper_poignet(o):
    coude, poignet = tete("lowerarm_l"), tete("hand_l")
    ax = nrm(poignet - coude)
    lim = np.linalg.norm(poignet - coude) + float(arg("canon_bout", "0.015"))
    P = pts(o)
    hors = (P - coude) @ ax > lim
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if hors[v.index]], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    print("GANTELET coupé au poignet : %d sommets retirés" % int(hors.sum()))

PIECES["main"] = construire_main(PIECES["gantelet"])
couper_poignet(PIECES["gantelet"])
print("MAIN %d faces" % len(PIECES["main"].data.polygons))

def miroir(o, nom):
    m = o.copy(); m.data = o.data.copy(); m.name = nom; m.data.name = nom
    bpy.context.collection.objects.link(m)
    P = pts(m); P[:, 0] *= -1; set_pts(m, P)
    m.data.flip_normals()
    return m

if DEBUG:
    os.makedirs(DEBUG, exist_ok=True)
    for nom in ("gantelet", "main", "jambiere", "botte"):
        miroir(PIECES[nom], nom + "_r")
    mat = bpy.data.materials.new("corps_gris"); mat.diffuse_color = (0.25, 0.3, 0.45, 1)
    corps.data.materials.clear(); corps.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading; sh.light = "STUDIO"; sh.color_type = "TEXTURE"
    sc.render.resolution_x = 700; sc.render.resolution_y = 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.0
    for v, d, c, os_ in (("face", (0, -1, 0), (0, 0, 0.92), 2.0), ("profil", (1, 0, 0), (0, 0, 0.92), 2.0), ("dos", (0, 1, 0), (0, 0, 0.92), 2.0),
                         ("q", (0.7, -0.7, 0.3), (0, 0, 0.92), 2.0), ("jambes", (0.5, -0.85, 0.1), (0.1, 0, 0.5), 1.1), ("bras", (0.3, -0.9, 0.2), (0.45, 0, 1.2), 0.9),
                         ("tete", (0.4, -0.9, 0.1), (0, 0, 1.6), 0.7), ("bras_dos", (0.2, 0.9, 0.3), (0.4, 0, 1.25), 0.9)):
        d = Vector(d).normalized()
        cam.data.ortho_scale = os_
        cam.location = Vector(c) + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(DEBUG, "ajuste_%s.png" % v)
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "ajuste.blend"))
if ETAPE == "ajuster":
    sys.exit(0)

# ---------------------------------------------------------------- 3. allègement adaptatif (par pièce, budget de triangles)
def bords(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    n = sum(1 for e in bm.edges if e.is_boundary); bm.free(); return n
HD = {}
for nom, o in PIECES.items():
    h = o.copy(); h.data = o.data.copy(); h.name = nom + "_hd"; bpy.context.collection.objects.link(h); HD[nom] = h
for nom, o in PIECES.items():
    avant = len(o.data.polygons); b0 = bords(o)
    if BUDGET[nom] >= avant:
        continue
    md = o.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = BUDGET[nom] / avant
    md.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)
    print("ALLEGE %-9s %7d -> %5d tris ; arêtes de bord %d -> %d" % (nom, avant, len(o.data.polygons), b0, bords(o)))

# ---------------------------------------------------------------- 4. atlas commun 512 recuit depuis la texture 4K d'origine
for o in bpy.data.objects:
    o.select_set(False)
ordre = ["casque", "cuirasse", "gantelet", "main", "jambiere", "botte"]
for i, nom in enumerate(ordre):
    o = PIECES[nom]
    vg = o.vertex_groups.new(name="piece_" + nom); vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    o.select_set(True)
bpy.context.view_layer.objects.active = PIECES["casque"]
bpy.ops.object.join()
armure = PIECES["casque"]; armure.name = "armure"; armure.data.name = "armure"
uv_src = armure.data.uv_layers[0].name
uv_at = armure.data.uv_layers.new(name="atlas", do_init=True)
armure.data.uv_layers.active = uv_at
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
# îlots d'UV d'origine (copiés de la carte source), mis à densité égale puis tassés dans un atlas neuf
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(rotate=True, margin=0.004, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
mats_src = [m for m in armure.data.materials if m]
def image_src(cle):
    return next(nd.image for m in mats_src for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and cle in nd.image.name)
img_src, img_nor = image_src("basecolor"), image_src("normal")
img_nor.colorspace_settings.name = "Non-Color"
# matière de cuisson des pièces HD : couleur de base x éclairage du relief (carte normale, lumière haute de face) -> l'or reste lisible
# sur le maillage allégé (le shader ps1 n'a pas de carte normale)
mhd = bpy.data.materials.new("hd_cuisson"); mhd.use_nodes = True
nt = mhd.node_tree; nt.nodes.clear()
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = uv_src
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img_src
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img_nor
nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = uv_src
# lumière = normale GÉOMÉTRIQUE relevée vers le haut (et non une direction fixe de face, qui cuisait le dos dans l'ombre) :
# le relief de la carte normale ressort pareil de face, de dos et de profil, plus clair sur le dessus des lames
geo = nt.nodes.new("ShaderNodeNewGeometry")
lv = nt.nodes.new("ShaderNodeVectorMath"); lv.operation = "ADD"; lv.inputs[1].default_value = (0, 0, float(arg("haut", "0.8")))
ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "NORMALIZE"
nt.links.new(geo.outputs["Normal"], lv.inputs[0]); nt.links.new(lv.outputs[0], ln.inputs[0])
dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"; nt.links.new(ln.outputs[0], dp.inputs[1])
mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = -0.3; mr.inputs[2].default_value = 1.0
mr.inputs[3].default_value = float(arg("ombre", "0.4")); mr.inputs[4].default_value = float(arg("lumiere", "1.4"))
gm = nt.nodes.new("ShaderNodeGamma"); gm.inputs[1].default_value = float(arg("gamma", "1.1"))
mu = nt.nodes.new("ShaderNodeMix"); mu.data_type = "RGBA"; mu.blend_type = "MULTIPLY"; mu.inputs[0].default_value = 1.0
em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
for a, b in ((uvn.outputs["UV"], ti.inputs["Vector"]), (uvn.outputs["UV"], tn.inputs["Vector"]), (tn.outputs["Color"], nm.inputs["Color"]),
             (nm.outputs["Normal"], dp.inputs[0]), (dp.outputs["Value"], mr.inputs[0]), (ti.outputs["Color"], gm.inputs[0]),
             (gm.outputs[0], mu.inputs[6]), (mr.outputs[0], mu.inputs[7]), (mu.outputs[2], em.inputs["Color"]), (em.outputs[0], out.inputs[0])):
    nt.links.new(a, b)
# main reconstruite : ses UV sont des lames recopiées (orientation quelconque) -> la carte normale y serait lue de travers
# (lames cuites dans l'ombre) ; on l'éclaire par sa normale géométrique seule
mhd_main = mhd.copy(); ntm = mhd_main.node_tree
dpm = next(n for n in ntm.nodes if n.type == "VECT_MATH" and n.operation == "DOT_PRODUCT")
ntm.links.new(next(n for n in ntm.nodes if n.type == "NEW_GEOMETRY").outputs["Normal"], dpm.inputs[0])
for nom, h in HD.items():
    h.data.materials.clear(); h.data.materials.append(mhd_main if nom == "main" else mhd)
CUIT = bpy.data.images.new("armure_cuit", 1024, 1024)
mat = bpy.data.materials.new("armure_cuisson"); mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
cible = nt.nodes.new("ShaderNodeTexImage"); cible.image = CUIT; nt.nodes.active = cible
em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], out.inputs[0])
armure.data.materials.clear(); armure.data.materials.append(mat)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
sc.render.bake.margin = 6; sc.render.bake.use_clear = True
sc.render.bake.use_selected_to_active = True; sc.render.bake.cage_extrusion = 0.03; sc.render.bake.max_ray_distance = 0.08
for o in bpy.data.objects:
    o.select_set(o == armure or (o in HD.values() and o != HD["main"]))
bpy.context.view_layer.objects.active = armure
bpy.ops.object.bake(type="EMIT")
# main reconstruite : lames serrées qui se chevauchent -> une cage de 3 cm tombait sur les lames voisines (dessous en cuir, creux) ;
# seconde cuisson de ses seules faces, cage de quelques mm, sans effacer le reste de l'atlas
am = armure.copy(); am.data = armure.data.copy(); am.name = "armure_main"; bpy.context.collection.objects.link(am)
gi = am.vertex_groups["piece_main"].index
garde = np.array([any(g.group == gi and g.weight > 0.5 for g in v.groups) for v in am.data.vertices])
bm = bmesh.new(); bm.from_mesh(am.data); bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not garde[v.index]], context="VERTS")
bm.to_mesh(am.data); bm.free()
for o in bpy.data.objects:
    o.select_set(o == am or o == HD["main"])
bpy.context.view_layer.objects.active = am
sc.render.bake.use_clear = False; sc.render.bake.margin = 2
sc.render.bake.cage_extrusion = 0.003; sc.render.bake.max_ray_distance = 0.02
bpy.ops.object.bake(type="EMIT")
bpy.data.objects.remove(am)
CUIT.scale(512, 512)
# reflets d'or relevés sur les arêtes claires (les lames restent lisibles de dos, à contre-jour) ; ombres inchangées
px = np.array(CUIT.pixels[:]).reshape(-1, 4)
lum = px[:, :3] @ np.array([0.3, 0.55, 0.15])
k = np.clip((lum - 0.3) / 0.45, 0, 1); k = k * k * (3 - 2 * k)
px[:, :3] = np.clip(px[:, :3] * (1 + float(arg("reflets", "0.4")) * k[:, None]), 0, 1)
CUIT.pixels[:] = px.ravel()
TEX = os.path.splitext(OUT_GLB)[0] + "_tex.png"
CUIT.filepath_raw = TEX; CUIT.file_format = "PNG"; CUIT.save()
print("ATLAS", TEX)
for h in HD.values():
    bpy.data.objects.remove(h)
armure.data.uv_layers.remove(armure.data.uv_layers[uv_src])
nt.nodes.clear()
bs = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = CUIT; ti.interpolation = "Closest"
nt.links.new(ti.outputs["Color"], bs.inputs["Base Color"]); nt.links.new(bs.outputs[0], out.inputs[0])
bs.inputs["Roughness"].default_value = 0.8
mat.name = "armure_or"

# ---------------------------------------------------------------- 5. poids : k plus proches sommets du corps, os autorisés par pièce, lissés
from mathutils import kdtree
cnoms = [g.name for g in corps.vertex_groups]
W = np.zeros((len(corps.data.vertices), len(cnoms)))
for v in corps.data.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
kd = kdtree.KDTree(len(CORPS_P))
for i, p in enumerate(CORPS_P):
    kd.insert(Vector(p), i)
kd.balance()
DOIGTS = ("thumb", "index", "middle", "ring", "pinky")
def permis(nom, os_):
    if nom == "casque":
        return os_ in ("Head",)
    if nom == "cuirasse":
        return os_ in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "thigh_l", "thigh_r") or os_.startswith(("clavicle", "upperarm", "lowerarm"))
    if nom == "gantelet":
        return os_.endswith("_l") and (os_.startswith(("lowerarm", "hand")) or os_.startswith(DOIGTS))
    if nom == "main":
        return os_ == "hand_l"
    if nom == "jambiere":
        return os_ in ("thigh_l", "calf_l", "foot_l")
    if nom == "botte":
        return os_ in ("calf_l", "foot_l", "ball_l")
    return False
me = armure.data
AP = np.array([v.co[:] for v in me.vertices])
piece_de = np.full(len(AP), "", dtype=object)
for nom in ordre:
    gi = armure.vertex_groups["piece_" + nom].index
    for v in me.vertices:
        if any(g.group == gi and g.weight > 0.5 for g in v.groups):
            piece_de[v.index] = nom
masques = {nom: np.array([permis(nom, n) for n in cnoms]) for nom in ordre}
# cuirasse : les MANCHES (sommets plus près de l'os du bras que de l'axe du torse) ne suivent que le bras (sinon elles restent au torse
# quand le bras se rabat et découvrent l'épaule) ; le torse ne prend pas les os des bras
d_tor = dseg(AP, tete("pelvis"), tete("neck_01"))
for s_ in ("l", "r"):
    d_bras = np.minimum(dseg(AP, tete("upperarm_" + s_), tete("lowerarm_" + s_)), dseg(AP, tete("lowerarm_" + s_), tete("hand_" + s_)))
    m_bras = np.array([n in ("upperarm_" + s_, "lowerarm_" + s_, "clavicle_" + s_) for n in cnoms])
    manche = (piece_de == "cuirasse") & (d_bras < d_tor * float(arg("manche", "0.75")))
    masques["manche_" + s_] = m_bras
    piece_de[manche] = "manche_" + s_
    print("MANCHE", s_, int(manche.sum()), "sommets")
masques["cuirasse"] = masques["cuirasse"] & ~np.array([n.startswith(("upperarm", "lowerarm")) for n in cnoms])
AW = np.zeros((len(AP), len(cnoms)))
for i, p in enumerate(AP):
    nom = piece_de[i]
    voisins = kd.find_n(Vector(p), 12)
    acc = np.zeros(len(cnoms))
    for co, j, d in voisins:
        acc += W[j] / (d + 0.01) ** 2
    acc *= masques[nom]
    if acc.sum() < 1e-9:
        acc = masques[nom].astype(float)
    AW[i] = acc / acc.sum()
# lissage laplacien sur les arêtes de l'armure (chaque pièce se lisse sur elle-même)
E = np.array([e.vertices[:] for e in me.edges])
for it in range(int(arg("lissage", "6"))):
    S = np.zeros_like(AW); n = np.zeros(len(AP))
    np.add.at(S, E[:, 0], AW[E[:, 1]]); np.add.at(S, E[:, 1], AW[E[:, 0]])
    np.add.at(n, E[:, 0], 1); np.add.at(n, E[:, 1], 1)
    AW = 0.5 * AW + 0.5 * S / np.maximum(n, 1)[:, None]
# bottes : poids nets par zones (le lissage tordait la pointe et la cheville) : tige -> mollet au-dessus de la cheville, pointe -> ball
# au-delà de la jointure des orteils, le reste -> pied ; fondus courts
ib = np.nonzero(piece_de == "botte")[0]
jc, jf, jb = cnoms.index("calf_l"), cnoms.index("foot_l"), cnoms.index("ball_l")
wc = lisse01((AP[ib, 2] - float(arg("cheville_z", "0.115"))) / 0.05)
wb = lisse01((tete("ball_l")[1] + 0.012 - AP[ib, 1]) / 0.024) * (1 - wc)
AW[ib] = 0.0
AW[ib, jc] = wc; AW[ib, jb] = wb; AW[ib, jf] = 1 - wc - wb
# 4 influences au plus, normalisé
idx = np.argsort(-AW, axis=1)[:, 4:]
np.put_along_axis(AW, idx, 0.0, axis=1)
AW /= AW.sum(1, keepdims=True)
for g in list(armure.vertex_groups):
    armure.vertex_groups.remove(g)
VG = [armure.vertex_groups.new(name=n) for n in cnoms]
for j in range(len(cnoms)):
    nz = np.nonzero(AW[:, j] > 1e-4)[0]
    for i in nz:
        VG[j].add([int(i)], float(AW[i, j]), "REPLACE")
print("POIDS ok ; os utilisés :", sorted({cnoms[j] for j in range(len(cnoms)) if AW[:, j].max() > 0.05}))

# ---------------------------------------------------------------- 6. miroir des pièces paires (gantelet, jambière, botte) -> côté droit
def nom_miroir(n):
    return n[:-2] + "_r" if n.endswith("_l") else (n[:-2] + "_l" if n.endswith("_r") else n)
bm = bmesh.new(); bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
bm.verts.ensure_lookup_table()
paires = {i for i in range(len(AP)) if piece_de[i] in ("gantelet", "main", "jambiere", "botte")}
faces = [f for f in bm.faces if all(v.index in paires for v in f.verts)]
res = bmesh.ops.duplicate(bm, geom=faces)
remap = {armure.vertex_groups[n].index: armure.vertex_groups[nom_miroir(n)].index for n in cnoms}
nv = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
for v in nv:
    v.co.x = -v.co.x
    d = dict(v[dl]); v[dl].clear()
    for k, w in d.items():
        v[dl][remap.get(k, k)] = w
nf = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
bmesh.ops.reverse_faces(bm, faces=nf)
bm.to_mesh(me); bm.free()
me.update()
print("ARMURE %d sommets, %d triangles" % (len(me.vertices), len(me.polygons)))

# ---------------------------------------------------------------- 7. sous-couche de mailles : le corps, ramené DERRIÈRE l'armure
# (comble aisselles, coudes, genoux, cou entre les pièces ; mains et pieds retirés : gantelets et bottes les remplacent)
from mathutils.bvhtree import BVHTree
sous = corps; sous.name = "sous_couche"; sous.data.name = "sous_couche"
bvh = BVHTree.FromObject(armure, bpy.context.evaluated_depsgraph_get())
gn = [g.name for g in sous.vertex_groups]
RETIRE = ("hand_", "ball_", "foot_") + DOIGTS
bm = bmesh.new(); bm.from_mesh(sous.data)
dl = bm.verts.layers.deform.verify()
bm.verts.ensure_lookup_table(); bm.normal_update()
retire = []
marge = float(arg("marge", "0.02")); pousses = 0
for v in bm.verts:
    d = v[dl]
    if d:
        k = max(d.items(), key=lambda kv: kv[1])[0]
        if gn[k].startswith(RETIRE) and gn[k] not in ("foot_l", "foot_r") or (gn[k] in ("foot_l", "foot_r") and v.co.z < 0.12):
            retire.append(v); continue
    loc, nor, fi, dist = bvh.find_nearest(v.co, 0.08)
    if loc is not None and (v.co - loc).dot(nor) > -marge:
        v.co = loc - nor * marge; pousses += 1
bmesh.ops.delete(bm, geom=retire, context="VERTS")
bm.to_mesh(sous.data); bm.free()
print("SOUS-COUCHE %d sommets (%d retirés, %d ramenés derrière l'armure)" % (len(sous.data.vertices), len(retire), pousses))
msous = bpy.data.materials.new("sous_couche_mailles"); msous.diffuse_color = (0.12, 0.1, 0.09, 1)
sous.data.materials.clear(); sous.data.materials.append(msous)

# ---------------------------------------------------------------- 8. export habillé
for o in (armure, sous):
    o.parent = arm
    mo = o.modifiers.new("Armature", "ARMATURE"); mo.object = arm
for o in list(bpy.data.objects):
    if o not in (arm, armure, sous):
        bpy.data.objects.remove(o)
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_format="GLB", export_skins=True, export_animations=False,
                          export_morph=False, export_yup=True, export_image_format="NONE")
print("EXPORT", OUT_GLB)
if DEBUG:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "final.blend"))
