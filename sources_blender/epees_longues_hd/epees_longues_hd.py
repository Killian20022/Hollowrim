# ÉPÉES LONGUES HD (branche armes/epees_longues_hd, demande du 2026-11-12 : refaire les six épées « maison » qui font encore jouet
# au niveau des lames HD v2, « en gardant leur forme d'origine ; raffine les lignes, fais ressortir les éléments, la brillance du
# shader ; avec 8 000 à 10 000 triangles ça peut être incroyable »).
# MÊME MÉTHODE que sources_blender/lames_hd/lames_hd_v2.py (silhouette d'origine conservée, détail HD par-dessus) :
#   lame    : MESURÉE sur le glb d'origine (assets/modeles/armes/epees/<v>.glb) par coupes (mesure_quaternius.py) à chaque hauteur de
#             sommet + tous les 1,5 cm -> bords et épaisseur exacts (crans de l'obsidienne compris) ; sections HD posées entre ces bords
#             (acier : fil, biseau secondaire, méplat, gouttière à fond creux ; cristal : facettes à arête tournante ; obsidienne :
#             biseaux à éclats conchoïdaux + bande de veine) ;
#   garde, pommeau, gemmes, fusée : la RECETTE d'origine (sources_blender/epees_longues/epees_longues.py) est REJOUÉE, chaque
#             primitive (barre, plaque, octaèdre, tour, poignée) étant remplacée par sa version HD AUX MÊMES PARAMÈTRES : même polygone
#             de section aux arêtes chanfreinées (les pans accrochent la lumière), stations subdivisées, gemmes taillées serties de
#             griffes, cuir enroulé en volume, viroles rivetées.
# Repères prise / garde / pointe : exactement ceux d'origine. Matériaux : noms d'origine suffixés « _hd » pour lame, lame_or, fer, or,
# rubis, verre, obsidienne (presets propres à ces six épées dans EpeesLongues.MATIERES) ; cuir, gemme, emeraude, veine, entrelacs
# inchangés.
#   blender.exe -b --python sources_blender/epees_longues_hd/epees_longues_hd.py -- [metal or rubis verre obsidienne skarnholt]
# Sortie : assets/modeles/armes/epees/hd/<v>.glb (l'original reste dans assets/modeles/armes/epees/<v>.glb).
import bpy, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
SB = os.path.dirname(ICI)
_v1 = open(os.path.join(SB, "lames_hd", "lames_hd.py"), encoding="utf-8").read().split('ARMES = {"epee_soldat"')[0]
_v1 = _v1.replace("ICI = os.path.dirname(os.path.abspath(__file__))", "ICI = %r" % os.path.join(SB, "lames_hd"))
exec(_v1)        # Maille, relier, pointe_sur, capuchon, vide, vider, MATS, Z_PRISE, tube, revol, fusee_enroulee, helice, ...
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SB, "lames_hd"))
import mesure_quaternius as mq
DEPOT = os.path.dirname(SB)
ORIGINE = os.path.join(DEPOT, "assets", "modeles", "armes", "epees")
SORTIE = os.path.join(ORIGINE, "hd")

# recette d'origine (fonctions epee_<v>) dans son propre espace de noms : on y remplace les primitives par les versions HD
_src = open(os.path.join(SB, "epees_longues", "epees_longues.py"), encoding="utf-8").read().split("\nVARIANTES = {")[0]
_src = _src.replace("ICI = os.path.dirname(os.path.abspath(__file__))", "ICI = %r" % os.path.join(SB, "epees_longues"))
ORIG = {"__name__": "recette"}
exec(_src, ORIG)
ELARGIR_, LARGE_, EPAIS_ = ORIG["ELARGIR"], ORIG["LARGE"], ORIG["EPAIS"]

GEMMES = ("gemme", "rubis", "emeraude", "veine", "verre", "saphir")
# par variante : matière des sertissures / viroles, matière de la lame, type de section, fils de la fusée
CONF = {
    "metal": {"serti": "fer", "lame": "acier", "fils": None},
    "or": {"serti": "or", "lame": "acier", "fils": "or"},
    "rubis": {"serti": "fer", "lame": "cristal", "fils": None},
    "verre": {"serti": "fer", "lame": "cristal", "fils": None},
    "obsidienne": {"serti": "obsidienne", "lame": "obsidienne", "fils": None},
    "skarnholt": {"serti": "entrelacs", "lame": "acier_large", "fils": None},
}
C = {}       # configuration de la variante en cours


def lerp(a, b, u):
    return a + (b - a) * u


# ------------------------------------------------------------------ chanfrein d'un polygone de section
def chanfrein(poly, k=0.14):
    """Chaque coin du polygone (y, z) devient deux sommets (arête chanfreinée) ; l'ensemble est remis à l'étendue d'origine."""
    n = len(poly)
    out = []
    for i in range(n):
        a, p, b = poly[i - 1], poly[i], poly[(i + 1) % n]
        out.append((p[0] + (a[0] - p[0]) * k, p[1] + (a[1] - p[1]) * k))
        out.append((p[0] + (b[0] - p[0]) * k, p[1] + (b[1] - p[1]) * k))
    for ax in (0, 1):     # même étendue que le polygone d'origine (silhouette conservée)
        o0, o1 = min(q[ax] for q in poly), max(q[ax] for q in poly)
        c0, c1 = min(q[ax] for q in out), max(q[ax] for q in out)
        if c1 - c0 > 1e-9:
            s = (o1 - o0) / (c1 - c0)
            out = [tuple(((q[j] - (c0 + c1) * 0.5) * s + (o0 + o1) * 0.5) if j == ax else q[j] for j in range(2)) for q in out]
    return out


# ------------------------------------------------------------------ primitives HD (mêmes signatures que la recette)
def barre_hd(m, stations, mat, z_centre, cotes=6, uv_l=2.0):
    """Barre transversale le long de X : mêmes stations (x, h, t, dz) et mêmes facteurs que barre(), linéaire entre stations
    (silhouette identique) mais subdivisée tous les 5 mm, section d'origine aux arêtes chanfreinées, bouts adoucis."""
    st = [(x * 1.25, h * 1.35, t * 1.35, dz * 1.25) for x, h, t, dz in stations]
    fin = []
    for a, b in zip(st, st[1:]):
        n = max(1, int(math.ceil(abs(b[0] - a[0]) / 0.005)))
        for k in range(n):
            u = k / n
            fin.append(tuple(lerp(a[i], b[i], u) for i in range(4)))
    fin.append(st[-1])
    anneaux = []
    for x, h, t, dz in fin:
        if cotes == 4:
            sec = [(0, -h), (t, 0), (0, h), (-t, 0)]
        else:
            sec = [(-t, -h * 0.55), (-t, h * 0.55), (0, h), (t, h * 0.55), (t, -h * 0.55), (0, -h)]
        anneaux.append([(x, y, z_centre + dz + z) for y, z in chanfrein(sec, 0.16)])
    x0, x1 = fin[0][0], fin[-1][0]

    def uv(p, k, i, mat_=None):
        return ((p[0] - x0) / (x1 - x0) * uv_l, i / len(anneaux[0]))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    # bouts : un anneau rentré (biseau du bout de quillon) puis le capuchon
    for bout, sgn in ((0, -1), (len(anneaux) - 1, 1)):
        a = anneaux[bout]
        cx = sum(p[1] for p in a) / len(a)
        cz = sum(p[2] for p in a) / len(a)
        ins = [(p[0] + sgn * 0.0012, cx + (p[1] - cx) * 0.62, cz + (p[2] - cz) * 0.62) for p in a]
        ri = relier(m, [a, ins] if sgn > 0 else [ins, a], lambda k, i: mat, uv)
        if sgn > 0:
            m.face(ri[-1], mat, [uv(p, 0, 0) for p in ins])
        else:
            capuchon(m, ri[0], ins, mat, uv)
    return anneaux


def bipyramide(m, c, rx, ry, rzh, rzb, mat, cotes=8, k_ch=0.18, dx_haut=0.0):
    """Losange 3D (plaque, langue, lobe, ergot) : sections losange (rx, ry) chanfreinées (8 pans), linéaires vers les deux pointes
    (silhouette = l'octaèdre d'origine), anneaux intermédiaires pour l'éclairage, pointes émoussées d'un fil."""
    cx, cy, cz = c
    los = chanfrein([(rx, 0.0), (0.0, ry), (-rx, 0.0), (0.0, -ry)], k_ch)
    fr = [-1.0, -0.62, -0.28, 0.0, 0.34, 0.68, 1.0]
    anneaux = []
    for f in fr[1:-1]:
        s = 1.0 - abs(f)
        z = cz + (f * rzh if f > 0 else f * rzb)
        dx = dx_haut * max(0.0, f)
        anneaux.append([(cx + dx + x * s, cy + y * s, z) for x, y in los])

    def uv(p, k, i, mat_=None):
        return (0.5 + 0.5 * (p[0] - cx) / max(rx, 1e-6), 0.5 + 0.5 * (p[2] - cz) / max(rzh, rzb, 1e-6))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (cx + dx_haut, cy, cz + rzh), lambda i: mat, uv, (0.5, 1.0))
    t = m.sommet((cx, cy, cz - rzb))
    n = len(ids[0])
    for i in range(n):
        j = (i + 1) % n
        m.face([ids[0][j], ids[0][i], t], mat, [uv(anneaux[0][j], 0, j), uv(anneaux[0][i], 0, i), (0.5, 0.0)])


def gemme_taillee(m, c, rx, ry, rzh, rzb, mat):
    """Gemme taillée à la place de l'octaèdre d'origine (même enveloppe : rondiste à rx / ry, pointes à rzh / rzb) : rondiste à
    16 pans, couronne à 8 facettes décalées, table plate, culasse en étoile ; quatre griffes de sertissure (matière du serti)."""
    cx, cy, cz = c
    n = 16

    def ell(s, rot=0.0, cnt=n):
        return [(cx + rx * s * math.cos(rot + TAU * j / cnt), cy + ry * s * math.sin(rot + TAU * j / cnt)) for j in range(cnt)]
    # rondiste (deux anneaux très proches), couronne, table ; culasse
    profil = [(-0.55, 0.45, 0.0), (-0.04, 0.98, 0.0), (0.04, 0.98, 0.0), (0.42, 0.62, math.pi / n), (0.80, 0.24, 0.0)]
    anneaux = []
    for f, s, rot in profil:
        z = cz + (f * rzh if f > 0 else f * rzb)
        anneaux.append([(x, y, z) for x, y in ell(s, rot)])

    def uv(p, k, i, mat_=None):
        return (0.5 + 0.5 * (p[0] - cx) / rx, 0.5 + 0.5 * (p[2] - cz) / max(rzh, rzb))
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    # table (haut) : éventail vers un sommet central un peu relevé ; pointe de culasse (bas)
    pointe_sur(m, ids[-1], anneaux[-1], (cx, cy, cz + rzh), lambda i: mat, uv, (0.5, 1.0))
    t = m.sommet((cx, cy, cz - rzb))
    for i in range(n):
        j = (i + 1) % n
        m.face([ids[0][j], ids[0][i], t], mat, [uv(anneaux[0][j], 0, j), uv(anneaux[0][i], 0, i), (0.5, 0.0)])
    # griffes : petits losanges posés sur le rondiste, aux quatre points cardinaux (dans l'enveloppe d'origine)
    serti = C.get("serti", "fer")
    for a in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
        px, py = cx + rx * 0.93 * math.cos(a), cy + ry * 0.93 * math.sin(a)
        bipyramide(m, (px, py, cz), min(rx, ry) * 0.16, min(rx, ry) * 0.16, max(rzh, rzb) * 0.30, max(rzh, rzb) * 0.22, serti,
                   k_ch=0.2)


def octaedre_hd(m, c, rx, ry, rz_haut, rz_bas, mat, dx_haut=0.0):
    if mat in GEMMES:
        gemme_taillee(m, c, rx, ry, rz_haut, rz_bas, mat)
    else:
        bipyramide(m, c, rx, ry, rz_haut, rz_bas, mat, dx_haut=dx_haut)


def plaque_hd(m, c, rx, ry, rz_haut, rz_bas, mat):
    """Langue de garde : mêmes facteurs que plaque() ; bipyramide chanfreinée + nervure médiane en relief sur les deux faces."""
    cc = (c[0] * 1.25, c[1], c[2])
    RX, RY, RH, RB = rx * 1.6, ry * 1.3, rz_haut * 1.3, rz_bas * 1.3
    bipyramide(m, cc, RX, RY, RH, RB, mat)


def catmull(profil, sub=4):
    """Profil (z, r) lissé (Catmull-Rom passant par les points d'origine)."""
    if len(profil) < 3:
        return list(profil)
    P = [profil[0]] + list(profil) + [profil[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for s in range(sub):
            t = s / sub
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 +
                                    (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    out.append(profil[-1])
    lo, hi = min(p[1] for p in profil), max(p[1] for p in profil)
    return [(z, min(hi, max(lo * 0.9, r))) for z, r in out]


def tour_hd(m, profil, mat, cotes=8, ecrase_y=1.0, bas=None, haut=None, rot=0.0, uv_tours=2.0, mat_de=None):
    """tour() d'origine : même polygone (cotes, rot, écrasement) aux arêtes chanfreinées, profil lissé passant par les points
    d'origine, pointes conservées (subdivisées)."""
    sec0 = [(math.cos(rot + TAU * i / cotes), ecrase_y * math.sin(rot + TAU * i / cotes)) for i in range(cotes)]
    sec = chanfrein(sec0, 0.15 if cotes <= 6 else 0.2)
    profil = sorted(profil)          # certaines recettes donnent le profil du haut vers le bas : la pointe va au bout le plus bas
    prof = catmull(profil, 4)
    if bas is not None:   # cône vers la pointe basse, subdivisé
        z0, r0 = prof[0]
        prof = [(lerp(bas, z0, u), r0 * u) for u in (0.18, 0.45, 0.75)] + prof
    if haut is not None:
        z1, r1 = prof[-1]
        prof = prof + [(lerp(z1, haut, u), r1 * (1 - u)) for u in (0.25, 0.55, 0.82)]
    anneaux = [[(r * x, r * y, z) for x, y in sec] for z, r in prof]
    zA, zB = prof[0][0], prof[-1][0]
    nv = len(sec)

    def uv(p, k, i, mat_=None):
        return (i / nv * uv_tours, (p[2] - zA) / max(1e-6, zB - zA))
    md = mat_de or (lambda k, i: mat)
    ids = relier(m, anneaux, lambda k, i: md(0, 0), uv)
    if bas is not None:
        t = m.sommet((0, 0, bas))
        for i in range(nv):
            j = (i + 1) % nv
            m.face([ids[0][j], ids[0][i], t], md(0, 0), [uv(anneaux[0][j], 0, j), uv(anneaux[0][i], 0, i), (0.5, 0)])
    else:
        capuchon(m, ids[0], anneaux[0], md(0, 0), uv)
    if haut is not None:
        pointe_sur(m, ids[-1], anneaux[-1], (0, 0, haut), lambda i: md(0, 0), uv, (0.5, 1.0))
    else:
        m.face(ids[-1], md(0, 0), [uv(p, len(anneaux) - 1, 0) for p in anneaux[-1]])


def virole(m, z0, z1, r, ry, mat, rivets=True, cotes=24):
    prof = [(z0, 0.99), (z0 + 0.0012, 1.06), (z1 - 0.0012, 1.06), (z1, 0.99)]
    an = [[(r * s * math.cos(TAU * j / cotes), ry * s * math.sin(TAU * j / cotes), z) for j in range(cotes)] for z, s in prof]
    relier(m, an, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes * 2, k / 3))
    if rivets:
        zc = (z0 + z1) * 0.5
        for sg in (1, -1):
            bipyramide(m, (0.0, sg * ry * 1.07, zc), 0.0016, 0.0009, 0.0016, 0.0016, mat, k_ch=0.25)


def poignee_hd(m, z0, z1, r, mat="cuir"):
    """Poignée d'origine (r, 1,08 r à 30 %, 1,03 r à 62 %, r ; écrasée 0,9) : cuir ENROULÉ en volume (lanière en hélice qui se
    chevauche, sommets de lanière = rayon d'origine), viroles rivetées aux deux bouts, fils d'or croisés pour l'épée en or."""
    L = z1 - z0
    cotes, n = 20, 34
    tours = L / 0.0125
    anneaux = []
    zs, rs = [z0, z0 + L * 0.3, z0 + L * 0.62, z1], [r, r * 1.08, r * 1.03, r]

    def base(z):
        for a in range(3):
            if zs[a] <= z <= zs[a + 1]:
                u = (z - zs[a]) / (zs[a + 1] - zs[a])
                u = u * u * (3 - 2 * u)
                return lerp(rs[a], rs[a + 1], u)
        return r
    for k in range(n + 1):
        u = k / n
        z = z0 + L * u
        a = []
        for j in range(cotes):
            f = TAU * j / cotes
            ph = (f / TAU - tours * u) % 1.0
            dent = ph / 0.84 if ph < 0.84 else (1.0 - ph) / 0.16
            rr = base(z) * (0.93 + 0.07 * dent)
            a.append((rr * math.cos(f), rr * 0.9 * math.sin(f), z))
        anneaux.append(a)
    relier(m, anneaux, lambda k, i: mat, lambda p, k, i, m_=None: (i / cotes * 2.0, k / n * 3.0))
    serti = C.get("serti", "fer")
    if serti != "entrelacs":          # skarnholt : ses bagues de bronze sont déjà dans la recette
        virole(m, z0 - 0.001, z0 + 0.0075, r * 0.99, r * 0.9 * 0.99, serti)
        virole(m, z1 - 0.0075, z1 + 0.001, r * 0.99, r * 0.9 * 0.99, serti)
    if C.get("fils"):
        helice(m, z0 + 0.009, z1 - 0.009, r * 0.985, tours * 0.5, C["fils"], ep=0.0009, ecrase=0.9, renfle=0.05, seg=6, cotes=4)
        helice(m, z0 + 0.009, z1 - 0.009, r * 0.985, -tours * 0.5, C["fils"], ep=0.0008, ecrase=0.9, renfle=0.05, seg=6, cotes=4)


# ------------------------------------------------------------------ lame : coupes du glb d'origine + sections HD
def coupes_origine(nom):
    """Triangles de la LAME d'origine (objet « lame » du glb) -> stations (z, x_min, x_max, demi-épaisseur), pointe."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ORIGINE, nom + ".glb"))
    tris = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.startswith("lame"):
            continue
        me = o.data
        me.calc_loop_triangles()
        M = o.matrix_world
        for t in me.loop_triangles:
            tris.append([tuple(M @ me.vertices[v].co) for v in t.vertices])
    z0, z1 = mq.etendue(tris, 2)
    zs = set(round(z, 5) for z in mq.sommets_z(tris, z0 + 1e-4, z1 - 1e-4))
    zs |= set(round(z0 + 0.015 * k, 5) for k in range(1, int((z1 - z0) / 0.015)))
    zs.add(round(z0 + 1e-4, 5))
    zs = sorted(z for z in zs if z < z1 - 0.003)
    # les crans (obsidienne) : une coupe juste avant et juste après chaque saut de largeur
    st = []
    for z, r in mq.profil(tris, 2, zs):
        if r is not None and r[0][1] - r[0][0] > 0.0015:
            st.append((z, r[0][0], r[0][1], max(abs(r[1][0]), abs(r[1][1]))))
    pts = [p for t in tris for p in t]
    haut = max(pts, key=lambda p: p[2])
    return st, (haut[0], haut[2]), len(tris)


def section_acier(w, t, g, large=False):
    """Demi-section haute de +w à -w : fil (micro-biseau), biseau secondaire bombé, méplat, gouttière à flancs nets et fond creux."""
    e = min(0.0014, 0.09 * w)
    gw = (0.33 if large else 0.25) * w
    d = t * (1.0 - 0.46 * g)
    dr = [(w, 0.0), (w - e, 0.24 * t), (0.86 * w, 0.58 * t), (0.74 * w, 0.86 * t), (0.62 * w, t), (gw + 0.05 * w, t),
          (gw, lerp(t, d, 0.55)), (gw * 0.8, d * 1.04), (gw * 0.4, d * 1.01)]
    return dr + [(0.0, d)] + [(-x, y) for x, y in reversed(dr)]


def section_cristal(w, t, dx, z):
    """Lame cristalline : facettes en gradins vers une arête décalée (dx), légère torsion des facettes avec la hauteur."""
    # gradins : tous les ~4 cm la ligne de facettes saute (cristal qui a poussé par couches), facettes en zigzag
    ph = (z / 0.042) % 1.0
    tw = 0.11 * (ph * 2.0 - 1.0 if int(z / 0.042) % 2 == 0 else 1.0 - ph * 2.0)
    dr = [(w, 0.0), (0.90 * w, 0.20 * t), (0.70 * w + tw * w, 0.56 * t), (0.46 * w - 0.5 * tw * w, 0.78 * t),
          (0.22 * w + dx * 0.5, 0.96 * t)]
    ga = [(-0.20 * w + dx * 0.5, 0.95 * t), (-0.44 * w + 0.5 * tw * w, 0.76 * t), (-0.68 * w + tw * w, 0.54 * t), (-0.89 * w, 0.22 * t),
          (-w, 0.0)]
    return dr + [(dx, t)] + ga


def section_obsidienne(w, t, z):
    """Obsidienne : biseaux à ÉCLATS (ligne de biseau festonnée, comme une lame taillée par percussion) et bande centrale de veine."""
    fe = abs(math.sin(z * math.pi / 0.021))           # festons de 2,1 cm
    fe2 = abs(math.sin(z * math.pi / 0.021 + 1.3))
    v = 0.16 * w
    dr = [(w, 0.0), (0.93 * w, 0.22 * t), (0.78 * w - 0.05 * w * fe, (0.55 + 0.12 * fe) * t), (0.55 * w + 0.04 * w * fe, t),
          (v + 0.03 * w, t), (v, 1.05 * t)]
    ga = [(-v, 1.05 * t), (-v - 0.03 * w, t), (-0.55 * w - 0.04 * w * fe2, t), (-0.78 * w + 0.05 * w * fe2, (0.55 + 0.12 * fe2) * t),
          (-0.93 * w, 0.22 * t), (-w, 0.0)]
    return dr + [(0.0, 1.07 * t)] + ga


def facettes_cristal(m, anneaux, infos, mat, z0, L):
    """Lame cristalline : chaque FACETTE (bande de quads entre deux arêtes, coupée en gradins tous les ~4 cm) lit sa propre région
    de la texture de cristal (UV discontinues d'une facette à l'autre) : les facettes se lisent comme des plans taillés distincts,
    en plus de leur éclairage propre."""
    n = len(anneaux[0])
    ids = [[m.sommet(p) for p in a] for a in anneaux]
    for k in range(len(anneaux) - 1):
        gr = int((anneaux[k][0][2] + anneaux[k + 1][0][2]) * 0.5 / 0.042)
        for i in range(n):
            j = (i + 1) % n
            q = [ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]]
            pts = [anneaux[k][i], anneaux[k][j], anneaux[k + 1][j], anneaux[k + 1][i]]
            h = ((i * 7 + gr * 3) * 0.6180339) % 1.0
            uvs = []
            for c_, p in enumerate(pts):
                kk = k + (1 if c_ >= 2 else 0)
                c, w = infos[min(kk, len(infos) - 1)]
                loc = 1.0 if c_ in (1, 2) else 0.0
                uvs.append(((h * 0.75 + loc * 0.22) % 1.0, h * 0.5 + (p[2] - z0) / L * 0.8))
            m.face(q, mat, uvs)
    return ids


def lame_hd(m, prof, z0, z_pointe, section, mat_de, w_ref, sym_dx=None, elargir=None):
    """Remplace lame() : bords et épaisseur MESURÉS sur le glb d'origine (coupes), sections HD de la matière de la variante."""
    st = C["coupes"]
    zt = C["pointe"][1]
    L = zt - z0
    mat = mat_de(0, 0)
    typ = C["lame"]
    dxs = [(p[0], p[3] if len(p) > 3 else 0.0) for p in prof]       # arête décalée de la recette (cristal)
    z_band = prof[-1][0]

    def dx_at(z):
        for a, b in zip(dxs, dxs[1:]):
            if a[0] <= z <= b[0]:
                return lerp(a[1], b[1], (z - a[0]) / (b[0] - a[0]))
        return dxs[-1][1] if z > dxs[-1][0] else dxs[0][1]
    anneaux, infos, mats = [], [], []
    for z, a, b, t in st:
        c, w = (a + b) * 0.5, (b - a) * 0.5
        f = (z - z0) / L
        g = min(1.0, max(0.0, f / 0.03)) * (1.0 if f < 0.66 else max(0.0, 1.0 - (f - 0.66) / 0.14))
        if typ in ("acier", "acier_large"):
            haut = section_acier(w, t, g, typ == "acier_large")
        elif typ == "cristal":
            haut = section_cristal(w, t, max(-0.25 * w, min(0.25 * w, dx_at(z))), z)
        else:
            haut = section_obsidienne(w, t, z)
        bas = [(x, -y) for x, y in reversed(haut[1:-1])]
        ring = haut + bas
        anneaux.append([(c + x, y, z) for x, y in ring])
        infos.append((c, w))
    nh = len(anneaux[0]) // 2 + 1                     # sommets de la demi-section haute
    if typ == "obsidienne":
        # bande de veine : quads entre (v, 1,05 t) et (-v, 1,05 t), dessus et dessous (indices 5,6 et symétriques)
        haut_idx = {5, 6}
        n = len(anneaux[0])
        bande = haut_idx | {n - 1 - i for i in haut_idx}
        zb = [s[0] for s in st]

        def md(k, i):
            return "veine" if (i in bande and zb[min(k, len(zb) - 1)] < z_band) else mat
    else:
        def md(k, i):
            return mat

    def uv(p, k, i, mat_=None):
        k = min(k, len(infos) - 1)
        c, w = infos[k]
        v = max(0.0, (p[2] - z0) / L)
        if mat_ == "veine":
            return ((p[0] - c) / (0.16 * w) * 0.5 + 0.5, v)
        return (0.5 + 0.5 * (p[0] - c) / w, v)
    if typ == "cristal":
        ids = facettes_cristal(m, anneaux, infos, mat, z0, L)
    else:
        ids = relier(m, anneaux, md, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (C["pointe"][0], 0.0, zt), lambda i: mat, uv, (0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat, uv)


# primitives HD posées dans l'espace de noms de la recette
ORIG.update({"barre": barre_hd, "plaque": plaque_hd, "octaedre": octaedre_hd, "tour": tour_hd, "poignee": poignee_hd,
             "lame": lame_hd, "Maille": Maille})
RECETTES = {"metal": "epee_metal", "or": "epee_or", "rubis": "epee_rubis", "verre": "epee_verre", "obsidienne": "epee_obsidienne",
            "skarnholt": "epee_skarnholt"}


def reperes_origine(nom):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ORIGINE, nom + ".glb"))
    rep = {}
    for o in bpy.data.objects:
        if o.type == 'EMPTY' and o.name.split(".")[0] in ("prise", "garde", "pointe"):
            rep[o.name.split(".")[0]] = tuple(o.matrix_world.translation)
    return rep


SUFFIXE_HD = ("lame", "lame_or", "fer", "or", "rubis", "verre", "obsidienne")


def construire(nom):
    C.clear()
    C.update(CONF[nom])
    rep = reperes_origine(nom)
    C["coupes"], C["pointe"], tris0 = coupes_origine(nom)
    vider()
    for n_ in MATS:
        bpy.data.materials.new(n_)
    ORIG[RECETTES[nom]]()
    for k, p in rep.items():           # repères exactement ceux d'origine
        o = vide(k, p[2])
        o.location = p
    for mt in bpy.data.materials:      # matières HD propres à ces six épées (EpeesLongues : *_hd), le reste du jeu inchangé
        if mt.name in SUFFIXE_HD:
            mt.name = mt.name + "_hd"
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris, par, zmin, zmax = 0, {}, 9.0, -9.0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            t = sum(len(q.vertices) - 2 for q in o.data.polygons)
            par[o.name] = t
            tris += t
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
    print("EPEE_HD %s tris=%d (%.3f -> %.3f) reperes=%s pieces=%s" % (nom, tris, zmin, zmax,
          {k: tuple(round(c, 4) for c in v) for k, v in rep.items()}, par))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, nom + "_hd.blend"), compress=True)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nom in [a for a in args if a in CONF] or list(CONF):
    construire(nom)
