# Armures HD « OBSIDIENNE » et « OR » d'après la planche de l'utilisateur (conception_rpg/references/planche_armures_5.png,
# colonnes GOLD et OBSIDIAN ; BRIEF_PLANCHE_5_ARMURES.md) et la charte CHARTE_ARMURES_HD.md (2026-11-02).
#   blender.exe -b --python sources_blender/armures/obsidienne_or/generer.py -- [ids...] [--apercu DOSSIER] [--pas-enchante]
# Sans id : les 8 pièces (casque_, cuirasse_, gantelets_, bottes_ × obsidienne, or).
# Géométrie : constructeurs ajustés de l'agent Y (lourdes/pieces.py : coque du casque mesurée sur le crâne, cotte et lames
# mesurées sur le torse, manchettes, doigts, bottes/grèves/genouillères) + plaques à épaisseur réelle projetées sur le corps
# (hd.plaque : pectoraux, plastron, épaulières en lames, tassettes, ceinture, tabard, pan déchiré), visières, cornes, couronne,
# têtes de lion en relief, cabochons, chaînes.
# Textures : 512² par pièce, CUITES (hd.py) depuis la position 3D, le matériau et les UV sémantiques ; peintres dans peintres.py.
# Sorties : assets/modeles/armures/porte/<id>.glb, sol/<id>.glb, + <id>_enchante.glb (même modèle, runes / broderies luisantes).
import bpy, sys, os, math
sys.dont_write_bytecode = True        # ne pas réécrire les __pycache__ commités de lourdes/
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(0, os.path.join(ICI, "..", "lourdes"))
import importlib
import commun as C
import pieces as PC
import hd
import peintres as PE
for m in (C, PC, hd, PE):
    importlib.reload(m)
from mathutils import Vector, Matrix

TEXTURES = os.path.join(ICI, "textures")
TAILLE = 512
TAU = math.tau
DEVANT = Vector((0, -1, 0)); HAUT = Vector((0, 0, 1)); GAUCHE = Vector((1, 0, 0)); DOS = Vector((0, 1, 0))
UV_D = (0.0, 89.5 / 128, 0.05, 90.5 / 128)       # 2e atlas (sémantique) des décors : hors des bandes de l'agent Y


def _s(b0, **kw):
    d = dict(b0); d.update(kw); return d


def arete(a, b, dents=0, amp=0.0, axe=1, signe=-1, g=0):
    """Points de a (inclus) à b (exclu) ; avec des dents en scie irrégulières (hauteur amp sur la coordonnée `axe`)."""
    if dents <= 0:
        return [a]
    out = []
    for k in range(2 * dents):
        f = k / (2 * dents)
        p = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]
        if k % 2 == 1:
            p[axe] += signe * amp * (0.65 + 0.7 * hd._hash(k, g, 3, 7))
        out.append(tuple(p))
    return out


def miroir(contour):
    return [(-a, z) for (a, z) in reversed(contour)]


def corps(r, noms=("tunique", "peau", "pantalon")):
    return C.bvh(r, list(noms))


# ============================================================================================================== petits volumes
def gemme(P, c, dehors, rayon, mat="gemme", haut=None):
    """Cabochon taillé (6 pans, pointe douce) posé sur la surface."""
    d = Vector(dehors).normalized()
    h = Vector(haut) if haut is not None else HAUT
    w = d.cross(h)
    if w.length < 1e-3:
        w = d.cross(GAUCHE)
    w.normalize()
    u = d.cross(w).normalized()
    eq = [c + (w * math.cos(TAU * k / 8) + u * math.sin(TAU * k / 8)) * rayon for k in range(8)]
    mi = [c + d * rayon * 0.45 + (w * math.cos(TAU * k / 8) + u * math.sin(TAU * k / 8)) * rayon * 0.62 for k in range(8)]
    pt = c + d * rayon * 0.62
    fond = c - d * rayon * 0.5
    ie = [P.sommet(p) for p in eq]; im = [P.sommet(p) for p in mi]
    ip, i_f = P.sommet(pt), P.sommet(fond, 0.6)
    for k in range(8):
        k2 = (k + 1) % 8
        P.face([ie[k], ie[k2], im[k2], im[k]], mat, [(0.9, 0.9), (0.95, 0.9), (0.95, 0.93), (0.9, 0.93)])
        P.face([im[k], im[k2], ip], mat, [(0.9, 0.93), (0.95, 0.93), (0.92, 0.95)])
        P.face([ie[k2], ie[k], i_f], mat, [(0.95, 0.9), (0.9, 0.9), (0.92, 0.85)])


def chaton(P, c, dehors, rayon, mat="or.patine", haut=None):
    """Sertissure d'or (anneau à bord relevé) autour d'un cabochon."""
    d = Vector(dehors).normalized()
    h = Vector(haut) if haut is not None else HAUT
    w = d.cross(h)
    if w.length < 1e-3:
        w = d.cross(GAUCHE)
    w.normalize(); u = d.cross(w).normalized()
    r1 = [c - d * 0.004 + (w * math.cos(TAU * k / 10) + u * math.sin(TAU * k / 10)) * rayon * 1.45 for k in range(10)]
    r2 = [c + d * 0.004 + (w * math.cos(TAU * k / 10) + u * math.sin(TAU * k / 10)) * rayon * 1.3 for k in range(10)]
    r3 = [c + d * 0.003 + (w * math.cos(TAU * k / 10) + u * math.sin(TAU * k / 10)) * rayon * 1.0 for k in range(10)]
    P.grille([r1, r2, r3], mat, (0.3, 93.0 / 128, 0.4, 94.0 / 128), fermer=True)


def chaine(P, arbres, proj, pts, ecart=0.012, pas=0.019, mat="fer.chaine"):
    """Chaîne pendante : maillons (pavés allongés) alternés à 90°, le long d'une courbe (s, t) projetée sur la surface + écart."""
    courbe = []
    for (s, t) in pts:
        o, d = proj(s, t)
        hit, n = hd.lancer(arbres, o, d)
        if hit is not None:
            courbe.append((hit - Vector(d) * ecart, -Vector(d)))
    # rééchantillonnage tous les `pas`
    pos = []
    acc = 0.0
    for i in range(1, len(courbe)):
        a, b = courbe[i - 1][0], courbe[i][0]
        L = (b - a).length
        while acc <= L:
            f = acc / L
            pos.append((a.lerp(b, f), courbe[i][1], (b - a).normalized()))
            acc += pas
        acc -= L
    for k, (c, dehors, tg) in enumerate(pos):
        w = dehors if k % 2 == 0 else tg.cross(dehors).normalized()
        v = tg.cross(w).normalized()
        L, Wd, E = 0.0125, 0.0055, 0.0022
        coins = [c + tg * sx * L + w * sy * Wd + v * sz * E for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        ids = [P.sommet(p, 0.85) for p in coins]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6)):      # bouts ouverts (cachés dans le maillon voisin)
            P.face([ids[i] for i in q], mat, [(0.5, 0.5), (0.52, 0.5), (0.52, 0.52), (0.5, 0.52)])


def corne(P, racine, d0, courbe, longueur, rayon, mat="obsidienne", seg=6, cotes=6):
    """Corne : tube à `cotes` pans le long d'un chemin courbé (d <- d + courbe à chaque pas), effilé, pointe."""
    axe = [Vector(racine)]
    d = Vector(d0).normalized()
    for k in range(seg):
        axe.append(axe[-1] + d * (longueur / seg))
        d = (d + Vector(courbe)).normalized()
    anneaux = []
    for k, c in enumerate(axe):
        tg = (axe[min(k + 1, seg)] - axe[max(k - 1, 0)]).normalized()
        u, w = C.repere(tg)
        rr = rayon * (1.0 - k / (seg + 0.6)) ** 0.9
        anneaux.append([c + (u * math.cos(TAU * i / cotes) + w * math.sin(TAU * i / cotes)) * rr for i in range(cotes)])
    ids = P.grille(anneaux, mat, (0.6, 92.0 / 128, 0.9, 96.0 / 128))
    pt = P.sommet(axe[-1] + (axe[-1] - axe[-2]).normalized() * longueur * 0.12)
    for i in range(cotes):
        P.face([ids[-1][i], ids[-1][(i + 1) % cotes], pt], mat, [(0.6, 0.75), (0.65, 0.75), (0.62, 0.76)])
    for i in ids[0]:
        P.ao[i] = 0.55


def tete_lion(P, c, dehors, haut, rayon, mat="or.lion"):
    """Tête de lion en relief (champ de hauteur polaire) : crinière en mèches rayonnantes, front, arcades, yeux creusés, museau,
    nez ; `haut` = sens du front (vers l'épaule)."""
    d = Vector(dehors).normalized()
    hv = Vector(haut); hv = (hv - d * hv.dot(d)).normalized()
    wv = hv.cross(d).normalized()
    R = [0.0, 0.18, 0.36, 0.52, 0.66, 0.80, 0.92, 1.0]
    NS = 16
    def h(r, th):
        x, y = r * math.cos(th), r * math.sin(th)
        if r > 0.6:
            meche = abs(math.sin(th * 6.0 + r * 3.0))
            v = 0.42 * (1.0 - (r - 0.6) / 0.4) ** 0.8 + 0.16 * meche * (1.0 - abs(r - 0.8) / 0.25)
        else:
            v = 0.58 + 0.22 * (1.0 - (r / 0.6) ** 2)
        v += 0.30 * max(0.0, 1.0 - math.hypot(x, y + 0.24) / 0.26)          # museau
        v += 0.10 * max(0.0, 1.0 - math.hypot(x, y - 0.02) / 0.12)          # nez
        v += 0.10 * max(0.0, 1.0 - abs(y - 0.2) / 0.08) * (abs(x) < 0.4)    # arcades
        for sx in (-1, 1):
            v -= 0.16 * max(0.0, 1.0 - math.hypot(x - 0.2 * sx, y - 0.1) / 0.1)   # yeux
        v -= 0.10 * max(0.0, 1.0 - math.hypot(x, y + 0.42) / 0.1)           # gueule
        return max(0.0, v)
    ids = []
    for r in R:
        row = []
        for k in range(NS):
            th = TAU * k / NS
            x, y = r * math.cos(th), r * math.sin(th)
            p = c + (wv * x + hv * y) * rayon + d * (h(r, th) * rayon * 0.55 - 0.004)
            row.append(P.sommet(p, 0.9 if r < 0.9 else 0.7))
        ids.append(row)
    ctr = ids[0][0]
    for k in range(NS):
        k2 = (k + 1) % NS
        P.face([ctr, ids[1][k], ids[1][k2]], mat, [(0.7, 0.9), (0.72, 0.9), (0.71, 0.91)])
    for j in range(1, len(R) - 1):
        for k in range(NS):
            k2 = (k + 1) % NS
            P.face([ids[j][k], ids[j + 1][k], ids[j + 1][k2], ids[j][k2]], mat, [(0.7, 0.9), (0.72, 0.9), (0.72, 0.91), (0.7, 0.91)])


# ============================================================================================================== CASQUES
def visiere(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="obsidienne", crete=0.014, ecart=0.022):
    """Visière fermée devant le visage (front -> menton), arête médiane anguleuse, tranche rentrée ; la fente (incandescente pour
    l'obsidienne, en T sombre pour l'or) est peinte."""
    arbre = C.bvh(r, ["peau", "Hair_Beard"], {"Head", "neck_01"}, 0.3)
    lons = [-84, -66, -46, -28, -13, 0, 13, 28, 46, 66, 84]
    zs = [1.693, 1.668, 1.642, 1.615, 1.588, 1.563, 1.541]
    grille = []
    for z in zs:
        f = 1.0 if z > 1.60 else 1.0 - (1.60 - z) / (1.60 - 1.541) * 0.5
        row = []
        for lo in lons:
            lr = math.radians(lo * f)
            dd = Vector((math.sin(lr), -math.cos(lr), 0))
            c = Vector((0, 0.004, z))
            hit = arbre.ray_cast(c + dd * 0.4, -dd, 0.4)
            rr = (0.4 - hit[3]) if hit[0] is not None else 0.095
            arete_m = crete * max(0.0, 1.0 - abs(lo * f) / 34.0)
            row.append(c + dd * (rr + ecart + arete_m))
        grille.append(row)
    # le rayon ne doit jamais rentrer d'une rangée à l'autre (pas de creux sous le nez) : max avec la rangée du dessus
    for j in range(1, len(grille)):
        for i in range(len(lons)):
            p, q = grille[j][i], grille[j - 1][i]
            rp = Vector((p.x, p.y - 0.004, 0)).length; rq = Vector((q.x, q.y - 0.004, 0)).length
            if rp < rq * 0.97:
                k = rq * 0.97 / max(rp, 1e-6)
                grille[j][i] = Vector((p.x * k, 0.004 + (p.y - 0.004) * k, p.z))
    P.grille(grille, mat, (0.0, 92.0 / 128, 0.5, 96.0 / 128), fermer=False, inverser=True)
    def dedans(p):
        c = Vector((0, 0.004, p.z))
        return p + (c - p).normalized() * 0.012 + Vector((0, 0, 0.004))
    gauche = [row[0] for row in grille]; droite = [row[-1] for row in grille]; bas = grille[-1]
    P.grille([gauche, [dedans(p) for p in gauche]], mat, (0.0, 92.0 / 128, 0.05, 96.0 / 128), fermer=False)
    P.grille([[dedans(p) for p in droite], droite], mat, (0.0, 92.0 / 128, 0.05, 96.0 / 128), fermer=False)
    P.grille([[dedans(p) for p in bas], bas], mat, (0.0, 92.0 / 128, 0.5, 92.5 / 128), fermer=False)


def cornes_obsidienne(P, t, r, centre, Pts, R_NAS, R_CORNE):
    arbre = hd.bvh_piece(P)
    for s in (1.0, -1.0):
        d = Vector((0.82 * s, 0.05, 0.57)).normalized()
        hit, n = hd.poser_sur(arbre, centre + d * 0.5, -d)
        if hit is None:
            continue
        corne(P, hit - d * 0.01, (0.92 * s, 0.10, 0.36), (-0.24 * s, 0.03, 0.40), 0.165, 0.025)


def quille(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="obsidienne", h=0.012, dents=False):
    """Crête basse du front à la nuque (section rectangulaire) ; dentée pour l'obsidienne."""
    arbre = hd.bvh_piece(P)
    rangs = []
    N = 17
    for k in range(N):
        th = math.radians(28 + 132 * k / (N - 1))
        d = (DEVANT * math.cos(th) + HAUT * math.sin(th)).normalized()
        hit, nrm = hd.poser_sur(arbre, centre + d * 0.5, -d)
        if hit is None:
            continue
        hh = h * math.sin(math.pi * (0.12 + 0.76 * k / (N - 1))) + 0.004
        if dents and k % 2 == 1:
            hh += h * 0.9
        base = hit - d * 0.004
        rangs.append([base + GAUCHE * 0.0035, base + GAUCHE * 0.0025 + d * (hh + 0.004), base - GAUCHE * 0.0025 + d * (hh + 0.004),
                      base - GAUCHE * 0.0035])
    P.grille(rangs, mat, (0.0, 92.5 / 128, 0.06, 93.5 / 128), fermer=True)
    for bout, inv in ((rangs[0], True), (rangs[-1], False)):
        ids = [P.sommet(p) for p in bout]
        P.face(ids if not inv else list(reversed(ids)), mat, [(0.0, 0.73)] * 4)


def couronne(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="or.patine"):
    """Couronne d'or posée sur le haut du heaume : bandeau en relief, 10 fleurons (le plus haut au milieu du front), rubis."""
    j = 3
    ring = Pts[j]
    n = len(ring)
    bas = [p + (p - centre).normalized() * 0.006 for p in ring]
    hautb = [p + (p - centre).normalized() * 0.007 + Vector((0, 0, 0.022)) for p in ring]
    dedans_b = [p - (p - centre).normalized() * 0.003 for p in ring]
    dedans_h = [p - (p - centre).normalized() * 0.002 + Vector((0, 0, 0.022)) for p in ring]
    P.grille([bas, hautb], mat, (0.0, 92.0 / 128, 1.0, 93.0 / 128))
    P.grille([hautb, dedans_h], mat, (0.0, 92.0 / 128, 1.0, 92.2 / 128))
    P.grille([dedans_b, bas], mat, (0.0, 92.0 / 128, 1.0, 92.2 / 128))
    nf = 10
    for k in range(nf):
        i0 = int(round((k - 0.5) * n / nf)) % n; i1 = int(round(k * n / nf)) % n; i2 = int(round((k + 0.5) * n / nf)) % n
        a, b = hautb[i0], hautb[i2]
        hh = (0.05 if k == 0 else (0.038 if k % 2 == 0 else 0.026))
        m = hautb[i1] + Vector((0, 0, hh)) + (hautb[i1] - centre).normalized() * 0.004
        a2, b2 = dedans_h[i0], dedans_h[i2]
        m2 = m - (hautb[i1] - centre).normalized() * 0.006
        ia, ib, im, ia2, ib2, im2 = [P.sommet(p) for p in (a, b, m, a2, b2, m2)]
        P.face([ia, ib, im], mat, [(0.5, 0.72), (0.6, 0.72), (0.55, 0.73)])
        P.face([ib2, ia2, im2], mat, [(0.6, 0.72), (0.5, 0.72), (0.55, 0.73)])
        P.face([ib, ib2, im2, im], mat, [(0.5, 0.72), (0.6, 0.72), (0.6, 0.73), (0.5, 0.73)])
        P.face([ia2, ia, im, im2], mat, [(0.5, 0.72), (0.6, 0.72), (0.6, 0.73), (0.5, 0.73)])
    f = (bas[0] + hautb[0]) / 2
    dehors = (bas[0] - centre).normalized()
    gemme(P, f + dehors * 0.004, dehors, 0.0075)


# ============================================================================================================== CUIRASSE OBSIDIENNE
PROJ_T = hd.proj_torse(0.0, 0.02)


def obs_torse(P, t, r, st):
    """Plastron d'obsidienne : pectoraux anguleux à bord inférieur denté, arête du sternum, deux rangs de chevrons dentés sur le
    ventre, dossière, boucle ; tassettes dentées ; pan de tissu rouge déchiré au milieu ; chaînes pendantes ; épaulières en trois
    lames dentées à trois éclats."""
    B = corps(r)
    M = "obsidienne"
    def A():
        return [hd.bvh_piece(P), B]
    # ventre : deux rangs (le bas d'abord, celui du haut le recouvre)
    for (zh, zb, g) in ((1.165, 1.055, 3), (1.255, 1.135, 5)):
        c = [(-60, zh), (0, zh + 0.006), (60, zh)] + arete((66, zh - 0.03), (60, zb + 0.01), 0) + \
            arete((60, zb + 0.01), (0, zb - 0.02), 3, 0.022, g=g) + arete((0, zb - 0.02), (-60, zb + 0.01), 3, 0.022, g=g + 1) + [(-66, zh - 0.03)]
        hd.plaque(P, A(), PROJ_T, c, 0.011, 0.008, M, UV_D, bombe=0.006, anneaux=2)
    # dos : dossière haute et basse
    for (zh, zb, g, dec) in ((1.17, 1.045, 7, 0.010), (1.47, 1.14, 9, 0.012)):
        c = [(128, zh), (180, zh + 0.01), (232, zh)] + arete((238, (zh + zb) / 2), (232, zb), 0) + \
            arete((232, zb), (128, zb), 4, 0.03, g=g) + [(122, (zh + zb) / 2)]
        hd.plaque(P, A(), PROJ_T, c, dec, 0.008, M, UV_D, bombe=0.008, anneaux=2)
    # pectoraux
    for s in (1, -1):
        c = [(5, 1.468), (32, 1.478), (56, 1.452), (69, 1.385), (67, 1.30)] + arete((63, 1.27), (9, 1.215), 3, 0.032, g=11 + s) + [(5, 1.30)]
        if s < 0:
            c = miroir(c)
        hd.plaque(P, A(), PROJ_T, c, 0.012, 0.009, M, UV_D, bombe=0.012, anneaux=3)
    # arête du sternum (par-dessus)
    hd.plaque(P, A(), PROJ_T, [(-7, 1.472), (7, 1.472), (10, 1.32), (0, 1.17), (-10, 1.32)], 0.012, 0.009, M, UV_D, bombe=0.009, anneaux=2)
    # boucle de ceinture
    hd.plaque(P, A(), PROJ_T, [(0, 1.06), (12, 1.0), (0, 0.94), (-12, 1.0)], 0.012, 0.007, M, UV_D, bombe=0.008, anneaux=2)
    # pan de tissu rouge déchiré (sous les tassettes)
    bas = arete((17, 0.64), (0, 0.50), 3, 0.06, g=21) + arete((0, 0.50), (-17, 0.62), 3, 0.07, g=22)
    c = [(-15, 0.972), (15, 0.972), (17, 0.80)] + bas + [(-17, 0.62), (-17, 0.80)]
    hd.plaque(P, A(), PROJ_T, c, 0.007, 0.003, "tissu.rouge", UV_D, bombe=0.0, anneaux=3, biseau=0.3)
    # tassettes : dos, côtés, devant
    for s in (1, -1):
        for (a0, a1, zb, dec, g) in ((112, 168, 0.76, 0.010, 31), (56, 106, 0.74, 0.012, 33), (15, 54, 0.72, 0.014, 35)):
            c = [(a0, 0.985), (a1, 0.985)] + arete((a1 + 3, 0.86), (a1, zb), 0) + arete((a1, zb), (a0, zb + 0.02), 2, 0.05, g=g) + [(a0 - 2, 0.86)]
            if s < 0:
                c = miroir(c)
            hd.plaque(P, A(), PROJ_T, c, dec, 0.008, M, UV_D, bombe=0.006, anneaux=2)
    # chaînes de part et d'autre du pan
    for s in (1, -1):
        pts = [(s * (16 + 28 * u), 0.968 - 0.17 * 4 * u * (1 - u) - 0.01 * u) for u in [k / 12 for k in range(13)]]
        chaine(P, A(), PROJ_T, pts)
    # épaulières : trois lames (la plus éloignée de l'épaule sous les autres), bords dentés, trois éclats sur le dôme
    for s in (1.0, -1.0):
        Aep = Vector((0.10 * s, 0.0, 1.47)); Bep = Vector((0.385 * s, 0.02, 1.44))
        pj = hd.proj_axe(Aep, Bep)
        bras = C.bvh(r, ["tunique", "peau"], {"upperarm_l" if s > 0 else "upperarm_r", "clavicle_l" if s > 0 else "clavicle_r", "spine_03"}, 0.3)
        for (t0, t1, a, dec, bom, g) in ((0.66, 0.96, 100, 0.016, 0.006, 41), (0.40, 0.74, 106, 0.022, 0.008, 43), (0.02, 0.50, 114, 0.03, 0.018, 45)):
            c = [(-a, t0), (0, t0 - 0.02), (a, t0)] + arete((a + 4, (t0 + t1) / 2), (a, t1), 0) + arete((a, t1), (-a, t1), 4, 0.06, axe=1, signe=1, g=g) + \
                [(-a - 4, (t0 + t1) / 2)]
            hd.plaque(P, [hd.bvh_piece(P), bras], pj, c, dec, 0.009, M, UV_D, bombe=bom, anneaux=2)
        arb = [hd.bvh_piece(P)]
        ax = (Bep - Aep).normalized()
        for (a, tt, L) in ((-20, 0.16, 0.05), (4, 0.30, 0.066), (26, 0.43, 0.052)):
            o, d = pj(a, tt)
            hit, n = hd.lancer(arb, o, d)
            if hit is None:
                continue
            dirn = (-Vector(d) + ax * 0.5 + DOS * 0.15).normalized()
            hd.eclat(P, hit, dirn, L, 0.014, 0.0065, M, UV_D, cote_w=ax)


# ============================================================================================================== CUIRASSE OR
def or_torse(P, t, r, st):
    """Plastron d'or : cuirasse bombée, dossière, ceinture d'or à soleil et rubis, tassettes à deux rangs, tabard bleu nuit devant
    et derrière ; épaulières à dôme et deux lames, tête de lion, cabochon de rubis serti."""
    B = corps(r)
    M = "or.patine"
    def A():
        return [hd.bvh_piece(P), B]
    # dossière
    c = [(126, 1.47), (180, 1.48), (234, 1.47), (238, 1.30), (232, 1.13), (180, 1.10), (128, 1.13), (122, 1.30)]
    hd.plaque(P, A(), PROJ_T, c, 0.010, 0.008, M, UV_D, bombe=0.010, anneaux=3)
    # plastron
    c = [(-56, 1.445), (-30, 1.476), (0, 1.482), (30, 1.476), (56, 1.445), (66, 1.33), (58, 1.215), (32, 1.155), (0, 1.135),
         (-32, 1.155), (-58, 1.215), (-66, 1.33)]
    hd.plaque(P, A(), PROJ_T, c, 0.010, 0.009, M, UV_D, bombe=0.016, anneaux=3)
    # tabard bleu nuit (devant et derrière), pointe en bas
    for (a, zb) in ((0, 0.47), (180, 0.50)):
        c = [(a - 14, 0.975), (a + 14, 0.975), (a + 14, zb + 0.08), (a, zb), (a - 14, zb + 0.08)]
        hd.plaque(P, A(), PROJ_T, c, 0.007, 0.003, "tissu.bleu", UV_D, bombe=0.0, anneaux=3, biseau=0.3)
    # tassettes : rang bas puis rang haut, dos, côtés, devant
    for s in (1, -1):
        for (a0, a1, zh, zb, dec) in ((114, 166, 0.90, 0.75, 0.010), (58, 108, 0.90, 0.735, 0.011), (16, 54, 0.90, 0.72, 0.012),
                                      (114, 166, 0.985, 0.86, 0.016), (58, 108, 0.985, 0.85, 0.017), (16, 54, 0.985, 0.84, 0.018)):
            c = [(a0, zh), (a1, zh), (a1 + 3, (zh + zb) / 2), (a1, zb), ((a0 + a1) / 2, zb - 0.012), (a0, zb), (a0 - 2, (zh + zb) / 2)]
            if s < 0:
                c = miroir(c)
            hd.plaque(P, A(), PROJ_T, c, dec, 0.008, M, UV_D, bombe=0.006, anneaux=2)
    # ceinture d'or (deux moitiés) + soleil + rubis
    for (a0, a1) in ((-180, 0), (0, 180)):
        c = [(a0, 1.032), ((a0 + a1) / 2, 1.032), (a1, 1.032), (a1, 0.966), ((a0 + a1) / 2, 0.966), (a0, 0.966)]
        hd.plaque(P, A(), PROJ_T, c, 0.008, 0.006, M, UV_D, bombe=0.002, anneaux=2)
    soleil = []
    for k in range(16):
        an = TAU * k / 16 + math.pi / 2
        rr = 1.0 if k % 2 == 0 else 0.58
        soleil.append((15.0 * rr * math.cos(an), 1.0 + 0.042 * rr * math.sin(an)))
    ext, pc = hd.plaque(P, A(), PROJ_T, soleil, 0.010, 0.006, M, UV_D, bombe=0.008, anneaux=2)
    dehors = (pc - Vector((0, 0.02, pc.z))); dehors.z = 0; dehors.normalize()
    gemme(P, pc + dehors * 0.003, dehors, 0.011)
    # épaulières
    for s in (1.0, -1.0):
        Aep = Vector((0.10 * s, 0.0, 1.47)); Bep = Vector((0.385 * s, 0.02, 1.44))
        pj = hd.proj_axe(Aep, Bep)
        bras = C.bvh(r, ["tunique", "peau"], {"upperarm_l" if s > 0 else "upperarm_r", "clavicle_l" if s > 0 else "clavicle_r", "spine_03"}, 0.3)
        for (t0, t1, a, dec, bom) in ((0.66, 0.97, 102, 0.016, 0.006), (0.42, 0.76, 108, 0.022, 0.008), (0.02, 0.52, 116, 0.030, 0.020)):
            c = [(-a, t0), (0, t0 - 0.02), (a, t0), (a + 5, (t0 + t1) / 2), (a, t1), (0, t1 + 0.03), (-a, t1), (-a - 5, (t0 + t1) / 2)]
            hd.plaque(P, [hd.bvh_piece(P), bras], pj, c, dec, 0.009, M, UV_D, bombe=bom, anneaux=3 if t0 < 0.1 else 2)
        arb = [hd.bvh_piece(P)]
        ax = (Bep - Aep).normalized()
        o, d = pj(0, 0.30)
        hit, n = hd.lancer(arb, o, d)
        if hit is not None:
            tete_lion(P, hit, -Vector(d), -ax, 0.05)
        o, d = pj(-78, 0.20)
        hit, n = hd.lancer(arb, o, d)
        if hit is not None:
            chaton(P, hit, -Vector(d), 0.012)
            gemme(P, hit - Vector(d) * 0.004, -Vector(d), 0.012)


# ============================================================================================================== avant-bras, jambes
def manchettes_eclats(P, t, r, st, mat="obsidienne"):
    """Trois éclats sur le dessus de chaque manchette (côté extérieur une fois les bras baissés), rabattus vers le coude."""
    arbre = hd.bvh_piece(P)
    for cote, s in (("l", 1.0), ("r", -1.0)):
        la, ha = r.os["lowerarm_" + cote], r.os["hand_" + cote]
        for tt, L in ((0.50, 0.046), (0.66, 0.040), (0.82, 0.032)):
            o = la.lerp(ha, tt) + Vector((0, 0, 0.25))
            hit, nrm = hd.poser_sur(arbre, o, Vector((0, 0, -1)))
            if hit is None:
                continue
            dirn = (HAUT * 0.75 - GAUCHE * s * 0.95).normalized()
            hd.eclat(P, hit, dirn, L, 0.012, 0.0055, mat, UV_D, cote_w=GAUCHE)


def genou_eclats(P, t, r, st, cote, s, jambe, A, B, mat="obsidienne"):
    arbre = hd.bvh_piece(P)
    ca = r.os["calf_" + cote]
    o = Vector((ca.x, ca.y - 0.3, ca.z + 0.014))
    hit, nrm = hd.poser_sur(arbre, o, Vector((0, 1, 0)))
    if hit is not None:
        hd.eclat(P, hit, (DEVANT + HAUT * 0.8).normalized(), 0.046, 0.013, 0.0065, mat, UV_D, cote_w=GAUCHE)
    # deux ailettes sur le côté extérieur du tibia
    for z, L in ((0.30, 0.04), (0.20, 0.032)):
        o = Vector((ca.x + 0.3 * s, ca.y, z))
        hit, nrm = hd.poser_sur(arbre, o, Vector((-s, 0, 0)))
        if hit is not None:
            hd.eclat(P, hit, (GAUCHE * s + HAUT * 0.6 + DOS * 0.2).normalized(), L, 0.011, 0.005, mat, UV_D, cote_w=HAUT)


# ============================================================================================================== styles
OBS = dict(pal=C.FER_NOIR, mat="obsidienne", mat_rebord="fer.noir", mat_main="obsidienne", mat_doigts="fer.noir", mat_genou="obsidienne",
           mat_maille="fer.maille", base=0.4, oxyde=0.0, crasse=0.3, poli=0.6, graine=131, z_ourlet=0.66)
OR = dict(pal=C.ACIER, mat="or.patine", mat_rebord="or.patine", mat_main="or.patine", mat_doigts="or.patine", mat_genou="or.patine",
          mat_maille="tissu.bleu", base=0.34, oxyde=0.0, crasse=0.2, poli=0.6, graine=151, z_ourlet=0.66)
NIV_BOTTES = [-0.02, 0.01, 0.04, 0.08, 0.13, 0.19, 0.26, 0.33, 0.40, 0.46, 0.50]

PIECES = {
    "casque_obsidienne": lambda r: PC.casque(r, _s(OBS, id="casque_obsidienne", n=30, bas=(0.03, -0.24, -0.58), bombe=0.016, ecart=0.019,
                                                   bandes=0, rebord=0.009,
                                                   decor=[lambda *a: visiere(*a, mat="obsidienne", crete=0.016), cornes_obsidienne,
                                                          lambda *a: quille(*a, mat="obsidienne", h=0.010, dents=True)])),
    "cuirasse_obsidienne": lambda r: PC.cuirasse(r, _s(OBS, id="cuirasse_obsidienne", mat="fer.noir", n=20, lames=3, bombe=0.02,
                                                       lames_epaule=0, decor=[obs_torse])),
    "gantelets_obsidienne": lambda r: PC.gantelets(r, _s(OBS, id="gantelets_obsidienne", evasement=0.038, griffes=0.011,
                                                         mat_griffes="obsidienne", decor=[manchettes_eclats])),
    "bottes_obsidienne": lambda r: PC.bottes(r, _s(OBS, id="bottes_obsidienne", mat_botte="fer.noir", niveaux=NIV_BOTTES,
                                                   decor=[genou_eclats])),
    "casque_or": lambda r: PC.casque(r, _s(OR, id="casque_or", n=30, bas=(0.03, -0.22, -0.54), bombe=0.004, ecart=0.019, bandes=0,
                                           rebord=0.008,
                                           decor=[lambda *a: visiere(*a, mat="or.patine", crete=0.012), couronne])),
    "cuirasse_or": lambda r: PC.cuirasse(r, _s(OR, id="cuirasse_or", n=20, lames=4, bombe=0.02, lames_epaule=0, decor=[or_torse])),
    "gantelets_or": lambda r: PC.gantelets(r, _s(OR, id="gantelets_or", evasement=0.042)),
    "bottes_or": lambda r: PC.bottes(r, _s(OR, id="bottes_or", mat_botte="or.patine", niveaux=NIV_BOTTES)),
}
ENSEMBLE = {pid: ("obsidienne" if pid.endswith("obsidienne") else "or") for pid in PIECES}
VARIANTE = {"obsidienne": {"obsidienne": "obsidienne.enchante"}, "or": {"tissu.bleu": "tissu.enchante", "gemme": "gemme.enchante"}}


def _piece(pid):
    return pid.split("_")[0]


def peintre(pid, enchante):
    ens = ENSEMBLE[pid]
    def fn(D):
        D = dict(D); D["piece"] = _piece(pid)
        return PE.peindre_obsidienne(D, enchante) if ens == "obsidienne" else PE.peindre_or(D, enchante)
    return fn


# ============================================================================================================== pose au sol
def version_sol(r, ob, pid, suffixe=""):
    """Pièce posée (copie sans peau d'os) : cuirasse couchée sur le dos, casque sur le côté avec doublure, gantelets côte à côte,
    bottes debout ; pivot au sol. (Repris de lourdes/generer.py, agent Y.)"""
    import bmesh
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
                x = d.x * math.cos(a) + d.z * math.sin(a)
                z = -d.x * math.sin(a) + d.z * math.cos(a)
                v.co = o + Vector((x, d.y, z))
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    elif "casque" in pid:
        bm = bmesh.new(); bm.from_mesh(me)
        faces = [f for f in bm.faces if f.material_index == 0]
        ret = bmesh.ops.duplicate(bm, geom=faces)
        nf = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        bm.normal_update()
        for v in nv:
            v.co = v.co - v.normal * 0.006
        bmesh.ops.reverse_faces(bm, faces=nf)
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
    chemin = os.path.join(C.SOL, pid + suffixe + ".glb")
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


# ============================================================================================================== aperçus
MASQUE = {"tete": {"Hair_Long"}, "torse": {"tunique", "mante", "accessoires", "pantalon"}, "mains": set(), "pieds": {"bottes"}}
CIBLE = {"casque": ((0, 0, 1.66), 0.6), "cuirasse": ((0, 0, 1.08), 1.45), "gantelets": ((0.6, 0, 1.45), 0.75), "bottes": ((0, 0, 0.3), 0.8)}
FAM = {"casque": "tete", "cuirasse": "torse", "gantelets": "mains", "bottes": "pieds"}


def apercu(r, ob, dossier, pid):
    import apercu as AP
    importlib.reload(AP)
    cache = MASQUE[FAM[_piece(pid)]]
    for n, o in r.corps.items():
        o.hide_render = n in cache
    cible, ortho = CIBLE[_piece(pid)]
    AP.rendre(os.path.join(dossier, pid), cible=cible, ortho=ortho, dist=3.0, vues=("face", "34", "dos"), taille=(420, 560))
    for o in r.corps.values():
        o.hide_render = True
    AP.rendre(os.path.join(dossier, pid + "_seul"), cible=cible, ortho=ortho * 0.85, dist=3.0, vues=("34", "34dos"), taille=(560, 700))


# ============================================================================================================== principal
def construire(pid, dossier=None, enchante=True):
    r = C.charger_reference()
    ob = PIECES[pid](r)
    tris = C.compter_tris(ob)
    print("PIECE", pid, tris, "tris", "matériaux", [m.name for m in ob.data.materials])
    hd.uv_uniques(ob)
    tab, _ = hd.cuire(ob, TAILLE, peintre(pid, False))
    img = hd.image(pid, tab, TEXTURES)
    tab_e = None
    if enchante:
        tab_e, _ = hd.cuire(ob, TAILLE, peintre(pid, True))
    hd.retirer_uv_sem(ob)
    hd.poser_image(ob, img)
    hd.couleur_blanche(ob)
    C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
    version_sol(r, ob, pid)
    if dossier:
        apercu(r, ob, dossier, pid)
    if tab_e is not None:
        img_e = hd.image(pid + "_enchante", tab_e, TEXTURES)
        hd.poser_image(ob, img_e)
        for m in ob.data.materials:
            nv = VARIANTE[ENSEMBLE[pid]].get(m.name)
            if nv:
                m.name = nv
        C.exporter([ob], r, os.path.join(C.PORTE, pid + "_enchante.glb"))
        version_sol(r, ob, pid, "_enchante")
    return tris


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    dossier = None
    if "--apercu" in argv:
        k = argv.index("--apercu"); dossier = argv[k + 1]; del argv[k:k + 2]
        os.makedirs(dossier, exist_ok=True)
    ench = "--pas-enchante" not in argv
    ids = [a for a in argv if not a.startswith("--")] or list(PIECES)
    bilan = {}
    for pid in ids:
        bilan[pid] = construire(pid, dossier, ench)
    print("BILAN", bilan)


main()
