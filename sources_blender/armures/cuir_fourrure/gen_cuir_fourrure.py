"""Armures LÉGÈRES en HAUTE DÉFINITION : CUIR et FOURRURE (charte conception_rpg/CHARTE_ARMURES_HD.md, branche armures_hd/cuir_fourrure).

  blender -b --python gen_cuir_fourrure.py -- [cuir|fourrure|chausses|tout] [apercu=<dossier>]

Reprend les outils de ../armures_lib.py et de ../legeres/gen_legeres.py (agent X : coques ajustées au héros, poids hérités des
vêtements Quaternius, poses au sol) et monte la qualité :
  - géométrie : torse 1 500-2 500 triangles, tête 800-1 400, gants / bottes 600-1 200, chausses 600-900 ; plaques de cuir bouilli
    DÉCOUPÉES dans la coque (bmesh.bisect : bords nets et droits), posées par-dessus avec épaisseur et bord bas soulevé (lames qui se
    chevauchent), boucles de fer en relief (matériau « fer » à part : reflets métal du shader), fourrure en MÈCHES (tuiles effilées
    en recouvrement, crête centrale, bas pendant double face), crocs d'os ;
  - texture : atlas 1024² par ensemble (torse 1024x576), peint texel par texel depuis la position 3D : grain du cuir à 4 échelles,
    plis, biseau usé au bord, points de couture RÉELS (échantillonnés le long des bords de chaque pièce), rivets bombés, entrelacs
    nordiques gravés au fer sur le cuir bouilli, laine sergée et galon tissé, poils de loup en mèches ; crasse dans les creux (AO).
Sorties : assets/modeles/armures/porte/<id>.glb, sol/<id>.glb, chausses/cuir.glb et chausses/fourrure.glb ; pieces.json (agent DONNÉES).
"""
import bpy, bmesh, sys, os, math, random, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, ".."))
sys.path.insert(0, os.path.join(ICI, "..", "legeres"))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAMILLE = next((a for a in ARGS if "=" not in a), "tout")
APERCU = next((a.split("=", 1)[1] for a in ARGS if a.startswith("apercu=")), "")
_argv = sys.argv
sys.argv = [_argv[0], "--", "aucune"]          # gen_legeres ne génère rien à l'import : on ne garde que ses outils
import armures_lib as L
import gen_legeres as X
sys.argv = _argv
from armures_lib import B, G

ARM = X.ARM
TETE, COU = X.TETE, X.COU

# ---------------------------------------------------------------------------------------------------------- palettes
CUIR = L.hexa("#150e09", "#1f150e", "#2b1d13", "#392719", "#483220", "#583e27", "#6a4b2f", "#7d5938", "#906843", "#a47a52")
BOUILLI = L.hexa("#170d08", "#22130b", "#2f1a0e", "#3e2312", "#4d2c17", "#5e371c", "#704223", "#844f2a", "#985d33")
SOMBRE = L.hexa("#0c0806", "#140d09", "#1d140d", "#281b12", "#342418", "#412d1e")
FER = L.hexa("#121214", "#1c1c20", "#2a2b30", "#3c3e45", "#52555d", "#6c7079", "#8b8f99", "#aeb2bc", "#d0d3da")
LAINE = L.hexa("#121512", "#191d19", "#212621", "#2a302a", "#333b33", "#3d463c", "#495347")
LOUP = L.hexa("#15120f", "#221d18", "#302922", "#40372e", "#51463b", "#635749", "#776958", "#8c7d6a", "#a3937f", "#bcad98", "#d2c5b0")
OURS = L.hexa("#140e0a", "#1f160f", "#2c2016", "#3a2a1d", "#4a3624", "#5b432c", "#6d5135")
OS = L.hexa("#2a2116", "#3d3122", "#54452f", "#6c5b3e", "#85724f", "#9c8862", "#b19d76", "#c4b18a", "#d6c59f")
FIL = np.array([0.66, 0.56, 0.40])
OCRE = np.array([0.55, 0.40, 0.16])
GARANCE = np.array([0.36, 0.11, 0.07])

# ---------------------------------------------------------------------------------------------------------- outils géométrie
def plan_xy(a, b, dedans):
    """Plan vertical (contient l'axe z) passant par a=(x, y) et b=(x, y) ; normale vers l'extérieur (opposée au point `dedans`)."""
    a, b, d = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0)), Vector((dedans[0], dedans[1], 0))
    t = (b - a).normalized()
    n = Vector((t.y, -t.x, 0))
    if n.dot(d - a) > 0:
        n = -n
    return (a, n)


def plan(co, no):
    return (Vector(co), Vector(no).normalized())


def couper(bm, plans):
    """Garde le côté dot(p - co, no) <= 0 de chaque plan (repère Godot) : bords nets."""
    for co, no in plans:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=B(co), plane_no=B(no), clear_outer=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')


def surplaque(base, nom, plans, decal, ep, partie, souleve=None, symetrie=False):
    """Plaque découpée dans la surface de `base` par des plans, poussée de `decal` vers l'extérieur (+ souleve(p_godot)), épaisseur
    rabattue sous les bords ; poids du sommet de `base` le plus proche. symetrie : aussi le miroir en x (plans miroités)."""
    jeux = [plans] + ([[(Vector((-co.x, co.y, co.z)), Vector((-no.x, no.y, no.z))) for co, no in plans]] if symetrie else [])
    objs = []
    for k, pl in enumerate(jeux):
        bm = bmesh.new()
        bm.from_mesh(base.data)
        dl = bm.verts.layers.deform.active
        if dl is not None:
            bm.verts.layers.deform.remove(dl)
        couper(bm, pl)
        bm.normal_update()
        part = L.couche_partie(bm)
        for f in bm.faces:
            f[part] = partie
        dep = {}
        for v in bm.verts:
            p = G(v.co)
            dep[v] = v.normal * (decal + (souleve(p) if souleve else 0.0))
        for v, d in dep.items():
            v.co = v.co + d
        X.epaissir_bords(bm, ep)
        o = X.en_objet(bm, "%s_%d" % (nom, k))
        L.ecrire_poids(o, L.normaliser(L.poids_proches(o, base, 3)))
        objs.append(o)
    return objs


def boite(bm, centre, taille, partie, ex=(1, 0, 0), ey=(0, 1, 0)):
    """Pavé (repère Godot) : centre, taille (sx, sy, sz) le long de ex, ey, ex^ey."""
    part = L.couche_partie(bm)
    ex, ey = Vector(ex).normalized(), Vector(ey).normalized()
    ez = ex.cross(ey).normalized()
    ey = ez.cross(ex).normalized()
    c = Vector(centre)
    vs = {}
    for i in (-1, 1):
        for j in (-1, 1):
            for k in (-1, 1):
                vs[(i, j, k)] = bm.verts.new(B(c + ex * i * taille[0] / 2 + ey * j * taille[1] / 2 + ez * k * taille[2] / 2))
    faces = [((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)), ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
             ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)), ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)),
             ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)), ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1))]
    for q in faces:
        f = bm.faces.new([vs[t] for t in q])
        f[part] = partie
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - B(c)) < 0:
            f.normal_flip()


def boucle(bm, centre, normale, haut, larg, haute, ep, partie):
    """Boucle de ceinture en fer : cadre rectangulaire (4 barres) + ardillon, posée sur la surface (normale), `haut` = vertical."""
    n = Vector(normale).normalized()
    u = Vector(haut).normalized()
    u = (u - n * n.dot(u)).normalized()
    s = u.cross(n).normalized()
    c = Vector(centre) + n * ep / 2
    b = 0.0065
    boite(bm, c + u * (haute / 2 - b / 2), (larg, b, ep), partie, s, u)
    boite(bm, c - u * (haute / 2 - b / 2), (larg, b, ep), partie, s, u)
    boite(bm, c + s * (larg / 2 - b / 2), (b, haute - 2 * b, ep), partie, s, u)
    boite(bm, c - s * (larg / 2 - b / 2), (b, haute - 2 * b, ep), partie, s, u)
    boite(bm, c + n * ep * 0.3, (larg * 0.62, 0.0035, ep * 0.7), partie, s, u)      # ardillon


def meches(surf, nom, n, longueur, largeur, partie, graine, zone=None, sens=None, souleve=0.012, double=None, src=None, crete=0.004):
    """Fourrure en MÈCHES : n tuiles effilées réparties à l'aire sur les faces de `surf` retenues par zone(c, n) (repère Godot),
    pointées selon sens(p, n) (projeté sur la surface, ± 25°), racine collée, pointe soulevée ; crête centrale (volume) ; double(p)
    -> mèche double face (celles qui pendent sous un bord). Poids : sommets les plus proches de `src` (ou `surf`)."""
    rng = random.Random(graine)
    me = surf.data
    me.calc_loop_triangles()
    tris, aires = [], []
    for t in me.loop_triangles:
        c = G(t.center)
        nn = G(t.normal)
        if zone is None or zone(c, nn):
            tris.append(t)
            aires.append(t.area)
    cum = np.cumsum(aires)
    bm = bmesh.new()
    part = L.couche_partie(bm)
    for i in range(n):
        t = tris[int(np.searchsorted(cum, rng.random() * cum[-1]))]
        a, b_ = rng.random(), rng.random()
        if a + b_ > 1:
            a, b_ = 1 - a, 1 - b_
        vs = [G(me.vertices[k].co) for k in t.vertices]
        p = vs[0] + (vs[1] - vs[0]) * a + (vs[2] - vs[0]) * b_
        nn = G(t.normal).normalized()
        d = sens(p, nn) if sens else Vector((0, -1, 0))
        d = (d - nn * d.dot(nn))
        if d.length < 1e-4:
            continue
        d = Matrix.Rotation(math.radians(rng.uniform(-25, 25)), 3, nn) @ d.normalized()
        sd = nn.cross(d).normalized()
        l = longueur * (0.75 + 0.5 * rng.random())
        w = largeur * (0.8 + 0.4 * rng.random())
        r0 = p + nn * 0.0015
        mid = p + d * l * 0.55 + nn * (0.002 + souleve * 0.45)
        tip = p + d * l + nn * souleve * (0.6 + 0.8 * rng.random()) + sd * rng.uniform(-0.3, 0.3) * w
        cr = nn * crete
        pts = [r0 - sd * w / 2, r0 + cr, r0 + sd * w / 2, mid - sd * w * 0.32, mid + cr * 0.8, mid + sd * w * 0.32, tip]
        faces = [(0, 3, 4, 1), (1, 4, 5, 2), (3, 6, 4), (4, 6, 5)]
        dbl = double(p, tip) if double else False
        for sens_f in ((1, -1) if dbl else (1,)):
            V = [bm.verts.new(B(q)) for q in pts]
            for fq in faces:
                f = bm.faces.new([V[k] for k in fq])
                f[part] = partie
                f.normal_update()
                if f.normal.dot(B(nn)) * sens_f < 0:
                    f.normal_flip()
    o = X.en_objet(bm, nom)
    L.ecrire_poids(o, L.normaliser(L.poids_proches(o, src or surf, 4)))
    return o


def croc(bm, racine, direction, longueur, rayon, partie, courbe=None):
    """Croc / griffe d'os : cône à 4 pans en 2 segments, légèrement courbé (vers `courbe`)."""
    d = Vector(direction).normalized()
    a = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    s1 = d.cross(a).normalized()
    s2 = d.cross(s1).normalized()
    cb = Vector(courbe).normalized() * longueur * 0.18 if courbe else Vector()
    part = L.couche_partie(bm)
    anneaux = []
    for k, (t, r) in enumerate(((0.0, 1.0), (0.5, 0.62))):
        c = Vector(racine) + d * longueur * t + cb * (t * t)
        anneaux.append([bm.verts.new(B(c + (s1 * math.cos(j * math.pi / 2 + 0.785) + s2 * math.sin(j * math.pi / 2 + 0.785)) * rayon * r)) for j in range(4)])
    pointe = bm.verts.new(B(Vector(racine) + d * longueur + cb))
    c0 = Vector(racine)
    fs = []
    for j in range(4):
        j2 = (j + 1) % 4
        fs.append(bm.faces.new((anneaux[0][j], anneaux[0][j2], anneaux[1][j2], anneaux[1][j])))
        fs.append(bm.faces.new((anneaux[1][j], anneaux[1][j2], pointe)))
    fs.append(bm.faces.new(anneaux[0][::-1]))
    for f in fs:
        f[part] = partie
    bmesh.ops.recalc_face_normals(bm, faces=fs)


def tube(bm, points, rayon, partie, n=4):
    """Cordon (lacet, lanière ronde) le long d'une polyligne (repère Godot)."""
    part = L.couche_partie(bm)
    anneaux = []
    for i, p in enumerate(points):
        d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        a = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        s1 = d.cross(a).normalized()
        s2 = d.cross(s1).normalized()
        anneaux.append([bm.verts.new(B(p + (s1 * math.cos(j * 2 * math.pi / n) + s2 * math.sin(j * 2 * math.pi / n)) * rayon)) for j in range(n)])
    fs = []
    for i in range(len(anneaux) - 1):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append(bm.faces.new((anneaux[i][j], anneaux[i][j2], anneaux[i + 1][j2], anneaux[i + 1][j])))
    for f in fs:
        f[part] = partie
    bmesh.ops.recalc_face_normals(bm, faces=fs)


def sur_surface(bvh, p, d, ecart):
    """Projette p (Godot) sur la surface la plus extérieure de bvh dans la direction -d, + ecart."""
    d = Vector(d).normalized()
    hit = bvh.ray_cast(B(p + d * 0.3), B(-d), 0.6)
    if hit[0] is None:
        return p
    return G(hit[0]) + d * ecart


# ---------------------------------------------------------------------------------------------------------- outils texture
def bords_ext(o):
    """Arêtes du bord VISIBLE de chaque pièce (au-dessus de la tranche rabattue par epaissir_bords) : [(a, b, vers_l_interieur, partie)]."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    part = bm.faces.layers.int.get("partie")
    res = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        f = e.link_faces[0]
        oe, sf = None, None
        if len(f.verts) == 4:
            ve = set(e.verts)
            for e2 in f.edges:
                if not (set(e2.verts) & ve):
                    oe = e2
            if oe is not None:
                autres = [g for g in oe.link_faces if g is not f]
                sf = autres[0] if autres else None
        if sf is None:
            oe, sf = e, f
        a, b = G(oe.verts[0].co), G(oe.verts[1].co)
        c = G(sf.calc_center_median())
        t = (b - a)
        if t.length < 1e-6:
            continue
        t.normalize()
        w = c - a
        dedans = w - t * w.dot(t)
        if dedans.length < 1e-6:
            continue
        res.append((a, b, dedans.normalized(), sf[part] if part else 0))
    bm.free()
    return res


def echantillons(aretes, parties, retrait, pas):
    pts = []
    for a, b, d, p in aretes:
        if p not in parties:
            continue
        n = max(1, int(round((b - a).length / pas)))
        for i in range(n):
            pts.append(a.lerp(b, (i + 0.5) / n) + d * retrait)
    return pts


def kd_de(pts):
    if not pts:
        return None
    kd = KDTree(len(pts))
    for i, q in enumerate(pts):
        kd.insert(q, i)
    kd.balance()
    return kd


def proches(kd, P):
    """Distance au point le plus proche et vecteur (P - point), par texel."""
    if kd is None:
        return np.full(len(P), 1.0), np.zeros((len(P), 3))
    d = np.empty(len(P))
    v = np.empty((len(P), 3))
    for i in range(len(P)):
        co, _, dist = kd.find(P[i])
        d[i] = dist
        v[i] = (P[i][0] - co[0], P[i][1] - co[1], P[i][2] - co[2])
    return d, v


def lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def grain(P, g=0, fort=1.0):
    """Grain du cuir : 4 échelles + plis fins sombres + éraflures claires."""
    v = (L.fbm(P, 5.0, g) - 0.5) * 0.16 + (L.bruit(P, 30.0, g + 1) - 0.5) * 0.08 + (L.bruit(P, 95.0, g + 2) - 0.5) * 0.06 \
        + (L.bruit(P, 260.0, g + 3) - 0.5) * 0.05
    w = np.abs(L.fbm(P * np.array([1.0, 2.6, 1.0]), 9.0, g + 4) - 0.5)
    v = v - 0.11 * (1 - lisse(0.0, 0.022, w))
    e = np.abs(np.sin((P[:, 0] * 0.7 + P[:, 1] * 1.3 + P[:, 2] * 0.4) * 90.0 + L.fbm(P, 5.0, g + 5) * 14.0))
    v = np.where((e < 0.07) & (L.bruit(P, 12.0, g + 6) > 0.78), v + 0.07, v)
    return v * fort


def rgba(rgb, a):
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0.03, 1.0)[:, None]], 1)


def peau(P, N, pal, base, g, brillance=0.35, fort=1.0):
    v = base + grain(P, g, fort) + np.clip(N[:, 1], -1, 1) * 0.05
    return v, rgba(L.rampe(pal, np.clip(v, 0, 0.999)), 0.10 + v * brillance)


def finition_bords(out, de, ds, dv, dr, dvr, m, couture=True, rivets=True):
    """Sur les texels m : biseau usé clair au bord visible (de), rainure, points de couture (ds : distance au point le plus
    proche), rivets bombés (dr, dvr)."""
    k = m & (de < 0.0022)
    out[k, :3] = out[k, :3] * 1.22 + 0.025
    k = m & (de >= 0.0022) & (de < 0.0042)
    out[k, :3] *= 0.70
    if couture:
        t = m & (ds < 0.0016)
        out[t, :3] = out[t, :3] * 0.15 + FIL * (0.80 + 0.35 * (dv[t, 1] / 0.0016)[:, None] * 0.3)
        out[t, 3] = 0.25
        o = m & (ds >= 0.0016) & (ds < 0.0024)
        out[o, :3] *= 0.62
    if rivets:
        r = 0.0042
        t = m & (dr < r)
        h = np.clip(1 - (dr[t] / r) ** 2, 0, 1)
        lum = 0.38 + 0.42 * h + 0.22 * np.clip((dvr[t] @ np.array([0.0, 0.8, 0.6])) / r, -1, 1)
        out[t, :3] = L.rampe(FER, np.clip(lum, 0, 0.999))
        out[t, 3] = 0.9
        o = m & (dr >= r) & (dr < r * 1.45)
        out[o, :3] *= 0.5
    return out


def entrelacs(u, v, K=55.0):
    """Entrelacs nordique : deux familles de rubans ondulés croisés, dessus / dessous alternés. Renvoie (rainure, liseré)."""
    a = (u + v) * K
    b = (u - v) * K
    r1 = np.sin(a + 1.25 * np.sin(b * 0.5))
    r2 = np.sin(b + 1.25 * np.sin(a * 0.5))
    dessus = np.mod(np.floor(a / math.pi) + np.floor(b / math.pi), 2) < 1
    l1 = np.abs(r1) < 0.16
    l2 = np.abs(r2) < 0.16
    rain = (l1 & (dessus | ~l2)) | (l2 & (~dessus | ~l1))
    lis = ((np.abs(r1) >= 0.16) & (np.abs(r1) < 0.26)) | ((np.abs(r2) >= 0.16) & (np.abs(r2) < 0.26))
    return rain, lis & ~rain


def gravure(out, P, N, m, de, cadre=0.011):
    """Cuir bouilli gravé : double filet en cadre à `cadre` m du bord, entrelacs à l'intérieur (projection selon l'axe dominant)."""
    if not m.any():
        return out
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    face = np.abs(N[:, 2]) >= np.abs(N[:, 0])
    u = np.where(face, x, z)
    rain, lis = entrelacs(u, y)
    f1 = m & (np.abs(de - cadre) < 0.0011)
    f2 = m & (np.abs(de - cadre - 0.0042) < 0.0009)
    out[f1 | f2, :3] *= 0.52
    dedans = m & (de > cadre + 0.008)
    out[dedans & rain, :3] *= 0.58
    out[dedans & lis, :3] = out[dedans & lis, :3] * 1.14 + 0.01
    return out


def fourrure_tex(P, N, bd, pal, base, g, sens=(0.0, 1.0, 0.0), meche=False):
    s = np.array(sens, dtype=float)
    s /= np.linalg.norm(s)
    Q = P - np.outer(P @ s, s) * 0.94
    v = base + (L.bruit(Q, 140.0, g) - 0.5) * 0.24 + (L.bruit(Q, 330.0, g + 1) - 0.5) * 0.14 + (L.fbm(Q, 26.0, g + 2) - 0.5) * 0.20 \
        + (L.fbm(P, 4.0, g + 3) - 0.5) * 0.10 + np.clip(N[:, 1], -1, 1) * 0.06
    jarre = L.bruit(Q, 520.0, g + 4) > 0.86                     # poils de jarre clairs, rares
    v = np.where(jarre, v + 0.14, v)
    if meche:
        v = np.where(bd < 0.0016, v - 0.16, np.where(bd < 0.006, v + 0.06, v))   # chaque mèche se détache (bord sombre, coeur clair)
    rgb = L.rampe(pal, np.clip(v, 0, 0.999))
    return rgba(rgb, 0.04 + v * 0.10)


def laine_tex(P, N, g, pal=LAINE, base=0.5):
    """Laine sergée : côtes diagonales (période 6 mm), fils irréguliers, boulochage."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    u = np.arctan2(x, z) * 0.16
    t = np.mod((u + y) / 0.006, 1.0)
    cote = np.abs(t - 0.5) * 2
    v = base + (cote - 0.5) * 0.10 + (L.bruit(P, 180.0, g) - 0.5) * 0.10 + (L.fbm(P, 7.0, g + 1) - 0.5) * 0.14 \
        + np.clip(N[:, 1], -1, 1) * 0.05
    return v, rgba(L.rampe(pal, np.clip(v, 0, 0.999)), 0.05 + v * 0.06)


def galon(out, P, m):
    """Galon tissé aux cartons (losanges ocre sur garance), sur les texels m."""
    if not m.any():
        return out
    c1 = np.array([0.53, 0.62, 0.58])
    c2 = np.array([-0.62, 0.35, 0.70])
    q = np.abs(np.mod(P @ c1 * 70.0, 1.0) - 0.5) + np.abs(np.mod(P @ c2 * 70.0, 1.0) - 0.5)
    lo = q < 0.30
    n = (L.bruit(P, 200.0, 77) - 0.5) * 0.12
    out[m, :3] = GARANCE * (0.9 + n[m, None])
    k = m & lo
    out[k, :3] = OCRE * (0.95 + n[k, None])
    k = m & (q >= 0.30) & (q < 0.36)
    out[k, :3] = np.array([0.10, 0.06, 0.04])
    out[m, 3] = 0.12
    return out


def os_tex(P, N, bd, base=0.62, g=0):
    v = base + (L.fbm(P, 9.0, g) - 0.5) * 0.10 + (L.bruit(P, 120.0, g + 1) - 0.5) * 0.06 + np.clip(N[:, 1], -1, 1) * 0.08
    f = np.abs(L.fbm(P, 30.0, g + 2) - 0.5)
    v = np.where(f < 0.012, v - 0.18, v)
    rgb = L.rampe(OS, np.clip(v, 0, 0.999))
    return rgba(rgb, 0.35 + v * 0.4)


def fer_tex(P, N, base=0.55, g=0):
    v = base + (L.fbm(P, 40.0, g) - 0.5) * 0.25 + np.clip(N[:, 1], -1, 1) * 0.12
    rgb = L.rampe(FER, np.clip(v, 0, 0.999))
    rouille = np.clip((L.fbm(P, 12.0, g + 1) - 0.6) * 3.0, 0, 1)[:, None]
    rgb = rgb * (1 - 0.35 * rouille) + np.array([0.32, 0.16, 0.07]) * 0.35 * rouille
    return rgba(rgb, 0.65 + v * 0.3)


class Ctx:
    """Données de bord d'une pièce (calculées sur la pièce finale) pour sa fonction de matière."""
    def __init__(self, o, coutures=(), rivets=(), pas_couture=0.0055, retrait_couture=0.0072, pas_rivet=0.034, retrait_rivet=0.012,
                 rivets_en_plus=()):
        ar = bords_ext(o)
        self.ext = kd_de([p for a, b, d, q in ar for p in (a.lerp(b, i / max(1, int((b - a).length / 0.002))) for i in range(max(1, int((b - a).length / 0.002)) + 1))])
        self.cout = kd_de(echantillons(ar, set(coutures), retrait_couture, pas_couture))
        self.riv = kd_de(echantillons(ar, set(rivets), retrait_rivet, pas_rivet) + list(rivets_en_plus))

    def __call__(self, P):
        de, _ = proches(self.ext, P)
        ds, dv = proches(self.cout, P)
        dr, dvr = proches(self.riv, P)
        return de, ds, dv, dr, dvr


# ---------------------------------------------------------------------------------------------------------- famille / atlas
FAM = []
PIECES = []
ATLAS = 1024
ZONES = [(0, 0, 1024, 576), (0, 576, 384, 448), (384, 576, 288, 448), (672, 576, 352, 448)]
JSON_PIECES = []


def finir(o, matiere, ident, tris_max, sol, mats=("cuir",), slot=None, tris_min=0):
    """slot(partie) -> indice dans mats (0 par défaut) : surface 0 = matière principale (ourlets / hauts de bottes lus dessus)."""
    L.lisser_normales(o)
    nb = L.nb_tris(o)
    print("PIECE %s : %d triangles (cible %d-%d)" % (ident, nb, tris_min, tris_max))
    assert nb <= tris_max, ident
    FAM.append({"o": o, "matiere": matiere, "ident": ident, "sol": sol, "mats": mats, "slot": slot, "tris": nb})


def finir_famille(nom):
    atlas = np.zeros((ATLAS, ATLAS, 4))
    atlas[:, :, 3] = 1.0
    for piece, (x, y, w, h) in zip(FAM, ZONES):
        o = piece["o"]
        L.uv_auto(o, 4.0 / min(w, h), 66)
        rgba_ = L.cuire(o, piece["matiere"], (w, h), piece["ident"], tableau=True)
        atlas[y:y + h, x:x + w] = rgba_
        for uv in o.data.uv_layers.active.data:
            uv.uv = ((x + uv.uv[0] * w) / ATLAS, (y + uv.uv[1] * h) / ATLAS)
        print("  cuit", piece["ident"])
    img = L.image_atlas("atlas_" + nom, atlas)
    mats = {}
    for piece in FAM:
        o = piece["o"]
        o.data.materials.clear()
        for nm in piece["mats"]:
            if nm not in mats:
                mats[nm] = L.materiau(nm, img)
            o.data.materials.append(mats[nm])
        if piece["slot"] is not None:
            attr = o.data.attributes.get("partie")
            for p in o.data.polygons:
                p.material_index = piece["slot"](attr.data[p.index].value if attr else 0)
        if APERCU:
            PIECES.append(o)
        L.exporter(o, ARM, piece["ident"], piece["sol"])
    FAM.clear()


# ============================================================================================================ CUIR
## parties : 0 coque (cuir souple), 1 ceinture, 2 épaulières (bouilli), 3 col, 5 plastron (bouilli gravé), 6 lames du ventre,
## 7 plaque du dos, 8 tassettes, 9 fer (boucles), 10 sacoche
def cuir():
    base = X.torse_base("armure_cuir", 700)
    tronc = X.torse_base("plaques_src", 430)      # source plus légère des plaques (bords découpés nets, peu de triangles)
    plaques = []
    # plastron en deux pièces de cuir bouilli (laçage au milieu), coins abattus
    pl = [plan((0.016, 0, 0), (-1, 0, 0)), plan((0.158, 0, 0), (1, 0, 0)), plan((0, 1.43, 0), (0, 1, 0)), plan((0, 1.205, 0), (0, -1, 0)),
          plan((0, 0, 0.02), (0, 0, -1)), plan_xy((0.158, 1.27), (0.105, 1.205), (0.05, 1.3)), plan_xy((0.016, 1.38), (0.06, 1.43), (0.1, 1.3))]
    plaques += surplaque(tronc, "plastron", pl, 0.017, 0.007, 5, symetrie=True)
    # trois lames de ventre qui se chevauchent (la plus haute par-dessus), bord bas soulevé
    for i, (yh, yb, dc) in enumerate([(1.21, 1.135, 0.014), (1.142, 1.07, 0.011), (1.077, 1.0, 0.008)]):
        pl = [plan((0, yh, 0), (0, 1, 0)), plan((0, yb, 0), (0, -1, 0)), plan((0.185, 0, 0), (1, 0, 0)), plan((-0.185, 0, 0), (-1, 0, 0)),
              plan((0, 0, -0.03), (0, 0, -1))]
        plaques += surplaque(tronc, "lame%d" % i, pl, dc, 0.006, 6, souleve=lambda p, yh=yh, yb=yb: 0.004 * max(0.0, min(1.0, (yh - p.y) / (yh - yb))))
    # plaque du dos (omoplates), coins abattus
    pl = [plan((0.155, 0, 0), (1, 0, 0)), plan((-0.155, 0, 0), (-1, 0, 0)), plan((0, 1.43, 0), (0, 1, 0)), plan((0, 1.17, 0), (0, -1, 0)),
          plan((0, 0, -0.03), (0, 0, 1)), plan_xy((0.155, 1.24), (0.09, 1.17), (0, 1.3)), plan_xy((-0.155, 1.24), (-0.09, 1.17), (0, 1.3))]
    plaques += surplaque(tronc, "dos", pl, 0.012, 0.007, 7)
    # tassettes : quatre pans de cuir bouilli sur la jupe (devant et derrière), suivent les cuisses
    for zs in (1,):
        pl = [plan((0.03, 0, 0), (-1, 0, 0)), plan((0.175, 0, 0), (1, 0, 0)), plan((0, 0.925, 0), (0, 1, 0)), plan((0, 0.70, 0), (0, -1, 0)),
              plan((0, 0, 0.0), (0, 0, -zs))]
        plaques += surplaque(tronc, "tass", pl, 0.009, 0.006, 8, symetrie=True,
                             souleve=lambda p: 0.006 * max(0.0, min(1.0, (0.90 - p.y) / 0.2)))
    bel = X.ceinture("ceint", 0.930, 0.996, 0.012, 20)
    # boucle de fer devant + sacoche au flanc arrière droit
    bm = bmesh.new()
    shell = L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3)
    c = sur_surface(shell, Vector((0, 0.963, 0.0)), (0, 0, 1), 0.024)
    boucle(bm, c, (0, 0, 1), (0, 1, 0), 0.056, 0.060, 0.007, 9)
    for xx in (-0.16, 0.16, -0.08, 0.08):        # passants de fer
        cc = sur_surface(shell, Vector((xx, 0.963, 0.0)), (xx * 3, 0, 1), 0.026)
        boite(bm, cc, (0.010, 0.074, 0.005), 9, Vector((1, 0, -xx * 3)).normalized(), (0, 1, 0))
    o_fer = X.en_objet(bm, "fer")
    X.poids_de(o_fer, "tunique", lambda p: abs(p.x) < 0.3)
    bm = bmesh.new()
    cs = sur_surface(shell, Vector((-0.13, 0.895, -0.10)), (-0.6, 0, -1), 0.045)
    boite(bm, cs, (0.10, 0.11, 0.045), 10, Vector((0.85, 0, -0.5)).normalized() * -1, (0, 1, 0))
    boite(bm, cs + Vector((0, 0.035, 0)) + Vector((-0.6, 0, -1)).normalized() * 0.024, (0.105, 0.05, 0.008), 10,
          Vector((0.85, 0, -0.5)).normalized() * -1, (0, 1, 0))
    o_sac = X.en_objet(bm, "sac")
    X.poids_de(o_sac, "tunique", lambda p: abs(p.x) < 0.3 and p.y > 0.95)
    ep_l = X.epauliere("ep_l", "l", [(0.14, 0.31, 0.008, 110), (0.19, 0.37, 0.008, 100), (0.245, 0.43, 0.008, 90)], n=6)
    ep_r = X.epauliere("ep_r", "r", [(0.14, 0.31, 0.008, 110), (0.19, 0.37, 0.008, 100), (0.245, 0.43, 0.008, 90)], n=6)
    col = X.col_montant("col", n=12)
    bpy.data.objects.remove(tronc)
    o = X.fusion([base] + plaques + [bel, o_fer, o_sac, ep_l, ep_r, col], "armure_cuir")
    ctx = Ctx(o, coutures=(0, 1, 2, 3, 5, 6, 7, 8, 10), rivets=(2, 6, 8), pas_rivet=0.038, retrait_rivet=0.013)

    def mat(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        de, ds, dv, dr, dvr = ctx(P)
        v, out = peau(P, N, CUIR, 0.50, 101, 0.30)
        # laçage du plastron : lacets croisés + oeillets sur la coque au milieu
        lac = (pa == 0) & (z > 0.05) & (y > 1.2) & (y < 1.44) & (np.abs(x) < 0.03)
        ph = np.mod(y / 0.026, 1.0)
        croix = lac & (np.abs(np.abs(x) - np.abs(ph - 0.5) * 0.032) < 0.0028)
        out[lac & ~croix, :3] *= 0.45
        out[croix, :3] = L.rampe(CUIR, np.full(croix.sum(), 0.78)) * (0.9 + 0.2 * np.abs(ph[croix] - 0.5))[:, None]
        # coque : coutures de côté et milieu du dos
        cou = (pa == 0) & (((np.abs(np.abs(x) - 0.17) < 0.0016) & (np.abs(z) < 0.06)) | ((np.abs(x) < 0.0016) & (z < -0.05) & (y > 0.86)))
        out[cou, :3] *= 0.55
        # cuir bouilli (plaques) : plus sombre, roux, ciré, gravé
        for p_, base_, g_ in ((5, 0.52, 111), (6, 0.48, 113), (7, 0.50, 117), (8, 0.46, 119), (2, 0.55, 121)):
            m = pa == p_
            if m.any():
                _, o2 = peau(P[m], N[m], BOUILLI, base_, g_, 0.55, 0.8)
                out[m] = o2
        out = gravure(out, P, N, (pa == 5) | (pa == 7), de, 0.010)
        # lames du ventre et tassettes : un seul filet gravé
        m = (pa == 6) | (pa == 8)
        out[m & (np.abs(de - 0.008) < 0.001), :3] *= 0.55
        # ceinture et sacoche : cuir sombre
        for p_, g_ in ((1, 131), (10, 133), (3, 135)):
            m = pa == p_
            if m.any():
                _, o2 = peau(P[m], N[m], SOMBRE if p_ != 3 else CUIR, 0.42 if p_ != 3 else 0.40, g_, 0.35)
                out[m] = o2
        # fer
        m = pa == 9
        if m.any():
            out[m] = fer_tex(P[m], N[m], 0.6, 137)
        out = finition_bords(out, de, ds, dv, dr, dvr, (pa != 9))
        # crasse : bas de la jupe
        b = y < 0.80
        out[b, :3] *= (0.72 + 0.28 * np.clip((y[b] - 0.66) / 0.14, 0, 1))[:, None]
        return out
    finir(o, mat, "armure_cuir", 2500, X.sol_torse, ("cuir", "fer"), lambda p: 1 if p == 9 else 0, 1500)
    JSON_PIECES.append({"id": "armure_cuir", "nom": "Justaucorps de cuir bouilli", "emplacement": "torse", "matiere": "cuir", "poids": 6.0})

    # --- capuche_cuir : capuche ajustée (32 colonnes), pèlerine courte, couture du crâne, bordure cousue, lacet de gorge
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau", "Hair_Beard", "accessoires_0"],
                      filtre=lambda p: p.y > 1.38 and abs(p.x) < 0.30 and not (p.y > 1.60 and p.z > 0.06))
    lignes = [90, 80, 70, 60, 50, 40, 31, 22, 13, 4, -5, -14, -23, -32, -41, -50, -58, -66]

    def jeu(th, ph):
        dos = max(0.0, -math.cos(th))
        haut = max(0.0, math.sin(ph))
        return 0.015 + 0.012 * dos * haut + (0.022 * (0.4 + 0.6 * dos) if ph < -0.5 else 0.0)

    def garder(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        if ph < math.radians(-30):
            return t > math.radians(50)
        if ph < math.radians(30):
            return t > math.radians(52 - 8 * max(0.0, -ph))
        return True
    bm = X.coque_tete("capuche_cuir", lignes, 32, jeu, garder, cibles)
    for v in bm.verts:
        p = G(v.co) - TETE
        if p.y > 0.06 and p.z < 0.0:
            v.co = B(TETE + p + Vector((0, -0.006, -0.012)) * (p.y - 0.06) / 0.05 * max(0.0, -p.z) / 0.1)
    X.epaissir_bords(bm, 0.008)
    o = X.en_objet(bm, "capuche_cuir")
    pw_p = L.poids_proches(o, bpy.data.objects["peau"], 4, lambda p: p.y > 1.40 and abs(p.x) < 0.2)
    pw_t = L.poids_proches(o, bpy.data.objects["tunique"], 4, lambda p: p.y > 1.30 and abs(p.x) < 0.3)
    pw = []
    for v, a, b in zip(o.data.vertices, pw_p, pw_t):
        r = math.hypot(G(v.co).x, G(v.co).z - COU.z)
        u = min(1.0, max(0.0, (r - 0.09) / 0.06))
        d = {k: x_ * (1 - u) for k, x_ in a.items()}
        for k, x_ in b.items():
            d[k] = d.get(k, 0.0) + x_ * u
        pw.append(d)
    res = []
    for v, d in zip(o.data.vertices, pw):
        y = G(v.co).y
        t = min(1.0, max(0.0, (y - (COU.y + 0.03)) / 0.06))
        dd = {k: x_ * (1 - t) for k, x_ in d.items()}
        dd["Head"] = dd.get("Head", 0.0) + t
        res.append(dd)
    res = L.lisser_poids(o, res, 3, 0.5)
    L.ecrire_poids(o, L.normaliser(res))
    ctx_c = Ctx(o, coutures=(0,), pas_couture=0.005)

    def mat_cap(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        de, ds, dv, dr, dvr = ctx_c(P)
        v, out = peau(P, N, CUIR, 0.48, 141, 0.30)
        # coutures des panneaux : milieu du crâne (bourrelet) et deux coutures latérales
        r = P - np.array(TETE[:])
        az = np.arctan2(r[:, 0], r[:, 2])
        for a0 in (math.pi, math.pi * 0.42, -math.pi * 0.42):
            dd = np.abs(np.angle(np.exp(1j * (az - a0)))) * np.hypot(r[:, 0], r[:, 2])
            m = (dd < 0.0018) & (y > TETE.y - 0.02)
            out[m, :3] *= 0.5
            pts = (np.abs(dd - 0.0045) < 0.0013) & (np.mod(y / 0.0055, 1.0) < 0.55) & (y > TETE.y - 0.02)
            out[pts, :3] = out[pts, :3] * 0.2 + FIL * 0.8
        mc = (np.abs(x) < 0.0022) & (y > TETE.y + 0.02)
        out[mc, :3] *= 0.5
        # bordure rapportée de cuir sombre autour du visage et de la pèlerine (1,6 cm)
        bo = de < 0.016
        out[bo, :3] = out[bo, :3] * 0.62
        out = finition_bords(out, de, ds, dv, dr, dvr, np.ones(len(P), bool), rivets=False)
        # lacet de gorge (sous le menton, de part et d'autre de l'ouverture)
        g = (y < COU.y + 0.06) & (y > COU.y - 0.04) & (z > COU.z + 0.03) & (de > 0.004) & (de < 0.02) & (np.mod(y / 0.018, 1.0) < 0.35)
        out[g, :3] = L.rampe(CUIR, np.full(g.sum(), 0.8))
        return out
    finir(o, mat_cap, "capuche_cuir", 1400, X.sol_tete, tris_min=800)
    JSON_PIECES.append({"id": "capuche_cuir", "nom": "Capuche de rôdeur", "emplacement": "tete", "matiere": "cuir", "poids": 1.0})

    # --- gants_cuir : gants entiers (sans décimation), brassards lacés, plaques de jointures en cuir bouilli rivetées
    g = X.gants_base("gants_cuir", 620)
    parts = [g]
    for cote in ("l", "r"):
        parts.append(X.manchette("m_" + cote, "brassards", 0.548, 0.676, 0.009, 0.006, 0.005, 16, 1, cote, 0.005))
    hl = X.os_g("hand_l")
    pl = [plan((hl.x + 0.02, 0, 0), (-1, 0, 0)), plan((hl.x + 0.095, 0, 0), (1, 0, 0)), plan((0, hl.y + 0.004, 0), (0, -1, 0)),
          plan((0, 0, hl.z + 0.036), (0, 0, 1)), plan((0, 0, hl.z - 0.036), (0, 0, -1))]
    parts += surplaque(g, "jointures", pl, 0.004, 0.004, 5, symetrie=True)
    o = X.fusion(parts, "gants_cuir")
    ctx_g = Ctx(o, coutures=(0, 1, 5), rivets=(5,), pas_rivet=0.03, retrait_rivet=0.008, pas_couture=0.0045, retrait_couture=0.004)

    def mat_g(P, N, pa, bd):
        x = np.abs(P[:, 0])
        de, ds, dv, dr, dvr = ctx_g(P)
        v, out = peau(P, N, CUIR, 0.46, 151, 0.30)
        # paume plus claire et usée, entre-doigts sombres
        pal_ = (pa == 0) & (N[:, 1] < -0.4)
        out[pal_, :3] *= 1.12
        m = pa == 1
        _, out[m] = peau(P[m], N[m], SOMBRE, 0.40, 153, 0.35)
        # laçage du brassard sur le dessus (lacets clairs croisés)
        lac = m & (N[:, 1] > 0.55)
        ph = np.mod(x / 0.016, 1.0)
        zc = P[:, 2] - X.os_g("hand_l").z
        cr = lac & (np.abs(np.abs(zc) - np.abs(ph - 0.5) * 0.02) < 0.0022)
        out[cr, :3] = L.rampe(CUIR, np.full(cr.sum(), 0.82))
        m = pa == 5
        _, out[m] = peau(P[m], N[m], BOUILLI, 0.52, 155, 0.55)
        out = finition_bords(out, de, ds, dv, dr, dvr, np.ones(len(P), bool))
        return out
    finir(o, mat_g, "gants_cuir", 1200, X.sol_paire_mains, tris_min=600)
    JSON_PIECES.append({"id": "gants_cuir", "nom": "Gants de cuir lacés", "emplacement": "mains", "matiere": "cuir", "poids": 1.0})

    # --- bottes_cuir : bottes hautes, revers, sangle à boucle de fer, jambière de cuir bouilli sur le tibia
    b = X.bottes_base("bottes_cuir", 490)
    parts = [b]
    bm = bmesh.new()
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        parts.append(X.revers_botte("rv_" + cote, cote, 0.355, 0.435, 0.007, 0.009, 0.005, 14, 1, evase=0.004))
        parts.append(X.revers_botte("s1_" + cote, cote, 0.205, 0.240, 0.004, 0.004, 0.006, 12, 2))
        k = X.os_g("calf_" + cote)
        f_ = X.os_g("foot_" + cote)
        t = (0.222 - f_.y) / (k.y - f_.y)
        c = f_.lerp(k, t)
        cb = L.bvh_de(["bottes"], filtre=lambda p, s=s: (p.x > 0) == (s > 0))
        q = sur_surface(cb, Vector((c.x + s * 0.045, 0.222, c.z + 0.02)), (s * 1, 0, 0.3), 0.012)
        boucle(bm, q, (s * 1, 0, 0.3), (0, 1, 0), 0.028, 0.034, 0.005, 9)
    o_fer = X.en_objet(bm, "fer_b")
    X.poids_de(o_fer, "bottes", None)
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        k = X.os_g("calf_" + cote)
        pl = [plan((0, 0.345, 0), (0, 1, 0)), plan((0, 0.255, 0), (0, -1, 0)), plan((0, 0, k.z + 0.01), (0, 0, -1)),
              plan((k.x + 0.05, 0, 0), (1, 0, 0)), plan((k.x - 0.05, 0, 0), (-1, 0, 0))]
        parts += surplaque(b, "tibia_" + cote, pl, 0.006, 0.005, 5)
    parts.append(o_fer)
    o = X.fusion(parts, "bottes_cuir")
    ctx_b = Ctx(o, coutures=(0, 1, 2, 5), rivets=(5,), pas_rivet=0.03, retrait_rivet=0.009)

    def mat_b(P, N, pa, bd):
        y = P[:, 1]
        de, ds, dv, dr, dvr = ctx_b(P)
        v, out = peau(P, N, CUIR, 0.45, 161, 0.30)
        sem = (pa == 0) & (y < 0.028)
        out[sem, :3] = L.rampe(SOMBRE, np.full(sem.sum(), 0.2)) * (0.9 + 0.2 * L.bruit(P[sem], 200.0, 3))[:, None]
        tal = (pa == 0) & (y < 0.06) & (P[:, 2] < X.os_g("foot_l").z - 0.03)
        out[tal, :3] *= 0.7
        boue = (pa == 0) & (y < 0.14)
        out[boue, :3] *= (0.62 + 0.38 * y[boue, None] / 0.14)
        for p_, pal, base_, g_ in ((2, SOMBRE, 0.40, 163), (1, CUIR, 0.56, 165), (5, BOUILLI, 0.52, 167)):
            m = pa == p_
            if m.any():
                _, out[m] = peau(P[m], N[m], pal, base_, g_, 0.5 if p_ == 5 else 0.3)
        m = pa == 9
        if m.any():
            out[m] = fer_tex(P[m], N[m], 0.6, 169)
        out = gravure(out, P, N, pa == 5, de, 0.008)
        out = finition_bords(out, de, ds, dv, dr, dvr, pa != 9)
        return out
    finir(o, mat_b, "bottes_cuir", 1200, X.sol_paire_pieds, ("cuir", "fer"), lambda p: 1 if p == 9 else 0, 600)
    JSON_PIECES.append({"id": "bottes_cuir", "nom": "Bottes de rôdeur", "emplacement": "pieds", "matiere": "cuir", "poids": 2.0})


# ============================================================================================================ FOURRURE
## parties : 0 coque (laine sergée), 1 ceinture, 3 col, 4 pelisse (peau de loup), 11 mèches, 12 os (crocs, olive de fermeture),
## 13 baudrier de cuir, 14 cordon
def fourrure():
    base = X.torse_base("armure_fourrure", 980, jeu=lambda p: 0.013)
    # pelisse de loup sur les épaules (découpée dans la coque, bord bas gonflé)
    pl = [plan((0, 1.235, 0), (0, -1, 0)), plan((0, 1.525, 0), (0, 1, 0)), plan((0.33, 0, 0), (1, 0, 0)), plan((-0.33, 0, 0), (-1, 0, 0))]
    pel = surplaque(base, "pelisse", pl, 0.021, 0.010, 4, souleve=lambda p: 0.010 * max(0.0, min(1.0, (1.42 - p.y) / 0.18)))[0]
    # baudrier de cuir en travers (épaule gauche -> hanche droite), sous la pelisse
    nb = Vector((0.62, -0.78, 0)).normalized()
    c0 = Vector((0, 1.17, 0))
    pl = [(c0 + nb * 0.028, nb), (c0 - nb * 0.028, -nb), plan((0, 1.28, 0), (0, 1, 0)), plan((0, 0.99, 0), (0, -1, 0))]
    baud = surplaque(base, "baudrier", pl, 0.006, 0.005, 13)
    bel = X.ceinture("ceint", 0.935, 0.995, 0.012, 24)
    surf = pel
    cnt = Vector((0, 1.58, COU.z - 0.01))

    def sens_p(p, n):
        r = p - cnt
        return Vector((r.x, -0.75 * max(0.3, Vector((r.x, 0, r.z)).length * 4.0), r.z))
    # mèches : 3 couches (dessous longues qui pendent sous le bord, milieu, dessus courtes vers le col)
    m1 = meches(surf, "m1", 120, 0.075, 0.034, 11, 5, zone=lambda c, n: c.y < 1.36 and n.y > -0.5, sens=sens_p, souleve=0.014,
                double=lambda p, t: t.y < 1.27, src=base)
    m2 = meches(surf, "m2", 110, 0.060, 0.030, 11, 6, zone=lambda c, n: 1.33 < c.y < 1.45 and n.y > -0.5, sens=sens_p, souleve=0.012, src=base)
    m3 = meches(surf, "m3", 80, 0.045, 0.026, 11, 7, zone=lambda c, n: c.y > 1.43 and n.y > -0.2, sens=sens_p, souleve=0.008, src=base)
    # olive d'os qui ferme la pelisse devant, sur un cordon ; collier de crocs
    bm = bmesh.new()
    import mathutils
    bvh_s = mathutils.bvhtree.BVHTree.FromObject(surf, bpy.context.evaluated_depsgraph_get())
    pts = []
    for i in range(13):
        a = -1.0 + 2.0 * i / 12
        p = Vector((0.11 * a, 1.36 - 0.06 * (1 - a * a), 0.3))
        pts.append(sur_surface(bvh_s, p, (a * 0.4, 0.2, 1), 0.020))
    tube(bm, pts, 0.0028, 14, 4)
    for i, a in enumerate((-0.5, -0.25, 0.0, 0.25, 0.5)):
        k = int(round((a + 1) / 2 * 12))
        q = pts[k]
        croc(bm, q - Vector((0, 0.004, 0)), Vector((a * 0.25, -1, 0.15)), 0.040 if a == 0 else 0.032, 0.0062 if a == 0 else 0.0052, 12,
             courbe=(0, 0, 1))
    o_os = X.en_objet(bm, "colier")
    L.ecrire_poids(o_os, L.normaliser(L.poids_proches(o_os, base, 4)))
    # boucle de ceinture en os (deux olives) + passants
    bm = bmesh.new()
    shell = L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3)
    c = sur_surface(shell, Vector((0, 0.965, 0.0)), (0, 0, 1), 0.026)
    boite(bm, c + Vector((0.016, 0, 0)), (0.026, 0.050, 0.012), 12, (1, 0, 0), (0, 1, 0))
    boite(bm, c - Vector((0.016, 0, 0)), (0.026, 0.050, 0.012), 12, (1, 0, 0), (0, 1, 0))
    o_bo = X.en_objet(bm, "boucle_os")
    X.poids_de(o_bo, "tunique", lambda p: abs(p.x) < 0.3)
    col = X.col_montant("col", n=16)
    o = X.fusion([base, pel] + baud + [bel, m1, m2, m3, o_os, o_bo, col], "armure_fourrure")
    ctx = Ctx(o, coutures=(0, 1, 13), rivets=(13,), pas_rivet=0.05, retrait_rivet=0.012)

    def mat(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        de, ds, dv, dr, dvr = ctx(P)
        v, out = laine_tex(P, N, 201)
        # galon tissé aux bords de la tunique (ourlet, emmanchures)
        out = galon(out, P, (pa == 0) & (de > 0.004) & (de < 0.024))
        # cuir : ceinture, col, baudrier
        for p_, pal, base_, g_ in ((1, SOMBRE, 0.40, 203), (3, CUIR, 0.44, 205), (13, CUIR, 0.50, 207)):
            m = pa == p_
            if m.any():
                _, out[m] = peau(P[m], N[m], pal, base_, g_, 0.35)
        # peau de loup (pelisse) et mèches
        m = pa == 4
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.50, 209)
        m = pa == 11
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.56, 211, meche=True)
        m = pa == 12
        out[m] = os_tex(P[m], N[m], bd[m], 0.66, 213)
        m = pa == 14
        out[m] = rgba(L.rampe(SOMBRE, np.full(m.sum(), 0.6)), np.full(m.sum(), 0.2))
        cuirs = (pa == 1) | (pa == 3) | (pa == 13)
        out = finition_bords(out, de, ds, dv, dr, dvr, cuirs)
        b = (pa == 0) & (y < 0.80)
        out[b, :3] *= (0.75 + 0.25 * np.clip((y[b] - 0.66) / 0.14, 0, 1))[:, None]
        return out
    finir(o, mat, "armure_fourrure", 2500, X.sol_torse, ("cuir", "fourrure", "os"),
          lambda p: 1 if p in (4, 11) else (2 if p == 12 else 0), 1500)
    JSON_PIECES.append({"id": "armure_fourrure", "nom": "Pelisse de loup du chasseur", "emplacement": "torse", "matiere": "fourrure", "poids": 7.0})

    # --- casque_fourrure : calotte de cuir à 4 panneaux et bandes cloutées, bourrelet de loup en mèches, rabats doublés, crocs au front
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.50 and abs(p.x) < 0.2)
    lignes = [90, 78, 66, 55, 45, 36, 28, 20, 12, 4, -4, -12, -18]

    def garder_c(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        return ph > math.radians(24) or t > math.radians(80)
    bm = X.coque_tete("casque_fourrure", lignes, 28, lambda th, ph: 0.020, garder_c, cibles, 0)
    X.epaissir_bords(bm, 0.008)
    o_dome = X.en_objet(bm, "dome")
    bm = bmesh.new()
    axe, ref = (0, 1, 0), (0, 0, 1)
    c = TETE + Vector((0, 0.072, -0.008))
    cbas = TETE + Vector((0, 0.040, -0.008))
    f0 = L.rayon_sur(cibles, c, axe, ref, 0.018)
    f1 = L.rayon_sur(cibles, cbas, axe, ref, 0.016)
    rs = [lambda t: f0(t) - 0.004, lambda t: f0(t) + 0.010, lambda t: (f0(t) + f1(t)) / 2 + 0.020, lambda t: f1(t) + 0.012, lambda t: f1(t) - 0.004]
    cs = [(c + Vector((0, 0.02, 0)), axe, ref), (c + Vector((0, 0.012, 0)), axe, ref), ((c + cbas) / 2, axe, ref), (cbas, axe, ref),
          (cbas + Vector((0, 0.004, 0)), axe, ref)]
    L.anneau(bm, cs, rs, 28, 4)
    X.orienter(bm, list(bm.faces), TETE + Vector((0, 0.2, 0)), TETE - Vector((0, 0.2, 0)))
    o_bord = X.en_objet(bm, "bord")
    rabats = []
    for s in (1, -1):
        bm = bmesh.new()
        axe2 = Vector((0, 1, 0))
        cs, rs = [], []
        for k, dy in enumerate([0.045, 0.015, -0.02, -0.06]):
            cc = TETE + Vector((0, dy, -0.012))
            cs.append((cc, axe2, (0, 0, 1)))
            rs.append(L.rayon_sur(cibles, cc, axe2, (0, 0, 1), 0.026 + 0.003 * k))
        th0 = math.pi / 2 if s > 0 else -math.pi / 2
        L.anneau(bm, cs, rs, 6, 5, ferme=False, arc=(th0 - 0.48, th0 + 0.48))
        X.orienter(bm, list(bm.faces), TETE + Vector((0, 0.3, 0)), TETE - Vector((0, 0.3, 0)))
        X.epaissir_bords(bm, 0.007)
        X.franges(bm, 0.016, filtre=lambda e: max(G(e.verts[0].co).y, G(e.verts[1].co).y) < TETE.y - 0.03, graine=3 + s, bas=0.8, demi=False)
        rabats.append(X.en_objet(bm, "rabat"))
    mb = meches(o_bord, "mb", 90, 0.034, 0.024, 11, 9, zone=lambda cc, n: Vector((n.x, 0, n.z)).length > 0.5,
                sens=lambda p, n: Vector((p.x - TETE.x, -0.5, p.z - TETE.z)), souleve=0.010, crete=0.003, src=o_bord)
    bm = bmesh.new()
    for a in (-0.32, 0.0, 0.32):
        d = Vector((math.sin(a), 0, math.cos(a)))
        q = sur_surface(cibles, TETE + Vector((0, 0.085, 0)) + d * 0.02, d + Vector((0, 0.25, 0)), 0.026)
        croc(bm, q, Vector((d.x * 0.3, 1.0, d.z * 0.5)), 0.034 if a == 0 else 0.026, 0.0058 if a == 0 else 0.0048, 12, courbe=(0, 0, -1))
    o_crocs = X.en_objet(bm, "crocs")
    o = X.fusion([o_dome, o_bord, mb, o_crocs] + rabats, "casque_fourrure")
    X.tete_rigide(o)
    ctx_c = Ctx(o, coutures=(0, 5), rivets=(), pas_couture=0.005,
                rivets_en_plus=[sur_surface(cibles, TETE + Vector((math.sin(t) * 0.05 * math.cos(ph), 0.05 + 0.1 * math.sin(ph), math.cos(t) * 0.05 * math.cos(ph))),
                                            Vector((math.sin(t) * math.cos(ph), math.sin(ph), math.cos(t) * math.cos(ph))), 0.020)
                                for t in (0, math.pi / 2, math.pi, -math.pi / 2) for ph in (math.radians(40), math.radians(52), math.radians(64), math.radians(76))])

    def mat_c(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        de, ds, dv, dr, dvr = ctx_c(P)
        v, out = peau(P, N, CUIR, 0.42, 221, 0.32)
        # bandes de cuir bouilli en croix sur la calotte, cloutées
        r = P - np.array(TETE[:])
        bande_ = (pa == 0) & ((np.abs(r[:, 0]) < 0.012) | (np.abs(r[:, 2]) < 0.012)) & (r[:, 1] > 0.03)
        _, out[bande_] = peau(P[bande_], N[bande_], BOUILLI, 0.52, 223, 0.55)
        lb = (pa == 0) & ((np.abs(np.abs(r[:, 0]) - 0.012) < 0.0012) | (np.abs(np.abs(r[:, 2]) - 0.012) < 0.0012)) & (r[:, 1] > 0.03)
        out[lb, :3] *= 0.5
        m = pa == 4
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.52, 225)
        m = pa == 11
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.58, 227, meche=True)
        m = pa == 5
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.48, 229)
        m = pa == 12
        out[m] = os_tex(P[m], N[m], bd[m], 0.68, 231)
        out = finition_bords(out, de, ds, dv, dr, dvr, pa == 0)
        return out
    finir(o, mat_c, "casque_fourrure", 1400, X.sol_tete, ("cuir", "fourrure", "os"), lambda p: 1 if p in (4, 5, 11) else (2 if p == 12 else 0), 800)
    JSON_PIECES.append({"id": "casque_fourrure", "nom": "Bonnet de loup", "emplacement": "tete", "matiere": "fourrure", "poids": 1.5})

    # --- gants_fourrure : gants de cuir, gros revers de loup en mèches, lanière croisée
    g = X.gants_base("gants_fourrure", 560, 0.005)
    parts = [g]
    revs = []
    for cote in ("l", "r"):
        r_ = X.manchette("mf_" + cote, "brassards", 0.548, 0.668, 0.011, 0.007, 0.007, 14, 4, cote, 0.006)
        revs.append(r_)
        s = 1 if cote == "l" else -1
        parts.append(meches(r_, "mg_" + cote, 36, 0.040, 0.026, 11, 13 + s,
                            zone=lambda c, n: abs(n.x) < 0.7, sens=lambda p, n, s=s: Vector((s * 1.0, -0.15, 0)), souleve=0.009,
                            double=lambda p, t, s=s: abs(t.x) > 0.66, src=r_))
    parts += revs
    o = X.fusion(parts, "gants_fourrure")
    ctx_g = Ctx(o, coutures=(0,), pas_couture=0.0045, retrait_couture=0.004)

    def mat_g(P, N, pa, bd):
        de, ds, dv, dr, dvr = ctx_g(P)
        v, out = peau(P, N, CUIR, 0.42, 241, 0.3)
        pal_ = (pa == 0) & (N[:, 1] < -0.4)
        out[pal_, :3] *= 1.12
        m = pa == 4
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.52, 243, sens=(1.0, 0.0, 0.0))
        m = pa == 11
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.58, 245, sens=(1.0, 0.0, 0.0), meche=True)
        out = finition_bords(out, de, ds, dv, dr, dvr, pa == 0, rivets=False)
        return out
    finir(o, mat_g, "gants_fourrure", 1200, X.sol_paire_mains, ("cuir", "fourrure"), lambda p: 1 if p in (4, 11) else 0, 600)
    JSON_PIECES.append({"id": "gants_fourrure", "nom": "Moufles de loup", "emplacement": "mains", "matiere": "fourrure", "poids": 1.0})

    # --- bottes_fourrure : bottes de cuir, revers de loup en mèches, lanière croisée à olive d'os
    b = X.bottes_base("bottes_fourrure", 500, 0.008)
    parts = [b]
    for cote in ("l", "r"):
        r_ = X.revers_botte("rf_" + cote, cote, 0.31, 0.44, 0.010, 0.012, 0.008, 12, 4, evase=0.005)
        parts.append(r_)
        parts.append(meches(r_, "mb_" + cote, 40, 0.050, 0.030, 11, 21 + (1 if cote == "l" else 0),
                            zone=lambda c, n: abs(n.y) < 0.7, sens=lambda p, n: Vector((0, -1, 0)), souleve=0.010,
                            double=lambda p, t: t.y < 0.33, src=r_))
        parts.append(X.revers_botte("l1_" + cote, cote, 0.150, 0.172, 0.006, 0.006, 0.005, 12, 2))
    bm = bmesh.new()
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        k = X.os_g("calf_" + cote)
        f_ = X.os_g("foot_" + cote)
        t = (0.161 - f_.y) / (k.y - f_.y)
        c = f_.lerp(k, t)
        cb = L.bvh_de(["bottes"], filtre=lambda p, s=s: (p.x > 0) == (s > 0))
        q = sur_surface(cb, Vector((c.x + s * 0.04, 0.161, c.z + 0.02)), (s, 0, 0.4), 0.014)
        boite(bm, q, (0.010, 0.028, 0.010), 12, (0, 1, 0), (s * 0.4, 0, -1))
    o_os = X.en_objet(bm, "olives")
    X.poids_de(o_os, "bottes", None)
    parts.append(o_os)
    o = X.fusion(parts, "bottes_fourrure")
    ctx_b = Ctx(o, coutures=(0, 2))

    def mat_b(P, N, pa, bd):
        y = P[:, 1]
        de, ds, dv, dr, dvr = ctx_b(P)
        v, out = peau(P, N, CUIR, 0.42, 251, 0.3)
        sem = (pa == 0) & (y < 0.03)
        out[sem, :3] = L.rampe(SOMBRE, np.full(sem.sum(), 0.2))
        boue = (pa == 0) & (y < 0.14)
        out[boue, :3] *= (0.62 + 0.38 * y[boue, None] / 0.14)
        # lanières croisées sur la tige (entre la cheville et le revers)
        xr = P[:, 0] - np.sign(P[:, 0]) * 0.11
        az = np.arctan2(xr, P[:, 2] - 0.02)
        lan = (pa == 0) & (y > 0.18) & (y < 0.31) & (np.abs(np.mod(y * 22.0 + az * 0.9, 1.0) - 0.5) < 0.09)
        lan |= (pa == 0) & (y > 0.18) & (y < 0.31) & (np.abs(np.mod(y * 22.0 - az * 0.9, 1.0) - 0.5) < 0.09)
        _, out[lan] = peau(P[lan], N[lan], SOMBRE, 0.36, 253, 0.3)
        m = pa == 4
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.50, 255)
        m = pa == 11
        out[m] = fourrure_tex(P[m], N[m], bd[m], LOUP, 0.56, 257, meche=True)
        m = pa == 2
        _, out[m] = peau(P[m], N[m], SOMBRE, 0.38, 259, 0.3)
        m = pa == 12
        out[m] = os_tex(P[m], N[m], bd[m], 0.66, 261)
        out = finition_bords(out, de, ds, dv, dr, dvr, (pa == 0) | (pa == 2), rivets=False)
        return out
    finir(o, mat_b, "bottes_fourrure", 1200, X.sol_paire_pieds, ("cuir", "fourrure", "os"), lambda p: 1 if p in (4, 11) else (2 if p == 12 else 0), 600)
    JSON_PIECES.append({"id": "bottes_fourrure", "nom": "Bottes fourrées", "emplacement": "pieds", "matiere": "fourrure", "poids": 2.5})


# ============================================================================================================ CHAUSSES
def chausses():
    o = L.copie("pantalon", "chausses", lambda c, n: c.y < 0.93)
    bvh = L.bvh_de(["pantalon"])
    L.ajuster(o, bvh, lambda p: 0.004, lissage=1, force=0.2)
    L.ecrire_poids(o, L.normaliser(L.poids(o)))
    # cuir : genouillères de cuir bouilli rivetées (découpées dans la chausse)
    gen = []
    for cote in ("l",):
        k = X.os_g("calf_l")
        pl = [plan((0, k.y + 0.075, 0), (0, 1, 0)), plan((0, k.y - 0.055, 0), (0, -1, 0)), plan((0, 0, k.z + 0.0), (0, 0, -1)),
              plan((k.x + 0.06, 0, 0), (1, 0, 0)), plan((k.x - 0.06, 0, 0), (-1, 0, 0))]
        gen += surplaque(o, "genou", pl, 0.005, 0.005, 5, symetrie=True)
    familles = {"cuir": gen, "fourrure": []}
    for fam, extra in familles.items():
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        c.name = "chausses_" + fam
        if extra:
            c = X.fusion([c] + extra, "chausses_" + fam)
        L.lisser_normales(c)
        print("PIECE chausses_%s : %d triangles" % (fam, L.nb_tris(c)))
        L.uv_auto(c, 0.012, 66)
        ctx = Ctx(c, coutures=(0, 5), rivets=(5,), pas_rivet=0.03, retrait_rivet=0.009)
        if fam == "cuir":
            def fn(P, N, pa, bd, ctx=ctx):
                x, y, z = P[:, 0], P[:, 1], P[:, 2]
                de, ds, dv, dr, dvr = ctx(P)
                v, out = peau(P, N, CUIR, 0.40, 301, 0.28)
                # coutures lacées sur le côté de la cuisse, rapiéçage
                lat = (np.abs(np.abs(x) - 0.20) < 0.0018) & (y > 0.45)
                out[lat, :3] *= 0.5
                ph = np.mod(y / 0.022, 1.0)
                cr = (np.abs(np.abs(x) - 0.20) < np.abs(ph - 0.5) * 0.016 + 0.0015) & (np.abs(np.abs(x) - 0.20) > np.abs(ph - 0.5) * 0.016 - 0.0015) & (y > 0.45)
                out[cr, :3] = L.rampe(CUIR, np.full(cr.sum(), 0.8))
                m = pa == 5
                _, out[m] = peau(P[m], N[m], BOUILLI, 0.52, 303, 0.55)
                out = gravure(out, P, N, m, de, 0.007)
                out = finition_bords(out, de, ds, dv, dr, dvr, pa == 5)
                b = y < 0.3
                out[b, :3] *= (0.75 + 0.25 * np.clip(y[b] / 0.3, 0, 1))[:, None]
                return out
        else:
            def fn(P, N, pa, bd, ctx=ctx):
                x, y, z = P[:, 0], P[:, 1], P[:, 2]
                v, out = laine_tex(P, N, 311, L.hexa("#141210", "#1c1915", "#25211c", "#2f2a23", "#3a332b", "#463e34", "#544a3e"), 0.5)
                # bandes molletières en spirale du genou à la cheville, croisillons de lanières
                xr = x - np.sign(x) * 0.11
                az = np.arctan2(xr, z - 0.02)
                bande_ = (y < 0.50) & (y > 0.10)
                ph = np.mod(y / 0.032 + az * 0.16, 1.0)
                vb, ob = laine_tex(P, N, 313, LAINE, 0.55)
                out[bande_] = ob[bande_]
                rec = bande_ & (ph > 0.86)
                out[rec, :3] *= 0.5
                bo = bande_ & (ph > 0.80) & (ph <= 0.86)
                out[bo, :3] *= 1.15
                for sg in (1, -1):
                    l = bande_ & (np.abs(np.mod(y * 9.0 + sg * az * 0.55, 1.0) - 0.5) < 0.045)
                    _, out[l] = peau(P[l], N[l], SOMBRE, 0.38, 315, 0.3)
                b = y < 0.3
                out[b, :3] *= (0.75 + 0.25 * np.clip(y[b] / 0.3, 0, 1))[:, None]
                return out
        img = L.cuire(c, fn, 512, "chausses_" + fam)
        c.data.materials.clear()
        c.data.materials.append(L.materiau("cuir", img))
        L.exporter(c, ARM, fam, None, X.CHAUSSES)
        if APERCU:
            PIECES.append(c)


if FAMILLE in ("chausses", "tout"):
    chausses()
if FAMILLE in ("cuir", "tout"):
    cuir()
    finir_famille("cuir")
if FAMILLE in ("fourrure", "tout"):
    fourrure()
    finir_famille("fourrure")
if JSON_PIECES:
    chemin = os.path.join(ICI, "pieces.json")
    anc = json.load(open(chemin, encoding="utf-8")) if os.path.exists(chemin) else []
    ids = {p["id"] for p in JSON_PIECES}
    tout = [p for p in anc if p["id"] not in ids] + JSON_PIECES
    json.dump(tout, open(chemin, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
if APERCU:
    os.makedirs(APERCU, exist_ok=True)
    corps = [bpy.data.objects[n] for n in ("SuperHero_Male",) if n in bpy.data.objects]
    L.apercu(PIECES + corps, APERCU, (0, 0.95, 0), 2.0, FAMILLE + "_")
    L.apercu(PIECES + corps, APERCU, (0, 1.35, 0), 0.8, FAMILLE + "_haut_")
print("FINI", FAMILLE)
