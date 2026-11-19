# PROPS TEXTURÉS PS1 « v5 » : packs Quaternius (CC0) À COULEURS UNIES ou à trims d'un AUTRE pack -> pq_* du jeu  (props/sources_v5, 2026-11-19)
#   blender.exe -b --python props_sources_v5.py -- [seulement=pq_a,pq_b]
# Entrée : props_sources_v5_liste.json (écrit par gen_props_sources_v5.py). Sortie : assets/modeles/props_quat/<catégorie>/<id>.glb
#          + data/props_sources_v5_brut.json (fusionné dans data/props_quaternius.json par outils/props_sources_v5_catalogue.py).
# Les fichiers Quaternius sont des DONNÉES : on les importe, on n'exécute rien d'eux.
#
# Différence avec props_quaternius.py (Fantasy Props MegaKit, UV d'origine sur ses trims) : ces packs n'ont PAS les trims du MegaKit
# (Ultimate Home Interior, Medieval Dungeon, Survival, Ultimate Food, Modular Dungeon = couleurs unies ; Medieval Village = ses propres
# trims). Pour rester HOMOGÈNE avec les 95 pq_* et sans nouvel atlas (PropsQuaternius.ATLAS_PQ inchangé, 8 matériaux par lot au plus),
# chaque matériau source est rangé dans une MATIÈRE et ses faces sont RE-PROJETÉES (projection par îlot sur l'axe dominant, densité
# ~80 texels/m comme les pq_* existants) sur une zone de l'atlas partagé :
#   bois[:f]      -> pq_bois, bande des planches (haut de l'atlas, fil horizontal ; U le long du grand côté de l'îlot), x f (sombre)
#   fer[:f]       -> pq_fer (fer sombre bruité, toute la surface), x f
#   v:<rampe>     -> pq_fer_v (luminance bruitée) x couleur de sommet = couleur source accrochée sur la rampe de la bible
#   tissu:<rampe> -> pq_tissu_v (zone des plis claire) x couleur de sommet accrochée sur la rampe
#   suppr         -> faces retirées (flammes des torches et bûchers : le jeu pose ses flammes)
#   auto          -> rampe la plus proche de la couleur source (bois -> bois, fer -> fer, sinon v:<rampe>)
# Puis comme props_quaternius.py : échelle réelle, origine au pied, soudure, réduction ADAPTATIVE seulement au-dessus du budget,
# lissage 35°, couleur de sommet = teinte x occlusion cuite x pied sombre, export glb sans image (matériaux « pq_<atlas> »).
import bpy, bmesh, math, os, sys, json, random, colorsys, zlib
import numpy as np
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import props_quaternius as PQ          # fonctions partagées (main() gardé derrière __name__)

BASE = PQ.BASE
SORTIE = PQ.SORTIE
BRUT = os.path.join(BASE, "data", "props_sources_v5_brut.json")
LISTE = os.path.join(ICI, "props_sources_v5_liste.json")
INFOS = json.load(open(os.path.join(PQ.TEX, "atlas.json")))

TX_M = 80.0                                  # texels par mètre visés (pq_* existants : 60-110)
# zones d'atlas (UV Blender : v = 1 en haut de l'image) ; None = toute la surface se répète
BANDE = {"bois": (1 - 54 / 128, 1 - 2 / 128), "fer": None, "fer_v": None, "tissu_v": (1 - 126 / 256, 1 - 66 / 256)}
TAILLE = {"bois": 128, "fer": 128, "fer_v": 128, "tissu_v": 256}
L_BOIS_REF = 0.16                            # luminance (linéaire) d'un bois « moyen » des packs unis


def couleur_source(m):
    if m is None or not m.use_nodes:
        return (0.5, 0.5, 0.5)
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b is None:
        return (0.5, 0.5, 0.5)
    c = list(b.inputs[0].default_value[:3])          # linéaire
    return tuple(c)


def srgb(c):
    c = np.array(c, dtype=float)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)


def lum_lin(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def spec_de(nom_mat, mats):
    """Matière d'un matériau source : clé de « mats » contenue dans le nom (clés longues d'abord), sinon « auto »."""
    for k in sorted(mats, key=len, reverse=True):
        if k.lower() in nom_mat.lower():
            return mats[k]
    return mats.get("*", "auto")


def resoudre(spec, c_lin, f_bois):
    """spec + couleur source -> (atlas, teinte RGB sRGB 0-1 de la couleur de sommet)."""
    if spec == "auto":
        c = PQ.virage_np(srgb(c_lin)[None, :], 0.78, 0.86, 0.06)
        best, rampe = 9e9, "bois"
        for r in PQ.CAND_V:
            pal, lab = PQ.palette((r,))
            l0 = PQ.oklab_np(np.clip(c, 0, 1))[0]
            d = (1.4 * (lab[:, 0] - l0[0]) ** 2 + (lab[:, 1] - l0[1]) ** 2 + (lab[:, 2] - l0[2]) ** 2).min()
            if d < best:
                best, rampe = d, r
        spec = "bois" if rampe in ("bois", "ecorce") else "fer" if rampe == "fer" else "v:" + rampe
    nom, _, arg = spec.partition(":")
    if nom == "bois":
        f = float(arg) if arg else f_bois
        return "bois", np.array([f, f, f])
    if nom == "fer":
        f = float(arg) if arg else 1.0
        return "fer", np.array([f, f, f])
    if nom in ("v", "tissu"):
        rampe, _, fx = arg.partition("*")
        c = PQ.virage_np(srgb(c_lin)[None, :], 0.78, 0.86, 0.06)
        pal, lab = PQ.palette((rampe,))
        t = PQ.accrocher_np(c, pal, lab, poids_l=0.6)[0]
        if fx:
            t = t * float(fx)
        return ("fer_v" if nom == "v" else "tissu_v"), np.clip(t, 0, 1)
    raise ValueError("matière inconnue : " + spec)


def importer(src, rot):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = src.lower().rsplit(".", 1)[-1]
    if ext == "fbx":
        bpy.ops.import_scene.fbx(filepath=src)
    elif ext == "obj":
        bpy.ops.wm.obj_import(filepath=src)
    else:
        bpy.ops.import_scene.gltf(filepath=src)
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    dg = bpy.context.evaluated_depsgraph_get()
    for o in obs:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        mw = o.matrix_world.copy()
        o.modifiers.clear()
        o.parent = None
        o.data = me
        o.matrix_world = mw
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    if rot:
        o.rotation_euler = [math.radians(a) for a in rot]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for x in [x for x in bpy.context.scene.objects if x != o]:
        bpy.data.objects.remove(x, do_unlink=True)
    return o


def matieres(o, e):
    """Matériaux source -> atlas + teinte par face ; faces « suppr » retirées. Renvoie (liste d'atlas, teinte par index de matériau)."""
    me = o.data
    mats = e.get("mats", {})
    srcs = []
    for s in o.material_slots:
        m = s.material
        nm = m.name if m else "?"
        srcs.append((nm, spec_de(nm, mats), couleur_source(m)))
    if not srcs:
        srcs = [("?", mats.get("*", "bois"), (0.16, 0.12, 0.08))]
    # bois sans facteur : le plus clair des bois du modèle = 1, les autres en proportion (plancher 0,6)
    lb = [lum_lin(c) for _, sp, c in srcs if sp == "bois"]
    lmax = max(lb) if lb else L_BOIS_REF
    res = []
    for nm, sp, c in srcs:
        if sp == "suppr":
            res.append(None)
            continue
        fb = max(0.6, min(1.0, (lum_lin(c) / max(lmax, 1e-4)) ** 0.5)) * e.get("bois_f", 1.0)
        res.append(resoudre(sp, c, fb))
        print("   mat %-22s %-18s -> pq_%s %s" % (nm, sp, res[-1][0], np.round(res[-1][1], 2)))
    # retrait des faces « suppr »
    bm = bmesh.new()
    bm.from_mesh(me)
    tuer = [f for f in bm.faces if f.material_index < len(res) and res[f.material_index] is None]
    if tuer:
        bmesh.ops.delete(bm, geom=tuer, context='FACES')
        # sommets orphelins
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(me)
    bm.free()
    atl = sorted({r[0] for r in res if r})
    teinte_mi = {}
    idx_atl = {}
    for i, r in enumerate(res):
        if r:
            idx_atl[i] = atl.index(r[0])
            teinte_mi[i] = r[1]
    # nouveaux matériaux = un par atlas ; la teinte par face est gardée dans un attribut
    face_teinte = [teinte_mi.get(p.material_index, np.array([1.0, 1.0, 1.0])) for p in me.polygons]
    face_atl = [idx_atl.get(p.material_index, 0) for p in me.polygons]
    me.materials.clear()
    for k in atl:
        me.materials.append(PQ.materiau_atlas(k))
    for p, i in zip(me.polygons, face_atl):
        p.material_index = i
    return atl, face_teinte


def echelle(o, e):
    me = o.data
    vs = [v.co for v in me.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    if "hauteur" in e:
        f = e["hauteur"] / max(hi.z - lo.z, 1e-6)
    elif "longueur" in e:
        f = e["longueur"] / max(hi.x - lo.x, hi.y - lo.y, 1e-6)
    else:
        f = e.get("ech", 1.0)
    c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in me.vertices:
        v.co = (v.co - c) * f
    me.update()
    return f


def projeter(o, atl):
    """UV re-projetées par îlot (faces voisines de même matériau et même axe dominant) dans la zone de l'atlas de leur matière."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    for l in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(l)
    uvl = bm.loops.layers.uv.new("UVMap")
    axe = {}
    for f in bm.faces:
        n = f.normal
        axe[f.index] = max(range(3), key=lambda i: abs(n[i]))
    vu = set()
    nb_ilots = 0
    for f0 in bm.faces:
        if f0.index in vu:
            continue
        a, mi = axe[f0.index], f0.material_index
        pile, ilot = [f0], []
        vu.add(f0.index)
        while pile:
            f = pile.pop()
            ilot.append(f)
            for ed in f.edges:
                for g in ed.link_faces:
                    if g.index not in vu and axe[g.index] == a and g.material_index == mi:
                        vu.add(g.index)
                        pile.append(g)
        nb_ilots += 1
        k = atl[mi]
        i1, i2 = [(1, 2), (0, 2), (0, 1)][a]
        pts = [l.vert.co for f in ilot for l in f.loops]
        e1 = max(p[i1] for p in pts) - min(p[i1] for p in pts)
        e2 = max(p[i2] for p in pts) - min(p[i2] for p in pts)
        iu, iv = (i1, i2) if e1 >= e2 else (i2, i1)
        mu = min(p[iu] for p in pts)
        mv = min(p[iv] for p in pts)
        ev = max(e1, e2) if False else (e2 if iu == i1 else e1)
        s = TX_M / TAILLE[k]
        h = zlib.crc32(("%d %.3f %.3f %.3f" % (mi, mu, mv, ev)).encode()) & 0xffff
        du = (h % 997) / 997.0
        bande = BANDE[k]
        if bande is None:
            sv, dv = s, ((h // 7) % 991) / 991.0
            v0 = 0.0
        else:
            hb = bande[1] - bande[0]
            sv = min(s, hb / max(ev, 1e-6))
            jeu = max(0.0, hb - ev * sv)
            v0, dv = bande[0], jeu * (((h // 7) % 991) / 991.0)
        for f in ilot:
            for l in f.loops:
                p = l.vert.co
                l[uvl].uv = (du + (p[iu] - mu) * s, v0 + dv + (p[iv] - mv) * sv)
    bm.to_mesh(me)
    bm.free()
    return nb_ilots


def couleurs(o, atl, face_teinte, e):
    """Couleur de sommet (coin) : teinte de la matière x occlusion cuite x pied sombre ; alpha 1 (comme props_quaternius.couleurs)."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    tris = [[l.vert.co.copy() for l in f.loops] for f in bm.faces]
    pts, polys = [], []
    for t in tris:
        polys.append(tuple(range(len(pts), len(pts) + len(t))))
        pts.extend(t)
    from mathutils.bvhtree import BVHTree
    arbre = BVHTree.FromPolygons([tuple(p) for p in pts], polys, epsilon=1e-6)
    taille = max(o.dimensions)
    portee = min(0.3, max(0.04, taille * 0.25))
    rg = random.Random(5)
    dirs = []
    for _ in range(14):
        u, v = rg.random(), rg.random()
        r = math.sqrt(u)
        th = 2 * math.pi * v
        dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0, 1 - u))))
    ao = {}
    for vt in bm.verts:
        n = vt.normal.copy()
        if n.length < 1e-6:
            ao[vt.index] = 1.0
            continue
        tg = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        bt = n.cross(tg)
        occ = 0.0
        org = vt.co + n * portee * 0.02
        for dx, dy, dz in dirs:
            d = (tg * dx + bt * dy + n * dz).normalized()
            hh = arbre.ray_cast(org, d, portee)
            if hh[0] is not None:
                occ += 1.0 - hh[3] / portee
        ao[vt.index] = max(0.5, 1.0 - 0.75 * occ / len(dirs) * 1.6)
    sol = e.get("sol", True)
    pied_h = min(0.2, max(0.03, o.dimensions.z * 0.25))
    lay = bm.loops.layers.float_color.new("Col")
    for f in bm.faces:
        t = face_teinte[f.index] if f.index < len(face_teinte) else np.array([1.0, 1.0, 1.0])
        for l in f.loops:
            a = ao[l.vert.index]
            z = l.vert.co.z
            p = (0.72 + 0.28 * min(1.0, max(0.0, z / pied_h))) if sol else 1.0
            k2 = a * p
            l[lay] = (PQ.lin(t[0] * k2), PQ.lin(t[1] * k2), PQ.lin(t[2] * k2), 1.0)
    bm.to_mesh(me)
    bm.free()
    for ca in list(me.color_attributes):
        if ca.name != "Col":
            me.color_attributes.remove(ca)
    me.color_attributes.active_color = me.color_attributes["Col"]
    try:
        me.color_attributes.render_color_index = 0
    except Exception:
        pass


def teintes_par_face(o, face_teinte_init):
    """La réduction renumérote les faces : on relit la teinte par la couleur provisoire posée avant (attribut « tmp_t »)."""
    me = o.data
    ca = me.attributes.get("tmp_t")
    if ca is None:
        return face_teinte_init
    out = [np.array(ca.data[p.index].color[:3]) for p in me.polygons]
    me.attributes.remove(ca)
    return out


def convertir(e):
    print("PROP", e["id"], e["src"].split("/")[-1])
    o = importer(e["src"], e.get("rot"))
    atl, ft = matieres(o, e)
    # teinte par face dans un attribut de FACE (survit à la soudure / réduction : interpolé au mieux)
    at = o.data.attributes.new("tmp_t", 'FLOAT_COLOR', 'FACE')
    for p in o.data.polygons:
        t = ft[p.index]
        at.data[p.index].color = (float(t[0]), float(t[1]), float(t[2]), 1.0)
    f = echelle(o, e)
    bpy.context.view_layer.update()
    d = max(o.dimensions)
    budget = e.get("budget", int(min(10000, max(1500, 1500 + 3000 * d))))
    red = PQ.reduire(o, budget)
    o.data.update()
    ft = teintes_par_face(o, ft)
    nb = projeter(o, atl)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception:
        bpy.ops.object.shade_smooth()
    couleurs(o, atl, ft, e)
    bpy.context.view_layer.update()
    me = o.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    chemin = os.path.join(SORTIE, e["categorie"], e["id"] + ".glb")
    PQ.exporter(o, chemin)
    dd = o.dimensions
    infos = {k: {"taille": TAILLE.get(k, 128)} for k in atl}
    r = {"id": e["id"], "source": os.path.splitext(os.path.basename(e["src"]))[0], "pack": e.get("pack", ""),
         "categorie": e["categorie"],
         "fichier": "res://assets/modeles/props_quat/%s/%s.glb" % (e["categorie"], e["id"]),
         "dimensions_m": [round(dd.x, 3), round(dd.z, 3), round(dd.y, 3)],
         "tris": tris, "tris_source": red["tris_source"], "reduction": red["palier"], "budget": budget,
         "echelle": round(f, 4), "atlas": ["pq_" + k for k in atl], "texels_m": PQ.densite(o, atl, infos),
         "collision": PQ.collision(o), "octets": os.path.getsize(chemin), "ilots_uv": nb}
    print("PROP %-26s %5d -> %5d tris  %s  %s" % (e["id"], red["tris_source"], tris, r["dimensions_m"], red["palier"]))
    return r


def main():
    args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
    liste = json.load(open(LISTE, encoding="utf8"))
    seul = set(args["seulement"].split(",")) if "seulement" in args else None
    anciens = {}
    if os.path.exists(BRUT):
        anciens = {r["id"]: r for r in json.load(open(BRUT, encoding="utf8"))}
    for e in liste:
        if seul and e["id"] not in seul:
            continue
        try:
            r = convertir(e)
            r.update({k: e[k] for k in ("nom", "matiere", "equivalent_q", "usage", "note") if k in e})
            anciens[e["id"]] = r
        except Exception as er:
            import traceback
            traceback.print_exc()
            print("ECHEC", e["id"], er)
    ordre = [e["id"] for e in liste]
    res = sorted([r for r in anciens.values() if r["id"] in ordre], key=lambda r: ordre.index(r["id"]))
    json.dump(res, open(BRUT, "w", encoding="utf8"), indent=1, ensure_ascii=False)
    print("FINI", len(res), "props ;", sum(r["tris"] for r in res), "tris ;", sum(r["octets"] for r in res), "octets")


if __name__ == "__main__":
    main()
