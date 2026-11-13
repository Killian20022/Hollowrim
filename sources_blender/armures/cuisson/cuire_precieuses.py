# CUISSON « haute déf -> basse déf » des armures PRÉCIEUSES (verre, rubis, saphir, cuir, fourrure, os, uniques non métalliques),
# précieuses HD v3 (2026-11-12). Même recette que cuire.py (acier nordique, commit dadeef17), mais en POST-TRAITEMENT d'un glb déjà
# généré : les générateurs (os_verre, rubis_saphir, cuir_fourrure, uniques) restent la source de la basse déf (triangles, poids d'os,
# découpes, matériaux) ; ce script ne touche qu'aux UV et à la texture.
#   blender.exe -b --python sources_blender/armures/cuisson/cuire_precieuses.py -- <id> [<id> ...] [--px 1024] [--debug DOSSIER]
#               [--niveau-hd 2] [--pas-sol] [--pas-enchante]
# Pour chaque pièce porte/<id>.glb :
#   1. import (armature + maillage skinné : l'aller-retour glTF garde les poses de liaison à l'identique, vérifié) ;
#   2. UV UNIQUES « cuisson » (smart project + empaquetage sans recouvrement, px²) ; la peinture d'origine (une image par matériau :
#      pièce, cristal, gemme…) est reprise texel par texel, alpha (brillance / masque de cristal) compris ;
#   3. HAUTE DÉF : copie soudée, arêtes vives pliées (crease), subdivisée (Catmull-Clark) -> chanfreins fins sur chaque arête de plaque ;
#   4. Cycles : normales (objet) + occlusion ambiante de la haute déf, dans ses propres UV ;
#   5. relief FIN dans l'espace de la texture, par MATIÈRE (lignes = arêtes vives / changements de matière, mesurées en 3D) :
#      métal : bande de bordure, gorge et rivets ; cuir : grain, rang de piqûres le long des bords, bords lustrés ; fourrure : mèches ;
#      os : pores et stries ; cristal : arêtes de facettes claires et nettes ; tissu : trame ;
#   6. ALBÉDO = peinture x occlusion x éclairage cuit léger + arêtes, alpha = brillance (relevée sur les arêtes polies, éteinte dans
#      les creux ; masque du cristal conservé tel quel : le shader pierre le lit par seuil) ;
#   7. export porte/<id>.glb, sol/<id>.glb (UV recopiées par correspondance d'UV d'origine) et, s'ils existent, les glb « _enchante »
#      (même maillage, leur propre peinture, même relief).
import bpy, bmesh, sys, os, math, time, importlib
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import raster as RS
import details as D
importlib.reload(RS); importlib.reload(D)

DEPOT = os.path.abspath(os.path.join(ICI, "..", "..", ".."))
PORTE = os.path.join(DEPOT, "assets", "modeles", "armures", "porte")
SOL = os.path.join(DEPOT, "assets", "modeles", "armures", "sol")
CHAUSSES = os.path.join(DEPOT, "assets", "modeles", "armures", "chausses")
TEXTURES = os.path.join(ICI, "textures_precieuses")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _opt(nom, defaut):
    if nom in ARGS:
        return ARGS[ARGS.index(nom) + 1]
    return defaut


# ------------------------------------------------------------------------------------------------------------ matières
def classe(nom):
    """Nom de matériau Blender -> classe de cuisson."""
    p = nom.split(".")[0]
    if p in ("rubis", "saphir", "gemme"):
        return "gemme"
    if p == "verre" or p.startswith("plaque_") or p.startswith("cristal_"):
        return "cristal"
    if p == "or":
        return "or"
    if p in ("acier", "fer", "argent") or p.startswith("acier_") or p.startswith("serti_"):
        return "metal"
    if p == "cuir":
        return "cuir"
    if p == "fourrure":
        return "fourrure"
    if p == "os":
        return "os"
    if p == "runes":
        return "runes"
    return "tissu"


# angle d'arête vive (degrés) par classe : en dessous, l'arête n'est pas une « ligne » (le cristal a des facettes douces)
ANGLE_LIGNE = {"cristal": 14.0, "gemme": 14.0, "metal": 38.0, "or": 38.0, "cuir": 50.0, "fourrure": 70.0, "os": 45.0, "tissu": 60.0, "runes": 60.0}
# forces de composition par classe : occlusion, éclairage cuit, reflet cuit, liseré d'arête (clair), creux (sombre)
F = {
    "metal":    dict(occ=0.85, ecl=0.55, spec=0.30, arete=0.55, creux=0.55, bri_arete=0.55),
    "or":       dict(occ=0.80, ecl=0.45, spec=0.25, arete=0.45, creux=0.45, bri_arete=0.45),
    "cristal":  dict(occ=0.45, ecl=0.0, spec=0.0, arete=0.38, creux=0.25, bri_arete=0.30),
    "gemme":    dict(occ=0.30, ecl=0.0, spec=0.0, arete=0.25, creux=0.15, bri_arete=0.0),
    "cuir":     dict(occ=0.75, ecl=0.42, spec=0.05, arete=0.30, creux=0.45, bri_arete=0.35),
    "fourrure": dict(occ=0.90, ecl=0.50, spec=0.0, arete=0.10, creux=0.55, bri_arete=0.0),
    "os":       dict(occ=0.85, ecl=0.50, spec=0.08, arete=0.32, creux=0.55, bri_arete=0.20),
    "tissu":    dict(occ=0.70, ecl=0.40, spec=0.0, arete=0.12, creux=0.35, bri_arete=0.0),
    "runes":    dict(occ=0.50, ecl=0.20, spec=0.0, arete=0.10, creux=0.20, bri_arete=0.0),
}
# composition du liseré d'arête : (ligne 3D fine, courbure fine, courbure large) par classe
POIDS_ARETE = {"metal": (0.9, 0.5, 0.5), "or": (0.9, 0.5, 0.5), "cristal": (0.85, 0.2, 0.0), "gemme": (0.6, 0.2, 0.0),
               "cuir": (0.55, 0.4, 0.45), "os": (0.6, 0.4, 0.6), "fourrure": (0.0, 0.2, 0.0), "tissu": (0.2, 0.2, 0.2), "runes": (0.2, 0.2, 0.0)}
FIL = np.array([0.50, 0.43, 0.32])          # fil de couture (lin ciré)
IVOIRE = np.array([0.78, 0.72, 0.58])


# ------------------------------------------------------------------------------------------------------------ import / export
def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importer(chemin):
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=chemin)
    neufs = [o for o in bpy.data.objects if o not in avant]
    mesh = [o for o in neufs if o.type == "MESH" and len(o.data.polygons) > 0 and (o.parent is not None or not any(x.type == "ARMATURE" for x in neufs))]
    arm = next((o for o in neufs if o.type == "ARMATURE"), None)
    # un seul maillage utile (les formes d'os personnalisées, ex. Icosphere, ne sont pas exportées)
    mesh.sort(key=lambda o: -len(o.data.polygons))
    return mesh[0], arm, neufs


def exporter(obs, chemin):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    kw = dict(filepath=chemin, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
              export_apply=False, export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
              export_image_format="AUTO", export_def_bones=False)
    for k, v in (("export_vertex_color", "ACTIVE"), ("export_all_vertex_colors", True), ("export_colors", True)):
        try:
            bpy.ops.export_scene.gltf.get_rna_type().properties[k]
            kw[k] = v
        except KeyError:
            pass
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORT", chemin)
    sans_materiaux_partages(chemin)


def sans_materiaux_partages(chemin):
    """La pièce a désormais SA texture (UV uniques) : l'import Godot ne doit plus remplacer ses matériaux par ceux de
    materiaux_partages/ (dédoublonnage de perf/exe_leger, qui pointaient vers l'ancien atlas commun)."""
    imp = chemin + ".import"
    if not os.path.exists(imp):
        return
    t = open(imp, encoding="utf-8").read()
    i = t.find("_subresources={")
    if i < 0:
        return
    prof = 0
    for j in range(i + len("_subresources="), len(t)):
        if t[j] == "{":
            prof += 1
        elif t[j] == "}":
            prof -= 1
            if prof == 0:
                break
    t2 = t[:i] + "_subresources={}" + t[j + 1:]
    if t2 != t:
        open(imp, "w", encoding="utf-8", newline="\n").write(t2)
        print("IMPORT sans materiaux partages", os.path.basename(imp))


def _image_np(img):
    W, H = img.size
    a = np.zeros(W * H * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(H, W, 4).astype(np.float64)


def images_par_materiau(ob):
    out = []
    for m in ob.data.materials:
        img = None
        if m and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    img = n.image
                    break
        out.append(_image_np(img) if img is not None else None)
    return out


def _png(chemin, arr):
    H, W = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((H, W, 1))], -1)
    img = bpy.data.images.new("tmp_png", W, H, alpha=True)
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = chemin
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# ------------------------------------------------------------------------------------------------------------ UV uniques
def deplier(ob, px):
    """UV « cuisson » : dépliées sur une copie SOUDÉE (le glb sépare les sommets à chaque arête vive / face plate : déplier l'original
    ferait une île par facette de cristal), puis recopiées coin par coin (même ordre de faces et de coins après la soudure)."""
    me = ob.data
    ancien = me.uv_layers[0].name
    w = ob.copy(); w.data = me.copy(); w.name = ob.name + "_soude"
    bpy.context.scene.collection.objects.link(w)
    w.modifiers.clear()
    for dist in (1e-5, 1e-6, 1e-7, 1e-9):
        # (fourrure : les mèches effilées ont des pointes presque confondues ; un seuil trop gros efface des faces)
        w.data = me.copy()
        bm = bmesh.new(); bm.from_mesh(w.data)
        nf0 = len(bm.faces)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
        bm.to_mesh(w.data); bm.free()
        if len(w.data.polygons) == nf0:
            break
    assert len(w.data.polygons) == nf0 == len(me.polygons), "soudure : faces perdues"
    uv = w.data.uv_layers.new(name="cuisson")
    w.data.uv_layers.active = uv
    bpy.ops.object.select_all(action="DESELECT")
    w.select_set(True)
    bpy.context.view_layer.objects.active = w
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    try:
        bpy.ops.uv.pack_islands(margin=2.5 / px, rotate=True, shape_method="CONCAVE")
    except TypeError:
        bpy.ops.uv.pack_islands(margin=2.5 / px, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    a = uv_np(w.data, "cuisson")
    # coins : même ordre (loop_start / loop_total identiques face par face)
    ls = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_start", ls)
    lw = np.zeros(len(me.polygons), np.int64); w.data.polygons.foreach_get("loop_start", lw)
    assert (ls == lw).all(), "soudure : coins décalés"
    u2 = me.uv_layers.new(name="cuisson")
    u2.data.foreach_set("uv", a.ravel())
    me.uv_layers.active = u2
    bpy.data.objects.remove(w, do_unlink=True)
    return ancien


def uv_np(me, nom):
    a = np.zeros(len(me.loops) * 2)
    me.uv_layers[nom].data.foreach_get("uv", a)
    return a.reshape(-1, 2)


def finaliser_uv(ob, ancien):
    """UV « cuisson » recopiées dans la PREMIÈRE couche (TEXCOORD_0), la couche « cuisson » retirée (les autres couches restent)."""
    me = ob.data
    nv = uv_np(me, "cuisson")
    me.uv_layers[ancien].data.foreach_set("uv", nv.ravel())
    me.uv_layers.remove(me.uv_layers["cuisson"])
    me.uv_layers.active = me.uv_layers[ancien]


# ------------------------------------------------------------------------------------------------------------ lignes (arêtes)
def lignes(ob, classes):
    """Points 3D (monde, tous les 1,5 mm) des LIGNES de la pièce : arêtes vives (angle dièdre > ANGLE_LIGNE de la classe), changements
    de matière, bords libres ; sur une copie soudée (les coutures d'UV du glb ne sont pas des arêtes). Retourne par classe :
    (KDTree, abscisse curviligne de chaque point, tangente)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    M = ob.matrix_world
    pts = {}
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) == 0:
            continue
        ca = classes[fs[0].material_index]
        vive = False
        if len(fs) == 1:
            vive = True
        elif len(fs) == 2:
            cb = classes[fs[1].material_index]
            if fs[0].material_index != fs[1].material_index:
                vive = True
            else:
                ang = math.degrees(fs[0].normal.angle(fs[1].normal, 0.0))
                vive = ang > ANGLE_LIGNE.get(ca, 45.0)
        else:
            vive = True
        if not vive:
            continue
        a, b = M @ e.verts[0].co, M @ e.verts[1].co
        Ln = (b - a).length
        if Ln < 1e-6:
            continue
        t = (b - a) / Ln
        n = max(1, int(Ln / 0.0015))
        cls = {classes[f.material_index] for f in fs}
        for c in cls:
            lst = pts.setdefault(c, [])
            s0 = len(lst) * 0.0
            for k in range(n + 1):
                lst.append((a.lerp(b, k / n), k / n * Ln, t))
    bm.free()
    out = {}
    for c, lst in pts.items():
        kd = KDTree(len(lst))
        for i, (p, s, t) in enumerate(lst):
            kd.insert(p, i)
        kd.balance()
        out[c] = (kd, np.array([s for _, s, _ in lst]), np.array([tuple(t) for _, _, t in lst]))
    return out


def distance_lignes(K, cl_tex, L):
    """Par texel : distance (m) à la ligne la plus proche de SA classe, abscisse le long de cette ligne, tangente."""
    N = K.N
    dist = np.full((N, N), 9.0)
    absc = np.zeros((N, N))
    tang = np.zeros((N, N, 3))
    for c, (kd, S, T) in L.items():
        sel = np.nonzero(cl_tex == c)
        P = K.pos[sel]
        dd = np.empty(len(P)); ss = np.empty(len(P)); tt = np.empty((len(P), 3))
        for i in range(len(P)):
            co, idx, d = kd.find(Vector(P[i]))
            dd[i] = d; ss[i] = S[idx]; tt[i] = T[idx]
        dist[sel] = dd; absc[sel] = ss; tang[sel] = tt
    return dist, absc, tang


# ------------------------------------------------------------------------------------------------------------ haute déf
def haute_def(ob, uv_nom, niveau):
    hd = ob.copy(); hd.data = ob.data.copy()
    hd.name = ob.name + "_HD"
    bpy.context.scene.collection.objects.link(hd)
    mw = ob.matrix_world.copy()
    hd.parent = None
    hd.matrix_world = mw
    hd.modifiers.clear()
    hd.vertex_groups.clear()
    me = hd.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    cr = bm.edges.layers.float.get("crease_edge") or bm.edges.layers.float.new("crease_edge")
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) != 2:
            e[cr] = 1.0
            continue
        if fs[0].material_index != fs[1].material_index:
            e[cr] = 0.95
            continue
        ang = math.degrees(fs[0].normal.angle(fs[1].normal, 0.0))
        # arête de plaque (> 55°) : presque vive (chanfrein fin) ; arête de facette (15-55°) : demi-pliée
        e[cr] = 0.92 if ang > 55 else (0.6 if ang > 15 else 0.0)
    bm.to_mesh(me); bm.free()
    sub = hd.modifiers.new("subdiv", "SUBSURF")
    sub.levels = sub.render_levels = niveau
    sub.uv_smooth = "NONE"
    try:
        sub.use_creases = True
    except AttributeError:
        pass
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(hd.evaluated_get(dg))
    hd.modifiers.clear()
    vieux = hd.data
    hd.data = me2
    bpy.data.meshes.remove(vieux)
    for p in me2.polygons:
        p.use_smooth = True
    print("HD", len(me2.polygons), "faces")
    return hd


def cuire_cycles(hd, px, uv_nom):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("monde")
    sc.world.light_settings.distance = 0.05
    for o in bpy.data.objects:
        o.hide_render = o is not hd
    hd.data.uv_layers.active = hd.data.uv_layers[uv_nom]
    hd.data.uv_layers[uv_nom].active_render = True
    mb = bpy.data.materials.new("cuisson_neutre")
    mb.use_nodes = True
    hd.data.materials.clear()
    hd.data.materials.append(mb)
    cartes = {}
    for typ, kw, ech in (("NORMAL", dict(normal_space="OBJECT"), 4), ("AO", {}, 96)):
        img = bpy.data.images.new("cuisson_" + typ, px, px, alpha=False, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        n = mb.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = img
        mb.node_tree.nodes.active = n
        sc.cycles.samples = ech
        bk = sc.render.bake
        bk.use_selected_to_active = False
        bk.margin = 6
        bk.target = "IMAGE_TEXTURES"
        bpy.ops.object.select_all(action="DESELECT")
        hd.select_set(True)
        bpy.context.view_layer.objects.active = hd
        t0 = time.time()
        bpy.ops.object.bake(type=typ, use_selected_to_active=False, **kw)
        print("CUISSON", typ, round(time.time() - t0, 1), "s")
        cartes[typ] = _image_np(img)[..., :3]
        mb.node_tree.nodes.remove(n)
        bpy.data.images.remove(img)
    for o in bpy.data.objects:
        o.hide_render = False
    return cartes


# ------------------------------------------------------------------------------------------------------------ composition
LUM = np.array([-0.42, -0.55, 0.72]); LUM /= np.linalg.norm(LUM)
VUE = np.array([0.0, -1.0, 0.25]); VUE /= np.linalg.norm(VUE)
DEMI = LUM + VUE; DEMI /= np.linalg.norm(DEMI)


def _voisin(a, dy, dx):
    return np.roll(np.roll(a, -dy, 0), -dx, 1)


def _flou(a, m, passes):
    N = a.shape[0]
    for _ in range(passes):
        acc = np.zeros_like(a); cnt = np.zeros(m.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                mm = _voisin(m, dy, dx)
                acc += _voisin(a, dy, dx) * mm; cnt += mm
        a = np.where(m, acc / np.maximum(cnt, 1), a)
    return a


def _tangentes(n):
    a = np.where(np.abs(n[..., 2:3]) < 0.9, np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0]))
    t1 = np.cross(n, a); t1 /= np.maximum(np.linalg.norm(t1, axis=-1, keepdims=True), 1e-9)
    t2 = np.cross(n, t1)
    return t1, t2


def relief_fin(cl, P, N, d, s, T):
    """Hauteur fine (m) par texel selon la classe ; d = distance à la ligne (m), s = abscisse le long, T = tangente de la ligne.
    Retourne (h, fil : masque des points de couture, rivet : masque des têtes de rivet)."""
    h = np.zeros(len(P)); fil = np.zeros(len(P)); riv = np.zeros(len(P))
    dmm = d * 1000.0
    if cl == "cuir":
        h += (D.bruit3(P, 0.0016, 81) - 0.5) * 0.00010 + (D.bruit3(P, 0.006, 82) - 0.5) * 0.00018
        h -= 0.00025 * np.clip(D.fbm3(P, 85, oct=((0.03, 0.6), (0.012, 0.4))) - 0.62, 0, 1) * 4        # plis
        # rang de piqûres à 3,2 mm du bord : un point de 2,6 mm tous les 4 mm (fil en relief, trou en creux entre)
        rang = np.exp(-((dmm - 3.2) / 0.55) ** 2)
        ph = (s * 1000.0 / 4.0) % 1.0
        point = (ph < 0.62).astype(np.float64)
        fil = rang * point
        h += 0.00022 * fil - 0.00018 * rang * (1 - point)
        # bord lustré roulé : léger bombé sur les 1,5 premiers mm
        h += 0.00012 * np.exp(-(dmm / 1.2) ** 2)
    elif cl == "fourrure":
        # mèches : bruit étiré le long de la pente (y monde), pointes claires
        Q = P * np.array([1.0, 1.0, 0.22])
        h += (D.bruit3(Q, 0.0022, 91) - 0.5) * 0.0011 + (D.bruit3(Q, 0.006, 92) - 0.5) * 0.0012
    elif cl == "os":
        h += (D.bruit3(P * np.array([1.0, 1.0, 0.3]), 0.0025, 61) - 0.5) * 0.00022     # stries de croissance
        pores = D.voronoi3(P, 0.0028, 63)[0]
        h -= 0.00012 * np.clip(1 - pores / 0.30, 0, 1)
    elif cl == "metal" or cl == "or":
        h += (D.bruit3(P, 0.004, 71) - 0.5) * 0.00002
        bande = D.lisse(0.6, 1.4, dmm) * (1 - D.lisse(3.2, 4.0, dmm))
        gorge = np.exp(-((dmm - 4.6) / 0.55) ** 2)
        h += 0.00028 * bande - 0.00024 * gorge
        # rivets tous les 26 mm sur la bande des grandes plaques
        ph = (s * 1000.0 / 26.0) % 1.0
        rr = np.sqrt(((ph - 0.5) * 26.0) ** 2 + (dmm - 2.4) ** 2)
        riv = np.clip(1 - (rr / 1.25) ** 2, 0, 1) * (dmm < 4.0)
        h += 0.0007 * np.sqrt(riv)
    elif cl == "tissu":
        tr = np.sin(P[:, 0] * 2400.0) * np.sin(P[:, 2] * 2400.0)
        h += tr * 0.00003
    elif cl == "cristal":
        # inclusions et fines fêlures internes (pas de relief : ce sont des lignes claires, voir composer)
        pass
    return h, fil, riv


def preparer(ob, K, cartes, L):
    """Tout ce qui ne dépend pas de la peinture : normale finale, occlusion, courbure, masques par classe."""
    N = K.N
    m = K.masque
    noms = [mm.name for mm in ob.data.materials]
    classes = [classe(n) for n in noms]
    cl_tex = np.full((N, N), "", dtype=object)
    for i, c in enumerate(classes):
        cl_tex[(K.mat == i) & m] = c
    R3 = np.array(ob.matrix_world)[:3, :3]
    nb = cartes["NORMAL"] * 2 - 1
    nb = nb @ R3.T
    nb /= np.maximum(np.linalg.norm(nb, axis=-1, keepdims=True), 1e-9)
    perdu = (np.abs(cartes["NORMAL"] - 0.5).sum(-1) < 1e-3) | ~np.isfinite(nb).all(-1)
    nb = np.where(perdu[..., None] | ~m[..., None], K.nrm, nb)
    ao = np.clip(cartes["AO"][..., 0], 0, 1)
    ao = _flou(np.where(m, ao, 1.0), m, 2)
    dist, absc, tang = distance_lignes(K, cl_tex, L)
    H = np.zeros((N, N)); FIL_ = np.zeros((N, N)); RIV = np.zeros((N, N))
    eps = 0.0004
    nf = nb.copy()
    for c in set(classes):
        sel = (cl_tex == c) & m
        if not sel.any():
            continue
        P = K.pos[sel]; Nn = nb[sel]
        d, s, T = dist[sel], absc[sel], tang[sel]
        h, fil, riv = relief_fin(c, P, Nn, d, s, T)
        H[sel] = h; FIL_[sel] = fil; RIV[sel] = riv
    # gradient de la hauteur fine dans l'atlas, ramené sur la surface (comme les bordures de cuire.py)
    hd_ = RS.dilater(H[..., None], m, passes=3)[..., 0]
    hx = (np.roll(hd_, -1, 1) - np.roll(hd_, 1, 1)) / 2
    hy = (np.roll(hd_, -1, 0) - np.roll(hd_, 1, 0)) / 2
    Tx, Ty = K.tx, K.ty
    a11 = (Tx * Tx).sum(-1); a12 = (Tx * Ty).sum(-1); a22 = (Ty * Ty).sum(-1)
    det = a11 * a22 - a12 * a12
    det = np.where(np.abs(det) < 1e-16, 1e-16, det)
    ca = (a22 * hx - a12 * hy) / det
    cb = (a11 * hy - a12 * hx) / det
    g = Tx * ca[..., None] + Ty * cb[..., None]
    g = np.where(m[..., None], np.clip(g, -1.5, 1.5), 0.0)
    nf = nf - (g - (g * nf).sum(-1, keepdims=True) * nf)
    nf /= np.maximum(np.linalg.norm(nf, axis=-1, keepdims=True), 1e-9)
    # courbure (divergence de la normale finale), voisins 3D seulement
    pos = K.pos
    div = np.zeros((N, N))
    for (dy, dx) in ((0, 1), (1, 0)):
        pa, pb = _voisin(pos, dy, dx), _voisin(pos, -dy, -dx)
        na, nb2 = _voisin(nf, dy, dx), _voisin(nf, -dy, -dx)
        ma, mb = _voisin(m, dy, dx), _voisin(m, -dy, -dx)
        dp = pa - pb
        l2 = (dp * dp).sum(-1)
        tex = np.sqrt(np.maximum((K.tx * K.tx).sum(-1) if dx else (K.ty * K.ty).sum(-1), 1e-14))
        ok = ma & mb & m & (l2 < (4.0 * tex) ** 2) & (l2 > 1e-14)
        div += np.where(ok, ((na - nb2) * dp).sum(-1) / np.maximum(l2, 1e-14), 0.0)
    cv = np.clip(_flou(div * 0.0045, m, 1), -1, 1)
    cvl = np.clip(_flou(cv, m, 4) * 2.2, -1, 1)
    # liseré d'ARÊTE (ligne 3D) : fin (0-0,9 mm) et net, survit au 480 x 270 grâce aux mipmaps « plus proche »
    lis = np.exp(-(dist * 1000.0 / 0.9) ** 2) * m
    P = dict(m=m, cl=cl_tex, classes=classes, nf=nf, ao=ao, cv=cv, cvl=cvl, dist=dist, fil=FIL_, riv=RIV, lis=lis, K=K)
    return P


def composer(Pp, base, dbg=None, nom=""):
    m = Pp["m"]; cl = Pp["cl"]; nf = Pp["nf"]; ao = Pp["ao"]; K = Pp["K"]
    N = K.N
    convexe = np.clip(Pp["cv"], 0, 1); creux = np.clip(-Pp["cv"], 0, 1)
    convexe_l = np.clip(Pp["cvl"], 0, 1); creux_l = np.clip(-Pp["cvl"], 0, 1)
    lam = np.clip((nf * LUM).sum(-1), 0, 1)
    ciel = 0.5 + 0.5 * nf[..., 2]
    spec = np.clip((nf * DEMI).sum(-1), 0, 1) ** 10
    rgb = base[..., :3].copy(); bri = base[..., 3].copy()
    bruit = np.zeros((N, N)); bruit[m] = D.fbm3(K.pos[m], 77, oct=((0.03, 0.6), (0.012, 0.4)))
    def par_classe(cle):
        out = np.zeros((N, N))
        for c, f in F.items():
            out[cl == c] = f[cle]
        return out
    k_occ, k_ecl, k_spec = par_classe("occ"), par_classe("ecl"), par_classe("spec")
    k_ar, k_cr, k_bri = par_classe("arete"), par_classe("creux"), par_classe("bri_arete")
    occl = ao ** 1.5
    rgb = rgb * (1 - k_occ[..., None] * (1 - occl[..., None]))
    ecl = 1.0 + k_ecl * ((0.65 * lam + 0.35 * ciel) - 0.62)
    rgb = rgb * ecl[..., None]
    # creux : sombre (crasse dans les plis, joints entre plaques)
    kc = np.clip(k_cr * (creux * 0.5 + creux_l * 1.3), 0, 0.8) * (0.7 + 0.5 * bruit)
    rgb = rgb * (1 - kc[..., None])
    # arêtes : liseré clair net (ligne 3D) + bombés convexes
    wl, wc, wcl = np.zeros((N, N)), np.zeros((N, N)), np.zeros((N, N))
    for c, (a_, b_, c_) in POIDS_ARETE.items():
        wl[cl == c] = a_; wc[cl == c] = b_; wcl[cl == c] = c_
    arete = np.clip(Pp["lis"] * wl + convexe * wc + convexe_l * wcl, 0, 1) * np.clip(occl * 1.3, 0, 1)
    lum_b = rgb.mean(-1, keepdims=True)
    clair = np.where((cl == "cristal")[..., None], rgb * 1.55 + 0.06, np.where((cl == "metal")[..., None], np.maximum(rgb * 1.7, 0.55 * lum_b + 0.24),
             np.where((cl == "os")[..., None], IVOIRE * 0.9, rgb * 1.6 + 0.04)))
    ka = (k_ar * arete)[..., None]
    rgb = rgb * (1 - ka) + np.clip(clair, 0, 1) * ka
    # reflet cuit sur les bombés (métal, un peu le cuir et l'os)
    rgb = rgb + (k_spec * spec * occl)[..., None] * np.array([0.85, 0.86, 0.88])
    # cristal : fêlures et plans de clivage internes (lignes claires fines, de longueur et d'intensité variables), fumée sombre au cœur
    cr = (cl == "cristal") & m
    if cr.any():
        Pc = K.pos[cr]
        d1, d2 = D.voronoi3(Pc, 0.016, 401)
        fel = np.exp(-((d2 - d1) / 0.045) ** 2) * D.lisse(0.45, 0.7, D.fbm3(Pc, 403, oct=((0.03, 0.6), (0.012, 0.4))))
        fum = D.lisse(0.55, 0.8, D.fbm3(Pc, 405, oct=((0.05, 0.6), (0.02, 0.4))))
        R = rgb[cr]
        R = R * (1 - 0.30 * fum[:, None])
        R = R * (1 - 0.30 * fel[:, None]) + np.clip(R * 1.7 + 0.07, 0, 1) * 0.30 * fel[:, None]
        rgb[cr] = R
    # cuir : points de couture en lin ciré
    fil = Pp["fil"]
    kf = np.where(cl == "cuir", fil * 0.85, 0.0)[..., None]
    rgb = rgb * (1 - kf) + FIL * (0.75 + 0.35 * lam[..., None]) * kf
    # métal : têtes de rivet claires au sommet
    kr = np.where((cl == "metal") | (cl == "or"), Pp["riv"], 0.0)[..., None]
    rgb = rgb * (1 - 0.5 * kr) + np.clip(rgb * 2.0 + 0.1, 0, 1) * 0.5 * kr
    # fourrure : pointes des mèches claires, racines sombres (hauteur ~ courbure fine)
    kfo = (cl == "fourrure")
    rgb = np.where(kfo[..., None], rgb * (0.82 + 0.36 * np.clip(0.5 + Pp["cv"] * 2.5, 0, 1))[..., None], rgb)
    # BRILLANCE (alpha) : cristal/plaques : masque inchangé (shader pierre : seuil 0,5-0,6) ; verre : arêtes relevées ;
    # métal : arêtes et rivets polis, creux éteints ; cuir : corps mat, bords lustrés ; fourrure : aucun reflet
    est_masque = np.zeros((N, N), bool)
    for i, nmat in enumerate([mm for mm in Pp["classes"]]):
        pass
    bri2 = bri.copy()
    met = (cl == "metal") | (cl == "or")
    bri2 = np.where(met, np.clip(bri * (0.5 + 0.5 * occl) + k_bri * arete + 0.4 * Pp["riv"] - 0.35 * creux_l, 0, 1), bri2)
    cu = cl == "cuir"
    bri2 = np.where(cu, np.clip(0.10 + 0.55 * arete + 0.25 * fil, 0, 1), bri2)
    bri2 = np.where(cl == "fourrure", 0.0, bri2)
    bri2 = np.where(cl == "os", np.clip(bri * (0.6 + 0.4 * occl) + 0.25 * arete, 0, 1), bri2)
    bri2 = np.where(cl == "tissu", np.clip(bri * 0.5, 0, 1), bri2)
    out = np.concatenate([np.clip(rgb, 0, 1), bri2[..., None]], -1)
    out = np.where(m[..., None], out, 0.0)
    out = RS.dilater(out, m, passes=10)
    if dbg:
        os.makedirs(dbg, exist_ok=True)
        _png(os.path.join(dbg, nom + "_ao.png"), ao)
        _png(os.path.join(dbg, nom + "_normale.png"), nf * 0.5 + 0.5)
        _png(os.path.join(dbg, nom + "_base.png"), base[..., :3])
        _png(os.path.join(dbg, nom + "_albedo.png"), out[..., :3])
        _png(os.path.join(dbg, nom + "_brillance.png"), out[..., 3])
        _png(os.path.join(dbg, nom + "_aretes.png"), np.stack([arete, Pp["lis"], fil], -1))
    return out


def base_peinte(ob, K, imgs, classes_alpha_brute=None):
    """Peinture d'origine reprise dans les nouvelles UV : chaque texel lit l'image de SON matériau (bilinéaire)."""
    N = K.N
    out = np.zeros((N, N, 4))
    for i, im in enumerate(imgs):
        sel = (K.mat == i) & K.masque
        if im is None or not sel.any():
            continue
        out[sel] = RS.echantillonner_lisse(im, K.uv_src[sel])
        # alpha du cristal (masque du shader pierre) : plus proche voisin, pas de valeurs intermédiaires qui changeraient le seuil
        out[sel, 3] = RS.echantillonner(im, K.uv_src[sel])[:, 3]
    return out


def poser_image(ob, nom, out, px):
    img = bpy.data.images.new(nom, px, px, alpha=True)
    img.pixels.foreach_set(out.astype(np.float32).ravel())
    os.makedirs(TEXTURES, exist_ok=True)
    img.filepath_raw = os.path.join(TEXTURES, nom + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    for mt in ob.data.materials:
        if mt and mt.node_tree:
            for n in mt.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = img
    return img


def couleurs_neutres(ob):
    for ca in ob.data.color_attributes:
        for d in ca.data:
            d.color = (1.0, 1.0, 1.0, d.color[3])


# ------------------------------------------------------------------------------------------------------------ sol / variantes
def recopier_uv(src, dst):
    """UV de cuisson de src (couche 0, déjà finalisée) -> dst, par correspondance des UV D'ORIGINE (dst : même maillage reposé,
    éventuellement complété de faces dupliquées). src_old : UV d'origine de src (avant cuisson), gardées dans src['uv_old']."""
    so = src["uv_old"]; sn = src["uv_new"]; sp = src["polys"]
    me = dst.data
    do = uv_np(me, me.uv_layers[0].name)
    dn = do.copy()
    # index des polygones source par centre d'UV d'origine + matériau
    kd = KDTree(len(sp))
    for i, (ls, lt, mi) in enumerate(sp):
        c = so[ls:ls + lt].mean(0)
        kd.insert((c[0], c[1], mi * 10.0), i)
    kd.balance()
    direct = len(me.polygons) >= len(sp)
    n_direct = n_kd = 0
    for pi, p in enumerate(me.polygons):
        ls, lt = p.loop_start, p.loop_total
        if direct and pi < len(sp) and sp[pi][1] == lt and np.abs(do[ls:ls + lt] - so[sp[pi][0]:sp[pi][0] + lt]).max() < 1e-4:
            dn[ls:ls + lt] = sn[sp[pi][0]:sp[pi][0] + lt]
            n_direct += 1
            continue
        c = do[ls:ls + lt].mean(0)
        best = None
        for (co, j, d) in kd.find_n((c[0], c[1], p.material_index * 10.0), 6):
            if sp[j][1] == lt:
                best = j
                break
        if best is None:
            best = kd.find((c[0], c[1], p.material_index * 10.0))[1]
        s0, st, _ = sp[best]
        for k in range(lt):
            q = do[ls + k]
            dd = np.abs(so[s0:s0 + st] - q).sum(1)
            dn[ls + k] = sn[s0 + int(np.argmin(dd))]
        n_kd += 1
    me.uv_layers[0].data.foreach_set("uv", dn.ravel())
    print("RECOPIE UV", dst.name, n_direct, "faces directes", n_kd, "par correspondance")


# ------------------------------------------------------------------------------------------------------------ pièce
def cuire(pid, px, niveau, dbg, chemin_porte, chemin_sol, tex_nom):
    t0 = time.time()
    vider()
    ob, arm, neufs = importer(chemin_porte)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    imgs = images_par_materiau(ob)
    noms = [m.name for m in ob.data.materials]
    classes = [classe(n) for n in noms]
    print("PIECE", pid, tris, "tris, matieres", list(zip(noms, classes)))
    ancien = deplier(ob, px)
    me = ob.data
    src = dict(uv_old=uv_np(me, ancien), uv_new=uv_np(me, "cuisson"), polys=[(p.loop_start, p.loop_total, p.material_index) for p in me.polygons])
    K = RS.rasteriser(ob, "cuisson", ancien, px)
    print("RASTER", pid, round(float(K.masque.mean()), 3), "de l'atlas couvert")
    L = lignes(ob, classes)
    hd = haute_def(ob, "cuisson", niveau)
    cartes = cuire_cycles(hd, px, "cuisson")
    bpy.data.objects.remove(hd, do_unlink=True)
    Pp = preparer(ob, K, cartes, L)
    base = base_peinte(ob, K, imgs)
    out = composer(Pp, base, dbg, pid)
    finaliser_uv(ob, ancien)
    poser_image(ob, tex_nom, out, px)
    couleurs_neutres(ob)
    obs = [ob] + ([arm] if arm else [])
    if "--pas-export" not in ARGS:
        exporter(obs, chemin_porte)
    res = dict(K=K, Pp=Pp, src=src, px=px)
    # pose au sol
    if chemin_sol and os.path.exists(chemin_sol) and "--pas-sol" not in ARGS:
        for o in list(bpy.data.objects):
            if o not in (ob, arm):
                bpy.data.objects.remove(o, do_unlink=True)
        so, sarm, _ = importer(chemin_sol)
        recopier_uv(src, so)
        img = bpy.data.images.get(tex_nom)
        for mt in so.data.materials:
            if mt and mt.node_tree:
                for n in mt.node_tree.nodes:
                    if n.type == "TEX_IMAGE":
                        n.image = img
        couleurs_neutres(so)
        if "--pas-export" not in ARGS:
            exporter([so] + ([sarm] if sarm else []), chemin_sol)
    print("FIN", pid, round(time.time() - t0, 1), "s")
    return res


def variante(pid, res, chemin_porte, chemin_sol, tex_nom):
    """Variante « _enchante » : même maillage, sa propre peinture, même relief / occlusion."""
    vider()
    ob, arm, _ = importer(chemin_porte)
    src = res["src"]
    if len(ob.data.loops) != len(src["uv_old"]):
        print("!!! VARIANTE", pid, "maillage différent : ignorée")
        return
    imgs = images_par_materiau(ob)
    K = res["K"]
    base = base_peinte(ob, K, imgs)
    out = composer(res["Pp"], base, None, pid)
    ob.data.uv_layers[0].data.foreach_set("uv", src["uv_new"].ravel())
    poser_image(ob, tex_nom, out, res["px"])
    couleurs_neutres(ob)
    if "--pas-export" not in ARGS:
        exporter([ob] + ([arm] if arm else []), chemin_porte)
    if chemin_sol and os.path.exists(chemin_sol) and "--pas-sol" not in ARGS:
        for o in list(bpy.data.objects):
            if o not in (ob, arm):
                bpy.data.objects.remove(o, do_unlink=True)
        so, sarm, _ = importer(chemin_sol)
        recopier_uv(src, so)
        img = bpy.data.images.get(tex_nom)
        for mt in so.data.materials:
            if mt and mt.node_tree:
                for n in mt.node_tree.nodes:
                    if n.type == "TEX_IMAGE":
                        n.image = img
        couleurs_neutres(so)
        if "--pas-export" not in ARGS:
            exporter([so] + ([sarm] if sarm else []), chemin_sol)
    print("VARIANTE", pid, "ok")


def main():
    px = int(_opt("--px", 1024))
    niveau = int(_opt("--niveau-hd", 2))
    dbg = _opt("--debug", None)
    ids = [a for i, a in enumerate(ARGS) if not a.startswith("--") and (i == 0 or ARGS[i - 1] not in ("--px", "--debug", "--niveau-hd"))]
    for pid in ids:
        if pid.startswith("chausses:"):
            fam = pid.split(":")[1]
            cp = os.path.join(CHAUSSES, fam + ".glb")
            cs = os.path.join(SOL, "jambieres_" + fam + ".glb")
            cuire(pid, min(px, 512), niveau, dbg, cp, cs, "chausses_" + fam)
            continue
        cp = os.path.join(PORTE, pid + ".glb")
        cs = os.path.join(SOL, pid + ".glb")
        try:
            res = cuire(pid, px, niveau, dbg, cp, cs, pid)
        except AssertionError as e:
            print("CUISSON ECHEC", pid, e, "(glb gardé non cuit)")
            continue
        ce = os.path.join(PORTE, pid + "_enchante.glb")
        if os.path.exists(ce) and "--pas-enchante" not in ARGS:
            variante(pid + "_enchante", res, ce, os.path.join(SOL, pid + "_enchante.glb"), pid + "_enchante")


main()
