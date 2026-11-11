"""RELIEF des armures maison (passe 2 « géométrie », 2026-11-11 : atteindre le niveau de détail des armures Tripo importées).

La passe 1 n'avait changé que les volumes et les textures ; ici on ajoute de la GÉOMÉTRIE, en post-traitement d'une pièce déjà
construite (poids d'os, découpes de démembrement et coque de base INCHANGÉS : tout le relief part VERS L'EXTÉRIEUR) :
  - sertir()   : panneau de cristal SERTI en volume : cadre de métal en saillie (biseau montant, plat, gorge), puis cristal
                 facetté en pyramide basse (arête/pointe au centre, pans plats sous ombrage plat) ;
  - rivets()   : têtes de rivet (cône à 6 pans) aux coins des cadres ;
  - ourler()   : bord épais des pans souples (cuir) : les bords libres sont repliés vers le corps (épaisseur visible) ;
  - nervurer() : bourrelet / lanière en relief sur une bande de faces choisie (inset + saillie) ;
  - meches()   : mèches de fourrure en volume (petites lames triangulaires) le long d'un bord.
Chaque fonction prend l'objet Blender et une clé de face (couche « partie » si elle existe, sinon index de matériau). Les sommets créés
héritent des poids d'os des sommets d'origine (bmesh copie la couche de déformation ; les îles rapportées copient le sommet le plus
proche). Lancer APRÈS resserrer.py (sinon la compression écrase le relief) et AVANT la cuisson de texture."""
import bmesh, math
from mathutils import Vector
from mathutils.kdtree import KDTree


# ------------------------------------------------------------------------------------------------ accès aux faces
class Cle:
    def __init__(self, bm):
        self.bm = bm
        self.lay = bm.faces.layers.int.get("partie")

    def get(self, f):
        return f[self.lay] if self.lay is not None else f.material_index

    def set(self, f, v):
        if self.lay is not None:
            f[self.lay] = v
        else:
            f.material_index = v


def _ouvrir(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    return bm


def _fermer(bm, ob):
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def _regions(faces):
    """Composantes connexes (par arête) d'un ensemble de faces."""
    reste = set(faces)
    out = []
    while reste:
        f0 = reste.pop()
        pile, reg = [f0], [f0]
        while pile:
            f = pile.pop()
            for e in f.edges:
                for g in e.link_faces:
                    if g in reste:
                        reste.discard(g)
                        pile.append(g)
                        reg.append(g)
        out.append(reg)
    return out


def _bord(reg):
    s = set(reg)
    return [e for f in reg for e in f.edges if sum(1 for g in e.link_faces if g in s) == 1]


def _dehors(f, centre_fn):
    """Cosinus entre la normale de la face et la direction corps -> face (centre_fn(p) = point du corps le plus proche)."""
    c = f.calc_center_median()
    o = centre_fn(c)
    if o is None:
        return 1.0
    d = c - o
    if d.length < 1e-6:
        return 1.0
    return f.normal.dot(d.normalized())


def corps_proche(bvh):
    """centre_fn depuis un BVHTree du corps (repère Blender de la pièce)."""
    def fn(p):
        h = bvh.find_nearest(p, 0.5)
        return h[0]
    return fn


# ------------------------------------------------------------------------------------------------ sertissage des panneaux
def sertir(ob, cristal, cadre, largeur=0.008, saillie=0.0022, bombe=0.005, gorge=0.0, centre_fn=None, dehors_min=0.25,
           aire_min=0.0006, rivet=None, rivet_aire=0.0035, anneaux=2, rivets_max=4, facettes=True, verbeux=True):
    """cristal : ensemble de clés de face à sertir ; cadre : clé posée sur l'anneau de métal (ou fonction clé_cristal -> clé).
    Par panneau (composante connexe des faces de cristal tournées vers l'extérieur) : 3 encarts (cadre montant / plat du cadre /
    gorge), puis cristal en pyramide basse. rivet = (rayon, hauteur, clé) : rivets aux coins du cadre. Retourne le nombre de panneaux."""
    bm = _ouvrir(ob)
    K = Cle(bm)
    cand = [f for f in bm.faces if K.get(f) in cristal and (centre_fn is None or _dehors(f, centre_fn) > dehors_min)]
    regs = _regions(cand)
    n_pan = 0
    coins = []
    for reg in regs:
        aire = sum(f.calc_area() for f in reg)
        if aire < aire_min:
            continue
        bord = _bord(reg)
        if not bord:
            continue
        per = sum(e.calc_length() for e in bord)
        larg_reg = 2 * aire / max(per, 1e-6)           # largeur moyenne du panneau
        w = min(largeur, 0.30 * larg_reg)
        if w < 0.0025:
            continue
        k_c = K.get(reg[0])
        k_cad = cadre(k_c) if callable(cadre) else cadre
        # coins du panneau (angle du contour) pour les rivets
        if rivet:
            vb = {}
            for e in bord:
                for v in e.verts:
                    vb.setdefault(v, []).append(e)
            for v, es in vb.items():
                if len(es) != 2:
                    continue
                a = (es[0].other_vert(v).co - v.co).normalized()
                b = (es[1].other_vert(v).co - v.co).normalized()
                if a.dot(b) > -0.15:                        # angle < ~100° : coin
                    coins.append((v, reg))
            if aire < rivet_aire:
                coins = [c for c in coins if c[1] is not reg]
            else:                                           # au plus 4 rivets par panneau, espacés
                garde = []
                for c in [c for c in coins if c[1] is reg]:
                    if len(garde) < rivets_max and all((c[0].co - g[0].co).length > 0.03 for g in garde):
                        garde.append(c)
                coins = [c for c in coins if c[1] is not reg] + garde
        coins_reg = [c for c in coins if c[1] is reg]
        # 1) cadre montant (biseau)
        r1 = bmesh.ops.inset_region(bm, faces=reg, thickness=w * (0.55 if anneaux > 1 else 1.0), depth=saillie,
                                    use_even_offset=False, use_boundary=True)
        for f in r1["faces"]:
            K.set(f, k_cad)
        # 2) plat du cadre
        if anneaux > 1:
            r2 = bmesh.ops.inset_region(bm, faces=reg, thickness=w * 0.45, depth=0.0, use_even_offset=False, use_boundary=True)
            for f in r2["faces"]:
                K.set(f, k_cad)
        # 3) gorge (le cristal part un peu sous le cadre)
        if gorge > 0:
            r3 = bmesh.ops.inset_region(bm, faces=reg, thickness=0.0012, depth=-gorge, use_even_offset=False, use_boundary=True)
            for f in r3["faces"]:
                K.set(f, k_cad)
        cen = sum((f.calc_center_median() for f in reg), Vector()) / len(reg)
        nn = sum((f.normal for f in reg), Vector()).normalized()
        # 4) cristal : pyramide basse (hauteur selon la distance au contour du panneau)
        if facettes and bombe > 0:
            _pyramide(bm, reg, bombe * min(1.0, larg_reg / 0.06) ** 0.5)
        n_pan += 1
        if rivet:
            # rivets posés sur le plat du cadre, au coin : position = sommet d'origine déplacé (il est devenu coin extérieur
            # du cadre) + décalage vers l'intérieur du panneau
            for v, _ in coins_reg:
                if not v.is_valid:
                    continue
                p = v.co + (cen - v.co).normalized() * (w * 0.75) + nn * saillie
                coins.append(("R", p, nn, v))
    riv = [c for c in coins if c[0] == "R"]
    if rivet and riv:
        r_, h_, k_r = rivet
        dl = bm.verts.layers.deform.active
        for (_, p, n, v_src) in riv:
            _cone(bm, K, p, n, r_, h_, k_r, 4, v_src, dl, base_dessous=saillie * 0.6)
    _fermer(bm, ob)
    if verbeux:
        print("RELIEF sertir", ob.name, "panneaux", n_pan, "rivets", len(riv))
    return n_pan


def _pyramide(bm, reg, h):
    """Soulève l'intérieur d'une région : sommets intérieurs selon la distance (géodésique sur arêtes) au contour ; les faces dont
    tous les sommets sont au bord sont piquées (pointe centrale) -> facettes nettes."""
    s = set(reg)
    vs = {v for f in reg for v in f.verts}
    bordv = {v for e in _bord(reg) for v in e.verts}
    # Dijkstra simple depuis le bord
    import heapq
    dist = {v: 0.0 for v in bordv}
    tas = [(0.0, i, v) for i, v in enumerate(bordv)]
    heapq.heapify(tas)
    cpt = len(tas)
    while tas:
        d, _, v = heapq.heappop(tas)
        if d > dist.get(v, 1e9):
            continue
        for e in v.link_edges:
            if not any(g in s for g in e.link_faces):
                continue
            u = e.other_vert(v)
            if u not in vs:
                continue
            nd = d + e.calc_length()
            if nd < dist.get(u, 1e9):
                dist[u] = nd
                cpt += 1
                heapq.heappush(tas, (nd, cpt, u))
    dmax = max(dist.values()) if dist else 0.0
    norm = {}
    for v in vs:
        n = Vector()
        for f in v.link_faces:
            if f in s:
                n += f.normal
        norm[v] = n.normalized() if n.length > 0 else v.normal.copy()
    if dmax > 1e-5:
        for v in vs:
            if v in bordv:
                continue
            t = min(1.0, dist.get(v, 0.0) / dmax)
            v.co += norm[v] * h * t
    # faces sans sommet intérieur : pointe centrale
    plates = [f for f in reg if f.is_valid and all(v in bordv for v in f.verts) and len(f.verts) >= 4]
    if plates:
        nrm = {f: f.normal.copy() for f in plates}
        larg = {f: min(e.calc_length() for e in f.edges) for f in plates}
        r = bmesh.ops.poke(bm, faces=plates)
        for v in r["verts"]:
            n = Vector()
            for f in v.link_faces:
                n += f.normal
            n = n.normalized() if n.length > 0 else Vector((0, 0, 1))
            l = min((e.calc_length() for e in v.link_edges), default=0.01)
            v.co += n * min(h, 0.45 * l)


def _cone(bm, K, p, n, r, h, k, cotes, v_src, dl, base_dessous=0.001):
    """Petit cône (rivet, clou) posé en p, axe n ; base enfoncée de base_dessous."""
    n = n.normalized()
    t1 = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    t2 = n.cross(t1)
    b = p - n * base_dessous
    ring = [bm.verts.new(b + (t1 * math.cos(math.tau * i / cotes) + t2 * math.sin(math.tau * i / cotes)) * r + n * (base_dessous * 0.7))
            for i in range(cotes)]
    top = bm.verts.new(p + n * h)
    fs = []
    for i in range(cotes):
        f = bm.faces.new((ring[i], ring[(i + 1) % cotes], top))
        K.set(f, k)
        f.smooth = False
        fs.append(f)
    if dl is not None and v_src is not None and v_src.is_valid:
        for v in ring + [top]:
            for g, w in v_src[dl].items():
                v[dl][g] = w
    bm.normal_update()
    for f in fs:
        if f.normal.dot(n) < 0:
            f.normal_flip()
    return fs


def rivets_sur(ob, points, rayon, hauteur, cle, cotes=4):
    """Rivets/clous sur la pièce aux points donnés (repère Blender) : collés à la surface la plus proche, poids du sommet proche."""
    from mathutils.bvhtree import BVHTree
    bm = _ouvrir(ob)
    K = Cle(bm)
    dl = bm.verts.layers.deform.active
    arbre = BVHTree.FromBMesh(bm)
    kd = KDTree(len(bm.verts))
    for v in bm.verts:
        kd.insert(v.co, v.index)
    kd.balance()
    bm.verts.ensure_lookup_table()
    src = list(bm.verts)
    n_ok = 0
    for p in points:
        loc, nrm, _, _ = arbre.find_nearest(Vector(p), 0.1)
        if loc is None:
            continue
        _, i, _ = kd.find(loc)
        _cone(bm, K, loc + nrm * 0.0006, nrm, rayon, hauteur, cle, cotes, src[i], dl, base_dessous=0.0012)
        n_ok += 1
    _fermer(bm, ob)
    return n_ok


# ------------------------------------------------------------------------------------------------ cuir : bords épais, bourrelets
def ourler(ob, cles, epaisseur=0.004, retour=0.003, cle_bord=None, filtre=None, verbeux=True):
    """Bords libres des faces de clé dans `cles` : bande repliée VERS LE CORPS (épaisseur visible du cuir) puis petit retour
    sous la pièce. filtre(p_centre_arête) -> bool limite les bords traités."""
    bm = _ouvrir(ob)
    K = Cle(bm)
    bords = [e for e in bm.edges if e.is_boundary and K.get(e.link_faces[0]) in cles
             and (filtre is None or filtre((e.verts[0].co + e.verts[1].co) / 2))]
    if not bords:
        bm.free()
        return 0
    # normale moyenne des faces au bord, par sommet
    nv = {}
    for e in bords:
        for v in e.verts:
            nv.setdefault(v, Vector())
            nv[v] += e.link_faces[0].normal
    r = bmesh.ops.extrude_edge_only(bm, edges=bords)
    nouv = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    nfaces = [g for g in r["geom"] if isinstance(g, bmesh.types.BMFace)]
    # chaque nouveau sommet : retrouver l'ancien (même position) -> recul le long de -normale
    kd = KDTree(len(nv))
    anciens = list(nv)
    for i, v in enumerate(anciens):
        kd.insert(v.co, i)
    kd.balance()
    for v in nouv:
        _, i, _ = kd.find(v.co)
        a = anciens[i]
        n = nv[a].normalized()
        # direction « vers l'intérieur de la pièce » le long de la surface : moyenne des arêtes non-bord
        dedans = Vector()
        for e in a.link_edges:
            if not e.is_boundary and e.other_vert(a) not in nv:
                dedans += (e.other_vert(a).co - a.co).normalized()
        dedans = dedans.normalized() if dedans.length > 0 else Vector()
        v.co = a.co - n * epaisseur + dedans * retour
    for f in nfaces:
        if cle_bord is not None:
            K.set(f, cle_bord)
        f.smooth = True
    bm.normal_update()
    # orientation : les faces du repli regardent vers l'extérieur de la bande (comme la face voisine, pliée)
    for f in nfaces:
        e = next((e for e in f.edges if e in set(bords)), None)
        if e is None:
            continue
        g = e.link_faces[0] if e.link_faces[0] is not f else (e.link_faces[1] if len(e.link_faces) > 1 else None)
        if g is None:
            continue
        # la face du repli doit avoir l'ordre d'arête opposé à la voisine
        if _meme_sens(e, f, g):
            f.normal_flip()
    _fermer(bm, ob)
    if verbeux:
        print("RELIEF ourler", ob.name, "aretes", len(bords))
    return len(bords)


def _meme_sens(e, f, g):
    def sens(face):
        for lp in face.loops:
            if lp.edge == e:
                return lp.vert == e.verts[0]
        return None
    return sens(f) == sens(g)


def nervurer(ob, cles, choisir, saillie=0.003, largeur=0.004, cle_nervure=None, centre_fn=None, dehors_min=0.2, verbeux=True):
    """Bourrelet / lanière en relief : faces de clé dans `cles` dont le centre satisfait choisir(p) -> régions encartées puis
    soulevées (biseau). cle_nervure : clé posée sur les faces soulevées (None : inchangée)."""
    bm = _ouvrir(ob)
    K = Cle(bm)
    sel = [f for f in bm.faces if K.get(f) in cles and choisir(f.calc_center_median())
           and (centre_fn is None or _dehors(f, centre_fn) > dehors_min)]
    regs = _regions(sel)
    n = 0
    for reg in regs:
        if len(reg) < 2:
            continue
        r1 = bmesh.ops.inset_region(bm, faces=reg, thickness=largeur * 0.5, depth=saillie, use_even_offset=True, use_boundary=True)
        if cle_nervure is not None:
            for f in reg + r1["faces"]:
                K.set(f, cle_nervure)
        n += 1
    _fermer(bm, ob)
    if verbeux:
        print("RELIEF nervurer", ob.name, "bandes", n)
    return n


# ------------------------------------------------------------------------------------------------ fourrure : mèches
def meches(ob, cles, choisir, longueur=0.035, largeur=0.014, pas=0.022, cle_meche=None, tombe=0.55, graine=3, centre_fn=None,
           dehors_min=0.0, verbeux=True):
    """Mèches de fourrure en volume : pour les faces de clé dans `cles` dont le centre satisfait choisir(p), une mèche (lame
    triangulaire pliée en V, 2 faces + dos) tous les `pas` m environ, qui sort de la surface et retombe (tombe = part vers le bas)."""
    import random
    rnd = random.Random(graine)
    bm = _ouvrir(ob)
    K = Cle(bm)
    dl = bm.verts.layers.deform.active
    faces = [f for f in bm.faces if K.get(f) in cles and choisir(f.calc_center_median())
             and (centre_fn is None or _dehors(f, centre_fn) > dehors_min)]
    pris = KDTree(max(1, len(faces)))
    pos = []
    for f in sorted(faces, key=lambda f: rnd.random()):
        c = f.calc_center_median()
        ok = True
        for q in pos:
            if (q - c).length < pas:
                ok = False
                break
        if not ok:
            continue
        pos.append(c)
        n = f.normal.copy()
        bas = Vector((0, 0, -1))
        d = (n * (1 - tombe) + bas * tombe)
        d = (d - n * min(0.0, d.dot(n))).normalized()
        if d.dot(n) < 0.15:
            d = (d + n * 0.4).normalized()
        L_ = longueur * (0.7 + 0.6 * rnd.random())
        W = largeur * (0.75 + 0.5 * rnd.random())
        t = n.cross(d)
        if t.length < 1e-4:
            t = n.cross(Vector((1, 0, 0)))
        t.normalize()
        base = c - n * 0.002
        v_src = f.verts[0]
        a = bm.verts.new(base - t * W * 0.5)
        b = bm.verts.new(base + t * W * 0.5)
        m = bm.verts.new(base + n * W * 0.35)                       # dos de la mèche (volume)
        tip = bm.verts.new(base + d * L_ + t * (rnd.random() - 0.5) * W * 0.6)
        fs = [bm.faces.new((a, m, tip)), bm.faces.new((m, b, tip)), bm.faces.new((b, a, tip))]
        for fz in fs:
            K.set(fz, cle_meche if cle_meche is not None else K.get(f))
            fz.smooth = False
        if dl is not None:
            for v in (a, b, m, tip):
                for g, w in v_src[dl].items():
                    v[dl][g] = w
        bm.normal_update()
        cen = (a.co + b.co + m.co + tip.co) / 4 - n * 0.003
        for fz in fs:
            if (fz.calc_center_median() - cen).dot(fz.normal) < 0:
                fz.normal_flip()
    _fermer(bm, ob)
    if verbeux:
        print("RELIEF meches", ob.name, len(pos))
    return len(pos)


def compter_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ------------------------------------------------------------------------------------------------ lanières, boucles (cuir)
def _poids_kd(bm, dl):
    kd = KDTree(len(bm.verts))
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        kd.insert(v.co, v.index)
    kd.balance()
    src = list(bm.verts)
    def copier(v):
        if dl is None:
            return
        _, i, _ = kd.find(v.co)
        for g, w in src[i][dl].items():
            v[dl][g] = w
    return copier


def laniere(ob, points, largeur, epaisseur, cle, decal=0.004, pas=0.025, cle_boucle=None, boucles=(), centre_fn=None, verbeux=True):
    """Lanière / sangle de cuir posée SUR la pièce le long d'une polyligne (repère Blender) : chaque point est ramené sur la surface la
    plus proche puis décalé de `decal` le long de la normale ; section = dessus + deux tranches (épaisseur visible), bouts fermés.
    boucles = indices (fraction 0..1 de la longueur) où poser une boucle de fer (cadre rectangulaire en relief, clé cle_boucle).
    Poids d'os : sommet de la pièce le plus proche."""
    from mathutils.bvhtree import BVHTree
    bm = _ouvrir(ob)
    K = Cle(bm)
    dl = bm.verts.layers.deform.active
    copier = _poids_kd(bm, dl)
    arbre = BVHTree.FromBMesh(bm)
    # rééchantillonnage
    pts = [Vector(p) for p in points]
    dense = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int((b - a).length / pas))
        for i in range(1, n + 1):
            dense.append(a.lerp(b, i / n))
    sur = []
    for p in dense:
        loc, nrm, _, _ = arbre.find_nearest(p, 0.3)
        if loc is None:
            continue
        if centre_fn is not None:
            o = centre_fn(loc)
            if o is not None and nrm.dot(loc - o) < 0:
                nrm = -nrm
        sur.append((loc + nrm * decal, nrm))
    # lissage des normales le long du trajet
    ns = [n for _, n in sur]
    for _ in range(2):
        ns = [(ns[max(i - 1, 0)] + ns[i] * 2 + ns[min(i + 1, len(ns) - 1)]).normalized() for i in range(len(ns))]
    rangs = []
    for i, ((p, _), n) in enumerate(zip(sur, ns)):
        t = sur[min(i + 1, len(sur) - 1)][0] - sur[max(i - 1, 0)][0]
        s = n.cross(t).normalized() * largeur * 0.5
        rangs.append([bm.verts.new(p - s - n * epaisseur), bm.verts.new(p - s), bm.verts.new(p + s), bm.verts.new(p + s - n * epaisseur)])
    fs = []
    for A, Bv in zip(rangs, rangs[1:]):
        for j in range(3):
            fs.append(bm.faces.new((A[j], A[j + 1], Bv[j + 1], Bv[j])))
    if len(rangs) >= 2:
        fs.append(bm.faces.new(rangs[0]))
        fs.append(bm.faces.new(list(reversed(rangs[-1]))))
    for f in fs:
        K.set(f, cle)
        f.smooth = True
    for r in rangs:
        for v in r:
            copier(v)
    bm.normal_update()
    # orientation : dessus vers la normale
    for f, i in zip(fs, range(len(fs))):
        c = f.calc_center_median()
        loc, nrm, _, _ = arbre.find_nearest(c, 0.3)
        if loc is not None and centre_fn is not None:
            o = centre_fn(loc)
            if o is not None and nrm.dot(loc - o) < 0:
                nrm = -nrm
        if loc is not None and (c - loc).dot(f.normal) < -1e-5 and abs(f.normal.dot(nrm)) > 0.5:
            f.normal_flip()
    nb = 0
    for fr in boucles:
        if not sur:
            break
        i = min(len(sur) - 1, int(fr * (len(sur) - 1)))
        p, n = sur[i][0], ns[i]
        t = (sur[min(i + 1, len(sur) - 1)][0] - sur[max(i - 1, 0)][0]).normalized()
        _boucle(bm, K, p + n * 0.0015, n, t, largeur * 1.35, largeur * 1.0, 0.0035, cle_boucle if cle_boucle is not None else cle, copier)
        nb += 1
    _fermer(bm, ob)
    if verbeux:
        print("RELIEF laniere", ob.name, len(rangs), "rangs", nb, "boucles")
    return len(rangs)


def _boucle(bm, K, c, n, t, haut, larg, ep, cle, copier):
    """Boucle de fer : cadre rectangulaire (4 barres à section carrée) + ardillon, posé en c, normale n, axe de la sangle t."""
    s = n.cross(t).normalized()
    hx, hy = larg * 0.5, haut * 0.5
    coins = [c + s * hx + t * hy, c - s * hx + t * hy, c - s * hx - t * hy, c + s * hx - t * hy]
    e = ep
    anneaux = []
    for k in range(4):
        p = coins[k]
        d = (p - c).normalized()
        anneaux.append([bm.verts.new(p + d * e * 0.5), bm.verts.new(p + d * e * 0.5 + n * e), bm.verts.new(p - d * e * 0.5 + n * e),
                        bm.verts.new(p - d * e * 0.5)])
    fs = []
    for k in range(4):
        A, Bv = anneaux[k], anneaux[(k + 1) % 4]
        for j in range(4):
            fs.append(bm.faces.new((A[j], A[(j + 1) % 4], Bv[(j + 1) % 4], Bv[j])))
    # ardillon
    a0 = bm.verts.new(c - t * hy * 0.9 + n * e * 0.6)
    a1 = bm.verts.new(c + t * hy * 1.05 + n * e * 1.1)
    a2 = bm.verts.new(c + n * e * 1.6)
    fs.append(bm.faces.new((a0, a1, a2)))
    for f in fs:
        K.set(f, cle)
        f.smooth = False
    for r in anneaux:
        for v in r:
            copier(v)
    for v in (a0, a1, a2):
        copier(v)
    bm.normal_update()
    for f in fs[:-1]:
        cc = f.calc_center_median()
        k = fs.index(f) // 4
        mid = (coins[k] + coins[(k + 1) % 4]) / 2 + n * e * 0.5
        if (cc - mid).dot(f.normal) < 0:
            f.normal_flip()


def reparer_uv(ob, n_faces_avant):
    """Faces ajoutées (index >= n_faces_avant) sans UV (rivets, lanières, mèches...) : chaque coin reprend l'UV du coin d'origine le
    plus proche (pièces dont la texture est déjà peinte dans un atlas, ex. uniques). Les faces encartées gardent leurs UV interpolées."""
    me = ob.data
    if not me.uv_layers:
        return 0
    uv = me.uv_layers.active.data
    pts = []
    for p in me.polygons:
        if p.index >= n_faces_avant:
            break
        for li in p.loop_indices:
            pts.append((me.vertices[me.loops[li].vertex_index].co.copy(), tuple(uv[li].uv)))
    kd = KDTree(len(pts))
    for i, (c, _) in enumerate(pts):
        kd.insert(c, i)
    kd.balance()
    n = 0
    for p in me.polygons:
        if p.index < n_faces_avant:
            continue
        if any(abs(uv[li].uv[0]) + abs(uv[li].uv[1]) > 1e-7 for li in p.loop_indices):
            continue
        for li in p.loop_indices:
            _, i, _ = kd.find(me.vertices[me.loops[li].vertex_index].co)
            uv[li].uv = pts[i][1]
        n += 1
    return n
