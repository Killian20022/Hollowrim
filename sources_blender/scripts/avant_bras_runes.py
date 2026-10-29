# Avant-bras FPS « runes » (références Jeux/references/avant_bras_magie/bras_*_1100.jpg) : modèle COMMUN à tous les
# équipements (épée, torche, bouclier, sorts, main vide). Sur le squelette d'origine (aucun os ajouté, aucun os déplacé :
# les clips bras_epee.tres / bras_finishers.tres et les IK restent valables), on remplace les gants, brassards, sangles et
# revers par un seul maillage par bras, rangé par matières :
#   ab_gant      gant de cuir noir-brun : paume en coque, 5 doigts en tubes à 3 phalanges (chaque phalange pondérée sur son
#                os, jointures renflées, mi-poids aux articulations : les doigts plient vraiment), revers évasé au poignet
#   ab_cuir      coque du brassard (cuir épais, coutures)          ab_tresse  6 tours de cuir tressé en spirale + bracelet
#   ab_metal     plaque nordique gravée (losanges runiques) sur l'avant-bras et sur le dos de la main
#   ab_fer       rivets, boucles, clous du bracelet, bagues de jointure        ab_sangle  2 sangles à boucle
#   ab_fourrure  manchette de fourrure grise et blanche côté coude, en mèches (pyramides) sur 3 rangs
# Couleurs de sommet (alpha 1) : occlusion des creux (base des tours, dessous des doigts, pied des mèches), pointes de
# fourrure plus claires — ps1.gdshader multiplie la texture par COLOR.rgb.
#   blender.exe -b --python avant_bras_runes.py        (exporte sources_blender/bras_fps_avant_torsion.glb depuis
#   sources_blender/bras_fps_skarnholt.glb ; puis os_torsion_bras.py ajoute les os de torsion -> bras_fps.glb). Matières habillées par AvantBras (scripts/avant_bras.gd).
import bpy, bmesh, math, os, shutil
from mathutils import Vector

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
# sortie : l'état SANS os de torsion, source de os_torsion_bras.py (qui produit bras_fps.glb, os de torsion compris)
SORTIE = os.path.join(base, "sources_blender", "bras_fps_avant_torsion.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_skarnholt.glb")
if not os.path.exists(SAUVE):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
GARDE = ("manches", "peau_bras")
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name not in GARDE:
        bpy.data.objects.remove(o)
obj = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
# manches et sous-couche : on ne garde que le bras (|x| < COUPE) ; l'avant-bras est entièrement couvert par le brassard
# (tube fermé) et le gant. Sans cela, la manche ample (rayon ~0,1 m) gonflait le brassard à 24 cm de diamètre.
COUPE = 0.472
for nom in GARDE:
    o = obj.get(nom)
    if o is None:
        continue
    bm0 = bmesh.new()
    bm0.from_mesh(o.data)
    bmesh.ops.delete(bm0, geom=[v for v in bm0.verts if abs(v.co.x) > COUPE], context='VERTS')
    bm0.to_mesh(o.data)
    bm0.free()
MATS = ["ab_gant", "ab_cuir", "ab_tresse", "ab_metal", "ab_fer", "ab_sangle", "ab_fourrure"]
TAU = 2 * math.pi


def h(i, j):
    x = (i * 73856093) ^ (j * 19349663)
    x = (x ^ (x >> 13)) * 1274126177
    return ((x ^ (x >> 16)) & 0xffff) / 65535.0


class Maille:
    """Maillage d'UN bras (repère du bras GAUCHE, +x vers la main ; le droit est son miroir)."""
    def __init__(self):
        self.v, self.w, self.c, self.f = [], [], [], []   # sommets, poids [(os, w)], couleurs, faces (indices, uvs, mat)

    def sommet(self, p, poids, col=1.0):
        self.v.append(Vector(p))
        self.w.append(poids)
        self.c.append(col if isinstance(col, tuple) else (col, col, col))
        return len(self.v) - 1

    def face(self, idx, uvs, mat, lisse=True):
        self.f.append((idx, uvs, MATS.index(mat), lisse))


def os_(n, c="l"):
    return arm.data.bones[n + "_" + c]


# ------------------------------------------------------------------ axe et rayon de l'avant-bras (os lowerarm)
LA = os_("lowerarm")
A0, A1 = LA.head_local.copy(), LA.tail_local.copy()


def centre(u):
    k = (u - A0.x) / (A1.x - A0.x)
    return A0 + (A1 - A0) * k


def _profil():
    pts = []
    for nom in ("manches", "peau_bras"):
        o = obj.get(nom)
        if o:
            pts += [v.co.copy() for v in o.data.vertices if v.co.x > 0]
    def rayon(u):
        c = centre(u)
        rs = [math.hypot(p.y - c.y, p.z - c.z) for p in pts if abs(p.x - u) < 0.012]
        return max(rs) if rs else 0.045
    tab = {round(0.40 + i * 0.005, 3): rayon(0.40 + i * 0.005) for i in range(80)}
    def r(u):
        k = min(max(round(round(u / 0.005) * 0.005, 3), 0.40), 0.795)
        return tab.get(k, 0.045)
    return r


R_PEAU = _profil()


def r_base(u):
    """Rayon du brassard (cuir épais sur l'avant-bras) : 7,0 cm au coude, 4,8 cm au poignet, galbe du muscle côté coude
    (passe 3 : avant-bras massifs des références, +20 %)."""
    k = min(max((u - 0.46) / (0.70 - 0.46), 0.0), 1.0)
    return 0.070 - 0.022 * k ** 1.4 + 0.0036 * math.sin(math.pi * min(k * 1.6, 1.0))


def poids_avant_bras(x):
    k = min(max((x - 0.690) / 0.03, 0.0), 1.0) * 0.45
    if x < 0.49:
        k2 = min(max((0.49 - x) / 0.04, 0.0), 1.0) * 0.3
        return [("lowerarm_l", 1.0 - k2), ("upperarm_l", k2)]
    return [("lowerarm_l", 1.0 - k), ("hand_l", k)] if k > 0 else [("lowerarm_l", 1.0)]


def anneau_tube(m, stations, mat, seg, a0=0.0, a1=TAU, ferme=True, rep_u=1.0, poids=poids_avant_bras, col=None,
                bruit=None, lisse=True, axe=None):
    """Tube autour de l'avant-bras. stations = [(x, rayon, v)] ; angle 0 = dessus (+z, dos), +pi/2 = côté pouce (-y)."""
    n = seg if ferme else seg + 1
    ids = []
    for k, (x, r, vv) in enumerate(stations):
        c = centre(x) if axe is None else axe(x)
        rang = []
        for i in range(n):
            a = a0 + (a1 - a0) * i / seg
            rr = r + (bruit(i, k) if bruit else 0.0)
            p = (x, c.y - rr * math.sin(a), c.z + rr * math.cos(a))
            cc = col(i, k) if col else 1.0
            rang.append(m.sommet(p, poids(x), cc))
        ids.append(rang)
    for k in range(len(stations) - 1):
        for i in range(seg):
            j = (i + 1) % n if ferme else i + 1
            u0 = i / seg * rep_u
            u1 = (i + 1) / seg * rep_u
            v0, v1 = stations[k][2], stations[k + 1][2]
            m.face([ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat, lisse)
    return ids


def disque(m, rang, centre_p, poids, mat, col=1.0):
    """Ferme un anneau par un éventail (bout de doigt, fond de tube)."""
    c = m.sommet(centre_p, poids, col)
    n = len(rang)
    for i in range(n):
        m.face([rang[i], rang[(i + 1) % n], c], [(i / n, 0.0), ((i + 1) / n, 0.0), (0.5, 0.5)], mat)


def repere(d, haut=Vector((0, 0, 1))):
    d = d.normalized()
    up = (haut - d * haut.dot(d)).normalized()
    return d, up, d.cross(up).normalized()


def rivet(m, p, n, r, mat="ab_fer", poids=None, haut=0.0035, seg=6):
    n = n.normalized()
    t1 = n.cross(Vector((1, 0, 0)))
    if t1.length < 0.1:
        t1 = n.cross(Vector((0, 1, 0)))
    t1.normalize()
    t2 = n.cross(t1)
    ap = m.sommet(p + n * haut, poids, 1.3)
    rg = [m.sommet(p + (t1 * math.cos(TAU * q / seg) + t2 * math.sin(TAU * q / seg)) * r, poids, 0.5) for q in range(seg)]
    for q in range(seg):
        m.face([rg[q], rg[(q + 1) % seg], ap], [(0.2, 0.2), (0.8, 0.2), (0.5, 0.9)], mat, False)


def point_tube(x, a, r):
    c = centre(x)
    return Vector((x, c.y - r * math.sin(a), c.z + r * math.cos(a))), Vector((0, -math.sin(a), math.cos(a)))


# ============================================================================== construction d'un bras (gauche)
def construire(var):
    """var : 0 = gauche, 1 = droite (petites différences de décor : gauche ≠ droite, comme sur les références)."""
    m = Maille()
    # ---------------------------------------------------------------- 1. coque du brassard (cuir épais à pans)
    xs = [0.468, 0.48, 0.50, 0.53, 0.56, 0.59, 0.62, 0.65, 0.675, 0.69, 0.70]
    st = [(x, r_base(x), (x - 0.468) * 9.0) for x in xs]
    anneau_tube(m, st, "ab_cuir", 18, rep_u=2.0, col=lambda i, k: 0.85 + 0.15 * h(i, k + 7))

    # ---------------------------------------------------------------- 2. tours de cuir tressé en spirale (6) + bracelet
    # passe 4 : rouleaux remontés jusque sous la main (plus de talon de gant lisse entre eux et la paume)
    # (3 tours seulement : la plaque gravée et la fourrure tiennent dans le coin bas, bras_feu_1100.jpg)
    tours = [0.665, 0.678, 0.691]
    if var == 1:
        tours = [0.663, 0.676, 0.690]
    for n_t, x0 in enumerate(tours):
        pente = 0.0025 * (1 if (n_t + var) % 2 == 0 else -1)    # tours inclinés : enroulement, pas des anneaux plats
        def axe_t(x, x0=x0):
            return centre(x0)
        seg, sec = 22, 5
        ep = 0.0058
        anneaux = []
        for i in range(seg):
            a = TAU * i / seg
            xc = x0 + pente * math.cos(a)
            rr = r_base(xc) + 0.0015
            p0, nrm = point_tube(xc, a, rr)
            rang = []
            for q in range(sec):
                b = TAU * q / sec
                off = nrm * (math.cos(b) * ep + ep * 0.6) + Vector((1, 0, 0)) * math.sin(b) * ep * 1.15
                ao = 0.38 + 0.87 * max(math.cos(b), 0.0) ** 1.5   # arête claire, creux sombre entre les tours
                rang.append(m.sommet(p0 + off, poids_avant_bras(xc), ao))
            anneaux.append(rang)
            if i % 2 == (n_t + var) % 2:
                # clou de fer sur l'arête du tour (références : rouleaux cloutés)
                rivet(m, p0 + nrm * ep * 1.6, nrm, 0.0026, poids=poids_avant_bras(xc), haut=0.0032, seg=5)
        for i in range(seg):
            j = (i + 1) % seg
            for q in range(sec):
                r_ = (q + 1) % sec
                m.face([anneaux[i][q], anneaux[j][q], anneaux[j][r_], anneaux[i][r_]],
                       [(i / seg * 6, q / sec), ((i + 1) / seg * 6, q / sec), ((i + 1) / seg * 6, (q + 1) / sec), (i / seg * 6, (q + 1) / sec)],
                       "ab_tresse")
    # bracelet du poignet : bourrelet épais + 10 clous de fer
    xb = 0.701
    st = [(xb - 0.012, r_base(xb) + 0.002, 0.0), (xb - 0.008, r_base(xb) + 0.011, 0.3), (xb + 0.006, r_base(xb) + 0.012, 0.7),
          (xb + 0.012, r_base(xb) + 0.003, 1.0)]
    anneau_tube(m, st, "ab_tresse", 20, rep_u=5.0, col=lambda i, k: 0.6 if k in (0, 3) else 1.0)
    for q in range(10):
        a = TAU * (q + 0.5 * var) / 10
        p, nrm = point_tube(xb - 0.001, a, r_base(xb) + 0.012)
        rivet(m, p, nrm, 0.0035, poids=poids_avant_bras(xb), haut=0.004)

    # ---------------------------------------------------------------- 3. plaque nordique gravée (dessus, côté coude)
    pu0, pu1 = (0.598, 0.656) if var == 0 else (0.600, 0.657)   # passe 4 : plus près du poignet, dans le cadre
    pa = math.radians(74)                      # demi-ouverture
    a_c = math.radians(-12 if var == 0 else 12)   # un peu tournée vers l'extérieur
    lignes = [(pu0, 0.0045, 0.0), (pu0 + 0.004, 0.0080, 0.04), (pu1 - 0.004, 0.0080, 0.96), (pu1, 0.0045, 1.0)]
    # surface gravée : grille 8 x 4 (UV 0..1 = un panneau de la texture)
    seg = 8
    ids = []
    for (x, d, vv) in lignes:
        rang = []
        for i in range(seg + 1):
            a = a_c - pa + 2 * pa * i / seg
            p, nrm = point_tube(x, a, r_base(x) + d)
            rang.append(m.sommet(p, poids_avant_bras(x), 1.0))
        ids.append(rang)
    for k in range(3):
        for i in range(seg):
            v0 = lignes[k][2]
            v1 = lignes[k + 1][2]
            m.face([ids[k][i], ids[k][i + 1], ids[k + 1][i + 1], ids[k + 1][i]],
                   [(i / seg, v0), ((i + 1) / seg, v0), ((i + 1) / seg, v1), (i / seg, v1)], "ab_metal", False)
    # tranches latérales de la plaque (épaisseur)
    for bord in (0, seg):
        a = a_c - pa + 2 * pa * bord / seg
        bas = [m.sommet(point_tube(x, a, r_base(x) + 0.001)[0], poids_avant_bras(x), 0.5) for (x, d, vv) in lignes]
        for k in range(3):
            q = [ids[k][bord], ids[k + 1][bord], bas[k + 1], bas[k]]
            m.face(q if bord == 0 else q[::-1], [(0, 0), (0, 0.05), (0.02, 0.05), (0.02, 0)], "ab_fer", False)
    for x in (pu0, pu1):
        q0 = ids[0] if x == pu0 else ids[3]
        bas = [m.sommet(point_tube(x, a_c - pa + 2 * pa * i / seg, r_base(x) + 0.001)[0], poids_avant_bras(x), 0.5) for i in range(seg + 1)]
        for i in range(seg):
            q = [q0[i], bas[i], bas[i + 1], q0[i + 1]]
            m.face(q if x == pu0 else q[::-1], [(0, 0), (0, 0.05), (0.02, 0.05), (0.02, 0)], "ab_fer", False)
    for x in (pu0 + 0.008, pu1 - 0.008):
        for s_ in (-1, 1):
            a = a_c + s_ * (pa - math.radians(9))
            p, nrm = point_tube(x, a, r_base(x) + 0.0082)
            rivet(m, p, nrm, 0.0034, poids=poids_avant_bras(x), haut=0.003)

    # ---------------------------------------------------------------- 4. deux sangles (par-dessus la plaque) + boucles
    for n_s, x in enumerate((pu0 + 0.018, pu1 - 0.018)):
        st = [(x - 0.0065, r_base(x) + 0.0075, 0.0), (x - 0.005, r_base(x) + 0.0105, 0.25), (x + 0.005, r_base(x) + 0.0105, 0.75),
              (x + 0.0065, r_base(x) + 0.0075, 1.0)]
        anneau_tube(m, st, "ab_sangle", 20, rep_u=4.0, col=lambda i, k: 0.7 if k in (0, 3) else 1.0, lisse=False)
        a = math.radians(102) * (1 if (n_s + var) % 2 == 0 else -1)   # boucle d'un côté puis de l'autre
        p, nrm = point_tube(x, a, r_base(x) + 0.0112)
        t = Vector((1, 0, 0))
        b = nrm.cross(t)
        # cadre de boucle : 4 barres (rectangle évidé)
        for (cx, cy, dx, dy) in ((0, 0.0085, 0.0085, 0.0018), (0, -0.0085, 0.0085, 0.0018), (0.0072, 0, 0.0016, 0.0085), (-0.0072, 0, 0.0016, 0.0085)):
            c0 = p + t * cx + b * cy
            vs = []
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (0, 1):
                        vs.append(m.sommet(c0 + t * dx * sx + b * dy * sy + nrm * 0.0028 * sz, poids_avant_bras(x), 1.0 if sz else 0.6))
            for q in ([1, 3, 7, 5], [0, 4, 6, 2], [4, 5, 7, 6], [0, 2, 3, 1], [2, 6, 7, 3], [0, 1, 5, 4]):
                m.face([vs[i] for i in q], [(0, 0), (1, 0), (1, 1), (0, 1)], "ab_fer", False)
        # ardillon
        rivet(m, p + nrm * 0.001, nrm, 0.0022, poids=poids_avant_bras(x), haut=0.004, seg=4)

    # ---------------------------------------------------------------- 5. manchette de fourrure grise et blanche (coude)
    F0 = 0.548     # manchette au milieu de l'avant-bras (passe 4 : remontée, dans le coin bas comme sur les références)
    st = [(F0, r_base(F0) - 0.004, 0.0), (F0 + 0.012, r_base(F0) + 0.012, 0.3), (F0 + 0.030, r_base(F0 + 0.03) + 0.014, 0.7),
          (F0 + 0.046, r_base(F0 + 0.046) + 0.003, 1.0)]
    anneau_tube(m, st, "ab_fourrure", 20, rep_u=3.0, col=lambda i, k: 0.75 + 0.25 * h(i + var * 50, k))
    rangs = [(F0 + 0.006, 32, 0.030, -0.55), (F0 + 0.022, 30, 0.028, -0.25), (F0 + 0.038, 28, 0.022, 0.15)]
    for n_r, (x, nb, lg, incl) in enumerate(rangs):
        for q in range(nb):
            a = TAU * (q + 0.5 * (n_r % 2) + 0.3 * h(q, n_r + var * 9)) / nb
            r0 = r_base(x) + 0.008
            p, nrm = point_tube(x, a, r0)
            t = Vector((1, 0, 0))
            b = nrm.cross(t)
            l_ = lg * (0.7 + 0.6 * h(q + 3, n_r + 17 + var * 5))
            larg = 0.0075 * (0.8 + 0.4 * h(q, n_r + 31))
            tip = p + nrm * l_ * 0.8 + t * (incl * l_) + b * (h(q, n_r + 41) - 0.5) * 0.012
            pw = poids_avant_bras(max(x, 0.47))
            blanc = 1.25 if h(q, n_r + 77 + var) > 0.45 else 1.0
            ba = [m.sommet(p + b * larg - t * 0.004, pw, 0.55), m.sommet(p - b * larg - t * 0.004, pw, 0.55),
                  m.sommet(p + t * 0.006 - nrm * 0.002, pw, 0.5)]
            ap = m.sommet(tip, pw, (blanc, blanc, blanc * 1.02))
            for (i0, i1) in ((0, 1), (1, 2), (2, 0)):
                m.face([ba[i0], ba[i1], ap], [(0.1 + 0.3 * (q % 3), 0.0), (0.3 + 0.3 * (q % 3), 0.0), (0.2 + 0.3 * (q % 3), 1.0)], "ab_fourrure")

    # ---------------------------------------------------------------- 6. gant : paume, revers du poignet, doigts
    H = os_("hand")
    hw = H.head_local.copy()       # poignet
    doigts = ["index", "middle", "ring", "pinky"]
    k01 = {d: os_(d + "_01").head_local.copy() for d in doigts}

    def poids_main(x):
        k = min(max((0.725 - x) / 0.03, 0.0), 1.0) * 0.4
        return [("hand_l", 1.0 - k), ("lowerarm_l", k)] if k > 0 else [("hand_l", 1.0)]

    # revers du gant (évasé, sous le bracelet, déborde côté main)
    # passe 4 : revers court, caché sous le bracelet (l'échelle x1,25 de la main ne l'étire plus en talon lisse)
    st = [(0.692, r_base(0.692) + 0.001, 0.0), (0.703, r_base(0.70) + 0.003, 0.5), (0.712, 0.040, 0.8), (0.720, 0.034, 1.0)]
    anneau_tube(m, st, "ab_gant", 16, rep_u=2.0, poids=lambda x: poids_main(x) if x > 0.709 else poids_avant_bras(x))

    # paume : coque à section de rectangle arrondi, du poignet aux jointures
    def section(x):
        k = min(max((x - 0.71) / (0.83 - 0.71), 0.0), 1.0)
        cy = 0.064 + (0.062 - 0.064) * k
        demi_l = 0.031 + (0.054 - 0.031) * k ** 0.6          # largeur pouce -> auriculaire (talon resserré, passe 4)
        dessus = 0.021 - 0.003 * k                             # dos de la main
        dessous = 0.019 - 0.003 * k                            # paume
        cz = 1.452 - 0.002 * k
        return cy, cz, demi_l, dessus, dessous
    nsec = 14
    stx = [0.712, 0.728, 0.748, 0.770, 0.792, 0.812, 0.828, 0.836]
    rangs = []
    for k, x in enumerate(stx):
        cy, cz, dl, hs, hb = section(x)
        rang = []
        for i in range(nsec):
            a = TAU * i / nsec
            ca, sa = math.cos(a), math.sin(a)
            # super-ellipse : bords francs (main gantée), pas un tube
            e = 0.88
            yy = dl * math.copysign(abs(sa) ** e, sa)
            zz = (hs if ca > 0 else hb) * math.copysign(abs(ca) ** e, ca)
            if k == len(stx) - 1:
                yy *= 0.92; zz *= 0.7
            ao = 0.8 if ca < -0.3 else 1.0
            rang.append(m.sommet((x, cy - yy, cz + zz), poids_main(x), ao))
        rangs.append(rang)
    for k in range(len(stx) - 1):
        for i in range(nsec):
            j = (i + 1) % nsec
            m.face([rangs[k][i], rangs[k][j], rangs[k + 1][j], rangs[k + 1][i]],
                   [(i / nsec * 2, k / 7 * 1.5), ((i + 1) / nsec * 2, k / 7 * 1.5), ((i + 1) / nsec * 2, (k + 1) / 7 * 1.5), (i / nsec * 2, (k + 1) / 7 * 1.5)], "ab_gant")
    disque(m, rangs[-1], Vector((0.838, 0.062, 1.450)), [("hand_l", 1.0)], "ab_gant")

    # dos de la main : cuir nu (références : pas de plaque), une couture de clous de fer en arc près du poignet
    # et un clou sur chaque jointure
    for q in range(5):
        t_ = -0.6 + 1.2 * q / 4
        x = 0.742 + 0.006 * (1.0 - t_ * t_)
        cy, cz, dl, hs, hb = section(x)
        p = Vector((x, cy - dl * 0.9 * t_, cz + hs * (1.0 - 0.45 * t_ * t_) + 0.001))
        rivet(m, p, Vector((0, -0.25 * t_, 1)), 0.0026, poids=poids_main(x), haut=0.0025)
    for d in doigts:
        b = k01[d]
        rivet(m, Vector((b.x - 0.006, b.y, b.z + 0.0125)), Vector((0, 0, 1)), 0.0028, poids=[("hand_l", 1.0)], haut=0.003)

    # doigts : tubes octogonaux, phalange par phalange
    def doigt(nom, r, bagues):
        chaine = [os_("%s_0%d" % (nom, i)) for i in (1, 2, 3)] + [os_(nom + "_04_leaf")]
        pts = [b.head_local.copy() for b in chaine] + [chaine[-1].tail_local.copy()]
        noms = [b.name for b in chaine]
        d0 = (pts[1] - pts[0]).normalized()
        depart = pts[0] - d0 * (0.022 if nom != "thumb" else 0.012)
        # stations : (point, rayon, poids)
        sts = [(depart, r * 1.05, [(noms[0], 1.0)] if nom != "thumb" else [("hand_l", 0.6), (noms[0], 0.4)])]
        for i in range(3):
            a, b = pts[i], pts[i + 1]
            jr = [1.22, 1.12, 1.06][i]
            wj = [(noms[i], 1.0)] if i == 0 else [(noms[i - 1], 0.5), (noms[i], 0.5)]
            if i == 0 and nom != "thumb":
                wj = [("hand_l", 0.35), (noms[0], 0.65)]
            sts.append((a, r * jr, wj))
            sts.append((a.lerp(b, 0.5), r * (1.0 - 0.06 * i), [(noms[i], 1.0)]))
        a, b = pts[3], pts[4]
        sts.append((a, r * 0.98, [(noms[2], 0.5), (noms[3], 0.5)]))
        sts.append((a.lerp(b, 0.55), r * 0.86, [(noms[3], 1.0)]))
        sts.append((a.lerp(b, 0.9), r * 0.62, [(noms[3], 1.0)]))
        sec = 8
        haut = Vector((0, 0, 1)) if nom != "thumb" else Vector((0, 0.6, 0.8)).normalized()
        rgs = []
        for k, (p, rr, w) in enumerate(sts):
            q = sts[min(k + 1, len(sts) - 1)][0] - sts[max(k - 1, 0)][0]
            d, up, cote = repere(q, haut)
            rang = []
            for i in range(sec):
                a_ = TAU * i / sec
                ca, sa = math.cos(a_), math.sin(a_)
                fl = 1.0 if ca > 0 else 0.82      # dessous des doigts un peu aplati
                pos = p + up * ca * rr * fl + cote * sa * rr
                ao = 1.0 if ca > -0.2 else 0.72
                if k in (1, 3, 5):
                    ao *= 1.08   # jointures (le cuir tendu accroche la lumière)
                rang.append(m.sommet(pos, w, ao))
            rgs.append(rang)
        for k in range(len(rgs) - 1):
            for i in range(sec):
                j = (i + 1) % sec
                m.face([rgs[k][i], rgs[k][j], rgs[k + 1][j], rgs[k + 1][i]],
                       [(i / sec, k / 4.0), ((i + 1) / sec, k / 4.0), ((i + 1) / sec, (k + 1) / 4.0), (i / sec, (k + 1) / 4.0)], "ab_gant")
        disque(m, rgs[-1], pts[3].lerp(pts[4], 1.0), [(noms[3], 1.0)], "ab_gant")
        # bague de jointure (fer) sur la première phalange
        if bagues:
            p = pts[0].lerp(pts[1], 0.55)
            d, up, cote = repere(pts[1] - pts[0], haut)
            rr = r * 1.13
            rg0, rg1 = [], []
            for i in range(sec):
                a_ = TAU * i / sec
                o = up * math.cos(a_) * rr + cote * math.sin(a_) * rr
                rg0.append(m.sommet(p - d * 0.004 + o, [(noms[0], 1.0)], 0.9))
                rg1.append(m.sommet(p + d * 0.004 + o, [(noms[0], 1.0)], 0.9))
            for i in range(sec):
                j = (i + 1) % sec
                m.face([rg0[i], rg0[j], rg1[j], rg1[i]], [(i / sec, 0), ((i + 1) / sec, 0), ((i + 1) / sec, 1), (i / sec, 1)], "ab_fer", False)

    bag = [["index", "middle"], ["middle", "ring"]][var]
    # doigts de gant épais (références : doigts gantés trapus, pas des baguettes) : rayons ~ +20 %
    for nom, r in (("index", 0.0138), ("middle", 0.0143), ("ring", 0.0135), ("pinky", 0.0118), ("thumb", 0.0160)):
        doigt(nom, r, nom in bag)
    return m


def miroir(poids):
    return [(n[:-2] + "_r" if n.endswith("_l") else n, w) for n, w in poids]


def creer(nom, m, droite):
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    s = -1.0 if droite else 1.0
    bv = [bm.verts.new((p.x * s, p.y, p.z)) for p in m.v]
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    for idx, uvs, mi, lisse in m.f:
        if droite:
            idx, uvs = idx[::-1], uvs[::-1]
        try:
            bf = bm.faces.new([bv[i] for i in idx])
        except ValueError:
            continue
        bf.material_index = mi
        bf.smooth = lisse
        for lo, i, uv in zip(bf.loops, idx, uvs):
            lo[uvl].uv = uv
            c = m.c[i]
            lo[col] = (min(c[0] * 0.8, 1.0), min(c[1] * 0.8, 1.0), min(c[2] * 0.8, 1.0), 1.0)   # 0,8 : marge pour les pointes claires
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for n in MATS:
        me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = arm
    for i, w in enumerate(m.w):
        for g, ww in (miroir(w) if droite else w):
            vg = o.vertex_groups.get(g) or o.vertex_groups.new(name=g)
            vg.add([i], ww, 'ADD')
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("TRI", nom, len(me.vertices), tris)
    return o


creer("avant_bras_l", construire(0), False)
creer("avant_bras_r", construire(1), True)

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
kw = dict(filepath=SORTIE, export_format='GLB', use_selection=True, export_skins=True, export_animations=False, export_apply=False)
try:
    bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
except TypeError:
    bpy.ops.export_scene.gltf(**kw)
print("EXPORT OK", SORTIE, "(lancer ensuite os_torsion_bras.py)")
