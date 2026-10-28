# C1 matières (2026-10-28, chantier « anti pâte à modeler », docs INSPIRATION_IGNITE §6 règle 1) : ARÊTE CLAIRE / CREUX SOMBRE
# en couleur de sommet, pour les modules Blender de la crypte et de la grotte (objets_donjon.py, crypte_modules_v2.py, et les lots
# C2-C8 dans leurs propres modules).
#
# Entrée / sortie = la sortie de Module.finir() de ces scripts : { matière: [((a, b, c), (col_a, col_b, col_c)), ...] }, sommets en
# repère Godot (y en haut, sol à y = 0), couleurs (r, g, b, a). La classe Module est recopiée dans chaque script : ce module ne dépend
# QUE de ce format (aucun bpy) et s'appelle juste après finir() :
#     import aretes ;  res = aretes.appliquer(M.finir())
#
# Règle (ce que la torche doit accrocher, comme chez Ignite) :
#   - arête VIVE CONVEXE (angle entre faces >= ANGLE_MIN) : liseré plus clair de LARGEUR m sur chaque face qui la borde ; +1 ton
#     (x GAIN_HAUT) si l'une des deux faces regarde vers le haut (arête haute, celle que la lumière d'en haut et la torche prennent),
#     x GAIN ailleurs (arêtes verticales) ; x BAS (plus sombre) sur les arêtes basses (dessous) ; rien au ras du sol ;
#   - arête vive CONCAVE (creux entre deux faces d'un même bloc) : liseré plus sombre (x CREUX) ;
#   - bord libre (face simple : pièces, plaques, disques) : traité comme une arête convexe ;
#   - face ÉTROITE (chanfrein, cerclage, rivet, tranche de pièce : hauteur < ETROIT x LARGEUR) : toute la face prend le ton de l'arête
#     (c'est elle, l'arête) ; la grande face voisine n'a alors pas de liseré en plus (pas de double trait) mais son cœur baisse (FOND) ;
#   - cœur des faces bordées x FOND : plafond de la couleur 8 bits (voir FOND).
# Le liseré est fait en GÉOMÉTRIE (la couleur de sommet s'interpole sur tout le triangle : éclaircir les coins d'une grande face
# l'éclaircirait en entier) : la face est découpée en un triangle intérieur (couleurs d'origine) et une bande par arête marquée
# (2 triangles), dégradé de l'arête vers l'intérieur sur LARGEUR. Coût : 1 triangle -> 3 à 7, seulement sur les faces larges à arête vive
# (option `bandes` : par défaut seulement les arêtes HAUTES ; « aucune » pour les grands modules de structure, déjà chanfreinés).
import math
from mathutils import Vector

LARGEUR = 0.024          # m : ~2 px du rendu 640x360 à 2 m
ANGLE_MIN = 32.0         # degrés entre normales
GAIN_HAUT = 1.4         # ≈ +1 ton des rampes (Pierre #565b72 -> #787d8e, Bois #6a4229 -> #92613a)
GAIN = 1.18
FOND = 0.8               # intérieur des faces bordées : la couleur de sommet est stockée en 8 bits (plafond 1,0) et les tons de
                         # pierre montent déjà à 0,9-1,0 ; l'écart d'un ton se fait donc AUSSI en baissant un peu le cœur de la face
CREUX = 0.7
BAS = 0.72               # arête basse (une face regarde vers le bas) : un ton plus sombre (BIBLE_VISUELLE §4.6, petits biseaux)
ETROIT = 1.7             # une face plus étroite que ETROIT x LARGEUR est une arête à elle seule
SOL = 0.02               # m : arêtes au ras du sol ignorées (pied sombre)
SANS = ("noir", "pts")   # matières laissées telles quelles
SOUDURE = 2000.0         # 1 / taille de la grille de soudure des sommets (0,5 mm)


def _cle(v):
    return (round(v[0] * SOUDURE), round(v[1] * SOUDURE), round(v[2] * SOUDURE))


def _melange(c, f):
    return (min(1.0, c[0] * f), min(1.0, c[1] * f), min(1.0, c[2] * f), c[3])


def _bary(p, a, b, c, ca, cb, cc):
    """Couleur interpolée en p (dans le plan du triangle a b c)."""
    v0, v1, v2 = b - a, c - a, p - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-18:
        return ca
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    u = 1.0 - v - w
    return tuple(ca[i] * u + cb[i] * v + cc[i] * w for i in range(4))


def _inter(p0, d0, p1, d1, n):
    """Intersection des droites p0 + t d0 et p1 + s d1 (même plan, normale n)."""
    den = d0.cross(d1).dot(n)
    if abs(den) < 1e-12:
        return None
    t = (p1 - p0).cross(d1).dot(n) / den
    return p0 + d0 * t


def appliquer(sortie, largeur=LARGEUR, angle_min=ANGLE_MIN, gain_haut=GAIN_HAUT, gain=GAIN, creux=CREUX, fond=FOND, bas=BAS, bandes="hautes", stats=None):
    """bandes : « toutes » (liseré géométrique sur chaque arête marquée), « hautes » (seulement les arêtes hautes : le reste passe par
    les faces étroites), « aucune » (zéro triangle de plus : faces étroites et cœurs assombris seulement — modules de structure, où
    les blocs sont déjà chanfreinés). Mesure perf du lot C1 : les liserés partout coûtaient +0,6 à +1,1 ms GPU dans la crypte."""
    tris = []            # (matière, [a, b, c] Vector, [cols], normale, centre, aire, hauteur min)
    for m, faces in sortie.items():
        for p, cols in faces:
            a, b, c = Vector(p[0]), Vector(p[1]), Vector(p[2])
            n = (b - a).cross(c - a)
            aire2 = n.length
            if aire2 < 1e-14:
                tris.append((m, [a, b, c], list(cols), Vector((0, 1, 0)), (a + b + c) / 3, 0.0, 0.0))
                continue
            n = n / aire2
            longest = max((b - a).length, (c - b).length, (a - c).length)
            tris.append((m, [a, b, c], list(cols), n, (a + b + c) / 3, aire2 * 0.5, aire2 / max(longest, 1e-9)))
    # arêtes soudées -> triangles qui les portent
    aretes = {}
    for t, (m, P, _, _, _, aire, _) in enumerate(tris):
        if aire <= 0.0:
            continue
        for i in range(3):
            ka, kb = _cle(P[i]), _cle(P[(i + 1) % 3])
            if ka == kb:
                continue
            aretes.setdefault((ka, kb) if ka < kb else (kb, ka), []).append(t)
    cos_min = math.cos(math.radians(angle_min))
    etroit = ETROIT * largeur
    res = {}
    n_av, n_ap = 0, 0
    for t, (m, P, C, n, ctr, aire, haut) in enumerate(tris):
        n_av += 1
        if m in SANS or aire <= 0.0:
            res.setdefault(m, []).append((tuple(P), tuple(C)))
            n_ap += 1
            continue
        fac = [1.0, 1.0, 1.0]        # facteur de chaque arête i = (P[i], P[i+1])
        chanfrein = False
        for i in range(3):
            a, b = P[i], P[(i + 1) % 3]
            if a.y < SOL and b.y < SOL:
                continue
            ka, kb = _cle(a), _cle(b)
            voisins = [u for u in aretes.get((ka, kb) if ka < kb else (kb, ka), []) if u != t]
            mil = (a + b) * 0.5
            if not voisins:
                if n.y > -0.3:       # bord libre (pas de dessous)
                    fac[i] = gain_haut if n.y > 0.5 else gain
                continue
            # voisin le plus « cassé » (plusieurs faces sur une arête : primitives jointives)
            u = min(voisins, key=lambda k: tris[k][3].dot(n))
            nu = tris[u][3]
            if nu.dot(n) > cos_min:
                continue
            convexe = n.dot(tris[u][4] - mil) < 0.0
            if convexe:
                if n.y < -0.5 or nu.y < -0.5:
                    fac[i] = bas     # arête basse : un ton plus sombre
                    continue
                if haut > etroit and tris[u][6] <= etroit:
                    chanfrein = True
                    continue         # la face voisine est un chanfrein : c'est lui qui porte le liseré
                fac[i] = gain_haut if (n.y > 0.5 or nu.y > 0.5) else gain
            else:
                fac[i] = creux
        if fac == [1.0, 1.0, 1.0]:
            res.setdefault(m, []).append((tuple(P), tuple(_melange(c, fond) for c in C) if chanfrein else tuple(C)))
            n_ap += 1
            continue
        if bandes != "toutes" and haut > etroit:      # liserés géométriques limités (perf)
            fac = [f if (bandes == "hautes" and f == gain_haut) else 1.0 for f in fac]
            if fac == [1.0, 1.0, 1.0]:
                res.setdefault(m, []).append((tuple(P), tuple(_melange(c, fond) for c in C) if chanfrein else tuple(C)))
                n_ap += 1
                continue
        if haut <= etroit:           # face étroite : elle est l'arête
            f = max(fac) if max(fac) > 1.0 else min(fac)
            res.setdefault(m, []).append((tuple(P), tuple(_melange(c, f) for c in C)))
            n_ap += 1
            continue
        # triangle intérieur : droites des arêtes marquées décalées de `largeur` vers l'intérieur
        lignes = []
        for i in range(3):
            a, b = P[i], P[(i + 1) % 3]
            d = (b - a).normalized()
            dedans = n.cross(d)          # vers l'intérieur (sens trigonométrique vu de la normale)
            if dedans.dot(ctr - a) < 0:
                dedans = -dedans
            lignes.append((a + dedans * (largeur if fac[i] != 1.0 else 0.0), d))
        Q = []
        for i in range(3):
            l0, l1 = lignes[(i - 1) % 3], lignes[i]
            q = _inter(l0[0], l0[1], l1[0], l1[1], n)
            Q.append(q)
        ok = all(q is not None for q in Q)
        if ok:
            nq = (Q[1] - Q[0]).cross(Q[2] - Q[0])
            ok = nq.dot(n) > 1e-10 and all(q is not None and (q - ctr).length < 2.0 * max((p - ctr).length for p in P) for q in Q)
        if not ok:                   # trop petit pour une bande : toute la face prend le ton
            f = max(fac) if max(fac) > 1.0 else min(fac)
            res.setdefault(m, []).append((tuple(P), tuple(_melange(c, f) for c in C)))
            n_ap += 1
            continue
        CQ = [_melange(_bary(q, P[0], P[1], P[2], C[0], C[1], C[2]), fond) for q in Q]
        sor = res.setdefault(m, [])
        sor.append((tuple(Q), tuple(CQ)))
        n_ap += 1
        for i in range(3):
            if fac[i] == 1.0:
                continue
            j = (i + 1) % 3
            ci, cj = _melange(C[i], fac[i]), _melange(C[j], fac[i])
            sor.append(((P[i], P[j], Q[j]), (ci, cj, CQ[j])))
            sor.append(((P[i], Q[j], Q[i]), (ci, CQ[j], CQ[i])))
            n_ap += 2
    if stats is not None:
        stats["avant"] = stats.get("avant", 0) + n_av
        stats["apres"] = stats.get("apres", 0) + n_ap
    return res
