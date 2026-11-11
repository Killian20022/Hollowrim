# RÉTREINDRE une pièce d'armure sur le corps (affinage 2026-11-11, retour utilisateur « certaines armures sont trop épaisses »).
# Chaque sommet est rapproché de la surface du corps de référence (peau + tenue de base du héros) selon une loi monotone du décollement d :
#     d' = d                                  si d <= m            (jeu minimal conservé)
#     d' = m + (d - m) * k                    si m < d <= D1       (le volume « vide » entre le corps et l'armure est comprimé)
#     d' = m + (D1 - m) * k + (d - D1)        si d > D1            (ce qui dépasse loin du corps — pointes, cornes, crêtes — garde
#                                                                    sa longueur : seule sa base recule)
# La MÊME loi pour toutes les pièces : l'ordre des couches (plaque du dessus / du dessous, cuirasse sur chausses, cuissots…) est
# conservé, donc pas de nouvelle traversée entre pièces au repos. Le déplacement est lissé à l'intérieur de chaque composante
# connexe (une plaque rigide recule d'un bloc, sans se tordre ; la tôle ne se froisse pas).
# Les mains (gantelets) ne sont pas touchées : le héros de référence n'a pas de mains modélisées.
import bpy, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

CORPS = ("peau", "tunique", "pantalon", "brassards", "bottes")
MAINS = ("hand", "index", "middle", "ring", "pinky", "thumb")


def arbre_corps(r):
    vs, fs = [], []
    for nom in CORPS:
        o = r.corps.get(nom)
        if o is None:
            continue
        b = len(vs)
        vs += [o.matrix_world @ v.co for v in o.data.vertices]
        fs += [[b + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(vs, fs)


def _composantes(me):
    par = list(range(len(me.vertices)))

    def rac(i):
        while par[i] != i:
            par[i] = par[par[i]]
            i = par[i]
        return i
    for e in me.edges:
        a, b = rac(e.vertices[0]), rac(e.vertices[1])
        if a != b:
            par[a] = b
    return [rac(i) for i in range(len(me.vertices))]


def loi(d, m, k, D1):
    if d <= m:
        return d
    if d <= D1:
        return m + (d - m) * k
    return m + (D1 - m) * k + (d - D1)


def retreindre(ob, r, m=0.012, k=0.6, D1=0.11, k_region=None, lissage=4, exclure_mat=(), verbeux=True, colle=0.012, seuil_support=0.08, taille_support=150):
    """k_region : {"epaules": 0.7, "tete": ...} ratio par région (os dominant) ; exclure_mat : préfixes de matériaux non touchés."""
    arbre = arbre_corps(r)
    me = ob.data
    mw = ob.matrix_world
    mi = mw.inverted()
    noms = {g.index: g.name for g in ob.vertex_groups}
    exclus = set()
    if exclure_mat:
        idx = {i for i, mt in enumerate(me.materials) if mt and any(mt.name.startswith(x) for x in exclure_mat)}
        for p in me.polygons:
            if p.material_index in idx:
                exclus.update(p.vertices)
    n = len(me.vertices)
    dep = [Vector() for _ in range(n)]
    poids = [0.0] * n
    stats = []
    for v in me.vertices:
        if v.index in exclus:
            continue
        reg = "torse"
        if v.groups:
            gm = max(v.groups, key=lambda g: g.weight)
            nm = noms[gm.group].lower()
            if any(nm.startswith(x) for x in MAINS):
                continue
            p_ = mw @ v.co
            if nm.startswith("head") or nm.startswith("neck"):
                reg = "tete"
            elif nm.startswith("upperarm") or nm.startswith("clavicle"):
                reg = "epaules" if p_.z > 1.33 else "bras"
            elif nm.startswith("lowerarm"):
                reg = "bras"
            elif nm.startswith("thigh"):
                reg = "cuisses"
            elif nm.startswith("calf"):
                reg = "tibias"
            elif nm.startswith("foot") or nm.startswith("ball"):
                reg = "pieds"
        p = mw @ v.co
        loc, nrm, _, d = arbre.find_nearest(p)
        if loc is None or d < 1e-5:
            continue
        dirn = (p - loc) / d
        if nrm is not None and dirn.dot(nrm) < -0.2:
            continue          # sommet sous la surface de la tenue : laissé tel quel
        kk = (k_region or {}).get(reg, k)
        d2 = loi(d, m, kk, D1)
        dep[v.index] = dirn * (d2 - d)
        poids[v.index] = 1.0
        stats.append(d - d2)
    # lissage du déplacement dans chaque composante connexe (plaque rigide = bloc)
    voisins = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        voisins[a].append(b); voisins[b].append(a)
    for _ in range(lissage):
        nouv = [Vector(x) for x in dep]
        for i in range(n):
            if poids[i] == 0.0 or not voisins[i]:
                continue
            acc = Vector(dep[i]); c = 1
            for j in voisins[i]:
                if poids[j] > 0.0:
                    acc += dep[j]; c += 1
            nouv[i] = acc / c
        dep = nouv
    # ACCESSOIRES POSÉS (sangles, rivets, disques, boucles, petites plaques) : une petite composante qui repose sur une autre
    # (à moins de `colle` de sa surface) suit le déplacement de son support au lieu du sien : elle reste collée, sans s'enfoncer.
    comp = _composantes(me)
    taille = {}
    for c in comp:
        taille[c] = taille.get(c, 0) + 1
    gros = max(taille.values()) if taille else 0
    W = [mw @ v.co for v in me.vertices]
    for _ in range(2):
        supports = [i for i in range(n) if taille[comp[i]] >= max(taille_support, gros * seuil_support)]
        petits = {}
        for i in range(n):
            if taille[comp[i]] < max(taille_support, gros * seuil_support):
                petits.setdefault(comp[i], []).append(i)
        if not petits or not supports:
            break
        kd = KDTree(len(supports))
        for j, i in enumerate(supports):
            kd.insert(W[i], j)
        kd.balance()
        for c, ids in petits.items():
            proches = [kd.find(W[i]) for i in ids]
            dmin = min(p[2] for p in proches)
            if dmin > colle:
                continue
            for i, (co, j, dd) in zip(ids, proches):
                dep[i] = Vector(dep[supports[j]])
                poids[i] = 1.0
        break
    for v in me.vertices:
        if poids[v.index] > 0.0:
            v.co = mi @ ((mw @ v.co) + dep[v.index])
    me.update()
    if verbeux and stats:
        stats.sort()
        print("RETREINDRE %s : %d sommets, recul moyen %.1f mm, max %.1f mm" % (ob.name, len(stats), 1000 * sum(stats) / len(stats), 1000 * stats[-1]))
    return ob
