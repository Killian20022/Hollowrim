# PIÈCES ARTICULÉES des armures lourdes (passe 2 « géométrie », 2026-11-11) : vraies plaques superposées posées SUR la pièce existante.
#  - coque_membre() : une plaque enroulée autour d'un segment d'os (A -> B), entre deux abscisses (m) et deux angles, à `decalage`
#    au-dessus de ce qui est déjà là (corps + armure, mesuré par lancer de rayons), bombée, bord inférieur évasé (lame qui recouvre
#    la suivante) ; UV pris dans l'îlot de la plaque existante la plus proche (même peinture / même cuisson) ;
#  - épaulières à lames étagées, couters (cubitière + ailette), genouillères à ailettes, tassettes en lames, gorgerin ;
#  - peau d'os : poids écrits par plaque (ex. couter 50 % bras / 50 % avant-bras : la plaque suit le coude à mi-angle, rigide) ;
#  - l'épaisseur et les rivets viennent ensuite de relief.relief() (bordures roulées) : appeler relief APRÈS ces ajouts.
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

EXCLURE_BVH = ("fourrure",)


def _bvh_ob(ob, exclure=EXCLURE_BVH):
    me = ob.data
    mw = ob.matrix_world
    mats = [m.name if m else "" for m in me.materials]
    vs = [mw @ v.co for v in me.vertices]
    fs = [list(p.vertices) for p in me.polygons if not any(x in mats[p.material_index] for x in exclure)]
    return BVHTree.FromPolygons(vs, fs)


def _repere(axe, ref):
    axe = axe.normalized()
    u = ref - axe * ref.dot(axe)
    u.normalize()
    w = axe.cross(u)
    return axe, u, w


class Contexte:
    """Prépare les arbres (corps, armure en cours) et les îlots UV de la pièce."""

    def __init__(self, ob, r, arbre_corps):
        self.ob, self.r = ob, r
        self.arbres = [arbre_corps, _bvh_ob(ob)]
        me = ob.data
        self.mats = [m.name if m else "" for m in me.materials]
        bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
        self.uv_noms = list(me.uv_layers.keys())
        # îlots : composantes de faces de même matériau
        lay = [bm.loops.layers.uv[n] for n in self.uv_noms]
        vu, self.ilots = set(), []
        for f in bm.faces:
            if f.index in vu:
                continue
            pile, comp = [f], []
            vu.add(f.index)
            while pile:
                x = pile.pop(); comp.append(x)
                for e in x.edges:
                    for y in e.link_faces:
                        if y.index not in vu and y.material_index == f.material_index:
                            vu.add(y.index); pile.append(y)
            ctr = sum((x.calc_center_median() for x in comp), Vector()) / len(comp)
            bb = []
            for L in lay:
                us = [l[L].uv for x in comp for l in x.loops]
                bb.append((min(u.x for u in us), min(u.y for u in us), max(u.x for u in us), max(u.y for u in us)))
            aire = sum(x.calc_area() for x in comp)
            self.ilots.append(dict(mat=f.material_index, centre=ob.matrix_world @ ctr, bb=bb, aire=aire,
                                   pts=[ob.matrix_world @ x.calc_center_median() for x in comp[::max(1, len(comp) // 12)]]))
        bm.free()

    def ilot_proche(self, p, mat_prefixes, aire_min=0.004):
        best, dbest = None, 1e9
        for il in self.ilots:
            if il["aire"] < aire_min or not any(self.mats[il["mat"]].startswith(m) for m in mat_prefixes):
                continue
            d = min((q - p).length for q in il["pts"])
            if d < dbest:
                best, dbest = il, d
        return best

    def rayon(self, p, d, r_def, portee=0.3):
        best = None
        for a in self.arbres:
            h = a.ray_cast(p + d * portee, -d, portee)
            if h[0] is not None:
                rr = (h[0] - p).length
                best = rr if best is None else max(best, rr)
        return r_def if best is None else best


def coque_membre(cx, A, B, t0, t1, a0, a1, ref, nt=4, na=7, decalage=0.016, bombe=0.008, evase=0.006, poids=None,
                 mats=("acier", "fer", "obsidienne", "or"), r_def=0.07, lisse=2, r_min=0.0, profil=None, uv_inset=0.12, rayon_fixe=None, portee=0.3):
    """Ajoute à cx.ob une plaque enroulée : abscisses t0..t1 (m depuis A le long de A->B), angles a0..a1 (degrés, 0 = `ref`).
    poids(t, a) -> {os: poids} ; profil(s, q) -> rayon additionnel (s, q dans [0, 1]) ; renvoie le nombre de tris ajoutés."""
    axe, u, w = _repere(B - A, ref)
    ts = [t0 + (t1 - t0) * j / (nt - 1) for j in range(nt)]
    angs = [math.radians(a0 + (a1 - a0) * i / (na - 1)) for i in range(na)]
    R = []
    for t in ts:
        p = A + axe * t
        row = []
        for a in angs:
            d = u * math.cos(a) + w * math.sin(a)
            row.append(rayon_fixe if rayon_fixe else cx.rayon(p, d, r_def, portee))
        R.append(row)
    # lissage + enveloppe : la plaque est rigide, elle ne suit pas chaque creux
    for _ in range(lisse):
        R2 = [row[:] for row in R]
        for j in range(nt):
            for i in range(na):
                vois = [R[j][i]]
                if i > 0: vois.append(R[j][i - 1])
                if i < na - 1: vois.append(R[j][i + 1])
                if j > 0: vois.append(R[j - 1][i])
                if j < nt - 1: vois.append(R[j + 1][i])
                R2[j][i] = max(R[j][i], sum(vois) / len(vois))
        R = R2
    il = cx.ilot_proche(A + axe * (t0 + t1) / 2 + u * 0.08, mats) or cx.ilot_proche(A, mats, 0.0)
    me = cx.ob.data
    mi = cx.ob.matrix_world.inverted()
    bm = bmesh.new(); bm.from_mesh(me)
    dl = bm.verts.layers.deform.verify()
    gidx = {g.name: g.index for g in cx.ob.vertex_groups}
    V = []
    for j, t in enumerate(ts):
        s = j / (nt - 1)
        p = A + axe * t
        row = []
        for i, a in enumerate(angs):
            q = i / (na - 1)
            d = u * math.cos(a) + w * math.sin(a)
            rr = max(R[j][i], r_min) + decalage + bombe * math.sin(math.pi * q) * (0.6 + 0.4 * math.sin(math.pi * s)) + evase * s * s
            if profil:
                rr += profil(s, q)
            v = bm.verts.new(mi @ (p + d * rr))
            pw = poids(t, math.degrees(a)) if poids else {}
            for nom, wgt in pw.items():
                if nom not in gidx:
                    gidx[nom] = cx.ob.vertex_groups.new(name=nom).index
                v[dl][gidx[nom]] = wgt
            row.append(v)
        V.append(row)
    lays = [bm.loops.layers.uv[n] for n in cx.uv_noms]
    col = list(bm.loops.layers.float_color.values()) + list(bm.loops.layers.color.values())
    n0 = 0
    for j in range(nt - 1):
        for i in range(na - 1):
            q = [V[j][i], V[j][i + 1], V[j + 1][i + 1], V[j + 1][i]]
            f = bm.faces.new(q)
            f.material_index = il["mat"] if il else 0
            f.smooth = True
            f.normal_update()
            c = sum((x.co for x in q), Vector()) / 4
            # face tournée vers l'extérieur du membre
            if f.normal.dot(c - (mi @ (A + axe * ((ts[j] + ts[j + 1]) / 2)))) < 0:
                f.normal_flip()
            for l in f.loops:
                jj = next(k for k in range(nt) if l.vert in V[k])
                ii = V[jj].index(l.vert)
                for L, bb in zip(lays, il["bb"] if il else [(0, 0, 1, 1)] * len(lays)):
                    x0, y0, x1, y1 = bb
                    dx, dy = (x1 - x0) * uv_inset, (y1 - y0) * uv_inset
                    l[L].uv = (x0 + dx + (x1 - x0 - 2 * dx) * ii / (na - 1), y0 + dy + (y1 - y0 - 2 * dy) * (1 - jj / (nt - 1)))
                for C in col:
                    try:
                        l[C] = (1.0, 1.0, 1.0, 1.0)
                    except Exception:
                        pass
            n0 += 2
    bm.to_mesh(me); bm.free(); me.update()
    return n0


# ------------------------------------------------------------------------------------------------ pièces par région
def _p(**kw):
    return lambda t, a: kw


def epaulieres(cx, lames=3, dome=(-0.07, 0.085), angles=(-112, 112), dec=0.020, pas=0.055, recouvre=0.016, bombe=0.012,
               evase=0.008, na=9, nt_dome=5, mats=("acier", "fer", "obsidienne", "or"), arete=0.0):
    """Dôme d'épaule + lames étagées qui descendent le bras ; la lame du dessus recouvre celle du dessous."""
    r = cx.r
    n = 0
    for s, cote in ((1, "l"), (-1, "r")):
        A, B = r.os["upperarm_" + cote], r.os["lowerarm_" + cote]
        haut = Vector((0, 0, 1))
        prof = (lambda s_, q: arete * max(0.0, 1 - abs(q - 0.5) * 6)) if arete else None

        def pd(t, a, cote=cote):
            k = max(0.0, min(1.0, (t + 0.02) / 0.06))
            return {"clavicle_" + cote: 0.45 * (1 - k), "upperarm_" + cote: 0.55 + 0.45 * k}
        n += coque_membre(cx, A, B, dome[0], dome[1], angles[0], angles[1], haut, nt=nt_dome, na=na, decalage=dec + lames * 0.004,
                          bombe=bombe, evase=evase, poids=pd, mats=mats, profil=prof)
        for k in range(lames):
            t0 = dome[1] - recouvre + k * pas
            t1 = t0 + pas + recouvre
            a0, a1 = angles[0] + 8 + 6 * k, angles[1] - 8 - 6 * k
            n += coque_membre(cx, A, B, t0, t1, a0, a1, haut, nt=2, na=na, decalage=dec + (lames - k - 1) * 0.004, bombe=bombe * 0.6,
                              evase=evase, poids=_p(**{"upperarm_" + cote: 1.0}), mats=mats, profil=prof)
    return n


def couters(cx, dec=0.016, bombe=0.014, aile=True, mats=("acier", "fer", "obsidienne", "or"), taille=1.0, na=7):
    """Cubitière bombée à l'arrière du coude + ailette en éventail côté extérieur ; 50/50 bras/avant-bras."""
    r = cx.r
    n = 0
    for cote in ("l", "r"):
        A, B = r.os["lowerarm_" + cote], r.os["hand_" + cote]
        pw = _p(**{"upperarm_" + cote: 0.5, "lowerarm_" + cote: 0.5})
        dos = Vector((0, 1, 0))
        n += coque_membre(cx, A, B, -0.055 * taille, 0.055 * taille, -85, 85, dos, nt=4, na=na, decalage=dec, bombe=bombe, evase=0.0, portee=0.15,
                          poids=pw, mats=mats, profil=lambda s, q: 0.010 * math.sin(math.pi * s) * math.sin(math.pi * q))
        if aile:
            # ailette : côté extérieur (vers le haut en pose T = vers l'extérieur bras baissé), évasée vers l'extérieur
            g = cote == "l"
            a0, a1 = (55, 108) if g else (-108, -55)
            n += coque_membre(cx, A, B, -0.045 * taille, 0.045 * taille, a0, a1, dos, nt=3, na=4, decalage=dec + 0.004, portee=0.15,
                              bombe=0.004, evase=0.0, poids=pw, mats=mats,
                              profil=(lambda s, q: 0.022 * q * math.sin(math.pi * s)) if g else (lambda s, q: 0.022 * (1 - q) * math.sin(math.pi * s)))
    return n


def genouilleres(cx, dec=0.016, bombe=0.014, aile=True, mats=("acier", "fer", "obsidienne", "or"), taille=1.0, na=7):
    """Genouillère bombée + ailette extérieure ; 50/50 cuisse/mollet."""
    r = cx.r
    n = 0
    for s, cote in ((1, "l"), (-1, "r")):
        A, B = r.os["calf_" + cote], r.os["foot_" + cote]
        pw = _p(**{"thigh_" + cote: 0.5, "calf_" + cote: 0.5})
        devant = Vector((0, -1, 0))
        n += coque_membre(cx, A, B, -0.065 * taille, 0.06 * taille, -78, 78, devant, nt=4, na=na, decalage=dec, bombe=bombe, evase=0.0, portee=0.14,
                          poids=pw, mats=mats, profil=lambda s_, q: 0.012 * math.sin(math.pi * s_) * math.sin(math.pi * q))
        if aile:
            # ailette côté extérieur (+X à gauche, -X à droite) : angle mesuré depuis l'avant, positif vers -X x devant... on teste les deux
            a0, a1 = (70, 118) if s < 0 else (-118, -70)
            n += coque_membre(cx, A, B, -0.05 * taille, 0.05 * taille, a0, a1, devant, nt=3, na=4, decalage=dec + 0.006, portee=0.14,
                              bombe=0.004, evase=0.0, poids=pw, mats=mats,
                              profil=(lambda s_, q: 0.024 * q * math.sin(math.pi * s_)) if s < 0 else (lambda s_, q: 0.024 * (1 - q) * math.sin(math.pi * s_)))
    return n


def tassettes(cx, lames=3, t0=0.02, pas=0.06, angles=(-35, 95), dec=0.022, recouvre=0.014, mats=("acier", "fer", "obsidienne", "or"), na=7):
    """Tassettes en lames sur le haut des cuisses (devant + côté), du bassin vers la cuisse : la plaque suit la jambe (pas de
    traversée à la marche)."""
    r = cx.r
    n = 0
    for s, cote in ((1, "l"), (-1, "r")):
        A, B = r.os["thigh_" + cote], r.os["calf_" + cote]
        devant = Vector((0, -1, 0))
        a0, a1 = (angles[0], angles[1]) if s < 0 else (-angles[1], -angles[0])
        for k in range(lames):
            ta = t0 + k * pas - recouvre
            tb = ta + pas + recouvre
            kk = (k + 0.5) / lames

            def pw(t, a, cote=cote, kk=kk):
                return {"pelvis": 0.55 * (1 - kk), "thigh_" + cote: 0.45 + 0.55 * kk}
            n += coque_membre(cx, A, B, ta, tb, a0, a1, devant, nt=2, na=na, decalage=dec + (lames - k - 1) * 0.004, bombe=0.006, portee=0.2,
                              evase=0.006, poids=pw, mats=mats)
    return n


def gorgerin(cx, lames=2, dec=0.012, mats=("acier", "fer", "obsidienne", "or"), z0=1.47, pas=0.03, na=12):
    """Lames de gorgerin autour du cou, la plus basse dessus (recouvre la suivante)."""
    r = cx.r
    A = Vector((0, r.os["neck_01"].y, z0 - 0.05))
    B = Vector((0, r.os["Head"].y, r.os["Head"].z))
    n = 0
    devant = Vector((0, -1, 0))
    for k in range(lames):
        ta = 0.05 + k * pas - 0.008
        tb = ta + pas + 0.008
        n += coque_membre(cx, A, B, ta, tb, -180, 180, devant, nt=2, na=na, decalage=dec + (lames - k - 1) * 0.004, bombe=0.0,
                          evase=-0.004, poids=_p(neck_01=0.6, spine_03=0.4), mats=mats, lisse=1)
    return n


def crete(ob, centre, h=0.012, larg=0.006, th0=25, th1=165, n=15, dents=0, h_bout=0.003, decal=0.0):
    """Crête sagittale du front à la nuque, posée sur la coque du casque (lancer de rayons sur la pièce elle-même) ; section en
    trapèze fermée ; UV / peau d'os pris sur la face touchée. dents : une dent sur `dents` pas (0 = crête lisse)."""
    me = ob.data
    arbre = _bvh_ob(ob, exclure=("maille",))
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table(); bm.verts.ensure_lookup_table()
    lays = [bm.loops.layers.uv[k] for k in me.uv_layers.keys()]
    devant, haut, gauche = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
    rangs = []
    src = None
    for k in range(n):
        th = math.radians(th0 + (th1 - th0) * k / (n - 1))
        d = (devant * math.cos(th) + haut * math.sin(th)).normalized()
        hit = arbre.ray_cast(centre + d * 0.4, -d, 0.4)
        if hit[0] is None:
            continue
        if src is None or k == n // 2:
            src = bm.faces[hit[2]]
        s = k / (n - 1)
        hh = h * math.sin(math.pi * (0.1 + 0.8 * s)) + h_bout
        if dents and k % dents == 1:
            hh += h * 0.8
        base = hit[0] - d * 0.002 + d * decal
        rangs.append([base + gauche * larg, base + gauche * larg * 0.55 + d * hh, base - gauche * larg * 0.55 + d * hh,
                      base - gauche * larg])
    if len(rangs) < 3 or src is None:
        bm.free(); return 0
    vex = max(src.verts, key=lambda v: len(v.link_faces))
    V = [[bm.verts.new(p, vex) for p in row] for row in rangs]
    nb = 0

    def face(q):
        nonlocal nb
        try:
            f = bm.faces.new(q, src)
        except ValueError:
            return
        f.smooth = False
        for l in f.loops:
            for L in lays:
                l[L].uv = src.loops[0][L].uv.copy()
        nb += len(q) - 2
    for j in range(len(V) - 1):
        for i in range(3):
            face([V[j][i], V[j + 1][i], V[j + 1][i + 1], V[j][i + 1]])
    face(list(reversed(V[0])))
    face(V[-1])
    bm.normal_update()
    bm.to_mesh(me); bm.free(); me.update()
    return nb
