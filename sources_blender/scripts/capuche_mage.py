"""Capuche v3 des mages (branche persos/capuche_v3) : capuche de laine épaisse AJUSTÉE AU CRÂNE du modèle de tête réel.
Retour utilisateur : « l'ancien modèle, la ronde qui fait coquille d'œuf » -> une capuche qui épouse la tête : sommet un peu pointu
tombant vers l'arrière, ouverture qui encadre le visage (bord épais roulé, ombre portée sur le front), volume autour des oreilles et
de la nuque, tissu qui retombe en plis sur les épaules en petit col / pèlerine.

Construction (repère GODOT : x, y haut, z devant ; converti (x, -z, y) pour Blender, l'export glTF +Y le ramène tel quel) :
  1. grille (s, r) « concentrique au visage » : r = 0 est le BORD de l'ouverture (du V de la poitrine à gauche, par le front, au V
     droit), r = 1 l'OURLET sur les épaules (de l'avant gauche, par le dos, à l'avant droit) ; chaque colonne s file du bord vers
     l'ourlet par-dessus le crâne (chemin sur la sphère passant par le haut de la nuque) ;
  2. relaxation « tissu » : traction vers le corps + lissage (composante normale seulement) + collision avec la surface réelle
     (peau de la tête et du cou, tunique, pèlerine ; sources_blender/capuche/tete_*.obj exportés par outils/exporter_tete_mage.gd)
     avec un JEU (épaisseur de laine + cheveux) : la capuche se pose sur le crâne et se tend des oreilles aux épaules ;
  3. forme : pointe molle au sommet arrière, bord roulé épais (deux rangs + une tranche intérieure), plis rayonnants du col,
     plis de nuque et deux plis obliques par côté ;
  4. UV conformes (une seule île), cuisson Cycles : AO (R), rang r (G, bord = 0), pointiness (B) -> bake_capuche[_femme].png
     (Godot : MageTextures.capuche_v3 colorie avec la palette de laine).
Deux variantes par corps : « ombre » (mage ennemi : bord avancé et abaissé, le visage reste dans l'ombre) et « visage » (PNJ :
bord reculé à la lisière, le visage reçoit la lumière). Même topologie et mêmes UV.
  blender -b --python capuche_mage.py -- <sources_blender/capuche> <assets/persos/mage/blender> <assets/personnages/mage> homme|femme
"""
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

_a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, BAKE = _a[:3]
FEMME = len(_a) > 3 and _a[3] == "femme"
CUIRE = not (len(_a) > 4 and _a[4] == "sans_cuisson")
SUF = "_femme" if FEMME else ""
NS = 29          # colonnes (le long du bord)
NR = 14          # rangs (du bord à l'ourlet)

def b(p):
    return Vector((p[0], -p[2], p[1]))

def lire_obj(nom):
    v, f = [], []
    for l in open(os.path.join(SRC, nom)):
        t = l.split()
        if not t:
            continue
        if t[0] == "v":
            v.append(Vector((float(t[1]), float(t[2]), float(t[3]))))
        elif t[0] == "f":
            f.append(tuple(int(q) - 1 for q in t[1:4]))
    return v, f

def fusion(*noms):
    V, F = [], []
    for nom in noms:
        if not os.path.exists(os.path.join(SRC, nom)):
            continue
        v, f = lire_obj(nom)
        o = len(V)
        V += v
        F += [(a + o, b_ + o, c + o) for (a, b_, c) in f]
    return V, F

OS_ = json.load(open(os.path.join(SRC, "os%s.json" % SUF)))
HEAD = Vector(OS_["Head"])
PV, PF = lire_obj("tete_peau%s.obj" % SUF)
used = sorted({i for f in PF for i in f})
tete_pts = [PV[i] for i in used if PV[i].y > HEAD.y - 0.02]
YTOP = max(p.y for p in tete_pts)
ZNEZ = max(p.z for p in tete_pts)
ZDOS = min(p.z for p in tete_pts)
XLAR = max(abs(p.x) for p in tete_pts if p.y > YTOP - 0.13)
print("TETE ytop %.3f znez %.3f zdos %.3f demi-largeur %.3f head %s" % (YTOP, ZNEZ, ZDOS, XLAR, tuple(HEAD)))
bvh_tete = BVHTree.FromPolygons([tuple(v) for v in PV], PF)
CV, CF = fusion("tete_peau%s.obj" % SUF, "tete_tunique%s.obj" % SUF, "tete_mante%s.obj" % SUF)
bvh_corps = BVHTree.FromPolygons([tuple(v) for v in CV], CF)
MV, MF = fusion("tete_tunique%s.obj" % SUF, "tete_mante%s.obj" % SUF)
bvh_epaules = BVHTree.FromPolygons([tuple(v) for v in MV], MF)
# centre du crâne : sous le sommet, au milieu avant/arrière
C = Vector((0.0, YTOP - 0.105, (ZNEZ + ZDOS) * 0.5 - 0.005))

def smooth(a, b_, x):
    t = min(1.0, max(0.0, (x - a) / (b_ - a))) if b_ != a else (1.0 if x >= a else 0.0)
    return t * t * (3 - 2 * t)

def catmull(pts, t):
    """Catmull-Rom uniforme sur une liste de points (t dans [0, 1])."""
    n = len(pts) - 1
    u = min(max(t, 0.0), 1.0) * n
    i = min(int(u), n - 1)
    f = u - i
    p0 = pts[max(i - 1, 0)]
    p1 = pts[i]
    p2 = pts[i + 1]
    p3 = pts[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)

def slerp(a, b_, t):
    a = a.normalized()
    b_ = b_.normalized()
    d = max(-1.0, min(1.0, a.dot(b_)))
    om = math.acos(d)
    if om < 1e-4:
        return a.lerp(b_, t).normalized()
    so = math.sin(om)
    return (a * (math.sin((1 - t) * om) / so) + b_ * (math.sin(t * om) / so)).normalized()

def bezier_sphere(d0, d1, d2, t):
    return slerp(slerp(d0, d1, t), slerp(d1, d2, t), t)

def rayon_sortant(d, bvh):
    """Distance de C à la DERNIÈRE paroi rencontrée dans la direction d."""
    o = C.copy()
    best = 0.0
    for _ in range(12):
        h = bvh.ray_cast(o + d * 1e-4, d, 1.0)
        if h[0] is None:
            break
        best = (h[0] - C).length
        o = h[0]
    return best

# ------------------------------------------------------------------ bord de l'ouverture (r = 0)
def bord(s, var):
    """Point du bord pour s (0 = V gauche (+x), 0,5 = front, 1 = V droit). var = 'ombre' | 'visage'."""
    sg = 1.0 if s < 0.5 else -1.0
    t = abs(0.5 - s) / 0.5            # 0 front -> 1 V
    ombre = var == "ombre"
    # profil 2D (x, y relatif au sommet du crâne), du front au V de la poitrine
    # le bord s'arrête sous la mâchoire, au col de la pèlerine (les pans plus bas restaient dans la pèlerine et seule leur tranche
    # dépassait, comme des lacets)
    v_x = 0.070 if ombre else 0.052
    # visage montré : ouverture un peu plus large aux joues (le bord se décolle des pommettes, l'intérieur sombre se lit autour)
    cles = [Vector((0.0, -0.046 if ombre else -0.040)), Vector((0.050 if ombre else 0.054, -0.058 if ombre else -0.052)),
            Vector((0.080 if ombre else 0.086, -0.100)), Vector((0.090 if ombre else 0.095, -0.160)), Vector((0.088 if ombre else 0.090, -0.205)),
            Vector((0.082 if ombre else 0.074, -0.235)), Vector((v_x, -0.262))]
    q = catmull(cles, t)
    x, y = q.x * sg, YTOP + q.y
    # profondeur : rayon depuis l'avant sur la tête (haut) ou sur les épaules (bas), plus un jeu ; capuche « ombre » avancée
    if q.y > -0.215:
        h = bvh_tete.ray_cast(Vector((x * 0.97, y, 0.5)), Vector((0, 0, -1)), 1.0)
        z = h[0].z if h[0] is not None else 0.03
        n = h[1].normalized() if h[0] is not None else Vector((0, 0, 1))
        haut = smooth(-0.20, -0.06, q.y)          # 1 au front, 0 à la mâchoire
        av = (0.040 * haut + 0.016) if ombre else (0.010 * haut + 0.014)
        p = Vector((x, y, z)) + n * 0.006 + Vector((0, 0, av))
        # bord abaissé devant le front (ombre portée) / relevé (visage)
        p.y += (-0.010 if ombre else 0.006) * haut
        # côté : le bord s'écarte un peu des joues
        p.x += sg * (0.008 if ombre else 0.007) * (1 - haut)
        return p
    h = bvh_corps.ray_cast(Vector((x, y, 0.5)), Vector((0, 0, -1)), 1.0)
    z = h[0].z if h[0] is not None else 0.06
    return Vector((x, y, z + 0.014))

# ------------------------------------------------------------------ ourlet (r = 1)
def ourlet(s):
    """Point de l'ourlet sur les épaules, de l'avant gauche (s = 0) par le dos (0,5) à l'avant droit (1)."""
    psi = math.radians(14.0 + s * (360.0 - 28.0))     # 0 = devant, vers +x
    dy = YTOP - 1.81                                     # suit la taille du corps
    # hauteur : sur la poitrine devant (1,50), posé sur le haut des épaulettes de la pèlerine (1,535), plus bas dans le dos (1,445)
    c = math.cos(psi)
    y = 1.535 + 0.0275 * c - 0.0625 * c * c + dy
    d = Vector((math.sin(psi), 0.0, math.cos(psi)))
    # sur les épaules : rayon horizontal depuis l'axe du cou, dernière paroi + jeu
    o = Vector((0.0, y, -0.02))
    best = 0.12
    p = o.copy()
    for _ in range(10):
        h = bvh_epaules.ray_cast(p + d * 1e-4, d, 1.0)
        if h[0] is None:
            break
        best = (h[0] - o).length
        p = h[0]
    return o + d * (best + 0.016)

# ------------------------------------------------------------------ jeu (épaisseur de laine + cheveux)
def jeu(p):
    d = (p - C)
    dn = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
    if p.y < C.y - 0.11:
        return 0.013                                   # cou / épaules : le tissu repose
    base = 0.020 if FEMME else 0.022
    nuque = smooth(-0.2, -0.7, dn.z) * smooth(C.y - 0.12, C.y - 0.02, p.y)
    return base + 0.010 * nuque + 0.004 * smooth(0.5, 0.95, dn.y)

def construire(var):
    P = [[None] * NS for _ in range(NR)]
    # répartition des rangs : serrés près du bord (bord roulé), plus larges vers l'ourlet
    rs = [(k / (NR - 1)) ** 1.18 for k in range(NR)]
    for j in range(NS):
        s = j / (NS - 1)
        R = bord(s, var)
        H = ourlet(s)
        sig = (s - 0.5) * 2.0                         # -1 gauche ... +1 droite (en x : gauche = +x)
        dR = (R - C).normalized()
        dH = (H - C).normalized()
        # contrôle du chemin : par le haut de la nuque pour les colonnes du front, droit vers l'ourlet près du V
        dTop = Vector((-sig * 0.95, 0.70 * (1 - sig * sig) + 0.05, -0.75)).normalized()
        a = abs(sig) ** 2.2
        dM = (dTop * (1 - a) + ((dR + dH).normalized() if (dR + dH).length > 1e-3 else dTop) * a).normalized()
        for k in range(NR):
            t = rs[k]
            d = bezier_sphere(dR, dM, dH, t)
            rho = rayon_sortant(d, bvh_corps) + 0.05
            rho = max(rho, 0.10)
            P[k][j] = C + d * rho
        P[0][j] = R
        P[NR - 1][j] = H
    # ---------------------------------------------------------------- relaxation « tissu »
    X = np.array([[tuple(P[k][j]) for j in range(NS)] for k in range(NR)], dtype=np.float64)
    fixe = np.zeros((NR, NS), dtype=bool)
    # bord fixé du front à la mâchoire ; sous la mâchoire il suit le tissu (les pans du devant tombent avec le col)
    for j in range(NS):
        if abs(0.5 - j / (NS - 1)) / 0.5 < 0.62:
            fixe[0, j] = True
    xmin = 0.066 if var == "ombre" else 0.030
    for it in range(260):
        # normales de la grille
        dk = np.zeros_like(X)
        dk[1:-1] = X[2:] - X[:-2]
        dk[0] = X[1] - X[0]
        dk[-1] = X[-1] - X[-2]
        dj = np.zeros_like(X)
        dj[:, 1:-1] = X[:, 2:] - X[:, :-2]
        dj[:, 0] = X[:, 1] - X[:, 0]
        dj[:, -1] = X[:, -1] - X[:, -2]
        N = np.cross(dj, dk)
        N /= np.linalg.norm(N, axis=2, keepdims=True) + 1e-9
        # orientées vers l'extérieur (loin de C / de l'axe du cou)
        out = X - np.array(tuple(C))
        out[:, :, 1] *= 0.3
        sgn = np.sign(np.sum(N * out, axis=2, keepdims=True))
        N *= np.where(sgn == 0, 1, sgn)
        # lissage (Laplacien, composante normale seulement)
        L = np.zeros_like(X)
        cnt = np.zeros((NR, NS, 1))
        L[1:] += X[:-1]; cnt[1:] += 1
        L[:-1] += X[1:]; cnt[:-1] += 1
        L[:, 1:] += X[:, :-1]; cnt[:, 1:] += 1
        L[:, :-1] += X[:, 1:]; cnt[:, :-1] += 1
        L = L / cnt - X
        Ln = np.sum(L * N, axis=2, keepdims=True) * N
        Lt = L - Ln
        pas = 0.55 * Ln + 0.12 * Lt
        # traction vers le corps (le tissu se pose)
        tr = 0.0016 if it < 200 else 0.0006
        pas -= N * tr
        # le col se resserre autour du cou (le tissu tombe du crâne et se tasse sur le col de la pèlerine) : traction horizontale
        # vers l'axe du cou dans la bande du cou, puis il s'évase sur les épaules
        ybas = C.y - 0.215
        yhaut = C.y - 0.075
        wcou = np.clip((X[:, :, 1] - ybas) / 0.05, 0, 1) * np.clip((yhaut - X[:, :, 1]) / 0.05, 0, 1)
        axe = X.copy()
        axe[:, :, 0] = 0.0
        axe[:, :, 2] = -0.02
        hz = X - axe
        hz[:, :, 1] = 0.0
        pas -= hz * (0.035 * wcou)[:, :, None]
        X = np.where(fixe[:, :, None], X, X + pas)
        # pans du devant : jamais au milieu (la barbe du mage passe entre eux)
        ax = np.abs(X[0, :, 0])
        X[0, :, 0] = np.where(fixe[0, :], X[0, :, 0], np.sign(X[0, :, 0] + 1e-9) * np.maximum(ax, xmin))
        # l'ourlet garde sa hauteur
        X[-1, :, 1] = np.array([P[NR - 1][j].y for j in range(NS)])
        # collision : jamais plus près du corps que le jeu
        for k in range(1, NR):
            for j in range(NS):
                p = Vector(X[k, j])
                loc, nrm, idx, dist = bvh_corps.find_nearest(p, 0.2)
                if loc is None:
                    continue
                c = jeu(p)
                nn = nrm.normalized()
                # normale orientée vers l'extérieur du corps (la pèlerine est une étoffe sans sens fiable) : depuis le centre du
                # crâne en haut, depuis l'axe du cou en bas
                ref = (loc - C) if loc.y > C.y - 0.10 else (loc - Vector((0.0, loc.y, -0.02)))
                if ref.dot(nn) < 0:
                    nn = -nn
                dedans = (p - loc).dot(nn) < 0
                if dedans or dist < c:
                    X[k, j] = tuple(loc + nn * c)
    return X

def forme(X, var):
    """Pointe, plis, bord roulé : déplacements sur la grille relaxée."""
    X = X.copy()
    NRk, NSk = X.shape[:2]
    Cn = np.array(tuple(C))
    # normales
    def normales(X):
        dk = np.gradient(X, axis=0)
        dj = np.gradient(X, axis=1)
        N = np.cross(dj, dk)
        N /= np.linalg.norm(N, axis=2, keepdims=True) + 1e-9
        out = X - Cn
        out[:, :, 1] *= 0.3
        sgn = np.sign(np.sum(N * out, axis=2, keepdims=True))
        return N * np.where(sgn == 0, 1, sgn)
    # 1. pointe molle au sommet arrière, tombant vers l'arrière (le tissu en trop du patron)
    Dpk = Vector((0.0, 0.62, -0.78)).normalized()
    chute = Vector((0.0, 0.10, -1.0)).normalized()
    for k in range(NRk):
        for j in range(NSk):
            p = Vector(X[k, j])
            q = (p - C).normalized().dot(Dpk)
            w = smooth(0.80, 0.985, q)
            X[k, j] = tuple(p + chute * (0.050 * w * w) + Vector((0, -0.006, 0)) * w)
    # lissage local de la pointe
    for _ in range(4):
        L = X.copy()
        L[1:-1, 1:-1] = (X[:-2, 1:-1] + X[2:, 1:-1] + X[1:-1, :-2] + X[1:-1, 2:]) * 0.25
        X[1:-1, 1:-1] = X[1:-1, 1:-1] * 0.5 + L[1:-1, 1:-1] * 0.5
    N = normales(X)
    ycou = C.y - 0.11
    rng = np.random.default_rng(20261102)
    ph = rng.uniform(0, 2 * math.pi, 4)
    for k in range(1, NRk):
        r = k / (NRk - 1)
        for j in range(NSk):
            s = j / (NSk - 1)
            p = Vector(X[k, j])
            dn = (p - C).normalized()
            d = 0.0
            # 2. plis rayonnants du col (sous la mâchoire, vers l'ourlet) : creux et crêtes larges, irréguliers
            col = smooth(ycou + 0.02, ycou - 0.10, p.y)
            f = math.sin(2 * math.pi * 6.5 * s + ph[0] + 1.4 * math.sin(2 * math.pi * 2.0 * s + ph[1]))
            d += 0.015 * col * (0.55 * f + 0.45 * abs(f) - 0.2)
            # 3. plis de nuque (le tissu de la pointe se tasse au-dessus du col)
            nuque = smooth(-0.45, -0.85, dn.z) * smooth(ycou - 0.03, ycou + 0.06, p.y) * smooth(ycou + 0.12, ycou + 0.05, p.y)
            d += 0.0065 * nuque * math.sin((p.y - ycou) * 95.0 + 1.3 * math.sin(p.x * 40.0))
            # 4. deux plis obliques par côté, de la joue vers la nuque (le bord tire sur le tissu)
            for s0, k0, a in ((0.20, 0.10, 0.0050), (0.28, 0.32, 0.0042)):
                for ss in (s0, 1 - s0):
                    pente = 0.55 if ss < 0.5 else -0.55
                    dist = (s - ss) - pente * (r - k0)
                    long_ = smooth(k0 - 0.05, k0 + 0.02, r) * smooth(k0 + 0.42, k0 + 0.22, r)
                    d += a * long_ * math.exp(-(dist / 0.022) ** 2)
            # 5. couture du milieu (du front à la nuque) : une arête nette casse la coquille
            d += 0.0045 * math.exp(-((s - 0.5) / 0.022) ** 2) * smooth(0.06, 0.16, r) * smooth(0.80, 0.55, r)
            X[k, j] = tuple(p + Vector(N[k, j]) * d)
    # 5. bord roulé : le rang 0 bombé vers l'extérieur et un peu en avant, le rang 1 en retrait (le bourrelet se lit)
    N = normales(X)
    for j in range(NSk):
        p0 = Vector(X[0, j])
        p1 = Vector(X[1, j])
        X[0, j] = tuple(p0 + Vector(N[0, j]) * 0.008)
        X[1, j] = tuple(p1 + Vector(N[1, j]) * 0.011)
        if NRk > 2:
            X[2, j] = tuple(Vector(X[2, j]) + Vector(N[2, j]) * 0.002)
    return X, N

NI = 5           # rangs de la doublure (face intérieure, vue par l'ouverture du visage)
EP = 0.013       # épaisseur de la laine (doublure rentrée de 1,3 cm)

def maillage(var):
    X = construire(var)
    X, N = forme(X, var)
    bm = bmesh.new()
    vs = [[bm.verts.new(b(X[k, j])) for j in range(NS)] for k in range(NR)]
    for k in range(NR - 1):
        for j in range(NS - 1):
            bm.faces.new((vs[k][j], vs[k][j + 1], vs[k + 1][j + 1], vs[k + 1][j]))
    # DOUBLURE : la face intérieure des NI premiers rangs, rentrée de EP vers la tête (vraie épaisseur : le matériau est à une seule
    # face, l'intérieur du capuchon vu par l'ouverture est cette doublure, éclairée de l'intérieur donc sombre) ; au-delà, la tête
    # cache l'intérieur. Le bord est une tranche qui relie l'extérieur à la doublure (bord roulé épais).
    vi = []
    for k in range(NI + 1):
        rang = []
        for j in range(NS):
            p = Vector(X[k, j])
            n = Vector(N[k, j])
            q = p - n * (EP * (1.25 if k == 0 else 1.0))
            if k == 0:
                q += (Vector(X[1, j]) - p).normalized() * 0.003
            rang.append(bm.verts.new(b(q)))
        vi.append(rang)
    for k in range(NI):
        for j in range(NS - 1):
            bm.faces.new((vi[k][j + 1], vi[k][j], vi[k + 1][j], vi[k + 1][j + 1]))
    for j in range(NS - 1):
        bm.faces.new((vs[0][j + 1], vs[0][j], vi[0][j], vi[0][j + 1]))
    bm.normal_update()
    me = bpy.data.meshes.new("capuche_" + var)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("capuche_" + var, me)
    bpy.context.collection.objects.link(ob)
    # attribut « rang » (0 = bord, 1 = ourlet ; doublure : 0) pour la cuisson
    col = me.color_attributes.new("rang", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        if i < NR * NS:
            k, j = divmod(i, NS)
            col.data[i].color = (k / (NR - 1), j / (NS - 1), 0.0, 1.0)
        else:
            col.data[i].color = (0.0, 0.5, 0.0, 1.0)
    for p in me.polygons:
        p.use_smooth = True
    # UV (texture 128 x 64) : u = colonne (le long du bord, couture du milieu à u = 0,5), v Godot = rang de l'extérieur (bord à
    # v = 0,08, ourlet à 0,99) proportionnel à la longueur moyenne des colonnes ; doublure dans la bande du haut (v < 0,045, bord
    # à 0,045) ; la tranche du bord entre les deux (0,045 -> 0,08). (Blender : v inversé, l'export glTF le remet dans le sens de
    # l'image.)
    lg = np.linalg.norm(np.diff(X, axis=0), axis=2).mean(axis=1)
    cum = np.concatenate([[0.0], np.cumsum(lg)])
    cum /= cum[-1]
    vg = {}
    for k in range(NR):
        for j in range(NS):
            vg[k * NS + j] = (j / (NS - 1), 0.08 + 0.91 * cum[k])
    base = NR * NS
    for k in range(NI + 1):
        for j in range(NS):
            vg[base + k * NS + j] = (j / (NS - 1), 0.045 * (1.0 - k / NI) + 0.004)
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            u, v = vg[me.loops[li].vertex_index]
            uvl.data[li].uv = (u * 0.98 + 0.01, 1.0 - v)
    return ob

def recalculer_normales(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # surface ouverte : vérifier que les normales sortent (loin du centre du crâne) sur les faces du haut
    cb = b(C)
    tot = 0.0
    for p in ob.data.polygons:
        if p.center.z > cb.z:
            tot += p.normal.dot(p.center - cb)
    if tot < 0:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
        print("normales retournées", ob.name)

def deplier(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="CONFORMAL", margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    # remplir le carré [0,1] en gardant les proportions
    uv = ob.data.uv_layers.active.data
    us = np.array([d.uv[0] for d in uv]); vs = np.array([d.uv[1] for d in uv])
    u0, u1, v0, v1 = us.min(), us.max(), vs.min(), vs.max()
    sc = 0.98 / max(u1 - u0, v1 - v0)
    for d in uv:
        d.uv = ((d.uv[0] - u0) * sc + 0.01, (d.uv[1] - v0) * sc + 0.01)

def copier_uv(src, dst):
    a = [tuple(d.uv) for d in src.data.uv_layers.active.data]
    if not dst.data.uv_layers:
        dst.data.uv_layers.new(name="UVMap")
    for d, u in zip(dst.data.uv_layers.active.data, a):
        d.uv = u

def objet_tete():
    me = bpy.data.meshes.new("tete")
    me.from_pydata([tuple(b(v)) for v in PV], [], PF)
    ob = bpy.data.objects.new("tete", me)
    bpy.context.collection.objects.link(ob)
    return ob

def cuire(ob, tete, taille=512, haut=256):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = False
    rb = sc.render.bake
    rb.use_selected_to_active = False
    rb.margin = 4
    rb.use_clear = True
    res = {}
    for typ in ("AO", "EMIT_RANG", "EMIT_POINT"):
        img = bpy.data.images.new("bake_" + typ, taille, haut, alpha=True)
        img.colorspace_settings.name = "Non-Color"
        mat = bpy.data.materials.new("m_" + typ)
        mat.use_nodes = True
        nt = mat.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        outn = nt.nodes.new("ShaderNodeOutputMaterial")
        if typ == "AO":
            bs = nt.nodes.new("ShaderNodeBsdfDiffuse")
            nt.links.new(bs.outputs[0], outn.inputs["Surface"])
        else:
            em = nt.nodes.new("ShaderNodeEmission")
            if typ == "EMIT_RANG":
                at = nt.nodes.new("ShaderNodeAttribute")
                at.attribute_name = "rang"
                nt.links.new(at.outputs["Color"], em.inputs["Color"])
            else:
                g = nt.nodes.new("ShaderNodeNewGeometry")
                cr = nt.nodes.new("ShaderNodeValToRGB")
                cr.color_ramp.elements[0].position = 0.40
                cr.color_ramp.elements[1].position = 0.60
                nt.links.new(g.outputs["Pointiness"], cr.inputs[0])
                nt.links.new(cr.outputs[0], em.inputs["Color"])
            nt.links.new(em.outputs[0], outn.inputs["Surface"])
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        nt.nodes.active = tn
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="AO" if typ == "AO" else "EMIT")
        px = np.array(img.pixels[:], dtype=np.float32).reshape(haut, taille, 4)
        res[typ] = px
    return res

def apercu(obs):
    """Aperçus Workbench (tête + épaules + capuche) : face, 3/4, profil, dos -> SRC/apercu_capuche_<var>.png"""
    tete = objet_tete()
    me = bpy.data.meshes.new("epaules")
    me.from_pydata([tuple(b(v)) for v in MV], [], MF)
    ep = bpy.data.objects.new("epaules", me)
    bpy.context.collection.objects.link(ep)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "SINGLE"
    sc.render.resolution_x = 400
    sc.render.resolution_y = 400
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 60
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    cible = b(Vector((0, YTOP - 0.17, -0.01)))
    for var, ob in obs.items():
        for o in obs.values():
            o.hide_render = o is not ob
        for nom, az in (("face", 0), ("34", 40), ("profil", 90), ("dos", 180)):
            a = math.radians(az)
            pos = b(Vector((math.sin(a) * 0.95, YTOP - 0.10, math.cos(a) * 0.95)))
            cam.location = pos
            dvec = cible - pos
            cam.rotation_euler = dvec.to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = os.path.join(SRC, "apercu_%s%s_%s.png" % (var, SUF, nom))
            bpy.ops.render.render(write_still=True)
    for o in obs.values():
        o.hide_render = False
    bpy.data.objects.remove(tete)
    bpy.data.objects.remove(ep)
    bpy.data.objects.remove(cam)

def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    obs = {}
    for var in ("ombre", "visage"):
        obs[var] = maillage(var)
        recalculer_normales(obs[var])
        print("CAPUCHE %s%s : %d sommets, %d faces" % (var, SUF, len(obs[var].data.vertices), len(obs[var].data.polygons)))
    if "apercu" in _a:
        apercu(obs)

    if CUIRE:
        tete = objet_tete()
        tete.hide_render = True                    # AO : la capuche seule (plis, dessous de la pointe), pas le corps
        obs["visage"].hide_render = True          # les deux variantes se recouvrent : l'une ne doit pas boucher l'autre
        if bpy.context.scene.world is None:
            bpy.context.scene.world = bpy.data.worlds.new("monde")
        bpy.context.scene.world.light_settings.distance = 0.08
        res = cuire(obs["ombre"], tete)
        obs["visage"].hide_render = False
        T = 512
        ao = res["AO"][:, :, 0]
        rang = res["EMIT_RANG"][:, :, 0]
        pt = res["EMIT_POINT"][:, :, 0]
        cov = res["EMIT_RANG"][:, :, 3]
        # réduction 512 -> 128 (moyenne 4 x 4)
        def red(a):
            return a.reshape(64, 4, 128, 4).mean(axis=(1, 3))
        out = np.zeros((64, 128, 4), dtype=np.float32)
        out[:, :, 0] = red(ao)
        out[:, :, 1] = red(rang)
        out[:, :, 2] = red(pt)
        out[:, :, 3] = (red(cov) > 0.25).astype(np.float32)
        img = bpy.data.images.new("bake_capuche", 128, 64, alpha=True)
        img.colorspace_settings.name = "Non-Color"
        img.pixels = out.ravel()
        img.filepath_raw = os.path.join(BAKE, "bake_capuche%s.png" % SUF)
        img.file_format = "PNG"
        img.save()
        print("CUISSON AO moy %.2f min %.2f | pt moy %.2f -> %s" % (out[:, :, 0][out[:, :, 3] > 0].mean(), out[:, :, 0][out[:, :, 3] > 0].min(), out[:, :, 2][out[:, :, 3] > 0].mean(), img.filepath_raw))
        bpy.data.objects.remove(tete)
    for ob in obs.values():
        ob.data.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs.values():
        ob.select_set(True)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "capuche_mage%s.glb" % SUF), use_selection=True, export_format="GLB",
        export_yup=True, export_apply=False, export_materials="NONE")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "capuche_mage%s.blend" % SUF))
    print("EXPORT capuche_mage%s.glb" % SUF)

main()
