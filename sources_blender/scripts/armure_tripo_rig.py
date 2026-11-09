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
BUDGET = {"casque": 1300, "cuirasse": 2900, "gantelet": 1000, "jambiere": 700, "botte": 450}
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

def rot(v, ang, k):
    k = k / np.linalg.norm(k); return v * math.cos(ang) + np.cross(k, v) * math.sin(ang) + k * (k @ v) * (1 - math.cos(ang))
def nrm(v): return v / np.linalg.norm(v)
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

def composantes(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    vu = np.zeros(len(bm.verts), bool); res = []
    for v in bm.verts:
        if vu[v.index]:
            continue
        pile = [v]; vu[v.index] = True; c = []
        while pile:
            x = pile.pop(); c.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if not vu[y.index]:
                    vu[y.index] = True; pile.append(y)
        res.append(np.array(c))
    bm.free(); return res

def poser_gantelet(o):
    # source = main DROITE pendante (doigts vers -z, dos de la main vers -y) -> main gauche par miroir x.
    # Le CANON suit l'avant-bras (repère de l'avant-bras) ; la MAIN du gantelet (géométrie Tripo d'origine : plaque de dos, doigts
    # articulés) est recalée à part sur la main du squelette au repos (poignet -> jointures, dos de la main), à la longueur de la main
    # du corps et à 1,12x sa largeur au plus ; doigts resserrés, pouce ramené le long de l'index ; fondu des deux repères dans la manchette.
    P0 = normaliser(o)
    P0[:, 0] *= -1                                           # main gauche
    z1 = P0[:, 2].max()
    zw, zk, dz = float(arg("z_poignet", "0.50")) * z1, float(arg("z_jointures", "0.19")) * z1, float(arg("z_fondu", "0.05")) * z1
    pouce = np.zeros(len(P0), bool)
    for c in composantes(o):
        Q = P0[c]
        if Q[:, 0].mean() < float(arg("x_pouce", "-0.015")) and Q[:, 2].max() < zw and Q[:, 2].min() > 0.05 * z1:
            pouce[c] = True
    doigts = (P0[:, 2] < zk) & ~pouce
    # --- canon : repère de l'avant-bras
    s = float(arg("s_gantelet", "2.5"))
    # axe propre du canon : milieu de la boîte de chaque tranche (z au-dessus du poignet), droite ajustée ; le canon est recentré sur
    # cet axe (centré sur la boîte de toute la pièce, pouce compris, il était décalé de 4-5 cm de l'os de l'avant-bras)
    zs = np.linspace(zw + 0.05 * z1, 0.92 * z1, 12)
    cs = []
    for z_ in zs:
        q_ = P0[np.abs(P0[:, 2] - z_) < 0.02 * z1, :2]
        cs.append((q_.min(0) + q_.max(0)) / 2)
    cs = np.array(cs)
    fx, fy = np.polyfit(zs, cs[:, 0], 1), np.polyfit(zs, cs[:, 1], 1)
    zc_ = np.clip(P0[:, 2], zw, z1)
    Q0 = P0.copy()
    Q0[:, 0] -= np.polyval(fx, zc_); Q0[:, 1] -= np.polyval(fy, zc_)
    print("GANTELET canon : axe recentré de (%.3f, %.3f) au poignet à (%.3f, %.3f) en haut (unités source)" % (
        np.polyval(fx, zw), np.polyval(fy, zw), np.polyval(fx, z1), np.polyval(fy, z1)))
    # le canon est un brassard qui va du POIGNET (bande, z = zw) au COUDE (bord évasé, rayon max de la pièce source) ; au-dessus du
    # bord, la crête pointue couvre le coude. Avant : échelle uniforme, le bord évasé tombait au milieu de l'avant-bras (cassure).
    coude, poignet = tete("lowerarm_l"), tete("hand_l")
    L_ab = np.linalg.norm(poignet - coude)
    zz = np.linspace(zw + 0.1 * z1, 0.95 * z1, 40)
    rr = [np.median(np.linalg.norm(Q0[np.abs(Q0[:, 2] - z_) < 0.015 * z1, :2], axis=1)) for z_ in zz]
    z_bord = zz[int(np.argmax(rr))]
    s_z = (L_ab - float(arg("bord_coude", "0.01"))) / (z_bord - zw)
    Pc = Q0.copy()
    Pc[:, :2] *= s * float(arg("k_canon", "0.86"))
    zr = Pc[:, 2].copy()
    Pc[:, 2] = (np.minimum(zr, z_bord) - zw) * s_z         # 0 au poignet, L_ab au coude
    Pc[:, 2] += np.maximum(zr - z_bord, 0) * s * float(arg("k_creste", "0.86"))   # crête au-dessus du coude : pas allongée
    print("GANTELET canon : bord évasé à z=%.2f (source), allongement %.2f (échelle z %.3f contre %.3f en largeur)" % (
        z_bord / z1, s_z / (s * float(arg("k_canon", "0.86"))), s_z, s * float(arg("k_canon", "0.86"))))
    ax = (poignet - coude) / L_ab
    up = np.array([0, 0, 1.0]); dos = up - ax * ax.dot(up); dos /= np.linalg.norm(dos)
    R = np.column_stack([np.cross(dos, ax) * 1.0, -dos, -ax])
    if np.linalg.det(R) < 0:
        R[:, 0] *= -1
    Pc = Pc @ R.T + poignet + dos * float(arg("h_gantelet", "0.0"))
    # --- main : repère de la main du squelette
    W_b = tete("hand_l")
    K_b = np.mean([tete(f + "_01_l") for f in ("index", "middle", "ring", "pinky")], axis=0)
    a_b = nrm(K_b - W_b)
    cote_b = nrm(tete("index_01_l") - tete("pinky_01_l"))
    dos_b = nrm(np.cross(cote_b, a_b))
    lat_b = np.cross(dos_b, a_b)
    Rh = np.column_stack([lat_b, -dos_b, -a_b])              # x -> lat, -y (dos source) -> dos, -z (doigts) -> axe de la main
    bande = (np.abs(P0[:, 2] - zk) < 0.04 * z1) & ~pouce
    xm, ym = (P0[bande, 0].min() + P0[bande, 0].max()) / 2, (P0[bande, 1].min() + P0[bande, 1].max()) / 2
    W_s = np.array([xm, ym, zw])
    w_src = np.ptp(P0[bande, 0])
    w_b = np.linalg.norm(tete("index_01_l") - tete("pinky_01_l")) + 2 * float(arg("doigt_demi", "0.011"))
    long_nue = np.linalg.norm(queue("middle_03_l") - W_b)
    cible_long = long_nue * float(arg("k_main_long", "1.10"))      # gantelet = main nue + 10 % (poignet -> bout du majeur)
    s_lat = float(arg("k_main_larg", "1.25")) * w_b / w_src          # une main en armure est plus large qu'une main nue
    L_d = zk - P0[doigts, 2].min()
    fl = math.radians(float(arg("flexion", "10")))
    def placer_main(s_h):
        # ancrée au POIGNET (la plaque de dos garde l'échelle de la manchette, pas de rétrécissement au poignet)
        sx_h, sy_h = s_lat, s_h * float(arg("k_main_ep", "0.9"))
        sx_c = sy_c = s * float(arg("k_canon", "0.86"))
        g_ = lisse01((P0[:, 2] - zk) / (zw - zk))[:, None]        # 0 aux jointures (main v8 intacte), 1 au poignet (section du canon)
        sxy = np.array([sx_h, sy_h]) ** (1 - g_) * np.array([sx_c, sy_c]) ** g_
        Ph = np.column_stack([(P0[:, :2] - W_s[:2]) * sxy, (P0[:, 2] - W_s[2]) * s_h]) @ Rh.T + W_b
        K_a = W_b + a_b * (zw - zk) * s_h                            # jointures du gantelet
        t_d = lisse01((zk - P0[doigts, 2]) / (0.6 * L_d))
        u = (Ph[doigts] - K_a) @ lat_b; uc = u.mean()
        Ph[doigts] += np.outer((uc + (u - uc) * (1 - (1 - float(arg("k_serre", "0.88"))) * t_d)) - u, lat_b)
        if fl > 0:                                                    # légère flexion vers la paume, nulle aux jointures
            idx = np.nonzero(doigts)[0]
            d_ = (Ph[idx] - K_a) @ a_b
            angs = fl * np.clip(d_ / (s_h * L_d), 0, 1)
            Ph[idx] = np.array([K_a + rot(Ph[i] - K_a, g, lat_b) for i, g in zip(idx, angs)])
        if pouce.any():                                               # pouce le long de l'index
            zp = P0[pouce, 2]
            base = Ph[pouce][zp > np.percentile(zp, 85)].mean(0); bout = Ph[pouce][zp < np.percentile(zp, 10)].mean(0)
            k_l = s_h * (zw - zk) / np.linalg.norm(K_b - W_b)
            cible = W_b + (tete("index_02_l") - W_b) * k_l - dos_b * float(arg("pouce_paume", "0.018")) * k_l
            v1, v2 = nrm(bout - base), nrm(cible - base)
            k = np.cross(v1, v2)
            if np.linalg.norm(k) > 1e-6:
                ang = math.acos(np.clip(v1 @ v2, -1, 1)) * float(arg("pouce_k", "1.0"))
                Ph[pouce] = np.array([base + rot(q - base, ang, k) for q in Ph[pouce]])
        return Ph, K_a
    s_h = np.linalg.norm(K_b - W_b) / (zw - zk)
    for _ in range(3):                                                # longueur poignet -> bout des doigts = cible
        Ph, K_a = placer_main(s_h)
        long_g = ((Ph[doigts] - W_b) @ a_b).max()
        s_h *= cible_long / long_g
    Ph, K_a = placer_main(s_h)
    long_g = ((Ph[doigts] - W_b) @ a_b).max()
    cote_pouce = np.sign((Ph[pouce].mean(0) - K_a) @ lat_b) if pouce.any() else 0
    attendu = np.sign((tete("thumb_01_l") - K_b) @ lat_b)
    print("GANTELET pouce : %d sommets, côté %+d (attendu %+d)" % (pouce.sum(), cote_pouce, attendu))
    # fondu canon / main dans la manchette
    t = lisse01((P0[:, 2] - (zw - dz)) / (2 * dz))
    P = Ph * (1 - t[:, None]) + Pc * t[:, None]
    set_pts(o, P)
    for nom, w in (("zone_main", 1 - t), ("zone_doigts", doigts.astype(float)), ("zone_pouce", pouce.astype(float))):
        vg = o.vertex_groups.new(name=nom)
        for i in np.nonzero(w > 1e-3)[0]:
            vg.add([int(i)], float(w[i]), "REPLACE")
    larg_g = np.ptp(P[bande] @ lat_b)
    d_c = R[:, 1] * -1; d_h = dos_b - ax * (ax @ dos_b); d_h /= np.linalg.norm(d_h)
    print("GANTELET torsion canon/main autour de l'avant-bras : %.1f°" % math.degrees(math.atan2(np.cross(d_c, d_h) @ ax, d_c @ d_h)))
    print("GANTELET échelles : canon xy %.3f ; main x %.3f y %.3f (raccord au poignet sur la section du canon)" % (
        s * float(arg("k_canon", "0.86")), s_lat, s_h * float(arg("k_main_ep", "0.9"))))
    avant_bras = np.linalg.norm(tete("hand_l") - tete("lowerarm_l"))
    print("GANTELET main : poignet->bout %.3f m (main nue %.3f, x%.2f) ; largeur jointures %.3f (nue %.3f, x%.2f) ; main/avant-bras %.2f" % (
        long_g, long_nue, long_g / long_nue, larg_g, w_b, larg_g / w_b, long_g / avant_bras))

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


def miroir(o, nom):
    m = o.copy(); m.data = o.data.copy(); m.name = nom; m.data.name = nom
    bpy.context.collection.objects.link(m)
    P = pts(m); P[:, 0] *= -1; set_pts(m, P)
    m.data.flip_normals()
    return m

if DEBUG:
    os.makedirs(DEBUG, exist_ok=True)
    for nom in ("gantelet", "jambiere", "botte"):
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
ordre = ["casque", "cuirasse", "gantelet", "jambiere", "botte"]
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
for h in HD.values():
    h.data.materials.clear(); h.data.materials.append(mhd)
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
    o.select_set(o == armure or o in HD.values())
bpy.context.view_layer.objects.active = armure
bpy.ops.object.bake(type="EMIT")
CUIT.scale(512, 512)
# main du gantelet : cuir sombre / métal bruni dans la source -> ramenée au doré du torse (rapport des teintes moyennes, par canal),
# sur ses seuls îlots de l'atlas (rastérisés, élargis de la marge de cuisson)
px = np.array(CUIT.pixels[:]).reshape(512, 512, 4)
me_a = armure.data; me_a.calc_loop_triangles(); uva = me_a.uv_layers["atlas"]
def poids_groupe(nom):
    z = np.zeros(len(me_a.vertices)); gi = armure.vertex_groups[nom].index
    for v in me_a.vertices:
        for g in v.groups:
            if g.group == gi:
                z[v.index] = g.weight
    return z
zm, zc = np.maximum(poids_groupe("zone_main"), poids_groupe("piece_gantelet")), poids_groupe("piece_cuirasse")
def tri_uv(t): return np.array([uva.data[l].uv[:] for l in t.loops]) * 511
masque = np.zeros((512, 512), bool); ech_m, ech_c = [], []
for t in me_a.loop_triangles:
    vs = list(t.vertices); T = tri_uv(t); c = T.mean(0).astype(int)
    if zc[vs].mean() > 0.5:
        ech_c.append(px[c[1], c[0], :3])
    if zm[vs].mean() > 0.5:
        ech_m.append(px[c[1], c[0], :3])
        x0, y0 = np.floor(T.min(0)).astype(int); x1, y1 = np.ceil(T.max(0)).astype(int)
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        Q = np.stack([X.ravel() + 0.5, Y.ravel() + 0.5], 1)
        (ax_, ay_), (bx_, by_), (cx_, cy_) = T
        den = (by_ - cy_) * (ax_ - cx_) + (cx_ - bx_) * (ay_ - cy_)
        if abs(den) < 1e-9:
            continue
        l1 = ((by_ - cy_) * (Q[:, 0] - cx_) + (cx_ - bx_) * (Q[:, 1] - cy_)) / den
        l2 = ((cy_ - ay_) * (Q[:, 0] - cx_) + (ax_ - cx_) * (Q[:, 1] - cy_)) / den
        ok = (l1 >= -0.05) & (l2 >= -0.05) & (1 - l1 - l2 >= -0.05)
        xs, ys = np.clip(X.ravel()[ok], 0, 511), np.clip(Y.ravel()[ok], 0, 511)
        masque[ys, xs] = True
for _ in range(3):
    masque = masque | np.roll(masque, 1, 0) | np.roll(masque, -1, 0) | np.roll(masque, 1, 1) | np.roll(masque, -1, 1)
ref, mn = np.median(np.array(ech_c), 0), np.median(np.array(ech_m), 0)
k_or = np.clip(ref / np.maximum(mn, 1e-3), 1.0, float(arg("or_max", "2.4")))
px[masque, :3] = np.clip(px[masque, :3] * k_or, 0, 1)
# cuir sombre du gantelet (fenêtres du canon, creux) relevé vers un or bruni : plus de taches noires sur l'avant-bras
lum = px[..., :3] @ np.array([0.3, 0.55, 0.15])
a_ = (1 - lisse01((lum - float(arg("cuir_bas", "0.05"))) / float(arg("cuir_large", "0.12")))) * masque
px[..., :3] = px[..., :3] * (1 - a_[..., None]) + (ref * (0.55 + 2.0 * lum[..., None])) * a_[..., None]
CUIT.pixels[:] = px.ravel()
print("MAIN dorée : teinte médiane %s -> torse %s (x%s), %d texels" % (mn.round(3), ref.round(3), k_or.round(2), masque.sum()))
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
# gantelet : poids par os (distance aux segments du squelette) selon la zone : canon -> avant-bras/main, doigts -> phalanges des
# 4 doigts, pouce -> phalanges du pouce ; le lissage laplacien qui suit fond les phalanges entre elles
def zone(nom):
    z = np.zeros(len(AP)); gi = armure.vertex_groups[nom].index
    for v in me.vertices:
        for g in v.groups:
            if g.group == gi:
                z[v.index] = g.weight
    return z
ig = np.nonzero(piece_de == "gantelet")[0]
z_d, z_p = zone("zone_doigts")[ig], zone("zone_pouce")[ig]
def poids_os(noms, P):
    D = np.stack([dseg(P, tete(n), queue(n)) for n in noms], 1)
    w = 1.0 / (D + 0.006) ** 4; return w / w.sum(1, keepdims=True)
jeux = {"paume": ["lowerarm_l", "hand_l"],
        "doigts": ["hand_l"] + [f + "_0%d_l" % k for f in ("index", "middle", "ring", "pinky") for k in (1, 2, 3)],
        "pouce": ["hand_l", "thumb_01_l", "thumb_02_l", "thumb_03_l"]}
Wg = np.zeros((len(ig), len(cnoms)))
# part des phalanges : l'animation referme les doigts du corps en poing ; à part pleine, les doigts du gantelet (plus longs) se
# replient en moignon. À 50 %, ils restent articulés par phalange mais ne se ferment qu'à moitié (doigts entiers lisibles).
k_ph = float(arg("part_phalanges", "0.5"))
for cle, f in (("paume", 1 - z_d - z_p), ("doigts", z_d), ("pouce", z_p)):
    w = poids_os(jeux[cle], AP[ig])
    if cle != "paume":
        w = w * k_ph; w[:, 0] += 1 - k_ph                     # jeux[cle][0] = hand_l
    for k, n in enumerate(jeux[cle]):
        Wg[:, cnoms.index(n)] += w[:, k] * np.clip(f, 0, 1)[:, None].ravel()
AW[ig] = Wg / Wg.sum(1, keepdims=True)
# lissage laplacien sur les arêtes de l'armure (chaque pièce se lisse sur elle-même)
E = np.array([e.vertices[:] for e in me.edges])
for it in range(int(arg("lissage", "6"))):
    S = np.zeros_like(AW); n = np.zeros(len(AP))
    np.add.at(S, E[:, 0], AW[E[:, 1]]); np.add.at(S, E[:, 1], AW[E[:, 0]])
    np.add.at(n, E[:, 0], 1); np.add.at(n, E[:, 1], 1)
    AW = 0.5 * AW + 0.5 * S / np.maximum(n, 1)[:, None]
# canon du gantelet : brassard RIGIDE. Après le lissage, l'avant-bras ne suit que lowerarm ; la main ne le reprend que dans les 2 cm
# avant le poignet (avant : poids à la distance + lissage, la rotation de la main tordait la plaque en bonbon).
z_m = zone("zone_main")[ig]
coude_, poignet_ = tete("lowerarm_l"), tete("hand_l")
ax_ = nrm(poignet_ - coude_)
t_ax = (AP[ig] - coude_) @ ax_ - np.linalg.norm(poignet_ - coude_)
hf = lisse01((t_ax + float(arg("canon_fondu", "0.02"))) / (2 * float(arg("canon_fondu", "0.02"))))
# la crête qui dépasse au-dessus du coude suit le haut du bras (sinon elle pivote avec l'avant-bras et sort du bras plié)
hu = lisse01(-((AP[ig] - coude_) @ ax_) / float(arg("creste_fondu", "0.05")))
rig = np.zeros((len(ig), len(cnoms)))
rig[:, cnoms.index("lowerarm_l")] = (1 - hf) * (1 - hu)
rig[:, cnoms.index("upperarm_l")] = hu
rig[:, cnoms.index("hand_l")] = hf
k_c = (1 - z_m)[:, None]
AW[ig] = AW[ig] * (1 - k_c) + rig * k_c
print("CANON rigide : %d sommets (lowerarm seul jusqu'à 2 cm du poignet)" % int((z_m < 0.5).sum()))
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
paires = {i for i in range(len(AP)) if piece_de[i] in ("gantelet", "jambiere", "botte")}
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
    if loc is None:
        continue
    # « derrière » = vers l'os du sommet (les plaques Tripo sont à une face, leur normale peut pointer vers l'intérieur : la règle
    # par la normale poussait le cuir AU-DEHORS du canon -> taches sombres sur l'avant-bras)
    if d and gn[k] in B and gn[k].startswith(("lowerarm", "hand")):
        q = pseg(np.array([v.co[:]]), tete(gn[k]), queue(gn[k]))[0]
        r_a = np.linalg.norm(np.array(loc[:]) - q); dv = np.array(v.co[:]) - q; r_v = np.linalg.norm(dv)
        if r_v > r_a - marge and r_v > 1e-6:
            v.co = Vector(q + dv / r_v * max(r_a - marge, 0.005)); pousses += 1
    elif (v.co - loc).dot(nor) > -marge:
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
