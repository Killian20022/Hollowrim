# Objets « divers » du registre (data/objets/consommables, ingredients, divers, quete .json) : potions, vivres, tomes de sort,
# ingrédients, reliques, objets de quête. Pose AU SOL, taille réelle, pivot au sol.
#   blender.exe -b --python objets_divers.py -- [id ...]      (sans argument : tous)
# Exporte assets/modeles/objets/<id>.glb (lus par scripts/rpg/objet_monde.gd via le champ `modele` de la fiche).
#
# REPÈRE : mètres, objet posé (z min = 0), centré en x/y sur sa boîte ; export glTF Y-up.
# MATÉRIAUX par NOM (aucune texture dans le glb ; suffixe _m = même matière que les bijoux, texture moins dense pour les
# pièces de plus de 5 cm) : peints dans Godot par scripts/rpg/objets_divers_materiaux.gd
# (ObjetsDiversMateriaux, shader_matiere ; textures 64² au bruit, alpha = brillance), ou par BijouxMateriaux / EpeesLongues pour
# les noms communs (or, argent, bronze, fer, cuir, os, gemme, saphir, rubis, jade, amethyste, bois, obsidienne).
# Budget : 80 à 600 triangles par objet. Les petites fonctions des bijoux (Maille, tube, tore, brillant, cabochon, chaine, jonc…)
# sont reprises de ../bijoux/bijoux.py (sa partie « outils », sans son registre).
import bpy, bmesh, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "objets")

_src = open(os.path.join(os.path.dirname(ICI), "bijoux", "bijoux.py"), encoding="utf-8").read()
exec(_src.split("# ------------------------------------------------------------------ registre")[0])   # Maille, tube, tore, …
SORTIE = os.path.join(DEPOT, "assets", "modeles", "objets")      # (le code des bijoux redéfinit SORTIE)

TAU = math.tau
# matériaux à facettes franches (pas de lissage) : pierres, cristaux, livres, métal plat
PLATS = {"gemme", "saphir", "rubis", "jade", "amethyste", "cristal_givre", "roche", "veine_fer", "veine_argent", "pages",
         "sceau_os", "sceau_givre", "sceau_eau", "obsidienne", "fer_rouille", "cendre"}


class M(Maille):
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
            if len(set(idx)) < 3:
                continue
            try:
                bf = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            bf.material_index = noms.index(mat)
            bf.smooth = lisse and mat not in PLATS
            for lo, uv in zip(bf.loops, uvs):
                lo[uvl].uv = uv
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for n in noms:
            me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
        o = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(o)
        return o


# ------------------------------------------------------------------ bruit (déterministe)
def _h3(x, y, z, g):
    s = math.sin(x * 127.1 + y * 311.7 + z * 74.7 + g * 19.19) * 43758.5453
    return s - math.floor(s)


def bruit(x, y, z, g=0):
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi
    u, v, w = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf), zf * zf * (3 - 2 * zf)
    def c(a, b, d):
        return _h3(xi + a, yi + b, zi + d, g)
    x00 = c(0, 0, 0) + (c(1, 0, 0) - c(0, 0, 0)) * u
    x10 = c(0, 1, 0) + (c(1, 1, 0) - c(0, 1, 0)) * u
    x01 = c(0, 0, 1) + (c(1, 0, 1) - c(0, 0, 1)) * u
    x11 = c(0, 1, 1) + (c(1, 1, 1) - c(0, 1, 1)) * u
    return (x00 + (x10 - x00) * v) + ((x01 + (x11 - x01) * v) - (x00 + (x10 - x00) * v)) * w


def h1(k, g=0):
    return _h3(k * 1.31, k * 0.71, 0.3, g)


# ------------------------------------------------------------------ primitives
def tour(m, profil, mat, n=10, c=(0, 0, 0), sx=1.0, sy=1.0, mats=None, phase=0.0, deforme=None, ferme_haut=True):
    """Révolution d'un profil [(r, z)] (bas -> haut) autour de l'axe z passant par c. r = 0 : pôle. `mats` : un matériau par
    segment (sinon `mat`). `deforme(x, y, z) -> (x, y, z)` : retouche des sommets (rainures, bosses). Le dernier anneau est fermé
    par un disque si ferme_haut et r > 0."""
    anneaux = []
    for k, (r, z) in enumerate(profil):
        if r <= 1e-7:
            p = (c[0], c[1], c[2] + z)
            if deforme:
                p = deforme(*p)
            anneaux.append([m.s(p)] * n)
            continue
        a = []
        for i in range(n):
            ang = phase + TAU * i / n
            p = (c[0] + math.cos(ang) * r * sx, c[1] + math.sin(ang) * r * sy, c[2] + z)
            if deforme:
                p = deforme(*p)
            a.append(m.s(p))
        anneaux.append(a)
    L = len(profil)
    for k in range(L - 1):
        mt = mats[k] if mats else mat
        for i in range(n):
            j = (i + 1) % n
            q = [anneaux[k][i], anneaux[k][j], anneaux[k + 1][j], anneaux[k + 1][i]]
            uv = [(i / n, k / L), ((i + 1) / n, k / L), ((i + 1) / n, (k + 1) / L), (i / n, (k + 1) / L)]
            if q[0] == q[1]:
                m.face([q[0], q[2], q[3]], mt, [uv[0], uv[2], uv[3]])
            elif q[2] == q[3]:
                m.face([q[0], q[1], q[2]], mt, uv[:3])
            else:
                m.face(q, mt, uv)
    if ferme_haut and profil[-1][0] > 1e-7:
        mt = mats[-1] if mats else mat
        m.face(list(anneaux[-1]), mt, [(0.5 + 0.5 * math.cos(TAU * i / n), 0.5 + 0.5 * math.sin(TAU * i / n)) for i in range(n)])
    if profil[0][0] > 1e-7:
        m.face(list(reversed(anneaux[0])), mats[0] if mats else mat, [(0.5, 0.5)] * n)
    return anneaux


def pave(m, c, t, mat, rz=0.0, coins=None):
    """Boîte de taille t centrée en c (rotation rz autour de z). coins : retouche des 8 sommets (fonction p -> p)."""
    hx, hy, hz = t[0] / 2, t[1] / 2, t[2] / 2
    cs, sn = math.cos(rz), math.sin(rz)
    ids = []
    for (dx, dy, dz) in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
        lx, ly = dx * hx, dy * hy
        p = (c[0] + lx * cs - ly * sn, c[1] + lx * sn + ly * cs, c[2] + dz * hz)
        if coins:
            p = coins(p)
        ids.append(m.s(p))
    F = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    for f in F:
        m.face([ids[i] for i in f], mat, [(0, 0), (1, 0), (1, 1), (0, 1)])
    return ids


_ICO = None


def _icosaedre(sub):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1),
         (-t, 0, -1), (-t, 0, 1)]
    v = [v_norm(p) for p in v]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(sub):
        cache = {}
        def mil(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                cache[k] = len(v)
                v.append(v_norm(v_mul(v_add(v[a], v[b]), 0.5)))
            return cache[k]
        nf = []
        for a, b, c in f:
            ab, bc, ca = mil(a, b), mil(b, c), mil(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nf
    return v, f


def caillou(m, c, r, mat, sub=1, bosse=0.3, g=0, ech=(1, 1, 1), sol=None, mat_face=None):
    """Bloc irrégulier (icosphère bosselée). `sol` : z local minimal (aplatit le dessous). mat_face(centre) -> nom."""
    v, f = _icosaedre(sub)
    ids = []
    pts = []
    for p in v:
        d = 1.0 + (bruit(p[0] * 1.7 + 3, p[1] * 1.7, p[2] * 1.7, g) - 0.5) * 2 * bosse
        q = (p[0] * d * r * ech[0], p[1] * d * r * ech[1], p[2] * d * r * ech[2])
        if sol is not None and q[2] < sol:
            q = (q[0] * 1.05, q[1] * 1.05, sol)
        q = (q[0] + c[0], q[1] + c[1], q[2] + c[2])
        pts.append(q)
        ids.append(m.s(q))
    for a, b, cc in f:
        mt = mat
        if mat_face:
            ce = v_mul(v_add(v_add(pts[a], pts[b]), pts[cc]), 1 / 3)
            mt = mat_face(ce)
        m.face([ids[a], ids[b], ids[cc]], mt, [(0, 0), (1, 0), (0.5, 1)])


def prisme(m, base, direction, r, longueur, mat, n=6, pointe=0.3, phase=0.0):
    """Cristal : prisme à n pans + pointe pyramidale, partant de `base` selon `direction`."""
    d = v_norm(direction)
    a = v_norm(v_cross(d, (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)))
    b = v_cross(d, a)
    def anneau(t, rr):
        cc = v_add(base, v_mul(d, t))
        return [m.s(v_add(cc, v_add(v_mul(a, math.cos(phase + TAU * i / n) * rr), v_mul(b, math.sin(phase + TAU * i / n) * rr))))
                for i in range(n)]
    a0 = anneau(0.0, r * 0.9)
    a1 = anneau(longueur * (1 - pointe), r)
    tip = m.s(v_add(base, v_mul(d, longueur)))
    for i in range(n):
        j = (i + 1) % n
        m.face([a0[i], a0[j], a1[j], a1[i]], mat, [(0, 0), (1, 0), (1, 0.75), (0, 0.75)])
        m.face([a1[i], a1[j], tip], mat, [(0, 0.75), (1, 0.75), (0.5, 1.0)])
    m.face(list(reversed(a0)), mat, [(0.5, 0.5)] * n)


def ruban(m, p0, ang, longueur, largeur, ep, mat, segs=6, g=0, onde=0.006, dechire=0.25):
    """Lanière (viande séchée, pan de fourrure) posée à plat le long de l'angle `ang`, bords irréguliers, ondulée."""
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    haut, bas = [], []
    for k in range(segs + 1):
        t = k / segs
        w = largeur * 0.5 * (1 - dechire * (bruit(t * 5, 1, 2, g) - 0.5) * 2) * (0.7 if k in (0, segs) else 1.0)
        z = ep * 0.5 + onde * (math.sin(t * 7.0 + g) * 0.5 + 0.5)
        tw = (bruit(t * 3, 4, 5, g + 3) - 0.5) * ep * 1.5
        cx, cy = p0[0] + dx * longueur * t, p0[1] + dy * longueur * t
        row_h = [m.s((cx + px * w * s, cy + py * w * s, z + ep * 0.5 + tw * s)) for s in (-1, 0, 1)]
        row_b = [m.s((cx + px * w * s * 0.96, cy + py * w * s * 0.96, z - ep * 0.5 + tw * s)) for s in (-1, 0, 1)]
        haut.append(row_h)
        bas.append(row_b)
    for k in range(segs):
        for s in range(2):
            m.face([haut[k][s], haut[k][s + 1], haut[k + 1][s + 1], haut[k + 1][s]], mat, [(k / segs, s / 2), (k / segs, (s + 1) / 2), ((k + 1) / segs, (s + 1) / 2), ((k + 1) / segs, s / 2)])
            m.face([bas[k][s + 1], bas[k][s], bas[k + 1][s], bas[k + 1][s + 1]], mat, [(0, 0), (1, 0), (1, 1), (0, 1)])
        for s in (0, 2):
            m.face([haut[k][s], haut[k + 1][s], bas[k + 1][s], bas[k][s]], mat, [(0, 0), (1, 0), (1, 1), (0, 1)])
    for k in (0, segs):
        for s in range(2):
            m.face([haut[k][s], haut[k][s + 1], bas[k][s + 1], bas[k][s]], mat, [(0, 0), (1, 0), (1, 1), (0, 1)])


# ------------------------------------------------------------------ potions
def fiole(nom, liquide, profil, remplir, n=10, sx=1.0, sy=1.0, cire=False, ficelle=None, cuir=False):
    """Fiole de verre ouverte en haut (bouchon de liège) + LIQUIDE intérieur (même profil rentré de 2,5 mm, dessus plat au niveau
    `remplir`) : le liquide coloré se voit à travers le verre translucide."""
    m = M(nom)
    tour(m, profil, "verre", n=n, sx=sx, sy=sy, ferme_haut=False)
    # liquide : profil rentré, coupé à `remplir`
    liq = [(0.0, 0.0035)]
    for k in range(1, len(profil)):
        r0, z0 = profil[k - 1]
        r1, z1 = profil[k]
        if z1 <= remplir:
            if z1 > 0.004:
                liq.append((max(r1 - 0.0028, 0.002), z1))
        else:
            t = (remplir - z0) / max(z1 - z0, 1e-6)
            liq.append((max(r0 + (r1 - r0) * t - 0.0028, 0.002), remplir))
            break
    liq.append((0.0, remplir))
    tour(m, liq, liquide, n=n, sx=sx, sy=sy)
    # bouchon de liège : du col jusqu'à 12 mm au-dessus de la lèvre
    rc, zc = profil[-1]
    tour(m, [(rc * 0.85, zc - 0.014), (rc * 0.92, zc), (rc * 1.08, zc + 0.008), (rc * 1.05, zc + 0.013), (0.0, zc + 0.014)], "liege", n=8)
    if cire:          # cachet de cire coulé sur le bouchon et la lèvre
        tour(m, [(rc * 1.5, zc - 0.006), (rc * 1.55, zc + 0.002), (rc * 1.3, zc + 0.012), (rc * 0.9, zc + 0.017), (0.0, zc + 0.018)], "cire", n=8,
             deforme=lambda x, y, z: (x, y, z - (0.004 * bruit(x * 400, y * 400, 0, 7) if z < zc else 0.0)))
    if cuir:          # coiffe de cuir nouée sur le bouchon
        tour(m, [(rc * 1.45, zc - 0.008), (rc * 1.5, zc + 0.004), (rc * 1.25, zc + 0.014), (0.0, zc + 0.016)], "cuir_m", n=8,
             deforme=lambda x, y, z: (x, y, z - (0.005 * bruit(x * 300, y * 300, 0, 3) if z < zc else 0.0)))
    if ficelle is not None:
        for k, dz in enumerate((0.0, 0.004)):
            r = 0
            for (pr, pz) in profil:
                if pz <= ficelle + dz:
                    r = pr
            tore(m, (0, 0, ficelle + dz), r * 1.02 + 0.0012, 0.0014, "ficelle", n=10, cotes=4)
    return m


def potion_soin():
    return fiole("potion_soin", "liquide_soin",
                 [(0, 0), (0.018, 0), (0.03, 0.006), (0.036, 0.02), (0.037, 0.034), (0.032, 0.05), (0.02, 0.062), (0.0115, 0.068),
                  (0.0105, 0.092), (0.0135, 0.095), (0.0135, 0.1), (0.0105, 0.101)], 0.046, n=10, ficelle=0.08)


def potion_soin_forte():
    return fiole("potion_soin_forte", "liquide_soin",
                 [(0, 0), (0.038, 0), (0.046, 0.008), (0.049, 0.04), (0.047, 0.072), (0.037, 0.093), (0.021, 0.107), (0.0145, 0.115),
                  (0.0135, 0.143), (0.0175, 0.147), (0.0175, 0.153), (0.0135, 0.154)], 0.085, n=10, cire=True, ficelle=0.124)


def potion_mana():
    return fiole("potion_mana", "liquide_mana",
                 [(0, 0), (0.025, 0), (0.03, 0.006), (0.031, 0.088), (0.025, 0.104), (0.013, 0.114), (0.0105, 0.138),
                  (0.0135, 0.141), (0.0135, 0.146), (0.0105, 0.147)], 0.082, n=6, ficelle=0.12)


def potion_endurance():
    return fiole("potion_endurance", "liquide_vigueur",
                 [(0, 0), (0.03, 0), (0.04, 0.01), (0.045, 0.034), (0.041, 0.057), (0.027, 0.071), (0.0125, 0.078), (0.0115, 0.095),
                  (0.0145, 0.098), (0.0145, 0.103), (0.0115, 0.104)], 0.052, n=10, sx=1.0, sy=0.58, cuir=True, ficelle=0.088)


# ------------------------------------------------------------------ vivres
def pain_seigle():
    m = M("pain_seigle")
    def entailles(x, y, z):
        if z > 0.035:
            for k in (-1, 0, 1):
                d = abs((x * 0.8 + y * 0.6) - k * 0.034)
                if d < 0.007:
                    z -= (0.007 - d) * 0.9 * min(1.0, (z - 0.035) / 0.02)
        z += (bruit(x * 60, y * 60, z * 60, 5) - 0.5) * 0.004
        return (x, y, z)
    tour(m, [(0, 0), (0.066, 0), (0.08, 0.008), (0.083, 0.022), (0.077, 0.038), (0.062, 0.053), (0.04, 0.064), (0.018, 0.069), (0, 0.07)],
         "croute", n=14, sx=1.22, sy=1.0, deforme=entailles,
         mats=["croute", "croute", "croute", "croute", "croute", "farine", "farine", "farine"])
    return m


def viande_sechee():
    m = M("viande_sechee")
    for k, (ang, ln, lg) in enumerate(((0.1, 0.21, 0.042), (-0.18, 0.19, 0.038), (0.35, 0.17, 0.034))):
        ruban(m, (-0.1 + k * 0.012, -0.035 + k * 0.034, k * 0.007), ang, ln, lg, 0.008, "viande", segs=7, g=k * 5 + 1, onde=0.005)
    # ficelle qui lie les lanières
    tube(m, [(0.0, math.cos(a) * 0.052, 0.014 + math.sin(a) * 0.016) for a in [TAU * k / 10 for k in range(10)]], 0.0018, 4, "ficelle", ferme=True, haut=(1, 0, 0))
    return m


# ------------------------------------------------------------------ livres
def livre(m, W, L, H, couv, coins=None, embleme=None, embleme_forme="brillant", fermoir=None, nervures=2, ecorne=0.0, g=0):
    """Livre couché : plats (couv) dépassant le bloc des pages (pages), dos arrondi côté -x, coins de métal, fermoir, emblème."""
    e = max(H * 0.12, 0.0035)
    ab = 0.004                                                                 # chasse des plats
    def usure(p):
        return (p[0], p[1], p[2] + (bruit(p[0] * 80, p[1] * 80, g, g) - 0.5) * ecorne)
    pave(m, (0, 0, e / 2), (W, L, e), couv, coins=usure)
    pave(m, (0, 0, H - e / 2), (W, L, e), couv, coins=usure)
    pave(m, (ab / 2, 0, H / 2), (W - ab - 0.002, L - 2 * ab, H - 2 * e + 0.001), "pages")
    tube(m, [(-W / 2 + 0.002, -L / 2, H / 2), (-W / 2 + 0.002, L / 2, H / 2)], H / 2, 6, couv, haut=(1, 0, 0), ecrase=0.32)
    for k in range(nervures):                                                  # nerfs du dos
        y = -L / 2 + L * (k + 1) / (nervures + 1)
        tube(m, [(-W / 2 + 0.002, y - 0.003, H / 2), (-W / 2 + 0.002, y + 0.003, H / 2)], H / 2 + 0.0015, 6, couv, haut=(1, 0, 0), ecrase=0.36)
    if coins:
        c = min(W, L) * 0.17
        for sx in (1,):
            for sy in (-1, 1):
                for z in (H + 0.0006, -0.0006):
                    x0, y0 = W / 2, sy * L / 2
                    ids = [m.s((x0, y0, z)), m.s((x0 - c, y0, z)), m.s((x0, y0 - sy * c, z))]
                    up = 0.0018 if z > 0 else -0.0018
                    ids2 = [m.s((x0, y0, z + up)), m.s((x0 - c, y0, z + up)), m.s((x0, y0 - sy * c, z + up))]
                    m.face(ids2, coins, [(0, 0), (1, 0), (0, 1)])
                    m.face(list(reversed(ids)), coins, [(0, 0), (1, 0), (0, 1)])
                    for a, b in ((0, 1), (1, 2), (2, 0)):
                        m.face([ids[a], ids[b], ids2[b], ids2[a]], coins, [(0, 0), (1, 0), (1, 1), (0, 1)])
    if fermoir:
        mat_f, y_f = fermoir
        for yy in y_f:
            pave(m, (W / 2 - 0.025, yy, H + 0.001), (0.05, 0.014, 0.002), "cuir_m")               # lanière sur le plat
            pave(m, (W / 2 + 0.0015, yy, H / 2), (0.003, 0.014, H + 0.002), "cuir_m")              # sur la tranche
            pave(m, (W / 2 - 0.045, yy, H + 0.0022), (0.012, 0.018, 0.0024), mat_f)             # boucle
    if embleme:
        mat_e, mat_cadre, r = embleme
        cz = H + 0.0005
        if mat_cadre:
            tore(m, (0.0, 0.0, cz + 0.0012), r * 1.35, 0.0016, mat_cadre, n=10, cotes=4)
            for k in range(4):
                a = TAU * k / 4 + math.pi / 4
                pave(m, (math.cos(a) * r * 2.1, math.sin(a) * r * 2.1, cz + 0.001), (0.006, 0.006, 0.002), mat_cadre, rz=a)
        if embleme_forme == "brillant":
            brillant(m, (0, 0, cz + 0.0026), r, 0.002, 0.003, mat_e, n=8, table=0.5)
        elif embleme_forme == "losange":
            brillant(m, (0, 0, cz + 0.0026), r, 0.0022, 0.003, mat_e, n=4, table=0.4, etire=1.5)
        else:
            cabochon(m, (0, 0, cz), r, r, r * 0.6, mat_e, n=8, anneaux=2)


# École -> (reliure, gemme de l'emblème)
ECOLES = {"feu": ("reliure_feu", "rubis"), "givre": ("reliure_givre", "gemme"), "eclair": ("reliure_eclair", "amethyste"),
          "tenebres": ("reliure_tenebres", "obsidienne"), "vie": ("reliure_vie", "rubis")}
TOMES = {
    "tome_boule_feu": ("feu", "or_m", "brillant", 1.0),
    "tome_explosion_incendiaire": ("feu", "fer_m", "losange", 1.08),
    "tome_lance_givre": ("givre", "argent_m", "losange", 1.0),
    "tome_souffle_givre": ("givre", "argent_m", "brillant", 1.06),
    "tome_nova_gelee": ("givre", "fer_m", "cabochon", 0.96),
    "tome_chaine_eclairs": ("eclair", "argent_m", "losange", 1.04),
    "tome_tempete_statique": ("eclair", "or_m", "brillant", 1.1),
    "tome_drain_vie": ("vie", "fer_m", "cabochon", 1.0),
    "tome_explosion_obscure": ("tenebres", "fer_m", "losange", 1.06),
    "tome_enchant_electricite": ("eclair", "bronze_m", "cabochon", 0.82),
    "tome_enchant_glace": ("givre", "bronze_m", "cabochon", 0.82),
    "tome_enchant_tenebres": ("tenebres", "bronze_m", "cabochon", 0.82),
}


def tome(nom):
    ecole, metal, forme, k = TOMES[nom]
    couv, gem = ECOLES[ecole]
    m = M(nom)
    enchant = "enchant" in nom
    W, L, H = 0.165 * k, 0.225 * k, (0.034 if enchant else 0.046) * (0.9 + 0.2 * h1(len(nom)))
    livre(m, W, L, H, couv, coins=metal, embleme=(gem, metal, 0.011 * k), embleme_forme=forme,
          fermoir=(metal, [0.0] if not enchant else [-L * 0.25, L * 0.25]), nervures=3 if not enchant else 2, ecorne=0.002, g=len(nom))
    return m


def registre_hrafn():
    m = M("registre_hrafn")
    livre(m, 0.21, 0.29, 0.068, "reliure_brune", coins="fer_m", fermoir=("fer_m", [-0.07, 0.07]), nervures=4, ecorne=0.003, g=3)
    # plaque de titre de fer au plat
    pave(m, (0.0, 0.0, 0.0695), (0.06, 0.03, 0.0018), "fer_m")
    return m


def journal_sigrun():
    m = M("journal_sigrun")
    W, L, H = 0.105, 0.148, 0.024
    livre(m, W, L, H, "reliure_claire", nervures=0, ecorne=0.003, g=9)
    # rabat de cuir souple et lacet enroulé
    pave(m, (W / 2 - 0.02, 0.0, H + 0.0012), (0.04, L - 0.01, 0.002), "reliure_claire")
    tube(m, [(-W / 2 - 0.003, 0.012, -0.001), (-W / 2 - 0.003, 0.012, H + 0.003), (W / 2 + 0.003, 0.012, H + 0.003),
             (W / 2 + 0.003, 0.012, -0.001)], 0.0014, 4, "ficelle", bouts=True)
    tube(m, [(W / 2 - 0.01, 0.012, H + 0.0035), (W / 2 - 0.03, -0.01, H + 0.004), (W / 2 - 0.02, -0.04, H + 0.0035)], 0.0012, 4, "ficelle")
    return m


# ------------------------------------------------------------------ ingrédients
def os_long(m, p0, p1, r, g=0):
    n = 8
    pts = [v_add(p0, v_mul(v_sub(p1, p0), k / (n - 1))) for k in range(n)]
    ray = [r * (1.55 if k in (0, n - 1) else (1.15 if k in (1, n - 2) else 0.82 + 0.06 * math.sin(k))) for k in range(n)]
    tube(m, pts, ray, 7, "os_vieux", haut=(0, 0, 1), ecrase=0.85)
    d = v_norm(v_sub(p1, p0))
    pd = (-d[1], d[0], 0)
    for k, (p, s) in enumerate(((p0, -1), (p1, 1))):
        for side in (-1, 1):
            c = v_add(v_add(p, v_mul(d, s * r * 0.6)), v_mul(pd, side * r * 0.8))
            caillou(m, c, r * 1.15, "os_vieux", sub=0, bosse=0.15, g=g + k * 2 + side, ech=(1, 1, 0.85))


def os_draugr():
    m = M("os_draugr")
    os_long(m, (-0.15, -0.01, 0.022), (0.15, 0.012, 0.022), 0.0155, g=2)              # fémur
    os_long(m, (-0.07, 0.06, 0.04), (0.12, -0.05, 0.016), 0.0095, g=7)                # cubitus en travers
    return m


def poussiere_tombe():
    m = M("poussiere_tombe")
    fr = lambda x, y, z: (x, y, z + (0.004 * math.sin(math.atan2(y, x) * 5) if z > 0.085 else 0.0))
    tour(m, [(0, 0), (0.028, 0), (0.043, 0.016), (0.047, 0.036), (0.041, 0.056), (0.024, 0.071), (0.0155, 0.078),
             (0.022, 0.087), (0.03, 0.096), (0.027, 0.098)], "toile", n=10, ferme_haut=False, deforme=fr)
    tore(m, (0, 0, 0.078), 0.017, 0.002, "ficelle", n=10, cotes=4)
    tour(m, [(0.022, 0.086), (0.012, 0.091), (0, 0.093)], "cendre", n=8)                        # poussière au goulot
    tour(m, [(0, 0), (0.035, 0), (0.024, 0.005), (0.01, 0.009), (0, 0.01)], "cendre", n=9, c=(0.065, 0.01, 0), sx=1.3, sy=0.8)
    return m


def ecaille_dragon():
    m = M("ecaille_dragon")
    N = 14
    def contour(i, s=1.0):
        a = TAU * i / N + math.pi / 2
        x = math.cos(a) * 0.062
        y = math.sin(a) * 0.072
        if y < 0:
            x *= 1.0 + y / 0.072 * 0.75     # pointe vers -y
            y *= 1.25
        return (x * s, y * s)
    def bombe(x, y, s):
        return 0.03 * (1 - s * s) + 0.006
    centre = m.s((0, 0.01, 0.038))
    mid = [m.s((*contour(i, 0.55), bombe(0, 0, 0.55) + (0.004 if i == N // 2 + N // 4 or i == N // 4 else 0))) for i in range(N)]
    bord = [m.s((*contour(i, 1.0), 0.008)) for i in range(N)]
    dessous = [m.s((*contour(i, 0.96), 0.0)) for i in range(N)]
    cb = m.s((0, 0.01, 0.009))
    for i in range(N):
        j = (i + 1) % N
        m.face([centre, mid[i], mid[j]], "ecaille", [(0.5, 0.5), (0, 0), (1, 0)])
        m.face([mid[i], bord[i], bord[j], mid[j]], "ecaille", [(0, 0), (0, 1), (1, 1), (1, 0)])
        m.face([bord[i], dessous[i], dessous[j], bord[j]], "ecaille", [(0, 0), (0, 1), (1, 1), (1, 0)])
        m.face([cb, dessous[j], dessous[i]], "ecaille", [(0.5, 0.5), (1, 0), (0, 0)])
    # carène : arête centrale vers la pointe
    tube(m, [(0, 0.02, 0.036), (0, -0.03, 0.033), (0, -0.088, 0.009)], [0.007, 0.005, 0.0015], 4, "ecaille", haut=(0, 0, 1), ecrase=0.7)   # carène
    return m


def minerai(nom, veine, g):
    m = M(nom)
    def mf(c):
        return veine if bruit(c[0] * 45 + 5, c[1] * 45, c[2] * 45, g) > 0.62 else "roche"
    caillou(m, (0, 0, 0.04), 0.065, "roche", sub=2, bosse=0.28, g=g, ech=(1.2, 1.0, 0.72), sol=-0.035, mat_face=mf)
    for k in range(4 if veine == "veine_argent" else 3):                       # pépites / rognons qui affleurent
        a = TAU * h1(k, g)
        c = (math.cos(a) * 0.05, math.sin(a) * 0.04, 0.045 + 0.015 * h1(k + 9, g))
        caillou(m, c, 0.012 + 0.008 * h1(k + 3, g), veine, sub=0, bosse=0.35, g=g + k)
    return m


def cristal_givre():
    m = M("cristal_givre")
    caillou(m, (0, 0, 0.018), 0.04, "roche", sub=1, bosse=0.25, g=31, ech=(1.25, 1.0, 0.5), sol=-0.035)
    for k, (d, r, L) in enumerate((((0.05, 0.0, 1.0), 0.016, 0.115), ((0.6, 0.25, 0.75), 0.011, 0.075), ((-0.55, 0.35, 0.8), 0.012, 0.08),
                                   ((0.2, -0.65, 0.7), 0.009, 0.06), ((-0.4, -0.5, 0.55), 0.008, 0.05))):
        b = (d[0] * 0.012, d[1] * 0.012, 0.022)
        prisme(m, b, d, r, L, "cristal_givre", n=6, pointe=0.28, phase=k * 0.4)
    return m


def champignon_lumineux():
    m = M("champignon_lumineux")
    tour(m, [(0, 0), (0.05, 0), (0.042, 0.008), (0.022, 0.014), (0, 0.016)], "mousse", n=9, sx=1.2, sy=0.9,
         deforme=lambda x, y, z: (x, y, z + (bruit(x * 70, y * 70, 0, 4) - 0.5) * 0.006 * (z > 0.001)))
    for k, (x, y, h, r) in enumerate(((0.0, 0.0, 0.07, 0.024), (0.032, 0.012, 0.048, 0.017), (-0.026, 0.018, 0.04, 0.014), (0.012, -0.028, 0.03, 0.011))):
        incl = (x * 3, y * 3)
        def pench(px, py, pz, incl=incl):
            return (px + incl[0] * pz, py + incl[1] * pz, pz)
        tour(m, [(r * 0.28, 0.008), (r * 0.22, h * 0.6), (r * 0.26, h - r * 0.25)], "pied_champi", n=6, c=(x, y, 0), deforme=pench, ferme_haut=False)
        tour(m, [(r * 0.2, h - r * 0.3), (r * 0.95, h - r * 0.32), (r, h - r * 0.2), (r * 0.8, h + r * 0.15), (r * 0.42, h + r * 0.38), (0, h + r * 0.45)],
             "chapeau_lumineux", n=8, c=(x, y, 0), deforme=pench, mats=["pied_champi", "chapeau_lumineux", "chapeau_lumineux", "chapeau_lumineux", "chapeau_lumineux"])
    return m


def fourrure_troll():
    """Peau de troll pliée en trois, posée à plat : couches de fourrure hirsute aux bords déchirés, chair (peau) visible au pli,
    nouée d'un lien de cuir."""
    m = M("fourrure_troll")
    for k, (lx, ly, ep, ang) in enumerate(((0.36, 0.26, 0.022, 0.0), (0.33, 0.24, 0.02, 0.06), (0.3, 0.2, 0.024, -0.05))):
        z0 = k * 0.024
        ruban(m, (-lx / 2, -0.01 * k, z0), ang, lx, ly, ep, "fourrure", segs=7, g=11 + k * 4, onde=0.006, dechire=0.3)
    # bord de chair au pli (côté +x) : bourrelet de peau
    tube(m, [(0.165, -0.1, 0.03), (0.172, 0.0, 0.034), (0.165, 0.1, 0.03)], 0.026, 6, "peau", haut=(1, 0, 0), ecrase=0.5)
    # mèches qui dépassent (pointes de poil)
    for k in range(9):
        a = TAU * k / 9 + 0.3
        x, y = math.cos(a) * 0.17, math.sin(a) * 0.12
        prisme(m, (x * 0.85, y * 0.85, 0.05 + 0.01 * h1(k, 2)), (math.cos(a), math.sin(a), -0.2), 0.012, 0.05 + 0.02 * h1(k, 5), "fourrure", n=4, pointe=0.8)
    tube(m, [(-0.04 + 0.002 * k, math.cos(a) * 0.135, 0.04 + math.sin(a) * 0.045) for k, a in enumerate([TAU * q / 10 for q in range(10)])],
         0.004, 4, "cuir_m", ferme=True, haut=(1, 0, 0))
    return m


def croc_troll():
    m = M("croc_troll")
    n = 9
    pts, ray, mats = [], [], []
    for k in range(n):
        t = k / (n - 1)
        a = t * 1.1
        pts.append((math.sin(a) * 0.09 - 0.045, (1 - math.cos(a)) * 0.075 - 0.015, 0.016))
        ray.append(0.017 * (1 - t) ** 0.8 + 0.001)
    tube(m, pts[:4], ray[:4], 7, "os_vieux", haut=(0, 0, 1), ecrase=0.8)
    tube(m, pts[3:], ray[3:], 7, "croc", haut=(0, 0, 1), ecrase=0.8)
    # trou de lien percé à la racine + lanière
    tore(m, (pts[0][0] - 0.006, pts[0][1], 0.016), 0.011, 0.002, "cuir_m", n=8, cotes=4, plan="xz")
    return m


# ------------------------------------------------------------------ divers
def lame_antique():
    m = M("lame_antique")
    segs = 9
    Lb = 0.47
    rings = []
    for k in range(segs + 1):
        t = k / segs
        x = 0.06 + Lb * t
        w = 0.024 * (1 - t * 0.35)
        if k == segs:
            w = 0.006                                                        # pointe cassée net
        cg = w - (0.006 if h1(k, 4) > 0.55 else 0.0)                         # ébréchures
        cd = w - (0.007 if h1(k, 8) > 0.6 else 0.0)
        e = 0.0045 * (1 - t * 0.5)
        rings.append([m.s((x, cg, 0.005)), m.s((x, 0, 0.005 + e)), m.s((x, -cd, 0.005)), m.s((x, 0, 0.005 - e))])
    for k in range(segs):
        for i in range(4):
            j = (i + 1) % 4
            m.face([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], "fer_rouille", [(k / segs, i / 4), (k / segs, j / 4), ((k + 1) / segs, j / 4), ((k + 1) / segs, i / 4)])
    m.face(list(reversed(rings[-1])), "fer_rouille", [(0, 0), (1, 0), (1, 1), (0, 1)])
    m.face(rings[0], "fer_rouille", [(0, 0), (1, 0), (1, 1), (0, 1)])
    pave(m, (0.055, 0, 0.008), (0.014, 0.11, 0.016), "bronze_m", coins=lambda p: (p[0], p[1], p[2] - 0.004 * (abs(p[1]) > 0.04)))   # garde
    tube(m, [(0.048, 0, 0.0095), (-0.045, 0, 0.0095)], [0.0105, 0.0095], 6, "cuir_m", haut=(0, 0, 1))                            # fusée
    for k in range(4):
        tore(m, (0.035 - k * 0.022, 0, 0.0095), 0.0105, 0.0016, "cuir_m", n=6, cotes=3, plan="yz")
    caillou(m, (-0.058, 0, 0.012), 0.016, "bronze_m", sub=0, bosse=0.1, g=3, ech=(0.8, 1.4, 0.75))                                # pommeau
    return m


def relique_offrande():
    m = M("relique_offrande")
    W, P, H = 0.15, 0.065, 0.068
    pave(m, (0, 0, 0.008), (W + 0.01, P + 0.01, 0.016), "bronze_m")                               # socle
    pave(m, (0, 0, 0.016 + H / 2), (W, P, H), "bois")                                             # coffre (âme de bois)
    for sx in (-1, 1):                                                                            # plaques d'or aux faces
        pave(m, (sx * (W / 2 + 0.001), 0, 0.016 + H / 2), (0.002, P - 0.008, H - 0.008), "bronze_m")
    for sy in (-1, 1):
        pave(m, (0, sy * (P / 2 + 0.001), 0.016 + H / 2), (W - 0.01, 0.002, H - 0.01), "bronze_m")
    # toit en bâtière (maison-reliquaire) avec faîtage et têtes de bête
    z0 = 0.016 + H
    zt = z0 + 0.045
    a = [m.s((-W / 2 - 0.004, -P / 2 - 0.006, z0)), m.s((W / 2 + 0.004, -P / 2 - 0.006, z0)), m.s((W / 2 + 0.004, P / 2 + 0.006, z0)),
         m.s((-W / 2 - 0.004, P / 2 + 0.006, z0)), m.s((-W / 2 - 0.004, 0, zt)), m.s((W / 2 + 0.004, 0, zt))]
    m.face([a[0], a[1], a[5], a[4]], "or_m", [(0, 0), (1, 0), (1, 1), (0, 1)])
    m.face([a[2], a[3], a[4], a[5]], "or_m", [(0, 0), (1, 0), (1, 1), (0, 1)])
    m.face([a[1], a[2], a[5]], "or_m", [(0, 0), (1, 0), (0.5, 1)])
    m.face([a[3], a[0], a[4]], "or_m", [(0, 0), (1, 0), (0.5, 1)])
    m.face([a[0], a[3], a[2], a[1]], "or_m", [(0, 0), (1, 0), (1, 1), (0, 1)])
    tube(m, [(-W / 2 - 0.012, 0, zt + 0.004), (W / 2 + 0.012, 0, zt + 0.004)], 0.004, 5, "or_m", haut=(0, 0, 1))
    for sx in (-1, 1):
        caillou(m, (sx * (W / 2 + 0.016), 0, zt + 0.008), 0.008, "or_m", sub=0, bosse=0.2, g=sx + 4, ech=(1.4, 0.7, 1.0))
    # pierres serties : rubis au centre des faces longues, cristaux aux coins
    for sy in (-1, 1):
        brillant(m, (0, sy * (P / 2 + 0.002), 0.016 + H / 2), 0.009, 0.003, 0.004, "rubis", n=8, axe="y" if sy > 0 else "-y")
        for sx in (-1, 1):
            cabochon_y = (sx * W * 0.32, sy * (P / 2 + 0.002), 0.016 + H * 0.5)
            brillant(m, cabochon_y, 0.0055, 0.002, 0.003, "gemme", n=6, axe="y" if sy > 0 else "-y")
        brillant(m, (0, sy * (P / 4 + 0.002), z0 + 0.024), 0.006, 0.002, 0.003, "gemme", n=6)
    return m


def anneau_cuivre():
    m = M("anneau_cuivre")
    jonc(m, "cuivre", largeur=0.0052, epaisseur=0.0024, n=18)
    for z in (0.0006, 0.0046):
        tore(m, (0, 0, z), R_DOIGT + 0.0024, 0.0005, "cuivre", n=18, cotes=4)
    return m


def coupe_argent():
    m = M("coupe_argent")
    prof = [(0, 0), (0.034, 0), (0.036, 0.004), (0.03, 0.008), (0.012, 0.016), (0.0075, 0.03), (0.0125, 0.043), (0.0075, 0.056),
            (0.011, 0.066), (0.028, 0.076), (0.039, 0.096), (0.044, 0.125), (0.0455, 0.148), (0.042, 0.149), (0.039, 0.124),
            (0.034, 0.098), (0.022, 0.085), (0, 0.082)]
    tour(m, prof, "argent_m", n=12, ferme_haut=False)
    tore(m, (0, 0, 0.128), 0.0447, 0.0022, "or_m", n=12, cotes=4)
    tore(m, (0, 0, 0.043), 0.0128, 0.002, "or_m", n=10, cotes=4)
    return m


def collier_or():
    m = M("collier_or")
    g = goutte_gabarit(0.062, 0.078, 0.5)
    tube(m, [(*g(t / 20), 0.0022) for t in range(20)], 0.0021, 4, "or", ferme=True)          # cordon d'or torsadé
    fil = []
    for k in range(34):
        t = k / 34
        x, y = g(t)
        x2, y2 = g((k + 1) / 34)
        d = v_norm((x2 - x, y2 - y, 0))
        a = k * 2.2
        fil.append((x - d[1] * math.cos(a) * 0.0021, y + d[0] * math.cos(a) * 0.0021, 0.0022 + math.sin(a) * 0.0021))
    tube(m, fil, 0.0009, 3, "or", ferme=True)
    tore(m, (0, -0.081, 0.0018), 0.0034, 0.0009, "or", n=8, cotes=4, plan="yz")
    c = (0, -0.1, 0)
    cabochon(m, c, 0.0165, 0.0165, 0.0035, "or", n=12, anneaux=2)
    tore(m, (c[0], c[1], 0.0018), 0.0168, 0.0016, "or", n=12, cotes=3)
    for k in range(3):                                                           # entrelacs en relief
        a = TAU * k / 3
        tube(m, [(c[0] + math.cos(a) * 0.004, c[1] + math.sin(a) * 0.004, 0.0038), (c[0] + math.cos(a + 1.2) * 0.012, c[1] + math.sin(a + 1.2) * 0.012, 0.003)],
             0.0011, 3, "or")
    brillant(m, (c[0], c[1], 0.0046), 0.0042, 0.0016, 0.002, "rubis", n=8)
    return m


# ------------------------------------------------------------------ quête
def anneau_givre():
    m = anneau_gemme("anneau_givre", "argent", "gemme", r=0.0056, etire=1.25, pointe=1.4)
    m.__class__ = M
    return m


def amulette_eirik():
    m = M("amulette_eirik")
    g = goutte_gabarit(0.068, 0.082, 0.55)
    pts = [(*g(t / 24), 0.0016) for t in range(24)]
    tube(m, pts, 0.0017, 4, "cuir", ferme=True)
    for k in (-1, 1):                                                            # perles de fer près du pendentif
        p = g(0.5 + k * 0.06)
        caillou(m, (p[0], p[1], 0.0028), 0.0028, "fer", sub=0, bosse=0.05, g=k + 2)
    # marteau (Mjöllnir) d'argent couché, tête vers -y
    y0 = -0.086
    tore(m, (0, y0, 0.002), 0.0035, 0.001, "argent", n=8, cotes=4, plan="yz")
    pave(m, (0, y0 - 0.013, 0.0022), (0.0055, 0.019, 0.0044), "argent")                      # manche
    pave(m, (0, y0 - 0.027, 0.0026), (0.026, 0.012, 0.0052), "argent",                        # tête évasée
         coins=lambda p: (p[0] * (1.0 if p[1] < y0 - 0.027 else 0.62), p[1], p[2]))
    for sx in (-1, 1):
        pave(m, (sx * 0.006, y0 - 0.027, 0.0055), (0.004, 0.006, 0.0012), "argent")          # ciselure
    return m


def fragment_sceau(nom, a0, base, incr):
    """Tiers d'un sceau circulaire de pierre (les trois fragments s'assemblent : os 0-120°, givre 120-240°, eau 240-360°)."""
    m = M(nom)
    R, H = 0.1, 0.022
    radii = [0.0, 0.03, 0.055, 0.06, 0.074, 0.079, 0.1]
    ns = 9
    def ang(i, r):
        a = a0 + (TAU / 3) * i / (ns - 1)
        if i in (0, ns - 1):                                                     # cassure dentelée le long des rayons
            a += (h1(int(r * 1000) + i * 7, len(nom)) - 0.5) * 0.18
        return a
    def z_de(ri, i):
        r = radii[ri]
        if 0.06 <= r <= 0.074:
            return H + 0.003
        return H - (0.002 if r > 0.079 else 0.0)
    top = []
    bot = []
    for ri, r in enumerate(radii):
        rowt, rowb = [], []
        for i in range(ns):
            a = ang(i, r) if r > 0 else 0.0
            rr = r if ri < len(radii) - 1 else r * (1 - 0.04 * h1(i, 3))
            rowt.append(m.s((math.cos(a) * rr, math.sin(a) * rr, z_de(ri, i))))
            rowb.append(m.s((math.cos(a) * rr, math.sin(a) * rr, 0.0)))
        top.append(rowt)
        bot.append(rowb)
    for ri in range(len(radii) - 1):
        for i in range(ns - 1):
            r_mid = (radii[ri] + radii[ri + 1]) / 2
            mt = base
            if 0.06 <= r_mid <= 0.074:
                mt = incr
            elif r_mid > 0.079 and h1(i * 3 + ri, len(nom) + 1) > 0.45:
                mt = incr                                                         # runes incrustées dans le bandeau
            q = [top[ri][i], top[ri][i + 1], top[ri + 1][i + 1], top[ri + 1][i]]
            m.face(q, mt, [(0, 0), (1, 0), (1, 1), (0, 1)])
            m.face([bot[ri][i + 1], bot[ri][i], bot[ri + 1][i], bot[ri + 1][i + 1]], base, [(0, 0), (1, 0), (1, 1), (0, 1)])
    last = len(radii) - 1
    for i in range(ns - 1):
        m.face([top[last][i + 1], top[last][i], bot[last][i], bot[last][i + 1]], base, [(0, 0), (1, 0), (1, 1), (0, 1)])
    for ri in range(len(radii) - 1):
        for i in (0, ns - 1):
            q = [top[ri][i], top[ri + 1][i], bot[ri + 1][i], bot[ri][i]]
            m.face(q if i == 0 else list(reversed(q)), base, [(0, 0), (1, 0), (1, 1), (0, 1)])
    return m


def cle_archives():
    m = M("cle_archives")
    z = 0.0042
    tore(m, (-0.05, 0, z), 0.017, 0.0042, "fer_m", n=12, cotes=5)                               # anneau
    tube(m, [(-0.033, 0, z), (0.072, 0, z)], 0.0042, 6, "fer_m", haut=(0, 0, 1))                # tige
    for x in (-0.03, -0.022, 0.06):
        tore(m, (x, 0, z), 0.0048, 0.0017, "fer_m", n=8, cotes=4, plan="yz")                     # bagues
    pave(m, (0.064, -0.013, z), (0.018, 0.02, 0.006), "fer_m")                                   # panneton
    for k, (x, l) in enumerate(((0.058, 0.007), (0.064, 0.012), (0.07, 0.005))):
        pave(m, (x, -0.023 - l / 2, z), (0.004, l, 0.006), "fer_m")                              # dents
    return m


def broche_sigrun():
    m = M("broche_sigrun")
    R = 0.021
    pts = [(math.cos(a) * R, math.sin(a) * R, 0.003) for a in [math.radians(-60 + 300 * k / 15) for k in range(16)]]
    tube(m, pts, 0.0026, 6, "argent", bouts=True)
    for p in (pts[0], pts[-1]):                                                  # terminaux en bouton (têtes de bête)
        cabochon(m, (p[0], p[1], 0.0), 0.0062, 0.0062, 0.0068, "argent", n=8, anneaux=2)
    tore(m, (-R, 0, 0.0045), 0.0034, 0.0012, "argent", n=8, cotes=4, plan="yz")                # œillet de l'épingle
    tube(m, [(-R - 0.001, 0, 0.0052), (0.0, 0.0, 0.0062), (R + 0.012, 0.0, 0.0052)], [0.0016, 0.0013, 0.0004], 5, "argent")   # épingle
    cabochon(m, (pts[0][0], pts[0][1], 0.0060), 0.0026, 0.0026, 0.0022, "jade", n=6, anneaux=2)
    cabochon(m, (pts[-1][0], pts[-1][1], 0.0060), 0.0026, 0.0026, 0.0022, "jade", n=6, anneaux=2)
    return m


# ------------------------------------------------------------------ registre
FABRIQUES = {
    "potion_soin": potion_soin, "potion_soin_forte": potion_soin_forte, "potion_mana": potion_mana, "potion_endurance": potion_endurance,
    "pain_seigle": pain_seigle, "viande_sechee": viande_sechee,
    "os_draugr": os_draugr, "poussiere_tombe": poussiere_tombe, "ecaille_dragon": ecaille_dragon,
    "minerai_fer": lambda: minerai("minerai_fer", "veine_fer", 13), "minerai_argent": lambda: minerai("minerai_argent", "veine_argent", 21),
    "cristal_givre": cristal_givre, "champignon_lumineux": champignon_lumineux, "fourrure_troll": fourrure_troll, "croc_troll": croc_troll,
    "lame_antique": lame_antique, "relique_offrande": relique_offrande, "anneau_cuivre": anneau_cuivre, "coupe_argent": coupe_argent,
    "collier_or": collier_or,
    "anneau_givre": anneau_givre, "amulette_eirik": amulette_eirik,
    "fragment_sceau_os": lambda: fragment_sceau("fragment_sceau_os", 0.0, "sceau_os", "obsidienne"),
    "fragment_sceau_givre": lambda: fragment_sceau("fragment_sceau_givre", TAU / 3, "sceau_givre", "cristal_givre"),
    "fragment_sceau_eau": lambda: fragment_sceau("fragment_sceau_eau", 2 * TAU / 3, "sceau_eau", "saphir"),
    "cle_archives": cle_archives, "registre_hrafn": registre_hrafn, "journal_sigrun": journal_sigrun, "broche_sigrun": broche_sigrun,
}
for _t in TOMES:
    FABRIQUES[_t] = (lambda n: (lambda: tome(n)))(_t)


def exporter(nom):
    vider()
    mm = FABRIQUES[nom]()
    if not isinstance(mm, M):
        mm.__class__ = M
    o = mm.creer()
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
    mats = ",".join(mt.name for mt in me.materials)
    print("OBJET %-26s tris=%4d taille=%.3f x %.3f x %.3f m  [%s]" % (nom, tris, dims[0], dims[1], dims[2], mats))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nom in (args or list(FABRIQUES)):
    exporter(nom)
