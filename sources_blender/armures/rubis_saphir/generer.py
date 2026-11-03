# Ensembles HD RUBIS et SAPHIR (charte conception_rpg/CHARTE_ARMURES_HD.md, branche armures_hd/rubis_saphir).
#   blender.exe -b --python sources_blender/armures/rubis_saphir/generer.py -- [ids... | rubis | saphir | chausses] [--apercu DOSSIER]
#               [--pas-sol] [--rapide]
# Sans id : les 8 pièces + les chausses des deux familles.
#
# Géométrie : constructeurs ajustés des armures lourdes (../lourdes/pieces.py : tubes mesurés sur le corps du héros, plaques qui se
# chevauchent avec lèvre d'épaisseur, épaulières à lames, peau d'os transférée) avec plus de segments, + ajouts propres à ces
# ensembles : gemmes taillées SERTIES (chaton à griffes et rayons, table, couronne à facettes), crête de flammes (heaume de rubis),
# couronne de crocs de givre (heaume de saphir), mantelet de fourrure à deux rangs de mèches (saphir).
# Textures : UV automatiques puis CUISSON texel par texel depuis la position 3D de repos (armures_lib.cuire, numpy) : 1024² pour la
# cuirasse, 512² pour les autres pièces ; liserés dorés / argentés au bord des plaques, rivets, flammes gravées à émail rouge (rubis),
# runes de glace et flocons gravés, givre dans les creux (saphir), mailles, cuir, fourrure en mèches. Bruit seulement (jamais de
# tramage). Gemmes : texture propre (cristal à facettes, palettes des armes Cœur-de-Braise / Croc-de-Givre : RUBIS_PROFOND,
# SAPHIR_PROFOND) pour la profondeur du shader « matière ».
# Variante ENCHANTÉE : même maillage, matériaux suffixés « .enchante » et texture aux runes / émaux plus clairs (lueur du preset) :
#   porte/<id>_enchante.glb, sol/<id>_enchante.glb.
import bpy, bmesh, sys, os, math
import numpy as np
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "lourdes"))
sys.path.insert(0, os.path.join(ICI, ".."))
import importlib
import commun as C
import pieces as PC
import armures_lib as L
importlib.reload(C); importlib.reload(PC); importlib.reload(L)
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

TAU = math.tau
CHAUSSES = os.path.join(C.DEPOT, "assets", "modeles", "armures", "chausses")
TEX = os.path.join(C.DEPOT, "sources_blender", "armures", "textures")

# ------------------------------------------------------------------------------------------------ palettes (numpy : listes de rgb)
ACIER_RUBIS = L.hexa("#050403", "#0a0706", "#110c0a", "#181110", "#201513", "#2a1c18", "#35241e", "#432e26", "#553a30", "#6b4a3d",
                     "#86604f", "#a88070", "#cdb0a2")
TREMPE_RUBIS = L.hexa("#0a0507", "#170a10", "#241019", "#331722", "#43202c", "#552b36", "#6a3842", "#83494f")   # reflets de trempe
OR_SOMBRE = L.hexa("#120c05", "#21160a", "#332210", "#4a3317", "#62461f", "#7c5b29", "#977236", "#b28b47", "#cba560", "#e2c587", "#f2e0b0")
BRONZE_SOMBRE = L.hexa("#0e0806", "#1c110c", "#2c1b13", "#3e271b", "#523425", "#684330", "#80553e", "#9a6a50", "#b88a6c")
CUIR_RUBIS = L.hexa("#0b0505", "#140909", "#1e0d0c", "#291210", "#351815", "#421e19", "#50261f")
ACIER_SAPHIR = L.hexa("#050609", "#0a0c11", "#101319", "#171b24", "#1f2530", "#292f3d", "#353d4d", "#444e61", "#586478", "#6f7d93",
                      "#8d9bb0", "#b4c2d4", "#dde8f4")
ARGENT = L.hexa("#2a3038", "#3f4752", "#56606d", "#6f7a88", "#8a96a4", "#a7b2bf", "#c5cfd9", "#e3eaf1", "#f6fafd")
CUIR_SAPHIR = L.hexa("#08090c", "#0f1116", "#171a21", "#20242d", "#2a2f3a", "#353b48", "#424a59")
FOURRURE_NEIGE = L.hexa("#4c5058", "#62666e", "#7a7e86", "#92969d", "#aaaeb4", "#c0c3c8", "#d3d5d9", "#e3e4e7", "#f0f1f2")
GIVRE = np.array([0.80, 0.88, 0.96])
RUBIS_PROFOND = L.hexa("#090003", "#140108", "#21020d", "#320413", "#46071a", "#5d0b22", "#78122b", "#962036", "#ba3a4c", "#e88a8c")
SAPHIR_PROFOND = L.hexa("#010309", "#030716", "#050e26", "#091838", "#0f244f", "#163469", "#204886", "#3062a6", "#5288c8", "#a2c4ec")
# palettes 128² des constructeurs (texture provisoire, remplacée par la cuisson HD)
P_RUB = ["#070505", "#180d0c", "#2e1714", "#4a241f", "#6e3730", "#a05e55", "#e0bcb4"]
P_SAP = ["#080a0e", "#171d26", "#2c3644", "#485567", "#6d7c91", "#9fb0c4", "#e4eef8"]

ENSEMBLES = {
    "rubis": dict(acier="acier_rubis", maille="acier_rubis.maille", serti="serti_rubis", gemme="rubis", cristal="cristal_rubis"),
    "saphir": dict(acier="acier_saphir", maille="acier_saphir.maille", serti="serti_saphir", gemme="saphir", cristal="cristal_saphir"),
}

# ------------------------------------------------------------------------------------------------ outils géométriques
GEMMES = []        # (centre, normale, rayon) des gemmes posées sur la pièce en cours (réorientation des faces)


def surface(P, origine, direction, portee=1.0):
    """Point et normale de la pièce en cours de construction touchés par un rayon (None si rien)."""
    arbre = BVHTree.FromPolygons([Vector(v) for v in P.v], [f[0] for f in P.f], epsilon=0.0)
    hit = arbre.ray_cast(Vector(origine), Vector(direction).normalized(), portee)
    if hit[0] is None:
        return None, None
    n = hit[1]
    if n.dot(Vector(direction)) > 0:
        n = -n
    return hit[0], n.normalized()


def _anneau(c, t1, t2, n, rayon, h, k, dec=0.0):
    return [c + (t1 * math.cos(TAU * (i + dec) / k) + t2 * math.sin(TAU * (i + dec) / k)) * rayon + n * h for i in range(k)]


def gemme(P, c, n, haut, rayon, mat_gemme, mat_serti, k=10, rayons=0, griffes=4, rayons_long=1.9):
    """Gemme taillée sertie sur la surface (c, n) : chaton (bâte) d'épaisseur, griffes, rayons décoratifs (flammes / givre) autour,
    pierre à rondiste, couronne à facettes décalées et table. ~90-160 triangles."""
    t1 = (haut - n * haut.dot(n)).normalized()
    t2 = n.cross(t1).normalized()
    hb = rayon * 0.42
    B0 = _anneau(c, t1, t2, n, rayon * 1.18, -0.003, k)
    B1 = _anneau(c, t1, t2, n, rayon * 1.18, hb, k)
    B2 = _anneau(c, t1, t2, n, rayon * 0.98, hb + 0.0015, k)
    B3 = _anneau(c, t1, t2, n, rayon * 0.9, hb * 0.6, k)
    P.grille([B0, B1, B2, B3], mat_serti, (0.0, 0.0, 0.1, 0.1))
    G0 = _anneau(c, t1, t2, n, rayon * 0.92, hb * 0.75, k)
    G1 = _anneau(c, t1, t2, n, rayon * 0.88, hb * 1.25, k)
    G2 = _anneau(c, t1, t2, n, rayon * 0.62, hb + rayon * 0.5, k, 0.5)
    G3 = _anneau(c, t1, t2, n, rayon * 0.40, hb + rayon * 0.66, k)
    ids = P.grille([G0, G1, G2, G3], mat_gemme, (0.0, 0.0, 1.0, 1.0))
    ct = P.sommet(c + n * (hb + rayon * 0.68))
    for i in range(k):
        P.face([ids[-1][i], ids[-1][(i + 1) % k], ct], mat_gemme, [(0.5, 0.5)] * 3)
    # griffes : petites pointes qui montent du chaton sur le rondiste
    for gi in range(griffes):
        a = TAU * (gi + 0.5) / griffes
        d = t1 * math.cos(a) + t2 * math.sin(a)
        e = t1 * math.cos(a + 0.5 * TAU / 2 / k * 2) + t2 * math.sin(a + 0.5 * TAU / 2 / k * 2)
        e2 = t1 * math.cos(a - 0.5 * TAU / 2 / k * 2) + t2 * math.sin(a - 0.5 * TAU / 2 / k * 2)
        b1 = c + e * rayon * 1.12 + n * hb
        b2 = c + e2 * rayon * 1.12 + n * hb
        tip = c + d * rayon * 0.78 + n * (hb + rayon * 0.42)
        dos = c + d * rayon * 1.2 + n * (hb * 0.4)
        ia, ib, it, idos = P.sommet(b1), P.sommet(b2), P.sommet(tip), P.sommet(dos)
        P.face([ia, ib, it], mat_serti, [(0.0, 0.0)] * 3)
        P.face([ib, idos, it], mat_serti, [(0.0, 0.0)] * 3)
        P.face([idos, ia, it], mat_serti, [(0.0, 0.0)] * 3)
    # rayons : arêtes en relief qui partent du chaton (soleil de flammes / étoile de givre)
    for ri in range(rayons):
        a = TAU * ri / rayons
        d = t1 * math.cos(a) + t2 * math.sin(a)
        w = t1 * math.cos(a + math.pi / 2) + t2 * math.sin(a + math.pi / 2)
        lg = rayons_long if ri % 2 == 0 else rayons_long * 0.72
        p0 = c + d * rayon * 1.15
        pa = p0 + w * rayon * 0.22 - n * 0.002
        pb = p0 - w * rayon * 0.22 - n * 0.002
        pm = c + d * rayon * (1.15 + (lg - 1.15) * 0.45) + n * rayon * 0.16
        pt = c + d * rayon * lg - n * 0.002
        ia, ib, im, iT = P.sommet(pa), P.sommet(pb), P.sommet(pm), P.sommet(pt)
        P.face([ia, im, iT], mat_serti, [(0.0, 0.0)] * 3)
        P.face([im, ib, iT], mat_serti, [(0.0, 0.0)] * 3)
        P.face([ib, im, ia], mat_serti, [(0.0, 0.0)] * 3)
    GEMMES.append((c.copy(), n.copy(), rayon))


def poser_gemme(P, origine, direction, haut, rayon, ens, decal=0.0, **kw):
    p, n = surface(P, origine, direction)
    if p is None:
        print("GEMME : surface non trouvée", origine)
        return
    gemme(P, p + n * decal, n, haut, rayon, ENSEMBLES[ens]["gemme"], ENSEMBLES[ens]["serti"], **kw)


def reorienter_gemmes(ob, mats):
    """Faces des gemmes / chatons tournées vers le dehors de LEUR gemme (orienter_dehors du constructeur les juge par rapport au
    corps, faux pour les facettes de côté)."""
    if not GEMMES:
        return
    idx = {i for i, m in enumerate(ob.data.materials) if m and m.name.split(".")[0] in mats}
    bm = bmesh.new(); bm.from_mesh(ob.data)
    flip = []
    for f in bm.faces:
        if f.material_index not in idx:
            continue
        c = f.calc_center_median()
        g = min(GEMMES, key=lambda x: (x[0] - c).length)
        if (g[0] - c).length > g[2] * 2.6:
            continue
        ref = g[0] - g[1] * g[2] * 1.2
        if f.normal.dot(c - ref) < 0:
            flip.append(f)
    bmesh.ops.reverse_faces(bm, faces=flip)
    bm.to_mesh(ob.data); bm.free()
    ob.data.update()


# ------------------------------------------------------------------------------------------------ décors
# Langage de forme (planche de référence conception_rpg/references/planche_armures_5.png, colonne RUBY) : plaques de CRISTAL
# facettées (faces plates) sur une STRUCTURE de métal sombre ; pointes cristallines aux épaules, coudes, genoux et au heaume,
# MESURÉES (5 à 10 cm) et qui SORTENT de l'armure : chaque pointe part d'un chaton de métal enfoncé dans la plaque ; gemme-noyau
# en losange au centre du torse. Saphir : même langage, plus sobre et défensif (pointes rares et courtes, plaques plus larges).
def pointe(P, c, n, axe, longueur, rayon, ens, k=6, serti=True, graine=0):
    """Pointe de cristal sertie : collerette de métal (chaton) enfoncée dans la surface (c, n), prisme facetté irrégulier qui sort de
    la collerette, sommet effilé légèrement décentré. axe : direction de la pointe."""
    mc, ms = ENSEMBLES[ens]["cristal"], ENSEMBLES[ens]["serti"]
    axe = Vector(axe).normalized()
    t1 = (n - axe * n.dot(axe)) if abs(n.dot(axe)) < 0.95 else Vector((1, 0, 0)) - axe * axe.x
    t1.normalize()
    t2 = axe.cross(t1).normalized()
    base = c - axe * 0.012
    if serti:
        C0 = _anneau(c - n * 0.004, t1, t2, axe, rayon * 1.55, 0.0, k)
        C1 = _anneau(c, t1, t2, axe, rayon * 1.5, rayon * 0.35, k)
        C2 = _anneau(c, t1, t2, axe, rayon * 1.12, rayon * 0.55, k)
        C3 = _anneau(c, t1, t2, axe, rayon * 1.0, rayon * 0.2, k)
        P.grille([C0, C1, C2, C3], ms, (0.0, 0.0, 0.1, 0.1))
    jit = [1.0 + 0.18 * (C._h(i, graine, 7) - 0.5) for i in range(k)]
    A0 = [base + (t1 * math.cos(TAU * i / k) + t2 * math.sin(TAU * i / k)) * rayon * jit[i] for i in range(k)]
    A1 = [c + axe * longueur * 0.42 + (t1 * math.cos(TAU * (i + 0.15) / k) + t2 * math.sin(TAU * (i + 0.15) / k)) * rayon * 0.82 * jit[i]
          for i in range(k)]
    ids = P.grille([A0, A1], mc, (0.0, 0.0, 1.0, 1.0))
    tip = P.sommet(c + axe * longueur + t1 * rayon * 0.12)
    for i in range(k):
        P.face([ids[-1][i], ids[-1][(i + 1) % k], tip], mc, [(0.5, 0.5)] * 3)
    GEMMES.append((c.copy(), axe.copy(), rayon))


def poser_pointe(P, origine, direction, axe, longueur, rayon, ens, **kw):
    p, n = surface(P, origine, direction)
    if p is None:
        print("POINTE : surface non trouvée", origine)
        return
    pointe(P, p, n, axe, longueur, rayon, ens, **kw)


def noyau(P, c, n, haut, h, l, saillie, ens):
    """Gemme-noyau en losange (double pyramide allongée, 8 facettes) dans un cadre de métal à quatre branches."""
    mg, ms = ENSEMBLES[ens]["gemme"], ENSEMBLES[ens]["serti"]
    t1 = (haut - n * haut.dot(n)).normalized()
    t2 = n.cross(t1).normalized()
    los = [t1 * h, t2 * l, -t1 * h * 0.8, -t2 * l]
    # cadre : losange extérieur, épaisseur, losange intérieur
    ext = [c + d * 1.32 - n * 0.003 for d in los]
    ext_h = [c + d * 1.32 + n * saillie * 0.35 for d in los]
    inn_h = [c + d * 1.08 + n * saillie * 0.45 for d in los]
    inn = [c + d * 1.02 + n * saillie * 0.1 for d in los]
    P.grille([ext, ext_h, inn_h, inn], ms, (0.0, 0.0, 0.1, 0.1))
    # branches du cadre (haut, bas, côtés) : arêtes en relief
    for i, d in enumerate(los):
        w = los[(i + 1) % 4].normalized() * 0.006
        p0 = c + d * 1.3
        pt = c + d * (1.75 if i % 2 == 0 else 1.55)
        pm = c + d * 1.5 + n * saillie * 0.25
        ia, ib, im, it = P.sommet(p0 + w), P.sommet(p0 - w), P.sommet(pm), P.sommet(pt - n * 0.002)
        P.face([ia, im, it], ms, [(0, 0)] * 3); P.face([im, ib, it], ms, [(0, 0)] * 3); P.face([ib, im, ia], ms, [(0, 0)] * 3)
    # pierre : rondiste (losange), couronne (8 facettes) et table
    G0 = [c + d * 1.0 + n * saillie * 0.15 for d in los]
    G1 = []
    for i in range(4):
        a, b = los[i], los[(i + 1) % 4]
        G1 += [c + a * 0.62 + n * saillie * 0.75, c + (a + b) * 0.38 + n * saillie * 0.7]
    G0b = []
    for i in range(4):
        a, b = los[i], los[(i + 1) % 4]
        G0b += [c + a * 1.0 + n * saillie * 0.15, c + (a + b) * 0.5 + n * saillie * 0.15]
    ids = P.grille([G0b, G1], mg, (0.0, 0.0, 1.0, 1.0))
    top = P.sommet(c + n * saillie)
    for i in range(8):
        P.face([ids[-1][i], ids[-1][(i + 1) % 8], top], mg, [(0.5, 0.5)] * 3)
    GEMMES.append((c.copy(), n.copy(), max(h, l)))


def deco_casque(ens):
    """Heaume : visière en T (bandeau de front + nasal de métal sombre), gemme au front, CRÊTE de cristal haute (trois éclats alignés
    sur le cimier, penchés vers l'arrière) et éclats de tempes. Même forme pour le saphir (v2)."""
    def dec(P, t, r, centre, Pts, R_NAS, R_CORNE):
        z = Pts[0][0].z + 0.042
        poser_gemme(P, (0, -0.5, z), (0, 1, 0), Vector((0, 0, 1)), 0.0105, ens, rayons=0, k=8)
        poser_pointe(P, centre + Vector((0, -0.03, 0.5)), (0, 0, -1), (0, 0.12, 1), 0.26, 0.030, ens, k=6, graine=1)
        poser_pointe(P, centre + Vector((0, 0.045, 0.5)), (0, 0, -1), (0, 0.55, 1), 0.19, 0.024, ens, k=5, graine=2)
        poser_pointe(P, centre + Vector((0, 0.11, 0.45)), (0, 0, -1), (0, 0.85, 0.7), 0.13, 0.018, ens, k=4, serti=False, graine=5)
        for s in (1.0, -1.0):
            poser_pointe(P, centre + Vector((0.5 * s, -0.01, 0.07)), (-s, 0, 0), (0.85 * s, 0.1, 0.55), 0.13, 0.019, ens, k=5, graine=3)
            poser_pointe(P, centre + Vector((0.45 * s, 0.07, 0.2)), (-s, 0, 0), (0.55 * s, 0.4, 0.8), 0.10, 0.015, ens, k=4, serti=False, graine=6)
    return dec


def deco_masque(ens, z_bas=1.60):
    """Mentonnière / masque de cristal (heaume fermé de la planche) : plaque facettée devant la bouche et les joues, sous la fente
    des yeux (entre le rebord du heaume et le haut du masque), ajustée sur le visage et la barbe, arête médiane en relief."""
    mc = ENSEMBLES[ens]["cristal"]
    def dec(P, t, r, centre, Pts, R_NAS, R_CORNE):
        arbre = C.bvh(r, ["peau", "Hair_Beard"], {"Head"}, 0.5)
        z_haut = Pts[0][0].z - 0.026
        zs = [z_haut, (z_haut + z_bas) / 2 + 0.008, z_bas]
        los = [-78, -52, -26, 0, 26, 52, 78]
        grid = []
        for k, z in enumerate(zs):
            row = []
            for lo_d in los:
                lo = math.radians(lo_d)
                d = Vector((math.sin(lo), -math.cos(lo), 0))
                c = Vector((0, 0.004, z))
                hit = arbre.ray_cast(c + d * 0.4, -d, 0.4)
                rr = (0.4 - hit[3]) if hit[0] is not None else 0.09
                arete = 0.012 if lo_d == 0 else (0.004 if abs(lo_d) == 26 else 0.0)
                row.append(c + d * (rr + 0.017 + arete + 0.004 * k))
            grid.append(row)
        # enveloppe : chaque colonne au moins aussi en avant que celle du dessus (pas de creux sous le nez)
        for k in range(1, len(grid)):
            for i in range(len(los)):
                a, b = grid[k - 1][i], grid[k][i]
                ra, rb = Vector((a.x, a.y, 0)).length, Vector((b.x, b.y, 0)).length
                if rb < ra:
                    grid[k][i] = Vector((b.x * ra / rb, b.y * ra / rb, b.z))
        P.grille(grid, mc, (0.0, 0.0, 1.0, 1.0), fermer=False, inverser=True)
        # tranches haute (bord de la fente) et basse : épaisseur vers le visage
        for row, inv in ((grid[0], False), (grid[-1], True)):
            dedans = [p + (Vector((0, 0.004, p.z)) - p).normalized() * 0.009 for p in row]
            P.grille([row, dedans], mc, (0.0, 0.0, 1.0, 0.1), fermer=False, inverser=inv)
    return dec



def deco_bandeau(mat):
    """Bandeau de front rapporté : bande de métal en relief (épaisseur, bords biseautés) autour du heaume, au-dessus du rebord."""
    def dec(P, t, r, centre, Pts, R_NAS, R_CORNE):
        ring = Pts[1]
        def off(p, k, dz=0.0):
            d = (p - centre); d.z = 0; d.normalize()
            return p + d * k + Vector((0, 0, dz))
        r0 = [off(p, 0.0005, -0.008) for p in ring]
        r1 = [off(p, 0.005, -0.006) for p in ring]
        r2 = [off(p, 0.005, 0.012) for p in ring]
        r3 = [off(p, 0.0005, 0.014) for p in ring]
        P.grille([r0, r1, r2, r3], mat, (0.0, 0.0, 1.0, 0.1))
    return dec


def deco_torse(ens):
    def dec(P, t, r, st):
        p, n = surface(P, (0, -0.6, st.get("z_coeur", 1.31)), (0, 1, 0))
        if p is not None:
            noyau(P, p + n * 0.002, n, Vector((0, 0, 1)), 0.082, 0.05, 0.04, ens)
        for s in (1.0, -1.0):
            # gerbe d'épaule : 5 éclats en éventail, vers le haut et le dehors (le plus grand ~0,3 m)
            gerbe = [((0.215, 0.0), (0.50, 0.04, 0.86), 0.30, 0.034), ((0.29, -0.025), (0.88, -0.15, 0.45), 0.22, 0.026),
                     ((0.255, 0.065), (0.38, 0.62, 0.69), 0.20, 0.024), ((0.17, 0.03), (0.15, 0.1, 1.0), 0.19, 0.022),
                     ((0.32, 0.03), (1.0, 0.1, 0.18), 0.15, 0.020)]
            for k, ((x, y), ax, lg, ry) in enumerate(gerbe):
                poser_pointe(P, (x * s, y, 1.9), (0, 0, -1), (ax[0] * s, ax[1], ax[2]), lg, ry, ens, k=6 if k < 1 else 4, serti=k < 1, graine=10 + k)
            # petite gemme sertie sur le dessus de l'épaule (devant la gerbe)
            poser_gemme(P, (0.24 * s, -0.075, 1.9), (0, 0, -1), Vector((s, 0, 0)), 0.013, ens, k=8, rayons=0, griffes=4)
            # coude : deux éclats vers l'arrière et le dehors, sertis au bout de la manche
            la = r.os["lowerarm_" + ("l" if s > 0 else "r")]
            poser_pointe(P, ((X_MANCHE - 0.035) * s, 0.5, la.z + 0.005), (0, -1, 0), (0.35 * s, 1.0, 0.1), 0.15, 0.021, ens, k=5, graine=13)
            poser_pointe(P, ((X_MANCHE - 0.06) * s, 0.5, la.z + 0.03), (0, -1, 0), (0.1 * s, 0.8, 0.6), 0.10, 0.015, ens, k=4, serti=False, graine=15)
        tassettes(P, r, st, ens)
    return dec


def tassettes(P, r, st, ens):
    """Tassettes : plaques de cristal en écu pointu qui pendent de la ceinture sur la jupe de mailles (facettées par une arête
    médiane en relief), avec une tranche d'épaisseur. Rubis : 7 étroites et pointues ; saphir : 5 larges, pointe émoussée."""
    mc = ENSEMBLES[ens]["cristal"]
    rub = True     # v2 : le saphir reprend les mêmes formes que le rubis
    angles = [0, 34, -34, 68, -68, 100, -100, 140, -140, 180]
    demi = math.radians(15)
    zt = st.get("z_ceinture", 1.0) - 0.02
    for a_deg in angles:
        a0 = math.radians(a_deg)
        cote = abs(a_deg) > 70 and abs(a_deg) < 120
        z_tip = 0.60 + (0.06 if cote else 0.0)
        z_sb = z_tip + 0.16
        zm = (zt + z_sb) / 2 + 0.02
        def pt(a, z, haut=0.0):
            d = Vector((math.sin(a), -math.cos(a), 0))
            p, n = surface(P, Vector((0, 0, z)) + d * 0.6, -d)
            if p is None:
                return Vector((0, 0, z)) + d * 0.2
            return p + d * (0.013 + haut)
        rows = [[pt(a0 - demi, zt), pt(a0, zt, 0.004), pt(a0 + demi, zt)],
                [pt(a0 - demi * 1.05, zm), pt(a0, zm, 0.008), pt(a0 + demi * 1.05, zm)],
                [pt(a0 - demi * 0.8, z_sb), pt(a0, z_tip, 0.006 if rub else 0.003), pt(a0 + demi * 0.8, z_sb)]]
        F = [[P.sommet(p) for p in row] for row in rows]
        uv = [(0, 0), (0.1, 0), (0.1, 0.1), (0, 0.1)]
        for j in range(2):
            for i in range(2):
                P.face([F[j][i], F[j + 1][i], F[j + 1][i + 1], F[j][i + 1]], mc, uv)
        # tranche (épaisseur 7 mm vers le corps)
        tour = [rows[0][0], rows[1][0], rows[2][0], rows[2][1], rows[2][2], rows[1][2], rows[0][2]]
        dedans = []
        for p in tour:
            d = Vector((p.x, p.y, 0)).normalized()
            dedans.append(p - d * 0.007)
        for i in range(len(tour) - 1):
            q = [P.sommet(tour[i]), P.sommet(dedans[i]), P.sommet(dedans[i + 1]), P.sommet(tour[i + 1])]
            P.face(q, mc, uv)
        GEMMES.append((rows[1][1], Vector((math.sin(a0), -math.cos(a0), 0)), 0.09))
        if abs(a_deg) in (68, 100):    # éclat de hanche : vers le dehors et un peu vers le bas
            d0 = Vector((math.sin(a0), -math.cos(a0), 0))
            poser_pointe(P, Vector((0, 0, zt - 0.03)) + d0 * 0.6, -d0, d0 * 1.0 + Vector((0, 0, 0.25)), 0.15, 0.022, ens, k=4, serti=False, graine=40 + a_deg)


# ------------------------------------------------------------------------------------------------ styles
def _s(b0, **kw):
    d = dict(b0); d.update(kw); return d

# plaques (lames, épaulières, coque du heaume, manchettes, grèves, genouillères) = CRISTAL ; structure, mailles, mains, solerets,
# rebords, nasal et joues = métal sombre.
RUBIS = dict(pal=P_RUB, mat="cristal_rubis", mat_maille="acier_rubis.maille", mat_rebord="acier_rubis", mat_main="acier_rubis",
             mat_doigts="acier_rubis", mat_genou="cristal_rubis", mat_botte="acier_rubis", base=0.4, oxyde=0.0, crasse=0.3, poli=0.6,
             graine=211, pal_maille=P_RUB, pal_cuir=["#0b0505", "#1e0d0c", "#351815", "#50261f"], bord_roule=True, z_ourlet=0.64)
SAPHIR = dict(pal=P_SAP, mat="cristal_saphir", mat_maille="acier_saphir.maille", mat_rebord="acier_saphir", mat_main="acier_saphir",
              mat_doigts="acier_saphir", mat_genou="cristal_saphir", mat_botte="acier_saphir", base=0.5, oxyde=0.0, crasse=0.2, poli=0.7,
              graine=307, pal_maille=P_SAP, pal_cuir=["#08090c", "#171a21", "#2a2f3a", "#424a59"], bord_roule=True, z_ourlet=0.66)

# Bout des manches de mailles (constructeur : 0,435). Au-delà de |x| = 0,41 la manche de tunique du héros suit l'AVANT-bras : un
# bout de manche plus long l'enfermait et, coude plié (Sort_Jet2M, combo), elle ressortait de 17 à 20 mm (test_armure_visible).
X_MANCHE = 0.405

PIECES = {
    "casque_rubis": ("rubis", lambda r: PC.casque(r, _s(RUBIS, id="casque_rubis", n=14, bas=(0.0, -0.3, -0.6), bandes=0, ecart=0.021,
                                                        bombe=0.05, decor=[lambda *a: PC.deco_nasal(*a, mat="acier_rubis", long=0.07, larg=0.015),
                                                                            lambda *a: PC.deco_joues(*a, mat="cristal_rubis"),
                                                                            deco_bandeau("acier_rubis"), deco_masque("rubis"), deco_casque("rubis")]))),
    "cuirasse_rubis": ("rubis", lambda r: PC.cuirasse(r, _s(RUBIS, id="cuirasse_rubis", n=24, lames=5, bombe=0.012, lames_epaule=4, z_plaques=(1.04, 1.47),
                                                            z_coeur=1.30, x_manche=X_MANCHE, decor=[deco_torse("rubis")]))),
    "gantelets_rubis": ("rubis", lambda r: PC.gantelets(r, _s(RUBIS, id="gantelets_rubis", evasement=0.034, debut_manchette=0.35,
                                                              decor=[deco_gant("rubis")]))),
    "bottes_rubis": ("rubis", lambda r: PC.bottes(r, _s(RUBIS, id="bottes_rubis", decor=[deco_genou("rubis")]))),
    "casque_saphir": ("saphir", lambda r: PC.casque(r, _s(SAPHIR, id="casque_saphir", n=16, bas=(0.05, -0.26, -0.55), bandes=0,
                                                          ecart=0.021, bombe=0.025,
                                                          decor=[lambda *a: PC.deco_nasal(*a, mat="acier_saphir", long=0.06, larg=0.016),
                                                                 lambda *a: PC.deco_joues(*a, mat="cristal_saphir"),
                                                                 deco_bandeau("acier_saphir"), deco_masque("saphir", 1.615), deco_casque("saphir")]))),
    "cuirasse_saphir": ("saphir", lambda r: PC.cuirasse(r, _s(SAPHIR, id="cuirasse_saphir", n=24, lames=5, bombe=0.012, lames_epaule=4, z_plaques=(1.04, 1.47),
                                                              z_coeur=1.30, x_manche=X_MANCHE, decor=[deco_torse("saphir")]))),
    "gantelets_saphir": ("saphir", lambda r: PC.gantelets(r, _s(SAPHIR, id="gantelets_saphir", evasement=0.03, debut_manchette=0.35,
                                                                decor=[deco_gant("saphir")]))),
    "bottes_saphir": ("saphir", lambda r: PC.bottes(r, _s(SAPHIR, id="bottes_saphir", decor=[deco_genou("saphir")]))),
}


def deco_gant(ens):
    """Manchette de cristal : gemme sur le dessus du poignet ; éclats sur l'avant-bras (dehors, dos, vers le coude)."""
    def dec(P, t, r, st):
        for cote, s in PC.COTES:
            la, ha = r.os["lowerarm_" + cote], r.os["hand_" + cote]
            p = la.lerp(ha, 0.8)
            poser_gemme(P, p + Vector((0, 0, 0.3)), (0, 0, -1), Vector((s, 0, 0)), 0.0095, ens, k=8, rayons=0, griffes=4)
            q = la.lerp(ha, 0.5)
            poser_pointe(P, q + Vector((0, 0.3, 0.05)), (0, -1, -0.15), (-0.55 * s, 0.75, 0.35), 0.13, 0.018, ens, k=5, graine=20)
            poser_pointe(P, q + Vector((0, 0.0, 0.3)), (0, 0, -1), (0.2 * s, -0.25, 1.0), 0.11, 0.016, ens, k=4, serti=False, graine=21)
            poser_pointe(P, la.lerp(ha, 0.6) + Vector((0.3 * s, 0.0, 0.0)), (-s, 0, 0), (1.0 * s, -0.2, 0.25), 0.10, 0.015, ens, k=4, serti=False, graine=22)
    return dec


def _plaques_membre(P, st, arbre, A, B, plages, arc, base, bomb, mat, rep_h=0.012):
    """Plaques facettées qui se recouvrent autour d'un membre (arc d'angles, repère de la grève du constructeur) : plages = liste de
    (t0, t1) le long de A -> B, la plaque du dessus (t plus grand) descend sur celle du dessous."""
    for k, (t0, t1) in enumerate(plages):
        def dec(j, i, a, k=k):
            return base + 0.004 * k + (0.006 if j == 0 else 0.0) + bomb * max(0.0, math.cos(a)) * math.sin(math.pi * (j + 0.5) / 2.0)
        Pg, _, _ = C.tube(arbre, A, B, [t0, t1], 0, dec, r_loin=0.4, dilate=0, lisse=1, angles=arc)
        P.grille(Pg, mat, C.rect_uv((0, 64, 64, 128)), fermer=False, inverser=True)


def deco_genou(ens):
    """Jambe v2 : cuissards (trois plaques facettées sur la cuisse), tibias couverts (trois plaques), genouillère à grand éclat,
    deux éclats sur le tibia. Même forme pour le saphir."""
    def dec(P, t, r, st, cote, s, jambe, A, B):
        if st.get("greve") is False:
            return
        ca = r.os["calf_" + cote]
        th = r.os["thigh_" + cote]
        arc_c = [math.radians(x) for x in range(-150, 151, 30)]
        # cuisse : de la hanche (th) au genou (ca), plaques du genou vers la hanche
        cuisse = C.bvh(r, ["pantalon"], {"thigh_" + cote}, 0.5)
        Ac, Bc = Vector((th.x, th.y, th.z)), Vector((ca.x, ca.y, ca.z + 0.03))
        _plaques_membre(P, st, cuisse, Ac, Bc, [(0.80, 1.0), (0.62, 0.86)], arc_c, 0.026, 0.012, st["mat"])
        # tibia : plaques larges (flancs compris) par-dessus la grève du constructeur
        arc_t = [math.radians(x) for x in range(-100, 101, 25)]
        z0 = lambda z: (z - A.z) / (B.z - A.z)
        _plaques_membre(P, st, jambe, A, B, [(z0(0.21), z0(0.31)), (z0(0.29), z0(0.40)), (z0(0.37), z0(0.48))], arc_t, 0.034, 0.008, st["mat"])
        poser_pointe(P, (ca.x, -0.5, ca.z + 0.015), (0, 1, 0), (0.15 * s, -0.8, 0.6), 0.16, 0.024, ens, k=5, graine=30 + int(s))
        poser_pointe(P, (ca.x, -0.5, ca.z - 0.12), (0, 1, 0), (0.1 * s, -0.7, 0.7), 0.10, 0.017, ens, k=4, serti=False, graine=33 + int(s))
        poser_pointe(P, (ca.x, -0.5, ca.z - 0.22), (0, 1, 0), (0.1 * s, -0.55, 0.85), 0.08, 0.014, ens, k=4, serti=False, graine=36 + int(s))
    return dec


# ------------------------------------------------------------------------------------------------ cuisson HD
def _hash1(i, g):
    n = (i.astype(np.int64) * 374761393 + g * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def coord_u(pid):
    """Coordonnée « le long des bords » (m) : arc autour de l'axe du membre + hauteur (bords horizontaux et verticaux)."""
    if "cuirasse" in pid:
        def u(P):
            x, y, z = P[:, 0], P[:, 1], P[:, 2]
            bras = (np.abs(x) > 0.2) & (y > 1.28)
            return np.where(bras, np.arctan2(z, y - 1.44) * 0.10 + np.abs(x), np.arctan2(x, z) * 0.16 + y)
    elif "casque" in pid:
        def u(P):
            return np.arctan2(P[:, 0], P[:, 2] - 0.004) * 0.11 + P[:, 1]
    elif "gant" in pid:
        def u(P):
            return np.arctan2(P[:, 2], P[:, 1] - 1.44) * 0.045 + np.abs(P[:, 0])
    else:
        def u(P):
            return np.arctan2(P[:, 0] - np.sign(P[:, 0]) * 0.11, P[:, 2] - 0.02) * 0.06 + P[:, 1]
    return u


def _rgba(rgb, al):
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(al, 0, 1)[:, None]], 1)


def peindre_rubis(P, N, bd, U, ench):
    n1 = L.fbm(P, 7.0, 3, 3)
    n2 = L.bruit(P, 95.0, 5)
    brosse = L.bruit(P * np.array([1.0, 9.0, 1.0]), 42.0, 7)
    v = 0.20 + (n1 - 0.5) * 0.22 + (n2 - 0.5) * 0.06 + (brosse - 0.5) * 0.10
    martele = L.bruit(P, 55.0, 9)
    v += (martele - 0.5) * 0.06
    al = 0.45 + 0.35 * n1
    rayure = np.abs(L.bruit(P * np.array([30.0, 3.0, 30.0]), 9.0, 11) - 0.5) < 0.004
    v = np.where(rayure, v + 0.16, v)
    al = np.where(rayure, 0.95, al)
    rgb = L.rampe(ACIER_RUBIS, np.clip(v, 0, 1))
    trempe = np.clip((L.fbm(P, 3.5, 13, 2) - 0.42) * 2.2, 0, 1)[:, None] * 0.45
    rgb = rgb * (1 - trempe) + L.rampe(TREMPE_RUBIS, np.clip(v * 1.15, 0, 1)) * trempe
    # bords : biseau poli, gorge, liseré d'or à rivets, filet gravé
    bis = bd < 0.0032
    rgb[bis] = np.minimum(1, rgb[bis] * 1.75 + 0.06); al[bis] = 1.0
    gorge = (bd >= 0.0032) & (bd < 0.0046)
    rgb[gorge] *= 0.42; al[gorge] = 0.1
    lis = (bd >= 0.0046) & (bd < 0.0098)
    vo = 0.36 + (L.fbm(P, 30.0, 17, 2)[lis] - 0.5) * 0.25 + (0.0072 - np.abs(bd[lis] - 0.0072)) * 18
    rgb[lis] = L.rampe(OR_SOMBRE, np.clip(vo, 0, 1)); al[lis] = 0.85
    per = 0.032
    fu = np.mod(U / per, 1.0) - 0.5
    riv = np.hypot(fu * per, bd - 0.0072) < 0.0021
    dome = np.clip(1.0 - np.hypot(fu * per + 0.0006, bd - 0.0078) / 0.0021, 0, 1)
    rgb[riv] = L.rampe(OR_SOMBRE, np.clip(0.35 + 0.65 * dome[riv], 0, 1)); al[riv] = 1.0
    filet = (bd >= 0.0098) & (bd < 0.0110)
    rgb[filet] *= 0.38; al[filet] = 0.15
    # flammes gravées qui montent des bords, émail rouge sombre et filet d'émail ardent au cœur (lueur de l'enchantement)
    f = bd - 0.0112
    W = 0.046
    ph = np.mod(U / W + 0.14 * (L.fbm(P, 18.0, 19, 2) - 0.5), 1.0)
    t1 = (1 - np.abs(2 * ph - 1)) ** 1.8
    t2 = (1 - np.abs(2 * np.mod(ph + 0.5, 1.0) - 1)) ** 2.4
    h = 0.036 * (0.22 + 0.78 * np.maximum(t1, 0.58 * t2))
    dedans = (f > 0) & (f < h)
    bord_f = dedans & (h - f < 0.0013)
    hors_f = (f >= h) & (f - h < 0.0010)
    rgb[hors_f] = np.minimum(1, rgb[hors_f] * 1.45 + 0.03); al[hors_f] = 0.9
    plein = dedans & ~bord_f
    emaille = np.array([0.30, 0.035, 0.03])
    rgb[plein] = rgb[plein] * 0.45 + emaille * (0.55 + 0.25 * (L.bruit(P[plein], 160.0, 23) - 0.5))[:, None]
    al[plein] = 0.55
    rgb[bord_f] *= 0.30; al[bord_f] = 0.05
    coeur = dedans & (np.abs(f - 0.52 * h) < 0.0009) & (h > 0.012)
    ardent = np.array([1.0, 0.46, 0.13]) if ench else np.array([0.66, 0.17, 0.06])
    rgb[coeur] = ardent; al[coeur] = 0.7
    return _rgba(rgb, al)


def peindre_saphir(P, N, bd, U, ench):
    n1 = L.fbm(P, 7.0, 31, 3)
    n2 = L.bruit(P, 90.0, 33)
    brosse = L.bruit(P * np.array([1.0, 9.0, 1.0]), 40.0, 35)
    v = 0.28 + (n1 - 0.5) * 0.22 + (n2 - 0.5) * 0.05 + (brosse - 0.5) * 0.10
    al = 0.55 + 0.35 * n1
    rayure = np.abs(L.bruit(P * np.array([30.0, 3.0, 30.0]), 9.0, 37) - 0.5) < 0.004
    v = np.where(rayure, v + 0.14, v)
    al = np.where(rayure, 1.0, al)
    rgb = L.rampe(ACIER_SAPHIR, np.clip(v, 0, 1))
    bis = bd < 0.003
    rgb[bis] = np.minimum(1, rgb[bis] * 1.5 + 0.08); al[bis] = 1.0
    gorge = (bd >= 0.003) & (bd < 0.0042)
    rgb[gorge] *= 0.45; al[gorge] = 0.1
    lis = (bd >= 0.0042) & (bd < 0.0082)
    va = 0.62 + (L.fbm(P, 30.0, 39, 2)[lis] - 0.5) * 0.25 + (0.0062 - np.abs(bd[lis] - 0.0062)) * 16
    rgb[lis] = L.rampe(ARGENT, np.clip(va, 0, 1)); al[lis] = 0.95
    filet = ((bd >= 0.0082) & (bd < 0.0094)) | ((bd >= 0.0178) & (bd < 0.019))
    rgb[filet] *= 0.4; al[filet] = 0.15
    # bande de runes de glace gravées entre deux filets
    W = 0.0135
    bande = (bd >= 0.0094) & (bd < 0.0178)
    cx = np.mod(U / W, 1.0)
    cy = (bd - 0.0094) / 0.0084
    gi = np.floor(U / W)
    h1, h2, h3 = _hash1(gi, 41), _hash1(gi, 43), _hash1(gi, 47)
    tr = 0.095
    trait = np.abs(cx - 0.32) < tr * 0.8
    trait |= (h1 > 0.45) & (np.abs(cy - 0.15 - (cx - 0.32) * 1.5) < tr) & (cx > 0.32) & (cx < 0.8)
    trait |= (h2 > 0.55) & (np.abs(cy - 0.52) < tr) & (cx > 0.32) & (cx < 0.78)
    trait |= (h3 > 0.5) & (np.abs(cy - 0.85 + (cx - 0.32) * 1.5) < tr) & (cx > 0.32) & (cx < 0.8)
    trait &= bande & (cy > 0.08) & (cy < 0.92)
    rune = np.array([0.55, 0.88, 1.0]) if ench else np.array([0.27, 0.43, 0.6])
    rgb[trait] = rune; al[trait] = 0.8
    # flocons gravés sur les grandes surfaces
    s = 0.062
    cell = np.floor(P / s)
    jit = np.stack([_hash1(cell[:, 0] * 7 + cell[:, 1] * 131 + cell[:, 2] * 977, 51 + k) for k in range(3)], 1) - 0.5
    c = (cell + 0.5 + jit * 0.25) * s
    d = P - c
    dn = (d * N).sum(1)
    d = d - N * dn[:, None]
    up = np.where(np.abs(N[:, 1:2]) > 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 1.0, 0]]))
    t1 = np.cross(N, up); t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-6)
    t2 = np.cross(N, t1)
    th = np.arctan2((d * t2).sum(1), (d * t1).sum(1))
    rr = np.linalg.norm(d, axis=1)
    R = 0.016
    a6 = np.mod(th + math.pi / 6, math.pi / 3) - math.pi / 6
    bras = (rr < R) & (rr * np.abs(np.sin(a6)) < 0.0009)
    # branches en V aux 3/5 de chaque bras
    xb = rr * np.cos(a6) - R * 0.58
    yb = np.abs(rr * np.sin(a6))
    branche = (xb > 0) & (xb < R * 0.3) & (np.abs(yb - xb * 1.0) < 0.0008)
    choisi = (_hash1(cell[:, 0] * 13 + cell[:, 1] * 71 + cell[:, 2] * 517, 57) > 0.5) & (np.abs(dn) < 0.008) & (bd > 0.028)
    flocon = choisi & (bras | branche | (rr < 0.0022))
    rgb[flocon] = rgb[flocon] * 0.35 + (np.array([0.62, 0.86, 1.0]) if ench else np.array([0.36, 0.5, 0.64])) * 0.65
    al[flocon] = 0.6
    # givre : croûte dans les creux des bords et en plaques, cristaux qui scintillent
    fr = np.clip((L.fbm(P, 11.0, 61, 3) - 0.56) * 3.2, 0, 1) * 0.55 + np.clip((0.006 - bd) / 0.006, 0, 1) * 0.0
    fr = fr * (1.0 - flocon.astype(float) - trait.astype(float)).clip(0, 1)
    k = fr[:, None]
    rgb = rgb * (1 - k) + GIVRE * (0.85 + 0.15 * L.bruit(P, 240.0, 63))[:, None] * k
    al = al * (1 - fr) + 0.25 * fr
    cris = (fr > 0.15) & (L.bruit(P, 520.0, 65) > 0.86)
    rgb[cris] = np.array([0.95, 0.98, 1.0]); al[cris] = 1.0
    return _rgba(rgb, al)


CRISTAL_RUBIS = L.hexa("#0a0003", "#180106", "#2c030b", "#44060f", "#5d0a16", "#780f1f", "#921728", "#ad2236", "#c93548", "#e25b6a", "#f79aa4", "#ffd6da")
CRISTAL_SAPHIR = L.hexa("#01020a", "#020615", "#040c26", "#071538", "#0b1f50", "#112c68", "#183b82", "#234e9c", "#3668b8", "#5a8ad4", "#94b8ec", "#dcecff")


def peindre_cristal(P, N, bd, ens, ench):
    """Cristal facetté : cellules de Voronoï 3D (facettes de valeurs différentes, éclats des arêtes), voiles intérieurs et
    inclusions (bruit), arête claire au bord des plaques, cœur plus sombre et plus saturé loin des bords."""
    pal = CRISTAL_RUBIS if ens == "rubis" else CRISTAL_SAPHIR
    s = 0.045
    q = P / s
    base = np.floor(q)
    d1 = np.full(len(P), 9.0); d2 = np.full(len(P), 9.0); idv = np.zeros(len(P))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                cell = base + np.array([dx, dy, dz])
                key = cell[:, 0] * 7 + cell[:, 1] * 131 + cell[:, 2] * 977
                jp = np.stack([_hash1(key, 201 + k) for k in range(3)], 1)
                d = np.linalg.norm(q - (cell + jp), axis=1)
                m = d < d1
                d2 = np.where(m, d1, np.minimum(d2, d))
                idv = np.where(m, _hash1(key, 211), idv)
                d1 = np.where(m, d, d1)
    v = (0.11 + 0.31 * idv) if ens == "rubis" else (0.06 + 0.27 * idv)                                          # grenat / cramoisi profond : une valeur franche par facette
    v = np.where(idv > 0.82, v + 0.34, v)                           # quelques facettes captent la lumière (reflet clair net)
    arete = np.clip(1.0 - (d2 - d1) / 0.05, 0, 1)
    v -= arete ** 1.5 * 0.20                                        # arêtes entre facettes plus sombres
    voile = L.fbm(P, 16.0, 221, 3)
    v += (voile - 0.5) * 0.10
    incl = L.bruit(P, 260.0, 223) > 0.93
    v = np.where(incl, v + 0.16, v)
    v = np.where(bd < 0.003, v + 0.34, v)                       # arête du bord de plaque : la lumière y accroche
    v = np.where((bd >= 0.004) & (bd < 0.0065), v - 0.12, v)
    if ench:
        v = v * 1.06 + 0.07
    al = 0.85 + 0.15 * arete
    return _rgba(L.rampe(pal, np.clip(v, 0, 1)), al)


def peindre_maille(P, N, pal, base, givre=0.0, g=0):
    y = P[:, 1]
    a = np.arctan2(P[:, 0], P[:, 2]) * 0.16
    rang = np.floor(y / 0.008)
    u = np.mod(a / 0.008 + 0.5 * np.mod(rang, 2), 1.0)
    w = np.mod(y / 0.008, 1.0)
    anneau = np.abs(np.hypot(u - 0.5, (w - 0.5) * 1.2) - 0.33) < 0.15
    v = base + (L.fbm(P, 8.0, g) - 0.5) * 0.18
    v = np.where(anneau, v + 0.16 * (1 - w), v - 0.24)
    rgb = L.rampe(pal, np.clip(v, 0, 1))
    if givre > 0:
        k = np.clip((L.fbm(P, 6.0, g + 7) - 0.48) * 3.0, 0, 1)[:, None] * givre
        rgb = rgb * (1 - k) + GIVRE * k
    al = np.where(anneau, 0.85, 0.25)
    return _rgba(rgb, al)


def peindre_cuir(P, bd, U, pal, g=0):
    v = 0.45 + (L.fbm(P, 20.0, g) - 0.5) * 0.3 + (L.bruit(P, 130.0, g + 1) - 0.5) * 0.12
    use = np.clip((L.fbm(P, 9.0, g + 3) - 0.6) * 3, 0, 1)
    v += use * 0.2
    v = np.where(bd < 0.003, v + 0.12, v)
    rgb = L.rampe(pal, np.clip(v, 0, 1))
    point = (np.abs(bd - 0.0052) < 0.0007) & (np.mod(U / 0.007, 1.0) < 0.55)
    rgb[point] = np.array([0.55, 0.48, 0.36]) * 0.8
    al = 0.12 + 0.2 * (1 - use)
    return _rgba(rgb, al)


def peindre_fourrure(P, bd, pal, g=0):
    meche = L.bruit(P * np.array([1.0, 0.14, 1.0]), 170.0, g) * 0.65 + L.bruit(P * np.array([1.0, 0.2, 1.0]), 340.0, g + 1) * 0.35
    v = 0.55 + (meche - 0.5) * 0.6 + (L.fbm(P, 10.0, g + 2) - 0.5) * 0.15
    v += np.clip((0.02 - bd) / 0.02, 0, 1) * 0.12      # pointes claires au bord des mèches
    rgb = L.rampe(pal, np.clip(v, 0, 1))
    return _rgba(rgb, 0.04 + 0.1 * meche)


def peindre_serti(P, bd, pal, ench):
    v = 0.5 + (L.fbm(P, 40.0, 71, 2) - 0.5) * 0.25 + (L.bruit(P, 300.0, 73) - 0.5) * 0.1
    v = np.where(bd < 0.0015, v + 0.2, v)
    return _rgba(L.rampe(pal, np.clip(v, 0, 1)), np.full(len(P), 0.95))


def matiere_piece(pid, ens, mats, ench, tout_cristal=False):
    U_fn = coord_u(pid)
    noms = [m.split(".")[0] if not m.endswith(".maille") else "maille" for m in mats]
    def fn(P, N, pa, bd):
        out = np.zeros((len(P), 4))
        U = U_fn(P)
        if tout_cristal:
            return peindre_cristal(P, N, bd, ens, ench)
        for i, m in enumerate(mats):
            sel = pa == i
            if not sel.any():
                continue
            Ps, Ns, bs, Us = P[sel], N[sel], bd[sel], U[sel]
            if m.endswith(".maille"):
                out[sel] = peindre_maille(Ps, Ns, ACIER_RUBIS if ens == "rubis" else ACIER_SAPHIR, 0.30 if ens == "rubis" else 0.40,
                                          0.0 if ens == "rubis" else 0.2, 81)
            elif m.startswith("cristal_"):
                out[sel] = peindre_cristal(Ps, Ns, bs, ens, ench)
            elif m.startswith("acier_"):
                out[sel] = (peindre_rubis if ens == "rubis" else peindre_saphir)(Ps, Ns, bs, Us, ench)
            elif m == "cuir":
                out[sel] = peindre_cuir(Ps, bs, Us, CUIR_RUBIS if ens == "rubis" else CUIR_SAPHIR, 91)
            elif m == "fourrure":
                out[sel] = peindre_fourrure(Ps, bs, FOURRURE_NEIGE, 101)
            elif m.startswith("serti_"):
                out[sel] = peindre_serti(Ps, bs, BRONZE_SOMBRE if ens == "rubis" else ARGENT, ench)
            else:   # gemme (texture propre ; ici seulement pour remplir l'atlas)
                out[sel] = _rgba(np.tile([0.3, 0.05, 0.05] if ens == "rubis" else [0.05, 0.1, 0.3], (sel.sum(), 1)), np.ones(sel.sum()))
        return out
    return fn


def image_gemme(ens, ench, taille=256):
    """Cristal à facettes (Voronoï) : facettes de valeurs différentes, arêtes claires, voile intérieur, cœur lumineux."""
    pal = RUBIS_PROFOND if ens == "rubis" else SAPHIR_PROFOND
    rng = np.random.default_rng(41 if ens == "rubis" else 63)
    pts = rng.random((48, 2))
    vals = rng.random(48)
    ys, xs = np.mgrid[0:taille, 0:taille] / taille
    best = np.full(xs.shape, 9.0); second = np.full(xs.shape, 9.0); idx = np.zeros(xs.shape, dtype=int)
    for k, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.hypot(xs - px - ox, ys - py - oy)
                m = d < best
                second = np.where(m, best, np.minimum(second, d))
                idx = np.where(m, k, idx)
                best = np.where(m, d, best)
    v = 0.34 + 0.42 * vals[idx]
    arete = np.clip(1 - (second - best) / 0.012, 0, 1)
    v += arete * 0.32
    P3 = np.stack([xs.ravel(), ys.ravel(), np.zeros(xs.size)], 1)
    v = v + (L.fbm(P3, 6.0, 5, 3).reshape(xs.shape) - 0.5) * 0.18
    if ench:
        v = v * 1.08 + 0.1
    rgb = L.rampe(pal, np.clip(v.ravel(), 0, 1))
    al = np.full(xs.size, 1.0)
    return np.concatenate([rgb, al[:, None]], 1).reshape(taille, taille, 4)


def image_depuis(nom, arr):
    H, W = arr.shape[:2]
    img = bpy.data.images.new(nom, W, H, alpha=True)
    img.pixels = arr.reshape(-1).tolist()
    os.makedirs(TEX, exist_ok=True)
    img.filepath_raw = os.path.join(TEX, nom + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def materiau(nom, img):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Closest"
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    try:
        nt.links.new(tx.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
        m.alpha_threshold = 0.0
    except Exception:
        pass
    return m


def cuire_hd(ob, pid, ens, taille, rapide=False):
    """UV automatiques + cuisson 3D -> matériaux de la pièce (atlas commun) et de la gemme (texture propre). Retourne
    {False: [matériaux normaux], True: [matériaux enchantés]} dans l'ordre des emplacements de matériau."""
    mats = [m.name for m in ob.data.materials]
    for m in ob.data.materials:
        m.name = m.name + "_provisoire"
    me = ob.data
    att = me.attributes.get("partie") or me.attributes.new("partie", "INT", "FACE")
    for p in me.polygons:
        att.data[p.index].value = p.material_index
    for uv in list(me.uv_layers):
        me.uv_layers.remove(uv)
    me.uv_layers.new(name="UVMap")
    L.uv_auto(ob, 0.003 if taille >= 1024 else 0.005, 66)
    res = {}
    if rapide:
        taille = 256
    for ench in (False, True):
        arr = L.cuire(ob, matiere_piece(pid, ens, mats, ench), taille, None, tableau=True)
        suf = "_enchante" if ench else ""
        img = image_depuis(pid + suf, arr)
        gem = image_depuis("gemme_%s%s" % (ens, suf), image_gemme(ens, ench))
        cri = None
        if any(n.startswith("cristal_") for n in mats):
            ac = L.cuire(ob, matiere_piece(pid, ens, mats, ench, tout_cristal=True), taille, None, tableau=True)
            vide = ac[:, :, :3].sum(2) <= 0.0
            fond = image_gemme(ens, ench, ac.shape[0])
            ac[vide] = fond[vide]
            cri = image_depuis(pid + "_cristal" + suf, ac)
        liste = []
        for nom in mats:
            base = nom.split(".")[0]
            nom_m = nom + (".enchante" if ench else "")
            liste.append(materiau(nom_m, gem if base in ("rubis", "saphir") else cri if base.startswith("cristal_") else img))
        res[ench] = liste
    return res


def poser_materiaux(ob, liste):
    for i, m in enumerate(liste):
        ob.data.materials[i] = m


# ------------------------------------------------------------------------------------------------ pose au sol (d'après ../lourdes/generer.py)
def version_sol(ob, pid, nom_fichier):
    c = ob.copy(); c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.parent = None
    c.modifiers.clear()
    c.vertex_groups.clear()
    c.matrix_world = Matrix.Identity(4)
    me = c.data
    if "cuirasse" in pid:
        for v in me.vertices:
            p = v.co
            if abs(p.x) > 0.2 and p.z > 1.3:
                s = 1 if p.x > 0 else -1
                o = Vector((0.2 * s, p.y, 1.45))
                d = p - o
                a = math.radians(70) * s
                v.co = o + Vector((d.x * math.cos(a) + d.z * math.sin(a), d.y, -d.x * math.sin(a) + d.z * math.cos(a)))
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    elif "casque" in pid:
        bm = bmesh.new(); bm.from_mesh(me)
        col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        faces = list(bm.faces)
        ret = bmesh.ops.duplicate(bm, geom=faces)
        nf = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        for v in nv:
            v.co = v.co - v.normal * 0.006
        bmesh.ops.reverse_faces(bm, faces=nf)
        for f in nf:
            for lp in f.loops:
                lp[col] = (0.22, 0.2, 0.18, 1.0)
        bm.to_mesh(me); bm.free()
        me.transform(Matrix.Rotation(math.radians(-80), 4, "Y") @ Matrix.Rotation(math.radians(12), 4, "X"))
    elif "gant" in pid:
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.52
    elif "botte" in pid:
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.05
    zmin = min(v.co.z for v in me.vertices)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    me.transform(Matrix.Translation((-cx, -cy, -zmin)))
    chemin = os.path.join(C.SOL, nom_fichier + ".glb")
    os.makedirs(C.SOL, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.context.view_layer.objects.active = c
    kw = dict(filepath=chemin, export_format="GLB", use_selection=True, export_skins=False, export_animations=False,
              export_yup=True, export_materials="EXPORT")
    if "export_vertex_color" in bpy.ops.export_scene.gltf.get_rna_type().properties:
        kw["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORT SOL", chemin)
    bpy.data.objects.remove(c, do_unlink=True)


# ------------------------------------------------------------------------------------------------ aperçus (Blender, sans Godot)
MASQUE = {"tete": {"Hair_Long"}, "torse": {"tunique", "mante", "accessoires"}, "mains": set(), "pieds": {"bottes"}}


def _famille(pid):
    return "tete" if "casque" in pid else "torse" if "cuirasse" in pid else "mains" if "gant" in pid else "pieds"


def apercu(r, ob, dossier, pid):
    import apercu as AP
    importlib.reload(AP)
    cache = MASQUE[_famille(pid)]
    for n, o in r.corps.items():
        o.hide_render = n in cache
    cible = {"tete": (0, 0, 1.66), "torse": (0, 0, 1.15), "mains": (0.6, 0, 1.45), "pieds": (0, 0, 0.3)}[_famille(pid)]
    ortho = {"tete": 0.55, "torse": 1.25, "mains": 0.75, "pieds": 0.8}[_famille(pid)]
    AP.rendre(os.path.join(dossier, pid), cible=cible, ortho=ortho, dist=3.0, vues=("face", "34", "dos"), taille=(360, 480))


# ------------------------------------------------------------------------------------------------ chausses
def chausses(familles=("rubis", "saphir"), rapide=False):
    """Chausses assorties (dérivées du pantalon du héros, mêmes poids : cf. ../legeres/gen_legeres.py) : mailles d'acier bruni
    rouge à genouillères implicites (rubis) ; cuir bleu nuit matelassé à bandes de mailles givrées (saphir)."""
    arm = L.scene_base()
    o = L.copie("pantalon", "chausses", lambda c, n: c.y < 0.93)
    bvh = L.bvh_de(["pantalon"])
    L.ajuster(o, bvh, lambda p: 0.004, lissage=1, force=0.2)
    pw = L.poids(o)
    L.ecrire_poids(o, L.normaliser(pw))
    L.lisser_normales(o)
    print("PIECE chausses : %d triangles" % L.nb_tris(o))
    L.uv_auto(o, 0.006, 80)

    def rubis(P, N, pa, bd):
        out = peindre_maille(P, N, ACIER_RUBIS, 0.30, 0.0, 111)
        y, z = P[:, 1], P[:, 2]
        # bandes de cuir rouge sombre cloutées d'or le long de l'extérieur de la cuisse
        cote = np.abs(np.abs(P[:, 0]) - 0.19) < 0.018
        out[cote] = peindre_cuir(P[cote], np.full(cote.sum(), 0.02), y[cote], CUIR_RUBIS, 113)
        clou = cote & (np.abs(np.abs(P[:, 0]) - 0.19) < 0.004) & (np.mod(y / 0.035, 1.0) < 0.14)
        out[clou, :3] = L.rampe(OR_SOMBRE, np.full(clou.sum(), 0.8)); out[clou, 3] = 1.0
        return out

    def saphir(P, N, pa, bd):
        y = P[:, 1]
        out = peindre_cuir(P, np.full(len(P), 0.02), y, CUIR_SAPHIR, 121)
        piq = np.abs(np.mod(y / 0.045, 1.0) - 0.5) > 0.46              # matelassage horizontal
        out[piq, :3] *= 0.5
        mb = (np.mod(y / 0.09, 1.0) < 0.38) & (y < 0.62)
        out[mb] = peindre_maille(P[mb], N[mb], ACIER_SAPHIR, 0.55, 0.35, 123)
        return out

    fns = {"rubis": ("acier_rubis.maille", rubis), "saphir": ("cuir", saphir)}
    for fam in familles:
        nom_mat, fn = fns[fam]
        c = o.copy(); c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        c.name = "chausses_" + fam
        arr = L.cuire(c, fn, 256 if rapide else 512, None, tableau=True)
        img = image_depuis("chausses_" + fam, arr)
        c.data.materials.clear()
        c.data.materials.append(materiau(nom_mat, img))
        L.exporter(c, arm, fam, None, CHAUSSES)


# ------------------------------------------------------------------------------------------------ principal
EVASE_MANCHE = 0.0      # m ajoutés au DOS du bout des manches de mailles (cf. construire ; essai sans effet)


def construire(pid, rapide=False):
    GEMMES.clear()
    ens, fab = PIECES[pid]
    r = C.charger_reference()
    # Manches de mailles de la cuirasse (constructeur commun : tube à 8 côtés, ts 0 / 0,5 / 1) : bout évasé AU DOS. Dans les sorts à
    # deux mains (Sort_Jet2M) et le combo, le dos de la manche de tunique du héros (x = ±0,42, juste avant la coupe du masquage)
    # ressortait de 17 à 20 mm à travers le bout de la manche (défaut commun à toutes les cuirasses du constructeur lourd).
    tube0 = C.tube
    def tube(arbre, A, B, ts, n, decalage, **kw):
        if n == 8 and list(ts) == [0.0, 0.5, 1.0] and kw.get("r_loin") == 0.3:
            dec0 = decalage
            decalage = lambda j, i, a: dec0(j, i, a) + EVASE_MANCHE * (j / 2.0) ** 2 * max(0.0, -math.cos(a)) ** 0.8
        return tube0(arbre, A, B, ts, n, decalage, **kw)
    C.tube = tube
    try:
        ob = fab(r)
    finally:
        C.tube = tube0
    reorienter_gemmes(ob, {"rubis", "saphir", "serti_rubis", "serti_saphir", "cristal_rubis", "cristal_saphir"})
    plats = {i for i, m in enumerate(ob.data.materials) if m and m.name.split(".")[0] in ("rubis", "saphir", "cristal_rubis", "cristal_saphir")}
    for p in ob.data.polygons:
        if p.material_index in plats:
            p.use_smooth = False
    taille = 1024 if "cuirasse" in pid else 512
    mats = cuire_hd(ob, pid, ens, taille, rapide)
    return r, ob, mats


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    dossier = None
    if "--apercu" in argv:
        k = argv.index("--apercu"); dossier = argv[k + 1]; del argv[k:k + 2]
    sol = "--pas-sol" not in argv
    rapide = "--rapide" in argv
    argv = [a for a in argv if not a.startswith("--")]
    ids = []
    faire_chausses = not argv
    for a in argv or list(PIECES):
        if a in ("rubis", "saphir"):
            ids += [p for p in PIECES if p.endswith("_" + a)]
        elif a == "chausses":
            faire_chausses = True
        else:
            ids.append(a)
    for pid in ids:
        r, ob, mats = construire(pid, rapide)
        print("PIECE", pid, C.compter_tris(ob), "tris", "groupes", len(ob.vertex_groups), "matériaux", [m.name for m in mats[False]])
        poser_materiaux(ob, mats[False])
        C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
        if sol:
            version_sol(ob, pid, pid)
        if dossier:
            apercu(r, ob, dossier, pid)
        poser_materiaux(ob, mats[True])
        C.exporter([ob], r, os.path.join(C.PORTE, pid + "_enchante.glb"))
        if sol:
            version_sol(ob, pid, pid + "_enchante")
    if faire_chausses:
        chausses(rapide=rapide)


main()
