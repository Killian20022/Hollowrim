"""RESSERRER une pièce d'armure sur le corps du héros (affinage 2026-11-11 : « certaines armures sont trop épaisses »).

Chaque sommet est rapproché du corps habillé (peau, tunique, pantalon, bottes, brassards, pose de repos) le long de la direction
corps -> sommet : un décollement d devient a + b (d - a) (a = jeu minimal gardé, b = taux de compression), au-delà de dmax le
décalage reste constant (les ornements suivent leur plaque sans être écrasés). La fonction est monotone : les plaques empilées gardent
leur ordre (pas de nouvelle traversée entre couches) et leur épaisseur est multipliée par b.
  - le champ de décalage est lissé sur les arêtes (pas de pli) ;
  - les PETITES îles (gemmes, éclats, rivets rapportés : diagonale < 0,20 m) bougent d'un bloc, du décalage moyen des sommets de coque
    les plus proches : leur forme est intacte ;
  - parametres(p_godot, nom_materiau) -> (a, b) ou None (sommet laissé en place) : jeu et compression par zone et par matière (la
    fourrure du col garde son volume, les mains ne bougent pas...).
Les poids d'os, UV et matériaux ne changent pas ; les découpes de démembrement (calculées sur les poids) sont conservées."""
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
import armures_lib as L

_CORPS = None


def corps():
    global _CORPS
    if _CORPS is None:
        _CORPS = L.bvh_de((), ("peau", "tunique", "pantalon", "bottes", "brassards"))
    return _CORPS


def resserrer(ob, parametres, dmax=0.09, lissage=4, diag_ile=0.20, verbeux=True):
    me = ob.data
    mw = ob.matrix_world
    mwi = mw.inverted()
    n = len(me.vertices)
    W = [mw @ v.co for v in me.vertices]
    # matériau dominant de chaque sommet
    mat_v = [""] * n
    noms = [m.name if m else "" for m in me.materials]
    for p in me.polygons:
        nm = noms[p.material_index] if p.material_index < len(noms) else ""
        for vi in p.vertices:
            if not mat_v[vi]:
                mat_v[vi] = nm
    # îles
    parent = list(range(n))
    def trouve(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for e in me.edges:
        a, b = trouve(e.vertices[0]), trouve(e.vertices[1])
        if a != b:
            parent[a] = b
    iles = {}
    for i in range(n):
        iles.setdefault(trouve(i), []).append(i)
    petite = [False] * n
    for r, vs in iles.items():
        P = np.array([W[i] for i in vs])
        if np.linalg.norm(P.max(0) - P.min(0)) < diag_ile:
            for i in vs:
                petite[i] = True
    C = corps()
    disp = np.zeros((n, 3))
    actif = np.zeros(n, bool)
    avant = []
    for i in range(n):
        if petite[i]:
            continue
        pr = parametres(L.G(W[i]), mat_v[i])
        if pr is None:
            continue
        a, b = pr
        hit = C.find_nearest(W[i], 0.4)
        if hit[0] is None:
            continue
        d = hit[3]
        if d <= a or d < 1e-5:
            actif[i] = True
            continue
        u = (W[i] - hit[0]) / d
        dc = min(d, dmax)
        f = a + b * (dc - a) + (d - dc)
        disp[i] = np.array(u * (f - d))
        actif[i] = True
        avant.append(d)
    # lissage du champ sur les arêtes (sommets actifs seulement)
    voisins = [[] for _ in range(n)]
    for e in me.edges:
        i, j = e.vertices
        voisins[i].append(j); voisins[j].append(i)
    for _ in range(lissage):
        nd = disp.copy()
        for i in range(n):
            if not actif[i]:
                continue
            vs = [j for j in voisins[i] if actif[j]]
            if vs:
                nd[i] = 0.5 * disp[i] + 0.5 * disp[vs].mean(0)
        disp = nd
    # petites îles : bloc, décalage des sommets de coque voisins
    kd = KDTree(int(actif.sum()))
    idx = np.nonzero(actif)[0]
    for k, i in enumerate(idx):
        kd.insert(W[i], k)
    kd.balance()
    if len(idx):
        for r, vs in iles.items():
            if not petite[vs[0]]:
                continue
            c = sum((W[i] for i in vs), Vector()) / len(vs)
            pr = parametres(L.G(c), mat_v[vs[0]])
            if pr is None:
                continue
            proches = kd.find_n(c, 4)
            dm = np.mean([disp[idx[k]] for (_, k, _) in proches], 0)
            for i in vs:
                disp[i] = dm
    for i in range(n):
        if disp[i].any():
            me.vertices[i].co = mwi @ (W[i] + Vector(disp[i]))
    me.update()
    if verbeux and avant:
        a = np.array(avant) * 1000
        print("RESSERRER", ob.name, "sommets", len(avant), "decollement med %.1f p90 %.1f mm" % (np.median(a), np.percentile(a, 90)),
              "deplacement moyen %.1f mm" % (np.linalg.norm(disp, axis=1)[actif].mean() * 1000))
