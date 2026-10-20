# Lot 4 : pieces de silhouette ajoutees aux deux corps (exec depuis personnages.py : partage arm, obj, TAILLE, PX_M, bpy, bmesh, math).
# Chaque piece est un maillage HABILLE (poids copies du corps, ou poids de « jupe » pour ce qui pend sous la taille), ajuste sur les
# vetements existants par lancer de rayons depuis l'axe du corps : elle suit donc les deux morphologies. Les UV sont metriques et
# reprennent la convention du vetement dont la piece emprunte la texture (bas de l'image = ourlet).
#   surcotte (tabard long), robe (jupe longue), cape (dos), tablier (forgeron), capuche (cagoule), epaulieres (plates),
#   haillons (lambeaux dechires), pteruges (lanieres de cuir), sacoche (bourse + gourde), carquois (dos).
import random
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TYPE_TEX = {"surcotte": "tunique", "robe": "tunique", "cape": "tunique", "cape_courte": "tunique", "tablier": "tunique", "capuche": "tunique", "haillons": "tunique",
            "pteruges": "tunique", "manchettes": "mante", "epaulieres": "brassards", "sacoche": "bottes", "carquois": "bottes"}
TAILLE_ACC = dict(TAILLE)

os_ = arm.data.bones
def pos(b, tail=False):
    return Vector(os_[b].tail_local if tail else os_[b].head_local)
ZSH = pos("spine_03", True).z            # epaules
ZN = pos("neck_01").z                    # base du cou
ZTETE = pos("Head", True).z
ZB = sum(v.co.z for v in obj["ceinture"].data.vertices) / len(obj["ceinture"].data.vertices)   # ceinture
YC0 = 0.03
corps_obj = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.lower().startswith("superhero"))
rng = random.Random(4242)
ZMAX = max(v.co.z for v in corps_obj.data.vertices)
HC = Vector((0.0, pos("Head").y, pos("Head").z + (ZMAX - pos("Head").z) * 0.5))
RZ_TETE = (ZMAX - pos("Head").z) * 0.5 + 0.012

def bvh_de(objs):
    verts, polys = [], []
    for o in objs:
        off = len(verts)
        verts += [v.co.copy() for v in o.data.vertices]
        polys += [tuple(off + i for i in p.vertices) for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)

BVH_CORPS = bvh_de([corps_obj])
BVH_HAB = bvh_de([obj[n] for n in ("tunique", "pantalon", "ceinture", "bottes") if n in obj])

def r_ajuste(bvh, z, th, defaut=0.15, yc=YC0, loin=0.9):
    """Rayon de la surface a la hauteur z, vers l'angle th (0 = devant, -y), mesure depuis l'axe (0, yc)."""
    d = Vector((math.sin(th), -math.cos(th), 0.0))
    h = bvh.ray_cast(Vector((0, yc, z)), d, loin)
    return h[3] if h[0] is not None else defaut

# ------------------------------------------------------------------ poids
GROUPES = [b.name for b in arm.data.bones]
def poids_corps(p):
    loc, n, idx, d = BVH_CORPS.find_nearest(p)
    me = corps_obj.data
    poly = me.polygons[idx]
    vs = [me.vertices[i] for i in poly.vertices]
    w = {}
    tot = 0.0
    for v in vs:
        k = 1.0 / max((v.co - p).length, 1e-4) ** 2
        for g in v.groups:
            w[corps_obj.vertex_groups[g.group].name] = w.get(corps_obj.vertex_groups[g.group].name, 0.0) + g.weight * k
            tot += g.weight * k
    return {k: v / tot for k, v in w.items()}

def poids_jupe(p):
    """Au-dessus de la taille : poids du corps ; en dessous : le bassin, et la cuisse du cote de p en proportion de la descente."""
    if p.z >= ZB + 0.02:
        return poids_corps(p)
    base = poids_corps(Vector((p.x * 0.5, p.y, ZB + 0.02)))
    s = max(0.0, min(1.0, (ZB - p.z) / 0.65)) * 0.85
    tl = 0.5 + 0.5 * max(-1.0, min(1.0, p.x / 0.13))        # fondu gauche / droite : le devant ne se fend pas
    genou = max(0.0, min(1.0, (0.58 - p.z) / 0.30))
    mollet = s * genou * 0.55
    cuisse = s - mollet
    w = {k: v * (1 - s) for k, v in base.items()}
    for nom, part in (("thigh_l", cuisse * tl), ("thigh_r", cuisse * (1 - tl)), ("calf_l", mollet * tl), ("calf_r", mollet * (1 - tl))):
        w[nom] = w.get(nom, 0.0) + part
    return w

# ------------------------------------------------------------------ construction
def mesh_de(nom, verts, faces, uvs, mode="corps"):
    me = bpy.data.meshes.new(nom)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = uvs[me.loops[li].vertex_index]
    o = bpy.data.objects.new(nom, me)
    bpy.context.collection.objects.link(o)
    for g in GROUPES:
        o.vertex_groups.new(name=g)
    fn = poids_jupe if mode == "jupe" else poids_corps
    for i, v in enumerate(verts):
        for g, w in fn(Vector(v)).items():
            if w > 0.02:
                o.vertex_groups[g].add([i], w, 'REPLACE')
    o.parent = arm
    md = o.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    mat = bpy.data.materials.new(nom)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    obj[nom] = o
    print("ACC", nom, len(verts), "sommets", len(faces), "faces")
    return o

def uvm(nom, u_m, v_m):
    W, H = TAILLE_ACC[TYPE_TEX[nom]]
    return (u_m * PX_M / W, v_m * PX_M / H)

def grille(nom, cols, rows, f, mode="corps", fermee=False):
    """f(i, j) -> (position, u_m, v_m) pour la colonne i (0..cols) et la rangee j (0..rows, 0 = haut). Retourne l'objet."""
    verts, uvs = [], []
    for j in range(rows + 1):
        for i in range(cols + 1):
            p, u, v = f(i, j)
            verts.append(p)
            uvs.append(uvm(nom, u, v))
    faces = []
    for j in range(rows):
        for i in range(cols):
            a = j * (cols + 1) + i
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    return mesh_de(nom, verts, faces, uvs, mode)

def pt(r, th, z, yc=YC0):
    return Vector((r * math.sin(th), yc - r * math.cos(th), z))

# ------------------------------------------------------------------ pieces en tube / panneaux
def tube(nom, z_haut, z_bas, th0, th1, cols, rows, dr, evase=0.0, plis=0.0, dents=0.0, bvh=None, plancher=0.13, mode="jupe", rmin_bas=None, fit_haut=True):
    """Tube (ou panneau) autour de l'axe : rayon = vetement ajuste + dr, qui s'evase vers le bas ; ourlet en dents irregulieres."""
    bvh = bvh or BVH_HAB
    bas_col = [z_bas + (rng.random() - 0.3) * dents for _ in range(cols + 1)]
    def f(i, j):
        t = i / cols
        th = th0 + (th1 - th0) * t
        zb = bas_col[i]
        k = j / rows
        z = z_haut + (zb - z_haut) * k
        # rayon du vetement a cette hauteur (sous l'ourlet de la tunique : on prolonge en evasant)
        zr = max(z, ZB - 0.28)
        r0 = max(r_ajuste(bvh, zr, th, plancher), plancher)
        r = r0 + dr + evase * max(0.0, (ZB - 0.28) - z) + evase * 0.35 * max(0.0, ZB - z)
        if rmin_bas:
            r = max(r, rmin_bas * k + (r0 + dr) * (1 - k))
        r += plis * math.sin(th * 9.0 + k * 1.5) * k
        return pt(r, th, z), th * r, z - zb
    return grille(nom, cols, rows, f, mode)

def faire_surcotte():
    # tabard : tube ferme au-dessus de la ceinture, deux panneaux (devant, dos) en dessous, flancs ouverts ; descend aux mollets
    zh = ZSH - 0.07
    bas = 0.34
    # haut : anneau complet de zh a ZB, bas : deux panneaux ; on construit un seul maillage pour la lisibilite des poids
    verts, uvs, faces = [], [], []
    def ajouter(f, cols, rows, mode_jupe):
        base = len(verts)
        for j in range(rows + 1):
            for i in range(cols + 1):
                p, u, v = f(i, j)
                verts.append(p); uvs.append(uvm("surcotte", u, v))
        for j in range(rows):
            for i in range(cols):
                a = base + j * (cols + 1) + i
                faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    dr = 0.022
    haut = lambda i, j: None
    def anneau(i, j):
        th = -math.pi + 2 * math.pi * i / 28
        z = zh + (ZB - zh) * j / 4
        r = max(r_ajuste(BVH_HAB, z, th, 0.15), 0.12) + dr
        return pt(r, th, z), th * r, 0.36 + (z - ZB) * 0.9
    ajouter(anneau, 28, 4, False)
    for (a0, a1) in ((-1.42, 1.42), (math.pi - 1.42, math.pi + 1.42)):
        zbs = [bas + (rng.random() - 0.3) * 0.05 for _ in range(9)]
        def pan(i, j, a0=a0, a1=a1, zbs=zbs):
            t = i / 8
            th = a0 + (a1 - a0) * t
            k = j / 7
            z = ZB + (zbs[i] - ZB) * k
            r0 = max(r_ajuste(BVH_HAB, max(z, ZB - 0.28), th, 0.13), 0.13)
            r = r0 + dr + 0.18 * max(0.0, ZB - 0.28 - z) + 0.05 * k
            r += 0.012 * math.sin(th * 7.0) * k
            return pt(r, th, z), th * r, z - zbs[i]
        ajouter(pan, 8, 7, True)
    # poids : jupe partout (au-dessus de la taille elle reprend les poids du corps)
    mesh_de("surcotte", verts, faces, uvs, "jupe")

def faire_robe():
    bas = 0.10
    zbs = [bas + rng.random() * 0.03 for _ in range(33)]
    def f(i, j):
        th = -math.pi + 2 * math.pi * i / 32
        k = j / 9
        z = (ZB + 0.02) + (zbs[i] - (ZB + 0.02)) * k
        zr = max(z, 0.68)
        r0 = max(r_ajuste(BVH_HAB, zr, th, 0.15), 0.17 if z > 0.6 else 0.13)
        r = r0 + 0.014 + 0.16 * max(0.0, 0.68 - z) / 0.68 * (1.0) + 0.04 * k
        r += 0.014 * math.sin(th * 6.0 + k) * k
        return pt(r, th, z), th * r, z - zbs[i]
    grille("robe", 32, 9, f, "jupe")

def faire_cape(longueur_bas, large=1.9, nom="cape"):
    cols, rows = 14, 9
    zbs = [longueur_bas + (rng.random() - 0.4) * 0.05 for _ in range(cols + 1)]
    th0, th1 = math.pi - large / 2, math.pi + large / 2
    def f(i, j):
        t = i / cols
        th = th0 + (th1 - th0) * t
        k = j / rows
        z = (ZSH + 0.03) + (zbs[i] - (ZSH + 0.03)) * k
        zr = max(z, ZB - 0.2)
        r0 = max(r_ajuste(BVH_HAB, zr, th, 0.14), 0.14)
        # au niveau des epaules le rayon vient du corps entier (bras compris) : on borne
        r0 = min(r0, 0.30)
        r = r0 + 0.03 + 0.10 * k + 0.012 * max(0.0, ZB - z) * 3.0
        r += 0.02 * math.sin(th * 11.0 + k * 2.0) * k
        return pt(r, th, z), th * r, (z - zbs[i]) * min(1.0, 0.9 / (ZSH + 0.03 - zbs[i]))
    grille(nom, cols, rows, f, "jupe")

def faire_tablier():
    cols, rows = 8, 8
    zh = ZSH - 0.10
    bas = ZB - 0.52
    def f(i, j):
        k = j / rows
        z = zh + (bas - zh) * k
        demi = (0.50 + 0.30 * min(1.0, k * 2.2))   # buste etroit puis jupe du tablier
        th = -demi + 2 * demi * i / cols
        r0 = max(r_ajuste(BVH_HAB, max(z, ZB - 0.28), th, 0.13), 0.13)
        r = r0 + 0.03 + 0.015 * k + 0.05 * max(0.0, ZB - 0.28 - z) * 2
        return pt(r, th, z), th * r, z - bas
    grille("tablier", cols, rows, f, "jupe")

def faire_capuche(rabattue=False):
    nrow, ncol = 16, 32
    rx, ry, rz = 0.100, 0.112, RZ_TETE
    avant = Vector((0, -1, 0.15)).normalized()
    verts, uvs, faces = [], [], []
    idx = {}
    for j in range(nrow + 1):
        al = math.radians(152.0) * j / nrow            # 0 = sommet du crane
        for i in range(ncol + 1):
            ph = 2 * math.pi * i / ncol
            d = Vector((math.sin(al) * math.sin(ph), -math.sin(al) * math.cos(ph), math.cos(al)))
            ev = 1.12 + 1.15 * max(0.0, (al - math.radians(92.0)) / math.radians(60.0)) ** 1.6   # le bas forme un col qui couvre les epaules
            p = HC + Vector((d.x * rx * ev, d.y * ry * ev, d.z * rz)) + d * 0.034
            if al > math.radians(92.0):
                p.z -= 0.05 * ((al - math.radians(92.0)) / math.radians(60.0))
            if d.y > 0.2:
                p.y += 0.085 * ((d.y - 0.2) / 0.8) ** 2 * (1.0 - j / nrow * 0.5)     # pointe du capuchon vers l'arriere
                p.z -= 0.02 * ((d.y - 0.2) / 0.8) ** 2 * (j / nrow)
            idx[(i, j)] = len(verts)
            verts.append(p)
            u = ph * 0.15
            v = 0.24 + (math.radians(152.0) - al) * 0.10
            uvs.append(uvm("capuche", u, v))
    fermer = 0.0 if not rabattue else 0.0
    cone = math.radians(46.0)
    for j in range(nrow):
        for i in range(ncol):
            a, b, c, d2 = idx[(i, j)], idx[(i + 1, j)], idx[(i + 1, j + 1)], idx[(i, j + 1)]
            ctr = (verts[a] + verts[b] + verts[c] + verts[d2]) / 4 - HC
            az = math.atan2(ctr.x, -ctr.y)                 # 0 = devant
            ez = (ctr.z + 0.034) / (0.52 * RZ_TETE)
            if ctr.y < 0 and (az / 0.80) ** 2 + ez ** 2 < 1.0:
                continue                                 # ouverture du visage (ovale : du menton au front)
            faces.append((a, b, c, d2))
    mesh_de("capuche", verts, faces, uvs, "corps")

def faire_epaulieres(nplaques=3, rayon0=0.082):
    verts, uvs, faces = [], [], []
    ya, za = 0.065, pos("upperarm_l").z
    for s in (1, -1):
        for k in range(nplaques):
            x0 = 0.17 + 0.075 * k
            x1 = x0 + 0.115
            rr = rayon0 + 0.010 * k
            nc = 8
            base = len(verts)
            for a in range(nc + 1):
                th = -math.radians(105) + math.radians(210) * a / nc
                for b in range(3):
                    x = x0 + (x1 - x0) * b / 2
                    r = rr * (1.0 + 0.06 * (b - 1))
                    y = ya + r * math.sin(th) * 1.0
                    z = za + r * math.cos(th) - 0.004 * k - 0.02 * (1 - abs(math.cos(th)))
                    verts.append(Vector((s * x, y, z + 0.008)))
                    uvs.append(uvm("epaulieres", th * r, (x1 - x) + 0.3))
            for a in range(nc):
                for b in range(2):
                    q = base + a * 3 + b
                    f = (q, q + 1, q + 4, q + 3)
                    faces.append(f if s > 0 else f[::-1])
    mesh_de("epaulieres", verts, faces, uvs, "corps")

def faire_haillons(n=9, zmin=0.52, longueur=(0.18, 0.40), large=(0.07, 0.11), bras=True, nom="haillons", z0=None):
    """Lambeaux : bandes effilees (pointe en bas) tombant de la ceinture, plus quelques-uns aux avant-bras."""
    verts, uvs, faces = [], [], []
    def bande(p0, d, axe_bas, L, w, flare):
        # p0 : point d'attache ; axe_bas : direction de chute ; d : direction laterale ; L : longueur ; w : largeur
        base = len(verts)
        n_r = 4
        for k in range(n_r + 1):
            t = k / n_r
            c = p0 + axe_bas * (L * t) + flare * (L * t) * (L * t)
            ww = w * (1.0 - 0.55 * t) * (1.0 if k < n_r else 0.0)
            for sgn in (-1, 1):
                verts.append(c + d * (ww * sgn * 0.5) + Vector((0, 0, 0)))
                uvs.append(uvm("haillons", sgn * ww * 0.5, (1.0 - t) * L))
        for k in range(n_r):
            q = base + k * 2
            faces.append((q, q + 1, q + 3, q + 2))
    z0 = ZB - 0.02 if z0 is None else z0
    for i in range(n):
        th = -math.pi + 2 * math.pi * (i + rng.random() * 0.6) / n
        r = max(r_ajuste(BVH_HAB, z0 - 0.05, th, 0.15), 0.13) + 0.028
        p0 = pt(r, th, z0)
        L = rng.uniform(*longueur)
        L = min(L, z0 - zmin + 0.10)
        d = Vector((math.cos(th), math.sin(th), 0.0))
        out = Vector((math.sin(th), -math.cos(th), 0.0))
        bande(p0, d, Vector((0, 0, -1)), L, rng.uniform(*large), out * 0.25)
    if bras:
        for s in (1, -1):
            for k in range(3):
                x = s * (0.30 + 0.12 * k + rng.random() * 0.03)
                th = math.pi * 0.5 * (0.2 + k * 0.4)
                ay, az = 0.065, pos("upperarm_l").z
                p0 = Vector((x, ay + 0.062 * math.sin(th * 1.0 + 1.2), az - 0.04))
                bande(p0, Vector((s, 0, 0)), Vector((0, 0.15, -1)).normalized(), rng.uniform(0.12, 0.26), 0.07, Vector((0, 0.1, 0)))
    mesh_de(nom, verts, faces, uvs, "corps" if False else "jupe")

def faire_pteruges(n=16, longueur=0.20, large=0.075):
    """Lanieres de cuir en jupe courte, deux rangs decales, sous la ceinture."""
    verts, uvs, faces = [], [], []
    for rang in range(2):
        for i in range(n):
            th = -math.pi + 2 * math.pi * (i + 0.5 * rang) / n
            z0 = ZB - 0.03 - 0.06 * rang
            r = max(r_ajuste(BVH_HAB, z0 - 0.05, th, 0.15), 0.13) + 0.03 + 0.012 * rang
            L = longueur * (0.9 + 0.2 * rng.random()) * (1.0 - 0.12 * rang)
            out = Vector((math.sin(th), -math.cos(th), 0.0))
            d = Vector((math.cos(th), math.sin(th), 0.0))
            p0 = pt(r, th, z0)
            base = len(verts)
            nr = 3
            for k in range(nr + 1):
                t = k / nr
                c = p0 + Vector((0, 0, -L * t)) + out * (0.07 * t * t * L * 4)
                w = large * (1.0 if k < nr else 0.78)
                for sgn in (-1, 1):
                    verts.append(c + d * (w * 0.5 * sgn))
                    uvs.append(uvm("pteruges", sgn * w * 0.5, (1.0 - t) * L + 0.24))
            for k in range(nr):
                q = base + k * 2
                faces.append((q, q + 1, q + 3, q + 2))
    mesh_de("pteruges", verts, faces, uvs, "jupe")

def boite(verts, uvs, faces, c, e, nom, rot=0.0):
    """Boite de demi-dimensions e centree en c (tournee de rot autour de z), UV planaires metriques."""
    sommets = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    base = len(verts)
    cr, sr = math.cos(rot), math.sin(rot)
    for sx, sy, sz in sommets:
        x, y = sx * e[0], sy * e[1]
        verts.append(Vector((c.x + x * cr - y * sr, c.y + x * sr + y * cr, c.z + sz * e[2])))
        uvs.append(uvm(nom, sx * e[0] + sy * e[1] * 0.5 + 0.2, sz * e[2] + 0.2))
    for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        faces.append(tuple(base + i for i in q))

def faire_sacoche():
    verts, uvs, faces = [], [], []
    th = math.radians(-78)
    r = max(r_ajuste(BVH_HAB, ZB - 0.1, th, 0.18), 0.15)
    c = pt(r + 0.045, th, ZB - 0.12)
    boite(verts, uvs, faces, c, (0.028, 0.055, 0.065), "sacoche", -th * 0.0)
    th2 = math.radians(95)
    r2 = max(r_ajuste(BVH_HAB, ZB - 0.1, th2, 0.18), 0.15)
    c2 = pt(r2 + 0.035, th2, ZB - 0.10)
    boite(verts, uvs, faces, c2, (0.025, 0.035, 0.085), "sacoche")      # gourde / etui de couteau
    # rabat de la bourse
    boite(verts, uvs, faces, c + Vector((0.0, 0.0, 0.052)), (0.03, 0.058, 0.014), "sacoche")
    mesh_de("sacoche", verts, faces, uvs, "corps")

def faire_carquois():
    verts, uvs, faces = [], [], []
    axe0 = Vector((-0.13, YC0 + 0.17, ZSH - 0.03))
    axe1 = Vector((0.08, YC0 + 0.24, ZSH - 0.55))
    d = (axe1 - axe0).normalized()
    u = d.cross(Vector((1, 0, 0))).normalized()
    w = d.cross(u).normalized()
    nc = 8
    for t, r in ((0.0, 0.052), (0.5, 0.050), (1.0, 0.040)):
        c = axe0 + (axe1 - axe0) * t
        for a in range(nc + 1):
            th = 2 * math.pi * a / nc
            verts.append(c + (u * math.cos(th) + w * math.sin(th)) * r)
            uvs.append(uvm("carquois", th * r, 0.55 * (1 - t)))
    for j in range(2):
        for a in range(nc):
            q = j * (nc + 1) + a
            faces.append((q, q + 1, q + nc + 2, q + nc + 1))
    # bande de transport en travers du torse (sangle) : ruban epais du carquois a la hanche opposee
    # fleches : trois tiges depassant de l'ouverture
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        base = axe0 - d * 0.0 + (u * math.cos(a) + w * math.sin(a)) * 0.022
        base2 = base - d * 0.14 + Vector((0.0, 0.0, 0.0))
        b = len(verts)
        for c, rr in ((base, 0.007), (base - d * 0.17, 0.005)):
            for s2 in range(3):
                th = 2 * math.pi * s2 / 3
                verts.append(c + (u * math.cos(th) + w * math.sin(th)) * rr)
                uvs.append(uvm("carquois", s2 * 0.01, 0.1))
        for s2 in range(3):
            faces.append((b + s2, b + (s2 + 1) % 3, b + 3 + (s2 + 1) % 3, b + 3 + s2))
    mesh_de("carquois", verts, faces, uvs, "corps")

def faire_manchettes():
    """Manchettes de fourrure au poignet (comme celles des bras de la vue a la premiere personne, lot 6)."""
    verts, uvs, faces = [], [], []
    bl = pos("lowerarm_l"); bt = pos("lowerarm_l", True)
    for sg in (1, -1):
        base = len(verts)
        nc, nr = 14, 3
        x0, x1 = bt.x - 0.115, bt.x - 0.012
        for j in range(nr + 1):
            t = j / nr
            x = x0 + (x1 - x0) * t
            for i in range(nc + 1):
                th = 2 * math.pi * i / nc
                hirsute = 1.0 + 0.30 * (1.0 if i % 2 else 0.0) * (0.4 + 0.6 * (1 - abs(t - 0.5) * 2)) + 0.12 * math.sin(i * 2.7)
                r = 0.050 * (1.0 + 0.5 * math.sin(math.pi * t) * 0.6) * hirsute + 0.010
                verts.append(Vector((sg * x, bl.y + r * math.sin(th), bl.z + r * math.cos(th))))
                uvs.append(uvm("manchettes", th * 0.05, 0.22 * (1 - t) + 0.02))
        for j in range(nr):
            for i in range(nc):
                a = base + j * (nc + 1) + i
                f = (a, a + 1, a + nc + 2, a + nc + 1)
                faces.append(f if sg > 0 else f[::-1])
    mesh_de("manchettes", verts, faces, uvs, "corps")

# ------------------------------------------------------------------ appel
faire_robe()
faire_cape(0.30)
faire_cape(0.80, 1.5, "cape_courte")
faire_tablier()
faire_capuche()
faire_epaulieres()
faire_haillons()
faire_pteruges()
faire_sacoche()
faire_carquois()
faire_manchettes()
