# Bijoux du registre (data/objets/bijoux.json) : 4 colliers / amulettes et 6 anneaux, en pose « au sol » (posés à plat).
#   blender.exe -b --python bijoux.py -- [id ...]      (sans argument : les dix)
# Exporte assets/modeles/bijoux/<id>.glb (lus par scripts/rpg/objet_monde.gd via le champ `modele` de la fiche).
#
# REPÈRE : taille RÉELLE (m), objet couché sur le sol, PIVOT AU SOL (z min = 0), centré en x/y sur sa boîte.
#   glTF (export Y-up) : Y = haut. ObjetMonde exagère l'échelle au sol (ECHELLE_BIJOU) pour la lisibilité.
# MATÉRIAUX (noms stables, posés dans Godot par scripts/rpg/bijoux_materiaux.gd = BijouxMateriaux, shader_matiere) :
#   or, argent, bronze, fer (fer noir), cuir, os, gemme (cristal de givre pâle), saphir, rubis, jade, amethyste.
# UV : tubes u = tour, v = long ; gemmes u = travers de facette (0..1), v = hauteur (couche « profondeur » du shader).
# Budget : ≤ 1200 triangles par collier (chaîne à maillons), ≤ 500 par anneau, aucune texture dans le glb (dessinées dans Godot).
import bpy, bmesh, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "bijoux")

TAU = math.tau


def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)


class Maille:
    def __init__(self, nom):
        self.nom = nom
        self.v = []
        self.f = []

    def s(self, p):
        self.v.append(tuple(p))
        return len(self.v) - 1

    def face(self, idx, mat, uvs):
        self.f.append((list(idx), mat, list(uvs)))

    def creer(self, lisse=True):
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        uvl = bm.loops.layers.uv.new("UVMap")
        noms = []
        for _, mat, _ in self.f:
            if mat not in noms:
                noms.append(mat)
        for idx, mat, uvs in self.f:
            try:
                bf = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            bf.material_index = noms.index(mat)
            bf.smooth = lisse and mat not in GEMMES
            for lo, uv in zip(bf.loops, uvs):
                lo[uvl].uv = uv
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for n in noms:
            me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
        o = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(o)
        return o


GEMMES = ("gemme", "saphir", "rubis", "jade", "amethyste")


def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_norm(a):
    l = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2) or 1.0
    return (a[0] / l, a[1] / l, a[2] / l)


def tube(m, chemin, rayons, cotes, mat, ferme=False, bouts=True, haut=(0, 0, 1), ecrase=1.0, uv_tours=1.0):
    """Tube le long de `chemin` (liste de points), rayon par point (`rayons` : nombre ou liste). `ecrase` < 1 : section
    aplatie selon `haut` (anneaux larges et plats)."""
    n = len(chemin)
    if not isinstance(rayons, (list, tuple)):
        rayons = [rayons] * n
    anneaux = []
    for k in range(n):
        if ferme:
            t = v_sub(chemin[(k + 1) % n], chemin[(k - 1) % n])
        else:
            t = v_sub(chemin[min(k + 1, n - 1)], chemin[max(k - 1, 0)])
        t = v_norm(t)
        b = v_norm(v_cross(t, haut))
        if abs(sum(x * x for x in b)) < 1e-6:
            b = (1, 0, 0)
        u = v_norm(v_cross(b, t))
        a = []
        for i in range(cotes):
            ang = TAU * i / cotes
            p = v_add(chemin[k], v_add(v_mul(b, math.cos(ang) * rayons[k]), v_mul(u, math.sin(ang) * rayons[k] * ecrase)))
            a.append(m.s(p))
        anneaux.append(a)
    lim = n if ferme else n - 1
    for k in range(lim):
        k2 = (k + 1) % n
        for i in range(cotes):
            j = (i + 1) % cotes
            m.face([anneaux[k][i], anneaux[k][j], anneaux[k2][j], anneaux[k2][i]], mat,
                   [(uv_tours * i / cotes, k / n), (uv_tours * (i + 1) / cotes, k / n), (uv_tours * (i + 1) / cotes, (k + 1) / n), (uv_tours * i / cotes, (k + 1) / n)])
    if bouts and not ferme:
        for k, sens in ((0, -1), (n - 1, 1)):
            if rayons[k] <= 1e-5:
                continue
            c = m.s(chemin[k])
            for i in range(cotes):
                j = (i + 1) % cotes
                idx = [anneaux[k][i], anneaux[k][j], c] if sens > 0 else [anneaux[k][j], anneaux[k][i], c]
                m.face(idx, mat, [(0.1, 0.1), (0.9, 0.1), (0.5, 0.9)])
    return anneaux


def cercle(c, r, n, plan="xy", depart=0.0, arc=TAU):
    pts = []
    for i in range(n):
        a = depart + arc * i / (n if arc >= TAU - 1e-6 else (n - 1))
        if plan == "xy":
            pts.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r, c[2]))
        elif plan == "xz":
            pts.append((c[0] + math.cos(a) * r, c[1], c[2] + math.sin(a) * r))
        else:
            pts.append((c[0], c[1] + math.cos(a) * r, c[2] + math.sin(a) * r))
    return pts


def tore(m, c, R, r, mat, n=16, cotes=6, plan="xy", ecrase=1.0):
    haut = {"xy": (0, 0, 1), "xz": (0, 1, 0), "yz": (1, 0, 0)}[plan]
    return tube(m, cercle(c, R, n, plan), r, cotes, mat, ferme=True, haut=haut, ecrase=ecrase)


def brillant(m, c, r, h_couronne, h_pavillon, mat, n=8, table=0.55, axe="z", etire=1.0, pointe=1.0):
    """Gemme taillée : table (dessus plat), couronne, rondiste, pavillon jusqu'à la colette. `axe` : direction du dessus
    ("z" posée à plat, "x"/"-x"/"y"/"-y" de côté). `etire` allonge selon l'axe local u (goutte / ovale), `pointe` > 1 étire
    un côté (goutte)."""
    def rep(lx, ly, lz):
        # lx, ly dans le plan du rondiste, lz le long de l'axe du dessus
        if axe == "z":
            return (c[0] + lx, c[1] + ly, c[2] + lz)
        if axe == "x":
            return (c[0] + lz, c[1] + lx, c[2] + ly)
        if axe == "-x":
            return (c[0] - lz, c[1] + lx, c[2] + ly)
        if axe == "y":
            return (c[0] + lx, c[1] + lz, c[2] + ly)
        return (c[0] + lx, c[1] - lz, c[2] + ly)

    def plan(rr, z, i):
        a = TAU * i / n
        x = math.cos(a) * rr * etire
        if x > 0:
            x *= pointe
        return rep(x, math.sin(a) * rr, z)
    t = [m.s(plan(r * table, h_couronne, i)) for i in range(n)]
    g = [m.s(plan(r, 0.0, i)) for i in range(n)]
    cu = m.s(rep(0, 0, -h_pavillon))
    m.face(t, mat, [(0.5 + 0.5 * math.cos(TAU * i / n), 0.5 + 0.5 * math.sin(TAU * i / n)) for i in range(n)])
    for i in range(n):
        j = (i + 1) % n
        m.face([t[i], g[i], g[j], t[j]], mat, [(0.15, 0.9), (0.0, 0.55), (1.0, 0.55), (0.85, 0.9)])
        m.face([g[j], g[i], cu], mat, [(1.0, 0.5), (0.0, 0.5), (0.5, 0.05)])


def cabochon(m, c, rx, ry, h, mat, n=10, anneaux=3):
    """Demi-ellipsoïde posé (dôme poli), base au plan z = c.z."""
    prec = None
    for k in range(anneaux + 1):
        phi = (math.pi / 2) * k / anneaux
        rr = math.cos(phi)
        z = c[2] + math.sin(phi) * h
        if k == anneaux:
            som = m.s((c[0], c[1], z))
            for i in range(n):
                j = (i + 1) % n
                m.face([prec[i], prec[j], som], mat, [(i / n, k / anneaux * 0.9), ((i + 1) / n, k / anneaux * 0.9), ((i + 0.5) / n, 1.0)])
            break
        a = [m.s((c[0] + math.cos(TAU * i / n) * rx * rr, c[1] + math.sin(TAU * i / n) * ry * rr, z)) for i in range(n)]
        if prec is not None:
            for i in range(n):
                j = (i + 1) % n
                m.face([prec[i], prec[j], a[j], a[i]], mat, [(i / n, (k - 1) / anneaux), ((i + 1) / n, (k - 1) / anneaux), ((i + 1) / n, k / anneaux), (i / n, k / anneaux)])
        else:
            m.face(list(reversed(a)), mat, [(0.5, 0.5)] * n)
        prec = a


def chaton(m, c, r, h, mat, n=10):
    """Sertissure : collerette (tube court ouvert) autour d'une gemme posée, de z = c.z - h*0.4 à c.z + h*0.6."""
    bas = [m.s((c[0] + math.cos(TAU * i / n) * r * 0.85, c[1] + math.sin(TAU * i / n) * r * 0.85, c[2] - h * 0.4)) for i in range(n)]
    hautr = [m.s((c[0] + math.cos(TAU * i / n) * r, c[1] + math.sin(TAU * i / n) * r, c[2] + h * 0.6)) for i in range(n)]
    inter = [m.s((c[0] + math.cos(TAU * i / n) * r * 0.82, c[1] + math.sin(TAU * i / n) * r * 0.82, c[2] + h * 0.45)) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        m.face([bas[i], bas[j], hautr[j], hautr[i]], mat, [(i / n, 0), ((i + 1) / n, 0), ((i + 1) / n, 1), (i / n, 1)])
        m.face([hautr[i], hautr[j], inter[j], inter[i]], mat, [(i / n, 0), ((i + 1) / n, 0), ((i + 1) / n, 1), (i / n, 1)])
    m.face(list(reversed(bas)), mat, [(0.5, 0.5)] * n)


def griffes(m, c, r, h, mat, nb=4, depart=0.785):
    for k in range(nb):
        a = depart + TAU * k / nb
        p0 = (c[0] + math.cos(a) * r * 0.9, c[1] + math.sin(a) * r * 0.9, c[2] - h * 0.3)
        p1 = (c[0] + math.cos(a) * r * 1.05, c[1] + math.sin(a) * r * 1.05, c[2] + h * 0.5)
        p2 = (c[0] + math.cos(a) * r * 0.7, c[1] + math.sin(a) * r * 0.7, c[2] + h * 0.85)
        tube(m, [p0, p1, p2], [r * 0.16, r * 0.14, r * 0.08], 4, mat)


# ------------------------------------------------------------------ anneaux
# Anneau couché à plat : jonc dans le plan XY (z = demi-épaisseur), chaton sur le côté +X, gemme tournée vers le haut
# (un anneau posé sur une table montre sa pierre au-dessus du jonc relevé : on surélève le chaton).
R_DOIGT = 0.0098


def jonc(m, mat, largeur=0.0042, epaisseur=0.0022, n=20):
    # section aplatie : large selon z (hauteur posée), mince selon le rayon
    return tube(m, cercle((0, 0, largeur * 0.5), R_DOIGT + epaisseur * 0.5, n, "xy"), epaisseur * 0.5, 6, mat, ferme=True,
                haut=(0, 0, 1), ecrase=largeur / epaisseur)


def tete_chaton(m, mat, gem_mat, r=0.0048, forme="brillant", etire=1.0, pointe=1.0):
    """Tête de bague sur le côté +X : épaule épaissie + chaton haut, gemme vers le haut."""
    cx = R_DOIGT + 0.0026
    base_z = 0.0052
    # épaules (deux petits tubes qui montent du jonc vers le chaton)
    for s in (-1, 1):
        a0 = s * 0.75
        p0 = (math.cos(a0) * (R_DOIGT + 0.0011), math.sin(a0) * (R_DOIGT + 0.0011), 0.0021)
        p1 = (cx - 0.0006, s * r * 0.75, base_z - 0.0008)
        tube(m, [p0, p1], [0.0014, 0.0016], 5, mat)
    c = (cx, 0.0, base_z)
    chaton(m, c, r * (etire if etire > 1 else 1.0) * 1.08, 0.0026, mat)
    if forme == "brillant":
        brillant(m, (cx, 0, base_z + 0.0012), r, 0.0016, 0.0032, gem_mat, n=8, etire=etire, pointe=pointe)
        griffes(m, (cx, 0, base_z + 0.0012), r * etire, 0.0026, mat)
    else:
        cabochon(m, (cx, 0, base_z + 0.0009), r * etire, r, 0.0034, gem_mat)


def anneau_gemme(nom, metal, gemme, forme="brillant", r=0.0048, etire=1.0, pointe=1.0):
    m = Maille(nom)
    jonc(m, metal)
    tete_chaton(m, metal, gemme, r, forme, etire, pointe)
    return m


def chevaliere(nom, metal, plateau_mat, large=False):
    """Chevalière : jonc épais qui s'élargit en plateau gravé (le relief du loup / du sceau = facettes en creux)."""
    m = Maille(nom)
    jonc(m, metal, largeur=0.0058 if large else 0.0048, epaisseur=0.0030 if large else 0.0026)
    cx = R_DOIGT + 0.0032
    w = 0.0062 if large else 0.0056
    zc = 0.0034 if large else 0.0029
    # plateau : prisme octogonal aplati, debout (face vers +X), légèrement incliné vers le haut pour se lire de dessus
    n = 8
    incl = 0.55
    def rep(lx, ly, lz):
        # lz = épaisseur vers +X ; incliné de `incl` vers +Z
        x = cx + lz * math.cos(incl) - ly * 0.0
        z = zc + lz * math.sin(incl)
        return (x - lx * math.sin(incl), ly, z + lx * math.cos(incl))
    ext = [m.s(rep(math.cos(TAU * (i + 0.5) / n) * w * 0.6, math.sin(TAU * (i + 0.5) / n) * w * 0.6, 0.0016)) for i in range(n)]
    inn = [m.s(rep(math.cos(TAU * (i + 0.5) / n) * w * 0.6, math.sin(TAU * (i + 0.5) / n) * w * 0.6, -0.0018)) for i in range(n)]
    gr = [m.s(rep(math.cos(TAU * (i + 0.5) / n) * w * 0.42, math.sin(TAU * (i + 0.5) / n) * w * 0.42, 0.0011)) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        m.face([inn[i], inn[j], ext[j], ext[i]], metal, [(i / n, 0), ((i + 1) / n, 0), ((i + 1) / n, 1), (i / n, 1)])
        m.face([ext[i], ext[j], gr[j], gr[i]], metal, [(i / n, 0), ((i + 1) / n, 0), ((i + 1) / n, 0.3), (i / n, 0.3)])
    m.face(gr, plateau_mat, [(0.5 + 0.5 * math.cos(TAU * i / n), 0.5 + 0.5 * math.sin(TAU * i / n)) for i in range(n)])
    m.face(list(reversed(inn)), metal, [(0.5, 0.5)] * n)
    # relief gravé (loup / sceau) : petit motif en creux = trois barrettes en saillie sur le plateau
    for k, (ly0, ly1, lx) in enumerate(((-0.0016, 0.0016, 0.0009), (-0.0012, 0.0010, -0.0002), (-0.0006, 0.0014, -0.0012))):
        tube(m, [rep(lx, ly0, 0.00125), rep(lx, ly1, 0.00125)], 0.00035, 4, metal)
    return m


# ------------------------------------------------------------------ colliers
def chaine(m, mat, gabarit, maillons=20, r_maillon=0.0042, fil=0.0009):
    """Chaîne posée à plat le long de `gabarit` (fonction t -> (x, y)), maillons alternés couché / debout."""
    pts = [gabarit(i / maillons) for i in range(maillons)]
    for i in range(maillons):
        p = pts[i]
        q = pts[(i + 1) % maillons]
        d = v_norm((q[0] - p[0], q[1] - p[1], 0))
        c = (p[0], p[1], r_maillon * (0.95 if i % 2 else 0.45))
        # maillon : tore allongé dans la direction d ; un sur deux debout (plan vertical)
        n = 6
        chemin = []
        for k in range(n):
            a = TAU * k / n
            lx = math.cos(a) * r_maillon * 1.35
            ly = math.sin(a) * r_maillon * 0.75
            if i % 2 == 0:
                chemin.append((c[0] + d[0] * lx - d[1] * ly, c[1] + d[1] * lx + d[0] * ly, c[2]))
            else:
                chemin.append((c[0] + d[0] * lx, c[1] + d[1] * lx, c[2] + ly))
        haut = (0, 0, 1) if i % 2 == 0 else (-d[1], d[0], 0)
        tube(m, chemin, fil, 3, mat, ferme=True, haut=haut)


def goutte_gabarit(rx, ry, bas):
    """Boucle de collier posée : ovale qui se resserre vers le pendentif (y = -ry)."""
    def g(t):
        a = TAU * t + math.pi / 2       # départ en haut
        x = math.cos(a) * rx
        y = math.sin(a) * ry
        if y < 0:
            x *= 1.0 - (-y / ry) * bas
        return (x, y)
    return g


def amulette_givre():
    m = Maille("amulette_givre")
    chaine(m, "argent", goutte_gabarit(0.07, 0.085, 0.55))
    # bélière + cristal de givre (prisme hexagonal à deux pointes), couché, pointe vers -Y
    tore(m, (0, -0.0875, 0.0018), 0.0034, 0.0009, "argent", n=8, cotes=4, plan="yz")
    y0 = -0.091
    L = 0.042
    r = 0.0062
    n = 6
    def anneau(y, rr):
        return [m.s((math.cos(TAU * i / n) * rr, y, r + math.sin(TAU * i / n) * rr)) for i in range(n)]
    a0 = anneau(y0 - 0.006, r * 0.75)
    a1 = anneau(y0 - 0.012, r)
    a2 = anneau(y0 - L + 0.010, r * 0.95)
    tete = m.s((0, y0, r))
    pointe = m.s((0, y0 - L, r))
    for i in range(n):
        j = (i + 1) % n
        m.face([tete, a0[j], a0[i]], "gemme", [(0.5, 1.0), (1, 0.9), (0, 0.9)])
        m.face([a0[i], a0[j], a1[j], a1[i]], "gemme", [(0, 0.9), (1, 0.9), (1, 0.8), (0, 0.8)])
        m.face([a1[i], a1[j], a2[j], a2[i]], "gemme", [(0, 0.8), (1, 0.8), (1, 0.25), (0, 0.25)])
        m.face([a2[i], a2[j], pointe], "gemme", [(0, 0.25), (1, 0.25), (0.5, 0.0)])
    # capuchon d'argent du cristal
    tube(m, [(0, y0 + 0.0004, r), (0, y0 - 0.0045, r)], [r * 0.45, r * 0.8], 6, "argent", haut=(0, 0, 1))
    return m


def amulette_ours():
    m = Maille("amulette_ours")
    # lacet de cuir (tube continu) + perles d'or près du pendentif
    g = goutte_gabarit(0.072, 0.088, 0.5)
    pts = [(*g(i / 40), 0.0016) for i in range(40)]
    tube(m, pts, 0.0016, 4, "cuir", ferme=True)
    for t in (0.42, 0.58):
        x, y = g(t)
        tore(m, (x, y, 0.0022), 0.0024, 0.0012, "or", n=6, cotes=4, plan="xz")
    # griffe : corne courbe effilée (os), couchée, base cerclée d'or
    base = (0.0, -0.091, 0.0)
    chemin = []
    ray = []
    n = 9
    for k in range(n):
        t = k / (n - 1)
        a = t * 1.25
        x = math.sin(a) * 0.024
        y = -0.091 - (1 - math.cos(a)) * 0.0 - t * 0.040
        x = 0.018 * (1 - math.cos(a * 1.1))
        chemin.append((base[0] + x, y, 0.0068 * (1 - t * 0.55)))
        ray.append(0.0068 * (1 - t) ** 0.9 + 0.0004)
    tube(m, chemin, ray, 7, "os", haut=(0, 0, 1), ecrase=0.85)
    # monture d'or : deux cercles autour de la base + bélière
    tore(m, (chemin[0][0], chemin[0][1] - 0.001, chemin[0][2]), 0.0072, 0.0012, "or", n=10, cotes=4, plan="xz")
    tore(m, (chemin[0][0], chemin[0][1] - 0.0045, chemin[0][2]), 0.0068, 0.0010, "or", n=10, cotes=4, plan="xz")
    tore(m, (0, -0.088, 0.0035), 0.0032, 0.0011, "or", n=8, cotes=4, plan="yz")
    return m


def amulette_arcaniste():
    m = Maille("amulette_arcaniste")
    chaine(m, "or", goutte_gabarit(0.07, 0.085, 0.55))
    tore(m, (0, -0.0875, 0.0018), 0.0034, 0.0009, "or", n=8, cotes=4, plan="yz")
    # médaillon : cadre d'or ovale (tube) en relief, améthyste ovale taillée, quatre perles au cadre
    c = (0.0, -0.106, 0.0)
    rx, ry = 0.0115, 0.0150
    cadre = [(c[0] + math.cos(TAU * i / 16) * rx, c[1] + math.sin(TAU * i / 16) * ry, 0.0026) for i in range(16)]
    tube(m, cadre, 0.0024, 5, "or", ferme=True)
    # fond du médaillon (plaque) sous la gemme
    plaque = Maille("_p")
    ids = [m.s((c[0] + math.cos(TAU * i / 12) * rx, c[1] + math.sin(TAU * i / 12) * ry, 0.0006)) for i in range(12)]
    m.face(ids, "or", [(0.5, 0.5)] * 12)
    brillant(m, (c[0], c[1], 0.0040), 0.0092, 0.0030, 0.0030, "amethyste", n=10, etire=ry / rx * 0.82, table=0.6, axe="z")
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        tore(m, (c[0] + math.cos(a) * rx * 1.02, c[1] + math.sin(a) * ry * 1.02, 0.0038), 0.0010, 0.0011, "or", n=6, cotes=4, plan="xy")
    return m


def collier_portefaix():
    m = Maille("collier_portefaix")
    # torque ouvert de bronze : jonc torsadé (section losange tournante simulée par 4 côtés) sur ~300°, boutons aux bouts
    R = 0.068
    ouverture = 0.75
    n = 30
    chemin = []
    for k in range(n):
        a = -math.pi / 2 + ouverture / 2 + (TAU - ouverture) * k / (n - 1)
        chemin.append((math.cos(a) * R, math.sin(a) * R * 1.08 + 0.0, 0.0055))
    ray = [0.0040 + 0.0016 * math.sin(math.pi * k / (n - 1)) for k in range(n)]
    tube(m, chemin, ray, 6, "bronze", haut=(0, 0, 1), uv_tours=2.0)
    # torsade : fil fin enroulé
    fil = []
    for k in range(n * 2):
        t = k / (n * 2 - 1)
        a = -math.pi / 2 + ouverture / 2 + (TAU - ouverture) * t
        rr = 0.0040 + 0.0016 * math.sin(math.pi * t)
        tw = t * 46.0
        ce = (math.cos(a) * R, math.sin(a) * R * 1.08, 0.0055)
        rad = (math.cos(a), math.sin(a), 0)
        fil.append(v_add(ce, v_add(v_mul(rad, math.cos(tw) * rr * 1.02), (0, 0, math.sin(tw) * rr * 1.02))))
    tube(m, fil, 0.0011, 3, "bronze")
    # boutons des extrémités
    for p in (chemin[0], chemin[-1]):
        cabochon(m, (p[0], p[1], 0.0), 0.0085, 0.0085, 0.011, "bronze", n=10, anneaux=3)
    return m


# ------------------------------------------------------------------ registre
def fabriquer(nom):
    if nom == "amulette_givre":
        return amulette_givre()
    if nom == "amulette_ours":
        return amulette_ours()
    if nom == "amulette_arcaniste":
        return amulette_arcaniste()
    if nom == "collier_portefaix":
        return collier_portefaix()
    if nom == "anneau_coureur":
        return anneau_gemme(nom, "argent", "jade", forme="cabochon", r=0.0050, etire=1.25)
    if nom == "anneau_adepte":
        return anneau_gemme(nom, "or", "saphir", r=0.0046, etire=1.0, pointe=1.55)
    if nom == "anneau_braise":
        return anneau_gemme(nom, "or", "rubis", r=0.0050)
    if nom == "anneau_orage":
        return anneau_gemme(nom, "argent", "amethyste", r=0.0050, etire=1.15)
    if nom == "anneau_berserker":
        return chevaliere(nom, "fer", "fer", large=True)
    if nom == "anneau_marchand":
        return chevaliere(nom, "or", "or")
    raise ValueError(nom)


TOUS = ["amulette_givre", "amulette_ours", "amulette_arcaniste", "collier_portefaix", "anneau_coureur", "anneau_adepte",
        "anneau_braise", "anneau_orage", "anneau_berserker", "anneau_marchand"]


def exporter(nom):
    vider()
    o = fabriquer(nom).creer()
    # pivot au sol, centré en x/y
    me = o.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zmin = min(v.co.z for v in me.vertices)
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    for v in me.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= zmin
    me.update()
    o.name = nom
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    dims = (max(xs) - min(xs), max(ys) - min(ys), max(v.co.z for v in me.vertices))
    print("BIJOU %-20s tris=%4d taille=%.3f x %.3f x %.3f m -> %s" % (nom, tris, dims[0], dims[1], dims[2], glb))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nom in (args or TOUS):
    exporter(nom)
