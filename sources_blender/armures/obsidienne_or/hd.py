# Armures HD (charte CHARTE_ARMURES_HD.md, 2026-11-02) : outils de l'agent « obsidienne + or ».
#  - cuisson HD : la pièce construite par lourdes/pieces.py (agent Y, plaques ajustées) garde ses UV « sémantiques » (atlas 128 de
#    l'agent Y : quelle lame, quelle bande) dans un 2e calque ; elle reçoit des UV uniques (projection intelligente) puis une texture
#    512² CUITE texel par texel : position 3D de repos, normale, matériau, UV sémantiques, distance au bord libre, occlusion ;
#  - bruits numpy 3D (armures_lib de l'agent X), cellules de Voronoï 3D (facettes d'obsidienne, coups de marteau, rivets) ;
#  - éclats (pyramides taillées à 4 pans) pour les crêtes, épaulières et manchettes.
# Repère : la géométrie de l'agent Y est en repère Blender (Z haut, -Y devant) ; les peintres reçoivent des positions GODOT
# (x, y haut, z devant) : P_godot = (x, z, -y).
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

TAU = math.tau


# ------------------------------------------------------------------------------------------------------------ bruits
def _hash(ix, iy, iz, g):
    n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (g * 2654435761)
    n = (n ^ (n >> 13)) * 1274126177
    n = (n ^ (n >> 16)) & 0xffff
    return n / 65535.0


def bruit(p, echelle, g=0):
    """Bruit de valeur 3D lissé, 0..1 ; echelle scalaire ou (3,) (anisotrope : rayures brossées)."""
    q = p * np.asarray(echelle)
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    res = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                h = _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, g)
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                res += h * w
    return res


def fbm(p, echelle, g=0, octaves=3):
    s, a, t = 0.0, 0.5, 0.0
    e = np.asarray(echelle, dtype=float)
    for o in range(octaves):
        s = s + bruit(p, e * (2 ** o), g + o) * a
        t += a
        a *= 0.5
    return s / t


def voronoi(p, cellule, g=0, jitter=0.85):
    """Cellules de Voronoï 3D : (F1, F2 en m, identifiant 0..1 de la cellule, vecteur p - germe le plus proche)."""
    q = p / cellule
    i = np.floor(q).astype(np.int64)
    n = len(p)
    f1 = np.full(n, 9.0); f2 = np.full(n, 9.0)
    cid = np.zeros(n); d1 = np.zeros((n, 3))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                cx, cy, cz = i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz
                jx = _hash(cx, cy, cz, g); jy = _hash(cx, cy, cz, g + 1); jz = _hash(cx, cy, cz, g + 2)
                germe = np.stack([cx + 0.5 + (jx - 0.5) * jitter, cy + 0.5 + (jy - 0.5) * jitter, cz + 0.5 + (jz - 0.5) * jitter], 1)
                d = q - germe
                dist = np.sqrt((d * d).sum(1))
                plus_proche = dist < f1
                f2 = np.where(plus_proche, f1, np.minimum(f2, dist))
                f1 = np.where(plus_proche, dist, f1)
                cid = np.where(plus_proche, _hash(cx, cy, cz, g + 3), cid)
                d1 = np.where(plus_proche[:, None], d, d1)
    return f1 * cellule, f2 * cellule, cid, d1 * cellule


def hexa(*cs):
    return np.array([[int(c[i:i + 2], 16) / 255.0 for i in (1, 3, 5)] for c in cs])


def rampe(pal, k):
    pal = np.asarray(pal)
    t = np.clip(k, 0.0, 0.999) * (len(pal) - 1)
    i = np.floor(t).astype(int)
    f = (t - i)[:, None]
    j = np.minimum(i + 1, len(pal) - 1)
    return pal[i] * (1 - f) + pal[j] * f


def lisse(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------------------------------------------ éclats
def eclat(P, base, dirn, longueur, larg, ep, mat, uvr, cote_w=None, renfle=1.15, ao_base=0.55, enfonce=0.012):
    """Éclat taillé : section en losange (larg x ep) à la base, renflement à 35 %, pointe. Base enfoncée dans la coque.
    cote_w : direction de la largeur (sinon perpendiculaire à dirn et à Z). uvr : (u0, v0, u1, v1) du 2e atlas sémantique."""
    d = Vector(dirn).normalized()
    w = Vector(cote_w) if cote_w is not None else d.cross(Vector((0, 0, 1)))
    if w.length < 1e-4:
        w = d.cross(Vector((1, 0, 0)))
    w = (w - d * w.dot(d)).normalized()
    u = d.cross(w).normalized()
    b0 = Vector(base) - d * enfonce
    def anneau(c, k):
        return [c + w * larg * k, c + u * ep * k, c - w * larg * k, c - u * ep * k]
    a0 = anneau(b0, 1.0)
    a1 = anneau(b0 + d * (longueur * 0.35 + enfonce), renfle)
    pt = b0 + d * (longueur + enfonce)
    u0, v0, u1, v1 = uvr
    i0 = [P.sommet(p, ao_base) for p in a0]
    i1 = [P.sommet(p, 0.95) for p in a1]
    it = P.sommet(pt, 1.0)
    for k in range(4):
        k2 = (k + 1) % 4
        ua = u0 + (u1 - u0) * k / 4; ub = u0 + (u1 - u0) * (k + 1) / 4
        P.face([i0[k], i0[k2], i1[k2], i1[k]], mat, [(ua, v0), (ub, v0), (ub, v0 + (v1 - v0) * 0.4), (ua, v0 + (v1 - v0) * 0.4)])
        P.face([i1[k], i1[k2], it], mat, [(ua, v0 + (v1 - v0) * 0.4), (ub, v0 + (v1 - v0) * 0.4), ((ua + ub) / 2, v1)])


def bvh_piece(P):
    return BVHTree.FromPolygons([Vector(v) for v in P.v], [f[0] for f in P.f], epsilon=0.0)


def poser_sur(arbre, origine, direction, portee=0.5):
    """Point de la surface touché en tirant de origine vers direction (None si rien)."""
    hit = arbre.ray_cast(Vector(origine), Vector(direction).normalized(), portee)
    return hit[0], hit[1]


# ------------------------------------------------------------------------------------------------------------ UV et cuisson
def uv_uniques(ob, angle=62, marge=0.006):
    """Le calque UV de l'agent Y devient « UVsem » ; un nouveau calque « UVMap » (actif, exporté) reçoit une projection intelligente."""
    me = ob.data
    sem = me.uv_layers[0]
    sem.name = "UVsem"
    nv = me.uv_layers.new(name="UVMap")
    me.uv_layers.active = nv
    nv.active_render = True
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=marge, area_weight=0.0, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(margin=marge, rotate=True, shape_method="CONCAVE")
    except TypeError:
        bpy.ops.uv.pack_islands(margin=marge, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def retirer_uv_sem(ob):
    me = ob.data
    if "UVsem" in me.uv_layers:
        me.uv_layers.remove(me.uv_layers["UVsem"])
    me.uv_layers.active = me.uv_layers["UVMap"]
    me.uv_layers["UVMap"].active_render = True


def occlusion(me, rayons=24, portee=0.06):
    """Occlusion par sommet contre la pièce elle-même (sous les lames, entre les plaques)."""
    import random
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons], epsilon=0.0)
    rnd = random.Random(7)
    dirs = []
    while len(dirs) < rayons:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.1 < d.length <= 1.0:
            dirs.append(d.normalized())
    res = []
    for v in me.vertices:
        n = v.normal
        libres = tot = 0
        for d in dirs:
            if d.dot(n) < 0:
                d = -d
            if d.dot(n) < 0.15:
                continue
            tot += 1
            if bvh.ray_cast(v.co + n * 0.0015, d, portee)[0] is None:
                libres += 1
        res.append(libres / max(tot, 1))
    return np.array(res)


def _godot(v):
    return (v[0], v[2], -v[1])


def cuire(ob, taille, peintre, debord=10):
    """Texture (H, W, 4) cuite : peintre(D) -> RGBA (N, 4), D = {P, N (godot), mat (noms), uv (sémantiques), bord (m), ao}."""
    me = ob.data
    me.calc_loop_triangles()
    W = H = taille
    uvb = me.uv_layers["UVMap"].data
    uvs = me.uv_layers["UVsem"].data
    ao_v = occlusion(me)
    P = np.zeros((H, W, 3)); Nn = np.zeros((H, W, 3)); S = np.zeros((H, W, 2)); A = np.ones((H, W))
    M = np.full((H, W), -1, dtype=np.int64)
    rempli = np.zeros((H, W), dtype=bool)
    for t in me.loop_triangles:
        uv = np.array([uvb[l].uv[:] for l in t.loops]) * [W, H]
        su = np.array([uvs[l].uv[:] for l in t.loops])
        ps = np.array([_godot(me.vertices[v].co) for v in t.vertices])
        ns = np.array([_godot(me.vertices[v].normal) for v in t.vertices])
        aos = ao_v[list(t.vertices)]
        x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0 = max(x0 - 1, 0), max(y0 - 1, 0); x1, y1 = min(x1 + 1, W), min(y1 + 1, H)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l3 = 1 - l1 - l2
        dedans = (l1 >= -0.03) & (l2 >= -0.03) & (l3 >= -0.03)
        if not dedans.any():
            continue
        yy, xx = (ys[dedans] - 0.5).astype(int), (xs[dedans] - 0.5).astype(int)
        L = np.stack([l1[dedans], l2[dedans], l3[dedans]], 1).clip(0, 1)
        L /= L.sum(1, keepdims=True)
        P[yy, xx] = L @ ps; Nn[yy, xx] = L @ ns; S[yy, xx] = L @ su; A[yy, xx] = L @ aos
        M[yy, xx] = t.material_index
        rempli[yy, xx] = True
    vrai = rempli.copy()
    for _ in range(debord):
        vide = ~rempli
        if not vide.any():
            break
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(rempli, dy, 0), dx, 1)
            m = vide & src
            for T in (P, Nn, S):
                T[m] = np.roll(np.roll(T, dy, 0), dx, 1)[m]
            A[m] = np.roll(np.roll(A, dy, 0), dx, 1)[m]
            M[m] = np.roll(np.roll(M, dy, 0), dx, 1)[m]
            rempli = rempli | m
            vide = ~rempli
    flat = rempli.reshape(-1)
    Pf = P.reshape(-1, 3)[flat]
    # distance au bord libre par texel (arêtes de bord échantillonnées tous les 3 mm)
    nb = {}
    for p_ in me.polygons:
        for k in p_.edge_keys:
            nb[k] = nb.get(k, 0) + 1
    ech = []
    for (a_, b_), c_ in nb.items():
        if c_ != 1:
            continue
        pa_, pb_ = Vector(_godot(me.vertices[a_].co)), Vector(_godot(me.vertices[b_].co))
        n_ = max(1, int((pb_ - pa_).length / 0.003))
        for i_ in range(n_ + 1):
            ech.append(pa_.lerp(pb_, i_ / n_))
    bord = np.full(len(Pf), 0.08)
    if ech:
        kd = KDTree(len(ech))
        for i_, q_ in enumerate(ech):
            kd.insert(q_, i_)
        kd.balance()
        bord = np.array([min(kd.find(q)[2], 0.08) for q in Pf])
    nn = Nn.reshape(-1, 3)[flat]
    nn = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
    noms = np.array([m.name.split(".0")[0] if m else "" for m in me.materials] + [""])
    mi = M.reshape(-1)[flat]
    D = {"P": Pf, "N": nn, "mat": noms[mi], "uv": S.reshape(-1, 2)[flat], "bord": bord, "ao": np.clip(A.reshape(-1)[flat], 0, 1)}
    rgba = np.zeros((H * W, 4)); rgba[:, 3] = 1.0
    rgba[flat] = peintre(D)
    return rgba.reshape(H, W, 4), vrai


def image(nom, tab, dossier=None):
    H, W = tab.shape[:2]
    img = bpy.data.images.new(nom, W, H, alpha=True)
    img.pixels.foreach_set(np.clip(tab, 0, 1).astype(np.float32).reshape(-1))
    if dossier:
        os.makedirs(dossier, exist_ok=True)
        img.filepath_raw = os.path.join(dossier, nom + ".png")
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def poser_image(ob, img):
    """Remplace l'image de chaque matériau de la pièce (atlas unique) ; échantillonnage net (le jeu filtre lui-même)."""
    for m in ob.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = img
                n.interpolation = "Closest"


def couleur_blanche(ob):
    """Occlusion cuite dans la texture : couleur de sommet ramenée au blanc (alpha 1 = pas de neige)."""
    me = ob.data
    for ca in me.color_attributes:
        for d in ca.data:
            d.color = (1.0, 1.0, 1.0, 1.0)


# ------------------------------------------------------------------------------------------------------------ plaques
def lancer(arbres, origine, direction, portee=0.8):
    """Premier impact (le plus proche de l'origine) parmi plusieurs BVH : (point, normale) ou (None, None)."""
    best = None
    for a in arbres:
        h = a.ray_cast(Vector(origine), Vector(direction).normalized(), portee)
        if h[0] is not None and (best is None or h[3] < best[3]):
            best = h
    return (best[0], best[1]) if best else (None, None)


def proj_torse(cx=0.0, cy=0.0, r=0.7):
    """(angle° autour du torse, 0 = devant, + vers la gauche du perso ; z) -> (origine, direction) d'un rayon vers l'axe."""
    def f(a, z):
        ar = math.radians(a)
        d = Vector((math.sin(ar), -math.cos(ar), 0.0))
        c = Vector((cx, cy, z))
        return c + d * r, -d
    return f


def proj_axe(A, B, haut=Vector((0, 0, 1)), r=0.4):
    """Cylindre autour du segment A->B : (angle°, 0 = côté `haut`, + vers l'arrière (+y) ; t 0..1 le long de A->B)."""
    A, B = Vector(A), Vector(B)
    ax = (B - A).normalized()
    u = (haut - ax * haut.dot(ax)).normalized()
    w = ax.cross(u).normalized()
    if w.y < 0:
        w = -w
    def f(a, t):
        ar = math.radians(a)
        d = u * math.cos(ar) + w * math.sin(ar)
        c = A.lerp(B, t)
        return c + d * r, -d
    return f


def plaque(P, arbres, proj, contour, decal, ep, mat, uvr=(0.0, 0.0, 1.0, 1.0), bombe=0.0, anneaux=3, centre=None, biseau=0.8,
           ao_bord=0.8, rentre=None):
    """Plaque d'épaisseur réelle posée sur une surface : contour (liste fermée de (s, t), étoilé autour de `centre`) projeté par
    proj(s, t) -> (origine, direction) sur le premier impact des `arbres`, décollée de `decal` (+ bombé au centre) ; tranche biseautée
    (vers l'extérieur et vers le corps, épaisseur ep) : jamais de plaque en papier, les bords accrochent la lumière.
    Retourne (anneau extérieur 3D, centre 3D)."""
    n = len(contour)
    if centre is None:
        centre = (sum(c[0] for c in contour) / n, sum(c[1] for c in contour) / n)
    s0, t0 = centre
    smin = min(c[0] for c in contour); smax = max(c[0] for c in contour)
    tmin = min(c[1] for c in contour); tmax = max(c[1] for c in contour)
    u0, v0, u1, v1 = uvr
    def uv(s, t):
        return (u0 + (u1 - u0) * (s - smin) / max(1e-6, smax - smin), v0 + (v1 - v0) * (t - tmin) / max(1e-6, tmax - tmin))
    dernier = [None]
    def pos(s, t, k):
        o, d = proj(s, t)
        hit, nrm = lancer(arbres, o, d)
        if hit is None:
            hit = dernier[0] if dernier[0] is not None else o + d * 0.5
        dernier[0] = hit
        dehors = -Vector(d)
        return hit + dehors * (decal + bombe * (1.0 - k * k)), dehors
    pc, dc = pos(s0, t0, 0.0)
    ic = P.sommet(pc, 1.0)
    anneaux_ids, anneaux_pts, anneaux_st = [], [], []
    for k in range(1, anneaux + 1):
        f = k / anneaux
        pts, ids, sts = [], [], []
        for (s, t) in contour:
            ss, tt = s0 + (s - s0) * f, t0 + (t - t0) * f
            p, d = pos(ss, tt, f)
            pts.append((p, d)); sts.append((ss, tt))
            ids.append(P.sommet(p, 1.0 if k < anneaux else ao_bord))
        anneaux_ids.append(ids); anneaux_pts.append(pts); anneaux_st.append(sts)
    for i in range(n):
        i2 = (i + 1) % n
        a, b = anneaux_ids[0][i], anneaux_ids[0][i2]
        P.face([ic, a, b], mat, [uv(s0, t0), uv(*anneaux_st[0][i]), uv(*anneaux_st[0][i2])])
    for k in range(anneaux - 1):
        for i in range(n):
            i2 = (i + 1) % n
            q = [anneaux_ids[k][i], anneaux_ids[k + 1][i], anneaux_ids[k + 1][i2], anneaux_ids[k][i2]]
            P.face(q, mat, [uv(*anneaux_st[k][i]), uv(*anneaux_st[k + 1][i]), uv(*anneaux_st[k + 1][i2]), uv(*anneaux_st[k][i2])])
    # tranche : de l'anneau extérieur vers le corps (ep), évasée vers l'extérieur du contour (biseau)
    ext = anneaux_pts[-1]
    rentre = ep if rentre is None else rentre
    tranche = []
    for i, (p, d) in enumerate(ext):
        tg = p - pc
        tg = tg - d * tg.dot(d)
        tg = tg.normalized() if tg.length > 1e-6 else Vector((0, 0, 0))
        tranche.append(P.sommet(p - d * rentre + tg * ep * biseau, ao_bord * 0.8))
    for i in range(n):
        i2 = (i + 1) % n
        q = [anneaux_ids[-1][i], tranche[i], tranche[i2], anneaux_ids[-1][i2]]
        P.face(q, mat, [uv(*anneaux_st[-1][i]), uv(*anneaux_st[-1][i]), uv(*anneaux_st[-1][i2]), uv(*anneaux_st[-1][i2])])
    return [p for p, d in ext], pc


def dentele(points, dents, amp, axe=1, signe=-1, depuis=0, jusqua=None, graine=0):
    """Ajoute des dents en scie entre deux sommets d'un contour (s, t) : `dents` pointes de hauteur amp (irrégulières), le long du
    segment points[depuis] -> points[jusqua] (indices dans la liste), direction de la pointe sur la coordonnée `axe`."""
    jusqua = len(points) - 1 if jusqua is None else jusqua
    a, b = points[depuis], points[jusqua]
    out = []
    for k in range(1, 2 * dents):
        f = k / (2 * dents)
        s = a[0] + (b[0] - a[0]) * f
        t = a[1] + (b[1] - a[1]) * f
        if k % 2 == 1:
            h = amp * (0.7 + 0.6 * _hash(k, graine, 3, 7))
            if axe == 1:
                t += signe * h
            else:
                s += signe * h
        out.append((s, t))
    return points[:depuis + 1] + out + points[jusqua:]
