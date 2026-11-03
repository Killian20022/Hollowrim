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
from mathutils.bvhtree import BVHTree

TEXTURES = os.path.join(ICI, "textures")
TAILLE = 512
TAILLE_OR = 1024      # l'or est peint en aplats nets anti-aliasés : 1024² (l'obsidienne reste à 512²)
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


RELIEF = 1.0


def tete_lion(P, c, dehors, haut, rayon, mat="or.lion"):
    """Tête de lion en relief (champ de hauteur polaire) : crinière en mèches rayonnantes, front, arcades, yeux creusés, museau,
    nez ; `haut` = sens du front (vers l'épaule)."""
    d = Vector(dehors).normalized()
    hv = Vector(haut); hv = (hv - d * hv.dot(d)).normalized()
    wv = hv.cross(d).normalized()
    R = [0.0, 0.18, 0.36, 0.52, 0.64, 0.75, 0.85, 0.93, 1.0]
    NS = 22
    def h(r, th):
        x, y = r * math.cos(th), r * math.sin(th)
        if r > 0.58:
            # crinière : 7 mèches pointues qui rayonnent, creux profonds entre elles, bord extérieur biseauté
            meche = abs(math.sin(th * 3.5 + r * 1.6)) ** 1.4
            ex = max(0.0, (r - 0.58) / 0.42)
            v = 0.30 * max(0.0, 1.0 - ex) ** 0.7 + 0.40 * meche * max(0.0, math.sin(math.pi * min(1.0, ex * 1.15))) ** 0.8
        else:
            v = 0.42 + 0.12 * (1.0 - (r / 0.58) ** 2)
        v += 0.34 * max(0.0, 1.0 - math.hypot(x, y + 0.26) / 0.28)          # museau
        v += 0.14 * max(0.0, 1.0 - abs(x) / 0.07) * (0.0 < y + 0.05 < 0.34)  # arête du nez
        v += 0.18 * max(0.0, 1.0 - math.hypot(x, y + 0.12) / 0.10)          # truffe
        v += 0.24 * max(0.0, 1.0 - abs(y - 0.20) / 0.07) * (abs(x) < 0.46)  # arcades en bourrelet
        for sx in (-1, 1):
            v -= 0.20 * max(0.0, 1.0 - math.hypot((x - 0.23 * sx) * 0.7, y - 0.09) / 0.10)   # yeux en fente
        v -= 0.16 * max(0.0, 1.0 - abs(y + 0.47) / 0.04) * (abs(x) < 0.16)  # gueule
        return max(0.0, v)
    ids = []
    for r in R:
        row = []
        for k in range(NS):
            th = TAU * k / NS
            x, y = r * math.cos(th), r * math.sin(th)
            p = c + (wv * x + hv * y) * rayon + d * (h(r, th) * rayon * 0.95 * RELIEF - 0.004)
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


def nasal(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="or.patine"):
    """Nasal : barre verticale en relief le long de la visière (du bandeau au menton), section en trapèze, évasée en bas."""
    arbre = hd.bvh_piece(P)
    rangs = []
    for z in (1.676, 1.662, 1.640, 1.610, 1.580, 1.556, 1.543):
        o = Vector((0, -0.5, z))
        hit, n = hd.poser_sur(arbre, o, Vector((0, 1, 0)))
        if hit is None:
            continue
        lw = 0.0075 + (0.0045 if z < 1.56 else 0.0)
        rangs.append([hit + Vector((lw, 0.001, 0)), hit + Vector((lw * 0.55, -0.014, 0)), hit + Vector((-lw * 0.55, -0.014, 0)),
                      hit + Vector((-lw, 0.001, 0))])
    P.grille(rangs, mat, (0.0, 92.5 / 128, 0.06, 93.5 / 128), fermer=False)
    for bout, inv in ((rangs[0], True), (rangs[-1], False)):
        ids = [P.sommet(p) for p in bout]
        P.face(ids if not inv else list(reversed(ids)), mat, [(0.0, 0.73)] * 4)


def bavolet(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="or.patine"):
    """Bavolet : jupe de deux rangs de lames festonnées qui pend du bord du heaume sur les côtés et la nuque (ouverte devant)."""
    ring = Pts[0]
    n = len(ring)
    a, b, c = [], [], []
    for i in range(5, n - 4):
        p = ring[i]
        o = Vector((p.x - centre.x, p.y - centre.y, 0)).normalized()
        a.append(p + o * 0.008 + Vector((0, 0, 0.004)))
        b.append(p + o * 0.030 - Vector((0, 0, 0.034)))
        c.append(p + o * 0.040 - Vector((0, 0, 0.060 if i % 2 else 0.082)))
    P.grille([a, b, c], mat, (0.0, 92.0 / 128, 1.0, 93.0 / 128), fermer=False)


def cornes_obsidienne(P, t, r, centre, Pts, R_NAS, R_CORNE):
    arbre = hd.bvh_piece(P)
    for s in (1.0, -1.0):
        d = Vector((0.82 * s, 0.05, 0.57)).normalized()
        hit, n = hd.poser_sur(arbre, centre + d * 0.5, -d)
        if hit is None:
            continue
        corne(P, hit - d * 0.012, (0.92 * s, 0.12, 0.34), (-0.26 * s, 0.02, 0.42), 0.155, 0.031)


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
        hh = (0.088 if k == 0 else (0.066 if k % 2 == 0 else 0.046))
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


def gorgerin(P, A, M, dents=0):
    """Gorgerin : plaque montante autour de la nuque et des côtés du cou (ouverte devant pour la barbe), sous le bord du casque."""
    haut = [(56, 1.528), (80, 1.575)] + arete((100, 1.592), (180, 1.60), dents, 0.012, signe=1, g=61) + \
        arete((180, 1.60), (260, 1.592), dents, 0.012, signe=1, g=62) + [(260, 1.592), (280, 1.575), (304, 1.528)]
    c = haut + [(306, 1.485), (180, 1.468), (54, 1.485)]
    hd.plaque(P, A, PROJ_T, c, 0.010, 0.007, M, UV_D, bombe=0.004, anneaux=2, centre=(180, 1.52))


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
        hd.plaque(P, A(), PROJ_T, c, 0.012, 0.009, M, UV_D, bombe=0.012, anneaux=2)
    # arête du sternum (par-dessus)
    hd.plaque(P, A(), PROJ_T, [(-7, 1.472), (7, 1.472), (10, 1.32), (0, 1.17), (-10, 1.32)], 0.012, 0.009, M, UV_D, bombe=0.009, anneaux=2)
    # boucle de ceinture
    hd.plaque(P, A(), PROJ_T, [(0, 1.06), (12, 1.0), (0, 0.94), (-12, 1.0)], 0.012, 0.007, M, UV_D, bombe=0.008, anneaux=2)
    gorgerin(P, A(), M, dents=3)
    # pan de tissu rouge déchiré (sous les tassettes)
    bas = arete((17, 0.50), (3, 0.34), 4, 0.10, g=21) + arete((3, 0.34), (-17, 0.46), 4, 0.11, g=22)
    c = [(-15, 0.972), (15, 0.972), (17, 0.80)] + bas + [(-17, 0.50), (-17, 0.80)]
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
    # éclats de bas de jupe (pointes vers le bas, par-dessus les tassettes)
    arbj = [hd.bvh_piece(P), B]
    for sg in (1, -1):
        for a in (30, 82, 138):
            o, d = PROJ_T(sg * a, 0.80)
            hit, n = hd.lancer(arbj, o, d)
            if hit is not None:
                hd.eclat(P, hit, (-Vector(d) * 0.45 + Vector((0, 0, -0.9))).normalized(), 0.075, 0.016, 0.008, M, UV_D, cote_w=GAUCHE)
    # épaulières : trois lames (la plus éloignée de l'épaule sous les autres), bords dentés, trois éclats sur le dôme
    for s in (1.0, -1.0):
        Aep = Vector((0.10 * s, 0.0, 1.47)); Bep = Vector((0.385 * s, 0.02, 1.44))
        pj = hd.proj_axe(Aep, Bep)
        bras = C.bvh(r, ["tunique", "peau"], {"upperarm_l" if s > 0 else "upperarm_r", "clavicle_l" if s > 0 else "clavicle_r", "spine_03"}, 0.3)
        for (t0, t1, a, dec, bom, g) in ((0.90, 1.16, 92, 0.011, 0.004, 47), (0.66, 0.96, 100, 0.014, 0.005, 41), (0.40, 0.74, 106, 0.019, 0.007, 43), (0.02, 0.50, 114, 0.025, 0.014, 45)):
            c = [(-a, t0), (0, t0 - 0.02), (a, t0)] + arete((a + 4, (t0 + t1) / 2), (a, t1), 0) + arete((a, t1), (-a, t1), 4, 0.06, axe=1, signe=1, g=g) + \
                [(-a - 4, (t0 + t1) / 2)]
            hd.plaque(P, [hd.bvh_piece(P), bras], pj, c, dec, 0.009, M, UV_D, bombe=bom, anneaux=2)
        arb = [hd.bvh_piece(P)]
        ax = (Bep - Aep).normalized()
        for (a, tt, L) in ((-24, 0.14, 0.085), (-4, 0.24, 0.11), (22, 0.20, 0.09), (-30, 0.36, 0.08), (12, 0.38, 0.115), (36, 0.34, 0.075)):
            o, d = pj(a, tt)
            hit, n = hd.lancer(arb, o, d)
            if hit is None:
                continue
            dirn = (-Vector(d) + ax * 0.5 + DOS * 0.15).normalized()
            hd.eclat(P, hit, dirn, L, 0.020, 0.009, M, UV_D, cote_w=ax)


# ============================================================================================================== CUIRASSE OR
def _hit_y(B, x, z, depuis_devant=True):
    o = Vector((x, -0.9 if depuis_devant else 0.9, z))
    d = Vector((0, 1, 0)) if depuis_devant else Vector((0, -1, 0))
    h = B.ray_cast(o, d, 2.0)
    return None if h[0] is None else h[0].y


def drap(P, B, mat, devant, hw0, hw1, z0, z1, nc, nr, ecart0, ecart1, pointe=0.0, courbe=0.0):
    """Drap (tabard devant, cape derriere) : grille nc x nr, largeur hw0 -> hw1 de z0 a z1, a `ecart` du corps (mesure par lancer),
    bas en V (pointe), bords releves (courbe). Retourne les indices de sommets."""
    zs = [z0 + (z1 - z0) * j / (nr - 1) for j in range(nr)]
    ids = []
    for j, z in enumerate(zs):
        f = j / (nr - 1.0)
        hw = hw0 + (hw1 - hw0) * f
        ec = ecart0 + (ecart1 - ecart0) * f
        ys = [_hit_y(B, hw * (2.0 * i / (nc - 1) - 1.0) * 0.9, z, devant) for i in range(nc)]
        ys = [y for y in ys if y is not None]
        if not ys:
            ys = [-0.12] if devant else [0.12]
        yb = (min(ys) - ec) if devant else (max(ys) + ec)
        row = []
        for i in range(nc):
            u = 2.0 * i / (nc - 1) - 1.0
            zz = z - pointe * f * (1.0 - abs(u))           # bas en V : le centre descend plus bas
            y = yb + (courbe * u * u * (1 if devant else -1)) * (0.5 + f)
            row.append(P.sommet(Vector((hw * u, y, zz)), 0.85 + 0.15 * (1 - f)))
        ids.append(row)
    for j in range(nr - 1):
        for i in range(nc - 1):
            q = [ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]]
            P.face(q, mat, [(UV_D[0], UV_D[1]), (UV_D[2], UV_D[1]), (UV_D[2], UV_D[3]), (UV_D[0], UV_D[3])])
    return ids


def peau_cape(ob, r):
    """Cape statique : poids rigides sur la colonne (spine_03 en haut -> spine_01 en bas), aucun poids sur les jambes."""
    import bmesh
    kd = [i for i, m in enumerate(ob.data.materials) if m and m.name == "tissu.doublure"]
    if kd:
        bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
        bmesh.ops.reverse_faces(bm, faces=[f for f in bm.faces if f.material_index in kd])
        bm.to_mesh(ob.data); bm.free()
    k = [i for i, m in enumerate(ob.data.materials) if m and m.name.startswith("tissu.cape") or m and m.name == "tissu.doublure"]
    if not k:
        return
    vs = set()
    for p in ob.data.polygons:
        if p.material_index in k:
            vs.update(p.vertices)
    for g in ob.vertex_groups:
        g.remove(list(vs))
    for i in vs:
        z = ob.data.vertices[i].co.z
        f = max(0.0, min(1.0, (z - 0.95) / (1.30 - 0.95)))
        ob.vertex_groups["spine_03"].add([i], f, "REPLACE") if f > 0 else None
        ob.vertex_groups["spine_01"].add([i], 1.0 - f, "REPLACE") if f < 1 else None


def or_torse(P, t, r, st):
    """Plastron d'or : cuirasse bombée, dossière, ceinture d'or à soleil et rubis, tassettes à deux rangs, tabard bleu nuit devant
    et derrière ; épaulières à dôme et deux lames, tête de lion, cabochon de rubis serti."""
    B = corps(r)
    M = "or.patine"
    def A():
        return [hd.bvh_piece(P), B]
    gorgerin(P, A(), M)
    # dossière
    c = [(126, 1.47), (180, 1.48), (234, 1.47), (238, 1.30), (232, 1.13), (180, 1.10), (128, 1.13), (122, 1.30)]
    hd.plaque(P, A(), PROJ_T, c, 0.010, 0.008, M, UV_D, bombe=0.010, anneaux=2)
    # plastron
    c = [(-56, 1.445), (-30, 1.476), (0, 1.482), (30, 1.476), (56, 1.445), (66, 1.33), (58, 1.215), (32, 1.155), (0, 1.135),
         (-32, 1.155), (-58, 1.215), (-66, 1.33)]
    hd.plaque(P, A(), PROJ_T, c, 0.010, 0.009, M, UV_D, bombe=0.016, anneaux=2)
    # tabard bleu nuit LARGE (devant : largeur des hanches, jusqu'aux mollets, pointe en bas) + cape bleue statique derrière
    drap(P, B, "tissu.tabard", True, 0.165, 0.150, 0.985, 0.42, 7, 6, 0.036, 0.05, pointe=0.10, courbe=0.012)
    drap(P, B, "tissu.cape", False, 0.27, 0.47, 1.50, 0.40, 7, 5, 0.085, 0.130, pointe=0.0, courbe=0.045)
    drap(P, B, "tissu.doublure", False, 0.27, 0.47, 1.50, 0.40, 7, 5, 0.078, 0.123, pointe=0.0, courbe=0.045)   # face intérieure (retournée après coup)
    # tassettes : rang bas puis rang haut, dos, côtés, devant
    for s in (1, -1):
        for (a0, a1, zh, zb, dec) in ((114, 166, 0.90, 0.75, 0.010), (58, 108, 0.90, 0.735, 0.011), (16, 54, 0.90, 0.72, 0.012),
                                      (114, 166, 0.985, 0.86, 0.016), (58, 108, 0.985, 0.85, 0.017), (16, 54, 0.985, 0.84, 0.018)):
            c = [(a0, zh), (a1, zh), (a1 + 3, (zh + zb) / 2), (a1, zb), ((a0 + a1) / 2, zb - 0.012), (a0, zb), (a0 - 2, (zh + zb) / 2)]
            if s < 0:
                c = miroir(c)
            hd.plaque(P, A(), PROJ_T, c, dec, 0.008, M, UV_D, bombe=0.006, anneaux=2)
    # 3e rang de tassettes (le plus bas, recouvert par les deux autres)
    for s_ in (1, -1):
        for (a0, a1) in ((114, 166), (58, 108), (16, 54)):
            c = [(a0, 0.80), (a1, 0.80), (a1 + 3, 0.74), (a1, 0.66), ((a0 + a1) / 2, 0.645), (a0, 0.66), (a0 - 2, 0.74)]
            if s_ < 0:
                c = miroir(c)
            hd.plaque(P, A(), PROJ_T, c, 0.007, 0.008, M, UV_D, bombe=0.005, anneaux=1)
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
        for (t0, t1, a, dec, bom) in ((0.90, 1.15, 92, 0.010, 0.004), (0.66, 0.95, 100, 0.013, 0.005), (0.42, 0.75, 106, 0.018, 0.006), (0.02, 0.52, 114, 0.024, 0.013)):
            c = [(-a, t0), (0, t0 - 0.02), (a, t0), (a + 5, (t0 + t1) / 2), (a, t1), (0, t1 + 0.03), (-a, t1), (-a - 5, (t0 + t1) / 2)]
            hd.plaque(P, [hd.bvh_piece(P), bras], pj, c, dec, 0.009, M, UV_D, bombe=bom, anneaux=2)
        arb = [hd.bvh_piece(P)]
        ax = (Bep - Aep).normalized()
        # tête de lion tournée vers l'avant et le haut (de face, elle se lit sur le dessus de l'épaule) : rayon visé sur l'axe
        cible = Aep + ax * (Bep - Aep).length * 0.58
        dl = Vector((0.20 * s, -0.78, 0.62)).normalized()
        hit, n = hd.lancer(arb, cible + dl * 0.5, -dl)
        if hit is not None:
            # rondel d'or repoussé sous la tête (ombre portée, anneau en saillie) : la tête lit comme un médaillon de métal
            wv = dl.cross(-ax).normalized(); hv = wv.cross(dl).normalized()
            def pl(s_, t_, wv=wv, hv=hv, dl=dl, hit=hit):
                return hit + dl * 0.4 + wv * s_ + hv * t_, -dl
            rond = [(0.132 * math.cos(TAU * k / 16), 0.132 * math.sin(TAU * k / 16)) for k in range(16)]
            hd.plaque(P, arb, pl, rond, 0.006, 0.011, "or.lion", (0.80, 0.9, 0.85, 0.91), bombe=0.012, anneaux=1, centre=(0.0, 0.0), biseau=1.0)
            hit2, n2 = hd.lancer([hd.bvh_piece(P)], cible + dl * 0.5, -dl)
            tete_lion(P, hit2 if hit2 is not None else hit, dl, -ax, 0.108)
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
        for tt, L in ((0.22, 0.075), (0.42, 0.085), (0.60, 0.075), (0.78, 0.062)):
            o = la.lerp(ha, tt) + Vector((0, 0, 0.25))
            hit, nrm = hd.poser_sur(arbre, o, Vector((0, 0, -1)))
            if hit is None:
                continue
            dirn = (HAUT * 0.75 - GAUCHE * s * 0.95).normalized()
            hd.eclat(P, hit, dirn, L, 0.012, 0.0055, mat, UV_D, cote_w=GAUCHE)


def greves_dentees(P, t, r, st, cote, s, jambe, A, B, mat="obsidienne"):
    """Grève d'obsidienne dentée sur le tibia, plaque de mollet, plaque du cou-de-pied (planche : jambes en plaques anguleuses)."""
    ca = r.os["calf_" + cote]
    Ah = Vector((ca.x, ca.y - 0.005, 0.47)); Bb = Vector((ca.x, -0.02, 0.05))
    pj = hd.proj_axe(Ah, Bb, haut=DEVANT, r=0.3)
    jb = C.bvh(r, ["bottes", "pantalon"], {"calf_" + cote, "foot_" + cote}, 0.4)
    c = arete((-62, 0.06), (62, 0.06), 2, 0.05, signe=-1, g=71) + [(62, 0.06), (70, 0.45)] + arete((64, 0.86), (-64, 0.86), 2, 0.06, signe=1, g=72) + [(-64, 0.86), (-70, 0.45)]
    hd.plaque(P, [hd.bvh_piece(P), jb], pj, c, 0.009, 0.008, mat, UV_D, bombe=0.008, anneaux=2)
    c = [(118, 0.10), (180, 0.08), (242, 0.10), (246, 0.42)] + arete((242, 0.70), (118, 0.70), 2, 0.05, signe=1, g=73) + [(114, 0.42)]
    hd.plaque(P, [hd.bvh_piece(P), jb], pj, c, 0.008, 0.007, mat, UV_D, bombe=0.006, anneaux=2)


def plaques_mains(P, t, r, st, mat="or.patine", dents=0):
    """Plaque bombée sur le dos de chaque main (du poignet aux jointures), bord relevé ; dentée pour l'obsidienne."""
    for cote, s in (("l", 1.0), ("r", -1.0)):
        ha = r.os["hand_" + cote]
        jo = (r.os["index_01_" + cote] + r.os["pinky_01_" + cote]) / 2
        pj = hd.proj_axe(ha, jo + (jo - ha).normalized() * 0.01, haut=HAUT, r=0.2)
        c = [(-62, 0.05), (0, 0.02), (62, 0.05)] + arete((66, 0.5), (60, 0.98), 0) + arete((60, 0.98), (-60, 0.98), dents, 0.08, signe=1, g=81) + [(-66, 0.5)]
        hd.plaque(P, [hd.bvh_piece(P)], pj, c, 0.004, 0.005, mat, UV_D, bombe=0.004, anneaux=2)


def genou_eclats(P, t, r, st, cote, s, jambe, A, B, mat="obsidienne"):
    greves_dentees(P, t, r, st, cote, s, jambe, A, B, mat)
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


# ============================================================================================================== NIVEAU DE DETAIL v_detail
PROJ_H = hd.proj_torse(0.0, 0.0, 0.5)


def _arc(a0, a1, t, n=3):
    return [(a0 + (a1 - a0) * k / n, t) for k in range(n + 1)]


def _lame_membre(P, arbres, pj, a, t0, t1, dec, bom, mat, dents=0, g=0, ang=3, anneaux=2, pointe=0.0, a0=None):
    """Lame enroulée sur un membre : arc d'angles [-a, a] entre t0 (haut) et t1 (bas), bord bas denté (obsidienne) ou arrondi (or)."""
    if a0 is not None:                       # lame centrée sur l'angle a0 (ex. 180 = arrière)
        haut = [(a0 + u, t0) for u, _ in _arc(-a, a, t0, ang)]
        cote_d = [(a0 + a + 4, (t0 + t1) / 2)]
        bas = [(a0 + a, t1), (a0 + a * 0.5, t1 + pointe * 0.45), (a0, t1 + pointe), (a0 - a * 0.5, t1 + pointe * 0.45), (a0 - a, t1)]
        c = haut + cote_d + bas + [(a0 - a - 4, (t0 + t1) / 2)]
        c = c[::-1]                          # côté arrière : le sens de l'angle s'inverse vu de l'extérieur
        hd.plaque(P, arbres, pj, c, dec, 0.008, mat, UV_D, bombe=bom, anneaux=anneaux)
        return
    if pointe:
        haut = _arc(-a, a, t0, ang)
        cote_d = [(a + 4, (t0 + t1) / 2)]
        bas = [(a, t1), (a * 0.5, t1 + pointe * 0.45), (0, t1 + pointe), (-a * 0.5, t1 + pointe * 0.45), (-a, t1)]
        c = haut + cote_d + bas + [(-a - 4, (t0 + t1) / 2)]
        hd.plaque(P, arbres, pj, c, dec, 0.008, mat, UV_D, bombe=bom, anneaux=anneaux)
        return
    haut = _arc(-a, a, t0, ang)
    cote_d = [(a + 4, (t0 + t1) / 2)]
    if dents:
        bas = arete((a, t1), (-a, t1), dents, 0.05, axe=1, signe=1, g=g)
    else:
        bas = [(a * 0.5, t1 + 0.012), (0, t1 + 0.02), (-a * 0.5, t1 + 0.012)]
        bas = [(a, t1)] + bas + [(-a, t1)]
    c = haut + cote_d + bas + [(-a - 4, (t0 + t1) / 2)]
    hd.plaque(P, arbres, pj, c, dec, 0.008, mat, UV_D, bombe=bom, anneaux=anneaux)


def cuissots(P, t, r, st, cote, s, jambe, A, B, mat="obsidienne", dents=0, rangs=3):
    """Cuissots en lames qui se recouvrent (de la hanche au genou), puis la lame du genou : les cuisses ne sont plus nues."""
    th, ca = r.os["thigh_" + cote], r.os["calf_" + cote]
    pj = hd.proj_axe(th, ca, haut=DEVANT, r=0.3)
    cuisse = C.bvh(r, ["pantalon"], {"thigh_" + cote, "calf_" + cote, "pelvis"}, 0.3)
    arb = [hd.bvh_piece(P), cuisse]
    # lames de haut en bas : chacune recouvre un peu la suivante
    bornes = [(0.04, 0.40), (0.30, 0.66), (0.56, 0.92)][:rangs]
    for k, (t0, t1) in enumerate(bornes):
        _lame_membre(P, arb, pj, 78 - 6 * k, t0, t1, 0.012 + 0.005 * (rangs - 1 - k), 0.006, mat, dents=dents, g=90 + k + (3 if s < 0 else 0), anneaux=1, ang=2)
    # petits éclats / rivets : flancs de la cuisse
    if dents:
        arbre = hd.bvh_piece(P)
        for tt, L in ((0.25, 0.05), (0.55, 0.045)):
            o, d = pj(-92 * 1.0, tt)
            hit, n = hd.lancer([cuisse], o, d)
            if hit is not None:
                hd.eclat(P, hit, (-Vector(d) + HAUT * 0.4 + DOS * 0.2).normalized(), L, 0.013, 0.006, mat, UV_D, cote_w=HAUT)


def brassards(P, t, r, st, mat="obsidienne", dents=0, rangs=2):
    """Brassards d'avant-bras en lames qui se recouvrent, par-dessus la manchette (avant-bras entièrement couvert)."""
    for cote, s in (("l", 1.0), ("r", -1.0)):
        la, ha = r.os["lowerarm_" + cote], r.os["hand_" + cote]
        pj = hd.proj_axe(la, ha, haut=HAUT, r=0.2)
        arb = [hd.bvh_piece(P)]
        bornes = [(0.02, 0.50), (0.38, 0.86)][:rangs]
        for k, (t0, t1) in enumerate(bornes):
            _lame_membre(P, arb, pj, 100, t0, t1, 0.010 + 0.006 * (rangs - 1 - k), 0.005, mat, dents=dents, g=110 + k + (3 if s < 0 else 0))


def joues(P, t, r, centre, Pts, R_NAS, R_CORNE, mat="obsidienne", dents=0):
    """Paragnathides : plaques de joue qui encadrent le visage (ouverture libre devant), bord bas denté ou arrondi."""
    arb = [hd.bvh_piece(P), C.bvh(r, ["peau"], {"Head", "neck_01"}, 0.5)]
    for sg in (1, -1):
        bas = arete((100, 1.575), (66, 1.560), dents, 0.025, axe=1, signe=-1, g=120 + sg) if dents else [(82, 1.555)]
        c = [(58, 1.690), (84, 1.700), (108, 1.680), (114, 1.62)] + [(104, 1.575)] + bas + [(60, 1.60)]
        if sg < 0:
            c = miroir(c)
        hd.plaque(P, arb, PROJ_H, c, 0.011, 0.006, mat, UV_D, bombe=0.006, anneaux=2)


def jambes_or(P, t, r, st, cote, s, jambe, A, B):
    """Jambe d'or articulée : grève en 6 lames qui se recouvrent (pointe vers le bas) + 4 lames de mollet, genouillère bombée
    (dôme, arête, ailette latérale, rubis serti), sabaton en lames sur le pied ; la botte dessous est en cuir sombre (visible
    entre les lames)."""
    ca = r.os["calf_" + cote]
    sg = 1.0 if ca.x > 0 else -1.0
    # BVH de CETTE jambe seulement (les rayons latéraux ne doivent pas toucher la botte voisine)
    fs = [f for f in P.f if sum(P.v[i].x for i in f[0]) / len(f[0]) * sg > 0.0]
    arb = [BVHTree.FromPolygons([Vector(v) for v in P.v], [f[0] for f in fs], epsilon=0.0)]
    M = "or.patine"
    Ah = Vector((ca.x, ca.y - 0.005, 0.47)); Bb = Vector((ca.x, -0.02, 0.05))
    pj = hd.proj_axe(Ah, Bb, haut=DEVANT, r=0.3)
    n = 6
    for k in range(n):
        t0 = -0.04 + 0.15 * k; t1 = t0 + 0.215
        _lame_membre(P, arb, pj, 92 - 2.5 * k, t0, t1, 0.010 + 0.0036 * (n - 1 - k), 0.008, M, anneaux=2, ang=4, pointe=0.022)
    pjr = hd.proj_axe(Ah + Vector((0, 0.07, 0)), Bb + Vector((0, 0.07, 0)), haut=DEVANT, r=0.4)     # axe du mollet (la cuve de la botte est reculée)
    for k in range(4):
        t0 = 0.0 + 0.2 * k; t1 = t0 + 0.28
        _lame_membre(P, arb, pjr, 66 - 3 * k, t0, t1, 0.009 + 0.004 * (3 - k), 0.007, M, anneaux=2, ang=3, pointe=0.0, a0=180)
    # genouillère : dôme, arête médiane, ailette extérieure
    corps_k = C.bvh(r, ["pantalon"], {"thigh_" + cote, "calf_" + cote}, 0.3)
    # manchette d'or au haut de la botte : quatre lames qui en font le tour (sous la genouillère)
    for a0, pjx, a, h0 in ((0, pj, 50, -0.13), (88, pj, 42, -0.06), (-88, pj, 42, -0.06), (180, pjr, 52, -0.06)):
        kw = {"a0": a0} if a0 else {}
        _lame_membre(P, arb + [corps_k], pjx, a, h0, -0.01, 0.017, 0.006, M, anneaux=1, ang=3, **kw)
    Ak = Vector((ca.x, ca.y, ca.z - 0.10)); Bk = Vector((ca.x, ca.y, ca.z + 0.10))
    pk = hd.proj_axe(Ak, Bk, haut=DEVANT, r=0.3)
    c = [(0, 0.10), (30, 0.20), (50, 0.40), (52, 0.55), (36, 0.76), (0, 0.90), (-36, 0.76), (-52, 0.55), (-50, 0.40), (-30, 0.20)]
    arb = arb + [corps_k]
    hd.plaque(P, arb, pk, c, 0.020, 0.010, M, UV_D, bombe=0.026, anneaux=3, biseau=1.0)
    corps_k = C.bvh(r, ["pantalon"], {"thigh_" + cote, "calf_" + cote}, 0.3)
    fs = [f for f in P.f if sum(P.v[i].x for i in f[0]) / len(f[0]) * sg > 0.0]
    arb2 = [BVHTree.FromPolygons([Vector(v) for v in P.v], [f[0] for f in fs], epsilon=0.0), corps_k]
    c = [(0, 0.20), (14, 0.42), (0, 0.80), (-14, 0.42)]
    hd.plaque(P, arb2, pk, c, 0.012, 0.006, M, UV_D, bombe=0.012, anneaux=2)
    c = [(66, 0.30), (92, 0.40), (96, 0.55), (92, 0.70), (66, 0.78), (60, 0.55)]
    hd.plaque(P, arb, pk, c, 0.016, 0.008, M, UV_D, bombe=0.012, anneaux=2)
    if cote == "l":
        c = [(-66, 0.30), (-92, 0.40), (-96, 0.55), (-92, 0.70), (-66, 0.78), (-60, 0.55)]
    else:
        c = [(-66, 0.30), (-92, 0.40), (-96, 0.55), (-92, 0.70), (-66, 0.78), (-60, 0.55)]
    hd.plaque(P, arb, pk, c, 0.016, 0.008, M, UV_D, bombe=0.012, anneaux=2)
    # jarretière d'or au-dessus du genou (bande fine qui fait tout le tour de la cuisse, par-dessus les lames du cuissot)
    th = r.os["thigh_" + cote]
    cuisse_b = C.bvh(r, ["pantalon"], {"thigh_" + cote, "calf_" + cote}, 0.3)
    arb_j = [BVHTree.FromPolygons([Vector(v) for v in P.v], [f[0] for f in fs], epsilon=0.0), cuisse_b]
    anneaux_j = []
    for zj in (0.646, 0.626):
        f_ = (th.z - zj) / (th.z - ca.z)
        ax = th.lerp(ca, f_)
        row = []
        for i in range(24):
            an = TAU * (i + 0.5) / 24
            dj = Vector((math.cos(an), math.sin(an), 0.0))
            hit, nrm = hd.lancer(arb_j, Vector((ax.x, ax.y, zj)) + dj * 0.3, -dj)
            row.append((hit + dj * 0.009) if hit is not None else Vector((ax.x, ax.y, zj)) + dj * 0.10)
        anneaux_j.append([Vector((p.x, p.y, zj)) for p in row])
    P.grille(anneaux_j, M, (UV_D[0], UV_D[1], UV_D[2], UV_D[3]), fermer=True)
    # sabaton : trois lames qui enveloppent le devant du pied (dessus + côtés), la plus haute recouvre la suivante
    Af = Vector((ca.x, -0.07, 0.17)); Bf = Vector((ca.x, -0.07, -0.01))
    pf = hd.proj_axe(Af, Bf, haut=DEVANT, r=0.45)
    for k, (t0, t1) in enumerate(((0.02, 0.50), (0.38, 0.80), (0.66, 1.02))):
        _lame_membre(P, arb, pf, 84 - 3 * k, t0, t1, 0.008 + 0.004 * (2 - k), 0.007, M, anneaux=2, ang=4, pointe=0.0)


# ============================================================================================================== styles
OBS = dict(pal=C.FER_NOIR, mat="obsidienne", mat_rebord="fer.noir", mat_main="obsidienne", mat_doigts="fer.noir", mat_genou="obsidienne",
           mat_maille="fer.maille", base=0.4, oxyde=0.0, crasse=0.3, poli=0.6, graine=131, z_ourlet=0.66)
OR = dict(pal=C.ACIER, mat="or.patine", mat_rebord="or.patine", mat_main="or.patine", mat_doigts="or.patine", mat_genou="or.patine",
          mat_maille="tissu.bleu", base=0.34, oxyde=0.0, crasse=0.2, poli=0.6, graine=151, z_ourlet=0.66)
NIV_BOTTES = [-0.02, 0.01, 0.04, 0.08, 0.13, 0.19, 0.26, 0.33, 0.40, 0.46, 0.50]

PIECES = {
    "casque_obsidienne": lambda r: PC.casque(r, _s(OBS, id="casque_obsidienne", n=30, bas=(0.03, -0.40, -0.62), bombe=0.016, ecart=0.019,
                                                   bandes=0, rebord=0.009,
                                                   decor=[lambda *a: visiere(*a, mat="obsidienne", crete=0.016), cornes_obsidienne, lambda *a: joues(*a, mat="obsidienne", dents=2),
                                                          lambda *a: quille(*a, mat="obsidienne", h=0.010, dents=True)])),
    "cuirasse_obsidienne": lambda r: PC.cuirasse(r, _s(OBS, id="cuirasse_obsidienne", mat="fer.noir", n=14, lames=3, bombe=0.02,
                                                       lames_epaule=0, x_manche=0.418, decor=[obs_torse])),
    "gantelets_obsidienne": lambda r: PC.gantelets(r, _s(OBS, id="gantelets_obsidienne", evasement=0.038, griffes=0.011, debut_manchette=0.16,
                                                         mat_griffes="obsidienne",
                                                         decor=[manchettes_eclats, lambda *a: plaques_mains(*a, mat="obsidienne", dents=2), lambda P_, t_, r_, st_: brassards(P_, t_, r_, st_, "obsidienne", dents=3)])),
    "bottes_obsidienne": lambda r: PC.bottes(r, _s(OBS, id="bottes_obsidienne", mat_botte="obsidienne", niveaux=NIV_BOTTES,
                                                   decor=[genou_eclats, lambda *a: cuissots(*a, mat="obsidienne", dents=2, rangs=2)])),
    "casque_or": lambda r: PC.casque(r, _s(OR, id="casque_or", n=30, bas=(0.03, -0.40, -0.60), bombe=0.004, ecart=0.019, bandes=0,
                                           rebord=0.008,
                                           decor=[lambda *a: visiere(*a, mat="or.patine", crete=0.012), couronne, nasal, bavolet, lambda *a: joues(*a, mat="or.patine")])),
    "cuirasse_or": lambda r: PC.cuirasse(r, _s(OR, id="cuirasse_or", n=14, lames=4, bombe=0.02, lames_epaule=0, x_manche=0.418, decor=[or_torse])),
    "gantelets_or": lambda r: PC.gantelets(r, _s(OR, id="gantelets_or", evasement=0.042, debut_manchette=0.16,
                                                   decor=[plaques_mains, lambda P_, t_, r_, st_: brassards(P_, t_, r_, st_, "or.patine", rangs=2)])),
    "bottes_or": lambda r: PC.bottes(r, _s(OR, id="bottes_or", mat_botte="cuir", niveaux=NIV_BOTTES, greve=False,
                                           decor=[jambes_or, lambda *a: cuissots(*a, mat="or.patine", dents=0, rangs=3)])),
}
ENSEMBLE = {pid: ("obsidienne" if pid.endswith("obsidienne") else "or") for pid in PIECES}
VARIANTE = {"obsidienne": {"obsidienne": "obsidienne.enchante"}, "or": {"tissu.bleu": "tissu.enchante", "tissu.cape": "tissu.enchante", "tissu.tabard": "tissu.enchante", "tissu.doublure": "tissu.enchante", "gemme": "gemme.enchante"}}


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
        # pose au sol : sans les cuissots (au-dessus du genou)
        import bmesh
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > 0.52], context="FACES")
        bm.to_mesh(me); bm.free()
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.05
    # NEIGE : le shader ps1 pose la neige du monde sur les faces tournées vers le haut si l'alpha de la couleur de sommet >= 0,5 :
    # pièce posée à plat = alpha 0 (sols sans neige)
    ca = me.color_attributes.get("Col")
    if ca is not None:
        for d in ca.data:
            d.color = (d.color[0], d.color[1], d.color[2], 0.0)
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = list(me.color_attributes).index(ca)
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
def evaser_manches(ob, r, x0=0.36, x1=0.437, plus=0.024):
    """Bout des manches de la cotte évasé (+2,4 cm au bord) : la manche du héros qui en sort (|x| > 0,415) ne la traverse plus
    quand le coude plie (défaut hérité des cuirasses de l'agent Y : 20 mm dans Sort_Jet2M / combo, aussi sur l'acier nordique)."""
    for v in ob.data.vertices:
        p = v.co
        ax = abs(p.x)
        if ax < x0 or ax > x1 + 0.01 or p.z < 1.3:
            continue
        cote = "l" if p.x > 0 else "r"
        a, b = r.os["upperarm_" + cote], r.os["lowerarm_" + cote]
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        c = a + ab * t
        d = p - c
        d = d - ab.normalized() * d.dot(ab.normalized())
        if d.length < 1e-5:
            continue
        k = min(1.0, (ax - x0) / (x1 - x0)) ** 2
        v.co = p + d.normalized() * plus * k


def or_en_premier(ob):
    """Le matériau d'or devient la surface 0 : les limites de masquage du jeu (armure_visible.limites) sont lues sur la surface 0,
    qui doit contenir les plaques de la jambe (pas seulement la cuve de botte en cuir)."""
    mats = list(ob.data.materials)
    k = [i for i, m in enumerate(mats) if m and m.name.startswith("or.")]
    if not k or k[0] == 0:
        return
    ordre = [k[0]] + [i for i in range(len(mats)) if i != k[0]]
    nouveau = {ancien: n for n, ancien in enumerate(ordre)}
    for p in ob.data.polygons:
        p.material_index = nouveau[p.material_index]
    ob.data.materials.clear()
    for i in ordre:
        ob.data.materials.append(mats[i])


def construire(pid, dossier=None, enchante=True):
    r = C.charger_reference()
    ob = PIECES[pid](r)
    if pid == "bottes_or":
        or_en_premier(ob)
    if pid == "cuirasse_or":
        peau_cape(ob, r)
    tris = C.compter_tris(ob)
    print("PIECE", pid, tris, "tris", "matériaux", [m.name for m in ob.data.materials])
    hd.uv_uniques(ob)
    tab, _ = hd.cuire(ob, TAILLE_OR if ENSEMBLE[pid] == "or" else TAILLE, peintre(pid, False), bord_rim=ENSEMBLE[pid] == "or")
    img = hd.image(pid, tab, TEXTURES)
    tab_e = None
    if enchante:
        tab_e, _ = hd.cuire(ob, TAILLE_OR if ENSEMBLE[pid] == "or" else TAILLE, peintre(pid, True), bord_rim=ENSEMBLE[pid] == "or")
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
