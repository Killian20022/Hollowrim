# Lot L8 objets : LUMINAIRES ET ACCROCHES en modules Blender (retouche des versions procédurales, mêmes encombrements).
#   blender.exe -b --python luminaires.py
# Sortie : assets/crypte/modules/luminaires.dat (même format que crypte_v2.dat ; relu par ObjLuminaires en FileAccess, sûr dans le
#          fil de construction). Pas de .glb ni de .blend : rien à inspecter que les captures ne montrent mieux.
# Modules (repère Godot, y haut, +z = devant / vers la pièce) :
#   maillon       maillon ovale ouvert (chaîne lisible : le jour passe dans l'anneau), pas de 0,1 m ; posé un sur deux tourné de 90°
#   applique_fer  applique murale (dos du mur en z = 0) : platine à fleurons et rivets, bras forgé et console en volute, bague à
#                 griffes, torche goudronnée cerclée ; flamme posée par le jeu à (0, 0,2, 0,32)
#   lanterne_fer  lanterne de fer (origine = crochet) : anneau, chapeau à 6 pans et fleuron, cadre, montants, plateau, bougie ;
#                 les vitres de corne sont des cartes additives posées par le jeu (on voit la flamme à travers)
#   lustre_l8 / lustre_l8_6  couronne de fer à cierges (8 ou 6) : double cercle riveté, pointes de couronne, coupelles, tiges de
#                 suspension à nœuds, anneau d'accroche à +0,55 ; points de flamme dans « pts »
#   candelabre_l8 candélabre à pied (1,45 m) : pieds en volute, fût à nœuds, bobèche, bras courbes ; points de flamme dans « pts »
#   brasero_trepied  brasero de fer de la grotte : trépied à pieds enroulés et cerclage, vasque rivetée à oreilles (0,44 m de rayon)
#   bougies_grappe_3 / _5 / _9  (lot C6, 2026-10-28) grappe de bougies de suif posée sur sa flaque de cire : hauteurs 4 à 22 cm,
#                 coulures en anneaux et larmes, mèches noires, chicots fondus ; points de flamme des bougies allumées dans « pts »
#                 (ObjLuminaires.bougies_grappe : UNE seule lumière par grappe, celle de la bougie remplacée) ; arêtes C1 (aretes.py)
# Les primitives (Module, occlusion cuite, conversion de repère) sont celles de crypte_modules_v2.py : le haut de ce fichier est
# exécuté tel quel (jusqu'au marqueur « modules »), sans reconstruire crypte_v2.dat.
import math, os, struct, sys

ICI_L8 = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(ICI_L8, "crypte_modules_v2.py"), encoding="utf-8").read()
_src = _src.split("# ======================================================================= modules")[0]
exec(compile(_src, "crypte_modules_v2.py (primitives)", "exec"))
from mathutils import Vector, Matrix
import bmesh

DAT_L8 = os.path.join(DOSSIER, "luminaires.dat")
TEINTE["corne"] = (1.0, 0.9, 0.7)


def anneau(M, R_x, R_y, e, pos, segs=6, mat="fer", ton=0.6, plan="xy", yaw=0.0, cotes=4, phase=0.0):
    """Anneau ovale (tore à section polygonale) : rayons R_x (horizontal) et R_y (vertical) au centre du fil, fil de demi-épaisseur e.
    plan « xy » : anneau vertical face à +z ; « xz » : anneau horizontal. Tourné de `yaw` autour de y."""
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = math.tau * (i + phase) / segs
        c = Vector((math.cos(a) * R_x, math.sin(a) * R_y, 0.0))
        # normale dans le plan de l'anneau (ellipse : gradient)
        n = Vector((math.cos(a) / max(R_x, 1e-4), math.sin(a) / max(R_y, 1e-4), 0.0)).normalized()
        z = Vector((0, 0, 1))
        ring = []
        for j in range(cotes):
            b = math.tau * (j + 0.5) / cotes
            q = c + n * (math.cos(b) * e) + z * (math.sin(b) * e)
            if plan == "xz":
                q = Vector((q.x, q.z, q.y))
            q = Matrix.Rotation(yaw, 3, 'Y') @ q
            ring.append(bm.verts.new(B(pos + q)))
        rings.append(ring)
    for i in range(segs):
        r0, r1 = rings[i], rings[(i + 1) % segs]
        for j in range(cotes):
            bm.faces.new((r0[j], r0[(j + 1) % cotes], r1[(j + 1) % cotes], r1[j]))
    M._emettre(bm, mat, ton)


def maillon(nom):
    """Maillon ovale vertical (15 x 8,6 cm hors tout, fil de 2,6 cm, bouts plats) : 6 x 3 faces = 36 triangles. Fer clair (ton 0,9) :
    la chaîne se détache du mur sombre."""
    M = Module(nom, 301)
    anneau(M, 0.03, 0.062, 0.013, Vector((0, 0, 0)), 6, "fer", 0.9, phase=0.5, cotes=3)
    return M


def applique_fer(nom):
    M = Module(nom, 311)
    # platine : plaque chanfreinée, fleurons haut et bas, 4 rivets
    M.boite((0.13, 0.3, 0.035), Vector((0, -0.01, 0.018)), "fer", bev=0.0, jit=0.002, ton=0.5)
    for s in (1, -1):
        M.coin([Vector((-0.045, s * 0.14, 0.0)), Vector((0.045, s * 0.14, 0.0)), Vector((-0.045, s * 0.14, 0.03)), Vector((0.045, s * 0.14, 0.03)),
                Vector((0.0, s * 0.2 - 0.01, 0.0)), Vector((0.0, s * 0.2 - 0.01, 0.025))], "fer", bev=0.0, ton=0.48)
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        M.boite((0.022, 0.022, 0.016), Vector((sx * 0.042, sy * 0.105 - 0.01, 0.04)), "fer", bev=0.0, jit=0.001, ton=0.75)
    # bras forgé (vers +z) et console en volute dessous
    M.boite((0.04, 0.04, 0.3), Vector((0, -0.06, 0.18)), "fer", bev=0.0, jit=0.002, ton=0.58)
    M.barre(Vector((0, -0.17, 0.035)), Vector((0, -0.07, 0.25)), 0.012, "fer", 0.55)
    anneau(M, 0.035, 0.035, 0.008, Vector((0, -0.13, 0.13)), 6, "fer", 0.6, yaw=math.pi / 2, cotes=3)    # volute (anneau de la console)
    # bague : collier + 4 griffes relevées
    anneau(M, 0.07, 0.07, 0.009, Vector((0, 0.015, 0.32)), 6, "fer", 0.7, plan="xz", cotes=3)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(Vector((0, -0.085, 0.32)) + d * 0.055, Vector((0, 0.03, 0.32)) + d * 0.075, 0.007, "fer", 0.55)
    # torche : manche, tête goudronnée cerclée
    M.cylindre(0.026, 0.032, 0.32, Vector((0, -0.12, 0.32)), 6, "bois", ton=0.75, jit=0.002)
    M.cylindre(0.05, 0.06, 0.1, Vector((0, 0.12, 0.32)), 7, "bois", ton=0.32, jit=0.004)
    for y in (0.135, 0.19):
        M.cylindre(0.063, 0.063, 0.014, Vector((0, y, 0.32)), 7, "fer", ton=0.45, jit=0.001)
    return M


def lanterne_fer(nom):
    M = Module(nom, 321)
    # anneau de suspension (origine = point d'accroche), cheminée, chapeau à 6 pans bas et rebord
    anneau(M, 0.022, 0.028, 0.007, Vector((0, -0.028, 0)), 6, "fer", 0.75)
    M.cylindre(0.032, 0.022, 0.03, Vector((0, -0.085, 0)), 6, "fer", ton=0.7, jit=0.0)
    M.cylindre(0.135, 0.032, 0.055, Vector((0, -0.135, 0)), 6, "fer", ton=0.72, jit=0.0)
    M.cylindre(0.14, 0.14, 0.012, Vector((0, -0.145, 0)), 6, "fer", ton=0.85, jit=0.0)
    # cadre : cercle haut, cercle bas, 6 montants fins (cage haute de 0,2 m : la flamme y tient)
    for y in (-0.15, -0.335):
        M.cylindre(0.118, 0.118, 0.014, Vector((0, y, 0)), 6, "fer", ton=0.75, jit=0.0)
    for k in range(6):
        a = math.tau * k / 6
        M.boite((0.013, 0.19, 0.013), Vector((math.cos(a) * 0.113, -0.24, math.sin(a) * 0.113)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.6)
    # plateau, pied court
    M.cylindre(0.1, 0.122, 0.028, Vector((0, -0.37, 0)), 6, "fer", ton=0.65, jit=0.0)
    M.cylindre(0.03, 0.05, 0.03, Vector((0, -0.4, 0)), 6, "fer", ton=0.6, jit=0.0)
    # bougie de suif
    M.cylindre(0.024, 0.022, 0.05, Vector((0, -0.342, 0)), 6, "cire", ton=0.95, jit=0.0)
    return M


def lustre_l8(nom, cierges=8, leger=False):
    """leger : variante des salles DonjonKit (lustre v1, nombreux) : cercles à 10 et 8 pans, sans rivets."""
    M = Module(nom, 331)
    R = 0.6
    M.tore_polygonal(R, 0.045, Vector((0, 0.0, 0)), 10 if leger else 14, "fer", 0.55, 0.07)
    M.tore_polygonal(R - 0.1, 0.03, Vector((0, 0.02, 0)), 8 if leger else 12, "fer", 0.5, 0.04)
    # pointes de couronne entre les cierges (silhouette nordique), rivets sur le cercle
    for k in range(cierges):
        a = math.tau * k / cierges
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.coin([d * (R - 0.02) + Vector((0, 0.035, 0)) + Vector((-d.z, 0, d.x)) * s * 0.03 for s in (1, -1)] +
               [d * (R + 0.02) + Vector((0, 0.035, 0)) + Vector((-d.z, 0, d.x)) * s * 0.03 for s in (1, -1)] +
               [d * R + Vector((0, 0.13, 0))], "fer", bev=0.0, ton=0.6)
        if not leger:
            M.boite((0.024, 0.02, 0.024), d * (R + 0.026) + Vector((0, -0.005, 0)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.78)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.boite((0.03, 0.03, R * 0.98), d * R * 0.5 + Vector((0, 0.03, 0)), "fer", yaw=-a, bev=0.0, jit=0.002, ton=0.5)
        M.barre(d * R * 0.95 + Vector((0, 0.04, 0)), Vector((0, 0.53, 0)), 0.012, "fer", 0.5)
        M.boite((0.034, 0.04, 0.034), d * R * 0.5 + Vector((0, 0.29, 0)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.62)     # nœud de la tige
    M.cylindre(0.05, 0.02, 0.2, Vector((0, -0.2, 0)), 6, "fer", ton=0.55, jit=0.002)
    M.sphere(0.065, Vector((0, 0.0, 0)), mat="fer", seg=6, ton=0.55, jit=0.003)
    M.cylindre(0.06, 0.05, 0.04, Vector((0, 0.51, 0)), 6, "fer", ton=0.55, jit=0.0)
    anneau(M, 0.03, 0.03, 0.008, Vector((0, 0.575, 0)), 6, "fer", 0.65)                     # anneau d'accroche de la chaîne
    for k in range(cierges):
        a = math.tau * (k + 0.5) / cierges
        c = Vector((math.cos(a) * R, 0.035, math.sin(a) * R))
        M.cylindre(0.062, 0.045, 0.06, c, 6, "fer", ton=0.66, jit=0.0)                        # coupelle à bobèche
        hc = 0.12 + 0.05 * (k % 3)
        M.cylindre(0.026, 0.024, hc, c + Vector((0, 0.06, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.pts.append(Vector((c.x, 0.06 + hc + 0.02, c.z)))
    return M


def candelabre_l8(nom, bras=3):
    M = Module(nom, 341)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(d * 0.04 + Vector((0, 0.3, 0)), d * 0.17 + Vector((0, 0.035, 0)), 0.016, "fer", 0.58)
        anneau(M, 0.03, 0.03, 0.009, d * 0.175 + Vector((0, 0.035, 0)), 6, "fer", 0.6, yaw=-a + math.pi / 2)     # pied en volute
    M.cylindre(0.07, 0.05, 0.08, Vector((0, 0.27, 0)), 8, "fer", ton=0.6, jit=0.0)
    M.cylindre(0.024, 0.024, 0.8, Vector((0, 0.35, 0)), 6, "fer", ton=0.55, jit=0.0)
    for y in (0.62, 0.95):
        M.cylindre(0.042, 0.042, 0.05, Vector((0, y - 0.025, 0)), 6, "fer", ton=0.62, jit=0.0)       # nœuds du fût
    M.cylindre(0.11, 0.08, 0.05, Vector((0, 1.15, 0)), 8, "fer", ton=0.62, jit=0.0)
    M.cylindre(0.115, 0.115, 0.012, Vector((0, 1.2, 0)), 8, "fer", ton=0.72, jit=0.0)
    for k in range(bras):
        a = math.tau * k / bras + 0.2
        d = Vector((math.cos(a), 0, math.sin(a)))
        c = d * 0.17
        M.barre(d * 0.03 + Vector((0, 1.17, 0)), d * 0.13 + Vector((0, 1.22, 0)), 0.011, "fer", 0.55)
        M.barre(d * 0.13 + Vector((0, 1.22, 0)), c + Vector((0, 1.36, 0)), 0.011, "fer", 0.55)
        M.cylindre(0.05, 0.035, 0.05, Vector((c.x, 1.36, c.z)), 8, "fer", ton=0.6, jit=0.0)
        M.cylindre(0.055, 0.055, 0.01, Vector((c.x, 1.405, c.z)), 8, "fer", ton=0.72, jit=0.0)
        hc = 0.13 + 0.05 * (k % 2)
        M.cylindre(0.024, 0.022, hc, Vector((c.x, 1.41, c.z)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.cylindre(0.03, 0.028, 0.025, Vector((c.x + 0.005, 1.41 + hc * 0.4, c.z)), 5, "cire", ton=0.85, jit=0.002)
        M.pts.append(Vector((c.x, 1.41 + hc + 0.01, c.z)))
    M.cylindre(0.026, 0.024, 0.2, Vector((0, 1.22, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
    M.cylindre(0.032, 0.03, 0.03, Vector((0.006, 1.27, 0)), 5, "cire", ton=0.85, jit=0.002)
    M.pts.append(Vector((0, 1.43, 0)))
    return M


def brasero_trepied(nom):
    M = Module(nom, 351)
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(d * 0.34 + Vector((0, 0.05, 0)), d * 0.16 + Vector((0, 0.72, 0)), 0.02, "fer", 0.55)
        anneau(M, 0.04, 0.04, 0.012, d * 0.37 + Vector((0, 0.045, 0)), 6, "fer", 0.6, yaw=-a + math.pi / 2)     # pied enroulé
    M.tore_polygonal(0.27, 0.022, Vector((0, 0.3, 0)), 9, "fer", 0.6, 0.03)                     # cerclage des pieds
    # vasque : profil évasé, lèvre épaisse rivetée, 4 oreilles
    M.cylindre(0.14, 0.36, 0.1, Vector((0, 0.68, 0)), 10, "fer", ton=0.58, jit=0.0)
    M.cylindre(0.36, 0.43, 0.14, Vector((0, 0.78, 0)), 10, "fer", ton=0.6, jit=0.0)
    M.tore_polygonal(0.425, 0.03, Vector((0, 0.925, 0)), 10, "fer", 0.72, 0.035)
    for k in range(10):
        a = math.tau * (k + 0.5) / 10
        M.boite((0.024, 0.024, 0.014), Vector((math.cos(a) * 0.41, 0.86, math.sin(a) * 0.41)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.8)
    for k in range(2):
        a = math.pi * k + 0.3
        anneau(M, 0.04, 0.03, 0.01, Vector((math.cos(a) * 0.43, 0.9, math.sin(a) * 0.43)), 6, "fer", 0.62, yaw=-a + math.pi / 2)
    return M


# ======================================================================= C6 (2026-10-28) : grappes de bougies
def _tri(M, mat, a, b, c, ton, dehors):
    """Triangle orienté (sens trigonométrique vu de `dehors`), comme ceux de Module._emettre."""
    if (b - a).cross(c - a).length_squared < 1e-14:
        return
    if (b - a).cross(c - a).dot(dehors) < 0.0:
        b, c = c, b
    M.tris.append((mat, (a.copy(), b.copy(), c.copy()), ton))


def _fut(M, c, profil, n, mat, ton, rot=0.0, cap=True, jit=0.0):
    """Révolution SANS fond (posée dans la cire) : profil [(r, y)] de bas en haut, chapeau en éventail si `cap`."""
    rg = M.rg
    P = lambda r, y, k: c + Vector((math.cos(rot + math.tau * k / n) * r, y, math.sin(rot + math.tau * k / n) * r))
    for i in range(len(profil) - 1):
        (r0, y0), (r1, y1) = profil[i], profil[i + 1]
        for k in range(n):
            an = rot + math.tau * (k + 0.5) / n
            d = Vector((math.cos(an) * (y1 - y0), r0 - r1, math.sin(an) * (y1 - y0)))
            t = ton * (1.0 + rg.uniform(-jit, jit))
            a, b, cc, dd = P(r0, y0, k), P(r0, y0, k + 1), P(r1, y1, k + 1), P(r1, y1, k)
            if r0 > 1e-5:
                _tri(M, mat, a, b, cc, t, d)
            if r1 > 1e-5:
                _tri(M, mat, a, cc, dd, t, d)
    if cap and profil[-1][0] > 1e-5:
        r, y = profil[-1]
        for k in range(1, n - 1):
            _tri(M, mat, P(r, y, 0), P(r, y, k), P(r, y, k + 1), ton, Vector((0, 1, 0)))


def _flaque_cire(M, R, n=10):
    """Flaque de cire figée : contour lobé (rayon R ± 30 %), bourrelet en biseau, dessus presque plat (cire à peine bombée)."""
    rg = M.rg
    rr = [R * rg.uniform(0.72, 1.12) for _ in range(n)]
    for k in range(0, n, 3):
        rr[k] *= rg.uniform(1.05, 1.25)          # lobes : coulées plus longues
    bord = [Vector((math.cos(math.tau * k / n) * rr[k], 0.0015, math.sin(math.tau * k / n) * rr[k])) for k in range(n)]
    haut = [Vector((p.x * 0.86, 0.009, p.z * 0.86)) for p in bord]
    ctr = Vector((0, 0.012, 0))
    for k in range(n):
        a, b = bord[k], bord[(k + 1) % n]
        c, d = haut[(k + 1) % n], haut[k]
        o = (a + b) * 0.5
        dehors = Vector((o.x, 0.6 * o.length, o.z))
        _tri(M, "cire", a, b, c, 0.78, dehors)
        _tri(M, "cire", a, c, d, 0.78, dehors)
        _tri(M, "cire", d, c, ctr, 0.9, Vector((0, 1, 0)))


def _bougie_c6(M, c, r, h, allumee):
    """Bougie de suif à 6 pans : fût un peu conique, anneaux de coulure, cratère et lèvre fondue au sommet, larmes, mèche."""
    rg = M.rg
    ton = rg.uniform(0.84, 1.0)
    rot = rg.uniform(0, math.tau)
    prof = [(r * 1.08, 0.0)]
    # anneaux de coulure : bourrelets de cire refroidie (la cire a coulé puis figé) ; deux sur les grandes bougies
    for y in sorted(rg.uniform(0.25, 0.8) * h for _ in range(2 if h > 0.15 else (1 if h > 0.05 else 0))):
        prof += [(r * 1.0, y - 0.01), (r * 1.24, y)]
    lev = r * rg.uniform(1.06, 1.16) if h > 0.06 else r * 0.9     # lèvre fondue débordante
    prof += [(r * 0.96, h - 0.008), (lev, h)]
    _fut(M, c, prof, 6, "cire", ton, rot, cap=True, jit=0.03)
    # larmes : cordons de cire qui descendent du sommet sur le fût, jusqu'à la flaque pour les plus longues
    for _ in range(rg.randint(1, 2)):
        a = rg.uniform(0, math.tau)
        d = Vector((math.cos(a), 0, math.sin(a)))
        tg = Vector((-d.z, 0, d.x))
        y1 = h - 0.004
        y0 = max(0.004, h * rg.uniform(0.0, 0.55))
        rb = r * 1.0
        w = rg.uniform(0.006, 0.01)
        p = [c + d * rb + tg * w + Vector((0, y1, 0)), c + d * rb - tg * w + Vector((0, y1, 0)),
             c + d * (rb + 0.007) + Vector((0, (y0 + y1) * 0.5, 0)),
             c + d * rb + tg * w * 1.4 + Vector((0, y0, 0)), c + d * rb - tg * w * 1.4 + Vector((0, y0, 0))]
        _tri(M, "cire", p[0], p[3], p[2], ton * 1.05, d + tg)
        _tri(M, "cire", p[1], p[2], p[4], ton * 1.05, d - tg)
        _tri(M, "cire", p[0], p[2], p[1], ton * 1.1, d + Vector((0, 1, 0)))
        _tri(M, "cire", p[3], p[4], p[2], ton * 0.9, d - Vector((0, 1, 0)))
    # mèche (noire, courbée) : prisme à 3 pans
    hm = 0.016 if allumee else 0.011
    m0 = c + Vector((0, h - 0.006, 0))
    m1 = c + Vector((rg.uniform(-0.004, 0.004), h + hm, rg.uniform(-0.004, 0.004)))
    for k in range(3):
        a0, a1 = math.tau * k / 3, math.tau * (k + 1) / 3
        e0 = Vector((math.cos(a0), 0, math.sin(a0))) * 0.0035
        e1 = Vector((math.cos(a1), 0, math.sin(a1))) * 0.0035
        dh = (e0 + e1)
        _tri(M, "noir", m0 + e0, m0 + e1, m1 + e1 * 0.5, 1.0, dh)
        _tri(M, "noir", m0 + e0, m1 + e1 * 0.5, m1 + e0 * 0.5, 1.0, dh)
    if allumee:
        M.pts.append(c + Vector((0, h + 0.012, 0)))


def bougies_grappe(nom, n):
    """Grappe de n bougies (3, 5 ou 9) sur une flaque de cire : hauteurs 4-22 cm (les hautes au centre), rayons 2,2-3,6 cm
    (bougies agrandies : >= 3 px à 3 m, règle §3.5), allumées : 3 / 4 / 7 ; chicots fondus (sans mèche) dans la flaque."""
    M = Module(nom, 361 + n)
    rg = M.rg
    R = {3: 0.08, 5: 0.11, 9: 0.155}[n]
    allumees = {3: 3, 5: 4, 9: 7}[n]
    _flaque_cire(M, R + 0.03, 9 if n < 9 else 12)
    pos = []
    essais = 0
    while len(pos) < n and essais < 2000:
        essais += 1
        k = len(pos)
        r = rg.uniform(0.022, 0.034) * (1.0 - min(0.3, essais / 2000.0))      # serré : rayons réduits si la place manque
        if k == 0 and n > 3:
            q = Vector((rg.uniform(-0.01, 0.01), 0, rg.uniform(-0.01, 0.01)))
        else:
            a = rg.uniform(0, math.tau)
            d = rg.uniform(0.2, 1.0) ** 0.5 * (R - r)
            q = Vector((math.cos(a) * d, 0, math.sin(a) * d))
        if all((q - p).length > r + rp + 0.004 for p, rp in pos):
            pos.append((q, r))
    assert len(pos) == n, (nom, len(pos))
    pos.sort(key=lambda e: e[0].length)
    for i, (q, r) in enumerate(pos):
        loin = q.length / max(R, 1e-3)
        h = 0.22 - loin * 0.14 + rg.uniform(-0.03, 0.02)          # 4 à 22 cm : hautes au centre, basses au bord
        h = max(0.04, min(0.22, h))
        if i >= allumees:
            h = max(0.04, h * 0.45)                                # bougies mortes : brûlées presque jusqu'à la cire
        _bougie_c6(M, q + Vector((0, 0.006, 0)), r, h, i < allumees)
    # chicots fondus : deux bosses de cire sans mèche dans la flaque (entre les bougies)
    for _ in range(2 if n > 3 else 1):
        for _e in range(30):
            a = rg.uniform(0, math.tau)
            q = Vector((math.cos(a), 0, math.sin(a))) * rg.uniform(0.5, 0.95) * R
            if all((q - p).length > rp + 0.03 for p, rp in pos):
                _fut(M, q + Vector((0, 0.006, 0)), [(0.022, 0.0), (0.016, 0.018), (0.006, 0.026)], 5, "cire", 0.85, rg.uniform(0, 6.3))
                break
    return M


GRAPPES = (3, 5, 9)


def construire_l8():
    return [maillon("maillon"), applique_fer("applique_fer"), lanterne_fer("lanterne_fer"), lustre_l8("lustre_l8", 8),
            lustre_l8("lustre_l8_6", 6, leger=True), candelabre_l8("candelabre_l8"), brasero_trepied("brasero_trepied")] + \
           [bougies_grappe("bougies_grappe_%d" % n, n) for n in GRAPPES]


def _lire_dat(chemin):
    """Entrées d'un .dat existant : { nom: [((p, p, p), (c, c, c)), ...] } (pour ne remplacer que certains modules)."""
    d = {}
    if not os.path.exists(chemin):
        return d
    b = open(chemin, "rb").read()
    o = 4
    for _ in range(struct.unpack_from("<I", b, 0)[0]):
        nom = b[o + 1:o + 1 + b[o]].decode()
        o += 1 + b[o]
        nb = struct.unpack_from("<I", b, o)[0]
        o += 4
        fl = struct.unpack_from("<%df" % (nb * 7), b, o)
        o += nb * 28
        sv = [(Vector(fl[i * 7:i * 7 + 3]), tuple(fl[i * 7 + 3:i * 7 + 7])) for i in range(nb)]
        d[nom] = [(tuple(q for q, _ in sv[j:j + 3]), tuple(c for _, c in sv[j:j + 3])) for j in range(0, nb, 3)]
    return d


def exporter_l8(mods, seulement=None):
    """seulement = préfixe : les modules qui ne le portent pas gardent leurs triangles du .dat existant (la génération des lustres
    n'est pas reproductible d'un lancement à l'autre : les lots suivants ne doivent pas les changer sans le vouloir)."""
    donnees = {}
    if seulement:
        ancien = _lire_dat(DAT_L8)
        mods = [M for M in mods if M.nom.startswith(seulement) or not any(k.startswith(M.nom + "__") for k in ancien)]
        for k, v in ancien.items():
            if not k.startswith(seulement):
                donnees[k] = v
    st = {}
    for M in mods:
        res = M.finir()
        if M.nom.startswith("bougies_grappe"):      # C6 : arête claire / pied sombre (lot C1) ; les luminaires L8 restent tels quels
            res = aretes.appliquer(res, bandes="hautes", stats=st)
        n_c6 = sum(len(f) for f in res.values())
        for mat, faces in res.items():
            donnees["%s__%s" % (M.nom, mat)] = faces
        if M.pts:
            donnees["%s__pts" % M.nom] = [((p, p, p), [(1, 1, 1, 1)] * 3) for p in M.pts]
        print("  %-18s %5d tris (%d apres aretes)" % (M.nom, len(M.tris), n_c6))
    with open(DAT_L8, "wb") as f:
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    print("luminaires L8 : %d modules ->" % len(mods), DAT_L8)


_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
#   blender.exe -b --python luminaires.py -- seulement=bougies_grappe   (C6 : ne régénère que les grappes, garde le reste du .dat)
exporter_l8(construire_l8(), next((a[10:] for a in _args if a.startswith("seulement=")), None))
