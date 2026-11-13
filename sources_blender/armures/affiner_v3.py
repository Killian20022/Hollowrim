# AFFINAGE v3 des armures lourdes (branche armures/lourdes_hd_v3, 2026-11-12 ; demande : « plus de détails et surtout plus fines,
# raffine les lignes ; avec 8 000 à 10 000 triangles ça peut être incroyable »). Appelé par fer_acier/generer_hd.construire et
# obsidienne_or/generer.construire, AVANT retreindre (la loi de rétreinte garde ensuite le jeu minimal au corps).
#  - subdiviser_plaques : les grandes plaques de métal les plus grossières (aire / triangle la plus forte) sont subdivisées en
#    INTERPOLANT (bmesh subdivide_edges, smooth=1 : les sommets d'origine ne bougent pas, les nouveaux suivent la courbure) : la
#    coque perd ses facettes (reflets continus sur le casque, les canons, les dômes d'épaule) sans rétrécir ni traverser ; les
#    poids d'os, les UV (toutes les couches) et les couleurs de sommet sont interpolés. Budget de triangles par pièce.
import bmesh, math
from mathutils import Vector

METAUX = ("acier", "fer", "obsidienne", "or")
EXCLUS = ("maille", "chaine", "lion", "gemme")


def est_metal(nom):
    n = (nom or "").lower()
    return any(n.startswith(m) for m in METAUX) and not any(x in n for x in EXCLUS)


def _composantes(faces):
    fs = set(faces)
    vu, out = set(), []
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
        out.append(comp)
    return out


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def subdiviser_plaques(ob, budget, aire_min=0.004, passes=2, filtre=None, verbeux=True):
    """Ajoute au plus `budget` triangles en subdivisant les plaques de métal les plus grossières. Une plaque peut être subdivisée
    deux fois (passes) si le budget le permet et qu'elle reste grossière (> 2,2 cm² par triangle). filtre(centre_monde) -> bool."""
    me = ob.data
    mats = [m.name if m else "" for m in me.materials]
    metal = {i for i, n in enumerate(mats) if est_metal(n)}
    ajout = 0
    t0 = tris(ob)
    for passe in range(passes):
        bm = bmesh.new(); bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        comps = []
        for c in _composantes([f for f in bm.faces if f.material_index in metal]):
            nt = sum(len(f.verts) - 2 for f in c)
            aire = sum(f.calc_area() for f in c)
            if aire < aire_min or nt < 8:
                continue
            dens = aire / nt
            if dens < 0.00022:
                continue
            if filtre is not None:
                ctr = sum((f.calc_center_median() for f in c), Vector()) / len(c)
                if not filtre(ob.matrix_world @ ctr):
                    continue
            comps.append((dens, nt, c))
        comps.sort(key=lambda x: -x[0])
        choisies = []
        for dens, nt, c in comps:
            if ajout + nt * 3 > budget:
                continue
            choisies.append(c)
            ajout += nt * 3
        if not choisies:
            bm.free()
            break
        aretes = set()
        for c in choisies:
            for f in c:
                aretes.update(f.edges)
        bmesh.ops.subdivide_edges(bm, edges=list(aretes), cuts=1, use_grid_fill=True, smooth=1.0, use_smooth_even=False)
        bm.to_mesh(me); bm.free(); me.update()
        if verbeux:
            print("SUBDIV", ob.name, "passe", passe + 1, len(choisies), "plaques")
    if verbeux:
        print("SUBDIV", ob.name, t0, "->", tris(ob), "tris (budget", budget, ")")
    return tris(ob) - t0


# Matériaux propres aux armures lourdes v3 : le jeu leur donne shader_lourd (scripts/rpg/armure_visible.gd, clés « spec » de MATIERES)
# sans toucher aux autres familles qui partagent les anciens noms (« fer » des cuirs, « fer.noir » du heaume du Jarl…).
RENOMMER = {"fer": "fer.lourd", "obsidienne": "obsidienne.lourd", "or.patine": "or.lourd", "or.lion": "or.lourd"}


def renommer_materiaux(ob, table=RENOMMER):
    for m in ob.data.materials:
        if m is None:
            continue
        base = m.name.split(".0")[0] if m.name[-4:-3] == "." and m.name[-3:].isdigit() else m.name
        if base in table:
            m.name = table[base]
    return [m.name for m in ob.data.materials if m]
