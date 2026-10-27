# Épées longues de la planche « combat à l'épée » (références/combat_epee) : métal, or, rubis, verre, obsidienne.
#   blender.exe -b --python epees_longues.py -- [metal or rubis verre obsidienne]   (sans argument : les cinq)
# Exporte assets/modeles/armes/epees/<variante>.glb (+ epees_longues.blend à côté de ce script).
#
# REPÈRE (identique à assets/modeles/joueur/epee_nordique.glb, voir scripts/mains.gd) :
#   glTF : +Y le long de la lame, +X = tranchant / quillons (sens des jointures), Z = épaisseur.
#   Blender : Z = le long de la lame, X = tranchant, Y = épaisseur (export Y-up : glTF Y = Z, glTF Z = -Y).
#   Origine au même endroit que l'épée nordique : centre du poing (MILIEU_POIGNEE) à 0,03 m, garde à ~0,09 m.
#   La poignée d'épée longue se prolonge SOUS la main (prise à une main et demie), pommeau plus bas.
# NŒUDS VIDES : `prise` (centre du poing, y = 0,03), `garde` (base de la lame), `pointe` (bout de la lame).
# MATÉRIAUX (noms stables, appliqués dans Godot par scripts/armes/materiaux_epees.gd) :
#   lame, lame_or, fer, or, cuir, gemme, rubis, verre, emeraude, obsidienne, veine.
# Textures : aucune dans le glb ; elles sont dessinées en pixel art dans Godot (palette limitée).
# UV : lame u = travers (0 = -X, 1 = +X), v = longueur (0 = garde, 1 = pointe) ; poignée u = tour (x2), v = long.
import bpy, bmesh, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "epees")

MATS = ("lame", "lame_or", "fer", "or", "cuir", "gemme", "rubis", "verre", "emeraude", "obsidienne", "veine")

Z_PRISE = 0.03


def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


class Maille:
    """Petite maille : sommets, faces (indices, matériau, uv par coin)."""

    def __init__(self, nom):
        self.nom = nom
        self.v = []
        self.f = []

    def sommet(self, p):
        self.v.append(tuple(p))
        return len(self.v) - 1

    def face(self, idx, mat, uvs):
        self.f.append((list(idx), mat, list(uvs)))

    def creer(self, lisse=False):
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        uvl = bm.loops.layers.uv.new("UVMap")
        noms = []
        for idx, mat, uvs in self.f:
            if mat not in noms:
                noms.append(mat)
        for idx, mat, uvs in self.f:
            try:
                bf = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            bf.material_index = noms.index(mat)
            bf.smooth = lisse
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


def relier(m, anneaux, mat_de, uv_de, ferme=True):
    """Relie des anneaux de même taille ; mat_de(k, i) -> matériau du quad (k, i) ; uv_de(p, k, i) -> uv."""
    n = len(anneaux[0])
    ids = [[m.sommet(p) for p in a] for a in anneaux]
    for k in range(len(anneaux) - 1):
        for i in range(n):
            j = (i + 1) % n
            if not ferme and j == 0:
                continue
            q = [ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]]
            pts = [anneaux[k][i], anneaux[k][j], anneaux[k + 1][j], anneaux[k + 1][i]]
            mat = mat_de(k, i)
            uvs = [uv_de(p, k + (1 if c >= 2 else 0), (i if c in (0, 3) else i + 1), mat) for c, p in enumerate(pts)]
            m.face(q, mat, uvs)
    return ids


def pointe_sur(m, ids_anneau, anneau, sommet_p, mat_de, uv_de, uv_pointe):
    t = m.sommet(sommet_p)
    n = len(ids_anneau)
    for i in range(n):
        j = (i + 1) % n
        m.face([ids_anneau[i], ids_anneau[j], t], mat_de(i), [uv_de(anneau[i], 0, i), uv_de(anneau[j], 0, i + 1), uv_pointe])


def capuchon(m, ids_anneau, anneau, mat, uv_de):
    m.face(list(reversed(ids_anneau)), mat, [uv_de(p, 0, 0) for p in reversed(anneau)])


# ------------------------------------------------------------------ lame
ELARGIR = (1.7, 1.2)    # lames de la planche : ~1,7x plus larges à la garde, effilées vers la pointe
# lames ROBUSTES (retour utilisateur 2026-10-27 : « pas l'impression de faire de l'escrime ») : vues de tranche (tenue à
# 79°), c'est l'épaisseur qui fait la largeur apparente → dos 1,8x plus épais, lame 1,12x plus large, biseaux plus courts
# (méplat plus large : l'arête du dos se lit), gouttière gardée
EPAIS = 1.8
LARGE = 1.12


def lame(m, prof, z0, z_pointe, section, mat_de, w_ref, sym_dx=None, elargir=ELARGIR):
    """prof : liste de (z, demi-largeur, demi-épaisseur[, décalage de l'arête en x]).
    section 'hex' (plat + biseaux, 6 sommets), 'diamant' (4 sommets, cristal), 'veine' (10 sommets, bande centrale)."""
    anneaux = []
    L = z_pointe - z0
    w_ref = w_ref * elargir[0] * LARGE
    for st in prof:
        z, w, t = st[0], st[1] * LARGE, st[2] * EPAIS
        fr = (z - z0) / L
        w = w * (elargir[0] + (elargir[1] - elargir[0]) * fr)
        dx = st[3] if len(st) > 3 else 0.0
        if section == "gorge":   # plat + biseaux + gouttière centrale en creux (s'efface vers la pointe)
            c = w * 0.64
            g = w * 0.26 if fr < 0.74 else w * 0.02
            f = t * (0.55 if fr < 0.74 else 0.98)
            a = [(-w, 0, z), (-c, t, z), (-g, f, z), (g, f, z), (c, t, z), (w, 0, z),
                 (c, -t, z), (g, -f, z), (-g, -f, z), (-c, -t, z)]
        elif section == "hex":
            c = w * 0.42
            a = [(-w, 0, z), (-c, t, z), (c, t, z), (w, 0, z), (c, -t, z), (-c, -t, z)]
        elif section == "diamant":
            a = [(-w, 0, z), (dx, t, z), (w, 0, z), (dx, -t, z)]
        else:  # veine : biseau, plat, bande centrale (veine), plat, biseau
            c = w * 0.55
            v = w * 0.16
            a = [(-w, 0, z), (-c, t, z), (-v, t * 1.05, z), (v, t * 1.05, z), (c, t, z), (w, 0, z),
                 (c, -t, z), (v, -t * 1.05, z), (-v, -t * 1.05, z), (-c, -t, z)]
        anneaux.append(a)

    def uv(p, k, i, mat=None):
        v = max(0.0, (p[2] - z0) / L)
        if mat == "veine":      # la bande de veine a sa propre texture, étalée sur toute sa largeur
            st = prof[min(k, len(prof) - 1)]
            demi = st[1] * LARGE * (elargir[0] + (elargir[1] - elargir[0]) * (st[0] - z0) / L) * 0.16
            return ((p[0] / demi + 1.0) * 0.5, v)
        return ((p[0] + w_ref) / (2 * w_ref), v)
    ids = relier(m, anneaux, mat_de, uv)
    pointe_sur(m, ids[-1], anneaux[-1], (0, 0, z_pointe), lambda i: mat_de(len(anneaux) - 1, i), uv, (0.5, 1.0))
    capuchon(m, ids[0], anneaux[0], mat_de(0, 0), uv)


# ------------------------------------------------------------------ garde (barre transversale le long de X)
def barre(m, stations, mat, z_centre, cotes=6, uv_l=2.0):
    """stations : (x, demi-hauteur z, demi-épaisseur y, décalage z). Section hexagonale (ou carrée si cotes = 4)."""
    anneaux = []
    for x, h, t, dz in stations:
        x, h, t, dz = x * 1.25, h * 1.35, t * 1.35, dz * 1.25
        if cotes == 4:
            sec = [(0, -h), (t, 0), (0, h), (-t, 0)]
        else:
            sec = [(-t, -h * 0.55), (-t, h * 0.55), (0, h), (t, h * 0.55), (t, -h * 0.55), (0, -h)]
        anneaux.append([(x, y, z_centre + dz + z) for y, z in sec])
    x0, x1 = stations[0][0] * 1.25, stations[-1][0] * 1.25

    def uv(p, k, i, mat=None):
        return ((p[0] - x0) / (x1 - x0) * uv_l, i / cotes)
    ids = relier(m, anneaux, lambda k, i: mat, uv)
    capuchon(m, ids[0], anneaux[0], mat, uv)
    m.face(ids[-1], mat, [uv(p, 0, 0) for p in anneaux[-1]])


def plaque(m, c, rx, ry, rz_haut, rz_bas, mat):
    """Plaque centrale de garde (langue en losange), à l'échelle des lames élargies."""
    octaedre(m, (c[0] * 1.25, c[1], c[2]), rx * 1.6, ry * 1.3, rz_haut * 1.3, rz_bas * 1.3, mat)


def octaedre(m, c, rx, ry, rz_haut, rz_bas, mat, dx_haut=0.0):
    """Losange 3D (gemme, plaque centrale, cristal) : 8 triangles."""
    cx, cy, cz = c
    h = m.sommet((cx + dx_haut, cy, cz + rz_haut))
    b = m.sommet((cx, cy, cz - rz_bas))
    eq = [m.sommet(p) for p in ((cx + rx, cy, cz), (cx, cy + ry, cz), (cx - rx, cy, cz), (cx, cy - ry, cz))]
    uvq = [(1, 0.5), (0.5, 1), (0, 0.5), (0.5, 0)]
    for i in range(4):
        j = (i + 1) % 4
        m.face([eq[i], eq[j], h], mat, [uvq[i], uvq[j], (0.5, 0.5)])
        m.face([eq[j], eq[i], b], mat, [uvq[j], uvq[i], (0.5, 0.5)])


# ------------------------------------------------------------------ tour (poignée, pommeau)
def tour(m, profil, mat, cotes=8, ecrase_y=1.0, bas=None, haut=None, rot=0.0, uv_tours=2.0, mat_de=None):
    """profil : (z, rayon) du bas vers le haut ; bas/haut : z d'une pointe fermant le tour (None = ouvert)."""
    anneaux = []
    for z, r in profil:
        anneaux.append([(r * math.cos(rot + 2 * math.pi * i / cotes), r * ecrase_y * math.sin(rot + 2 * math.pi * i / cotes), z)
                        for i in range(cotes)])
    z0, z1 = profil[0][0], profil[-1][0]

    def uv(p, k, i, mat=None):
        return (i / cotes * uv_tours, (p[2] - z0) / max(1e-6, z1 - z0))
    md = mat_de or (lambda k, i: mat)
    ids = relier(m, anneaux, md, uv)
    if bas is not None:
        t = m.sommet((0, 0, bas))
        for i in range(cotes):
            j = (i + 1) % cotes
            m.face([ids[0][j], ids[0][i], t], md(0, i), [uv(anneaux[0][j], 0, j), uv(anneaux[0][i], 0, i), (0.5, 0)])
    if haut is not None:
        t = m.sommet((0, 0, haut))
        k = len(anneaux) - 1
        for i in range(cotes):
            j = (i + 1) % cotes
            m.face([ids[k][i], ids[k][j], t], md(k, i), [uv(anneaux[k][i], k, i), uv(anneaux[k][j], k, j), (0.5, 1)])


def poignee(m, z0, z1, r, mat="cuir"):
    zs = [z0, z0 + (z1 - z0) * 0.3, z0 + (z1 - z0) * 0.62, z1]
    rs = [r, r * 1.08, r * 1.03, r]
    tour(m, list(zip(zs, rs)), mat, cotes=8, ecrase_y=0.9, uv_tours=2.0)


def vide(nom, z):
    o = bpy.data.objects.new(nom, None)
    o.location = (0, 0, z)
    o.empty_display_size = 0.02
    bpy.context.scene.collection.objects.link(o)
    return o


# ================================================================== variantes
def epee_metal():
    """Acier : lame à plat et biseaux, garde en croix sombre droite à bouts renflés, gemme au centre, cuir tressé, pommeau rond."""
    zt = 0.965
    L = Maille("lame")
    prof = [(0.086, 0.0235, 0.0042), (0.13, 0.0240, 0.0040), (0.45, 0.0215, 0.0036), (0.76, 0.0180, 0.0031),
            (0.88, 0.0120, 0.0026), (0.935, 0.0060, 0.0020)]
    lame(L, prof, 0.086, zt, "gorge", lambda k, i: "lame", 0.024)
    L.creer()
    G = Maille("croisee")
    barre(G, [(-0.110, 0.0050, 0.0055, -0.005), (-0.101, 0.0120, 0.0105, -0.004), (-0.088, 0.0085, 0.0080, -0.001),
              (-0.030, 0.0100, 0.0095, 0.0), (0.030, 0.0100, 0.0095, 0.0), (0.088, 0.0085, 0.0080, -0.001),
              (0.101, 0.0120, 0.0105, -0.004), (0.110, 0.0050, 0.0055, -0.005)], "fer", 0.092)
    plaque(G, (0, 0, 0.093), 0.030, 0.0125, 0.046, 0.028, "fer")       # plaque centrale en losange (langue de garde)
    G.creer()
    J = Maille("gemme")
    octaedre(J, (0, 0, 0.096), 0.0224, 0.0301, 0.0266, 0.021, "gemme")
    J.creer()
    P = Maille("poignee")
    poignee(P, -0.088, 0.084, 0.0165)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(-0.088, 0.0140), (-0.096, 0.0270), (-0.112, 0.0320), (-0.126, 0.0240)], "fer", cotes=8, ecrase_y=0.6,
         bas=-0.134, uv_tours=1.0)
    M.creer()
    return 0.086, zt


def epee_or():
    """Or : lame d'acier doré gravée, quillons dorés recourbés vers la lame et évasés, pommeau à facettes, rubis central."""
    zt = 0.955
    L = Maille("lame")
    prof = [(0.088, 0.0215, 0.0038), (0.14, 0.0225, 0.0037), (0.50, 0.0195, 0.0033), (0.78, 0.0160, 0.0029),
            (0.885, 0.0100, 0.0023), (0.93, 0.0050, 0.0018)]
    lame(L, prof, 0.088, zt, "gorge", lambda k, i: "lame_or", 0.0225)
    L.creer()
    G = Maille("croisee")
    barre(G, [(-0.112, 0.0020, 0.0040, 0.030), (-0.106, 0.0110, 0.0060, 0.022), (-0.094, 0.0070, 0.0060, 0.010),
              (-0.060, 0.0065, 0.0070, 0.001), (-0.020, 0.0125, 0.0110, 0.0), (0.020, 0.0125, 0.0110, 0.0),
              (0.060, 0.0065, 0.0070, 0.001), (0.094, 0.0070, 0.0060, 0.010), (0.106, 0.0110, 0.0060, 0.022),
              (0.112, 0.0020, 0.0040, 0.030)], "or", 0.090)
    plaque(G, (0, 0, 0.092), 0.020, 0.0110, 0.034, 0.030, "or")
    G.creer()
    J = Maille("gemme")
    octaedre(J, (0, 0, 0.095), 0.021, 0.0294, 0.0252, 0.0196, "rubis")
    J.creer()
    P = Maille("poignee")
    poignee(P, -0.082, 0.082, 0.0160)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(-0.084, 0.0150), (-0.091, 0.0260), (-0.106, 0.0290), (-0.120, 0.0170)], "or", cotes=6, ecrase_y=0.75,
         bas=-0.133, uv_tours=1.0, rot=math.pi / 6)
    M.creer()
    return 0.088, zt


def epee_rubis():
    """Rubis : lame cristalline à section losange, facettes irrégulières (arête décalée, largeurs en gradins),
    garde de fer sombre aux quillons tombants, rubis au centre et cristal au pommeau."""
    zt = 0.975
    L = Maille("lame")
    prof = [(0.086, 0.0200, 0.0060, 0.000), (0.12, 0.0250, 0.0068, 0.003), (0.26, 0.0225, 0.0064, -0.004),
            (0.40, 0.0240, 0.0062, 0.003), (0.55, 0.0205, 0.0058, -0.003), (0.68, 0.0215, 0.0055, 0.003),
            (0.80, 0.0165, 0.0048, -0.002), (0.89, 0.0105, 0.0040, 0.001)]
    lame(L, prof, 0.086, zt, "gorge", lambda k, i: "rubis", 0.025)
    L.creer()
    G = Maille("croisee")
    barre(G, [(-0.104, 0.0020, 0.0030, -0.022), (-0.096, 0.0075, 0.0070, -0.014), (-0.070, 0.0080, 0.0075, -0.003),
              (-0.024, 0.0110, 0.0095, 0.0), (0.024, 0.0110, 0.0095, 0.0), (0.070, 0.0080, 0.0075, -0.003),
              (0.096, 0.0075, 0.0070, -0.014), (0.104, 0.0020, 0.0030, -0.022)], "fer", 0.091)
    plaque(G, (0, 0, 0.092), 0.022, 0.0115, 0.036, 0.026, "fer")
    G.creer()
    J = Maille("gemme")
    octaedre(J, (0, 0, 0.097), 0.021, 0.0301, 0.0252, 0.0196, "rubis")
    octaedre(J, (0, 0, -0.120), 0.0190, 0.0140, 0.0120, 0.0230, "rubis")    # cristal du pommeau
    J.creer()
    P = Maille("poignee")
    poignee(P, -0.084, 0.083, 0.0160)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(-0.100, 0.0160), (-0.091, 0.0215), (-0.084, 0.0150)], "fer", cotes=6, ecrase_y=0.8, uv_tours=1.0)
    M.creer()
    return 0.086, zt


def epee_verre():
    """Verre : lame translucide émeraude, fine (section losange mince, plus étroite), garde de fer verdi fine et
    élancée, émeraudes au centre et aux bouts des quillons, cristal au pommeau."""
    zt = 0.955
    L = Maille("lame")
    prof = [(0.086, 0.0190, 0.0042, 0.0), (0.13, 0.0225, 0.0045, 0.002), (0.32, 0.0212, 0.0043, -0.002),
            (0.52, 0.0205, 0.0040, 0.002), (0.70, 0.0188, 0.0036, -0.0015), (0.82, 0.0145, 0.0031, 0.001),
            (0.90, 0.0080, 0.0025, 0.0)]
    lame(L, prof, 0.086, zt, "gorge", lambda k, i: "verre", 0.0225, elargir=(1.55, 1.15))
    L.creer()
    G = Maille("croisee")
    barre(G, [(-0.100, 0.0030, 0.0030, 0.012), (-0.090, 0.0060, 0.0050, 0.006), (-0.050, 0.0055, 0.0055, 0.0),
              (-0.018, 0.0090, 0.0080, 0.0), (0.018, 0.0090, 0.0080, 0.0), (0.050, 0.0055, 0.0055, 0.0),
              (0.090, 0.0060, 0.0050, 0.006), (0.100, 0.0030, 0.0030, 0.012)], "fer", 0.091)
    plaque(G, (0, 0, 0.092), 0.017, 0.0095, 0.030, 0.022, "fer")
    G.creer()
    J = Maille("gemme")
    octaedre(J, (0, 0, 0.096), 0.0196, 0.0266, 0.0238, 0.0182, "emeraude")
    for sx in (-1, 1):
        octaedre(J, (sx * 0.132, 0, 0.106), 0.0075, 0.0065, 0.0105, 0.0050, "emeraude")
    octaedre(J, (0, 0, -0.116), 0.0160, 0.0120, 0.0100, 0.0210, "emeraude")
    J.creer()
    P = Maille("poignee")
    poignee(P, -0.080, 0.083, 0.0150)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(-0.096, 0.0150), (-0.088, 0.0200), (-0.080, 0.0140)], "fer", cotes=6, ecrase_y=0.8, uv_tours=1.0)
    M.creer()
    return 0.086, zt


def epee_obsidienne():
    """Obsidienne : lame large et épaisse, bande centrale de veines rougeoyantes, crans dentelés près de la garde ;
    garde agressive en pointes relevées vers la lame ; pommeau en pointe."""
    zt = 0.995
    L = Maille("lame")
    prof = [(0.088, 0.0290, 0.0062), (0.12, 0.0315, 0.0062), (0.150, 0.0270, 0.0062), (0.152, 0.0320, 0.0061),
            (0.200, 0.0280, 0.0060), (0.202, 0.0322, 0.0060), (0.255, 0.0290, 0.0059), (0.45, 0.0300, 0.0056),
            (0.72, 0.0265, 0.0050), (0.86, 0.0190, 0.0042), (0.94, 0.0090, 0.0030)]
    # veine : bande centrale (quads 2 et 7 de l'anneau à 10 sommets), sur toute la lame sauf la pointe
    lame(L, prof, 0.088, zt, "veine",
         lambda k, i: "veine" if (i in (2, 7) and k < len(prof) - 1) else "obsidienne", 0.032, elargir=(1.45, 1.15))
    L.creer()
    G = Maille("croisee")
    barre(G, [(-0.118, 0.0015, 0.0020, 0.050), (-0.108, 0.0080, 0.0060, 0.030), (-0.088, 0.0110, 0.0085, 0.010),
              (-0.050, 0.0105, 0.0100, -0.004), (-0.022, 0.0140, 0.0120, -0.002), (0.022, 0.0140, 0.0120, -0.002),
              (0.050, 0.0105, 0.0100, -0.004), (0.088, 0.0110, 0.0085, 0.010), (0.108, 0.0080, 0.0060, 0.030),
              (0.118, 0.0015, 0.0020, 0.050)], "obsidienne", 0.090, cotes=4)
    plaque(G, (0, 0, 0.088), 0.026, 0.0130, 0.050, 0.032, "obsidienne")
    for sx in (-1, 1):   # ergots sous les quillons, pointés vers la poignée
        plaque(G, (sx * 0.060, 0, 0.082), 0.0060, 0.0060, 0.004, 0.026, "obsidienne")
    G.creer()
    J = Maille("gemme")
    octaedre(J, (0, 0, 0.095), 0.021, 0.0322, 0.0266, 0.0196, "veine")
    J.creer()
    P = Maille("poignee")
    poignee(P, -0.090, 0.082, 0.0170)
    P.creer()
    M = Maille("pommeau")
    tour(M, [(-0.104, 0.0200), (-0.098, 0.0230), (-0.092, 0.0140)], "obsidienne", cotes=4, ecrase_y=0.7, bas=-0.150,
         rot=math.pi / 4, uv_tours=1.0)
    M.creer()
    return 0.088, zt


VARIANTES = {"metal": epee_metal, "or": epee_or, "rubis": epee_rubis, "verre": epee_verre, "obsidienne": epee_obsidienne}


def construire(nom):
    vider()
    for n in MATS:
        bpy.data.materials.new(n)
    z_garde, z_pointe = VARIANTES[nom]()
    vide("prise", Z_PRISE)
    vide("garde", z_garde + 0.010)
    vide("pointe", z_pointe)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, nom + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    zmin = min(min(v.co.z for v in o.data.vertices) for o in bpy.data.objects if o.type == 'MESH')
    print("EPEE %-10s tris=%4d longueur=%.3f m pointe=%.3f pommeau=%.3f -> %s" % (nom, tris, z_pointe - zmin, z_pointe, zmin, glb))
    return tris


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
choix = [a for a in args if a in VARIANTES] or list(VARIANTES)
for n in choix:
    construire(n)
if len(choix) == len(VARIANTES):
    # .blend de travail : les cinq épées côte à côte (régénéré, source = ce script)
    vider()
    for n in MATS:
        bpy.data.materials.new(n)
    for k, n in enumerate(VARIANTES):
        avant = set(bpy.data.objects)
        VARIANTES[n]()
        for o in set(bpy.data.objects) - avant:
            o.name = n + "_" + o.name.split(".")[0]
            o.location.x += k * 0.3
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ICI, "epees_longues.blend"), compress=True)
