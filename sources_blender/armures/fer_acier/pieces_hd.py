# Armures lourdes HD : FER (soldat rugueux) et ACIER NORDIQUE (huscarl). Constructeurs de pièces portées, ajustées au héros par
# les outils de l'agent Y (lourdes/commun.py : tubes mesurés sur le corps, peau d'os transférée), géométrie détaillée (plaques
# épaisses biseautées qui se chevauchent, bords roulés, rivets peints en relief, cotte de mailles en anneaux, ourlets dentelés,
# fourrure en mèches, cornes, joues, camail) et textures HD peintes par hd.py (512² par pièce, 1024² pour la cuirasse).
# Repère Blender (import glTF du héros) : Z haut, -Y devant (Godot +Z), +X = gauche du personnage.
import math
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
import commun as C
import hd as H

TAU = math.tau
COTES = (("l", 1.0), ("r", -1.0))


def _lerp(a, b, t):
    return a + (b - a) * t


def _lisse(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _h(i, j, g):
    return C._h(i, j, g)


# ======================================================================================================== maillage
class PieceHD(C.Piece):
    """Piece de l'agent Y + faces « dedans » (doublures, revers : tournées vers l'intérieur à l'orientation finale)."""

    def __init__(self, nom):
        super().__init__(nom)
        self.dedans = []

    def face(self, idx, mat, uvs, dedans=False):
        super().face(idx, mat, uvs)
        self.dedans.append(dedans)

    def grille_v(self, Pts, mat, rect, vs=None, fermer=True, inverser=False, ao=None, dedans=False, us=None):
        """Grille d'anneaux Pts[j][i] ; rect en unités d'atlas (x0, y0, x1, y1) ; vs / us : fraction 0..1 par rang / colonne ;
        mat : nom, ou fonction (i, j) -> nom / None (face omise : fentes, matières par secteur)."""
        u0, v0, u1, v1 = C.rect_uv(rect)
        nj, ni = len(Pts), len(Pts[0])
        vs = vs or [j / (nj - 1) for j in range(nj)]
        ids = [[self.sommet(Pts[j][i], ao[j] if ao else 1.0) for i in range(ni)] for j in range(nj)]
        nci = ni if fermer else ni - 1
        us = us or [i / nci for i in range(nci + 1)]
        for j in range(nj - 1):
            for i in range(nci):
                i2 = (i + 1) % ni
                m = mat(i, j) if callable(mat) else mat
                if m is None:
                    continue
                q = [ids[j][i], ids[j][i2], ids[j + 1][i2], ids[j + 1][i]]
                ua, ub = u0 + (u1 - u0) * us[i], u0 + (u1 - u0) * us[i + 1]
                va, vb = v0 + (v1 - v0) * vs[j], v0 + (v1 - v0) * vs[j + 1]
                uv = [(ua, va), (ub, va), (ub, vb), (ua, vb)]
                if inverser:
                    q.reverse(); uv.reverse()
                self.face(q, m, uv, dedans)
        return ids

    def boite(self, coins, mat, rect, dedans=False):
        """Pavé (8 coins : 4 du bas puis 4 du haut, même ordre) : 6 faces, UV du rectangle sur chacune."""
        u0, v0, u1, v1 = C.rect_uv(rect)
        ids = [self.sommet(p) for p in coins]
        uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        for q in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            self.face([ids[k] for k in q], mat, uv, dedans)

    def objet_oriente(self, centre_fn, centres_mat=None):
        """Objet Blender ; faces orientées vers l'extérieur (loin de centre_fn) sauf les faces « dedans » (vers centre_fn)."""
        import bpy
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        bm.verts.ensure_lookup_table()
        uvl = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.float_color.new("Col")
        ded = bm.faces.layers.int.new("dedans")
        for (idx, m, uvs), d in zip(self.f, self.dedans):
            if len(set(idx)) < 3:
                continue
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            f.material_index = m
            f[ded] = 1 if d else 0
            for lp, uv, i in zip(f.loops, uvs, idx):
                lp[uvl].uv = uv
                a = self.ao[i]
                lp[col] = (a, a, a, 1.0)
        bm.normal_update()
        flip = []
        for f in bm.faces:
            c = f.calc_center_median()
            fn = (centres_mat or {}).get(self.mats[f.material_index], centre_fn)
            dehors = f.normal.dot(c - fn(c)) >= 0
            if dehors == bool(f[ded]):
                flip.append(f)
        bmesh.ops.reverse_faces(bm, faces=flip)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0003)
        bm.faces.layers.int.remove(ded)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        return ob


def aretes_vives(ob, angle=55):
    """Arêtes à angle vif (tranches des plaques, lèvres) : normales séparées (sinon le lissage moyenne deux faces opposées)."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(angle))
    bm.to_mesh(me); bm.free()


def occlusion_sommets(ob, rayons=24, portee=0.06, force=0.55):
    """Occlusion ambiante par sommet contre la pièce elle-même (sous les lames, entre les plaques, sous le col) -> couleur de
    sommet (multipliée à l'albédo par le shader ps1), alpha 1 (pas de neige)."""
    import random
    me = ob.data
    me.update()
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons], epsilon=0.0)
    rnd = random.Random(11)
    dirs = []
    while len(dirs) < rayons:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.1 < d.length <= 1.0:
            dirs.append(d.normalized())
    ao = []
    for v in me.vertices:
        n = v.normal
        libres = tot = 0
        for d in dirs:
            if d.dot(n) < 0:
                d = -d
            if d.dot(n) < 0.2:
                continue
            tot += 1
            if bvh.ray_cast(v.co + n * 0.0015, d, portee)[0] is None:
                libres += 1
        ao.append(libres / max(tot, 1))
    col = me.color_attributes.get("Col")
    if col is None:
        return
    for lp in me.loops:
        a = col.data[lp.index].color[0] * (1.0 - force * (1.0 - ao[lp.vertex_index]) ** 1.2)
        col.data[lp.index].color = (a, a, a, 1.0)


# ======================================================================================================== peinture commune
def peindre_plaque(T, rect, st, g, bas=True, haut=True, rivets=0, rivet_y=None, graver=None, larg_bis=1.0, pal=None):
    """Plaque métal : matière du style, biseau (arêtes polies), rivets (fer) ou bande gravée (acier)."""
    pal = pal or st["pal"]
    T.zone(rect, H.metal(pal, g, base=st["base"], contraste=st.get("contraste", 0.28), martele=st.get("martele", 0.0),
                         cellule=st.get("cellule", 2.6), oxyde=st.get("oxyde", 0.0), crasse=st.get("crasse", 0.3), poli=st.get("poli", 0.5),
                         patine=st.get("patine", 0.15)),
           rouille=st.get("rouille", 0.0), sale=st.get("sale", 0.6), poli=st.get("poli_bord", 0.25))
    cotes = ("b" if bas else "") + ("h" if haut else "")
    if cotes:
        T.biseau(rect, larg=larg_bis, haut=0.4, cotes=cotes, poli=st.get("poli_arete", 0.9))
    x0, y0, x1, y1 = rect
    if rivets:
        ry = rivet_y if rivet_y is not None else (y1 - larg_bis * 2.2)
        pas = (x1 - x0) / rivets
        T.rivets([(x0 + pas * (k + 0.5), ry) for k in range(rivets)], r=st.get("r_rivet", 0.7), pal=st.get("pal_rivet", pal),
                 k=st.get("k_rivet", 0.62), rouille=st.get("rouille", 0.0) * 0.5)
    if graver:
        T.entrelacs(graver, prof=0.22, poli=0.9)
    if st.get("rayures", 0):
        T.rayures(rect, int(st["rayures"] * (x1 - x0) * (y1 - y0) / 400) + 1, g + 300)


# ======================================================================================================== CASQUE
def casque(r, st):
    """Coque ajustée au crâne (n = 28), rebord épais en bandeau, bandes de renfort en relief (fer) ou crête (acier), nasal épais,
    camail de mailles (fer) ou joues + cornes courtes (acier)."""
    P = PieceHD(st["id"])
    T = H.Toile(st["id"], st.get("px", 512))
    pal = st["pal"]
    g = st.get("graine", 3)
    R_COQUE, R_REB, R_BANDE, R_NAS, R_X1, R_X2 = (0, 0, 128, 70), (0, 70, 128, 82), (0, 82, 40, 128), (40, 82, 56, 128), (56, 82, 92, 128), (92, 82, 128, 128)
    R_CAMAIL = (56, 82, 128, 128)
    arbre = C.bvh(r, ["peau"], {"Head", "neck_01"}, 0.5)
    centre = Vector((0.0, 0.004, 1.685))
    n = st.get("n", 28)
    lats_t = [0.0, 0.1, 0.22, 0.36, 0.5, 0.64, 0.77, 0.89, 1.0]
    bas_front, bas_cote, bas_nuque = st.get("bas", (0.26, -0.12, -0.45))

    def bas(lo):
        c = math.cos(lo); s = abs(math.sin(lo))
        return (bas_front if c > 0 else bas_nuque) * abs(c) ** 1.5 + bas_cote * s ** 1.2
    devant, haut, gauche = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))

    def direction(jt, lo):
        la = _lerp(bas(lo), math.radians(84), jt)
        d = (devant * math.cos(lo) + gauche * math.sin(lo)) * math.cos(la) + haut * math.sin(la)
        return d.normalized()
    dirs, R = [], []
    for jt in lats_t:
        drow, rrow = [], []
        for i in range(n):
            d = direction(jt, TAU * i / n)
            hit = arbre.ray_cast(centre + d * 0.5, -d, 0.5)
            rrow.append(0.5 - hit[3] if hit[0] is not None else None)
            drow.append(d)
        ok = [x for x in rrow if x]
        m = sum(ok) / len(ok)
        R.append([x if x else m for x in rrow]); dirs.append(drow)
    R = C.max_grille(R, 1)
    R = C.lisser_grille(R, 3, k=0.5)
    ep = st.get("ecart", 0.017)
    bombe = st.get("bombe", 0.0)

    def extra(jt):
        return ep + bombe * max(0.0, jt - 0.55) ** 2 * 4.0

    def rayon(j, lo):
        f = (lo % TAU) / TAU * n
        i0 = int(math.floor(f)) % n
        t = f - math.floor(f)
        return R[j][i0] * (1 - t) + R[j][(i0 + 1) % n] * t

    def point(j, lo, plus=0.0):
        return centre + direction(lats_t[j], lo) * (rayon(j, lo) + extra(lats_t[j]) + plus)
    Pts = [[centre + dirs[j][i] * (R[j][i] + extra(jt)) for i in range(n)] for j, jt in enumerate(lats_t)]
    sommet = centre + haut * (max(R[-1]) + ep + bombe * 0.9)
    ids = P.grille_v(Pts, st["mat"], R_COQUE, vs=[jt * 0.97 for jt in lats_t])
    s_id = P.sommet(sommet)
    u0, v0, u1, v1 = C.rect_uv(R_COQUE)
    for i in range(n):
        a, b = ids[-1][i], ids[-1][(i + 1) % n]
        P.face([a, b, s_id], st["mat"], [(u0 + (u1 - u0) * i / n, v1 * 0.97), (u0 + (u1 - u0) * (i + 1) / n, v1 * 0.97), (u0 + (u1 - u0) * (i + 0.5) / n, v1)])
    for i in ids[0]:
        P.ao[i] = 0.75
    # rebord : bandeau épais (dessus en gradin, face, dessous rentré vers le crâne)
    bord = Pts[0]
    deb = st.get("rebord", 0.007)
    hb = st.get("haut_rebord", 0.026)
    r_haut = [p + (p - centre).normalized() * 0.002 + Vector((0, 0, hb)) for p in bord]
    r_haut2 = [p + (p - centre).normalized() * deb + Vector((0, 0, hb - 0.003)) for p in bord]
    r_bas = [p + (p - centre).normalized() * deb + Vector((0, 0, 0.002)) for p in bord]
    r_bas2 = [p + (p - centre).normalized() * (deb * 0.5) - Vector((0, 0, 0.002)) for p in bord]
    dedans = [p - (p - centre).normalized() * (ep * 0.9) for p in bord]
    P.grille_v([r_bas2, r_bas, r_haut2, r_haut], st["mat_rebord"], R_REB, vs=[0.0, 0.12, 0.88, 1.0])
    P.grille_v([dedans, r_bas2], st["mat_rebord"], (0, 70, 128, 71))
    # bandes de renfort (fer : 4 spangen rivetées) ou crête (acier : arête avant-arrière), en relief sur la coque
    bandes = st.get("bandes", [0.0, TAU / 4, TAU / 2, 3 * TAU / 4])
    lb = st.get("larg_bande", 0.016)
    hbnd = st.get("haut_bande", 0.0035)
    jmax = st.get("j_bande", len(lats_t) - 2)
    for k, lo in enumerate(bandes):
        rows = []
        for j in range(0, jmax + 1):
            rr = rayon(j, lo) + extra(lats_t[j])
            w = lb / max(rr, 0.05) * (1.0 if j < jmax else 0.6)
            hh = hbnd if j > 0 else hbnd + 0.002
            rows.append([point(j, lo - w, 0.0005), point(j, lo - w * 0.75, hh), point(j, lo + w * 0.75, hh), point(j, lo + w, 0.0005)])
        bx0 = R_BANDE[0] + (R_BANDE[2] - R_BANDE[0]) * k / max(1, len(bandes))
        bx1 = R_BANDE[0] + (R_BANDE[2] - R_BANDE[0]) * (k + 1) / max(1, len(bandes))
        cols = [[rows[j][c] for j in range(len(rows))] for c in range(4)]
        # grille : colonnes = profil (4 points), rangs = latitude
        P.grille_v(rows, st["mat"], (bx0, R_BANDE[1], bx1, R_BANDE[3]), fermer=False, us=[0.0, 0.2, 0.8, 1.0])
    for dec in st.get("decor", []):
        dec(P, T, r, centre, Pts, point, st)
    # ---- peinture
    T.zone(R_COQUE, H.metal(pal, g, base=st["base"], contraste=0.3, martele=st.get("martele", 0.0), cellule=st.get("cellule", 2.6),
                            oxyde=st.get("oxyde", 0.0), crasse=st.get("crasse", 0.3), poli=st.get("poli", 0.5), patine=0.2),
           rouille=st.get("rouille", 0.0), sale=st.get("sale", 0.6), poli=0.15)
    T.rayures(R_COQUE, int(st.get("rayures", 0) * 40) + 1, g + 7)
    # ombre douce au bas de la coque (sous le rebord) et vers le sommet plus poli
    peindre_plaque(T, R_REB, st, g + 1, rivets=st.get("rivets_rebord", 0), rivet_y=76, larg_bis=0.9,
                   graver=(1, 72.4, 127, 79.6) if st.get("graver") else None)
    for k in range(len(bandes)):
        bx0 = R_BANDE[0] + (R_BANDE[2] - R_BANDE[0]) * k / max(1, len(bandes))
        bx1 = R_BANDE[0] + (R_BANDE[2] - R_BANDE[0]) * (k + 1) / max(1, len(bandes))
        rb = (bx0, R_BANDE[1], bx1, R_BANDE[3])
        T.zone(rb, H.metal(st.get("pal_bande", pal), g + 20 + k, base=st["base"] + 0.06, contraste=0.25, oxyde=st.get("oxyde", 0.0) * 0.8,
                           crasse=0.2, poli=st.get("poli", 0.5) + 0.15), rouille=st.get("rouille", 0.0), sale=0.5, poli=0.3)
        T.biseau(rb, larg=(bx1 - bx0) * 0.22, haut=0.35, cotes="gd", poli=0.9)
        if st.get("rivets_bande", True):
            cx = (bx0 + bx1) / 2
            T.rivets([(cx, R_BANDE[1] + 3 + y) for y in range(0, 40, 7)], r=min(0.9, (bx1 - bx0) * 0.18), pal=pal, k=0.66, rouille=st.get("rouille", 0) * 0.5)
        elif st.get("graver"):
            T.entrelacs((bx0 + (bx1 - bx0) * 0.25, R_BANDE[1] + 1, bx1 - (bx1 - bx0) * 0.25, R_BANDE[3] - 1), brins=2,
                        larg_ruban=(bx1 - bx0) * 0.1, pas=(bx1 - bx0) * 0.9) if False else None
    for p in st.get("peintures", []):
        p(T, st, g)
    T.finir(g=g)
    img = T.image()
    ob = P.objet_oriente(lambda c: centre if c.z > centre.z - 0.12 or abs(c.y + 0.09) > 0.05 else c + Vector((0, 0.05, 0)))
    aretes_vives(ob, 60)
    occlusion_sommets(ob, portee=0.04)
    C.appliquer_materiaux(ob, P, img)
    # poids : tête ; le camail (nuque, sous 1,63 m) se fond vers le cou (il suit la nuque quand la tête se penche)
    def poids(p):
        k = _lisse(1.635, 1.565, p.z) * _lisse(-0.01, 0.035, p.y) * st.get("fondu_cou", 0.0)
        return {"Head": 1.0 - k, "neck_01": k}
    C.peau_fonction(ob, r, poids)
    C.lier(ob, r)
    return ob


def deco_nasal(P, T, r, centre, Pts, point, st, long=0.068, larg=0.015, R=(40, 82, 56, 128)):
    """Nasal forgé épais : face avant bombée, flancs, dessous ; prolonge la bande avant."""
    mat = st["mat"]
    top = point(0, 0.0, 0.004) + Vector((0, 0, st.get("haut_rebord", 0.026) * 0.6))
    rows = []
    for k, z in enumerate((0.0, -long * 0.35, -long * 0.7, -long)):
        w = larg * (1.0, 0.92, 0.86, 0.78)[k]
        y = top.y - 0.004 - 0.005 * k
        e = 0.009
        rows.append([Vector((-w, y + e, top.z + z)), Vector((-w, y, top.z + z)), Vector((-w * 0.45, y - 0.002, top.z + z)),
                     Vector((w * 0.45, y - 0.002, top.z + z)), Vector((w, y, top.z + z)), Vector((w, y + e, top.z + z))])
    P.grille_v(rows, mat, R, fermer=False, us=[0.0, 0.12, 0.35, 0.65, 0.88, 1.0])
    bot = [P.sommet(p) for p in rows[-1]]
    u0, v0, u1, v1 = C.rect_uv(R)
    P.face([bot[0], bot[1], bot[4], bot[5]], mat, [(u0, v0)] * 4)
    P.face([bot[1], bot[2], bot[3], bot[4]], mat, [(u0, v0)] * 4)

    def peint(T, st, g):
        peindre_plaque(T, R, st, g + 40, bas=False, haut=False)
        T.biseau(R, larg=2.2, haut=0.4, cotes="gd", poli=0.9)
        if st.get("rivets_bande", True):
            T.rivets([(48, 120), (48, 110)], r=0.85, pal=st["pal"], k=0.66)
        if st.get("graver"):
            T.entrelacs((43.5, 86, 52.5, 124), brins=2, larg_ruban=1.4, pas=6.0)
    st.setdefault("peintures", []).append(peint)


def deco_camail(P, T, r, centre, Pts, point, st, R=(56, 82, 128, 128)):
    """Camail de mailles : rideau qui tombe du rebord sur la nuque et les côtés (des oreilles à l'autre oreille par derrière),
    deux épaisseurs (dessus / doublure), bas dentelé ; écarté de la nuque et du col."""
    a0, a1 = math.radians(st.get("camail_arc", (88, 272))[0]), math.radians(st.get("camail_arc", (88, 272))[1])
    m = 15
    arbre = C.bvh(r, ["peau"], {"Head", "neck_01", "spine_03"}, 0.3)
    lon = [_lerp(a0, a1, i / (m - 1)) for i in range(m)]
    devant, gauche = Vector((0, -1, 0)), Vector((1, 0, 0))
    rows = []
    hauteurs = [0.0, -0.03, -0.06, -0.085]
    for k, dz in enumerate(hauteurs):
        row = []
        for i, lo in enumerate(lon):
            top = point(0, lo, st.get("rebord", 0.007) * 0.4)
            d = (devant * math.cos(lo) + gauche * math.sin(lo))
            z = top.z + dz
            c = Vector((0, 0.004, z))
            hit = arbre.ray_cast(c + d * 0.4, -d, 0.4)
            rr = (0.4 - hit[3]) if hit[0] is not None else 0.08
            r_top = (top - Vector((0, 0.004, top.z))).length
            rad = max(rr + 0.030 + 0.012 * k, r_top - 0.004 + 0.006 * k) if k > 0 else r_top - 0.002
            dent = (-0.010 if i % 2 == 0 else 0.0) if k == len(hauteurs) - 1 else 0.0
            row.append(Vector((0, 0.004, z + dent)) + d * rad)
        rows.append(row)
    rows.reverse()                    # du bas vers le haut (v = 0 au bas dentelé)
    vs = [0.0, 0.3, 0.65, 1.0]
    P.grille_v(rows, "fer.maille" if st["mat"].startswith("fer") else "acier.maille", R, vs=vs, fermer=False)
    dbl = [[p + (Vector((0, 0.004, p.z)) - p).normalized() * 0.005 for p in row] for row in rows]
    P.grille_v(dbl, "fer.maille" if st["mat"].startswith("fer") else "acier.maille", (R[0], R[1], R[2], R[1] + 6), vs=vs, fermer=False, dedans=True)
    # tranche du bas (épaisseur) : entre dessus et doublure
    P.grille_v([dbl[0], rows[0]], "fer.maille" if st["mat"].startswith("fer") else "acier.maille", (R[0], R[1], R[2], R[1] + 1), fermer=False)

    def peint(T, st, g):
        T.zone(R, H.maille(H.FER, g + 50, pu=0.85, pv=0.62, base=st.get("base_maille", 0.5), rouille=st.get("oxyde", 0.0)),
               rouille=st.get("rouille", 0.0) * 0.8, sale=0.7, poli=0.1)
    st.setdefault("peintures", []).append(peint)
    st["fondu_cou"] = 0.55


def deco_joues(P, T, r, centre, Pts, point, st, R=(56, 82, 92, 128)):
    """Joues d'acier (paragnathides) épaisses : face bombée, bord biseauté, doublure, des tempes le long des joues."""
    mat = st["mat"]
    arbre = C.bvh(r, ["peau", "Hair_Beard"], {"Head"}, 0.5)
    for cote in (1.0, -1.0):
        grid = []
        zs = st.get("joues_z", (1.672, 1.648, 1.624, 1.600))
        la0, la1 = st.get("joues_arc", (36, 104))
        for k, z in enumerate(zs):
            row = []
            for a in range(6):
                lo = math.radians(_lerp(la0, la1, a / 5)) * cote
                d = Vector((math.sin(lo), -math.cos(lo), 0))
                c = Vector((0, 0.004, z))
                hit = arbre.ray_cast(c + d * 0.4, -d, 0.4)
                rr = (0.4 - hit[3]) if hit[0] is not None else 0.085
                bombe = 0.004 * math.sin(math.pi * a / 5) * math.sin(math.pi * (k + 0.5) / len(zs))
                row.append(c + d * (rr + st.get("joues_ecart", 0.017) + 0.004 * k + bombe))
            grid.append(row if cote > 0 else list(reversed(row)))
        grid.reverse()       # bas -> haut
        P.grille_v(grid, mat, R, fermer=False)
        dbl = [[p + (Vector((0, 0.004, p.z)) - p).normalized() * 0.006 for p in row] for row in grid]
        P.grille_v(dbl, mat, (R[0], R[1], R[2], R[1] + 4), fermer=False, dedans=True)
        # tranches : bas et bord avant / arrière
        P.grille_v([dbl[0], grid[0]], mat, (R[0], R[1], R[2], R[1] + 1), fermer=False)
        P.grille_v([[row[0] for row in dbl], [row[0] for row in grid]], mat, (R[0], R[1], R[0] + 1, R[3]), fermer=False)
        P.grille_v([[row[-1] for row in grid], [row[-1] for row in dbl]], mat, (R[2] - 1, R[1], R[2], R[3]), fermer=False)

    def peint(T, st, g):
        peindre_plaque(T, R, st, g + 60, bas=True, haut=False, larg_bis=1.6)
        T.biseau(R, larg=1.6, haut=0.4, cotes="gd", poli=0.9)
        T.entrelacs((R[0] + 3, R[1] + 4, R[2] - 3, R[1] + 11), brins=2)
        T.rivets([(R[0] + 4, R[3] - 4), (R[2] - 4, R[3] - 4), ((R[0] + R[2]) / 2, R[3] - 3)], r=0.9, pal=st["pal"], k=0.7)
    st.setdefault("peintures", []).append(peint)


def deco_masque_t(P, T, r, centre, Pts, point, st, R=(92, 82, 128, 128)):
    """Fond de la visière en T : coque intérieure noircie, juste devant le visage, derrière la fente des yeux et la fente
    verticale ; à distance de jeu le T se lit en noir franc (on ne voit plus la peau à travers)."""
    arbre = C.bvh(r, ["peau", "Hair_Beard"], {"Head"}, 0.5)
    la0, la1 = st.get("masque_arc", (-24, 24))
    zs = st.get("masque_z", (1.575, 1.61, 1.645, 1.68, 1.715))
    m = 7
    grid = []
    rad = []
    for z in zs:
        rrow = []
        for a in range(m):
            lo = math.radians(_lerp(la0, la1, a / (m - 1)))
            d = Vector((math.sin(lo), -math.cos(lo), 0))
            hit = arbre.ray_cast(Vector((0, 0.004, z)) + d * 0.4, -d, 0.4)
            rrow.append((0.4 - hit[3]) if hit[0] is not None else 0.1)
        rad.append(rrow)
    # coque lisse qui passe DEVANT le nez : rayon = max de la rangée (et des voisines), adouci vers les bords
    rows = []
    for k, z in enumerate(zs):
        rm = max(max(rad[kk]) for kk in range(max(0, k - 1), min(len(zs), k + 2)))
        row = []
        for a in range(m):
            lo = math.radians(_lerp(la0, la1, a / (m - 1)))
            d = Vector((math.sin(lo), -math.cos(lo), 0))
            f = abs(_lerp(-1.0, 1.0, a / (m - 1)))
            rr = max(rad[k][a], rm - 0.022 * f * f)
            row.append(Vector((0, 0.004, z)) + d * (rr + st.get("masque_ecart", 0.013)))
        rows.append(row)
    P.grille_v(rows, st["mat"], R, fermer=False)

    def peint(T, st, g):
        def noir(X, Y, U, V):
            n = H.fbm(X, Y, g + 90, oct=((4, 0.6), (1.5, 0.4)))
            return H.rampe(["#030303", "#070707", "#0c0c0c", "#121212"], 0.3 + 0.4 * n), np.full(X.shape, 0.02), None
        T.zone(R, noir, sale=0.0)
    st.setdefault("peintures", []).append(peint)


def deco_cornes(P, T, r, centre, Pts, point, st, R=(92, 82, 128, 128), longueur=0.115, base=0.026):
    """Cornes courtes recourbées (vers l'extérieur puis l'avant et le haut), 8 côtés, 6 tronçons, virole d'acier à la base."""
    for cote in (1.0, -1.0):
        racine = centre + Vector((0.083 * cote, 0.006, 0.072))
        axe = [racine]
        dirn = Vector((0.9 * cote, 0.05, 0.42)).normalized()
        p = racine
        ns = 6
        for k in range(ns):
            p = p + dirn * (longueur / ns)
            dirn = (dirn + Vector((0, -0.2, 0.28))).normalized()
            axe.append(p)
        anneaux = []
        for k, c in enumerate(axe):
            tg = (axe[min(k + 1, ns)] - axe[max(k - 1, 0)]).normalized()
            u, w = C.repere(tg)
            rr = base * (1.0 - k / (ns + 1.2)) * (1.08 if k == 0 else 1.0)
            anneaux.append([c + (u * math.cos(TAU * i / 8) + w * math.sin(TAU * i / 8)) * rr for i in range(8)])
        ids = P.grille_v(anneaux, "os.corne", R, inverser=cote < 0)
        pt = P.sommet(axe[-1] + (axe[-1] - axe[-2]).normalized() * 0.024)
        u0, v0, u1, v1 = C.rect_uv(R)
        for i in range(8):
            q = [ids[-1][i], ids[-1][(i + 1) % 8], pt] if cote > 0 else [ids[-1][(i + 1) % 8], ids[-1][i], pt]
            P.face(q, "os.corne", [(u0 + (u1 - u0) * i / 8, v1 * 0.99), (u0 + (u1 - u0) * (i + 1) / 8, v1 * 0.99), (u0 + (u1 - u0) * (i + 0.5) / 8, v1)])
        for i in ids[0]:
            P.ao[i] = 0.5
        # virole : anneau d'acier épais à la base
        tg = (axe[1] - axe[0]).normalized()
        u, w = C.repere(tg)
        vir = []
        for k, (dz, rr) in enumerate(((-0.004, base * 1.32), (0.006, base * 1.32), (0.012, base * 1.18))):
            c = axe[0] + tg * dz
            vir.append([c + (u * math.cos(TAU * i / 10) + w * math.sin(TAU * i / 10)) * rr for i in range(10)])
        P.grille_v(vir, st["mat"], (R[0], R[1], R[2], R[1] + 3), inverser=cote < 0)

    def peint(T, st, g):
        def corne(X, Y, U, V):
            n = H.fbm(X, Y, g + 70, oct=((6, 0.5), (2, 0.3), (0.7, 0.2)))
            stries = 0.5 + 0.5 * np.sin(V * 34.0 + n * 3.0)
            t = 0.25 + 0.55 * V ** 1.3 + (n - 0.5) * 0.25 - 0.06 * stries
            rgb = H.rampe(H.CORNE, t)
            return rgb, 0.25 + 0.35 * V, -0.06 * stries + (n - 0.5) * 0.05
        T.zone((R[0], R[1] + 3, R[2], R[3]), corne, sale=0.5, poli=0.2)
        peindre_plaque(T, (R[0], R[1], R[2], R[1] + 3), st, g + 71, bas=True, haut=True, larg_bis=0.6)
    st.setdefault("peintures", []).append(peint)



# ======================================================================================================== CUIRASSE
TORSE_OS = {"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"}
R_JUPE, R_HAUT, R_PLAQ, R_CEINT, R_BOUCLE, R_SACOCHE, R_SANGLE, R_TASS, R_EPAUL, R_MANCHE, R_FOUR = (
    (0, 0, 128, 22), (0, 22, 128, 40), (0, 40, 128, 80), (0, 80, 100, 88), (100, 80, 106, 88), (106, 80, 112, 88), (0, 88, 112, 92),
    (112, 80, 128, 92), (0, 92, 84, 112), (0, 112, 84, 128), (84, 92, 128, 128))
AXE_T = Vector((0, -0.005, 0.0))


def _dir(a):
    """Direction horizontale d'angle a (0 = devant -Y, pi/2 = gauche +X), convention de commun.tube."""
    return Vector((math.sin(a), -math.cos(a), 0.0))


def _ang_col(i, n):
    a = math.pi + TAU * (i + 0.5) / n
    return math.atan2(math.sin(a), math.cos(a))


def _bvh_faces(P, filtre_mat=None):
    faces = [idx for (idx, m, uvs) in P.f if filtre_mat is None or P.mats[m] in filtre_mat]
    return BVHTree.FromPolygons(P.v, faces, epsilon=0.0)


def _interieur(q):
    """Point intérieur de référence (axe du bras sur les épaules, axe du torse ailleurs) : oriente les normales des surfaces."""
    if abs(q.x) > 0.17 and 1.38 < q.z < 1.56:
        return Vector((q.x, 0.03, 1.455))
    return Vector((0.0, -0.005, min(q.z, 1.50)))


def pousser(rows, arbres, marge):
    """Pousse dehors (le long de la normale de la surface la plus proche, orientée vers l'extérieur) les points sous / trop près
    des surfaces des arbres."""
    for row in rows:
        for k, p in enumerate(row):
            q = p.copy()
            for _ in range(3):
                for a in arbres:
                    loc, nrm, _, dist = a.find_nearest(q, 0.3)
                    if loc is None:
                        continue
                    if nrm.dot(loc - _interieur(loc)) < 0:
                        nrm = -nrm
                    sgn = (q - loc).dot(nrm)
                    if sgn < marge:
                        q = q + nrm * (marge - sgn)
            row[k] = q
    return rows


def cuirasse(r, st):
    """Planche de référence (colonne STEEL/IRON) : plastron riveté et lames d'acier sur une cotte de mailles, sangles de cuir
    croisées à boucles et disque, ceinture large à boucle carrée, sacoche, tablier de mailles devant entre des pans de cuir
    (fendus, déchirés pour le fer), tassettes sur les hanches, épaulières de lames, manches de cuir, GROS COL DE FOURRURE beige sur
    les épaules (manteau qui couvre le haut des épaulières)."""
    P = PieceHD(st["id"])
    T = H.Toile(st["id"], st.get("px", 1024))
    g = st.get("graine", 5)
    pal = st["pal"]
    MM = st.get("mat_maille", "fer.maille")
    axeA, axeB = Vector((0, -0.005, 0.66)), Vector((0, -0.005, 1.60))
    Hh = axeB.z - axeA.z

    def tz(z):
        return (z - axeA.z) / Hh
    n = st.get("n", 24)
    arbre = C.bvh(r, ["tunique", "peau"], TORSE_OS, 0.5)
    arbre_jambes = C.bvh(r, ["pantalon"], {"pelvis", "thigh_l", "thigh_r", "spine_01"}, 0.3)
    angs = [math.pi + TAU * i / n for i in range(n)]
    # ---------------------------------------------------------------- jupe : tablier de mailles devant, pans de cuir ailleurs
    zo = st.get("z_ourlet", 0.68)
    z_jupe = [zo, zo + 0.06, zo + 0.13, 0.89, 0.955, 1.02]
    nj = len(z_jupe)
    tab = math.radians(st.get("tablier", 30))
    fentes = [math.radians(x) for x in st.get("fentes", (-105, 105, 180))]
    h_fente = st.get("h_fente", 3)            # rangs fendus depuis l'ourlet

    def dec_jupe(j, i, a):
        aa = math.atan2(math.sin(a), math.cos(a))
        cuir = abs(aa) > tab
        return (0.03 + 0.05 * (1.0 - j / (nj - 1.0)) ** 1.3 + (0.012 if math.cos(a) < 0 else 0.0) + (0.0035 if (j % 2 == 1 and not cuir) else 0.0)
                + (0.006 if cuir else 0.0))
    Pj, Rj, _ = C.tube(arbre_jambes, axeA, axeB, [tz(z) for z in z_jupe], n, dec_jupe, r_loin=0.6, dilate=2, lisse=3)
    dech = st.get("dechire", 0.0)
    for i, p in enumerate(Pj[0]):
        aa = math.atan2(math.sin(angs[i]), math.cos(angs[i]))
        if abs(aa) <= tab + 0.05:
            Pj[0][i] = p - Vector((0, 0, st.get("dents", 0.010) if i % 2 == 0 else 0.0)) - Vector((0, 0, 0.03))   # tablier plus long
        else:
            Pj[0][i] = p - Vector((0, 0, dech * _h(i, 0, g + 3)))

    def mat_jupe(i, j):
        a = _ang_col(i, n)
        if j < h_fente and any(abs(math.atan2(math.sin(a - f), math.cos(a - f))) < TAU / n * 0.55 for f in fentes):
            return None
        return MM if abs(a) <= tab else "cuir"
    P.grille_v(Pj, mat_jupe, R_JUPE, inverser=True)
    ourlet = [p + (Vector((0, -0.005, p.z)) - p).normalized() * 0.010 + Vector((0, 0, 0.008)) for p in Pj[0]]
    P.grille_v([ourlet, Pj[0]], lambda i, j: mat_jupe(i, 0), (0, 0, 128, 1.2), inverser=True)
    # ---------------------------------------------------------------- haut de cotte (mailles sous les plaques) et col montant
    zp0, zp1 = st.get("z_plaques", (1.04, 1.42))
    z_haut = [zp1 - 0.03, 1.47, 1.52, 1.545, 1.565]

    def dec_maille(j, i, a):
        return 0.012 if j < 3 else 0.009 + 0.014 * max(0.0, -math.cos(a)) ** 1.5
    Ph, Rh, _ = C.tube(arbre, axeA, axeB, [tz(z) for z in z_haut], n, dec_maille, r_loin=0.6, dilate=1, lisse=2)
    Ph[-1] = [p - Vector((0, 0, 0.03 * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Ph[-1], angs)]
    Ph[-2] = [p - Vector((0, 0, 0.02 * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Ph[-2], angs)]
    P.grille_v(Ph, MM, R_HAUT, inverser=True)
    col_dedans = [p + (Vector((0, 0.0, p.z)) - p).normalized() * 0.014 - Vector((0, 0, 0.01)) for p in Ph[-1]]
    P.grille_v([Ph[-1], col_dedans], MM, (0, 38.5, 128, 40), inverser=True)
    # ---------------------------------------------------------------- plaques : la lame du dessus recouvre celle du dessous (bord
    # libre en BAS, biseauté et riveté) ; la plus haute = plastron bombé, à bord haut roulé
    zs = st.get("z_lames") or [zp0 + (zp1 - zp0) * k / 3 for k in range(4)]
    lames = len(zs) - 1
    bomb = st.get("bombe", 0.0)
    ep_l = st.get("ep_lame", 0.006)
    hls = [(zs[k + 1] - zs[k]) for k in range(lames)]
    tot = sum(hls)
    v_l = [R_PLAQ[1]]
    for hh in hls:
        v_l.append(v_l[-1] + (R_PLAQ[3] - R_PLAQ[1]) * hh / tot)
    for k in range(lames):
        za, zb = zs[k] - (0.02 if k > 0 else 0.0), zs[k + 1]
        haut_libre = (k == lames - 1)
        bev = min(0.012, (zb - za) * 0.15)

        def dec_lame(j, i, a, k=k):
            avant = max(0.0, math.cos(a)) ** 2
            flanc = 0.3 + 0.7 * abs(math.cos(a)) ** 0.8
            plast = math.sin(math.pi * min(1.0, (j + 0.5) / 6.0)) if k == lames - 1 else 1.0
            base = (0.022 + 0.006 * k) * flanc + bomb * avant * (plast if k == lames - 1 else 0.3)
            prof = (-ep_l * 1.6, -ep_l * 0.2, ep_l * 0.45, ep_l * 0.4, (ep_l * 0.1 if haut_libre else 0.0), (-ep_l * 1.4 if haut_libre else 0.0))
            return base + prof[j]
        rows_z = [za + 0.001, za, za + bev, (za + zb) / 2, zb, zb - 0.002]
        Pl, Rl, _ = C.tube(arbre, axeA, axeB, [tz(z) for z in rows_z], n, dec_lame, r_loin=0.6, dilate=2, lisse=3)
        if not haut_libre:
            Pl = Pl[:5]
        vs = [0.0, 0.03, 0.10, 0.5, 1.0]
        if haut_libre:
            vs = [0.0, 0.03, 0.10, 0.5, 0.96, 1.0]
        ids = P.grille_v(Pl, st["mat"], (0, v_l[k], 128, v_l[k + 1]), vs=vs)
        for i in ids[1]:
            P.ao[i] = 0.85
    arbre_plaques = _bvh_faces(P, {st["mat"]})
    # ---------------------------------------------------------------- tassettes sur les hanches (au-dessus des pans de cuir)
    if st.get("tassettes"):
        t0, t1 = st["tassettes"]
        for cote in (1.0, -1.0):
            arc = sorted(math.radians(x) * cote for x in (t0, (2 * t0 + t1) / 3, (t0 + 2 * t1) / 3, t1))
            zt = st.get("z_tassettes", [1.00, 0.925, 0.85])
            for k in range(len(zt) - 1):
                za, zb = zt[k + 1], zt[k] + 0.012

                def dec_t(j, i, a, k=k):
                    return st.get("ecart_tassettes", 0.06) + 0.008 * k + (0.0, 0.004, 0.004, 0.0)[j]
                Pt, _, _ = C.tube(arbre_jambes, axeA, axeB, [tz(z) for z in (za, za + 0.006, zb - 0.008, zb)], 0, dec_t, r_loin=0.6,
                                  dilate=1, lisse=1, angles=arc)
                lip = [p + (Vector((0, -0.005, p.z)) - p).normalized() * 0.008 for p in Pt[0]]
                hy = (R_TASS[3] - R_TASS[1]) / (len(zt) - 1)
                rt = (R_TASS[0], R_TASS[1] + hy * k, R_TASS[2], R_TASS[1] + hy * (k + 1))
                P.grille_v([lip] + Pt, st["mat"], rt, vs=[0.0, 0.06, 0.16, 0.86, 1.0], fermer=False, inverser=cote < 0)
    # ---------------------------------------------------------------- ceinture large et boucle carrée
    zc = st.get("z_ceinture", 1.0)
    hc = st.get("h_ceinture", 0.032)
    rows_c = [zc - hc, zc - hc + 0.004, zc + hc - 0.004, zc + hc]
    Pc, _, _ = C.tube(arbre, axeA, axeB, [tz(z) for z in rows_c], n, lambda j, i, a: 0.05 + (0.0, 0.006, 0.006, 0.0)[j], r_loin=0.6, dilate=2, lisse=3)
    Pc2, _, _ = C.tube(arbre_jambes, axeA, axeB, [tz(z) for z in rows_c], n, lambda j, i, a: 0.05 + (0.0, 0.006, 0.006, 0.0)[j], r_loin=0.6, dilate=2, lisse=3)

    def rad(p):
        return (p - Vector((0, -0.005, p.z))).length
    Pc = [[Pc[j][i] if rad(Pc[j][i]) > rad(Pc2[j][i]) else Pc2[j][i] for i in range(n)] for j in range(4)]
    P.grille_v(Pc, "cuir", R_CEINT, vs=[0.0, 0.1, 0.9, 1.0], inverser=True)
    bas_c = [p + (Vector((0, -0.005, p.z)) - p).normalized() * 0.012 for p in Pc[0]]
    P.grille_v([bas_c, Pc[0]], "cuir", (0, 80, 100, 80.6), inverser=True)
    i0 = n // 2
    avant = (Pc[1][i0] + Pc[2][i0]) / 2
    nrm = (avant - Vector((0, -0.005, avant.z))).normalized()
    tg = Vector((1, 0, 0))
    bw, bh, bd = 0.034, hc + 0.006, 0.006
    c0 = avant + nrm * 0.001
    bas4 = [c0 + tg * x + Vector((0, 0, z)) for (x, z) in ((-bw, -bh), (bw, -bh), (bw, bh), (-bw, bh))]
    P.boite(bas4 + [p + nrm * bd for p in bas4], st.get("mat_boucle", st["mat"]), R_BOUCLE)
    lang = [c0 + tg * 0.016 + nrm * 0.004 + Vector((0, 0, -bh * 0.5)), c0 + tg * 0.042 + nrm * 0.004 + Vector((0, 0, -bh * 0.5)),
            c0 + tg * 0.040 + nrm * 0.008 + Vector((0, 0, -0.12)), c0 + tg * 0.018 + nrm * 0.008 + Vector((0, 0, -0.12))]
    il = [P.sommet(p) for p in lang]
    u0, v0, u1, v1 = C.rect_uv(R_SANGLE)
    P.face(il, "cuir", [(u0, v1), (u0 + (u1 - u0) * 0.2, v1), (u0 + (u1 - u0) * 0.2, v0), (u0, v0)])
    # ---------------------------------------------------------------- sacoche (accrochée à la ceinture, hanche droite)
    if st.get("sacoche") is not None:
        a = math.radians(st["sacoche"])
        ic_ = int(round((a - math.pi) / TAU * n)) % n
        rb = max(rad(Pc[0][ic_]), rad(Pj[-2][ic_]) if len(Pj) > 1 else 0) - 0.004
        d = _dir(a); tg = Vector((math.cos(a), math.sin(a), 0.0))
        o = Vector((0, -0.005, 0))
        z0s, z1s = zc - hc - 0.105, zc - hc + 0.012
        corps = []
        for (rr, zz) in ((rb, z0s), (rb, z1s)):
            pass
        bas4 = [o + d * rb + tg * x + Vector((0, 0, z0s)) for x in (-0.05, 0.05)] + [o + d * (rb + 0.042) + tg * x + Vector((0, 0, z0s + 0.006)) for x in (0.048, -0.048)]
        haut4 = [o + d * rb + tg * x + Vector((0, 0, z1s)) for x in (-0.05, 0.05)] + [o + d * (rb + 0.044) + tg * x + Vector((0, 0, z1s)) for x in (0.05, -0.05)]
        P.boite(bas4 + haut4, "cuir", R_SACOCHE)
        # rabat : plaque de cuir épaisse qui retombe sur le devant
        fz0, fz1 = z1s - 0.05, z1s + 0.004
        fb = [o + d * (rb + 0.044) + tg * x + Vector((0, 0, fz0)) for x in (-0.052, 0.052)] + [o + d * (rb + 0.052) + tg * x + Vector((0, 0, fz0)) for x in (0.052, -0.052)]
        fh = [o + d * (rb + 0.044) + tg * x + Vector((0, 0, fz1)) for x in (-0.052, 0.052)] + [o + d * (rb + 0.052) + tg * x + Vector((0, 0, fz1 + 0.002)) for x in (0.052, -0.052)]
        P.boite(fb + fh, "cuir", R_SACOCHE)
    # ---------------------------------------------------------------- sangles de cuir sur le plastron (posées sur les plaques)
    for (a0, z0), (a1, z1) in st.get("sangles", []):
        m = 8
        centres = []
        for k in range(m + 1):
            t = k / m
            a = math.radians(_lerp(a0, a1, t)); z = _lerp(z0, z1, t)
            d = _dir(a)
            c = Vector((0, -0.005, z))
            hit = arbre_plaques.ray_cast(c + d * 0.6, -d, 0.6)
            p = hit[0] + d * 0.0045 if hit[0] is not None else c + d * 0.2
            centres.append((p, d))
        rows = []
        for k, (p, d) in enumerate(centres):
            tgk = (centres[min(k + 1, m)][0] - centres[max(k - 1, 0)][0]).normalized()
            side = tgk.cross(d).normalized()
            w = 0.021
            rows.append([p + side * w - d * 0.002, p + side * w * 0.8, p - side * w * 0.8, p - side * w - d * 0.002])
        P.grille_v(rows, "cuir", (0, 88, 112, 92), fermer=False, us=[0.0, 0.1, 0.9, 1.0])
    # disque d'acier où les sangles se croisent sur l'épaule
    if st.get("disque") is not None:
        a, z = st["disque"]
        a = math.radians(a)
        d = _dir(a)
        c = Vector((0, -0.005, z))
        hit = arbre_plaques.ray_cast(c + d * 0.6, -d, 0.6)
        if hit[0] is not None:
            ctr = hit[0] + d * 0.009
            nn = (hit[1] if hit[1].dot(d) > 0 else -hit[1]).normalized()
            u, w = C.repere(nn)
            prof = ((0.030, -0.003), (0.030, 0.003), (0.024, 0.008), (0.012, 0.012), (0.003, 0.013))
            rings = [[ctr + nn * hh + (u * math.cos(TAU * i / 8) + w * math.sin(TAU * i / 8)) * rr for i in range(8)] for rr, hh in prof]
            P.grille_v(rings, st["mat"], R_BOUCLE)
    # ---------------------------------------------------------------- manches de cuir et épaulières de lames
    for cote, s in COTES:
        ua, la = r.os["upperarm_" + cote], r.os["lowerarm_" + cote]
        bras = C.bvh(r, ["tunique", "brassards", "peau"], {"upperarm_" + cote, "lowerarm_" + cote}, 0.5)
        A = ua + Vector((-0.03 * s, 0, 0))
        B = Vector((st.get("x_manche", 0.435) * s, la.y, la.z))
        nm = 10
        Pm, Rm, _ = C.tube(bras, A, B, [0.0, 0.5, 0.9, 1.0], nm,
                           lambda j, i, a: 0.011 + 0.016 * (j / 3) ** 2 + (0.003 if j == 2 else 0.0), r_loin=0.3, dilate=1, lisse=2)
        P.grille_v(Pm, "cuir", R_MANCHE, inverser=s > 0, vs=[0.0, 0.5, 0.9, 1.0])
        bm_ = [p + (A.lerp(B, 1.0) - p).normalized() * 0.01 for p in Pm[-1]]
        P.grille_v([Pm[-1], bm_], "cuir", (R_MANCHE[0], R_MANCHE[3] - 1, R_MANCHE[2], R_MANCHE[3]), inverser=s > 0)
        nl = st.get("lames_epaule", 3)
        epaule = C.bvh(r, ["tunique", "peau"], {"upperarm_" + cote, "clavicle_" + cote, "spine_03"}, 0.5)
        E0 = Vector((0.12 * s, -0.005, 1.47))
        E1 = Vector((0.36 * s, 0.02, 1.455))
        arc = [math.radians(x) for x in range(142, 409, 24)]
        wl = (R_EPAUL[2] - R_EPAUL[0]) / nl
        roule = st.get("bord_roule", False)
        t_dep = st.get("epaule_debut", 0.18)
        for k in range(nl):
            ta = t_dep + (0.95 - t_dep) * k / nl
            tb = t_dep + (0.95 - t_dep) * (k + 1) / nl + 0.06
            tm = (ta + tb) / 2

            def dec_e(j, i, a, k=k):
                dessus = max(0.0, -math.sin(a))
                base = st.get("epaule_ecart", 0.026) + 0.009 * (nl - k) + 0.018 * dessus ** 0.5
                return base + (0.0, 0.004, (0.008 if roule else 0.003), (0.004 if roule else -0.004))[j]
            ts = [ta, tb - 0.04, tb - 0.012, tb]
            Pe, Re, rep = C.tube(epaule, E0, E1, ts, 0, dec_e, r_loin=0.4, dilate=0, lisse=1, angles=arc)
            if s < 0:
                Pe = [list(reversed(row)) for row in Pe]
            re = (R_EPAUL[0] + wl * k, R_EPAUL[1], R_EPAUL[0] + wl * (k + 1), R_EPAUL[3])
            ide = P.grille_v(Pe, st["mat"], re, vs=[0.0, 0.78, 0.92, 1.0], fermer=False, inverser=s < 0)
            tr = [p + (E0.lerp(E1, tb) - p).normalized() * (0.020 if roule else 0.012) for p in Pe[-1]]
            P.grille_v([Pe[-1], tr], st["mat"], (re[0], re[3] - 0.8, re[2], re[3]), fermer=False, inverser=s < 0)
            for col_i, inv in ((0, False), (-1, True)):
                bord = [row[col_i] for row in Pe]
                bord_in = [p + (E0.lerp(E1, t) - p).normalized() * 0.010 for p, t in zip(bord, ts)]
                P.grille_v([bord, bord_in], st["mat"], (re[0], re[1], re[0] + 0.8, re[3]), fermer=False, inverser=(inv != (s < 0)))
            for i in ide[0]:
                P.ao[i] = 0.6
    # ---------------------------------------------------------------- GROS COL DE FOURRURE : manteau sur le haut des épaules et la
    # nuque, ouvert devant (la barbe), volume en boudin, bord en mèches ; écarté du corps et des épaulières
    if st.get("fourrure"):
        F = st["fourrure"]
        fa0, fa1 = F.get("arc", (48, 312))
        nf = int((fa1 - fa0) / F.get("pas", 14)) + 1      # linspace : arc EXACTEMENT symétrique (range() s'arrêtait à 300°)
        arc_f = [math.radians(fa0 + (fa1 - fa0) * q / (nf - 1)) for q in range(nf)]
        # manteau drapé : depuis un pivot au-dessus de la base du cou, rayons lancés de l'extérieur vers le pivot dans le plan
        # vertical de chaque angle ; la 1re surface touchée (épaulières, mailles du col, corps) porte la fourrure + son épaisseur
        O = Vector((0, 0.0, F.get("z_pivot", 1.60)))
        haut_v = Vector((0, 0, 1))
        support = BVHTree.FromPolygons(P.v, [idx for (idx, m, uvs) in P.f if P.mats[m] in (st["mat"], MM)], epsilon=0.0)
        corps_t = C.bvh(r, ["tunique", "peau"], TORSE_OS - {"neck_01"} | {"upperarm_l", "upperarm_r"}, 0.4)
        phis_dos = F.get("phis", (-50, -42, -20, 10, 34, 50))
        phis_cote = F.get("phis_cote", (-20, -14, 0, 18, 36, 50))

        def phi(k, a_):
            w = max(0.0, -math.cos(a_)) ** 1.2
            return math.radians(phis_cote[k] + (phis_dos[k] - phis_cote[k]) * w)
        phis = phis_dos
        ep = [e * F.get("gonfle", 1.0) for e in F.get("ep", (0.006, 0.030, 0.060, 0.064, 0.040, 0.012))]
        R = []
        for k, ph in enumerate(phis):
            row = []
            for i, a_ in enumerate(arc_f):
                ph = phi(k, a_)
                d = _dir(a_) * math.cos(ph) + haut_v * math.sin(ph)
                best = None
                for arb in (support, corps_t):
                    hit = arb.ray_cast(O + d * 0.7, -d, 0.7)
                    if hit[0] is not None:
                        dd = 0.7 - hit[3]
                        best = dd if best is None else max(best, dd)
                row.append(best)
            ok = [x for x in row if x is not None]
            moy = sum(ok) / len(ok) if ok else 0.15
            R.append([x if x is not None else moy for x in row])
        R = C.max_grille(R, 1)
        R = C.lisser_grille(R, 2, circulaire=False, k=0.5)
        rows = []
        for k, ph in enumerate(phis):
            row = []
            for i, a_ in enumerate(arc_f):
                ph = phi(k, a_)
                d = _dir(a_) * math.cos(ph) + haut_v * math.sin(ph)
                s_ = abs(math.sin(a_))
                e = ep[k] * (1.0 + F.get("cote", 0.25) * s_) + 0.012 * (_h(min(i, nf - 1 - i), k, g + 7) - 0.5) * (1 if 0 < k < len(phis) - 1 else 0)
                row.append(O + d * (R[k][i] + F.get("marge", 0.012) + e))
            rows.append(row)
        # bord extérieur un peu rabattu vers le bas (poids de la peau) ; dessous rentré vers le support
        rows[0] = [p + Vector((0, 0, -0.008)) for p in rows[0]]
        # emprise limitée au haut des épaules et à la nuque (planche : col sur les épaules, épaulières visibles dessous)
        for row in rows:
            for k, p in enumerate(row):
                hz = Vector((p.x, p.y, 0.0))
                a_ = math.atan2(p.x, -p.y)
                rmax = F.get("r_max", 0.17) + F.get("r_max_cote", 0.07) * abs(math.sin(a_))
                if hz.length > rmax:
                    row[k] = Vector((p.x * rmax / hz.length, p.y * rmax / hz.length, p.z))
        pousser(rows, [support, corps_t], 0.010)
        P.grille_v(rows, "fourrure", R_FOUR, vs=[0.0, 0.1, 0.4, 0.68, 0.88, 1.0], fermer=False, inverser=True)
        for bout in (0, -1):
            col_b = [row[bout] for row in rows]
            ctr = sum(col_b, Vector()) / len(col_b)
            ids_b = [P.sommet(p) for p in col_b]
            ic_ = P.sommet(ctr)
            u0, v0, u1, v1 = C.rect_uv((84, 92, 90, 128))
            # bouchon des deux côtés (deux faces opposées, la seconde décalée de 1,5 mm vers l'intérieur du col) : jamais de trou
            voisin = [row[1 if bout == 0 else -2] for row in rows]
            dec = (sum(voisin, Vector()) / len(voisin) - ctr).normalized() * 0.0015
            ids_b2 = [P.sommet(p + dec) for p in col_b]
            ic2 = P.sommet(ctr + dec)
            for k in range(len(col_b) - 1):
                uvq = [(u0, v0 + (v1 - v0) * k / 5), (u0, v0 + (v1 - v0) * (k + 1) / 5), (u1, (v0 + v1) / 2)]
                P.face([ids_b[k], ids_b[k + 1], ic_], "fourrure", uvq)
                P.face([ids_b2[k], ids_b2[k + 1], ic2], "fourrure", uvq, dedans=True)
        # doublure intérieure (faces « dedans », maillage clairsemé) : plus de face noire vue de l'intérieur du col
        lig = [[rows[k][i] - Vector((rows[k][i].x, rows[k][i].y + 0.005, 0.0)).normalized() * 0.004 for i in range(0, nf, 2)] for k in (0, 2, 5)]
        P.grille_v(lig, "fourrure", R_FOUR, vs=[0.0, 0.4, 1.0], fermer=False, inverser=True, dedans=True)
        # MÈCHES (technique de la fourrure loup, 3 triangles par mèche : bande pliée + pointe) : petites, denses, couchées vers le
        # bas et l'extérieur, plus nombreuses sur le bord et le dessus du col ; teinte et dégradé portés par la texture
        u0, v0, u1, v1 = C.rect_uv(R_FOUR)
        L0 = F.get("long_meche", 0.055)
        dens = F.get("densite", (3, 1, 1, 1, 1))
        for k in range(1, len(rows)):
            for i in range(nf - 1):
                for q in range(dens[k - 1]):
                    h1, h2, h3 = _h(i, k * 7 + q, 21), _h(i, k * 7 + q, 22), _h(i, k * 7 + q, 23)
                    fu, fv = (q + h1) / dens[k - 1], 0.25 + 0.7 * h2
                    top = lambda g_: rows[k][i].lerp(rows[k][i + 1], g_)
                    bot = lambda g_: rows[k - 1][i].lerp(rows[k - 1][i + 1], g_)
                    pos = top(fu).lerp(bot(fu), fv)
                    desc = (bot(fu) - top(fu))
                    desc = desc.normalized() if desc.length > 1e-6 else Vector((0, 0, -1))
                    lat = (rows[k][i + 1] - rows[k][i]).normalized()
                    out = (pos - Vector((0, -0.005, pos.z))).normalized()
                    L = L0 * (0.7 + 0.6 * h3) * (1.15 if k == 1 else 1.0)
                    w = 0.016 * (0.8 + 0.5 * h2)
                    sens = desc * (1.0 if k >= 3 else 0.8)
                    a_ = pos - lat * w / 2 + out * 0.002
                    b_ = pos + lat * w / 2 + out * 0.002
                    mid = pos + sens * L * 0.5 + out * (0.012 + 0.006 * h1) + Vector((0, 0, -0.004))
                    ma, mb = mid - lat * w * 0.35, mid + lat * w * 0.35
                    tip = pos + sens * L + out * (0.020 + 0.010 * h3) + Vector((0, 0, -0.016 - 0.008 * h2)) + lat * (h1 - 0.5) * 0.008
                    ia, ib = P.sommet(a_, 0.7), P.sommet(b_, 0.7)
                    ima, imb = P.sommet(ma, 0.85), P.sommet(mb, 0.85)
                    it = P.sommet(tip, 1.0)
                    uu = u0 + (u1 - u0) * (0.1 + 0.8 * h1)
                    uw = (u1 - u0) * 0.05
                    va, vm, vt = v0 + (v1 - v0) * 0.85, v0 + (v1 - v0) * 0.5, v0 + (v1 - v0) * 0.1
                    P.face([ia, ib, imb, ima], "fourrure", [(uu - uw, va), (uu + uw, va), (uu + uw * 0.7, vm), (uu - uw * 0.7, vm)])
                    P.face([ima, imb, it], "fourrure", [(uu - uw * 0.7, vm), (uu + uw * 0.7, vm), (uu, vt)])
    # ================================================================ peinture
    pm = st.get("pal_maille", H.FER)
    pc = st.get("pal_cuir", H.CUIR)
    T.zone(R_JUPE, H.cuir(pc, g + 6, base=st.get("base_cuir", 0.42), use=0.7), sale=0.7)
    ut = tab / TAU
    T.zone((64 - 128 * ut - 1, 0, 64 + 128 * ut + 1, 22), H.maille(pm, g, pu=0.95, pv=0.62, base=st.get("base_maille", 0.5), rouille=st.get("oxyde_maille", 0.0)),
           rouille=st.get("rouille", 0.0) * 0.8, sale=0.75, poli=0.1)
    for x in (64 - 128 * ut - 1, 64 + 128 * ut + 1):          # bords des pans cousus
        T.couture((x + (2 if x > 64 else -2), 2), (x + (2 if x > 64 else -2), 21), pas=0.9)
    T.couture((0, 2.5), (64 - 128 * ut - 3, 2.5), pas=0.9); T.couture((64 + 128 * ut + 3, 2.5), (128, 2.5), pas=0.9)
    T.zone(R_HAUT, H.maille(pm, g + 1, pu=0.95, pv=0.78, base=st.get("base_maille", 0.5), rouille=st.get("oxyde_maille", 0.0)),
           rouille=st.get("rouille", 0.0) * 0.8, sale=0.75, poli=0.1)
    for k in range(lames):
        rect = (0, v_l[k], 128, v_l[k + 1])
        hl = v_l[k + 1] - v_l[k]
        haut_libre = (k == lames - 1)
        nr = st.get("rivets_lame", 0)
        peindre_plaque(T, rect, st, g + 10 + k, bas=True, haut=haut_libre, rivets=nr, rivet_y=v_l[k] + max(1.6, hl * 0.12), larg_bis=min(1.4, hl * 0.12))
        if haut_libre and nr:
            T.rivets([(128 / nr * (q + 0.5), v_l[k + 1] - max(1.6, hl * 0.08)) for q in range(nr)], r=st.get("r_rivet", 0.7), pal=pal, k=0.64,
                     rouille=st.get("rouille", 0.0) * 0.5)
        if haut_libre and st.get("rivets_milieu"):
            # rivets le long du milieu du plastron (arête centrale) : rangées verticales de part et d'autre
            for x in (60.5, 67.5):
                T.rivets([(x, v_l[k] + hl * f) for f in (0.3, 0.45, 0.6, 0.75)], r=st.get("r_rivet", 0.7), pal=pal, k=0.62)
            T.ligne_v(64, v_l[k] + 1, v_l[k + 1] - 1, larg=0.6, prof=0.15)
    T.zone(R_CEINT, H.cuir(pc, g + 2, base=0.40), sale=0.6)
    T.biseau(R_CEINT, larg=0.8, haut=0.2, cotes="bh", poli=0.3)
    T.couture((1, 81.2), (99, 81.2), pas=0.9)
    T.couture((1, 86.8), (99, 86.8), pas=0.9)
    # boucle carrée : cadre d'acier, ardillon, le cuir visible au milieu
    T.zone(R_BOUCLE, H.metal(st.get("pal_boucle", pal), g + 3, base=st["base"] + 0.08, contraste=0.25, crasse=0.3, poli=0.7), sale=0.5, poli=0.6)

    def cadre(t, sl, X, Y, U, V):
        dedans = (U > 0.2) & (U < 0.8) & (V > 0.22) & (V < 0.78)
        t.h[sl] = np.where(dedans, t.h[sl] - 0.5, t.h[sl] + 0.1)
        c = H.rampe(pc, np.full(X.shape, 0.3))
        t.rgb[sl] = np.where(dedans[..., None], c, t.rgb[sl])
        barre = (np.abs(U - 0.5) < 0.05) & dedans
        t.h[sl] = np.where(barre, t.h[sl] + 0.6, t.h[sl])
        t.rgb[sl] = np.where(barre[..., None], H.rampe(st.get("pal_boucle", pal), np.full(X.shape, 0.7)), t.rgb[sl])
    T.appliquer((100, 80, 106, 84.5), cadre)
    T.biseau((100, 80, 106, 84.5), larg=0.5, haut=0.3, cotes="bhgd", poli=1.0)
    T.zone(R_SACOCHE, H.cuir(pc, g + 8, base=0.36, use=0.8), sale=0.7)
    T.couture((106.6, 80.6), (106.6, 87.4), pas=0.7); T.couture((111.4, 80.6), (111.4, 87.4), pas=0.7)
    T.zone(R_SANGLE, H.cuir(pc, g + 4, base=0.34), sale=0.55)
    T.biseau(R_SANGLE, larg=0.6, haut=0.2, cotes="bh", poli=0.25)
    T.couture((0, 88.7), (112, 88.7), pas=1.0); T.couture((0, 91.3), (112, 91.3), pas=1.0)
    if st.get("tassettes"):
        zt = st.get("z_tassettes", [1.00, 0.925, 0.85])
        hy = (R_TASS[3] - R_TASS[1]) / (len(zt) - 1)
        for k in range(len(zt) - 1):
            rt = (R_TASS[0], R_TASS[1] + hy * k, R_TASS[2], R_TASS[1] + hy * (k + 1))
            peindre_plaque(T, rt, st, g + 80 + k, bas=True, haut=False, larg_bis=0.5, rivets=3 if st.get("rivets_lame") else 0, rivet_y=rt[1] + 1.2)
    nl = st.get("lames_epaule", 3)
    for k in range(nl):
        wl = (R_EPAUL[2] - R_EPAUL[0]) / nl
        re = (R_EPAUL[0] + wl * k, R_EPAUL[1], R_EPAUL[0] + wl * (k + 1), R_EPAUL[3])
        peindre_plaque(T, re, st, g + 40 + k, bas=False, haut=True, rivets=st.get("rivets_epaule", 0), rivet_y=re[3] - 2.4, larg_bis=1.4)
        T.biseau(re, larg=1.0, haut=0.25, cotes="gd", poli=0.6)
    T.zone(R_MANCHE, H.cuir(pc, g + 9, base=st.get("base_cuir", 0.42) - 0.04, use=0.6), sale=0.6)
    for x in (2, 42, 82):
        T.couture((x, 112.5), (x, 127.5), pas=0.9)
    T.couture((0, 126.6), (84, 126.6), pas=0.9)
    if st.get("fourrure"):
        T.zone(R_FOUR, H.fourrure(st.get("pal_fourrure", H.FOURRURE_BEIGE), g + 5, base=st.get("base_fourrure", 0.55), longueur=st.get("long_meches", 2.4), degrade=st.get("degrade_fourrure", 0.0)),
               sale=0.25, relief=0.8)
    for p in st.get("peintures", []):
        p(T, st, g)
    T.finir(g=g)
    img = T.image()
    ob = P.objet_oriente(_centre_corps, {"fourrure": lambda c: Vector((0.0, 0.0, c.z - 0.12))})
    aretes_vives(ob, 60)
    occlusion_sommets(ob, portee=0.06)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["tunique", "peau"], lisser=1)
    Wm = C.poids_transferes(ob, r, ["tunique"], os_permis={"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "clavicle_l", "clavicle_r"}, lisser=0)
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        if abs(p.x) > 0.30 and p.z > 1.28 and p.z < 1.53:
            cote = "l" if p.x > 0 else "r"
            d = {k: w for k, w in Wm[v.index].items() if k.endswith("_" + cote)}
            tot = sum(d.values())
            if tot <= 0:
                d, tot = {"upperarm_" + cote: 1.0}, 1.0
            for gg in list(ob.vertex_groups):
                gg.remove([v.index])
            for k, w in d.items():
                if k not in ob.vertex_groups:
                    ob.vertex_groups.new(name=k)
                ob.vertex_groups[k].add([v.index], w / tot, "REPLACE")
    # fourrure : jamais les os du bras (elle reste sur les épaules quand le bras se lève) -> clavicule du même côté
    if "fourrure" in P.mats:
        mi = [i for i, m in enumerate(ob.data.materials) if m.name.split(".")[0] == "fourrure" or m.name == "fourrure"]
        vf = {vi for p in ob.data.polygons if p.material_index in mi for vi in p.vertices}
        noms = {g.index: g.name for g in ob.vertex_groups}
        for vi in vf:
            v = ob.data.vertices[vi]
            d = {}
            for gg in v.groups:
                k = noms[gg.group]
                if k.startswith("upperarm_") or k.startswith("lowerarm_"):
                    k = "clavicle_" + k[-1]
                elif k == "Head":
                    k = "neck_01"
                d[k] = d.get(k, 0.0) + gg.weight
            for gg in list(v.groups):
                ob.vertex_groups[noms[gg.group]].remove([vi])
            tot = sum(d.values()) or 1.0
            for k, w in d.items():
                if k not in ob.vertex_groups:
                    ob.vertex_groups.new(name=k)
                ob.vertex_groups[k].add([vi], w / tot, "REPLACE")
    C.lier(ob, r)
    return ob


def _centre_corps(c):
    if abs(c.x) > 0.17 and c.z > 1.3 and c.z < 1.53:
        return Vector((c.x * 0.6 if abs(c.x) < 0.3 else c.x, 0.03, 1.40 if abs(c.x) < 0.3 else 1.455))
    if c.z > 1.53:
        return Vector((0.0, -0.005, max(c.z - 0.05, 1.50)))
    return Vector((0.0, -0.005, c.z))


# ======================================================================================================== GANTELETS
DOIGTS = ("index", "middle", "ring", "pinky", "thumb")


def gantelets(r, st):
    """Manchette évasée épaisse (bord roulé, doublure), dos de la main en lames qui se chevauchent, doigts : cuir à plaques de
    jointure (fer) ou phalanges d'acier articulées (acier), pouce."""
    P = PieceHD(st["id"])
    T = H.Toile(st["id"], st.get("px", 512))
    g = st.get("graine", 7)
    pal = st["pal"]
    R_MANCH, R_MAIN, R_LAMES, R_DOIGTS = (0, 0, 128, 44), (0, 44, 128, 64), (0, 64, 128, 88), (0, 88, 128, 128)
    for cote, s in COTES:
        la, ha = r.os["lowerarm_" + cote], r.os["hand_" + cote]
        avb = C.bvh(r, ["brassards", "tunique", "peau", "accessoires"], {"lowerarm_" + cote}, 0.5)
        A = la.lerp(ha, st.get("debut_manchette", 0.45))
        B = ha + (ha - la).normalized() * 0.01
        ev = st.get("evasement", 0.025)
        nm = 12
        # profil de la manchette : lèvre de doublure, bord roulé, évasement, poignet
        Pm, Rm, _ = C.tube(avb, A, B, [0.0, 0.0, 0.04, 0.46, 0.47, 0.52, 1.0], nm,
                           lambda j, i, a: (0.004 + ev, 0.018 + ev, 0.014 + ev, 0.014 + ev * 0.55, 0.009 + ev * 0.5, 0.013 + ev * 0.45, 0.012)[j],
                           r_loin=0.3, dilate=1, lisse=2)
        Pm[1] = [p + (A - B).normalized() * 0.004 for p in Pm[1]]
        P.grille_v(Pm, st["mat"], R_MANCH, vs=[0.0, 0.03, 0.08, 0.5, 0.52, 0.56, 1.0], inverser=s > 0)
        if st.get("cretes_manchette"):
            # nervures en relief le long de la manchette (acier) : deux arêtes sur le dessus
            pass
        main = C.bvh(r, ["accessoires", "peau"], {"hand_" + cote}, 0.6)
        jo = (r.os["index_01_" + cote] + r.os["pinky_01_" + cote]) / 2
        Am = ha - (jo - ha).normalized() * 0.01
        Bm = jo
        Ph, Rh, rep = C.tube(main, Am, Bm, [0.0, 0.35, 0.7, 0.97], 12, lambda j, i, a: 0.007 + (0.004 if math.sin(a) < 0 else 0.0), r_loin=0.25, dilate=1, lisse=1)
        ids = P.grille_v(Ph, st["mat_main"], R_MAIN, inverser=s > 0)
        cb = sum(Ph[-1], Vector()) / len(Ph[-1])
        ic = P.sommet(cb)
        u0, v0, u1, v1 = C.rect_uv(R_MAIN)
        for i in range(12):
            a, b = ids[-1][i], ids[-1][(i + 1) % 12]
            P.face([a, b, ic] if s < 0 else [b, a, ic], st["mat_main"], [(u0, v1), (u1, v1), ((u0 + u1) / 2, v1)])
        # lames du dos de la main : arc du dessus, chaque lame recouvre la suivante vers les doigts
        u_ax, w_ax, axe = rep
        nl = st.get("lames_main", 3)
        dos = [a for a in [math.pi + TAU * i / 12 for i in range(12)]]
        # dessus de la main = côté où sin(a) < 0 (offset plus grand) : arc de 7 angles centré dessus
        arc = [math.radians(x) for x in range(-160, -15, 24)]
        for k in range(nl):
            ta, tb = 0.05 + 0.85 * k / nl, 0.05 + 0.85 * (k + 1) / nl + 0.08

            def dec_l(j, i, a, k=k):
                return 0.013 + 0.003 * (nl - k) + (0.0, 0.002, 0.003, -0.001)[j]
            Pl, _, _ = C.tube(main, Am, Bm, [ta, ta + 0.02, tb - 0.03, tb], 0, dec_l, r_loin=0.25, dilate=1, lisse=1, angles=arc)
            hy = (R_LAMES[3] - R_LAMES[1]) / nl
            rl = (R_LAMES[0], R_LAMES[1] + hy * k, R_LAMES[2], R_LAMES[1] + hy * (k + 1))
            P.grille_v(Pl, st["mat"], rl, vs=[0.0, 0.1, 0.85, 1.0], fermer=False, inverser=s < 0)
            lip = [p + (Am.lerp(Bm, tb) - p).normalized() * 0.006 for p in Pl[-1]]
            P.grille_v([Pl[-1], lip], st["mat"], (rl[0], rl[3] - 0.5, rl[2], rl[3]), fermer=False, inverser=s < 0)
        # doigts
        for d in DOIGTS:
            chaine = [r.os["%s_0%d_%s" % (d, k, cote)] for k in (1, 2, 3)] + [r.os["%s_04_leaf_%s" % (d, cote)]]
            doigt = C.bvh(r, ["accessoires", "peau"], {"%s_0%d_%s" % (d, k, cote) for k in (1, 2, 3)}, 0.5)
            centres, rayons, reps = [], [], []
            for k, c in enumerate(chaine):
                tg = (chaine[min(k + 1, 3)] - chaine[max(k - 1, 0)]).normalized()
                u, w = C.repere(tg)
                pts = []
                for ia in range(8):
                    dd = u * math.cos(TAU * ia / 8) + w * math.sin(TAU * ia / 8)
                    hit = doigt.ray_cast(c + dd * 0.05, -dd, 0.05)
                    if hit[0] is not None:
                        pts.append(hit[0])
                cc = sum(pts, Vector()) / len(pts) if len(pts) >= 3 else c
                rr = max(((p - cc) - (p - cc).project(tg)).length for p in pts) if len(pts) >= 3 else 0.009
                rr = min(max(rr, 0.007), 0.014) * 1.2 + 0.003
                if k == 3:
                    rr *= 0.8
                centres.append(cc); rayons.append(rr); reps.append((u, w, tg))
            di = DOIGTS.index(d)
            rd = (di * 25.6, R_DOIGTS[1], di * 25.6 + 25.6, R_DOIGTS[3])
            ns = st.get("cotes_doigts", 5)
            if st.get("phalanges"):
                # acier : une plaque par phalange (tronc de cône), chacune un peu plus large que la suivante, se chevauchant
                for k in range(3):
                    c0, c1 = centres[k], centres[k + 1]
                    u, w, tg = reps[k]
                    a0 = c0 - (c1 - c0) * 0.12
                    a1 = c1 + (c1 - c0) * (0.08 if k < 2 else 0.0)
                    r0, r1 = rayons[k] * 1.12 + 0.001 * (3 - k), rayons[k + 1] * 1.0 + 0.001 * (3 - k)
                    rings = [[a + (u * math.cos(TAU * i / ns + TAU / 12) + w * math.sin(TAU * i / ns + TAU / 12)) * rr for i in range(ns)]
                             for a, rr in ((a0, r0 * 0.92), (a0.lerp(a1, 0.15), r0), (a1, r1))]
                    hy = (rd[3] - rd[1]) / 3
                    P.grille_v(rings, st["mat_doigts"], (rd[0], rd[1] + hy * k, rd[2], rd[1] + hy * (k + 1)), vs=[0.0, 0.12, 1.0], inverser=s > 0)
                ct = centres[-1]
                tip = P.sommet(ct + (chaine[-1] - chaine[-2]).normalized() * 0.010)
                last = rings[-1]
                il = [P.sommet(p) for p in last]
                for i in range(ns):
                    a, b = il[i], il[(i + 1) % ns]
                    P.face([a, b, tip] if s < 0 else [b, a, tip], st["mat_doigts"], [(C.rect_uv(rd)[0], C.rect_uv(rd)[3])] * 3)
            else:
                anneaux = []
                for k, cc in enumerate(centres):
                    u, w, tg = reps[k]
                    anneaux.append([cc + (u * math.cos(TAU * i / ns + TAU / 12) + w * math.sin(TAU * i / ns + TAU / 12)) * rayons[k] for i in range(ns)])
                idd = P.grille_v(anneaux, st["mat_doigts"], rd, inverser=s > 0)
                ct = sum(anneaux[-1], Vector()) / ns
                tip = P.sommet(ct + (chaine[-1] - chaine[-2]).normalized() * 0.008)
                for i in range(ns):
                    a, b = idd[-1][i], idd[-1][(i + 1) % ns]
                    P.face([a, b, tip] if s < 0 else [b, a, tip], st["mat_doigts"], [(C.rect_uv(rd)[0], C.rect_uv(rd)[3])] * 3)
                # plaque de jointure (fer) sur la 1re phalange : petite tuile rivetée sur le dessus
                if d != "thumb" and st.get("jointures", True):
                    c0, c1 = centres[0], centres[1]
                    u, w, tg = reps[0]
                    haut_d = -w if True else w
                    rings = []
                    for t_, e_ in ((0.1, 0.0), (0.2, 0.003), (0.85, 0.003), (0.95, 0.0)):
                        c = c0.lerp(c1, t_)
                        rr = rayons[0] + 0.001 + e_
                        rings.append([c + (u * math.cos(a) + w * math.sin(a)) * rr for a in [math.radians(x) for x in (-145, -105, -75, -35)]])
                    P.grille_v(rings, st["mat"], (rd[0], rd[3] - 6, rd[2], rd[3]), fermer=False, inverser=s < 0)
    # ================================================================ peinture
    peindre_plaque(T, R_MANCH, st, g, bas=True, haut=False, rivets=st.get("rivets_manchette", 0), rivet_y=6.0, larg_bis=2.5,
                   graver=(1, 9, 127, 19) if st.get("graver") else None)
    if st.get("main_cuir"):
        T.zone(R_MAIN, H.cuir(st.get("pal_cuir", H.CUIR), g + 1, base=0.42), sale=0.6)
        T.couture((2, 50), (126, 50), pas=1.0)
    else:
        peindre_plaque(T, R_MAIN, st, g + 1, bas=False, haut=False)
    nl = st.get("lames_main", 3)
    hy = (R_LAMES[3] - R_LAMES[1]) / nl
    for k in range(nl):
        rl = (R_LAMES[0], R_LAMES[1] + hy * k, R_LAMES[2], R_LAMES[1] + hy * (k + 1))
        peindre_plaque(T, rl, st, g + 10 + k, bas=False, haut=True, rivets=st.get("rivets_lames", 0), rivet_y=rl[3] - 2.0, larg_bis=1.0,
                       graver=(rl[0] + 30, rl[1] + 1.5, rl[2] - 30, rl[3] - 3.5) if st.get("graver") else None)
    if st.get("phalanges"):
        for di in range(5):
            for k in range(3):
                hy3 = (R_DOIGTS[3] - R_DOIGTS[1]) / 3
                rp = (di * 25.6, R_DOIGTS[1] + hy3 * k, di * 25.6 + 25.6, R_DOIGTS[1] + hy3 * (k + 1))
                peindre_plaque(T, rp, st, g + 20 + di * 3 + k, bas=True, haut=False, larg_bis=1.6)
    else:
        T.zone(R_DOIGTS, H.cuir(st.get("pal_cuir", H.CUIR), g + 2, base=0.36), sale=0.65)
        for di in range(5):
            T.couture((di * 25.6 + 2, 90), (di * 25.6 + 2, 120), pas=1.2)
            rj = (di * 25.6, R_DOIGTS[3] - 6, di * 25.6 + 25.6, R_DOIGTS[3])
            peindre_plaque(T, rj, st, g + 30 + di, bas=True, haut=True, larg_bis=0.8)
            T.rivets([(di * 25.6 + 12.8, R_DOIGTS[3] - 3)], r=0.9, pal=pal, k=0.62)
    T.finir(g=g)
    img = T.image()
    ob = P.objet_oriente(_ctr_main(r))
    aretes_vives(ob, 60)
    occlusion_sommets(ob, portee=0.025)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["accessoires", "brassards", "peau"], lisser=1, cote_strict=True,
                     os_permis={b.name for b in r.arm.data.bones if any(k in b.name for k in ("hand", "lowerarm", "index", "middle", "ring", "pinky", "thumb"))})
    C.lier(ob, r)
    return ob


def _ctr_main(r):
    def ctr(c):
        cote = "l" if c.x > 0 else "r"
        best = None
        segs = [("lowerarm_" + cote, "hand_" + cote)] + [("hand_" + cote, "middle_01_" + cote)]
        for d in DOIGTS:
            ch = ["%s_0%d_%s" % (d, k, cote) for k in (1, 2, 3)] + ["%s_04_leaf_%s" % (d, cote)]
            segs += list(zip(ch[:-1], ch[1:]))
        for a_, b_ in segs:
            a, b = r.os[a_], r.os[b_]
            ab = b - a
            t = max(0.0, min(1.0, (c - a).dot(ab) / max(ab.length_squared, 1e-9)))
            p = a + ab * t
            d2 = (c - p).length_squared
            if best is None or d2 < best[0]:
                best = (d2, p)
        return best[1]
    return ctr


# ======================================================================================================== BOTTES
GALBE = ((-0.1, 0.97), (0.03, 0.95), (0.10, 0.70), (0.20, 0.79), (0.32, 0.85), (0.42, 0.89), (0.52, 0.91), (1.0, 0.91))


def galbe(rows, table=GALBE, k=1.0):
    """Botte galbée : chaque anneau resserré autour de son centre selon sa hauteur (cheville marquée, mollet évasé)."""
    out = []
    for row in rows:
        c = sum(row, Vector()) / len(row)
        z = c.z
        f = table[-1][1]
        for (z0, f0), (z1, f1) in zip(table[:-1], table[1:]):
            if z0 <= z <= z1:
                t = (z - z0) / (z1 - z0)
                f = f0 + (f1 - f0) * t
                break
        f = 1.0 - (1.0 - f) * k
        out.append([Vector((c.x + (p.x - c.x) * f, c.y + (p.y - c.y) * f, p.z)) for p in row])
    return out


def bottes(r, st):
    """Botte ajustée (cuir, n = 16), semelle, revers ; grève épaisse à arête (fer : rivetée ; acier : nervure gravée),
    genouillère bombée à ailette, sangles à boucle (fer) ou solerets articulés sur le pied (acier)."""
    P = PieceHD(st["id"])
    T = H.Toile(st["id"], st.get("px", 512))
    g = st.get("graine", 9)
    pal = st["pal"]
    R_BOTTE, R_GREVE, R_GENOU, R_SEM, R_SANG, R_SOL = (0, 0, 128, 60), (0, 60, 64, 128), (64, 60, 128, 96), (64, 96, 96, 112), (96, 96, 128, 112), (64, 112, 96, 128)
    R_FOUR_B, R_EMBOUT = (0, 60, 64, 128), (96, 112, 128, 128)     # sans grève : la fourrure du revers prend la place de la grève
    for cote, s in COTES:
        th, ca, fo = r.os["thigh_" + cote], r.os["calf_" + cote], r.os["foot_" + cote]
        jambe = C.bvh(r, ["bottes", "pantalon"], {"calf_" + cote, "foot_" + cote, "ball_" + cote}, 0.5)
        A = Vector((ca.x, -0.015, -0.025))
        B = Vector((ca.x, ca.y, ca.z))
        zs = st.get("niveaux", [-0.02, 0.0, 0.04, 0.10, 0.20, 0.32, 0.42, 0.50])
        zh = st.get("haut", 0.50)
        zs = [z for z in zs if z <= zh]
        n = st.get("n", 12)

        def dec(j, i, a):
            return 0.008 + (0.004 if j >= len(zs) - 1 else 0.0) + (0.002 if j == 1 else 0.0)
        Pb, Rb, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in zs], n, dec, r_loin=0.4, dilate=1, lisse=2)
        Pb = galbe(Pb)
        Pb[0] = [Vector((p.x, p.y, -0.022)) for p in Pb[0]]
        Pb[1] = [Vector((p.x, p.y, -0.006)) + (p - Vector((ca.x, p.y, p.z))).normalized() * 0.003 for p in Pb[1]]
        angs = [math.pi + TAU * i / n for i in range(n)]
        for jj, kz in ((len(Pb) - 1, 0.10), (len(Pb) - 2, 0.04)):
            Pb[jj] = [p - Vector((0, 0, kz * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Pb[jj], angs)]
        MB = st.get("mat_botte", "cuir")
        vs = [(z - zs[0]) / (zs[-1] - zs[0]) for z in zs]
        ids = P.grille_v(Pb, MB, R_BOTTE, vs=vs)
        c0 = sum(Pb[0], Vector()) / n
        ic = P.sommet(c0)
        u0, v0, u1, v1 = C.rect_uv(R_SOL)
        for i in range(n):
            a, b = ids[0][i], ids[0][(i + 1) % n]
            P.face([b, a, ic], "cuir", [(u0, v0), (u1, v0), ((u0 + u1) / 2, v1)])
        # semelle épaisse : talon / bord (anneau un peu plus large juste au-dessus du sol)
        for i in ids[0]:
            P.ao[i] = 0.55
        # revers rabattu du haut de la tige (épaisseur + bande)
        top = Pb[-1]
        ctop = Vector((B.x, B.y, 0))
        rv_out = [p + (Vector((p.x, p.y, 0)) - Vector((ca.x, B.y if p.z > 0.2 else p.y, 0))).normalized() * 0.008 + Vector((0, 0, 0.004)) for p in top]
        rv_bas = [p + (Vector((p.x, p.y, 0)) - Vector((ca.x, B.y if p.z > 0.2 else p.y, 0))).normalized() * 0.010 - Vector((0, 0, st.get("revers_h", 0.045))) for p in top]
        rv_in = [p + (Vector((ca.x, B.y if p.z > 0.2 else p.y, p.z)) - p).normalized() * 0.010 for p in top]
        if not st.get("revers_fourrure"):
            P.grille_v([rv_bas, rv_out], MB, R_SEM, fermer=True)
            P.grille_v([rv_out, top], MB, (R_SEM[0], R_SEM[3] - 1, R_SEM[2], R_SEM[3]))
        P.grille_v([top, rv_in], MB, (R_SEM[0], R_SEM[1], R_SEM[2], R_SEM[1] + 1))
        # sangles en relief (fer) : bandes autour de la cheville et du mollet
        for zz in st.get("sangles", ()):
            Ps, _, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in (zz - 0.013, zz, zz + 0.013)], n,
                              lambda j, i, a: 0.008 + (0.001, 0.005, 0.001)[j], r_loin=0.4, dilate=1, lisse=2)
            Ps = galbe(Ps)
            P.grille_v(Ps, "cuir", R_SANG, vs=[0.0, 0.5, 1.0])
            # boucle sur le côté extérieur
            ib = int(round((math.pi / 2 * s + math.pi) / TAU * n)) % n
            pb = Ps[1][ib]
            nrm = (pb - Vector((ca.x, ca.y, pb.z))).normalized()
            tgt = Vector((0, 0, 1)).cross(nrm).normalized()
            q = [pb + tgt * x + Vector((0, 0, z)) + nrm * 0.001 for (x, z) in ((-0.012, -0.011), (0.012, -0.011), (0.012, 0.011), (-0.012, 0.011))]
            P.boite(q + [p + nrm * 0.004 for p in q], st["mat"], (R_SANG[0], R_SANG[1], R_SANG[0] + 6, R_SANG[3]))
        if st.get("solerets"):
            # solerets : lames articulées sur le dessus du pied, de la cheville aux orteils (chacune recouvre la suivante)
            pied = C.bvh(r, ["bottes"], {"foot_" + cote, "ball_" + cote}, 0.3)
            arc = [math.radians(x) for x in range(-80, 81, 32)]
            Af = Vector((ca.x, 0.04, 0.035)); Bf = Vector((ca.x, -0.15, 0.025))
            nls = 4
            for k in range(nls):
                ta, tb = k / nls * 0.92, (k + 1) / nls * 0.92 + 0.07

                def dec_s(j, i, a, k=k):
                    return 0.028 - 0.002 * k + (0.0, 0.003, 0.003, -0.002)[j]
                Ps, _, _ = C.tube(jambe, Af, Bf, [ta, ta + 0.03, tb - 0.04, tb], 0, dec_s, r_loin=0.3, dilate=1, lisse=1, angles=[a + math.pi / 2 for a in arc])
                hy = (R_GENOU[3] - R_GENOU[1]) / 2 / nls
                rs = (R_GENOU[0], R_GENOU[1] + (R_GENOU[3] - R_GENOU[1]) / 2 + hy * k, R_GENOU[2], R_GENOU[1] + (R_GENOU[3] - R_GENOU[1]) / 2 + hy * (k + 1))
                P.grille_v(Ps, st["mat"], rs, vs=[0.0, 0.1, 0.85, 1.0], fermer=False, inverser=True)
        if st.get("revers_fourrure"):
            # revers de fourrure sous la genouillère : boudin hirsute au haut de la tige, mèches qui retombent
            zr = zs[-1]
            ep = st.get("ep_revers", 1.0)
            Pr, _, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in (zr - 0.075, zr - 0.035, zr + 0.008, zr + 0.016)], n,
                              lambda j, i, a: ((0.016, 0.034, 0.024, 0.012)[j] * ep + 0.006 * (C._h(i, j, 5) - 0.5))
                              * (0.6 if abs(math.sin(a) + (1 if cote == "l" else -1)) < 0.5 else 1.0), r_loin=0.4, dilate=0, lisse=1)
            Pr = galbe(Pr, k=0.8)
            for jj, kz in ((2, 0.10), (3, 0.10), (1, 0.04)):
                Pr[jj] = [p - Vector((0, 0, kz * max(0.0, -math.cos(a)) ** 1.5)) for p, a in zip(Pr[jj], angs)]
            P.grille_v(Pr, "fourrure", R_FOUR_B, vs=[0.0, 0.4, 0.85, 1.0])
            for i in range(n):
                a_, b_ = Pr[1][i], Pr[1][(i + 1) % n]
                m = (a_ + b_) / 2 + Vector((0, 0, -0.03 - 0.025 * C._h(i, 1, 9))) + ((a_ + b_) / 2 - Vector((B.x, B.y, a_.z))).normalized() * 0.008
                ia, ib, im = P.sommet(a_, 0.85), P.sommet(b_, 0.85), P.sommet(m, 0.6)
                u0, v0, u1, v1 = C.rect_uv(R_FOUR_B)
                P.face([ia, ib, im], "fourrure", [(u0, v1), (u1, v1), ((u0 + u1) / 2, v0)])
        if st.get("embout"):
            # embout d'acier sur les orteils (coque bombée sur le dessus du pied)
            arc_e = [math.radians(x) for x in range(-70, 71, 28)]
            Ae = Vector((ca.x, -0.06, 0.035)); Be = Vector((ca.x, -0.17, 0.02))
            Pe, _, _ = C.tube(jambe, Ae, Be, [0.0, 0.08, 0.6, 1.0], 0, lambda j, i, a: 0.006 + (0.0, 0.003, 0.004, 0.002)[j], r_loin=0.3, dilate=1,
                              lisse=1, angles=[a + math.pi / 2 for a in arc_e])
            P.grille_v(Pe, st["mat"], R_EMBOUT, vs=[0.0, 0.1, 0.7, 1.0], fermer=False, inverser=True)
        if st.get("greve") is False:
            genou_seul = True
        else:
            genou_seul = False
        # grève : coque devant le tibia, arête centrale, tranches latérales épaisses
        if not genou_seul:
            arc = [math.radians(x) for x in range(-84, 85, 21)]
            z0, z1 = st.get("greve", (0.10, 0.45))
            arete = st.get("arete", 0.006)

            def dec_g(j, i, a):
                return 0.024 + 0.006 * math.cos(a) + arete * max(0.0, 1.0 - abs(a) / math.radians(30)) + (0.003 if j in (1, 3) else 0.0) * 0
            zg = [z0, z0 + 0.012, (z0 + z1) / 2, z1 - 0.012, z1]
            Pg, Rg, _ = C.tube(jambe, A, B, [(z - A.z) / (B.z - A.z) for z in zg], 0, dec_g, r_loin=0.4, dilate=0, lisse=1, angles=arc)
            # bords haut et bas roulés vers l'extérieur
            Pg[0] = [p + (p - Vector((ca.x, ca.y, p.z))).normalized() * 0.003 for p in Pg[0]]
            Pg[-1] = [p + (p - Vector((ca.x, ca.y, p.z))).normalized() * 0.003 for p in Pg[-1]]
            P.grille_v(Pg, st["mat"], R_GREVE, vs=[0.0, 0.05, 0.5, 0.95, 1.0], fermer=False, inverser=True)
            for col_i, rect_tr in ((0, (0, 60, 1, 128)), (-1, (63, 60, 64, 128))):
                bord = [row[col_i] for row in Pg]
                tr = [p + (Vector((ca.x, ca.y, p.z)) - p).normalized() * 0.010 for p in bord]
                P.grille_v([bord, tr] if col_i == 0 else [tr, bord], st["mat"], rect_tr, fermer=False)
            for row_i in (0, -1):
                bord = Pg[row_i]
                tr = [p + (Vector((ca.x, ca.y, p.z)) - p).normalized() * 0.010 for p in bord]
                P.grille_v([bord, tr] if row_i == -1 else [tr, bord], st["mat"], (0, 60, 64, 61), fermer=False, inverser=True)
        # genouillère : coque bombée + ailette extérieure
        genou = C.bvh(r, ["pantalon"], {"calf_" + cote, "thigh_" + cote}, 0.3)
        Kc = Vector((ca.x, ca.y, ca.z))
        aile = st.get("ailette", 0.0)
        angs_k = [math.radians(x) for x in range(-84, 85, 21)]

        def dec_k(j, i, a):
            b = 0.026 + 0.018 * math.sin(math.pi * j / 4) * max(0.0, math.cos(a)) ** 0.7
            # ailette sur le côté extérieur (a > 0 côté +x pour la gauche)
            ext = max(0.0, math.sin(a) * s)
            return b + aile * ext ** 2 * math.sin(math.pi * j / 4)
        Pk, Rk, _ = C.tube(genou, Kc + Vector((0, 0, -0.05)), Kc + Vector((0, 0, 0.065)), [0.0, 0.25, 0.5, 0.75, 1.0], 0, dec_k,
                           r_loin=0.4, dilate=1, lisse=1, angles=angs_k)
        P.grille_v(Pk, st["mat_genou"], (R_GENOU[0], R_GENOU[1], R_GENOU[2], R_GENOU[1] + (R_GENOU[3] - R_GENOU[1]) / 2), fermer=False, inverser=True)
        for row_i in (0, -1):
            bord = Pk[row_i]
            tr = [p + (Kc - p).normalized() * 0.008 for p in bord]
            P.grille_v([bord, tr] if row_i == -1 else [tr, bord], st["mat_genou"], (R_GENOU[0], R_GENOU[1], R_GENOU[2], R_GENOU[1] + 0.6), fermer=False, inverser=True)
    # ================================================================ peinture
    if st.get("mat_botte", "cuir") == "cuir":
        T.zone(R_BOTTE, H.cuir(st.get("pal_cuir", H.CUIR), g, base=st.get("base_cuir", 0.38)), sale=0.75)
        for x in (32, 96):
            T.couture((x, 2), (x, 58), pas=1.0)
        T.couture((1, 3.5), (127, 3.5), pas=1.0)
    else:
        peindre_plaque(T, R_BOTTE, st, g, bas=False, haut=False)
    T.zone(R_SEM, H.cuir(st.get("pal_cuir", H.CUIR), g + 3, base=0.30), sale=0.6)
    T.couture((65, 98), (95, 98), pas=0.8)
    T.zone(R_SOL, H.cuir(H.CUIR_NOIR, g + 4, base=0.25), sale=0.9)
    T.zone(R_SANG, H.cuir(st.get("pal_cuir", H.CUIR), g + 5, base=0.30), sale=0.6)
    T.biseau(R_SANG, larg=1.0, haut=0.2, cotes="bh", poli=0.2)
    peindre_plaque(T, (R_SANG[0], R_SANG[1], R_SANG[0] + 6, R_SANG[3]), st, g + 6, larg_bis=1.0)
    if st.get("greve") is not False:
        peindre_plaque(T, R_GREVE, st, g + 1, bas=True, haut=True, larg_bis=2.0, graver=(26, 66, 38, 122) if st.get("graver") else None)
        T.biseau(R_GREVE, larg=2.5, haut=0.35, cotes="gd", poli=0.8)
    else:
        T.zone(R_FOUR_B, H.fourrure(st.get("pal_fourrure", H.FOURRURE_BEIGE), g + 1, base=st.get("base_fourrure", 0.55), longueur=2.0), sale=0.3, relief=0.8)
    if st.get("embout"):
        peindre_plaque(T, R_EMBOUT, st, g + 7, bas=True, haut=True, larg_bis=1.5, rivets=4 if st.get("rivets_greve") else 0, rivet_y=R_EMBOUT[1] + 3)
    if st.get("rivets_greve") and st.get("greve") is not False:
        T.rivets([(4, y) for y in range(66, 126, 8)] + [(60, y) for y in range(66, 126, 8)], r=0.85, pal=pal, k=0.62, rouille=st.get("rouille", 0) * 0.5)
    if st.get("graver") and st.get("greve") is not False:
        # nervure centrale gravée (deux filets) : la grève est vue de face
        T.ligne_v(31, 62, 126, larg=0.35, prof=0.2); T.ligne_v(33, 62, 126, larg=0.35, prof=0.2)
    hk = (R_GENOU[3] - R_GENOU[1]) / 2
    peindre_plaque(T, (R_GENOU[0], R_GENOU[1], R_GENOU[2], R_GENOU[1] + hk), st, g + 2, bas=True, haut=True, larg_bis=2.0,
                   rivets=4 if st.get("rivets_greve") else 0, rivet_y=R_GENOU[1] + hk - 3,
                   graver=(R_GENOU[0] + 6, R_GENOU[1] + 4, R_GENOU[2] - 6, R_GENOU[1] + 10) if st.get("graver") else None)
    if st.get("solerets"):
        nls = 4
        for k in range(nls):
            hy = hk / nls
            rs = (R_GENOU[0], R_GENOU[1] + hk + hy * k, R_GENOU[2], R_GENOU[1] + hk + hy * (k + 1))
            peindre_plaque(T, rs, st, g + 50 + k, bas=False, haut=True, larg_bis=1.0)
    T.finir(g=g)
    img = T.image()
    ob = P.objet_oriente(_ctr_jambe(r))
    aretes_vives(ob, 60)
    occlusion_sommets(ob, portee=0.04)
    C.appliquer_materiaux(ob, P, img)
    C.peau_transfert(ob, r, ["bottes", "pantalon"], lisser=1, cote_strict=True,
                     os_permis={b.name for b in r.arm.data.bones if any(k in b.name for k in ("calf", "foot", "ball", "thigh"))})
    C.lier(ob, r)
    return ob


def _ctr_jambe(r):
    def ctr(c):
        cote = "l" if c.x > 0 else "r"
        ca = r.os["calf_" + cote]
        if c.z < 0.12:
            return Vector((ca.x, -0.02 if c.y < -0.02 else c.y * 0.5, max(c.z - 0.02, 0.02)))
        return Vector((ca.x, ca.y if c.z > 0.2 else 0.02, c.z))
    return ctr
