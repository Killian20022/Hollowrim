# ARMES QUATERNIUS HD (lot 2 de la branche armes/hybrides_hd, 2026-11-12) : modélisation DÉDIÉE par arme, sur les mesures de
# l'original (assets/modeles/armes/cc0_essai/06..12_*.glb, gardés ; une première passe générique « chanfrein seul » a été rejetée :
# invisible en rendu). Chaque pièce de l'original est repérée (composantes connexes + matériaux) puis refaite :
#   haches  : fer = plaque mesurée par coupes le long du manche (bord intérieur / tranchant exacts : cornes, crans, barbe),
#             section à JOUES épaisses près de l'œil, biseau et FIL au tranchant (u 0,5 -> 1 : le fil de la texture « lame » suit) ;
#             douille / œil (+ pointe) refaits à pans sur leurs coupes, rivets, deux ferrures (attelles) rivetées le long du manche ;
#   marteaux: têtes, collets et attelles refaits à pans chanfreinés sur leurs coupes (le long de leur grand axe), clous refaits en
#             têtes bombées ; sangles de cuir d'origine gardées (chanfreinées) ;
#   masse   : corps à 8 pans chanfreinés sur ses coupes, pointes refaites en volume (cône à 8 pans + rondelle), viroles rivetées,
#             poignée gainée de cuir enroulé ;
#   manches : bois refait sur ses coupes (14 pans irréguliers = bois fendu), veinage dans les UV (bois), bagues de cuir d'origine
#             refaites en cuir enroulé ;
#   boucliers : planches d'origine SÉPARÉES (joints de 3 mm), chanfreinées, clous ; cerclage chanfreiné et riveté ; clous d'origine
#             refaits en têtes bombées à rondelle ; umbo bombé riveté (bouclier rond) ; poignées en cuir.
# Matériaux nommés comme EpeesLongues (lame, fer, acier_fil, bois, planches, cuir) : les .tscn hd/ n'ont plus de remap_materiaux.
# Mêmes coordonnées que le glb d'origine : assets/modeles/armes/integrees/hd/<id>.tscn reprend le montage (échelle, décalage, repères).
#   blender.exe -b --python sources_blender/hybrides_hd/quaternius_hd.py -- [hache_guerre ...]
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, bvhtree

MOI = os.path.abspath(__file__)
_h = open(os.path.join(os.path.dirname(MOI), "hybrides_hd.py"), encoding="utf-8").read()
__file__ = os.path.join(os.path.dirname(MOI), "hybrides_hd.py")
exec(_h.split("# ------------------------------------------------------------------ assemblage")[0])   # outils hybrides + v2 + v1
__file__ = MOI
ICI = os.path.dirname(MOI)
DEPOT = os.path.dirname(os.path.dirname(ICI))
SRC = os.path.join(DEPOT, "assets", "modeles", "armes", "cc0_essai")
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "integrees", "hd")
MATS_Q = ("lame", "fer", "acier_fil", "bois", "planches", "cuir", "acier_q")

ARMES = {
    "hache_guerre": ("06_axe", "hache"),
    "hachette": ("07_axe_small", "hache"),
    "marteau_guerre": ("08_hammer_small", "marteau"),
    "grand_marteau": ("09_hammer_double", "marteau"),
    "masse_cloutee": ("10_club_mace", "masse"),
    "bouclier_cercle": ("11_shield_round", "bouclier"),
    "ecu_chevalier": ("12_shield_heater", "bouclier"),
}


# ------------------------------------------------------------------ lecture : composantes connexes (sommets soudés)
def composantes(chemin):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=chemin)
    src = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    src.data.transform(src.matrix_world)
    src.matrix_world.identity()
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.faces.ensure_lookup_table()
    noms = [m.name for m in src.data.materials]
    vu, comps = set(), []
    for f in bm.faces:
        if f.index in vu:
            continue
        pile, cf = [f], []
        vu.add(f.index)
        while pile:
            a = pile.pop()
            cf.append(a)
            for e in a.edges:
                for b in e.link_faces:
                    if b.index not in vu:
                        vu.add(b.index)
                        pile.append(b)
        par = {}
        for a in cf:
            vs = [tuple(v.co) for v in a.verts]
            for i in range(1, len(vs) - 1):
                par.setdefault(noms[a.material_index], []).append([vs[0], vs[i], vs[i + 1]])
        comps.append({"faces": [a.index for a in cf], "par": par, "mats": set(par)})
    me = bpy.data.meshes.new("soude")
    bm.to_mesh(me)
    bm.free()
    for m_ in src.data.materials:
        me.materials.append(m_)
    src.data = me
    return src, comps


def tous(c):
    return [t for v in c["par"].values() for t in v]


def ext3(tris):
    return [mq.etendue(tris, k) for k in range(3)]


def garder(src, faces, mat_de, nom, biseau=0.0015, decoupe=0.02, mats_garde=None):
    """Recopie des faces de l'original (UV gardées), chanfrein des arêtes vives, grandes faces redécoupées."""
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.faces.ensure_lookup_table()
    garde_ = set(faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in garde_], context='FACES')
    if mats_garde is not None:
        idx = [i for i, m in enumerate(src.data.materials) if m.name in mats_garde]
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in idx], context='FACES')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    vives = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(30)]
    if biseau > 0 and vives:
        bmesh.ops.bevel(bm, geom=vives, offset=biseau, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES',
                        clamp_overlap=True, loop_slide=True)
    longues = [e for e in bm.edges if e.calc_length() > decoupe]
    if longues:
        bmesh.ops.subdivide_edges(bm, edges=longues, cuts=1, use_grid_fill=True)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    noms = [m.name for m in src.data.materials]
    nouveaux = []
    for m in noms:
        n = mat_de(m)
        if n not in nouveaux:
            nouveaux.append(n)
    remap = [nouveaux.index(mat_de(m)) for m in noms]
    idx = [remap[p.material_index] for p in me.polygons]
    me.materials.clear()          # (clear() remet les indices à 0 : on les pose APRÈS)
    for n in nouveaux:
        me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
    for p, i in zip(me.polygons, idx):
        p.material_index = i
        p.use_smooth = False
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ------------------------------------------------------------------ volumes mesurés
def bloc(m, tris, axe, n, mat, cotes=16, chanfrein=0.80, marge=0.0008, bout=0.9, rond=False):
    """Volume sur les coupes mesurées le long de `axe` ; section carrée à coins chanfreinés (ou ronde), bouts chanfreinés."""
    a0, a1 = mq.etendue(tris, axe)
    vals = [a0 + marge + (a1 - a0 - 2 * marge) * k / (n - 1) for k in range(n)]
    st = [(v, r) for v, r in mq.profil(tris, axe, vals) if r is not None]
    autres = [k for k in range(3) if k != axe]
    anneaux = []
    for i, (v, ((b0, b1), (c0, c1))) in enumerate(st):
        s = bout if i in (0, len(st) - 1) else 1.0
        cb, cc_ = (b0 + b1) * 0.5, (c0 + c1) * 0.5
        rb, rc = max(0.0012, (b1 - b0) * 0.5) * s, max(0.0012, (c1 - c0) * 0.5) * s
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            k = 1.0 if rond else 1.0 / max(abs(math.cos(f)), abs(math.sin(f)), chanfrein)
            p = [0.0, 0.0, 0.0]
            p[axe] = v
            p[autres[0]] = cb + rb * k * math.cos(f)
            p[autres[1]] = cc_ + rc * k * math.sin(f)
            a.append(tuple(p))
        anneaux.append(a)

    def uv(p, k, i, mat_=None):
        return (i / cotes * 2.0, k / max(1, len(anneaux) - 1) * 2.0)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    capuchon(m, ids[0], anneaux[0], mat, uv)
    m.face(ids[-1], mat, [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return st


def manche_bois(m, tris, cotes=14, pas=0.010):
    z0, z1 = mq.etendue(tris, 2)
    n = max(12, int((z1 - z0) / pas))
    zs = [z0 + 0.0015 + (z1 - z0 - 0.003) * k / n for k in range(n + 1)]
    st = [(z, r) for z, r in mq.profil(tris, 2, zs) if r is not None]
    anneaux = []
    for k, (z, ((x0, x1), (y0, y1))) in enumerate(st):
        cx, cy, rx, ry = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (x1 - x0) * 0.5, (y1 - y0) * 0.5
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            fil = 1.0 + 0.04 * math.sin(3 * f + 0.45 * k) * math.cos(0.31 * k + 1.7 * j)   # bois fendu : pans irréguliers
            a.append((cx + rx * 0.97 * fil * math.cos(f), cy + ry * 0.97 * fil * math.sin(f), z))
        anneaux.append(a)
    L = z1 - z0
    ids = relier(m, anneaux, lambda k, i: "bois", lambda p, k, i, m_=None: (i / cotes, (p[2] - z0) / L * 6.0))
    capuchon(m, ids[0], anneaux[0], "bois", lambda p, k, i, m_=None: (0.5, 0.0))
    m.face(ids[-1], "bois", [(0.5, 1.0)] * cotes)
    return st


def cuir_bandes(m, tris, tours=1.6, cotes=14):
    """Bagues de cuir d'origine : profil MESURÉ tous les 2 mm (bourrelets compris), coupé en anneaux aux creux ; chaque anneau
    refait en lanière enroulée (relief en dents de scie qui tourne), bords arrondis."""
    for lo, hi, ts in bandes(tris):
        if hi - lo < 0.004:
            continue
        n = max(4, int((hi - lo) / 0.003))
        zs = [lo + 0.0006 + (hi - lo - 0.0012) * k / n for k in range(n + 1)]
        pr = [(z, r) for z, r in mq.profil(ts, 2, zs) if r is not None]
        if len(pr) < 3:
            continue
        zz = [z for z, r in pr]
        cx = [(r[0][0] + r[0][1]) * 0.5 for z, r in pr]
        cy = [(r[1][0] + r[1][1]) * 0.5 for z, r in pr]
        rx = [(r[0][1] - r[0][0]) * 0.5 for z, r in pr]
        ry = [(r[1][1] - r[1][0]) * 0.5 for z, r in pr]
        # creux = minima locaux du rayon (séparation entre deux anneaux)
        coupes = [0]
        for i in range(1, len(pr) - 1):
            if rx[i] < rx[i - 1] and rx[i] <= rx[i + 1] and rx[i] < 0.94 * max(rx[max(0, i - 4):i + 5]):
                if zz[i] - zz[coupes[-1]] > 0.006:
                    coupes.append(i)
        coupes.append(len(pr) - 1)
        for a_, b_ in zip(coupes, coupes[1:]):
            anneaux = []
            for i in range(a_, b_ + 1):
                u = (zz[i] - zz[a_]) / max(1e-6, zz[b_] - zz[a_])
                bord = 0.90 + 0.10 * math.sin(math.pi * u) ** 0.5      # bords arrondis
                a = []
                for j in range(cotes):
                    f = TAU * j / cotes
                    ph = (f / TAU - tours * u) % 1.0
                    dent = ph / 0.82 if ph < 0.82 else (1.0 - ph) / 0.18
                    s_ = bord * (1.0 + 0.08 * (dent - 0.5))
                    a.append((cx[i] + rx[i] * s_ * math.cos(f), cy[i] + ry[i] * s_ * math.sin(f), zz[i]))
                anneaux.append(a)
            if len(anneaux) >= 2:
                relier(m, anneaux, lambda k, i: "cuir", lambda p, k, i, m_=None: (i / cotes * 2.0, k / max(1, len(anneaux) - 1)))


def clou(m, base, nor, r, mat, h=None, rondelle=True):
    """Tête de clou / rivet bombée (8 pans) posée en `base`, vers `nor` ; rondelle plate dessous."""
    nor = Vector(nor).normalized()
    t = nor.orthogonal().normalized()
    b = nor.cross(t)
    h = 0.75 * r if h is None else h
    prof = ([(-0.3 * r, 1.45), (0.12 * r, 1.45), (0.14 * r, 1.0)] if rondelle else [(-0.3 * r, 1.05)]) + \
        [(0.16 * r, 1.0), (0.5 * h, 0.86), (0.85 * h, 0.5)]
    anneaux = [[tuple(Vector(base) + nor * hh + (t * math.cos(TAU * j / 8) + b * math.sin(TAU * j / 8)) * r * s) for j in range(8)]
               for hh, s in prof]
    ids = relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / 8, k / len(prof)))
    pointe_sur(m, ids[-1], anneaux[-1], tuple(Vector(base) + nor * h), lambda i: mat, lambda p, k, i, m_=None: (0.5, 0.5), (0.5, 0.5))


def pointe(m, base, apex, r, mat, cotes=8):
    """Pointe (clou de masse) en volume : cône à pans, collet, rondelle."""
    base, apex = Vector(base), Vector(apex)
    d = (apex - base)
    L = d.length
    nor = d.normalized()
    t = nor.orthogonal().normalized()
    b = nor.cross(t)
    prof = [(-0.25 * r, 1.55), (0.0, 1.55), (0.06 * L, 1.45), (0.10 * L, 1.0), (0.45 * L, 0.62), (0.80 * L, 0.24)]
    anneaux = [[tuple(base + nor * hh + (t * math.cos(TAU * j / cotes) + b * math.sin(TAU * j / cotes)) * r * s) for j in range(cotes)]
               for hh, s in prof]
    ids = relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes, k / 5))
    pointe_sur(m, ids[-1], anneaux[-1], tuple(apex), lambda i: mat, lambda p, k, i, m_=None: (0.5, 1.0), (0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, lambda p, k, i, m_=None: (0.5, 0.0))


def poser(objs, p, d):
    """Point de la surface des objets le plus proche de p (BVH), avec sa normale."""
    best = None
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        arbre = bvhtree.BVHTree.FromBMesh(bm)
        bm.free()
        loc, nor, i, dist = arbre.find_nearest(Vector(p))
        if loc is not None and (best is None or dist < best[2]):
            best = (loc, nor, dist)
    if best is None:
        return None, None
    nor = best[1] if best[1].dot(Vector(d)) >= 0 else -best[1]
    return best[0], nor


# ------------------------------------------------------------------ hache : plaque de fer mesurée
def fer_hache(m, tris, pas=0.007):
    z0, z1 = mq.etendue(tris, 2)
    zs = set(round(z, 5) for z in mq.sommets_z(tris, z0 + 2e-4, z1 - 2e-4))
    vz = sorted(zs)
    n = int((z1 - z0) / pas)
    for k in range(1, n):
        z = round(z0 + (z1 - z0) * k / n, 5)
        if all(abs(z - w) > 0.003 for w in vz):
            zs.add(z)
    st = []
    for z, r in mq.profil(tris, 2, sorted(zs)):
        if r is not None and r[0][1] - r[0][0] > 0.0015:
            st.append((z, r[0][0], r[0][1]))
    xe = min(s[1] for s in st)                  # côté de l'œil
    anneaux, infos = [], []
    for z, a, b in st:
        W = b - a
        joue = max(0.0, 1.0 - (a - xe) / 0.05)    # joues épaisses près de l'œil
        t = 0.0040 + 0.0028 * joue
        bv = min(0.42 * W, 0.016)
        ch = min(0.0025, 0.12 * W)
        haut = [(a, 0.55 * t), (a + ch, t), (a + 0.45 * (W - bv), 0.92 * t), (b - bv, 0.62 * t), (b - bv * 0.55, 0.40 * t),
                (b - bv * 0.18, 0.16 * t), (b, 0.0)]
        bas = [(x, -y) for x, y in reversed(haut[:-1])]
        anneaux.append([(x, y, z) for x, y in haut + bas])
        infos.append((a, W))

    def uv(p, k, i, mat_=None):
        k = min(k, len(infos) - 1)
        a, W = infos[k]
        return (0.5 + 0.5 * min(1.0, max(0.0, (p[0] - a) / W)), (p[2] - z0) / (z1 - z0))
    ids = relier(m, anneaux, lambda k, i: "acier_fil", uv)
    capuchon(m, ids[0], anneaux[0], "acier_fil", uv)
    m.face(ids[-1], "acier_fil", [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])
    return st


def hache(ident, src, comps):
    lame_c = next(c for c in comps if "lame.3" in c["mats"])
    manche_c = next(c for c in comps if "cuir.2" in c["mats"])
    autres = [c for c in comps if c is not lame_c and c is not manche_c]
    M = Maille("fer_hache")
    stf = fer_hache(M, tous(lame_c))
    M.creer()
    B = Maille("manche")
    stm = manche_bois(B, manche_c["par"]["cuir.2"])
    B.creer()
    C = Maille("cuir")
    cuir_bandes(C, manche_c["par"]["cuir.1"])
    C.creer()
    F = Maille("douille")
    douille = manche_c["par"].get("lame.0", [])
    for lo, hi, ts in bandes(douille):
        bloc(F, ts, 2, max(6, int((hi - lo) / 0.006)), "fer", cotes=16, chanfrein=0.86, bout=0.94)
    # ferrures (attelles) rivetées le long du manche, sous la douille, sur les deux faces (±y)
    d0 = min(lo for lo, hi, ts in bandes(douille)) if douille else mq.etendue(manche_c["par"]["cuir.2"], 2)[1] - 0.12
    longueur = 0.075 if ident == "hache_guerre" else 0.055
    for sy in (1, -1):
        anneaux = []
        for k in range(9):
            z = d0 - longueur + longueur * k / 8 + 0.004
            e = min(stm, key=lambda s: abs(s[0] - z))
            (x0, x1), (y0, y1) = e[1]
            cx, yy = (x0 + x1) * 0.5, (y1 if sy > 0 else y0)
            w = 0.0055 * (0.55 if k == 0 else 1.0)
            anneaux.append([(cx - w, yy - sy * 0.0008, z), (cx + w, yy - sy * 0.0008, z), (cx + w, yy + sy * 0.0016, z),
                            (cx - w, yy + sy * 0.0016, z)])
        ids = relier(F, anneaux, lambda k, i: "fer", lambda p, k, i, m_=None: (i / 4, k / 8))
        capuchon(F, ids[0], anneaux[0], "fer", lambda p, k, i, m_=None: (0, 0))
        for zf in (0.25, 0.7):
            z = d0 - longueur * (1 - zf)
            e = min(stm, key=lambda s: abs(s[0] - z))
            (x0, x1), (y0, y1) = e[1]
            clou(F, ((x0 + x1) * 0.5, (y1 if sy > 0 else y0) + sy * 0.0016, z), (0, sy, 0), 0.0030, "acier_fil", rondelle=False)
    # rivets de l'œil (deux faces) : sur la douille, côté fer
    if douille:
        dz = mq.etendue(douille, 2)
        for sy in (1, -1):
            for zf in (0.35, 0.62):
                z = dz[0] + (dz[1] - dz[0]) * zf
                ys = [abs(p[1]) for t in douille for p in t if abs(p[2] - z) < 0.01]
                clou(F, (0.0, sy * (max(ys) if ys else 0.02), z), (0, sy, 0), 0.0034, "acier_fil")
    F.creer()
    for c in autres:   # ligature de cuir qui serre le fer au manche : gardée, chanfreinée
        garder(src, c["faces"], lambda n: "cuir", "ligature", biseau=0.0012)
    # coin de bois chassé dans l'œil (visible au-dessus de la douille) -> petit rivet-coin de fer en tête
    return stf


# ------------------------------------------------------------------ marteaux
def marteau(ident, src, comps):
    manche_c = next(c for c in comps if "cuir.2" in c["mats"])
    B = Maille("manche")
    manche_bois(B, manche_c["par"]["cuir.2"])
    B.creer()
    C = Maille("cuir")
    grand = ident == "grand_marteau"
    cuir_bandes(C, manche_c["par"]["cuir.1"], cotes=12 if grand else 14)
    C.creer()
    F = Maille("tete")
    pas_t = 0.006 if ident == "marteau_guerre" else 0.011
    for lo, hi, ts in bandes(manche_c["par"].get("lame.0", [])):
        bloc(F, ts, 2, max(6, int((hi - lo) / pas_t)), "fer", cotes=12 if grand else 16, chanfrein=0.80, bout=0.93)
    clous = []
    for c in comps:
        if c is manche_c:
            continue
        T = tous(c)
        (x0, x1), (y0, y1), (z0, z1) = ext3(T)
        if c["mats"] == {"lame.3"}:
            clous.append(((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5, (x1 - x0, y1 - y0, z1 - z0)))
        elif c["mats"] == {"lame.0"}:
            tailles = [x1 - x0, y1 - y0, z1 - z0]
            axe = tailles.index(max(tailles))
            bloc(F, T, axe, max(8, int(tailles[axe] / (0.005 if ident == "marteau_guerre" else 0.010))), "fer", cotes=12 if grand else 16, chanfrein=0.80,
                 bout=0.90)
        else:      # sangles de cuir croisées d'origine
            o = garder(src, c["faces"], lambda n: "cuir", "sangles", biseau=0.0010)
            cx_, cy_ = (x0 + x1) * 0.5, (y0 + y1) * 0.5
            for v in o.data.vertices:
                v.co.x = cx_ + (v.co.x - cx_) * 1.07
                v.co.y = cy_ + (v.co.y - cy_) * 1.07
    F.creer()
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith("tete")]
    K = Maille("clous")
    for cx, cy, cz, (dx, dy, dz) in clous:
        sy = 1 if cy > 0 else -1
        loc, nor = poser(objs, (cx, cy, cz), (0, sy, 0))
        if loc is None:
            continue
        clou(K, tuple(loc), nor, max(dx, dz) * 0.52, "acier_fil")
    K.creer()


# ------------------------------------------------------------------ masse cloutée
def masse(ident, src, comps):
    T = tous(comps[0])
    z0, z1 = mq.etendue(T, 2)
    pts = list(set(p for t in T for p in t))
    zs = [z0 + 0.002 + (z1 - z0 - 0.004) * k / 90 for k in range(91)]
    rz = []
    for z in zs:
        c = mq.coupe(T, 2, z)
        if not c:
            rz.append((z, None))
            continue
        ds = sorted(math.hypot(p[0], p[1]) for p in c)
        rz.append((z, ds[max(0, int(len(ds) * 0.35) - 1)]))
    rz = [(z, r) for z, r in rz if r is not None]
    zz = [z for z, r in rz]
    rr = lisse([r for z, r in rz], zz, 0.012, "min")

    def r_at(z):
        return min(zip(zz, rr), key=lambda e: abs(e[0] - z))[1]
    # pointes : sommets nettement hors du corps, regroupés
    cand = sorted([p for p in pts if math.hypot(p[0], p[1]) > 1.45 * r_at(p[2]) + 0.006], key=lambda p: -math.hypot(p[0], p[1]))
    apex = []
    for p in cand:
        if all(math.dist(p, q) > 0.02 for q in apex):
            apex.append(p)
    M = Maille("corps")
    anneaux = []
    cotes = 16
    for z, r in zip(zz, rr):
        a = []
        for j in range(cotes):
            f = TAU * j / cotes + TAU / 16
            k = 1.0 / max(abs(math.cos(f * 1.0)), abs(math.sin(f)), 0.0001)
            k = 1.0 / max(math.cos((f % (TAU / 8)) - TAU / 16), 0.90)     # octogone à arêtes chanfreinées
            a.append((r * k * math.cos(f), r * k * math.sin(f), z))
        anneaux.append(a)
    ids = relier(M, anneaux, lambda k, i: "fer", lambda p, k, i, m_=None: (i / cotes * 2, k / len(anneaux) * 6))
    capuchon(M, ids[0], anneaux[0], "fer", lambda p, k, i, m_=None: (0.5, 0))
    M.face(ids[-1], "fer", [(0.5, 1)] * cotes)
    for p in apex:
        rho = math.hypot(p[0], p[1])
        d = (p[0] / rho, p[1] / rho)
        zb = p[2]
        rb = r_at(zb)
        L = rho - rb
        pointe(M, (d[0] * rb * 0.96, d[1] * rb * 0.96, zb), p, max(0.0040, 0.15 * L), "acier_q")
    # viroles rivetées entre la poignée et la tête, poignée gainée de cuir
    zp0, zp1 = z0 + 0.035, z0 + 0.20
    for zc in (zp1 + 0.012, z0 + 0.32):
        r = r_at(zc)
        bague_hd(M, zc - 0.009, zc + 0.009, 0.0, r * 1.07, r * 1.07, "fer", cotes=16)
        for j in range(4):
            f = TAU * j / 4 + 0.4
            clou(M, (r * 1.16 * math.cos(f), r * 1.16 * math.sin(f), zc), (math.cos(f), math.sin(f), 0), 0.0028, "acier_fil",
                 rondelle=False)
    M.creer()
    C = Maille("cuir")
    sel = [(z, r) for z, r in zip(zz, rr) if zp0 <= z <= zp1]
    fake = []
    for z, r in sel:          # gabarit de poignée = corps +2 mm
        rg = r * 1.10 + 0.002
        for j in range(8):
            f1, f2 = TAU * j / 8, TAU * (j + 1) / 8
            fake.append([(rg * math.cos(f1), rg * math.sin(f1), z), (rg * math.cos(f2), rg * math.sin(f2), z),
                         (rg * math.cos(f1), rg * math.sin(f1), z + 0.004)])
    fusee_hd(C, fake, cotes=16, n=40, tours=8.0, relief=0.14)
    C.creer()
    print("MASSE pointes=%d" % len(apex))


# ------------------------------------------------------------------ boucliers
def bouclier(ident, src, comps):
    rond = ident == "bouclier_cercle"
    gros = next(c for c in comps if "lame.1" in c["mats"])      # cerclage + fond
    planche_mat = "cuir.0" if rond else "cuir.2"
    planches = [c for c in comps if c["mats"] == {planche_mat}]
    clous_c = [c for c in comps if c["mats"] == {"lame.3"}]
    poignees = [c for c in comps if c is not gros and c not in planches and c not in clous_c]
    R = garder(src, gros["faces"], lambda n: "fer" if n.startswith("lame") else "cuir", "cerclage", biseau=0.0022, decoupe=0.03)
    for c in planches:          # planches séparées : chacune rétrécie de 1,5 mm de chaque côté autour de son milieu
        o = garder(src, c["faces"], lambda n: "planches", "planche", biseau=0.0020, decoupe=0.025)
        (x0, x1), _, _ = ext3(tous(c))
        cx, w = (x0 + x1) * 0.5, (x1 - x0) * 0.5
        s = max(0.5, 1.0 - 0.0026 / w)
        for v in o.data.vertices:
            v.co.x = cx + (v.co.x - cx) * s
    for c in poignees:
        garder(src, c["faces"], lambda n: "cuir", "poignee", biseau=0.0015)
    K = Maille("clous")
    for c in clous_c:
        (x0, x1), (y0, y1), (z0, z1) = ext3(tous(c))
        clou(K, ((x0 + x1) * 0.5, y1 - 0.004, (z0 + z1) * 0.5), (0, -1, 0), (x1 - x0) * 0.52, "acier_fil", h=(y1 - y0) * 0.9)
    # clous des planches (haut et bas de chaque planche, sur la face avant -y)
    pl_objs = [o for o in bpy.data.objects if o.name.startswith("planche")]
    for c in planches:
        (x0, x1), (y0, y1), (z0, z1) = ext3(tous(c))
        for zf in (0.16, 0.84):
            loc, nor = poser(pl_objs, ((x0 + x1) * 0.5, -0.3, z0 + (z1 - z0) * zf), (0, -1, 0))
            if loc is not None:
                clou(K, tuple(loc), nor, 0.0036, "fer", rondelle=False)
    if rond:   # umbo bombé riveté au centre de la face avant
        T = tous(gros)
        (x0, x1), (y0, y1), (z0, z1) = ext3(T)
        cz = (z0 + z1) * 0.5
        loc, nor = poser(pl_objs, (0.0, -0.3, cz), (0, -1, 0))
        yb = loc.y if loc is not None else -0.10
        ru, hu = 0.072, 0.040
        prof = [(0.0, ru * 1.30), (0.004, ru * 1.30), (0.006, ru * 1.0), (0.016, ru * 0.97), (0.026, ru * 0.84), (0.034, ru * 0.62),
                (0.039, ru * 0.34), (hu, ru * 0.10)]
        an = [[(r * math.cos(TAU * j / 20), yb - h, cz + r * math.sin(TAU * j / 20)) for j in range(20)] for h, r in prof]
        ids = relier(K, an, lambda k, i: "fer", lambda p, k, i, m_=None: (0.5 + (p[0]) / (2.6 * ru), 0.5 + (p[2] - cz) / (2.6 * ru)))
        capuchon(K, ids[-1], an[-1], "fer", lambda p, k, i, m_=None: (0.5, 0.5))
        capuchon(K, list(reversed(ids[0])), list(reversed(an[0])), "fer", lambda p, k, i, m_=None: (0.5, 0.5))
        for j in range(6):
            f = TAU * j / 6
            clou(K, (ru * 1.16 * math.cos(f), yb - 0.004, cz + ru * 1.16 * math.sin(f)), (0, -1, 0), 0.0040, "acier_fil")
    # rivets du cerclage (face avant)
    T = tous(gros)
    (x0, x1), (y0, y1), (z0, z1) = ext3(T)
    cx, cz, rx, rz = (x0 + x1) * 0.5, (z0 + z1) * 0.5, (x1 - x0) * 0.5, (z1 - z0) * 0.5
    nr = 24 if rond else 18
    for j in range(nr):
        f = TAU * (j + 0.5) / nr
        p = (cx + rx * 0.955 * math.cos(f), -0.3, cz + rz * 0.955 * math.sin(f))
        loc, nor = poser([R], p, (0, -1, 0))
        if loc is not None and nor.y < -0.3:
            clou(K, tuple(loc), nor, 0.0032, "acier_fil", rondelle=False)
    K.creer()


# ------------------------------------------------------------------ assemblage
def construire(ident):
    src_nom, genre = ARMES[ident]
    src, comps = composantes(os.path.join(SRC, src_nom + ".glb"))
    tris0 = sum(len(tous(c)) for c in comps)
    for n_ in MATS_Q:
        bpy.data.materials.get(n_) or bpy.data.materials.new(n_)
    {"hache": hache, "marteau": marteau, "masse": masse, "bouclier": bouclier}[genre](ident, src, comps)
    bpy.data.objects.remove(src)
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and len(o.data.polygons) == 0:
            bpy.data.objects.remove(o)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, src_nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    par = {}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            par[o.name] = par.get(o.name, 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
    tris = sum(par.values())
    print("QUATERNIUS_HD %s tris=%d -> %d pieces=%s" % (ident, tris0, tris, par))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, ident + ".blend"))
    return {"source": src_nom, "triangles_avant": tris0, "triangles": tris}


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
choix = [a for a in args if a in ARMES] or list(ARMES)
chemin_info = os.path.join(ICI, "quaternius_hd_info.json")
infos = json.load(open(chemin_info, encoding="utf-8")) if os.path.exists(chemin_info) else {}
for ident in choix:
    infos[ident] = construire(ident)
json.dump(infos, open(chemin_info, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
