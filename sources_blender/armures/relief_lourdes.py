# (Intégration n°3 : ex-relief.py de la branche armures_affinage/lourdes, renommé à côté de relief_precieuses.py.)
# RELIEF géométrique des armures (passe 2 « géométrie », 2026-11-11) : ce qui était seulement peint devient du volume.
#  - border(ob) : chaque bord libre d'une plaque de métal reçoit une BORDURE ROULÉE (bourrelet vers l'extérieur puis tranche qui
#    rentre vers le corps) : la tôle a une épaisseur visible, l'arête accroche la lumière comme sur les armures Tripo ;
#  - rivets(ob) : têtes de rivets en relief (pyramide à 4 pans, 4 tris) le long des bords, à quelques mm à l'intérieur ;
#  - les nouveaux sommets copient la PEAU D'OS du sommet de bord dont ils naissent (démembrement / ArmureVisible inchangés) et toutes
#    les couches de boucle (UV, UV sémantiques, couleurs) de la boucle source : texture et cuisson continuent de fonctionner.
# Appelé par fer_acier/generer_hd.py et obsidienne_or/generer.py après retreindre (avant la cuisson pour l'obsidienne/or).
import bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

METAUX = ("acier", "fer", "obsidienne", "or")
EXCLUS = ("maille", "chaine", "lion", "gemme")


def est_metal(nom):
    n = nom.lower()
    return any(n.startswith(m) for m in METAUX) and not any(x in n for x in EXCLUS)


def _copier_boucles(bm, f_new, src_loops):
    """src_loops : boucle source pour chaque sommet de f_new (même ordre)."""
    for lay in (bm.loops.layers.uv, bm.loops.layers.float_color, bm.loops.layers.color):
        for k in lay.keys():
            L = lay[k]
            for ln, ls in zip(f_new.loops, src_loops):
                if ls is None:
                    continue
                if lay is bm.loops.layers.uv:
                    ln[L].uv = ls[L].uv.copy()
                else:
                    ln[L] = ls[L].copy() if hasattr(ls[L], "copy") else ls[L]


def _composantes_faces(bm, faces):
    vu, comps = set(), []
    fs = set(faces)
    for f in faces:
        if f in vu:
            continue
        pile, comp = [f], []
        vu.add(f)
        while pile:
            x = pile.pop(); comp.append(x)
            for e in x.edges:
                for y in e.link_faces:
                    if y in fs and y not in vu:
                        vu.add(y); pile.append(y)
        comps.append(comp)
    return comps


def relief(ob, lip=0.0, ep=0.0055, sortie=0.0025, min_tris=10, rivet_pas=0.045, rivet_r=0.0042, rivet_h=0.0034,
           rivet_retrait=0.0085, rivet_min_tris=24, rivets=True, filtre=None, verbeux=True, max_rivets=70, bords_on=True, deja_epais=0.55, couvert=0.035, min_tris_bord=None):
    """filtre(centre_monde, nom_mat) -> bool : bords à traiter (None = tous les métaux)."""
    me = ob.data
    mats = [m.name if m else "" for m in me.materials]
    metal_idx = {i for i, n in enumerate(mats) if est_metal(n)}
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    bm.normal_update()
    faces_m = [f for f in bm.faces if f.material_index in metal_idx]
    tris0 = sum(len(f.verts) - 2 for f in bm.faces)
    ok_face = set()
    paroi = set()
    for comp in _composantes_faces(bm, faces_m):
        if sum(len(f.verts) - 2 for f in comp) >= min_tris:
            ok_face.update(comp)
            # plaque DÉJÀ épaisse (hd.plaque : tranche modélisée) : la face du bord libre est une paroi presque perpendiculaire à
            # la plaque -> pas de seconde tranche
            nm, aire = Vector(), 0.0
            for f in comp:
                nm += f.normal * f.calc_area(); aire += f.calc_area()
            if aire > 0 and nm.length / aire > 0.6:
                nm.normalize()
                for f in comp:
                    if abs(f.normal.dot(nm)) < deja_epais and len(comp) > 8:
                        paroi.add(f)
    # bords libres des plaques retenues ; un bord RECOUVERT (une autre plaque juste au-dessus, lame d'en dessous, plaque sous la
    # fourrure) n'est pas vu : pas de tranche
    arbre = BVHTree.FromBMesh(bm)
    comp_de = {}
    for k, comp in enumerate(_composantes_faces(bm, list(bm.faces))):
        for f in comp:
            comp_de[f.index] = (k, len(comp))
    bords = []
    for e in bm.edges:
        if len(e.link_faces) != 1:
            continue
        f = e.link_faces[0]
        if f not in ok_face or f in paroi:
            continue
        if min_tris_bord and comp_de[f.index][1] < min_tris_bord:
            continue
        if couvert > 0:
            m = (e.verts[0].co + e.verts[1].co) / 2
            h = arbre.ray_cast(m + f.normal * 0.002, f.normal, couvert)
            if h[0] is not None and comp_de.get(h[2], (-1,))[0] != comp_de[f.index][0]:
                continue
        if filtre is not None and not filtre(ob.matrix_world @ ((e.verts[0].co + e.verts[1].co) / 2), mats[f.material_index]):
            continue
        bords.append((e, f))
    if not bords:
        bm.free(); return 0
    # par sommet de bord : normale de surface, direction « hors de la plaque » dans son plan
    nrm, sor, src = {}, {}, {}
    for e, f in bords:
        a, b = e.verts
        mid = (a.co + b.co) / 2
        t = (b.co - a.co).normalized()
        d = mid - f.calc_center_median()
        d = (d - t * d.dot(t))
        n = f.normal
        d = (d - n * d.dot(n))
        if d.length < 1e-9:
            continue
        d.normalize()
        for v in (a, b):
            sor[v] = sor.get(v, Vector()) + d
    for v in sor:
        n = Vector()
        for f in v.link_faces:
            if f in ok_face:
                n += f.normal
        nrm[v] = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
        o = sor[v]
        o = o - nrm[v] * o.dot(nrm[v])
        sor[v] = o.normalized() if o.length > 1e-9 else Vector()
    boucle = {}
    for e, f in bords:
        for l in f.loops:
            boucle[(f, l.vert)] = l
    r1, r2 = {}, {}
    for v in (sor if bords_on else []):
        n, o = nrm[v], sor[v]
        if lip > 0:
            r1[v] = bm.verts.new(v.co + n * lip + o * sortie, v)
        r2[v] = bm.verts.new(v.co - n * ep + o * sortie, v)
    nf = 0
    for e, f in (bords if bords_on else []):
        a, b = e.verts
        if a not in r2 or b not in r2:
            continue
        la, lb = boucle[(f, a)], boucle[(f, b)]
        # orientation : la face de bord regarde « hors de la plaque » (même sens d'enroulement que la face source)
        if la.link_loop_next.vert is b:
            s1 = s2 = [lb, la, la, lb]
            q1 = [b, a, r1[a], r1[b]] if lip > 0 else None
            q2 = [r1[b], r1[a], r2[a], r2[b]] if lip > 0 else None
        else:
            s1 = s2 = [la, lb, lb, la]
            q1 = [a, b, r1[b], r1[a]] if lip > 0 else None
            q2 = [r1[a], r1[b], r2[b], r2[a]] if lip > 0 else None
        if lip <= 0:
            # une seule tranche : du bord droit vers l'intérieur (2 tris)
            if la.link_loop_next.vert is b:
                q2 = [b, a, r2[a], r2[b]]
            else:
                q2 = [a, b, r2[b], r2[a]]
            todo = ((q2, s2),)
        else:
            todo = ((q1, s1), (q2, s2))
        for q, s in todo:
            try:
                fn = bm.faces.new(q, f)
            except ValueError:
                continue
            _copier_boucles(bm, fn, s)
            fn.smooth = False
            nf += 1
    # rivets le long des bords (plaques assez grandes)
    nr = 0
    if rivets and rivet_pas > 0 and max_rivets > 0:
        grandes = set()
        for comp in _composantes_faces(bm, [f for f in ok_face]):
            if sum(len(f.verts) - 2 for f in comp) >= rivet_min_tris:
                grandes.update(comp)
        cumul = {}
        tot = sum((e.verts[1].co - e.verts[0].co).length for e, f in bords if f in grandes)
        rivet_pas = max(rivet_pas, tot / max(1, max_rivets))
        for e, f in bords:
            if f not in grandes:
                continue
            a, b = e.verts
            if a not in sor or b not in sor:
                continue
            L = (b.co - a.co).length
            c = cumul.get("g", 0.0) + L
            nb = int(c // rivet_pas)
            cumul["g"] = c - nb * rivet_pas
            for k in range(nb):
                t = (k + 0.5) / max(nb, 1)
                p = a.co.lerp(b.co, t)
                n = nrm[a].lerp(nrm[b], t).normalized()
                o = sor[a].lerp(sor[b], t)
                if o.length < 1e-9:
                    continue
                o.normalize()
                c0 = p - o * rivet_retrait
                tg = (b.co - a.co).normalized()
                bi = n.cross(tg)
                lb = boucle[(f, a)]
                base = [bm.verts.new(c0 + (tg * math.cos(an) + bi * math.sin(an)) * rivet_r + n * 0.0006, a)
                        for an in (0.5 * math.pi, 1.1667 * math.pi, 1.8333 * math.pi)]
                som = bm.verts.new(c0 + n * rivet_h, a)
                for i in range(3):
                    tri = [base[i], base[(i + 1) % 3], som]
                    try:
                        fn = bm.faces.new(tri, f)
                    except ValueError:
                        continue
                    # tri orienté vers l'extérieur
                    fn.normal_update()
                    if fn.normal.dot(n) < 0:
                        fn.normal_flip()
                    _copier_boucles(bm, fn, [lb, lb, lb])
                    fn.smooth = False
                nr += 1
    bm.to_mesh(me); bm.free(); me.update()
    tris1 = sum(len(p.vertices) - 2 for p in me.polygons)
    if verbeux:
        print("RELIEF", ob.name, "bords", len(bords), "faces bord", nf, "rivets", nr, "tris", tris0, "->", tris1)
    return tris1 - tris0
