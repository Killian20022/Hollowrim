# Mesure du DÉCOLLEMENT des armures portées par rapport à la PEAU du héros (pose de repos), par région du corps.
#   blender.exe -b --python sources_blender/scripts/mesurer_epaisseur_armures.py -- <dossier_glb_porte> <sortie.json> id1 id2 ...
# Pour chaque pièce : distance de chaque sommet à la peau la plus proche (mm), regroupée par os dominant
# (torse, epaules, bras, mains, cuisses, tibias, pieds, tete) -> moyenne, p90, max ; + largeur/profondeur de la silhouette.
import bpy, sys, os, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ICI = os.path.dirname(os.path.abspath(__file__))
REF = os.path.normpath(os.path.join(ICI, "..", "armures", "heros_reference.glb"))


CORPS = {"peau", "tunique", "pantalon", "brassards", "bottes"}


def region(nom, z):
    n = nom.lower()
    if n.startswith("head") or n.startswith("neck"):
        return "tete"
    if n.startswith("upperarm") or n.startswith("clavicle"):
        return "epaules" if z > 1.33 else "bras"
    if n.startswith("lowerarm"):
        return "bras"
    if n.startswith("hand") or any(n.startswith(d) for d in ("index", "middle", "ring", "pinky", "thumb")):
        return "mains"
    if n.startswith("thigh"):
        return "cuisses"
    if n.startswith("calf"):
        return "tibias"
    if n.startswith("foot") or n.startswith("ball"):
        return "pieds"
    return "torse"


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    dossier, sortie, ids = a[0], a[1], a[2:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=REF)
    bpy.context.view_layer.update()
    # « corps » = peau (tête/cou) + vêtements de base du héros (tunique, pantalon, brassards, bottes) : c'est la surface que
    # l'armure recouvre (le héros de référence n'a pas de peau sous ses vêtements)
    vs, fs = [], []
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name.split(".")[0] not in CORPS:
            continue
        b = len(vs)
        vs += [o.matrix_world @ v.co for v in o.data.vertices]
        fs += [[b + i for i in p.vertices] for p in o.data.polygons]
    arbre = BVHTree.FromPolygons(vs, fs)
    res = {}
    for pid in ids:
        avant = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(dossier, pid + ".glb"))
        bpy.context.view_layer.update()
        neufs = [o for o in bpy.data.objects if o not in avant and o.type == "MESH" and not o.name.startswith("Icosphere")]
        par = {}
        tous = []
        xs, ys = [], []
        for o in neufs:
            noms = {g.index: g.name for g in o.vertex_groups}
            for v in o.data.vertices:
                p = o.matrix_world @ v.co
                hit = arbre.find_nearest(p)
                if hit[0] is None:
                    continue
                d = hit[3] * 1000.0
                if v.groups:
                    gmax = max(v.groups, key=lambda g: g.weight)
                    reg = region(noms[gmax.group], p.z)
                else:
                    reg = "torse"
                par.setdefault(reg, []).append(d)
                tous.append(d)
                xs.append(p.x); ys.append(p.y)
        ligne = {}
        for reg, L in sorted(par.items()):
            L.sort()
            ligne[reg] = {"n": len(L), "moy": round(sum(L) / len(L), 1), "p90": round(L[int(0.9 * (len(L) - 1))], 1), "max": round(L[-1], 1)}
        ligne["_largeur_mm"] = round((max(xs) - min(xs)) * 1000) if xs else 0
        ligne["_profondeur_mm"] = round((max(ys) - min(ys)) * 1000) if ys else 0
        ligne["_tris"] = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in neufs)
        res[pid] = ligne
        print("EPAISSEUR", pid, json.dumps(ligne))
        for o in list(bpy.data.objects):
            if o not in avant:
                bpy.data.objects.remove(o, do_unlink=True)
    with open(sortie, "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1, ensure_ascii=False)


main()
